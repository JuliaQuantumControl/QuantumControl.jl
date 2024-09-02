module PulseParameterizations

export SquareParameterization,
    TanhParameterization,
    TanhSqParameterization,
    LogisticParameterization,
    LogisticSqParameterization,
    ParameterizedAmplitude

using QuantumPropagators.Controls: discretize_on_midpoints
using QuantumPropagators.Amplitudes: ControlAmplitude, ShapedAmplitude

import QuantumPropagators.Controls: evaluate, get_controls
import ..Controls: get_control_deriv


#! format: off


"""Specification for a "time-local" pulse parameterization.

The parameterization is given as a collection of three functions:

* ``a(ϵ(t))``
* ``ϵ(a(t))``
* ``∂a/∂ϵ`` as a function of ``ϵ(t)``.
"""
struct PulseParameterization
    name::String
    a_of_epsilon::Function
    epsilon_of_a::Function
    da_deps_derivative::Function
end


function Base.show(io::IO, p::PulseParameterization)
    print(io, p.name)
end


"""Parameterization a(t) = ϵ²(t), enforcing pulse values ``a(t) ≥ 0``."""
SquareParameterization() = PulseParameterization(
    "SquareParameterization()",
    ϵ -> begin # a_of_epsilon
        a = ϵ^2
    end,
    a -> begin # epsilon_of_a
        a = max(a, 0.0)
        ϵ = √a
    end,
    ϵ -> begin # da_deps_derivative
        ∂a╱∂ϵ = 2ϵ
    end
)


"""Parameterization with a tanh function that enforces `a_min < a(t) < a_max`.
"""
function TanhParameterization(a_min, a_max)

    Δ = a_max - a_min
    Σ = a_max + a_min
    aₚ = eps(1.0)  # 2⋅10⁻¹⁶ (machine precision)
    @assert a_max > a_min

    PulseParameterization(
        "TanhParameterization($a_min, $a_max)",
        ϵ -> begin # a_of_epsilon
            a = tanh(ϵ) * Δ / 2 + Σ / 2
        end,
        a -> begin # epsilon_of_a
            a = clamp(2a / Δ - Σ / Δ, -1 + aₚ, 1 - aₚ)
            ϵ = atanh(a)  # -18.4 < ϵ < 18.4
        end,
        ϵ -> begin # da_deps_derivative
            ∂a╱∂ϵ = (Δ / 2) * sech(ϵ)^2
        end
    )

end


"""Parameterization with a tanh² function that enforces `0 ≤ a(t) < a_max`.
"""
function TanhSqParameterization(a_max)

    aₚ = eps(1.0)  # 2⋅10⁻¹⁶ (machine precision)
    @assert a_max > 0

    PulseParameterization(
        "TanhSqParameterization($a_max)",
        ϵ -> begin # a_of_epsilon
            a = a_max * tanh(ϵ)^2
        end,
        a -> begin # epsilon_of_a
            a = clamp(a / a_max, 0, 1 - aₚ)
            ϵ = atanh(√a)
        end,
        ϵ -> begin # da_deps_derivative
            ∂a╱∂ϵ = 2a_max * tanh(ϵ) * sech(ϵ)^2
        end
    )

end


"""
Parameterization with a Logistic function that enforces `a_min < a(t) < a_max`.
"""
function LogisticParameterization(a_min, a_max; k=1.0)

    Δ = a_max - a_min
    a₀ = eps(0.0)  # 5⋅10⁻³²⁴
    @assert a_max > a_min

    PulseParameterization(
        "LogisticParameterization($a_max, $a_max; k=$k)",
        ϵ -> begin # a_of_epsilon
            a = Δ / (1 + exp(-k * ϵ)) + a_min
        end,
        a -> begin # epsilon_of_a
            a′ = a - a_min
            a = max(a′ / (Δ - a′), a₀)
            ϵ = log(a) / k
        end,
        ϵ -> begin # da_deps_derivative
            e⁻ᵏᵘ = exp(-k * ϵ)
            ∂a╱∂ϵ = Δ * k * e⁻ᵏᵘ / (1 + e⁻ᵏᵘ)^2
        end
    )

end


