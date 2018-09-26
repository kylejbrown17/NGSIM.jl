__precompile__(true)

module NGSIM

# using AutomotiveDrivingModels
using DataFrames, CSV, Query
import HDF5
using Distributions
using Parameters

include("data_loader.jl")
include("trajectory_smoothing.jl")
include("preprocessing.jl")
# include("roadway.jl")
# include("ngsim_trajdata.jl")
# include("trajdata.jl")

end # module
