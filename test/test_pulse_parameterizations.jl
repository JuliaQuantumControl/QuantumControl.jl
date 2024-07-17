using Test
using LinearAlgebra
using QuantumControl: QuantumControl, ControlProblem, hamiltonian, optimize, Trajectory
using QuantumControlTestUtils.RandomObjects: random_matrix
using QuantumControl.Controls: substitute
using QuantumControl.Shapes: flattop
using QuantumPropagators: ExpProp
using QuantumControl.PulseParameterizations:
    ParameterizedAmplitude,
    SquareParameterization,
    TanhParameterization,
    TanhSqParameterization,
    LogisticParameterization,
    LogisticSqParameterization
using QuantumControl.Controls: get_controls, evaluate, discretize
using Krotov
using IOCapture


@testset "Instantiate ParameterizedAmplitude" begin

    # See https://github.com/orgs/JuliaQuantumControl/discussions/42
    # https://github.com/JuliaQuantumControl/QuantumControl.jl/issues/43

    N = 10

    H0 = random_matrix(N; hermitian=true)
    H1 = random_matrix(N; hermitian=true)
    H2 = random_matrix(N; hermitian=true)

    ϵ(t) = 0.5
    a = ParameterizedAmplitude(ϵ; parameterization=SquareParameterization())
    @test get_controls(a) == (ϵ,)

    H = hamiltonian(H0, (H1, ϵ), (H2, a); check=false)
    @test get_controls(H) == (ϵ,)

    @test norm(Array(evaluate(H, 0.0)) - (H0 + 0.5 * H1 + 0.5^2 * H2)) < 1e-12

end

@testset "Positive parameterizations" begin

    # See figure at
    # https://juliaquantumcontrol.github.io/QuantumControlExamples.jl/stable/tutorials/krotov_pulse_parameterization/#Positive-(Bounded)-Controls

    u_vals = collect(range(-3, 3, length=101))
    ϵ_vals = collect(range(0, 1, length=101))
    ϵ_max = 1.0

    ϵ_tanhsq = TanhSqParameterization(ϵ_max).a_of_epsilon.(u_vals)
    @test minimum(ϵ_tanhsq) ≈ 0.0
    @test 0.95 < maximum(ϵ_tanhsq) <= 1.0

    ϵ_logsq1 = LogisticSqParameterization(ϵ_max).a_of_epsilon.(u_vals)
    @test minimum(ϵ_logsq1) ≈ 0.0
    @test 0.81 < maximum(ϵ_logsq1) <= 0.83

    ϵ_logsq4 = LogisticSqParameterization(ϵ_max, k=4.0).a_of_epsilon.(u_vals)
    @test minimum(ϵ_logsq4) ≈ 0.0
    @test 0.95 < maximum(ϵ_logsq4) <= 1.0

    ϵ_sq = SquareParameterization().a_of_epsilon.(u_vals)
    @test minimum(ϵ_sq) ≈ 0.0
    @test maximum(ϵ_sq) ≈ 9.0

    u_tanhsq = TanhSqParameterization(ϵ_max).epsilon_of_a.(ϵ_vals)
    @test u_tanhsq[begin] ≈ 0.0
    @test maximum(u_tanhsq) ≈ u_tanhsq[end]
    @test 18.0 < maximum(u_tanhsq) <= 19.0

    u_logsq1 = LogisticSqParameterization(ϵ_max).epsilon_of_a.(ϵ_vals)
    @test u_logsq1[begin] ≈ 0.0
    @test maximum(u_logsq1) ≈ u_logsq1[end]
    @test 740.0 < maximum(u_logsq1) <= 750.0

    u_logsq4 = LogisticSqParameterization(ϵ_max, k=4.0).epsilon_of_a.(ϵ_vals)
    @test u_logsq4[begin] ≈ 0.0
    @test maximum(u_logsq4) ≈ u_logsq4[end]
    @test 180.0 < maximum(u_logsq4) <= 190.0

    u_sq = SquareParameterization().epsilon_of_a.(ϵ_vals)
    @test u_sq[begin] ≈ 0.0
    @test maximum(u_sq) ≈ u_sq[end]
    @test maximum(u_sq) ≈ 1.0

    d_tanhsq = TanhSqParameterization(ϵ_max).da_deps_derivative.(u_vals)
    @test maximum(d_tanhsq) ≈ -minimum(d_tanhsq)
    @test 0.7 < maximum(d_tanhsq) < 0.8

    d_logsq1 = LogisticSqParameterization(ϵ_max).da_deps_derivative.(u_vals)
    @test maximum(d_logsq1) ≈ -minimum(d_logsq1)
    @test 0.35 < maximum(d_logsq1) < 0.40

    d_logsq4 = LogisticSqParameterization(ϵ_max, k=4.0).da_deps_derivative.(u_vals)
    @test maximum(d_logsq4) ≈ -minimum(d_logsq4)
    @test 1.5 < maximum(d_logsq4) < 1.6

