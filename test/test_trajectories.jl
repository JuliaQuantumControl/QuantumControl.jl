using Test

using QuantumControl: Trajectory, propagate_trajectory
using QuantumPropagators: Cheby, ExpProp
using QuantumPropagators.Controls: substitute, get_controls
using QuantumControlTestUtils.RandomObjects: random_state_vector, random_dynamic_generator
using StableRNGs
using LinearAlgebra: norm
using IOCapture

using TestingUtilities: @Test  # better for string comparison

@testset "Trajectory instantiation" begin

    rng = StableRNG(3143161815)
    N = 10
    Ψ₀ = random_state_vector(N; rng)
    Ψtgt = random_state_vector(N; rng)
    tlist = [0.0, 1.0]
    H = random_dynamic_generator(N, tlist)

    traj = Trajectory(Ψ₀, H)
    @test startswith(repr(traj), "Trajectory(ComplexF64[")
    repl_repr = repr("text/plain", traj; context=(:limit => true))
    @test contains(repl_repr, "initial_state: 10-element Vector{ComplexF64}")
    @test contains(repl_repr, "generator: Generator with 2 ops and 1 amplitudes")
    @test contains(repl_repr, "target_state: Nothing")
    @test summary(traj) ==
          "Trajectory with 10-element Vector{ComplexF64} initial state, Generator with 2 ops and 1 amplitudes, no target state"

    # with target state
    traj = Trajectory(Ψ₀, H; target_state=Ψtgt)
    @test startswith(repr(traj), "Trajectory(ComplexF64[")
    repl_repr = repr("text/plain", traj; context=(:limit => true))
    @test contains(repl_repr, "target_state: 10-element Vector{ComplexF64}")
    @test summary(traj) ==
          "Trajectory with 10-element Vector{ComplexF64} initial state, Generator with 2 ops and 1 amplitudes, 10-element Vector{ComplexF64} target state"

    # with weight
    traj = Trajectory(Ψ₀, H; weight=0.3)
    @test startswith(repr(traj), "Trajectory(ComplexF64[")
    repl_repr = repr("text/plain", traj; context=(:limit => true))
    @test contains(repl_repr, "weight: 0.3")
    @test summary(traj) ==
          "Trajectory with 10-element Vector{ComplexF64} initial state, Generator with 2 ops and 1 amplitudes, no target state, weight=0.3"

    # with extra data
    traj = Trajectory(
        Ψ₀,
        H;
        weight=0.3,
        note="Note",
        prop_inplace=false,
        prop_method=Cheby,
        prop_specrange_method=:manual
    )
    @test startswith(repr(traj), "Trajectory(ComplexF64[")
    repl_repr = repr("text/plain", traj; context=(:limit => true))
    @test contains(repl_repr, r"prop_method: .*.Cheby")
    @test contains(repl_repr, "note: \"Note\"")
    @test contains(repl_repr, "prop_specrange_method: :manual")
    @test contains(repl_repr, "prop_inplace: false")
    @test summary(traj) ==
          "Trajectory with 10-element Vector{ComplexF64} initial state, Generator with 2 ops and 1 amplitudes, no target state, weight=0.3 and 4 extra kwargs"

    vec = [traj, traj]
    repl_repr = repr("text/plain", vec; context=(:limit => true))
    @test contains(repl_repr, "2-element Vector")
    @test contains(repl_repr, "Trajectory with 10-element Vector{ComplexF64} initial state")

end


@testset "Trajectory substitution" begin

    rng = StableRNG(3143161815)
    N = 10
    Ψ₀ = random_state_vector(N; rng)
    Ψtgt = random_state_vector(N; rng)
    tlist = [0.0, 1.0]
    ϵ1(t) = 0.0
    ϵ2(t) = 1.0
    H = random_dynamic_generator(N, tlist; amplitudes=[ϵ1])

    traj = Trajectory(Ψ₀, H)
    @test get_controls([traj]) == (ϵ1,)
    traj2 = substitute(traj, IdDict(ϵ1 => ϵ2))
    @test get_controls([traj2]) == (ϵ2,)

    trajs = [traj, traj2]
    @test get_controls(trajs) == (ϵ1, ϵ2)
    trajs2 = substitute(trajs, IdDict(ϵ1 => ϵ2))
    @test get_controls(trajs2) == (ϵ2,)

end


@testset "Trajectory propagation" begin

    rng = StableRNG(3143161815)
    N = 10
    Ψ₀ = random_state_vector(N; rng)
    Ψtgt = random_state_vector(N; rng)
    tlist = [0.0, 0.5, 1.0]
    H = random_dynamic_generator(N, tlist)

    traj = Trajectory(Ψ₀, H)
    captured = IOCapture.capture(rethrow=Union{}) do
        propagate_trajectory(traj, tlist)
    end
    @test captured.value isa UndefKeywordError
    @test contains(captured.output, "Cannot initialize propagation for trajectory")
    @test contains(captured.output, "keyword argument `method` not assigned")

    Ψout = propagate_trajectory(traj, tlist, method=Cheby)
    @test Ψout isa Vector{ComplexF64}
    @test abs(1.0 - norm(Ψout)) < 1e-12

    traj = Trajectory(Ψ₀, H; prop_method=Cheby)
    captured = IOCapture.capture(rethrow=Union{}, passthrough=false) do
        propagate_trajectory(traj, tlist; verbose=true)
    end
    Ψout2 = captured.value
    @test norm(Ψout2 - Ψout) < 1e-12
    @test contains(captured.output, "Info: Initializing propagator for trajectory")
    @test contains(captured.output, r":method => .*.Cheby")

end
