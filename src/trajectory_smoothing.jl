# Smoothing
function locally_weighted_regression_smoothing(X, t_raw, t_smooth, order=2; σ=1.0, λ=0.0, threshold=0.01)
    """
    smoothes a time history of one or multiple features via locally weighted least
    squares regression
        X ∈ Rᵐˣᵈ        :   contains the 2D data to be smoothed
        t_raw ∈ Rᵐ      :   is a vector of time values corresponding to the rows
            of X
        t_smooth ∈ Rⁿ   :   is a vector of new time values at which to evaluate
            a smoothed row of X
        order ∈ R       :   is the order of regression polynomial
        σ ∈ R           :   tunes the "bandwidth" of the local smoothing kernel
        λ ∈ R           :   a scalar regularization term
    """
    t_s = t_smooth - t_raw[1]
    t_r = t_raw - t_raw[1]
    if ndims(X) > 1
        x_smooth = zeros(length(t_s),size(X)[end])
    else
        x_smooth = zeros(length(t_s))
    end
    d = Int(round(sqrt((σ^2)*-log(threshold))))
    for b in 1:length(t_s)
        t_eval = t_s[b]
        ctr = indmin((t_r - t_eval).^2)
        idx_left = max(ctr-d,1)
        idx_right = min(ctr+d,length(t_r))
        T = reduce(hcat,[t_r[idx_left:idx_right].^n for n in 0:order ])
        w = diagm(exp.(-((t_r[idx_left:idx_right] .- t_eval)/(t_r[idx_right]-t_r[idx_left])).^2)) / (2*d)
        # w = w + eye(size(w)[1])*(1 - sum(w)) / size(w)[1] # compensate for end effects
        # regression
        θ = nothing
        try
            θ = inv(T'*w*T + λ)*T'*w*X[idx_left:idx_right,:]
        catch error
            println("T: ", T)
            println("w: ", diag(w))
            throw(error)
        end
        x_smooth[b,:] = reduce(hcat,[[t_eval].^n for n in 0:order]) * θ
    end
    return x_smooth
end
# function locally_weighted_regression_smoothing(X, t_raw, t_smooth, order=2; σ=1.0, λ=0.0, dt=0.1, threshold=0.01)
#     """
#     smoothes a time history of one or multiple features via locally weighted least
#     squares regression
#         X ∈ Rᵐˣᵈ        :   contains the 2D data to be smoothed
#         t_raw ∈ Rᵐ      :   is a vector of time values corresponding to the rows
#             of X
#         t_smooth ∈ Rⁿ   :   is a vector of new time values at which to evaluate
#             a smoothed row of X
#         order ∈ R       :   is the order of regression polynomial
#         σ ∈ R           :   tunes the "bandwidth" of the local smoothing kernel
#         λ ∈ R           :   a scalar regularization term
#         threshold ∈ R   :   determines the cutoff weight beyond which examples
#             from X do not contribute to the regression
#     """
#     k1 = 1
#     k2 = 1
#     if ndims(X) > 1
#         x_smooth = zeros(length(t_smooth),size(X)[end])
#     else
#         x_smooth = zeros(length(t_smooth))
#     end
#     # d = Int(round(5*exp(σ^2)))
#     d = sqrt((σ^2)*-log(threshold))
#     for b in 1:length(t_smooth)
#         t_eval = t_smooth[b]
#         ctr = indmin((t_raw - t_eval).^2)
#         idx_left = ctr
#         while idx_left - 1 >= k1
#             if abs(t_eval - t_raw[idx_left - 1]) <= d
#                 idx_left = idx_left - 1
#             else
#                 break
#             end
#         end
#         k1 = idx_left
#         idx_right = k2
#         while k2 <= idx_right + 1 <= length(t_raw)
#             if abs(t_eval - t_raw[idx_right + 1]) <= d
#                 idx_right = idx_right + 1
#             else
#                 break
#             end
#         end
#         k2 = idx_right
#         T = reduce(hcat,[t_raw[idx_left:idx_right].^n for n in 0:order ])
#         w = diagm(exp.((1/σ^2)*-(t_raw[idx_left:idx_right] .- t_eval).^2))
#         # regression
#         θ = inv(T'*w*T + λ)*T'*w*X[idx_left:idx_right,:]
#         x_smooth[b,:] = reduce(hcat,[[t_eval].^n for n in 0:order]) * θ
#     end
#     return x_smooth
# end

# Filtering
mutable struct VehicleSystem
    H::Matrix{Float64} # observation Jacobian
    R::MvNormal # process noise
    Q::MvNormal # observation noise
    Δt::Float64
    n_integration_steps::Int
    control_noise_accel::Float64
    control_noise_turnrate::Float64

    function VehicleSystem(;
        process_noise::Float64 = 0.077,
        observation_noise::Float64 = 16.7,
        control_noise_accel::Float64 = 16.7,
        control_noise_turnrate::Float64 = 0.46,
        )

        Δt = 0.1
        H = [1.0 0.0 0.0 0.0;
             0.0 1.0 0.0 0.0]
        r = process_noise
        R = MvNormal(diagm([r*0.01, r*0.01, r*0.00001, r*0.1])) # process, TODO: tune this
        q = observation_noise
        Q = MvNormal(diagm([q, q])) # obs, TODO: tune this

        n_integration_steps = 10

        new(H, R, Q, Δt, n_integration_steps, control_noise_accel, control_noise_turnrate)
    end
end

draw_proc_noise(ν::VehicleSystem) = rand(ν.R)
draw_obs_noise(ν::VehicleSystem) = rand(ν.Q)
get_process_noise_covariance(ν::VehicleSystem) = ν.R.Σ.mat
get_observation_noise_covariance(ν::VehicleSystem) = ν.Q.Σ.mat

"""
    To derive the covariance of the additional motion noise,
    we first determine the covariance matrix of the noise in control space
    Inputs:
        - ν is the vehicle concrete type
        - u is the control [a,ω]ᵀ
"""
function get_control_noise_in_control_space(ν::VehicleSystem, u::Vector{Float64})
    [ν.control_noise_accel 0.0;
     0.0 ν.control_noise_turnrate]
end

"""
    To derive the covariance of the additional motion noise,
    we transform the covariance of noise in the control space
    by a linear approximation to the derivative of the motion function
    with respect to the motion parameters
    Inputs:
        - ν is the vehicle concrete type
        - u is the control [a,ω]ᵀ
        - x is the state estimate [x,y,θ,v]ᵀ
"""
function get_transform_control_noise_to_state_space(ν::VehicleSystem, u::Vector{Float64}, x::Vector{Float64})

    x, y, θ, v = x[1], x[2], x[3], x[4]
    a, ω = u[1], u[2]
    ω² = ω*ω
    Δt = ν.Δt

    ϕ = θ + ω*Δt

    if abs(ω) < 1e-6
        [0.0                  0.0;
         0.0                  0.0;
         0.0                   Δt;
          Δt                  0.0]
    else
        [0.0   v/ω²*(sin(θ) - sin(ϕ))+v/ω*cos(ϕ)*Δt;
         0.0  -v/ω²*(cos(θ) - cos(ϕ))+v/ω*sin(ϕ)*Δt;
         0.0                   Δt;
          Δt                  0.0]
    end
end

"""
    Vehicle dynamics, return the new state
    Inputs:
        - ν is the vehicle concrete type
        - x is the state estimate [x,y,θ,v]ᵀ
        - u is the control [a,ω]ᵀ
"""
function step(ν::VehicleSystem, x::Vector{Float64}, u::Vector{Float64})

    a, ω = u[1], u[2]
    x, y, θ, v = x[1], x[2], x[3], x[4]

    δt = ν.Δt/ν.n_integration_steps

    for i in 1 : ν.n_integration_steps

        if abs(ω) < 1e-6 # simulate straight
            x += v*cos(θ)*δt
            y += v*sin(θ)*δt
        else # simulate with an arc
            x += (v/ω)*(sin(θ + ω*δt) - sin(θ))
            y += (v/ω)*(cos(θ) - cos(θ + ω*δt))
        end

        θ += ω*δt
        v += a*δt
    end

    [x,y,θ,v]
end

"""
    Vehicle observation, returns a saturated observation
    Inputs:
        - ν is the vehicle concrete type
        - x is the state estimate [x,y,θ,v]ᵀ
"""
observe(ν::VehicleSystem, x::Vector{Float64}) = [x[1], x[2]]

"""
    Computes the observation Jacobian (H matrix)
    Inputs:
        - ν is the vehicle concrete type
        - x is the state estimate [x,y,θ,v]ᵀ
"""
compute_observation_jacobian(ν::VehicleSystem, x::Vector{Float64}) = ν.H

"""
    Computes the dynamics Jacobian
    Inputs:
        - ν is the vehicle
        - x is the vehicle state [x,y,θ,v]ᵀ
        - u is the control [a,ω]
"""
function compute_dynamics_jacobian(ν::VehicleSystem, x::Vector{Float64}, u::Vector{Float64})
    Δt = ν.Δt
    θ, v = x[3], x[4]
    ω = u[2]

    if abs(ω) < 1e-6
        # drive straight
        [1.0 0.0  -v*sin(θ)*Δt  cos(θ)*Δt;
         0.0 1.0   v*cos(θ)*Δt  sin(θ)*Δt;
         0.0 0.0        1.0         0.0;
         0.0 0.0        0.0         1.0]
    else
        # drive in an arc
        ϕ = θ+ω*Δt
        [1.0 0.0  v/ω*(-cos(θ) + cos(ϕ))   -1/ω*sin(θ) + 1/ω*sin(ϕ);
         0.0 1.0  v/ω*(-sin(θ) + sin(ϕ))    1/ω*cos(θ) - 1/ω*cos(ϕ);
         0.0 0.0              1.0                     0.0;
         0.0 0.0              0.0                     1.0]
    end
end

function EKF(
    ν::VehicleSystem,
    μ::Vector{Float64}, # mean of belief at time t-1
    Σ::Matrix{Float64}, # cov of belief at time t-1
    u::Vector{Float64}, # next applied control
    z::Vector{Float64}, # observation for time t
    )

    G = compute_dynamics_jacobian(ν, μ, u)
    μbar = step(ν, μ, u)
    R = get_process_noise_covariance(ν)
    M = get_control_noise_in_control_space(ν, u)
    V = get_transform_control_noise_to_state_space(ν, u, μbar)
    # R = V*M*V'
    Σbar = G*Σ*G' + R + V*M*V'
    H = compute_observation_jacobian(ν, μbar)
    K = Σbar * H' / (H*Σbar*H' + get_observation_noise_covariance(ν))
    μ_next = μbar + K*(z - observe(ν, μbar))
    Σ_next = Σbar - K*H*Σbar
    (μ_next, Σ_next)