"""
Parameterization with a Logistic-Square function that enforces `0 ≤ a(t) < a_max`.
"""
function LogisticSqParameterization(a_max; k=1.0)

    a₀ = eps(0.0)  # 5⋅10⁻³²⁴
    @assert a_max > 0

    PulseParameterization(
        "LogisticSqParameterization($a_max; k=$k)",
        ϵ -> begin # a_of_epsilon
            a = a_max * (2 / (1 + exp(-k * ϵ)) - 1)^2
        end,
        a -> begin # epsilon_of_a
            ρ = clamp(a / a_max, 0.0, 1.0)
            a = clamp((2 / (√ρ + 1)) - 1, a₀, 1.0)
            ϵ = -log(a) / k
        end,
        ϵ -> begin # da_deps_derivative
            eᵏᵘ = exp(k * ϵ)
            ∂a╱∂ϵ = 4k * a_max * eᵏᵘ * (eᵏᵘ - 1) / (eᵏᵘ + 1)^3
        end
    )

end


#! format: on


#### ParameterizedAmplitude ####################################################


"""An amplitude determined by a pulse parameterization.

That is, ``a(t) = a(ϵ(t))`` with a bijective mapping between the value of
``a(t)`` and ``ϵ(t)``, e.g. ``a(t) = ϵ^2(t)`` (a [`SquareParameterization`](@ref
SquareParameterization)). Optionally, the amplitude may be multiplied with an
additional shape function, cf. [`ShapedAmplitude`](@ref).


```julia
ampl = ParameterizedAmplitude(control; parameterization)
```

initializes ``a(t) = a(ϵ(t)`` where ``ϵ(t)`` is the `control`, and the mandatory
keyword argument `parameterization` is a [`PulseParameterization`](@ref
PulseParameterization). The `control` must either be a vector of values
discretized to the midpoints of a time grid, or a callable `control(t)`.

```julia
ampl = ParameterizedAmplitude(control; parameterization, shape=shape)
```

initializes ``a(t) = S(t) a(ϵ(t))`` where ``S(t)`` is the given `shape`. It
must be a vector if `control` is a vector, or a callable `shape(t)` if
`control` is a callable.


```julia
ampl = ParameterizedAmplitude(control, tlist; parameterization, shape=shape)
```

discretizes `control` and `shape` (if given) to the midpoints of `tlist` before
initialization.


```julia
ampl = ParameterizedAmplitude(
    amplitude, tlist; parameterization, shape=shape, parameterize=true
)
```

initializes ``ã(t) = S(t) a(t)`` where ``a(t)`` is the input `amplitude`.
First, if `amplitude` is a callable `amplitude(t)`, it is discretized to the
midpoints of `tlist`. Then, a `control` ``ϵ(t)`` is calculated so that ``a(t) ≈
a(ϵ(t))``. Clippling may occur if the values in `amplitude` cannot represented
with the given `parameterization`. Lastly, `ParameterizedAmplitude(control;
parameterization, shape)` is initialized with the calculated `control`.

Note that the `tlist` keyword argument is required when `parameterize=true` is
given, even if `amplitude` is already a vector.
"""
abstract type ParameterizedAmplitude <: ControlAmplitude end

abstract type ShapedParameterizedAmplitude <: ParameterizedAmplitude end

function ParameterizedAmplitude(
    control;
    parameterization::PulseParameterization,
    shape=nothing
)
    if isnothing(shape)
        if control isa Vector{Float64}
            return ParameterizedPulseAmplitude(control, parameterization)
        else
            try
                ϵ_t = control(0.0)
            catch
                error(
                    "A ParameterizedAmplitude control must either be a vector of values or a callable"
                )
            end
            return ParameterizedContinuousAmplitude(control, parameterization)
        end
    else
        if (control isa Vector{Float64}) && (shape isa Vector{Float64})
            return ShapedParameterizedPulseAmplitude(control, shape, parameterization)
        else
            try
                ϵ_t = control(0.0)
            catch
                error(
                    "A ParameterizedAmplitude control must either be a vector of values or a callable"
                )
            end
            try
                S_t = shape(0.0)
            catch
                error(
                    "A ParameterizedAmplitude shape must either be a vector of values or a callable"
                )
            end
            return ShapedParameterizedContinuousAmplitude(control, shape, parameterization)
        end
    end
end


