using NGSIM


filepaths = [
    "/home/kylebrown/.julia/v0.6/NGSIM/data/trajectory_data/i101/i101_trajectories-0750am-0805am.csv"
    "/home/kylebrown/.julia/v0.6/NGSIM/data/trajectory_data/i101/i101_trajectories-0805am-0820am.csv"
    "/home/kylebrown/.julia/v0.6/NGSIM/data/trajectory_data/i101/i101_trajectories-0820am-0835am.csv"
    "/home/kylebrown/.julia/v0.6/NGSIM/data/trajectory_data/i80/i80_trajectories-0400pm-0415pm.csv"
    "/home/kylebrown/.julia/v0.6/NGSIM/data/trajectory_data/i80/i80_trajectories-0500pm-0515pm.csv"
    "/home/kylebrown/.julia/v0.6/NGSIM/data/trajectory_data/i80/i80_trajectories-0515pm-0530pm.csv"
    # "/home/kylebrown/.julia/v0.6/NGSIM/data/trajectory_data/Lankershim/lankershim_trajectories-0830am-0845pm.csv"
    # "/home/kylebrown/.julia/v0.6/NGSIM/data/trajectory_data/Lankershim/lankershim_trajectories-0845am-0900pm.csv"
    # "/home/kylebrown/.julia/v0.6/NGSIM/data/trajectory_data/Peachtree/peachtree_trajectories-0400pm-0415pm.csv"
    # "/home/kylebrown/.julia/v0.6/NGSIM/data/trajectory_data/Peachtree/peachtree_trajectories-1245pm-0100pm.csv"
]
convert_raw_csv_files_to_smoothed_csv(;filepaths=filepaths,convert_to_meters=true)