end

mutable struct SimulationResults
    x_arr::Matrix{Float64}
    z_arr::Matrix{Float64}
    u_arr::Matrix{Float64}
    μ_arr::Matrix{Float64}
    Σ_arr::Array{Float64, 3}
end
function simulate(ν::VehicleSystem, nsteps::Int64, x₀::Vector{Float64})
    x_arr = fill(NaN, 4, nsteps+1)
    z_arr = fill(NaN, 2, nsteps)
    u_arr = fill(NaN, 2, nsteps)
    μ_arr = fill(NaN, 4, nsteps+1)
    Σ_arr = fill(NaN, 4, 4, nsteps+1)

    # initial belief
    μ = copy(x₀)
    Σ = copy(ν.R.Σ.mat)

    x_arr[:, 1] = x₀
    μ_arr[:, 1] = μ
    Σ_arr[:, :, 1] = Σ

    x = x₀
    for i in 1 : nsteps

        # move system forward and make observation
        u = [sin(i*0.01), cos(i*0.01)+0.01]
        xₚ = step(ν, x, u) + draw_proc_noise(ν)
        z = observe(ν, xₚ) + draw_obs_noise(ν)

        # record trajectories
        x_arr[:,i+1] = xₚ
        z_arr[:,i] = z
        u_arr[:,i] = u

        # apply Kalman filter
        μ_next, Σ_next = EKF(ν, μ, Σ, u, z)
        μ_arr[:,i+1] = μ_next
        Σ_arr[:,:,i+1] = Σ_next

        copy!(x, xₚ)
        copy!(μ, μ_next)
        copy!(Σ, Σ_next)
    end

    SimulationResults(x_arr, z_arr, u_arr, μ_arr, Σ_arr)
end
