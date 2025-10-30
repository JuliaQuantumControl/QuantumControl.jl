using QuantumPropagators
using QuantumPropagators.Generators: Generator
using QuantumPropagators.Controls: get_controls
using QuantumPropagators.Interfaces: catch_abbreviated_backtrace
using ..Controls: get_control_derivs, get_control_deriv


"""Check the dynamical `generator` in the context of optimal control.

```
@test check_generator(
    generator; state, tlist,
    for_expval=true, for_pwc=true, for_time_continuous=false,
    for_parameterization=false, for_gradient_optimization=true,
    atol=1e-15, quiet=false
)
```

verifies the given `generator`. This checks all the conditions of
[`QuantumPropagators.Interfaces.check_generator`](@ref). In addition, the
following conditions must be met.

If `for_gradient_optimization`:

* [`get_control_derivs(generator, controls)`](@ref get_control_derivs) must be
  defined and return a vector containing the result of
  [`get_control_deriv(generator, control)`](@ref get_control_deriv) for every
  `control` in `controls`.
* [`get_control_deriv(generator, control)`](@ref get_control_deriv) must return
  an object that passes the less restrictive
  [`QuantumPropagators.Interfaces.check_generator`](@ref) if `control` is in
  `get_controls(generator)`. The controls in the derivative (if any) must be a
  subset of the controls in `generator.`
* [`get_control_deriv(generator, control)`](@ref get_control_deriv) must return
  `nothing` if `control` is not in
  [`get_controls(generator)`](@ref get_controls)
* If `generator` is a [`Generator`](@ref) instance, every `ampl` in
  `generator.amplitudes` must pass [`check_amplitude(ampl; tlist)`](@ref
  check_amplitude).

The function returns `true` for a valid generator and `false` for an invalid
generator. Unless `quiet=true`, it will log an error to indicate which of the
conditions failed.
"""
function check_generator(
    generator;
    state,
    tlist,
    for_expval = true,
    for_pwc = true,
    for_time_continuous = false,
    for_parameterization = false,
    for_gradient_optimization = true,
    atol = 1e-15,
    quiet = false,
    _message_prefix = ""  # for recursive calling
)

    px = _message_prefix

    success = QuantumPropagators.Interfaces.check_generator(
        generator;
        state,
        tlist,
        for_expval,
        for_pwc,
        for_time_continuous,
        for_parameterization,
        atol,
        quiet,
        _message_prefix,
        _check_amplitudes = false  # amplitudes are checked separately
    )
    success || (return false)

    if for_gradient_optimization

        try
            controls = get_controls(generator)
            control_derivs = get_control_derivs(generator, controls)
            if !(control_derivs isa Vector)
                quiet ||
                    @error "$(px)`get_control_derivs(generator, controls)` must return a Vector"
                success = false
            end
            if length(control_derivs) ≠ length(controls)
                quiet ||
                    @error "$(px)`get_control_derivs(generator, controls)` must return a derivative for every `control` in `controls`"
                success = false
            end
            # In general, we can't check for equality between
            # `get_control_deriv` and `get_control_deriv`, because `==` may not
            # be implemented to compare arbitrary generators by value
        catch exc
            quiet || @error(
                "$(px)`get_control_derivs(generator, controls)` must be defined.",
                exception = (exc, catch_abbreviated_backtrace())
            )
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
                    for_expval,
                    atol,
                    quiet,
                    _message_prefix = "On `deriv = get_control_deriv(generator, control)` of type $(typeof(deriv)) for control $i: ",
                    for_gradient_optimization = false
                )
                if !valid_deriv
                    quiet ||
                        @error "$(px)the result of `get_control_deriv(generator, control)` for control $i is not a valid generator"
                    success = false
                else
                    deriv_controls = Set(objectid(c) for c in get_controls(deriv))
                    if deriv_controls ⊈ Set(objectid.(controls))
                        quiet ||
                            @error "$(px)get_control_deriv(generator, control) for  control $i must return an object `D` so that `get_controls(D)` is a subset of `get_controls(generator)`"
                        success = false
                    end
                end
            end
        catch exc
            quiet || @error(
                "$(px)`get_control_deriv(generator, control)` must be defined.",
                exception = (exc, catch_abbreviated_backtrace())
            )
            success = false
        end

        try
            controls = get_controls(generator)
            dummy_control_CYRmE(t) = rand()
            @assert dummy_control_CYRmE ∉ controls
            deriv = get_control_deriv(generator, dummy_control_CYRmE)
            if deriv ≢ nothing
                quiet ||
                    @error "$(px)`get_control_deriv(generator, control)` must return `nothing` if `control` is not in `get_controls(generator)`, not $(repr(deriv))"
                success = false
            end
        catch exc
            quiet || @error(
                "$(px)`get_control_deriv(generator, control)` must return `nothing` if `control` is not in `get_controls(generator)`.",
                exception = (exc, catch_abbreviated_backtrace())
            )
            success = false
        end

        if generator isa Generator
            for (i, ampl) in enumerate(generator.amplitudes)
                valid_ampl = check_amplitude(
                    ampl;
                    tlist,
                    for_gradient_optimization,
                    quiet,
                    _message_prefix = "On ampl $i ($(typeof(ampl))) in `generator`: "
                )
                if !valid_ampl
                    quiet ||
                        @error "$(px)amplitude $i in `generator` does not pass `check_amplitude`"
                    success = false
                end
            end
        end

    end

    return success

end
