import CSV
import HDF5
using DataFrames, Query

GLOBAL_TYPES = Dict(
    :Vehicle_ID => Int,:Frame_ID => Int,:Total_Frames => Int,
    :Global_Time => Int,:Local_X => Float64,:Local_Y => Float64,
    :Global_X => Float64,:Global_Y => Float64, :Global_Heading => Float64,
    :v_Length => Float64,:v_Width => Float64,:v_Class => Int,
    :v_Vel => Float64,:v_Acc => Float64,:Lane_ID => Int,
    :Preceding => Int,:Following => Int,:Space_Headway => Float64,
    :Time_Headway => Float64)

# Convert all CSV files to HDF5
LOGDIR = Pkg.dir("NGSIM","data/trajectories")
OUTDIR = joinpath(LOGDIR,"HDF5")
filenames = [
                "i101_trajectories-0750am-0805am",
                "i101_trajectories-0805am-0820am",
                "i101_trajectories-0820am-0835am",
                "i80_trajectories-0400-0415",
                "i80_trajectories-0500-0515",
                "i80_trajectories-0515-0530"
                ]

# Convert NGSIM CSV files to a trajectory-based HDF5 format
for filename in filenames
    in_path = joinpath(LOGDIR, string(filename, ".csv"))
    out_path = joinpath(OUTDIR, string(filename, ".hdf5"))
    print("processing ", filename, "...\n")
    # get data types for columns
    df = CSV.read(in_path;rows=1)
    type_dict = Dict(k => GLOBAL_TYPES[k] for k in names(df))
    # read CSV file
    df = CSV.read(in_path; types=Dict(String(n) => v for (n,v) in type_dict))

    # write HDF5 file
    if !isfile(out_path) || "--overwrite" in ARGS
        HDF5.h5open(out_path, "w") do hdf5_file
            hdf5_file["Global_Time"] = sort!(collect(Set(df[:Global_Time])))
            hdf5_file["Frame_IDs"] = sort!(collect(Set(df[:Frame_ID])))
            vehicle_summaries = HDF5.g_create(hdf5_file, "vehicle_summaries")
            # record vehicle summaries
            sort!(df, [:Vehicle_ID, :Frame_ID])
            i = 1
            j = i
            while i < nrow(df)
                veh_id = df[i,:Vehicle_ID]
                while (df[j+1,:Vehicle_ID] == veh_id)
                    j += 1
                    if j == nrow(df)
                        break
                    end
                end
                df[i:j,:Global_X]
                car = HDF5.g_create(vehicle_summaries, string(veh_id))
                # attributes (single element only)
                HDF5.attrs(car)["id"] = df[i,:Vehicle_ID]
                HDF5.attrs(car)["Length"] = df[i,:v_Length]
                HDF5.attrs(car)["Width"] = df[i,:v_Width]
                HDF5.attrs(car)["Class"] = df[i,:v_Class]
                # time stamps
                car["Frame_IDs"] = df[i:j,:Frame_ID]
                # continuous features (can be smoothed)
                # continuous_features = HDF5.g_create(car, "car")
                car["Global_X"] = df[i:j,:Global_X]
                car["Global_Y"] = df[i:j,:Global_Y]
                if :Global_Heading in names(df)
                    car["Heading"] = df[i:j,:Global_Heading]
                end
                car["Local_X"] = df[i:j,:Local_X]
                car["Local_Y"] = df[i:j,:Local_Y]
                car["Vel"] = df[i:j,:v_Vel]
                car["Acc"] = df[i:j,:v_Acc]
                # discrete features (can't be smoothed)
                # discrete_features = HDF5.g_create(car, "discrete_features")
                car["Lane_ID"] = df[:Lane_ID]
                car["Preceding"] = df[:Preceding]
                car["Following"] = df[:Following]
                i = j + 1
            end
            # write active vehicle lists
            active_vehicles = HDF5.g_create(hdf5_file, "active_vehicles")
            sort!(df, [:Frame_ID, :Vehicle_ID])
            i = 1
            j = i
            while i < nrow(df)
                current_frame = df[i,:Frame_ID]
                while (df[j+1,:Frame_ID] == current_frame)
                    j += 1
                    if j == nrow(df)
                        break
                    end
                end
                active_vehicles[string(current_frame)] = df[i:j,:Vehicle_ID]
                i = j + 1
            end
        end
    else
        print(string("WARNING! You are about to overwrite ", out_path, "\n",
        "To proceed, pass in argument --overwrite"))
        break
    end
end
print("Processing Complete \n")
