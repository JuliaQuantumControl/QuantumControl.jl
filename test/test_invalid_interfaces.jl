using Test
using Logging: with_logger
using LinearAlgebra: I
using QuantumPropagators
using QuantumControlTestUtils: QuantumTestLogger
using QuantumControlTestUtils.RandomObjects: random_matrix, random_state_vector
using QuantumControl.Interfaces: check_generator


import QuantumPropagators.Controls: get_controls, evaluate, evaluate!, substitute

struct InvalidGenerator
    control
end

# Define the methods required for propagation, but not the methods required
# for gradients
get_controls(G::InvalidGenerator) = (G.control,)
evaluate(G::InvalidGenerator, args...) = I(4)
evaluate!(op, G, args...) = op
substitute(G::InvalidGenerator, args...) = G


struct InvalidAmplitude
    control
end

get_controls(a::InvalidAmplitude) = (a.control,)
substitute(a::InvalidAmplitude, args...) = a
evaluate(a::InvalidAmplitude, args...; kwargs...) = evaluate(a.control, args...; kwargs...)


@testset "Invalid generator" begin

    state = ComplexF64[1, 0, 0, 0]
    tlist = collect(range(0, 10, length=101))

    generator = InvalidGenerator(t -> 1.0)

    @test QuantumPropagators.Interfaces.check_generator(generator; state, tlist)

    test_logger = QuantumTestLogger()
    with_logger(test_logger) do
        @test check_generator(generator; state, tlist) ≡ false
    end

    @test "`get_control_derivs(generator, controls)` must be defined" ∈ test_logger
    @test "`get_control_deriv(generator, control)` must return `nothing` if `control` is not in `get_controls(generator)`" ∈
          test_logger

end


@testset "Invalid amplitudes" begin

    N = 5
    state = random_state_vector(N)
    tlist = collect(range(0, 10, length=101))

    H₀ = random_matrix(5; hermitian=true)
    H₁ = random_matrix(5; hermitian=true)
    ampl = InvalidAmplitude(t -> 1.0)

    @test QuantumPropagators.Interfaces.check_amplitude(ampl; tlist)

    H = hamiltonian(H₀, (H₁, ampl))

    @test QuantumPropagators.Interfaces.check_generator(H; state, tlist)

    test_logger = QuantumTestLogger()
    with_logger(test_logger) do
        @test check_generator(H; state, tlist) ≡ false
    end

    @test "get_control_deriv(ampl, control) must be defined" ∈ test_logger

end
