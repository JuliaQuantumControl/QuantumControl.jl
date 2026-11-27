# SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT

using QuantumPropagators.Generators: Generator, Operator, ScaledOperator, _make_generator
using QuantumPropagators.Amplitudes: LockedAmplitude, ShapedAmplitude, GuidedAmplitude
using QuantumPropagators.Controls:
    ParameterizedFunction, StaticParameter, get_parameters, combine_parameters
using QuantumPropagators.ParameterizedFunctions: CRABFunction, VariedFrequencyCRABFunction
import QuantumPropagators.Controls: get_controls, substitute, evaluate


"""Get a vector of the derivatives of `generator` w.r.t. each control.

```julia
get_control_derivs(generator, controls)
```

returns a vector containing the derivative of `generator` with respect to each
control in `controls`, as obtained from [`get_control_deriv`](@ref).
"""
function get_control_derivs(generator, controls)
    controlderivs = []
    for (i, control) in enumerate(controls)
        push!(controlderivs, get_control_deriv(generator, control))
    end
    return [controlderivs...]  # narrow eltype
end

get_control_derivs(operator::AbstractMatrix, controls) = [nothing for c ∈ controls]
get_control_derivs(operator::Operator, controls) = [nothing for c ∈ controls]


@doc raw"""
Get the derivative of the generator ``G`` w.r.t. the control ``ϵ(t)``.

```julia
μ  = get_control_deriv(generator, control)
```

returns `nothing` if the `generator` (Hamiltonian or Liouvillian) does not
depend on `control`, or a generator

```math
μ = \frac{∂G}{∂ϵ(t)}
```

otherwise. For linear control terms, `μ` will be a static operator, e.g. an
`AbstractMatrix` or an [`Operator`](@ref). For non-linear controls, `μ` will be
time-dependent, e.g. a [`Generator`](@ref). In either case,
[`evaluate`](@ref) should be used to evaluate `μ` into a constant operator
for particular values of the controls and a particular point in time.

For constant generators, e.g. an [`Operator`](@ref), the result is always
`nothing`.
"""
function get_control_deriv(generator::Tuple, control)
    return get_control_deriv(_make_generator(generator...), control)
end


function get_control_deriv(generator::Generator, control)
    terms = []
    drift_offset = length(generator.ops) - length(generator.amplitudes)
    for (i, ampl) in enumerate(generator.amplitudes)
        ∂a╱∂ϵ = get_control_deriv(ampl, control)
        if ∂a╱∂ϵ == 0.0
            continue
        elseif ∂a╱∂ϵ == 1.0
            mu_op = generator.ops[i+drift_offset]
            push!(terms, mu_op)
        else
            mu_op = generator.ops[i+drift_offset]
            push!(terms, (mu_op, ∂a╱∂ϵ))
        end
    end
    if length(terms) == 0
        return nothing
    else
        return _make_generator(terms...)
    end
end

@doc raw"""
```julia
a = get_control_deriv(ampl, control)
```

returns the derivative ``∂a_l(t)/∂ϵ_{l'}(t)`` of the given amplitude
``a_l(\{ϵ_{l''}(t)\}, t)`` with respect to the given control ``ϵ_{l'}(t)``. For
"trivial" amplitudes, where ``a_l(t) ≡ ϵ_l(t)``, the result with be either
`1.0` or `0.0` (depending on whether `ampl ≡ control`). For non-trivial
amplitudes, the result may be another amplitude that depends on the controls
and potentially on time, but can be evaluated to a constant with
[`evaluate`](@ref).
"""
get_control_deriv(ampl::Function, control) = (ampl ≡ control) ? 1.0 : 0.0
get_control_deriv(ampl::Vector, control) = (ampl ≡ control) ? 1.0 : 0.0

get_control_deriv(operator::AbstractMatrix, control) = nothing
get_control_deriv(operator::Operator, control) = nothing


# Amplitudes

get_control_deriv(ampl::LockedAmplitude, control) = 0.0

