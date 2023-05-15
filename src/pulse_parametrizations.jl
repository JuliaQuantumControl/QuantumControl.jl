module PulseParametrizations

export SquareParametrization,
    TanhParametrization,
    TanhSqParametrization,
    LogisticParametrization,
    LogisticSqParametrization,
    ParametrizedAmplitude

using QuantumPropagators.Controls: discretize_on_midpoints
using QuantumPropagators.Amplitudes: ControlAmplitude, ShapedAmplitude

import QuantumPropagators.Controls: evaluate, get_controls
import QuantumControlBase: get_control_deriv


#! format: off


"""Specification for a "time-local" pulse parametrization.

The parametrization is given as a collection of three functions:

* ``a(ϵ(t))``
* ``ϵ(a(t))``
* ``∂a/∂ϵ`` as a function of ``ϵ(t)``.
"""
struct PulseParametrization
    name::String
    a_of_epsilon::Function
    epsilon_of_a::Function
    da_deps_derivative::Function
end


function Base.show(io::IO, p::PulseParametrization)
    print(io, p.name)
end


"""Parametrization a(t) = ϵ²(t), enforcing pulse values ``a(t) ≥ 0``."""
SquareParametrization() = PulseParametrization(
    "SquareParametrization()",
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


"""Parametrization with a tanh function that enforces `a_min < a(t) < a_max`.
"""
function TanhParametrization(a_min, a_max)

    Δ = a_max - a_min
    Σ = a_max + a_min
    aₚ = eps(1.0)  # 2⋅10⁻¹⁶ (machine precision)
    @assert a_max > a_min

    PulseParametrization(
        "TanhParametrization($a_min, $a_max)",
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


"""Parametrization with a tanh² function that enforces `0 ≤ a(t) < a_max`.
"""
function TanhSqParametrization(a_max)

    aₚ = eps(1.0)  # 2⋅10⁻¹⁶ (machine precision)
    @assert a_max > 0

    PulseParametrization(
        "TanhSqParametrization($a_max)",
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
Parametrization with a Logistic function that enforces `a_min < a(t) < a_max`.
"""
function LogisticParametrization(a_min, a_max; k=1.0)

    Δ = a_max - a_min
    a₀ = eps(0.0)  # 5⋅10⁻³²⁴
    @assert a_max > a_min

    PulseParametrization(
        "LogisticParametrization($a_max, $a_max; k=$k)",
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
Parametrization with a Logistic-Square function that enforces `0 ≤ a(t) < a_max`.
"""
function LogisticSqParametrization(a_max; k=1.0)

    a₀ = eps(0.0)  # 5⋅10⁻³²⁴
    @assert a_max > 0

    PulseParametrization(
        "LogisticSqParametrization($a_max; k=$k)",
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


#### ParametrizedAmplitude ####################################################


"""An amplitude determined by a pulse parametrization.

That is, ``a(t) = a(ϵ(t))`` with a bijective mapping between the value of
``a(t)`` and ``ϵ(t)``, e.g. ``a(t) = ϵ^2(t)`` (a [`SquareParametrization`](@ref
SquareParametrization)). Optionally, the amplitude may be multiplied with an
additional shape function, cf. [`ShapedAmplitude`](@ref).


```julia
ampl = ParametrizedAmplitude(control; parametrization)
```

initilizes ``a(t) = a(ϵ(t)`` where ``ϵ(t)`` is the `control`, and the mandatory
keyword argument `parametrization` is a [`PulseParametrization`](@ref
PulseParametrization). The `control` must either be a vector of values
discretized to the midpoints of a time grid, or a callable `control(t)`.

```julia
ampl = ParametrizedAmplitude(control; parametrization, shape=shape)
```

initializes ``a(t) = S(t) a(ϵ(t))`` where ``S(t)`` is the given `shape`. It
must be a vector if `control` is a vector, or a callable `shape(t)` if
`control` is a callable.


```julia
ampl = ParametrizedAmplitude(control, tlist; parametrization, shape=shape)
```

discretizes `control` and `shape` (if given) to the midpoints of `tlist` before
initialization.


```julia
ampl = ParametrizedAmplitude(
    amplitude, tlist; parametrization, shape=shape, parametrize=true
)
```

initializes ``ã(t) = S(t) a(t)`` where ``a(t)`` is the input `amplitude`.
First, if `amplitude` is a callable `amplitude(t)`, it is discretized to the
midpoints of `tlist`. Then, a `control` ``ϵ(t)`` is calculated so that ``a(t) ≈
a(ϵ(t))``. Clippling may occur if the values in `amplitude` cannot represented
with the given `parametrization`. Lastly, `ParametrizedAmplitude(control;
parametrization, shape)` is initialized with the calculated `control`.

Note that the `tlist` keyword argument is required when `parametrize=true` is
given, even if `amplitude` is already a vector.
"""
abstract type ParametrizedAmplitude <: ControlAmplitude end

abstract type ShapedParametrizedAmplitude <: ParametrizedAmplitude end

function ParametrizedAmplitude(
    control;
    parametrization::PulseParametrization,
    shape=nothing
)
    if isnothing(shape)
        if control isa Vector{Float64}
            return ParametrizedPulseAmplitude(control, parametrization)
        else
            try
                ϵ_t = control(0.0)
            catch
                error(
                    "A ParametrizedAmplitude control must either be a vector of values or a callable"
                )
            end
            return ParametrizedContinuousAmplitude(control, parametrization)
        end
    else
        if (control isa Vector{Float64}) && (shape isa Vector{Float64})
            return ShapedParametrizedPulseAmplitude(control, shape)
        else
            try
                ϵ_t = control(0.0)
            catch
                error(
                    "A ParametrizedAmplitude control must either be a vector of values or a callable"
                )
            end
            try
                S_t = shape(0.0)
            catch
                error(
                    "A ParametrizedAmplitude shape must either be a vector of values or a callable"
                )
            end
            return ShapedParametrizedContinuousAmplitude(control, shape)
        end
    end
end


function ParametrizedAmplitude(
    control,
    tlist;
    parametrization::PulseParametrization,
    shape=nothing,
    parameterize=false
)
    control = discretize_on_midpoints(control, tlist)
    if parameterize
        control = parametrization.epsilon_of_a.(control)
    end
    if !isnothing(shape)
        shape = discretize_on_midpoints(shape, tlist)
    end
    return ParametrizedAmplitude(control; parametrization, shape)
end

function Base.show(io::IO, ampl::ParametrizedAmplitude)
    print(
        io,
        "ParametrizedAmplitude(::$(typeof(ampl.control)); parametrization=$(ampl.parametrization))"
    )
end

function Base.show(io::IO, ampl::ShapedParametrizedAmplitude)
    print(
        io,
        "ParametrizedAmplitude(::$(typeof(ampl.control)); parametrization=$(ampl.parametrization), shape::$(typeof(ampl.shape)))"
    )
end

struct ParametrizedPulseAmplitude <: ParametrizedAmplitude
    control::Vector{Float64}
    parametrization::PulseParametrization
end

function Base.Array(ampl::ParametrizedPulseAmplitude)
    return ampl.parametrization.a_of_epsilon.(ampl.control)
end

struct ParametrizedContinuousAmplitude <: ParametrizedAmplitude
    control
    parametrization::PulseParametrization
end

struct ShapedParametrizedPulseAmplitude <: ShapedParametrizedAmplitude
    control::Vector{Float64}
    shape::Vector{Float64}
    parametrization::PulseParametrization
end

struct ShapedParametrizedContinuousAmplitude <: ShapedParametrizedAmplitude
    control
    shape
    parametrization::PulseParametrization
end


function evaluate(ampl::ParametrizedAmplitude, args...; kwargs...)
    ϵ = evaluate(ampl.control, args...; kwargs...)
    return ampl.parametrization.a_of_epsilon(ϵ)
end


function evaluate(ampl::ShapedParametrizedAmplitude, args...; kwargs...)
    ϵ = evaluate(ampl.control, args...; kwargs...)
    S = evaluate(ampl.shape, args...; kwargs...)
    return S * ampl.parametrization.a_of_epsilon(ϵ)
end


function Base.Array(ampl::ShapedParametrizedPulseAmplitude)
    return ampl.shape .* ampl.parametrization.a_of_epsilon.(ampl.control)
end


function get_controls(ampl::ParametrizedAmplitude)
    return (ampl.control,)
end


function get_control_deriv(ampl::ParametrizedAmplitude, control)
    if control ≡ ampl.control
        return ParametrizationDerivative(control, ampl.parametrization.da_deps_derivative)
    else
        return 0.0
    end
end

function get_control_deriv(ampl::ShapedParametrizedPulseAmplitude, control)
    if control ≡ ampl.control
        return ShapedParametrizationPulseDerivative(
            control,
            ampl.parametrization.da_deps_derivative,
            ampl.shape
        )
    else
        return 0.0
    end
end

function get_control_deriv(ampl::ShapedParametrizedContinuousAmplitude, control)
    if control ≡ ampl.control
        return ShapedParametrizationContinuousDerivative(
            control,
            ampl.parametrization.da_deps_derivative,
            ampl.shape
        )
    else
        return 0.0
    end
end


struct ParametrizationDerivative <: ControlAmplitude
    control
    func
end

struct ShapedParametrizationPulseDerivative <: ControlAmplitude
    control::Vector{Float64}
    func
    shape::Vector{Float64}
end

struct ShapedParametrizationContinuousDerivative <: ControlAmplitude
    control
    func
    shape
end

function evaluate(deriv::ParametrizationDerivative, args...; vals_dict=IdDict())
    ϵ = evaluate(deriv.control, args...; vals_dict)
    return deriv.func(ϵ)
end

function evaluate(deriv::ShapedParametrizationPulseDerivative, tlist, n; vals_dict=IdDict())
    ϵ = evaluate(deriv.control, tlist, n; vals_dict)
    S = evaluate(deriv.shape, tlist, n; vals_dict)
    return S * deriv.func(ϵ)
end

function evaluate(
    deriv::ShapedParametrizationContinuousDerivative,
    tlist,
    n;
    vals_dict=IdDict()
)
    ϵ = evaluate(deriv.control, tlist, n; vals_dict)
    S = evaluate(deriv.shape, tlist, n; vals_dict)
    return S * deriv.func(ϵ)
end

end
