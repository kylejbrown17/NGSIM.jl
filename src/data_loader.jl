export
    VehicleSummary,
    vehicle_summary_from_dict,
    DataLoader,
    set_index!,
    step!,
    prune_snapshot

const num2class = Dict(1 => :motorcycle, 2 => :car, 3 => :truck)
const class2num = Dict(v => k for (k,v ) in num2class)

@with_kw struct VehicleSummary{T,S}
    id::Int64               = 0
    length::Float64         = 4.5
    width::Float64          = 2.8
    height::Float64         = 1.8
    class::Int              = 1

    time_stamps::S          = fill!(Vector{Int}(10),-1)
    X::T                    = fill!(Vector{Float64}(10),NaN)
    Y::T                    = fill!(Vector{Float64}(10),NaN)
    θ::T                    = fill!(Vector{Float64}(10),NaN)
    v::T                    = fill!(Vector{Float64}(10),NaN)
    v_x::T                  = fill!(Vector{Float64}(10),NaN)
    v_y::T                  = fill!(Vector{Float64}(10),NaN)
    # Frenet trajectory
    s::T                    = fill!(Vector{Float64}(10),NaN)
    t::T                    = fill!(Vector{Float64}(10),NaN)
    ϕ::T                    = fill!(Vector{Float64}(10),NaN)
    lane_ids::S             = fill!(Vector{Int}(10),-1)
    # d_left::T               = zeros(10)
    # d_right::T              = zeros(10)
    # Control history
    # a::T # acceleration
    # ω::T # steering angle
end

function VehicleSummary(car::VehicleSummary,idx::Int)
    """
    returns a "snapshot" VehicleSummary
    """
    VehicleSummary(
        id = car.id,
        length = car.length,
        width = car.width,
        class = car.class,
        time_stamps = car.time_stamps[idx],
        X = car.X[idx],
        Y = car.Y[idx],
        θ = car.θ[idx],
        v = car.v[idx],
        v_x = car.v_x[idx],
        v_y = car.v_y[idx],
        s = car.s[idx],
        t = car.t[idx],
        ϕ = car.ϕ[idx],
        lane_ids = car.lane_ids[idx]
    )
end
function vehicle_summary_from_dict(dict)
    N = length(get(dict, "Frame_IDs", [0]))
    VehicleSummary{Vector{Float64},Vector{Int}}(
        id      = get(dict, "id", -1),
        length  = get(dict, "Length", 4.5),
        width   = get(dict, "Width", 2.8),
        width   = get(dict, "Width", 1.8),
        class   = get(dict, "Class", 1),
        time_stamps = get(dict, "Frame_IDs", fill!(Array{Int}(N),typemin(Int))),
        X       = get(dict, "Global_X", fill!(Array{Float64}(N),NaN)),
        Y       = get(dict, "Global_Y", fill!(Array{Float64}(N),NaN)),
        θ       = get(dict, "Heading", fill!(Array{Float64}(N),NaN)),
        v       = get(dict, "Vel", fill!(Array{Float64}(N),NaN)),
        v_x     = get(dict, "Vel_X", fill!(Array{Float64}(N),NaN)),
        v_y     = get(dict, "Vel_Y", fill!(Array{Float64}(N),NaN)),
        s       = get(dict, "S", fill!(Array{Float64}(N),NaN)),
        t       = get(dict, "T", fill!(Array{Float64}(N),NaN)),
        ϕ       = get(dict, "Phi", fill!(Array{Float64}(N),NaN)),
        lane_ids = get(dict, "Lane_ID", fill!(Array{Int64}(N),typemin(Int))),
    )
end

mutable struct DataLoader
    hdf5_file::HDF5.HDF5File
    active_vehicles::HDF5.HDF5Group
    time_stamps::Vector{Int}
    idx::Int
    vehicle_summaries::Dict{Int,VehicleSummary{Vector{Float64},Vector{Int}}}
end

function DataLoader(filepath::String; idx=1)
    hdf5_file = HDF5.h5open(filepath)
    active_vehicles = hdf5_file["active_vehicles"]
    time_stamps = HDF5.read(hdf5_file["Frame_IDs"])
    idx = idx
    vehicle_summaries = Dict{Int,VehicleSummary{Vector{Float64},Vector{Int}}}()
    for id in HDF5.read(active_vehicles[string(time_stamps[idx])])
        car = HDF5.read(hdf5_file["vehicle_summaries"][string(id)])
        car["id"]       = HDF5.a_read(hdf5_file["vehicle_summaries"][string(id)], "id")
        car["Length"]   = HDF5.a_read(hdf5_file["vehicle_summaries"][string(id)], "Length")
        car["Width"]    = HDF5.a_read(hdf5_file["vehicle_summaries"][string(id)], "Width")
        car["Class"]    = HDF5.a_read(hdf5_file["vehicle_summaries"][string(id)], "Class")
        vehicle_summaries[id] = vehicle_summary_from_dict(car)
    end
    DataLoader(hdf5_file,active_vehicles,time_stamps,idx,vehicle_summaries)
end

function set_index!(loader::DataLoader, idx)
    loader.idx = idx
    active_ids = HDF5.read(loader.active_vehicles[string(loader.time_stamps[loader.idx])])
    dropped_ids = setdiff(collect(keys(loader.vehicle_summaries)), active_ids)
    for id in dropped_ids
        delete!(loader.vehicle_summaries, id)
    end
    for id in active_ids
        if !haskey(loader.vehicle_summaries, id)
            car = HDF5.read(loader.hdf5_file["vehicle_summaries"][string(id)])
            car["id"]       = HDF5.a_read(loader.hdf5_file["vehicle_summaries"][string(id)], "id")
            car["Length"]   = HDF5.a_read(loader.hdf5_file["vehicle_summaries"][string(id)], "Length")
            car["Width"]    = HDF5.a_read(loader.hdf5_file["vehicle_summaries"][string(id)], "Width")
            car["Class"]    = HDF5.a_read(loader.hdf5_file["vehicle_summaries"][string(id)], "Class")
            loader.vehicle_summaries[id] = vehicle_summary_from_dict(car)
        end
    end
    """
    Need to return state snapshots! Should have left things as states rather
    than breaking it out into trajectories...
    But then again, it's probably not that much slower to pull things out this
    way
    """
    return Dict{Int,VehicleSummary{Float64,Int}}(
        id => VehicleSummary(car, loader.time_stamps[loader.idx] - car.time_stamps[1] + 1)
        for (id,car) in loader.vehicle_summaries
    )
end

function step!(loader::DataLoader)
    set_index!(loader, loader.idx + 1)
end

function prune_snapshot(snapshot::Dict{Int,VehicleSummary{Float64,Int}}, ego_id::Int;
    MAX_DIST = 300)
    """
    pruned out vehicles that are farther from ego vehicle than MAX_DIST
    """
    ego_summary = snapshot[ego_id]
    pruned_snapshot = similar(snapshot)
    for k in keys(snapshot)
        veh_summary = snapshot[k]
        if norm([veh_summary.X - ego_summary.X; veh_summary.Y - ego_summary.Y]) < MAX_DIST
            pruned_snapshot[k] = veh_summary
        end
    end
    pruned_snapshot
end
