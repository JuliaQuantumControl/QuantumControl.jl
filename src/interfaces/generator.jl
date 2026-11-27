# SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT

using QuantumPropagators
using QuantumPropagators.Generators: Generator
using QuantumPropagators.Controls: get_controls, get_parameters
using QuantumPropagators.Interfaces: catch_abbreviated_backtrace
using ..Controls: get_control_derivs, get_control_deriv
using ..Controls: get_parameter_derivs, get_parameter_deriv


"""Check the dynamical `generator` in the context of optimal control.

```
@test check_generator(
    generator; state, tlist,
    for_expval=true, for_pwc=true, for_time_continuous=false,
    for_parameterization=false, for_gradient_optimization=true,
    for_hessian=false, atol=1e-15, quiet=false
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

If `for_parameterization` and `for_gradient_optimization`:

* Every control in [`get_controls(generator)`](@ref get_controls) must pass
  [`check_control`](@ref) with `for_parameterization`,
  `for_gradient_optimization`, and `for_hessian`.
* [`derivs = get_parameter_derivs(generator, u)`](@ref get_parameter_derivs)
  for the parameters [`u = get_parameters(generator)`](@ref get_parameters)
  must be defined and return a vector of the same length as `u`.
* Every element of `derivs` that is not `nothing` must pass
  [`QuantumPropagators.Interfaces.check_generator`](@ref) with
  `for_parameterization=true`, and its [parameter blocks](@ref ParameterBlocks)
  must be blocks of `generator`.
* Every element `derivs[n]` applied to `state` must agree with the central
  finite difference of `evaluate(generator, tlist, n) * state` with respect to
  `u[n]` for all intervals of `tlist`, where `evaluate(nothing, tlist, n)` is
  taken as zero. The finite difference is obtained by mutating `u[n]`, and the
  original value is restored afterwards.
* After changing the values in `u`, every element of `derivs` must again
  agree with the finite difference. This ensures that the derivatives read the
  parameter values when they are evaluated, not when they are created.
* For a block that `generator` neither holds nor inherits,
  [`get_parameter_deriv(generator, block, i)`](@ref get_parameter_deriv) must
  return `nothing`.

If `for_hessian` (in addition to `for_parameterization` and
`for_gradient_optimization`), every element of `derivs` that is not `nothing`
must in turn pass `check_generator` with `for_parameterization=true` and
`for_gradient_optimization=true`, i.e., the second derivatives must agree with
the finite differences of the first derivatives. Second derivatives are
optional, so the default is `for_hessian=false`.

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
    for_hessian = false,
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

    if for_parameterization && for_gradient_optimization

        try
            for (i, control) in enumerate(get_controls(generator))
                valid_control = check_control(
                    control;
                    tlist,
                    for_parameterization,
                    for_gradient_optimization,
                    for_hessian,
                    quiet,
                    _message_prefix = "On control $i ($(typeof(control))) in `generator`: "
                )
                if !valid_control
                    quiet ||
                        @error "$(px)control $i ($(typeof(control))) in `generator` must pass check_control"
                    success = false
                end
            end
        catch exc
            quiet || @error(
                "$(px)all controls in `generator` must pass `check_control`.",
                exception = (exc, catch_abbreviated_backtrace())
            )
            success = false
        end

        success &= _check_generator_parameter_derivs(
            generator;
            state,
            tlist,
            for_expval,
            for_pwc,
            for_time_continuous,
            for_hessian,
            atol,
            quiet,
            _message_prefix
        )

    end

    return success

end


function _applied_generator(generator, state, tlist)
    if isnothing(generator)
        return [zero(state) for n = 1:(length(tlist)-1)]
    else
        return [evaluate(generator, tlist, n) * state for n = 1:(length(tlist)-1)]
    end
end


# Norm of a vector of states
_norm_states(states) = sqrt(sum(norm(Ψ)^2 for Ψ in states; init = 0.0))


function _check_generator_parameter_derivs(
    generator;
    state,
    tlist,
    for_expval,
    for_pwc,
    for_time_continuous,
    for_hessian,
    atol,
    quiet,
    _message_prefix
)

    px = _message_prefix
    success = true

    local u, blocks, derivs
    try
        u = get_parameters(generator)
        blocks = u.x
        derivs = get_parameter_derivs(generator, u)
        if !(derivs isa Vector)
            quiet || @error "$(px)`get_parameter_derivs(generator, u)` must return a Vector"
            return false
        end
        if length(derivs) ≠ length(u)
            quiet ||
                @error "$(px)`get_parameter_derivs(generator, u)` must return a derivative for every element of `u = get_parameters(generator)`"
            return false
        end
    catch exc
        quiet || @error(
            "$(px)`get_parameter_derivs(generator, u)` must be defined for `u = get_parameters(generator)`.",
            exception = (exc, catch_abbreviated_backtrace())
        )
        return false
    end

    parameters = [(block, i) for block in blocks for i = 1:length(block)]
    valid_derivs = trues(length(derivs))

    for (n, D) in enumerate(derivs)
        isnothing(D) && continue
        msg_prefix = "On `D = get_parameter_derivs(generator, u)[$n]` of type $(typeof(D)): "
        if for_hessian
            valid_deriv = check_generator(
                D;
                state,
                tlist,
                for_expval,
                for_pwc,
                for_time_continuous,
                for_parameterization = true,
                for_gradient_optimization = true,
                for_hessian = false,
                atol,
                quiet,
                _message_prefix = msg_prefix
            )
        else
            valid_deriv = QuantumPropagators.Interfaces.check_generator(
                D;
                state,
                tlist,
                for_expval,
                for_pwc,
                for_time_continuous,
                for_parameterization = true,
                atol,
                quiet,
                _message_prefix = msg_prefix
            )
        end
        if !valid_deriv
            quiet ||
                @error "$(px)the derivative `get_parameter_derivs(generator, u)[$n]` is not a valid generator"
            success = false
            valid_derivs[n] = false
            continue
        end
        try
            for block in get_parameters(D).x
                if !any(b -> b === block, blocks)
                    quiet ||
                        @error "$(px)the parameter blocks of `get_parameter_derivs(generator, u)[$n]` must be parameter blocks of `generator`"
                    success = false
                    valid_derivs[n] = false
                end
            end
        catch exc
            quiet || @error(
                "$(px)`get_parameters(D)` must be defined for `D = get_parameter_derivs(generator, u)[$n]`.",
                exception = (exc, catch_abbreviated_backtrace())
            )
            success = false
            valid_derivs[n] = false
        end
    end

    saved_blocks = [copy(block) for block in blocks]
    try
        for round = 1:2
            if round == 2
                _perturb_parameters!(blocks)
            end
            scale = _norm_states(_applied_generator(generator, state, tlist))
            for (n, D) in enumerate(derivs)
                valid_derivs[n] || continue
                (block, i) = parameters[n]
                try
                    vals = _applied_generator(D, state, tlist)
                    (fd, fd2) = _central_fd(
                        () -> _applied_generator(generator, state, tlist),
                        block,
                        i
                    )
                    (agrees, Δ, tol) =
                        _agrees_with_fd(vals, fd, fd2, scale; normfunc = _norm_states)
                    if !agrees
                        changed = (round == 2) ? " after changing the parameter values" : ""
                        msg = "$(px)`get_parameter_derivs(generator, u)[$n]` must match the finite difference of `evaluate(generator, tlist, n) * state` with respect to `u[$n]`$changed"
                        quiet || @error msg error = Δ tolerance = tol
                        success = false
                    end
                catch exc
                    quiet || @error(
                        "$(px)`evaluate(D, tlist, n) * state` must be defined for `D = get_parameter_derivs(generator, u)[$n]`.",
                        exception = (exc, catch_abbreviated_backtrace())
                    )
                    success = false
                end
            end
        end
    finally
        for (block, saved) in zip(blocks, saved_blocks)
            copyto!(block, saved)
        end
    end

    try
        other_block = [0.0]
        D = get_parameter_deriv(generator, other_block, 1)
        if !isnothing(D)
            quiet ||
                @error "$(px)`get_parameter_deriv(generator, block, i)` must return `nothing` for a block that `generator` neither holds nor inherits, not $(repr(D))"
            success = false
        end
    catch exc
        quiet || @error(
            "$(px)`get_parameter_deriv(generator, block, i)` must be defined for a block that `generator` neither holds nor inherits.",
            exception = (exc, catch_abbreviated_backtrace())
        )
        success = false
    end

    return success

end