get_control_deriv(ampl::ShapedAmplitude, control) =
    (control ≡ ampl.control) ? LockedAmplitude(ampl.shape) : 0.0

get_control_deriv(ampl::GuidedAmplitude, control) =
    (control ≡ ampl.control) ? LockedAmplitude(ampl.shape) : 0.0


# Parameter derivatives

@doc raw"""
Get the derivative of an object with respect to a single control parameter.

```julia
D = get_parameter_deriv(object, block, i)
```

returns the derivative of a control, an amplitude, or a generator with respect
to the control parameter ``u = `` `block[i]`. A parameter is identified by the
pair `(block, i)` of a [parameter block](@ref ParameterBlocks) (compared with
`===`) and a linear index into that block. The `block` must be a single block
as held by a control or by a custom generator type, e.g., an element of
`get_parameters(object).x`, not the parameters of an object as returned by
[`get_parameters`](@ref); passing the latter throws an `ArgumentError`. Use [`get_parameter_derivs`](@ref) for the
derivatives with respect to all parameters of an object.

The derivative is an object of the same kind as `object`:

| `object`  | Return value                                                                                     |
|:----------|:-------------------------------------------------------------------------------------------------|
| control   | `0.0` if the control does not depend on `block[i]`, otherwise a number, a function of `t` without parameters, or a control that holds `block` |
| amplitude | `0.0`, a number, or an amplitude                                                                 |
| generator | `nothing` if the generator does not depend on `block[i]`, otherwise a static operator or a [`Generator`](@ref) |

These are the conventions of [`get_control_deriv`](@ref). A derivative `D` is
evaluated with [`evaluate`](@ref) with the same arguments as `object`, e.g.,
`evaluate(D, tlist, n; vals_dict)`. It reads the current parameter values when
it is evaluated, so it remains valid while an optimizer mutates the
parameters. A derivative never holds a new parameter block: the derivative of a
control holds the block of the original control, or none at all. Thus,
`get_parameter_deriv` can be applied to a derivative again, to obtain higher
derivatives, if the objects involved support it.

# Implementing parameter derivatives

The author of a [`ParameterizedFunction`](@ref) defines the two-argument method

```julia
get_parameter_deriv(control::MyParameterizedFunction, i)
```

which returns the derivative with respect to `control.parameters[i]`: a number
for a constant derivative (including `0.0`), a function of `t` without
parameters, or a [`ParameterizedFunction`](@ref) that holds the same block,
`control.parameters`, and reads the values from it when it is called. There is
no fallback: a `ParameterizedFunction` without this method raises a
`MethodError`. The two-argument method is for authors only. Consumers always
call the three-argument method, which returns `0.0` unless
`block === control.parameters`.

Everything else is generic: functions that are not a
[`ParameterizedFunction`](@ref), vectors of pulse values, and
[`LockedAmplitude`](@ref) instances have the derivative `0.0`. Any other
amplitude ``a(t)`` uses the chain rule

```math
\frac{∂a(t)}{∂u} = \sum_l \frac{∂a(t)}{∂ϵ_l(t)} \frac{∂ϵ_l(t)}{∂u}
```

over its controls ``ϵ_l(t)`` (as returned by [`get_controls`](@ref)), with
[`get_control_deriv`](@ref) for the first factor. Thus, any amplitude that
supports [`get_control_deriv`](@ref) also supports `get_parameter_deriv`. For a
[`Generator`](@ref) with operators ``Ĥ_i`` and amplitudes ``a_i(t)``, the
derivative is

```math
\frac{∂Ĥ(t)}{∂u} = \sum_i Ĥ_i \frac{∂a_i(t)}{∂u}\,,
```

where a term is dropped if the derivative of its amplitude is `0.0`, and the
operator ``Ĥ_i`` is scaled if that derivative is a number. Static operators
have the derivative `nothing`.

A custom generator type that holds parameter blocks in its own fields (i.e.,
that has a custom [`get_parameters`](@ref) method), or that contains
parameterized controls, must implement the three-argument method itself. That
method recognizes the blocks that it holds by identity (`===`), and applies
the chain rule for the blocks of its controls. Without it, the generic method
raises an error, instead of returning a derivative that is silently zero.

The `get_parameter_deriv` function is meant for setting up a propagation or an
optimization. Call it once and keep the result, instead of calling it
repeatedly. See [Controls and Derivatives](@ref ControlsAndDerivatives) for
details.

# See also

* [`get_parameter_derivs`](@ref) — derivatives with respect to all parameters
* [`QuantumControl.Interfaces.check_control`](@ref) and
  [`QuantumControl.Interfaces.check_generator`](@ref) — verify the derivatives
"""
function get_parameter_deriv end


