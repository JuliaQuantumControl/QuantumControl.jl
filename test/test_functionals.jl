using Test
using LinearAlgebra
using QuantumControl.Functionals
using QuantumControl.Functionals: chi_re!, chi_sm!, chi_ss!
using QuantumControlTestUtils.RandomObjects: random_state_vector
using QuantumControlTestUtils.DummyOptimization: dummy_control_problem


N_HILBERT = 10
N = 4
L = 2
N_T = 50
PROBLEM = dummy_control_problem(; N=N_HILBERT, n_objectives=N, n_controls=L, n_steps=N_T)


@testset "functionals-tau-no-tau" begin

    # Test that the various chi routines give the same result whether they are
    # called with ϕ states or with τ values

    objectives = PROBLEM.objectives
    χ1 = [similar(obj.initial_state) for obj in objectives]
    χ2 = [similar(obj.initial_state) for obj in objectives]
    ϕ = [random_state_vector(N_HILBERT) for k = 1:N]
    τ = [obj.target_state ⋅ ϕ[k] for (k, obj) in enumerate(objectives)]

    @test J_T_re(ϕ, objectives) ≈ J_T_re(nothing, objectives; τ)
    chi_re!(χ1, ϕ, objectives)
    chi_re!(χ2, ϕ, objectives; τ=τ)
    @test maximum(norm.(χ1 .- χ2)) < 1e-12

    @test J_T_sm(ϕ, objectives) ≈ J_T_sm(nothing, objectives; τ)
    chi_sm!(χ1, ϕ, objectives)
    chi_sm!(χ2, ϕ, objectives; τ=τ)
    @test maximum(norm.(χ1 .- χ2)) < 1e-12

    @test J_T_ss(ϕ, objectives) ≈ J_T_ss(nothing, objectives; τ)
    chi_ss!(χ1, ϕ, objectives)
    chi_ss!(χ2, ϕ, objectives; τ=τ)
    @test maximum(norm.(χ1 .- χ2)) < 1e-12

end
