using Test
using Logging: with_logger
using LinearAlgebra: I
using QuantumPropagators
using QuantumControlTestUtils: QuantumTestLogger
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