"""Get a vector of the derivatives of `object` w.r.t. each control parameter.

```julia
derivs = get_parameter_derivs(object, parameters)
```

returns a vector of the same length as `parameters`, where element `n` is the
derivative of `object` (a control, an amplitude, or a generator) with respect
to `parameters[n]`, as obtained from [`get_parameter_deriv`](@ref).

The `parameters` may be the parameters of any object, as returned by
[`get_parameters`](@ref), e.g., of the `object` itself, or of a
[`ControlProblem`](@ref QuantumControl.ControlProblem) that contains `object`,
or a single [parameter block](@ref ParameterBlocks). The function calls
`get_parameter_deriv(object, block, i)` for each element `(block, i)` of the
blocks of `parameters`, which are `parameters.x` for the result of
`get_parameters`. The derivatives with respect to the parameters
in a block that `object` does not hold or inherit are `0.0` for controls and
amplitudes and `nothing` for generators. This includes all parameters of a
*copy* of the parameters, since blocks are identified by `===`.

For example, for a [`ControlProblem`](@ref QuantumControl.ControlProblem),

```julia
u = get_parameters(problem)
for traj in problem.trajectories
    derivs = get_parameter_derivs(traj.generator, u)
    # length(derivs) == length(u)
end
```

The `get_parameter_derivs` function is meant for setting up a propagation or an
optimization. Call it once and keep the result, instead of calling it
repeatedly.
"""
function get_parameter_derivs(object, parameters)
    derivs = []
    for block in combine_parameters(parameters).x
        for i = 1:length(block)
            push!(derivs, get_parameter_deriv(object, block, i))
        end
    end
    return [derivs...]  # narrow eltype
end

function get_parameter_derivs(generator::Tuple, parameters)
    return get_parameter_derivs(_make_generator(generator...), parameters)
end


# Generators

function get_parameter_deriv(generator::Tuple, block, i)
    return get_parameter_deriv(_make_generator(generator...), block, i)
end

function get_parameter_deriv(generator::Generator, block, i)
    terms = []
    drift_offset = length(generator.ops) - length(generator.amplitudes)
    for (k, ampl) in enumerate(generator.amplitudes)
        ∂a╱∂u = get_parameter_deriv(ampl, block, i)
        op = generator.ops[k+drift_offset]
        if ∂a╱∂u isa Number
            if iszero(∂a╱∂u)
                continue
            elseif isone(∂a╱∂u)
                push!(terms, op)
            else
                # A number is not a valid amplitude, so we scale the operator
                push!(terms, ∂a╱∂u * op)
            end
        else
            push!(terms, (op, ∂a╱∂u))
        end
    end
    if length(terms) == 0
        return nothing
    else
        return _make_generator(terms...)
    end
end

get_parameter_deriv(operator::AbstractMatrix, block, i) = nothing
get_parameter_deriv(operator::Operator, block, i) = nothing
get_parameter_deriv(operator::ScaledOperator, block, i) = nothing


# Controls

function get_parameter_deriv(control::ParameterizedFunction, block, i)
    _check_is_block(block)
    if block === getfield(control, :parameters)
        return get_parameter_deriv(control, i)
    else
        return 0.0
    end
end