function ParameterizedAmplitude(
    control,
    tlist;
    parameterization::PulseParameterization,
    shape=nothing,
    parameterize=false
)
    control = discretize_on_midpoints(control, tlist)
    if parameterize
        control = parameterization.epsilon_of_a.(control)
    end
    if !isnothing(shape)
        shape = discretize_on_midpoints(shape, tlist)
    end
    return ParameterizedAmplitude(control; parameterization, shape)
end

function Base.show(io::IO, ampl::ParameterizedAmplitude)
    print(
        io,
        "ParameterizedAmplitude(::$(typeof(ampl.control)); parameterization=$(ampl.parameterization))"
    )
end

function Base.show(io::IO, ampl::ShapedParameterizedAmplitude)
    print(
        io,
        "ParameterizedAmplitude(::$(typeof(ampl.control)); parameterization=$(ampl.parameterization), shape::$(typeof(ampl.shape)))"
    )
end

struct ParameterizedPulseAmplitude <: ParameterizedAmplitude
    control::Vector{Float64}
    parameterization::PulseParameterization
end

function Base.Array(ampl::ParameterizedPulseAmplitude)
    return ampl.parameterization.a_of_epsilon.(ampl.control)
end

struct ParameterizedContinuousAmplitude <: ParameterizedAmplitude
    control
    parameterization::PulseParameterization
end

struct ShapedParameterizedPulseAmplitude <: ShapedParameterizedAmplitude
    control::Vector{Float64}
    shape::Vector{Float64}
    parameterization::PulseParameterization
end

struct ShapedParameterizedContinuousAmplitude <: ShapedParameterizedAmplitude
    control
    shape
    parameterization::PulseParameterization
end


function evaluate(ampl::ParameterizedAmplitude, args...; kwargs...)
    ϵ = evaluate(ampl.control, args...; kwargs...)
    return ampl.parameterization.a_of_epsilon(ϵ)
end


function evaluate(ampl::ShapedParameterizedAmplitude, args...; kwargs...)
    ϵ = evaluate(ampl.control, args...; kwargs...)
    S = evaluate(ampl.shape, args...; kwargs...)
    return S * ampl.parameterization.a_of_epsilon(ϵ)
end


function Base.Array(ampl::ShapedParameterizedPulseAmplitude)
    return ampl.shape .* ampl.parameterization.a_of_epsilon.(ampl.control)
end


function get_controls(ampl::ParameterizedAmplitude)
    return (ampl.control,)
end


function get_control_deriv(ampl::ParameterizedAmplitude, control)
    if control ≡ ampl.control
        return ParameterizationDerivative(control, ampl.parameterization.da_deps_derivative)
    else
        return 0.0
    end
end

function get_control_deriv(ampl::ShapedParameterizedPulseAmplitude, control)
    if control ≡ ampl.control
        return ShapedParameterizationPulseDerivative(
            control,
            ampl.parameterization.da_deps_derivative,
            ampl.shape
        )
    else
        return 0.0
    end
end

function get_control_deriv(ampl::ShapedParameterizedContinuousAmplitude, control)
    if control ≡ ampl.control
        return ShapedParameterizationContinuousDerivative(
            control,
            ampl.parameterization.da_deps_derivative,
            ampl.shape
        )
    else
        return 0.0
    end
end


struct ParameterizationDerivative <: ControlAmplitude
    control
    func
end

struct ShapedParameterizationPulseDerivative <: ControlAmplitude
    control::Vector{Float64}
    func
    shape::Vector{Float64}
end

struct ShapedParameterizationContinuousDerivative <: ControlAmplitude
    control
    func
    shape
end

function evaluate(deriv::ParameterizationDerivative, args...; vals_dict=IdDict())
    ϵ = evaluate(deriv.control, args...; vals_dict)
    return deriv.func(ϵ)
end

function evaluate(
    deriv::ShapedParameterizationPulseDerivative,
    tlist,
    n;
    vals_dict=IdDict()
)
    ϵ = evaluate(deriv.control, tlist, n; vals_dict)
    S = evaluate(deriv.shape, tlist, n; vals_dict)
    return S * deriv.func(ϵ)
end

function evaluate(
    deriv::ShapedParameterizationContinuousDerivative,
    tlist,
    n;
    vals_dict=IdDict()
)
    ϵ = evaluate(deriv.control, tlist, n; vals_dict)
    S = evaluate(deriv.shape, tlist, n; vals_dict)
    return S * deriv.func(ϵ)
end

end
