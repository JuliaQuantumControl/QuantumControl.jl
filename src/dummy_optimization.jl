# SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT

"""Dummy control problems and a dummy optimization method, for testing.

!!! warning

    This module is experimental. It is not part of the public API of
    `QuantumControl` and is not covered by semantic versioning: it may change or
    be removed in any release.

It provides [`dummy_control_problem`](@ref
QuantumControl.DummyOptimization.dummy_control_problem) to set up a control
problem with random operators and states, and the `:dummymethod` optimization
method for [`QuantumControl.optimize`](@ref), implemented by
[`optimize_with_dummy_method`](@ref
QuantumControl.DummyOptimization.optimize_with_dummy_method). These are used for
testing the optimization machinery in `QuantumControl` and packages that
implement optimization methods.
"""
module DummyOptimization

using Random
using Printf
using LinearAlgebra
using SparseArrays

using ..Controls: get_controls, discretize, discretize_on_midpoints
using ..QuantumControl: Trajectory, ControlProblem
import ..QuantumControl


# The following functions are private copies of the random-object generators
# in `QuantumControlTestUtils.RandomObjects` (which `QuantumControl` cannot
# depend on). For the same `rng`, they must produce the same random objects.

function random_matrix(
    N;
    density = 1.0,
    complex = true,
    hermitian = false,
    spectral_radius = 1.0,
    exact_spectral_radius = false,
    rng = Random.GLOBAL_RNG
)
    if (density ≤ 0.0) || (density > 1.0)
        error("density must be in (0, 1]")
    end
    if complex
        if density < 1.0  # sparse matrix
            if hermitian
                random_hermitian_sparse_matrix(
                    N,
                    spectral_radius,
                    density;
                    rng,
                    exact_spectral_radius
                )
            else
                random_complex_sparse_matrix(
                    N,
                    spectral_radius,
                    density;
                    rng,
                    exact_spectral_radius
                )
            end
        else  # dense matrix
            if hermitian
                random_hermitian_matrix(N, spectral_radius; rng, exact_spectral_radius)
            else
                random_complex_matrix(N, spectral_radius; rng, exact_spectral_radius)
            end
        end
    else  # real-valued matrix
        if density < 1.0  # sparse matrix
            if hermitian
                random_hermitian_sparse_real_matrix(
                    N,
                    spectral_radius,
                    density;
                    rng,
                    exact_spectral_radius
                )
            else
                random_real_sparse_matrix(
                    N,
                    spectral_radius,
                    density;
                    rng,
                    exact_spectral_radius
                )
            end
        else  # dense matrix
            if hermitian
                random_hermitian_real_matrix(N, spectral_radius; rng, exact_spectral_radius)
            else
                random_real_matrix(N, spectral_radius; rng, exact_spectral_radius)
            end
        end
    end
end


function random_complex_matrix(N, ρ; rng = Random.GLOBAL_RNG, exact_spectral_radius = false)
    Δ = √(12 / N)
    X = Δ * (rand(rng, N, N) .- 0.5)
    Y = Δ * (rand(rng, N, N) .- 0.5)
    H = ρ * (X + Y * 1im) / √2
    if exact_spectral_radius
        λ = eigvals(H)
        Δ = maximum(abs.(λ))
        return (ρ / Δ) * H
    else
        return H
    end
end


function random_real_matrix(N, ρ; rng = Random.GLOBAL_RNG, exact_spectral_radius = false)
    Δ = √(12 / N)
    X = Δ * (rand(rng, N, N) .- 0.5)
    H = ρ * X
    if exact_spectral_radius
        λ = eigvals(H)
        Δ = maximum(abs.(λ))
        return (ρ / Δ) * H
    else
        return H
    end
end