# Throw an error if `block` is not a single parameter block, e.g., if it is the
# result of `get_parameters`, which is easy to mistake for a block
function _check_is_block(block)
    # An empty block holds no parameters, and `combine_parameters` drops it
    if !isempty(block) && (combine_parameters(block).x !== (block,))
        msg = "The `block` in `get_parameter_deriv(object, block, i)` must be a single parameter block, not the parameters of an object as returned by `get_parameters`. Use `get_parameter_derivs(object, parameters)`, or obtain the blocks as `get_parameters(object).x`."
        throw(ArgumentError(msg))
    end
end

get_parameter_deriv(control::Function, block, i) = 0.0
get_parameter_deriv(control::Vector, block, i) = 0.0
get_parameter_deriv(value::Number, block, i) = 0.0


# Amplitudes

get_parameter_deriv(ampl::LockedAmplitude, block, i) = 0.0

function get_parameter_deriv(ampl, block, i)
    # Chain rule for any amplitude
    controls = []
    for control in get_controls(ampl)
        if control === ampl
            # An object that is its own control, but that has no
            # `get_parameter_deriv` method (e.g., a control that is not a
            # `Function`)
            throw(MethodError(get_parameter_deriv, (ampl, block, i)))
        end
        any(c -> c === control, controls) || push!(controls, control)
    end
    if _holds_block(ampl, block, controls)
        # E.g., a custom generator type with its own `get_parameters`, but
        # without its own `get_parameter_deriv` method
        throw(MethodError(get_parameter_deriv, (ampl, block, i)))
    end
    products = []
    for control in controls
        ∂ϵ╱∂u = get_parameter_deriv(control, block, i)
        _is_zero(∂ϵ╱∂u) && continue
        ∂a╱∂ϵ = get_control_deriv(ampl, control)
        _is_zero(∂a╱∂ϵ) && continue
        if (∂a╱∂ϵ isa Union{Nothing,AbstractMatrix,Operator,Generator})
            msg = "The generic `get_parameter_deriv(ampl, block, i)` applies only to amplitudes, but `get_control_deriv` for an object of type $(typeof(ampl)) returned a generator or operator. A custom generator type must implement its own `get_parameter_deriv(generator, block, i)` method."
            error(msg)
        end
        push!(products, (∂a╱∂ϵ, ∂ϵ╱∂u))
    end
    return _sum_of_products(products)
end


# Whether `object` holds `block` itself, as opposed to inheriting it from
# its `controls` or not containing it at all
function _holds_block(object, block, controls)
    _has_block(parameters) = any(b -> b === block, parameters.x)
    any(control -> _has_block(get_parameters(control)), controls) && return false
    return _has_block(get_parameters(object))
end


_is_zero(x) = (x isa Number) && iszero(x)


# An amplitude that is a sum of products of numbers, controls, and amplitudes,
# as obtained from the chain rule and the product rule. Each element of
# `terms` is a tuple `(c, factors)` of a number `c` and a tuple `factors` of
# controls and amplitudes. Internal: instantiate via `_sum_of_products`.
struct SumOfProductsAmplitude{T<:Tuple}
    terms::T
end


# Product of all factors in each element of `products`, summed. Numbers are
# combined into a coefficient for each term. Returns `0.0` if all terms
# vanish, a number if there is a single term without any factors that are not
# numbers, the single factor if there is a single term with coefficient one,
# and a `SumOfProductsAmplitude` otherwise.
function _sum_of_products(products)
    terms = []
    for product in products
        c = 1.0
        factors = []
        for f in product
            if f isa Number
                c *= f
            else
                push!(factors, f)
            end
        end
        iszero(c) || push!(terms, (c, Tuple(factors)))
    end
    if length(terms) == 0
        return 0.0
    elseif length(terms) == 1
        (c, factors) = terms[1]
        if length(factors) == 0
            return c
        elseif isone(c) && (length(factors) == 1)
            return factors[1]
        end
    end
    return SumOfProductsAmplitude(Tuple(terms))
end


function Base.show(io::IO, ampl::SumOfProductsAmplitude)
    print(io, "SumOfProductsAmplitude(")
    for (k, (c, factors)) in enumerate(ampl.terms)
        (k > 1) && print(io, " + ")
        show(io, c)
        for f in factors
            print(io, " * ")
            show(io, f)
        end
    end
    print(io, ")")