end


@testset "Symmetric parameterizations" begin

    # See figure at
    # https://juliaquantumcontrol.github.io/QuantumControlExamples.jl/stable/tutorials/krotov_pulse_parameterization/#Symmetric-Bounded-Controls

    u_vals = collect(range(-3, 3, length=101))
    ϵ_vals = collect(range(-1, 1, length=101))
    ϵ_min = -1.0
    ϵ_max = 1.0

    ϵ_tanh = TanhParameterization(ϵ_min, ϵ_max).a_of_epsilon.(u_vals)
    @test minimum(ϵ_tanh) ≈ -maximum(ϵ_tanh)
    @test 0.99 <= maximum(ϵ_tanh) <= 1.0

    ϵ_log1 = LogisticParameterization(ϵ_min, ϵ_max).a_of_epsilon.(u_vals)
    @test minimum(ϵ_log1) ≈ -maximum(ϵ_log1)
    @test 0.90 <= maximum(ϵ_log1) <= 0.91

    ϵ_log4 = LogisticParameterization(ϵ_min, ϵ_max, k=4.0).a_of_epsilon.(u_vals)
    @test minimum(ϵ_log4) ≈ -maximum(ϵ_log4)
    @test 0.999 <= maximum(ϵ_log4) <= 1.0

    u_tanh = TanhParameterization(ϵ_min, ϵ_max).epsilon_of_a.(ϵ_vals)
    @test minimum(u_tanh) ≈ -maximum(u_tanh)
    @test 18.0 <= maximum(u_tanh) <= 19.0

    # These diverge to Inf for the maximum:
    u_log1 = LogisticParameterization(ϵ_min, ϵ_max).epsilon_of_a.(ϵ_vals)
    u_log4 = LogisticParameterization(ϵ_min, ϵ_max, k=4.0).epsilon_of_a.(ϵ_vals)

    d_tanh = TanhParameterization(ϵ_min, ϵ_max).da_deps_derivative.(u_vals)
    @test 0.009 < minimum(d_tanh) < 0.010
    @test maximum(d_tanh) ≈ 1.0

    d_log1 = LogisticParameterization(ϵ_min, ϵ_max).da_deps_derivative.(u_vals)
    @test 0.08 < minimum(d_log1) < 0.10
    @test maximum(d_log1) ≈ 0.5

    d_log4 = LogisticParameterization(ϵ_min, ϵ_max, k=4.0).da_deps_derivative.(u_vals)
    @test 4e-5 < minimum(d_log4) < 6e-5
    @test maximum(d_log4) ≈ 2.0

end


@testset "Parameterized optimization" begin

    ϵ(t) = 0.2 * flattop(t, T=5, t_rise=0.3, func=:blackman)

    function tls_hamiltonian(; Ω=1.0, ampl=ϵ)
        σ̂_z = ComplexF64[
            1  0
            0 -1
        ]
        σ̂_x = ComplexF64[
            0  1
            1  0
        ]
        Ĥ₀ = -0.5 * Ω * σ̂_z
        Ĥ₁ = σ̂_x
        return hamiltonian(Ĥ₀, (Ĥ₁, ampl))
    end

    function ket(label)
        result = Dict("0" => Vector{ComplexF64}([1, 0]), "1" => Vector{ComplexF64}([0, 1]),)
        return result[string(label)]
    end

    H = tls_hamiltonian()
    tlist = collect(range(0, 5, length=500))
    trajectories = [Trajectory(ket(0), H; target_state=ket(1))]

    a = ParameterizedAmplitude(
        ϵ,
        tlist;
        parameterization=TanhParameterization(-0.5, 0.5),
        parameterize=true
    )

    problem_tanh = ControlProblem(
        trajectories=substitute(trajectories, IdDict(ϵ => a)),
        prop_method=ExpProp,
        lambda_a=1,
        update_shape=(t -> flattop(t, T=5, t_rise=0.3, func=:blackman)),
        tlist=tlist,
        iter_stop=30,
        J_T=QuantumControl.Functionals.J_T_ss,
    )

    captured = IOCapture.capture(passthrough=false) do
        optimize(problem_tanh; method=Krotov, rethrow_exceptions=true)
    end
    opt_result_tanh = captured.value
    @test opt_result_tanh.iter == 30
    @test 0.15 < opt_result_tanh.J_T < 0.16

    opt_ampl =
        Array(substitute(a, IdDict(a.control => opt_result_tanh.optimized_controls[1])))

    @test -0.5 < minimum(opt_ampl) < -0.4
    @test 0.4 < maximum(opt_ampl) < 0.5

end
