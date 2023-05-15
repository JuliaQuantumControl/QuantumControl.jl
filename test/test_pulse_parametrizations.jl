using Test
using LinearAlgebra
using QuantumControl: hamiltonian
using QuantumControlTestUtils.RandomObjects: random_matrix
using QuantumControl.PulseParametrizations: SquareParametrization, ParametrizedAmplitude
using QuantumControl.Controls: get_controls, evaluate


@testset "Instantiate ParametrizedAmplitude" begin

    # See https://github.com/orgs/JuliaQuantumControl/discussions/42
    # https://github.com/JuliaQuantumControl/QuantumControl.jl/issues/43

    N = 10

    H0 = random_matrix(N; hermitian=true)
    H1 = random_matrix(N; hermitian=true)
    H2 = random_matrix(N; hermitian=true)

    ϵ(t) = 0.5
    a = ParametrizedAmplitude(ϵ; parametrization=SquareParametrization())
    @test get_controls(a) == (ϵ,)

    H = hamiltonian(H0, (H1, ϵ), (H2, a); check=false)
    @test get_controls(H) == (ϵ,)

    @test norm(Array(evaluate(H, 0.0)) - (H0 + 0.5 * H1 + 0.5^2 * H2)) < 1e-12

end
