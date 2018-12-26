export
    convert_csv_to_smoothed_csv,
    convert_raw_csv_files_to_smoothed_csv,
    convert_csv_to_hdf5,
    convert_smoothed_csv_files_to_hdf5,
    convert_raw_csv_files_to_smoothed_csv

const METERS_PER_FOOT = 0.3048
const dt = 0.1

smooth = (x,t) -> locally_weighted_regression_smoothing(x,t,t,2;σ=4.0,threshold=0.0001)
"""
    `convert_csv_to_smoothed_csv(in_path,out_path;factor=1.0)`

    smooths a raw .csv file at `in_path` and saves the output
    at `out_path`.
"""
function convert_csv_to_smoothed_csv(
    in_path,out_path,INPUT_TYPES,OUTPUT_TYPES,OUTPUT_COLS;
    convert_to_meters=false)

    factor = (convert_to_meters) ? METERS_PER_FOOT : 1.0

    if !isfile(out_path) || "--overwrite" in ARGS
        print("processing ", in_path, "...")
        df = CSV.read(in_path;rows=1)
        type_dict = Dict(k => INPUT_TYPES[k] for k in names(df))
        # read CSV file
        df = CSV.read(in_path; types=Dict(String(n) => v for (n,v) in type_dict))
        out_df = DataFrame([OUTPUT_TYPES[c] for c in OUTPUT_COLS],OUTPUT_COLS,0)
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
            # Smooth X
            X = smooth(df[i:j,:Global_X],collect(i:j))  * factor
            v_X = diff(X) / dt
            v_X = vcat(v_X[1],v_X)
            # Smooth Y
            Y = smooth(df[i:j,:Global_Y],collect(i:j))  * factor
            v_Y = diff(Y) / dt
            v_Y = vcat(v_Y[1],v_Y)
            # Write to out_df
            for k in i:j
                push!(
                    out_df,
                    Dict(
                        :id => df[i,:Vehicle_ID],
                        :Length => df[i,:v_Length] * factor,
                        :Width => df[i,:v_Width] * factor,
                        :Class => df[i,:v_Class],

                        :Frame_ID => df[k,:Frame_ID],
                        :Global_Time => df[k,:Global_Time],
                        :Global_X => X[k-i+1],
                        :Global_Y => Y[k-i+1],
                        :Vel_X => v_X[k-i+1],
                        :Vel_Y => v_Y[k-i+1],

                        :Lane_ID => df[k, :Lane_ID],
                        :Preceding => df[k,:Preceding],
                        :Following => df[k,:Following]
                    )
                )
            end
            i = j + 1
        end
        # Write out_df to csv file
        CSV.write(out_path, out_df)
        println("done")
    else
        println(string("WARNING! ", out_path, " already exists."))
        println("To overwrite, pass in argument --overwrite")
    end
end

"""
    `convert_raw_csv_files_to_smoothed_csv(;convert_to_meters=false)`

    Converts all raw .csv files in Pkg.dir("NGSIM","data","trajectory_data")
    to smoothed csv files. Note that the fieldnames used in the original NGSIM
    file are different than those used in the final NGSIM file (see function
    definition for details)
"""
function convert_raw_csv_files_to_smoothed_csv(;filepaths=nothing,convert_to_meters=false)
    INPUT_TYPES = Dict(
        :Vehicle_ID => Int,:Frame_ID => Int,:Total_Frames => Int,
        :Global_Time => Int,:Local_X => Float64,:Local_Y => Float64,
        :Global_X => Float64,:Global_Y => Float64, :Global_Heading => Float64,
        :v_Length => Float64,:v_Width => Float64,:v_Class => Int,
        :v_Vel => Float64,:v_Acc => Float64,:Lane_ID => Int,
        :Preceding => Int,:Following => Int,:Space_Headway => Float64,
        :Time_Headway => Float64)

    OUTPUT_COLS = [
        :id, :Length, :Width, :Class,
        :Frame_ID, :Global_Time, :Global_X, :Global_Y,
        :Vel_X, :Vel_Y, :Lane_ID, :Preceding, :Following
    ]
    OUTPUT_TYPES = Dict(
        :id => Int, :Length => Float64, :Width => Float64, :Class => Int,
        :Frame_ID => Int, :Global_Time => Float64, :Global_X => Float64,
        :Global_Y => Float64, :Vel_X => Float64, :Vel_Y => Float64,
        :Lane_ID => Int, :Preceding => Int, :Following => Int
    )
    if filepaths == nothing
        filepaths = Vector{String}()
        for (root, dirs, files) in walkdir(Pkg.dir("NGSIM","data","trajectory_data"))
            for file in files
                filepath = joinpath(root,file)
                (filename, ext) = splitext(filepath)
                if ext == ".csv" && !contains(filename,"smoothed")
                    push!(filepaths, filepath)
                end
            end
        end
    end

    # smooth = (x,t) -> locally_weighted_regression_smoothing(x,t,t,2;σ=4.0,threshold=0.0001)
    # Convert NGSIM CSV files to a trajectory-based HDF5 format
    for in_path in filepaths
        (filename, ext) = splitext(in_path)
        out_path = "$(filename)_smoothed$(ext)"
        # print("processing ", filename, "...\n")
        convert_csv_to_smoothed_csv(in_path,out_path,INPUT_TYPES,OUTPUT_TYPES,
            OUTPUT_COLS;convert_to_meters=convert_to_meters)
    end
    println("All Files Processed")