end


# The keyword arguments (`vals_dict`) are forwarded to the factors, so that
# their defaults apply when they are not given
function evaluate(ampl::SumOfProductsAmplitude, args...; kwargs...)
    return _evaluate_terms(ampl.terms, args, kwargs)
end

# Recursion over tuples, for type stability without allocations
_evaluate_terms(::Tuple{}, args, kwargs) = 0.0
function _evaluate_terms(terms::Tuple, args, kwargs)
    (c, factors) = first(terms)
    val = c * _evaluate_factors(factors, args, kwargs)
    return val + _evaluate_terms(Base.tail(terms), args, kwargs)
end

_evaluate_factors(::Tuple{}, args, kwargs) = 1.0
function _evaluate_factors(factors::Tuple, args, kwargs)
    val = evaluate(first(factors), args...; kwargs...)
    return val * _evaluate_factors(Base.tail(factors), args, kwargs)
end


function get_controls(ampl::SumOfProductsAmplitude)
    controls = []
    for (c, factors) in ampl.terms
        for f in factors
            for control in get_controls(f)
                if !any(ϵ -> ϵ === control, controls)
                    push!(controls, control)
                end
            end
        end
    end
    return Tuple(controls)
end


function substitute(ampl::SumOfProductsAmplitude, replacements)
    terms = map(ampl.terms) do (c, factors)
        (c, map(f -> substitute(f, replacements), factors))
    end
    return SumOfProductsAmplitude(terms)
end


function get_control_deriv(ampl::SumOfProductsAmplitude, control)
    # Product rule
    products = []
    for (c, factors) in ampl.terms
        for (j, f) in enumerate(factors)
            ∂f╱∂ϵ = get_control_deriv(f, control)
            _is_zero(∂f╱∂ϵ) && continue
            push!(products, (c, ∂f╱∂ϵ, factors[1:(j-1)]..., factors[(j+1):end]...))
        end
    end
    return _sum_of_products(products)
end


# Static parameters

function get_parameter_deriv(f::StaticParameter, i)
    checkbounds(f.parameters, i)
    return (i == f.index) ? 1.0 : 0.0
end


# CRAB functions

# The derivative of a CRAB function with respect to the coefficient ``c_0`` of
# the guess: a function of `t` without parameters
struct CRABGuessDeriv{G} <: Function
    guess::G
end

(f::CRABGuessDeriv)(t) = f.guess(t)

Base.show(io::IO, f::CRABGuessDeriv) = print(io, "CRABGuessDeriv(", f.guess, ")")


# The derivative of a `CRABFunction` with respect to the coefficient
# ``c^{(±)}_i``: a function of `t` without parameters, ``S(t) cos(ω_i t)`` or
# ``S(t) sin(ω_i t)``
struct CRABBasisFunction{S} <: Function
    shape::S
    ω::Float64
    sine::Bool
end

function (f::CRABBasisFunction)(t)
    val = f.sine ? sin(f.ω * t) : cos(f.ω * t)
    isnothing(f.shape) || (val *= f.shape(t))
    return val
end

function Base.show(io::IO, f::CRABBasisFunction)
    print(io, "CRABBasisFunction(", f.shape, ", ", f.ω, ", sine=", f.sine, ")")
end


# For the parameter with index `j` of a CRAB function, return a tuple
# `(kind, k)` where `kind` is one of `:guess` (``c_0``), `:cos`
# (``c^{(+)}_k``), `:sin` (``c^{(-)}_k``), or `:r` (``r_k``, only for
# `VariedFrequencyCRABFunction`), and `k` is the index of the frequency.
function _crab_parameter(crab, j)
    checkbounds(crab.parameters, j)
    N = length(crab.frequencies)
    if crab.scale_guess && (j == 1)
        return (:guess, 0)
    elseif (crab.parity != :odd) && (crab.i_cos < j <= crab.i_cos + N)
        return (:cos, j - crab.i_cos)
    elseif (crab.parity != :even) && (crab.i_sin < j <= crab.i_sin + N)
        return (:sin, j - crab.i_sin)
    else
        return (:r, j - (length(crab.parameters) - N))
    end
