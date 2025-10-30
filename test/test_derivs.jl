using Test
using LinearAlgebra
using QuantumControl.Controls: get_control_deriv, get_control_derivs
using QuantumPropagators.Generators
using QuantumPropagators.Controls
using QuantumPropagators: Generator, Operator
using QuantumControlTestUtils.RandomObjects: random_matrix, random_state_vector
using QuantumControl.Interfaces: check_generator, check_amplitude
using QuantumPropagators.Amplitudes: LockedAmplitude, ShapedAmplitude
import QuantumPropagators
import QuantumControl


_AT(::Generator{OT,AT}) where {OT,AT} = AT


struct MySquareAmpl
    control::Function
end


struct MyScaledAmpl
    c::Number
    control::Function
end


function QuantumControl.Controls.get_control_deriv(a::MySquareAmpl, control)
    if control ≡ a.control
        return MyScaledAmpl(2.0, control)
    else
        return 0.0
    end
end


QuantumPropagators.Controls.get_controls(a::MySquareAmpl) = (a.control,)

QuantumPropagators.Controls.get_controls(a::MyScaledAmpl) = (a.control,)


function QuantumPropagators.Controls.evaluate(a::MySquareAmpl, args...; kwargs...)
    v = evaluate(a.control, args...; kwargs...)
    return v^2
end


function QuantumPropagators.Controls.evaluate(
    a::MyScaledAmpl,
    args...;
    vals_dict = IdDict()
)
    return a.c * evaluate(a.control, args...; vals_dict)
end


@testset "Standard get_control_derivs" begin
    H₀ = random_matrix(5; hermitian = true)
    H₁ = random_matrix(5; hermitian = true)
    H₂ = random_matrix(5; hermitian = true)
    ϵ₁ = t -> 1.0
    ϵ₂ = t -> 1.0
    H = (H₀, (H₁, ϵ₁), (H₂, ϵ₂))

    @test get_control_deriv(ϵ₁, ϵ₁) == 1.0
    @test get_control_deriv(ϵ₁, ϵ₂) == 0.0

    derivs = get_control_derivs(H₀, (ϵ₁, ϵ₂))
    @test all(isnothing.(derivs))

    derivs = get_control_derivs(H, (ϵ₁, ϵ₂))
    @test derivs[1] isa Matrix{ComplexF64}
    @test derivs[2] isa Matrix{ComplexF64}
    @test norm(derivs[1] - H₁) < 1e-14
    @test norm(derivs[2] - H₂) < 1e-14

    for deriv in derivs
        O = evaluate(deriv; vals_dict = IdDict(ϵ₁ => 1.1, ϵ₂ => 2.0))
        @test O ≡ deriv
    end

    @test isnothing(get_control_deriv(H, t -> 3.0))

    Ψ = random_state_vector(5)
    tlist = collect(range(0, 10; length = 101))
    @test check_generator(H; state = Ψ, tlist, for_gradient_optimization = true)

end


@testset "Nonlinear get_control_derivs" begin

    H₀ = random_matrix(5; hermitian = true)
    H₁ = random_matrix(5; hermitian = true)
    H₂ = random_matrix(5; hermitian = true)
    ϵ₁ = t -> 1.0
    ϵ₂ = t -> 1.0
    H = (H₀, (H₁, MySquareAmpl(ϵ₁)), (H₂, MySquareAmpl(ϵ₂)))

    derivs = get_control_derivs(H, (ϵ₁, ϵ₂))
    @test derivs[1] isa Generator
    @test derivs[2] isa Generator
    @test derivs[1].ops[1] ≡ H₁
    @test _AT(derivs[1]) ≡ MyScaledAmpl

    O₁ = evaluate(derivs[1]; vals_dict = IdDict(ϵ₁ => 1.1, ϵ₂ => 2.0))
    @test O₁ isa Operator
    @test length(O₁.ops) == length(O₁.coeffs) == 1
    @test O₁.ops[1] ≡ H₁
    @test O₁.coeffs[1] ≈ (2 * 1.1)

    O₂ = evaluate(derivs[2]; vals_dict = IdDict(ϵ₁ => 1.1, ϵ₂ => 2.0))
    @test O₂ isa Operator
    @test length(O₂.ops) == length(O₂.coeffs) == 1
    @test O₂.ops[1] ≡ H₂
    @test O₂.coeffs[1] ≈ (2 * 2.0)

    @test isnothing(get_control_deriv(H, t -> 3.0))

    Ψ = random_state_vector(5)
    tlist = collect(range(0, 10; length = 101))
    @test check_amplitude(H[2][2]; tlist)
    @test check_amplitude(H[3][2]; tlist)
    @test check_generator(H; state = Ψ, tlist, for_gradient_optimization = true)

end


@testset "LockedAmplitude  get_control_derivs" begin

    shape(t) = 1.0
    tlist = [0.0, 0.5, 1.0]

    ampl1 = LockedAmplitude(shape)
    ampl2 = LockedAmplitude(shape, tlist)

    @test get_control_deriv(ampl1, t -> 0.0) == 0.0
    @test get_control_deriv(ampl1, shape) == 0.0

    @test get_control_deriv(ampl2, t -> 0.0) == 0.0
    @test get_control_deriv(ampl2, shape) == 0.0

end


@testset "ShapedAmplitude  get_control_derivs" begin

    shape(t) = 1.0
    control(t) = 0.5
    tlist = [0.0, 0.5, 1.0]

    ampl1 = ShapedAmplitude(control; shape)
    ampl2 = ShapedAmplitude(control, tlist; shape)

    @test get_control_deriv(ampl1, t -> 0.0) == 0.0
    @test get_control_deriv(ampl1, shape) == 0.0
    @test get_control_deriv(ampl1, control) == LockedAmplitude(shape)

    @test get_control_deriv(ampl2, t -> 0.0) == 0.0
    @test get_control_deriv(ampl2, shape) == 0.0
    control2 = get_controls(ampl2)[1]
    @test control2 ≢ control  # should have been discretized
    @test ampl2.shape ≢ shape  # should have been discretized
    @test control2 isa Vector{Float64}
    @test ampl2.shape isa Vector{Float64}
    @test get_control_deriv(ampl2, control2) == LockedAmplitude(ampl2.shape)

end