end

"""
    convert_csv_to_hdf5(in_path,out_path,INPUT_TYPES,OUTPUT_TYPES,OUTPUT_COLS;
        convert_to_meters=false)

    converts a smoothed .csv file at `in_path` and saves the output
    at `out_path`.
    ...
    # Arguments
    - `in_path::String` : path to input .csv file
    - `out_path::String` : path to output .csv file
    - `INPUT_TYPES::Dict{Symbol,Type}` :  Specifies types of columns in input file
    - `OUTPUT_TYPES::Dict{Symbol,Type}` :  Specifies types of columns in output file
    - `OUTPUT_COLS::Vector{Symbol}` :  Specifies names of columns in output file
    # Keyword Arguments:
    - convert_to_meters::Bool = false : if true, convert from feet to meters
    ...
"""
function convert_csv_to_hdf5(
    in_path,out_path,INPUT_TYPES,OUTPUT_TYPES,OUTPUT_COLS;
    convert_to_meters=false)

    factor = (convert_to_meters) ? METERS_PER_FOOT : 1.0

    # write HDF5 file
    if !isfile(out_path) || "--overwrite" in ARGS
        print("processing ", in_path, "...\n")
        # get data types for columns
        df = CSV.read(in_path;rows=1)
        type_dict = Dict(k => OUTPUT_TYPES[k] for k in names(df))
        # read CSV file
        df = CSV.read(in_path; types=Dict(String(n) => v for (n,v) in type_dict))
        HDF5.h5open(out_path, "w") do hdf5_file
            hdf5_file["Global_Time"] = sort!(collect(Set(df[:Global_Time])))
            hdf5_file["Frame_IDs"] = sort!(collect(Set(df[:Frame_ID])))
            vehicle_summaries = HDF5.g_create(hdf5_file, "vehicle_summaries")
            # record vehicle summaries
            sort!(df, [:id, :Frame_ID])
            i = 1
            j = i
            while i < nrow(df)
                veh_id = df[i,:id]
                while (df[j+1,:id] == veh_id)
                    j += 1
                    if j == nrow(df)
                        break
                    end
                end
                # df[i:j,:Global_X]
                car = HDF5.g_create(vehicle_summaries, string(veh_id))
                # attributes (single element only)
                HDF5.attrs(car)["id"]       = df[i,:id]
                HDF5.attrs(car)["Length"]   = df[i,:Length] * factor
                HDF5.attrs(car)["Width"]    = df[i,:Width] * factor
                HDF5.attrs(car)["Class"]    = df[i,:Class]
                # time stamps
                car["Frame_IDs"]            = df[i:j,:Frame_ID]
                car["Global_X"]             = df[i:j,:Global_X] * factor
                car["Global_Y"]             = df[i:j,:Global_Y] * factor
                car["Vel_X"]                = df[i:j,:Vel_X] * factor
                car["Vel_Y"]                = df[i:j,:Vel_Y] * factor
                i = j + 1
            end
            # write active vehicle lists
            active_vehicles = HDF5.g_create(hdf5_file, "active_vehicles")
            sort!(df, [:Frame_ID, :id])
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
                active_vehicles[string(current_frame)] = df[i:j,:id]
                i = j + 1
            end
        end
    else
        println(string("WARNING! ", out_path, " already exists. Skipping..."))
        println("To overwrite, pass in argument --overwrite")
    end
end

