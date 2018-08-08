import CSV
import HDF5
using DataFrames, Query
# using NGSIM

# using IRLutils
# using VehicleModels
function getDataTypeVector(file_path;global_types= Dict("Vehicle_ID" => Int,"Frame_ID" => Int,"Total_Frames" => Int,
        "Global_Time" => Int,"Local_X" => Float64,"Local_Y" => Float64,
        "Global_X" => Float64,"Global_Y" => Float64,# "Global_Heading" => Float64,
        "v_Length" => Float64,"v_Width" => Float64,"v_Class" => Int,
        "v_Vel" => Float64,"v_Acc" => Float64,"Lane_ID" => Int,
        "Preceding" => Int,"Following" => Int,"Space_Headway" => Float64,
        "Time_Headway" => Float64))
    """
    retrieves the data types associated with logfiles. Important for loading
    logfiles into the correct datatypes
    """
    df = CSV.read(file_path;rows=1)
    type_keys = [String(n) for n in df.colindex.names]
    types = Dict(k => global_types[k] for k in type_keys)
    return types
end

function getActiveAgents(history,k1,k2;
    ego_id=nothing,fnames=nothing,type_dict=nothing,dt=0.1)
    active_agents = [
        (id,d,b1,b2) for (id,d,b1,b2) in history if k1 <= b2 && k2 >= b1 && b2 - b1 > 2 && id != ego_id];
    ## Check if active agents are in the right time window
    # PyPlot.plot([1 length(active_agents)]', [k1 k1]',c="black")
    # PyPlot.plot([1 length(active_agents)]', [k2 k2]',c="black")
    # for (i,(id,d,b1,b2)) in enumerate(active_agents)
    #     PyPlot.plot([i;i],[b1;b2],c="r")
    # end
    cars = Dict()
    for (id,d,b1,b2) in active_agents
        if b2-b1 > 1
            features = extractAgentData(id,b1,b2,data,fnames; type_dict=type_dict)
            cars[id] = VehicleSummary(features, dt)
        end
    end
    return cars
end

# Convert all CSV files to HDF5
LOGDIR = Pkg.dir("NGSIM","data")
OUTDIR = joinpath(LOGDIR,"HDF5")
filenames = [
                "i101_trajectories-0750am-0805am",
                "i101_trajectories-0805am-0820am",
                "i101_trajectories-0820am-0835am",
                "i80_trajectories-0400-0415",
                "i80_trajectories-0500-0515",
                "i80_trajectories-0515-0530"
                ]

for filename in filenames
    in_path = joinpath(LOGDIR, string(filename, ".csv"))
    out_path = joinpath(OUTDIR, string(filename, ".hdf5"))
    print("processing ", filename, "...\n")
    types = getDataTypeVector(in_path)
    # csv_data = CSV.read(in_path; types=types);
    #
    # fnames = names(csv_data)
    # type_dict = Dict(fnames[i]=>types[i] for i in 1:length(fnames));
    # vehicle_fnames = [Symbol(string(n)[12:end]) for n in names(csv_data) if contains(string(n), "veh0_mode0_")]
    # vehicle_type_dict = Dict(k=>type_dict[Symbol(string("veh0_mode0_",string(k)))] for k in vehicle_fnames);
    #
    # agent_history = computeAgentHistory(csv_data);
    #
    # if !isfile(out_path) || "--overwrite" in ARGS
    #     HDF5.h5open(out_path, "w") do hdf5_file
    #         vehicle_summaries = HDF5.g_create(hdf5_file, "vehicle_summaries")
    #         global_time = HDF5.g_create(hdf5_file, "global_time")
    #         global_time["time"] = csv_data[:timestamp].values .- csv_data[:timestamp].values[1]
    #
    #         for (i, (id, d, k1, k2)) in enumerate(agent_history)
    #             car = HDF5.g_create(vehicle_summaries, string("vehicle_",i))
    #             features = extractAgentData(id, k1, k2, csv_data, vehicle_fnames; type_dict=vehicle_type_dict)
    #             # attributes (single element only)
    #             HDF5.attrs(car)["id"] = id
    #             HDF5.attrs(car)["k1"] = k1
    #             HDF5.attrs(car)["k2"] = k2
    #             HDF5.attrs(car)["length"] = features[:length][end]
    #             HDF5.attrs(car)["width"] = features[:width][end]
    #             HDF5.attrs(car)["height"] = features[:height][end]
    #             HDF5.attrs(car)["x_offset"] = features[:x_offset][end]
    #             # time stamps
    #             car["time_stamps"] = collect(k1:k2)
    #             # continuous features (can be smoothed)
    #             continuous_features = HDF5.g_create(car, "continuous_features")
    #             continuous_features["X"] = features[:position_x]
    #             continuous_features["Y"] = features[:position_y]
    #             continuous_features["Z"] = features[:position_z]
    #             continuous_features["v_x"] = features[:v_linear_x]
    #             continuous_features["v_y"] = features[:v_linear_y]
    #             continuous_features["v_z"] = features[:v_linear_z]
    #             # discrete features (can't be smoothed)
    #             discrete_features = HDF5.g_create(car, "discrete_features")
    #             discrete_features["num_lanes"] = features[:num_lanes]
    #             discrete_features["lane_id0"] = features[:lane_id0]
    #             discrete_features["lane_id1"] = features[:lane_id1]
    #             discrete_features["lane_id2"] = features[:lane_id2]
    #             discrete_features["lane_id3"] = features[:lane_id3]
    #         end
    #     end
    # else
    #     print(string("WARNING! You are about to overwrite ", out_path, "\n",
    #     "To proceed, pass in argument --overwrite"))
    #     break
    # end
end
print("Processing Complete \n")
