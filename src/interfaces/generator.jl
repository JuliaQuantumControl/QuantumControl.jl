using QuantumPropagators
using QuantumPropagators.Generators: Generator
using QuantumControl.Controls: get_controls, get_control_derivs, get_control_deriv
using Test


"""Check the dynamical `generator` in the context of optimal control

```
@test check_generator(generator; state, tlist,
                     for_mutable_state=true, for_immutable_state=true,
                     for_expval=true, for_gradient_optimization=true,
                     atol=1e-15)
```

verifies the given `generator`. This checks all the conditions of
[`QuantumPropagators.Interfaces.check_generator`](@ref). In addition, the
following conditions must be met.

If `for_gradient_optimization`:

* `get_control_derivs(generator, controls)` must be defined and return a vector
  containing the result of `get_control_deriv(generator, control)` for every
  `control` in `controls`.
* `get_control_deriv(generator, control)` must return an object that passes the
  simpler [`QuantumPropagators.Interfaces.check_generator`](@ref) if `control`
  is in `get_controls(generator)`.
* `get_control_deriv(generator, control)` must return `nothing` if `control` is
  not in `get_controls(generator)`
* If `generator` is a [`Generator`](@ref) instance, for every `ampl` in
  `generator.amplitudes`, a function `get_control_deriv(ampl, control)` must be
  defined
* If `ampl` does not depend on `control`, the function `get_control_deriv(ampl,
  control)` must return `0.0`
* Otherwise, `get_control_deriv(ampl, control)` must return an object `u` so
  that `evaluate(u, tlist, n)` returns a Number. In most cases, `u` itself will
  be a Number.
"""
function check_generator(
    generator;
    state,
    tlist,
    for_mutable_state=true,
    for_immutable_state=true,
    for_expval=true,
    for_gradient_optimization=true,
    atol=1e-15
)

    success = QuantumPropagators.Interfaces.check_generator(
        generator;
        state,
        tlist,
        for_mutable_state,
        for_immutable_state,
        for_expval,
        atol
    )

    if for_gradient_optimization

        try
            controls = get_controls(generator)
            control_derivs = get_control_derivs(generator, controls)
            if !(control_derivs isa Vector)
                @error "`get_control_derivs(generator, controls)` must return a Vector"
                success = false
            end
            if length(control_derivs) ≠ length(controls)
                @error "`get_control_derivs(generator, controls)` must return a derivative for every `control` in `controls`"
                success = false
            end
            # In general, we can't check for equality between
            # `get_control_deriv` and `get_control_deriv`, because `==` may not
            # be implemented to compare arbitrary generators by value
        catch exc
            @error "`get_control_derivs(generator, controls)` must be defined: $exc"
            success = false
        end

        try
            controls = get_controls(generator)
            for (i, control) in enumerate(controls)
                deriv = get_control_deriv(generator, control)
                valid_deriv = check_generator(
                    deriv;
                    state,
                    tlist,
                    for_mutable_state,
                    for_immutable_state,
                    for_expval,
                    atol,
                    for_gradient_optimization=false
                )
                if !valid_deriv
                    @error "the result of `get_control_deriv(generator, control)` for control $i is not a valid generator"
                    success = false
                end
            end
        catch exc
            @error "`get_control_deriv(generator, control)` must be defined: $exc"
            success = false
        end

        try
            controls = get_controls(generator)
            dummy_control_CYRmE(t) = rand()
            @assert dummy_control_CYRmE ∉ controls
            deriv = get_control_deriv(generator, dummy_control_CYRmE)
            if deriv ≢ nothing
                @error "`get_control_deriv(generator, control)` must return `nothing` if `control` is not in `get_controls(generator)`, not $(repr(deriv))"
                success = false
            end
        catch exc
            @error "`get_control_deriv(generator, control)` must return `nothing` if `control` is not in `get_controls(generator)`: $exc"
            success = false
        end

        if generator isa Generator
            controls = get_controls(generator)
            dummy_control_aSQeB(t) = rand()
            @assert dummy_control_aSQeB ∉ controls
            for (i, ampl) in enumerate(generator.amplitudes)
                for (j, control) in enumerate(controls)
                    try
                        deriv = get_control_deriv(ampl, control)
                        val = evaluate(deriv, tlist, 1)
                        if !(val isa Number)
                            @error "get_control_deriv(ampl, control) for amplitude $i and control $j must return an object that evaluate to a Number, not $(typeof(val))"
                            success = false
                        end
                    catch exc
                        @error "get_control_deriv(ampl, control) must be defined for amplitude $i and control $j"
                        success = false
                    end
                end
                try
                    deriv = get_control_deriv(ampl, dummy_control_aSQeB)
                    if deriv ≠ 0.0
                        @error "get_control_deriv(ampl, control) for amplitude $i must return 0.0 if it does not depend on `control`, not $(repr(deriv))"
                        success = false
                    end
                catch exc
                    @error "get_control_deriv(ampl, control) must be defined for amplitude $i"
                    success = false
                end
            end
        end

    end

    return success

end