function convert_smoothed_csv_files_to_hdf5(;filepaths=nothing,convert_to_meters=false)
    # factor = (convert_to_meters) ? METERS_PER_FOOT : 1.0
    INPUT_TYPES = Dict(
        :Vehicle_ID => Int,:Frame_ID => Int,:Total_Frames => Int,
        :Global_Time => Int,:Local_X => Float64,:Local_Y => Float64,
        :Global_X => Float64,:Global_Y => Float64, :Global_Heading => Float64,
        :v_Length => Float64,:v_Width => Float64,:v_Class => Int,
        :v_Vel => Float64,:v_Acc => Float64,:Lane_ID => Int,
        :Preceding => Int,:Following => Int,:Space_Headway => Float64,
        :Time_Headway => Float64)

    OUTPUT_COLS = [
        :id, :Length, :Width, :Class,
        :Frame_ID, :Global_Time, :Global_X, :Global_Y,
        :Vel_X, :Vel_Y, :Lane_ID, :Preceding, :Following
    ]
    OUTPUT_TYPES = Dict(
        :id => Int, :Length => Float64, :Width => Float64, :Class => Int,
        :Frame_ID => Int, :Global_Time => Float64, :Global_X => Float64,
        :Global_Y => Float64, :Vel_X => Float64, :Vel_Y => Float64,
        :Lane_ID => Int, :Preceding => Int, :Following => Int
    )

    # Convert all CSV files to HDF5
    if filepaths == nothing
        filepaths = Vector{String}()
        for (root, dirs, files) in walkdir(Pkg.dir("NGSIM","data","trajectory_data"))
            for file in files
                filepath = joinpath(root,file)
                (filename, ext) = splitext(filepath)
                if ext == ".csv" && contains(filename,"smoothed")
                    push!(filepaths, filepath)
                end
            end
        end
    end

    # Convert NGSIM CSV files to a trajectory-based HDF5 format
    for in_path in filepaths
        (filename, ext) = splitext(in_path)
        out_path = "$(filename).hdf5"
        convert_csv_to_hdf5(in_path,out_path,INPUT_TYPES,OUTPUT_TYPES,
        OUTPUT_COLS;convert_to_meters=convert_to_meters)
    end
    println("Processing Complete")
end

function convert_raw_csv_files_to_smoothed_hdf5(;convert_to_meters=false)
    factor = (convert_to_meters) ? METERS_PER_FOOT : 1.0
    INPUT_TYPES = Dict(
        :Vehicle_ID => Int,:Frame_ID => Int,:Total_Frames => Int,
        :Global_Time => Int,:Local_X => Float64,:Local_Y => Float64,
        :Global_X => Float64,:Global_Y => Float64, :Global_Heading => Float64,
        :v_Length => Float64,:v_Width => Float64,:v_Class => Int,
        :v_Vel => Float64,:v_Acc => Float64,:Lane_ID => Int,
        :Preceding => Int,:Following => Int,:Space_Headway => Float64,
        :Time_Headway => Float64)

    smooth = (x,t) -> locally_weighted_regression_smoothing(x,t,t,2;σ=4.0,threshold=0.0001)

    filepaths = Vector{String}()
    for (root, dirs, files) in walkdir(Pkg.dir("NGSIM","data","trajectory_data"))
        for file in files
            filepath = joinpath(root,file)
            (filename, ext) = splitext(filepath)
            if ext == ".csv" && !contains(filename,"smoothed")
                push!(filepaths, filepath)
            end
        end
    end
    # Convert NGSIM CSV files to a trajectory-based HDF5 format
    for in_path in filepaths
        (filename, ext) = splitext(in_path)
        out_path = "$(filename)_smoothed.hdf5"
        print("processing ", in_path, "...\n")
        # get data types for columns
        df = CSV.read(in_path;rows=1)
        type_dict = Dict(k => INPUT_TYPES[k] for k in names(df))
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
                    car = HDF5.g_create(vehicle_summaries, string(veh_id))
                    # attributes (single element only)
                    HDF5.attrs(car)["id"] = df[i,:Vehicle_ID]
                    HDF5.attrs(car)["Length"] = df[i,:v_Length] * factor
                    HDF5.attrs(car)["Width"] = df[i,:v_Width]   * factor
                    HDF5.attrs(car)["Class"] = df[i,:v_Class]
                    # time stamps
                    car["Frame_IDs"] = df[i:j,:Frame_ID]
                    # continuous features (can be smoothed)
                    X = smooth(df[i:j,:Global_X],collect(i:j))  * factor
                    v_X = diff(X) / dt
                    v_X = vcat(v_X[1],v_X)
                    car["Global_X"] = X
                    car["Vel_X"] = v_X
                    Y = smooth(df[i:j,:Global_Y],collect(i:j))  * factor
                    v_Y = diff(Y) / dt
                    v_Y = vcat(v_Y[1],v_Y)
                    car["Global_Y"] = Y
                    car["Vel_Y"] = v_Y

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
            println(string("WARNING! ", out_path, " already exists. Skipping..."))
            println("To overwrite, pass in argument --overwrite")
        end
    end
    println("Processing Complete")
end