function random_hermitian_matrix(
    N,
    ρ;
    rng = Random.GLOBAL_RNG,
    exact_spectral_radius = false
)
    Δ = √(12 / N)
    X = Δ * (rand(rng, N, N) .- 0.5)
    Y = Δ * (rand(rng, N, N) .- 0.5)
    Z = (X + Y * 1im) / √2
    H = ρ * (Z + Z') / (2 * √2)
    if exact_spectral_radius
        λ = eigvals(H)
        λ₀ = λ[1]
        Δ = λ[end] - λ₀
        H_norm = (H - λ₀ * I) / Δ
        return 2 * ρ * H_norm - ρ * I
    else
        return H
    end
end


function random_hermitian_real_matrix(
    N,
    ρ;
    rng = Random.GLOBAL_RNG,
    exact_spectral_radius = false
)
    Δ = √(12 / N)
    X = Δ * (rand(rng, N, N) .- 0.5)
    H = ρ * (X + X') / (2 * √2)
    if exact_spectral_radius
        λ = eigvals(H)
        λ₀ = λ[1]
        Δ = λ[end] - λ₀
        H_norm = (H - λ₀ * I) / Δ
        return 2 * ρ * H_norm - ρ * I
    else
        return H
    end
end


function random_complex_sparse_matrix(
    N,
    ρ,
    density;
    rng = Random.GLOBAL_RNG,
    exact_spectral_radius = false
)
    p = 1 - √(1 - density)
    Δ = √(12 / (p * N))
    X = sprand(rng, N, N, p)
    X.nzval .= Δ .* (X.nzval .- 0.5)
    Y = sprand(rng, N, N, p)
    Y.nzval .= Δ .* (Y.nzval .- 0.5)
    H = ρ * (X + Y * 1im) / √2
    if exact_spectral_radius
        λ = eigvals(Array(H))
        Δ = maximum(abs.(λ))
        return (ρ / Δ) * H
    else
        return H
    end
end


function random_real_sparse_matrix(
    N,
    ρ,
    density;
    rng = Random.GLOBAL_RNG,
    exact_spectral_radius = false
)
    p = density
    Δ = √(12 / (p * N))
    X = sprand(rng, N, N, density)
    X.nzval .= Δ .* (X.nzval .- 0.5)
    H = ρ * X
    if exact_spectral_radius
        λ = eigvals(Array(H))
        Δ = maximum(abs.(λ))
        return (ρ / Δ) * H
    else
        return H
    end
end


function random_hermitian_sparse_matrix(
    N,
    ρ,
    density;
    rng = Random.GLOBAL_RNG,
    exact_spectral_radius = false
)
    p = 1 - √(1 - density)
    Δ = √(12 / (p * N))
    X = sprand(rng, N, N, p)
    X.nzval .= Δ .* (X.nzval .- 0.5)
    Y = copy(X)
    Y.nzval .= Δ * (rand(rng, length(Y.nzval)) .- 0.5)
    Z = (X + Y * 1im) / √2
    H = ρ * (Z + Z') / (2 * √2)
    if exact_spectral_radius
        λ = eigvals(Array(H))
        λ₀ = λ[1]
        Δ = λ[end] - λ₀
        H_norm = (H - λ₀ * I) / Δ
        return 2 * ρ * H_norm - ρ * I
    else
        return H
    end
end


function random_hermitian_sparse_real_matrix(
    N,
    ρ,
    density;
    rng = Random.GLOBAL_RNG,
    exact_spectral_radius = false
)
    p = 1 - √(1 - density)
    Δ = √(12 / (p * N))
    X = sprand(rng, N, N, p)
    X.nzval .= Δ .* (X.nzval .- 0.5)
    H = ρ * (X + X') / (2 * √2)
    if exact_spectral_radius
        λ = eigvals(Array(H))
        λ₀ = λ[1]
        Δ = λ[end] - λ₀
        H_norm = (H - λ₀ * I) / Δ
        return 2 * ρ * H_norm - ρ * I
    else
        return H
    end
end


function random_state_vector(N; rng = Random.GLOBAL_RNG)
    Ψ = rand(rng, N) .* exp.((2π * im) .* rand(rng, N))
    Ψ ./= norm(Ψ)
    return Ψ
end


"""Set up a dummy control problem.

```julia
problem = dummy_control_problem(;
    N=10, n_trajectories=1, n_controls=1, n_steps=50, dt=1.0, density=0.5,
    complex_operators=true, hermitian=true, pulses_as_controls=false, rng,
    kwargs...)
```

Sets up a control problem with random (sparse) Hermitian matrices.

# Arguments

* `N`: The dimension of the Hilbert space
* `n_trajectories`: The number of trajectories in the optimization. All
  trajectories will have the same Hamiltonian, but random initial and target
  states.
* `n_controls`: The number of controls, that is, the number of control terms in
  the control Hamiltonian. Each control is an array of random values,
  normalized on the intervals of the time grid.
* `n_steps`: The number of time steps (intervals of the time grid)
* `dt`: The time step
* `density`: The density of the Hamiltonians, as a number between 0.0 and
  1.0. For `density=1.0`, the Hamiltonians will be dense matrices.
* `complex_operators`: Whether or not the drift/control operators will be
  complex-valued or real-valued.
* `hermitian`: Whether or not all drift/control operators will be Hermitian
  matrices.
* `pulses_as_controls=false`: If true, directly use pulses (discretized to the
  midpoints of the time grid) as controls, instead of the normal controls
  discretized to the points of the time grid.
* `rng=Random.GLOBAL_RNG`: The random number generator to use. For a given
  `rng`, the random matrices and states are the same as those from
  `random_matrix` and `random_state_vector` in `QuantumControlTestUtils`.
* `kwargs`: All other keyword arguments are passed on to
  `QuantumControl.ControlProblem`
"""
function dummy_control_problem(;
    N = 10,
    n_trajectories = 1,
    n_controls = 1,
    n_steps = 50,
    dt = 1.0,
    density = 0.5,
    complex_operators = true,
    hermitian = true,
    pulses_as_controls = false,
    prop_method = :cheby,
    rng = Random.GLOBAL_RNG,
    kwargs...
)

    tlist = collect(range(0; length = (n_steps + 1), step = dt))
    pulses = [rand(rng, length(tlist) - 1) for l = 1:n_controls]
    for l = 1:n_controls
        # we normalize on the *intervals*, not on the time grid points
        pulses[l] ./= norm(pulses[l])
    end
    if pulses_as_controls
        controls = pulses
    else
        controls = [discretize(pulse, tlist) for pulse in pulses]
    end

    hamiltonian = []
    H_0 = random_matrix(N; rng, density, hermitian, complex = complex_operators)
    push!(hamiltonian, H_0)
    for control ∈ controls
        H_c = random_matrix(N; rng, density, hermitian, complex = complex_operators)
        push!(hamiltonian, (H_c, control))
    end

    trajectories = [
        Trajectory(
            random_state_vector(N; rng),
            tuple(hamiltonian...);
            target_state = random_state_vector(N; rng)
        ) for k = 1:n_trajectories
    ]

    return ControlProblem(
        trajectories,
        tlist;
        pulse_options = Dict(
            control => Dict(:lambda_a => 1.0, :update_shape => t -> 1.0) for
            control in controls
        ),
        prop_method,
        kwargs...
    )
end


"""Result returned by [`optimize_with_dummy_method`](@ref)."""
mutable struct DummyOptimizationResult
    tlist::Vector{Float64}
    iter_start::Int64  # the starting iteration number
    iter_stop::Int64 # the maximum iteration number
    iter::Int64  # the current iteration number
    J_T::Float64  # the current value of the final-time functional J_T
    J_T_prev::Float64  # previous value of J_T
    guess_controls::Vector{Vector{Float64}}
    optimized_controls::Vector{Vector{Float64}}
    converged::Bool
    message::String

    function DummyOptimizationResult(problem)
        tlist = problem.tlist
        controls = get_controls(problem.trajectories)
        iter_start = get(problem.kwargs, :iter_start, 0)
        iter = iter_start
        iter_stop = get(problem.kwargs, :iter_stop, 20)
        guess_controls = [discretize(control, tlist) for control in controls]
        J_T = 0.0
        J_T_prev = 0.0
        optimized_controls = [copy(guess) for guess in guess_controls]
        converged = false
        message = "in progress"
        new(
            tlist,
            iter_start,
            iter_stop,
            iter,
            J_T,
            J_T_prev,
            guess_controls,
            optimized_controls,
            converged,
            message
        )
    end

end

struct DummyOptimizationWrk
    trajectories
    adjoint_trajectories
    kwargs
    controls
    pulses0::Vector{Vector{Float64}}
    pulses1::Vector{Vector{Float64}}
    result
end


function DummyOptimizationWrk(problem)
    trajectories = [traj for traj in problem.trajectories]
    adjoint_trajectories = [adjoint(traj) for traj in problem.trajectories]
    controls = get_controls(trajectories)
    kwargs = Dict(problem.kwargs)
    tlist = problem.tlist
    if haskey(kwargs, :continue_from)
        @info "Continuing previous optimization"
        result = kwargs[:continue_from]
        if !(result isa DummyOptimizationResult)
            result = convert(DummyOptimizationResult, result)
        end
        result.iter_stop = get(problem.kwargs, :iter_stop, 20)
        result.converged = false
        result.message = "in progress"
        pulses0 = [
            discretize_on_midpoints(control, tlist) for control in result.optimized_controls
        ]
    else
        result = DummyOptimizationResult(problem)
        pulses0 = [discretize_on_midpoints(control, tlist) for control in controls]
    end
    pulses1 = [copy(pulse) for pulse in pulses0]
    return DummyOptimizationWrk(
        trajectories,
        adjoint_trajectories,
        kwargs,
        controls,
        pulses0,
        pulses1,
        result,
    )
end

function update_result!(wrk::DummyOptimizationWrk, ϵ⁽ⁱ⁺¹⁾, i::Int64)
    res = wrk.result
    res.J_T_prev = res.J_T
    res.J_T = sum([norm(ϵ) for ϵ ∈ ϵ⁽ⁱ⁺¹⁾])
    (i > 0) && (res.iter = i)
    if i >= res.iter_stop
        res.converged = true
        res.message = "Reached maximum number of iterations"
    end
end


"""Run a dummy optimization.

```julia
result = optimize(problem, method=:dummymethod)
```

runs through and "optimization" of the given `problem` where in each iteration,
the amplitude of the guess pulses is diminished by 10%. The (summed) vector
norm of the the control serves as the value of the optimization functional.
"""
function optimize_with_dummy_method(problem)
    # This is connected to the main `optimize` method in the main
    # QuantumControl.jl
    iter_start = get(problem.kwargs, :iter_start, 0)
    check_convergence! = get(problem.kwargs, :check_convergence, res -> res)
    wrk = DummyOptimizationWrk(problem)
    ϵ⁽ⁱ⁾ = wrk.pulses0
    ϵ⁽ⁱ⁺¹⁾ = wrk.pulses1
    update_result!(wrk, ϵ⁽ⁱ⁺¹⁾, 0)
    println("# iter\tJ_T")
    @printf("%6d\t%.2e\n", 0, wrk.result.J_T)
    i = wrk.result.iter  # = 0, unless continuing from previous optimization
    while !wrk.result.converged
        i = i + 1
        for l = 1:length(ϵ⁽ⁱ⁺¹⁾)
            ϵ⁽ⁱ⁺¹⁾[l] .= 0.9 * ϵ⁽ⁱ⁾[l]
        end
        update_result!(wrk, ϵ⁽ⁱ⁺¹⁾, i)
        @printf("%6d\t%.2e\n", i, wrk.result.J_T)
        check_convergence!(wrk.result)
        ϵ⁽ⁱ⁾, ϵ⁽ⁱ⁺¹⁾ = ϵ⁽ⁱ⁺¹⁾, ϵ⁽ⁱ⁾
    end
    for l = 1:length(ϵ⁽ⁱ⁾)
        wrk.result.optimized_controls[l] = discretize(ϵ⁽ⁱ⁾[l], problem.tlist)
    end
    return wrk.result
end


QuantumControl.optimize(problem, method::Val{:dummymethod}) =
    optimize_with_dummy_method(problem)


end