end


function get_parameter_deriv(crab::CRABFunction, j)
    (kind, k) = _crab_parameter(crab, j)
    if kind == :guess
        return CRABGuessDeriv(crab.guess)
    else
        return CRABBasisFunction(crab.shape, crab.frequencies[k], kind == :sin)
    end
end


# The derivative of a `VariedFrequencyCRABFunction` with respect to the
# parameters with the given `indices` (any order). It holds the block of the
# original function, and keeps only the terms for frequency `k`: for a
# derivative w.r.t. a coefficient, only the term of that coefficient
# (`coeff = :cos` or `:sin`), with the coefficient replaced by one. Each of the
# `order` derivatives w.r.t. ``r_k`` multiplies the terms by ``ω_k t`` and
# shifts their phase by ``π/2``. Combinations of indices for which the
# derivative vanishes are not instantiated.
struct VariedFrequencyCRABFunctionDeriv{G,S} <: ParameterizedFunction
    parameters::Vector{Float64}
    crab::VariedFrequencyCRABFunction{G,S}
    indices::Vector{Int64}
    k::Int64
    order::Int64
    coeff::Symbol  # :cos, :sin, :none
end

function Base.show(io::IO, f::VariedFrequencyCRABFunctionDeriv)
    print(io, "VariedFrequencyCRABFunctionDeriv(<crab>, indices=", f.indices, ")")
end


# m'th derivative of cos(x r) w.r.t. r, divided by x^m, at r = 1
function _cos_deriv(x, m)
    m = mod(m, 4)
    if m == 0
        return cos(x)
    elseif m == 1
        return -sin(x)
    elseif m == 2
        return -cos(x)
    else
        return sin(x)
    end
end

# m'th derivative of sin(x r) w.r.t. r, divided by x^m, at r = 1
function _sin_deriv(x, m)
    m = mod(m, 4)
    if m == 0
        return sin(x)
    elseif m == 1
        return cos(x)
    elseif m == 2
        return -sin(x)
    else
        return -cos(x)
    end
end


function (f::VariedFrequencyCRABFunctionDeriv)(t)
    crab = f.crab
    p = f.parameters
    N = length(crab.frequencies)
    k = f.k
    m = f.order
    ωt = crab.frequencies[k] * t
    x = p[end-N+k] * ωt
    if f.coeff == :cos
        val = _cos_deriv(x, m)
    elseif f.coeff == :sin
        val = _sin_deriv(x, m)
    else
        val = 0.0
        (crab.parity != :odd) && (val += p[crab.i_cos+k] * _cos_deriv(x, m))
        (crab.parity != :even) && (val += p[crab.i_sin+k] * _sin_deriv(x, m))
    end
    (m > 0) && (val *= ωt^m)
    isnothing(crab.shape) || (val *= crab.shape(t))
    return val
end


function _varied_frequency_crab_deriv(crab, indices)
    k = 0
    order = 0
    coeff = :none
    for j in indices
        (kind, kj) = _crab_parameter(crab, j)
        if kind == :guess
            # c₀ enters linearly and multiplies only the guess
            return (length(indices) == 1) ? CRABGuessDeriv(crab.guess) : 0.0
        end
        (k == 0) && (k = kj)
        (kj == k) || return 0.0  # two different frequencies
        if kind == :r
            order += 1
        else
            (coeff == :none) || return 0.0  # two coefficients
            coeff = kind
        end
    end
    return VariedFrequencyCRABFunctionDeriv(
        crab.parameters,
        crab,
        sort(indices),
        k,
        order,
        coeff
    )
end


function get_parameter_deriv(crab::VariedFrequencyCRABFunction, j)
    return _varied_frequency_crab_deriv(crab, Int64[j])
end

function get_parameter_deriv(f::VariedFrequencyCRABFunctionDeriv, j)
    return _varied_frequency_crab_deriv(f.crab, Int64[f.indices; j])
end
