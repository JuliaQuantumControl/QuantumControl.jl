using Test
using QuantumPropagators: Cheby
using QuantumPropagators.Controls: substitute, get_controls
using QuantumControl: Trajectory, ControlProblem
using QuantumControlTestUtils.RandomObjects: random_state_vector, random_dynamic_generator
using StableRNGs

@testset "ControlProblem instantiation" begin

    rng = StableRNG(3143161816)
    N = 10
    Ψ0 = random_state_vector(N; rng)
    Ψ1 = random_state_vector(N; rng)
    Ψ0_tgt = random_state_vector(N; rng)
    Ψ1_tgt = random_state_vector(N; rng)
    tlist = collect(range(0, 5; length = 101))
    H = random_dynamic_generator(N, tlist)

    problem = ControlProblem(
        [
            Trajectory(Ψ0, H; target_state = Ψ0_tgt, weight = 0.3),
            Trajectory(Ψ1, H; target_state = Ψ1_tgt, weight = 0.7),
        ],
        tlist,
        J_T = (Ψ -> 1.0),
        prop_method = Cheby,
        iter_stop = 10,
    )

    @test length(problem.trajectories) == 2
    @test length(get_controls(problem)) == 1
    @test length(problem.kwargs) == 3

    @test endswith(
        summary(problem),
        "ControlProblem with 2 trajectories and 101 time steps"
    )
    repl_repr = repr("text/plain", problem; context = (:limit => true))
    @test contains(repl_repr, "ControlProblem with 2 trajectories and 101 time steps")
    @test contains(
        repl_repr,
        "Trajectory with 10-element Vector{ComplexF64} initial state, Generator with 2 ops and 1 amplitudes, 10-element Vector{ComplexF64} target state, weight=0.3"
    )
    @test contains(
        repl_repr,
        "Trajectory with 10-element Vector{ComplexF64} initial state, Generator with 2 ops and 1 amplitudes, 10-element Vector{ComplexF64} target state, weight=0.7"
    )
    @test contains(repl_repr, ":J_T => ")
    @test contains(repl_repr, "tlist: [0.0, 0.05 … 5.0]")
    @test contains(repl_repr, ":iter_stop => 10")
    @test contains(repl_repr, r":prop_method => .*.Cheby")

    problem = ControlProblem([Trajectory(Ψ0, H; target_state = Ψ0_tgt)], [0.0, 0.1])
    repl_repr = repr("text/plain", problem; context = (:limit => true))
    @test contains(repl_repr, "tlist: [0.0, 0.1]")

end


@testset "ControlProblem substitution" begin

    rng = StableRNG(3143161816)
    N = 10
    Ψ0 = random_state_vector(N; rng)
    Ψ1 = random_state_vector(N; rng)
    Ψ0_tgt = random_state_vector(N; rng)
    Ψ1_tgt = random_state_vector(N; rng)
    tlist = collect(range(0, 5; length = 101))
    ϵ1(t) = 0.0
    ϵ2(t) = 1.0
    H = random_dynamic_generator(N, tlist; amplitudes = [ϵ1])

    problem = ControlProblem(
        [
            Trajectory(Ψ0, H; target_state = Ψ0_tgt, weight = 0.3),
            Trajectory(Ψ1, H; target_state = Ψ1_tgt, weight = 0.7),
        ],
        tlist,
        J_T = (Ψ -> 1.0),
        prop_method = Cheby,
        iter_stop = 10,
    )

    @test get_controls(problem) == (ϵ1,)

    problem2 = substitute(problem, IdDict(ϵ1 => ϵ2))
    @test get_controls(problem2) == (ϵ2,)

end
