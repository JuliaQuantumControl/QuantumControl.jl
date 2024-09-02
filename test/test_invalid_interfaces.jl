using Test
using Logging: with_logger
using LinearAlgebra: I
using QuantumPropagators
using QuantumControl: hamiltonian
using QuantumControlTestUtils.RandomObjects: random_matrix, random_state_vector
using QuantumControl.Interfaces: check_generator, check_amplitude
using IOCapture

import QuantumControl.Controls:
    get_control_deriv,
    get_controls,
    evaluate,
    evaluate!,
    substitute,
    discretize_on_midpoints

struct InvalidGenerator
    control
end

# Define the methods required for propagation, but not the methods required
# for gradients
get_controls(G::InvalidGenerator) = (G.control,)
evaluate(G::InvalidGenerator, args...; kwargs...) = I(4)
evaluate!(op, G, args...; kwargs...) = op
substitute(G::InvalidGenerator, args...) = G


struct InvalidAmplitude
    control
end

get_controls(a::InvalidAmplitude) = (a.control,)
substitute(a::InvalidAmplitude, args...) = a
evaluate(a::InvalidAmplitude, args...; kwargs...) = evaluate(a.control, args...; kwargs...)


struct InvalidAmplitudeNonPreserving
    control
end

function InvalidAmplitudeNonPreserving(control, tlist)
    pulse = discretize_on_midpoints(control, tlist)
    InvalidAmplitudeNonPreserving(pulse)
end

get_controls(a::InvalidAmplitudeNonPreserving) = (a.control,)
substitute(a::InvalidAmplitudeNonPreserving, args...) = a
evaluate(a::InvalidAmplitudeNonPreserving, args...; kwargs...) =
    evaluate(a.control, args...; kwargs...)
function get_control_deriv(a::InvalidAmplitudeNonPreserving, control)
    if control ≡ a.control
        if a.control isa Function
            return InvalidAmplitudeNonPreserving(t -> a.control(t))
        else
            return InvalidAmplitudeNonPreserving(copy(a.control))
        end
        # The `copy` above is the "non-preserving" problematic behavior
    else
        return 0.0
    end
end


struct InvalidAmplitudeWrongDeriv
    control
end

get_controls(a::InvalidAmplitudeWrongDeriv) = (a.control,)
substitute(a::InvalidAmplitudeWrongDeriv, args...) = a
evaluate(a::InvalidAmplitudeWrongDeriv, args...; kwargs...) =
    evaluate(a.control, args...; kwargs...)
get_control_deriv(::InvalidAmplitudeWrongDeriv, control) = nothing


@testset "Invalid generator" begin

    state = ComplexF64[1, 0, 0, 0]
    tlist = collect(range(0, 10, length=101))

    generator = InvalidGenerator(t -> 1.0)

    @test QuantumPropagators.Interfaces.check_generator(generator; state, tlist)

    captured = IOCapture.capture(rethrow=Union{}, passthrough=false) do
        check_generator(generator; state, tlist)
    end
    @test captured.value ≡ false
    @test contains(
        captured.output,
        "`get_control_derivs(generator, controls)` must be defined"
    )
    @test contains(
        captured.output,
        "`get_control_deriv(generator, control)` must return `nothing` if `control` is not in `get_controls(generator)`"
    )

    H₀ = random_matrix(4; hermitian=true)
    H₁ = random_matrix(4; hermitian=true)
    ampl = InvalidAmplitudeNonPreserving(t -> 1.0)
    generator = hamiltonian(H₀, (H₁, ampl))
    captured = IOCapture.capture(rethrow=Union{}, passthrough=false) do
        check_generator(generator; state, tlist)
    end
    @test captured.value ≡ false
    @test contains(
        captured.output,
        "must return an object `D` so that `get_controls(D)` is a subset of `get_controls(generator)`"
    )

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

    captured = IOCapture.capture(rethrow=Union{}, passthrough=false) do
        check_generator(H; state, tlist)
    end
    @test captured.value ≡ false
    @test contains(captured.output, "get_control_deriv(ampl, control) must be defined")

    ampl = InvalidAmplitudeWrongDeriv(t -> 1.0)
    captured = IOCapture.capture(rethrow=Union{}, passthrough=false) do
        check_amplitude(ampl; tlist)
    end
    @test contains(
        captured.output,
        "get_control_deriv(ampl, control) for  control 1 must return an object that evaluates to a Number"
    )
    @test contains(
        captured.output,
        "get_control_deriv(ampl, control) must return 0.0 if it does not depend on `control`"
    )

    ampl = InvalidAmplitudeNonPreserving(t -> 1.0, tlist)
    deriv = get_control_deriv(ampl, ampl.control)
    @test get_controls(ampl)[1] ≢ get_controls(deriv)[1]  # This is the "bug"
    captured = IOCapture.capture(rethrow=Union{}, passthrough=false) do
        check_amplitude(ampl; tlist)
    end
    @test contains(
        captured.output,
        "must return an object `u` so that `get_controls(u)` is a subset of `get_controls(ampl)`"
    )
    @test captured.value ≡ false

end
