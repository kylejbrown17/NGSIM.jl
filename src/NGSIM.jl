__precompile__(true)

module NGSIM

# using AutomotiveDrivingModels
using DataFrames, CSV, Query
import HDF5
using Distributions
using Parameters

export
    VehicleSummary,
    DataLoader,
    set_index!,
    step!,
    prune_snapshot,
    # trajectory smoothing
    locally_weighted_regression_smoothing,
    # NGSIMRoadway,
    # RoadwayInputParams,
    #
    # ROADWAY_80,
    # ROADWAY_101,
    #
    # NGSIMTrajdata,
    # VehicleSystem,
    # FilterTrajectoryResult,
    #
    # NGSIM_TIMESTEP,
    # NGSIM_TRAJDATA_PATHS,
    # TRAJDATA_PATHS,
    #
    # carsinframe,
    # load_ngsim_trajdata,
    # get_corresponding_roadway,
    # filter_trajectory!,
    # symmetric_exponential_moving_average!,
    # load_trajdata,
    # convert_raw_ngsim_to_trajdatas,
    # smooth_ngsim_data

    # data conversion
    convert_csv_to_hdf5,
    convert_csv_to_smoothed_hdf5

include("data_loader.jl")
include("trajectory_smoothing.jl")
include("ngsim_data_conversion.jl")
# include("roadway.jl")
# include("ngsim_trajdata.jl")
# include("trajdata.jl")

end # module
