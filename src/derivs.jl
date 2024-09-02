using QuantumPropagators.Generators: Generator, Operator, _make_generator, evaluate
using QuantumPropagators.Amplitudes: LockedAmplitude, ShapedAmplitude


"""Get a vector of the derivatives of `generator` w.r.t. each control.

```julia
get_control_derivs(generator, controls)
```

return as vector containing the derivative of `generator` with respect to each
control in `controls`. The elements of the vector are either `nothing` if
`generator` does not depend on that particular control, or a function `μ(α)`
that evaluates the derivative for a particular value of the control, see
[`get_control_deriv`](@ref).
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
