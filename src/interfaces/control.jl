# SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT

using LinearAlgebra: norm
using QuantumPropagators
using QuantumPropagators.Controls: get_parameters, evaluate
using QuantumPropagators.Interfaces: catch_abbreviated_backtrace
using ..Controls: get_parameter_deriv


"""Check a control in the context of optimal control.

```
@test check_control(
    control;
    tlist,
    for_parameterization=true,
    for_time_continuous=(control isa Function),
    for_gradient_optimization=true,
    for_hessian=false,
    quiet=false
)
```

verifies the given `control` (one of the elements of the tuple returned by
[`get_controls`](@ref)). This checks all the conditions of
[`QuantumPropagators.Interfaces.check_control`](@ref). In addition, the
following conditions must be met.

If `for_parameterization` and `for_gradient_optimization`: for every index
`i` of the [parameter block](@ref ParameterBlocks) `p` that `control` holds
(if any), the derivative
[`d = get_parameter_deriv(control, p, i)`](@ref get_parameter_deriv) must be
defined, and

* `d` must be a number, or pass `check_control` (with
  `for_gradient_optimization=for_hessian`)
* `d` must hold no parameter block other than `p`, i.e., the blocks
  [`get_parameters(d).x`](@ref get_parameters) must be empty or `(p,)`
* `evaluate(d, tlist, n)` must agree with the central finite difference of
  `evaluate(control, tlist, n)` with respect to `p[i]`, for all intervals `n`
  of `tlist`. The finite difference is obtained by mutating `p[i]`, and the
  original value is restored afterwards.
* After changing the values in `p`, `evaluate(d, tlist, n)` must again agree
  with the finite difference. This ensures that `d` reads the parameter values
  when it is evaluated, not when it is created.
* If the value of `d` changes with the values in `p`, `d` must hold `p`, i.e.,
  [`get_parameters(d)`](@ref get_parameters) must not be empty.

Also, for a block that `control` does not hold,
[`get_parameter_deriv(control, block, i)`](@ref get_parameter_deriv) must
return `0.0`.

If `for_hessian` (in addition to `for_parameterization` and
`for_gradient_optimization`), every derivative `d` that is not a number must
in turn have parameter derivatives that pass the above checks. Second
derivatives are optional, so the default is `for_hessian=false`.

The function returns `true` for a valid control and `false` for an invalid
control. Unless `quiet=true`, it will log an error to indicate which of the
conditions failed.
"""
function check_control(
    control;
    tlist,
    for_parameterization = true,
    for_time_continuous = (control isa Function),
    for_gradient_optimization = true,
    for_hessian = false,
    quiet = false,
    _message_prefix = ""  # for recursive calling
)

    px = _message_prefix
    success = QuantumPropagators.Interfaces.check_control(
        control;
        tlist,
        for_parameterization,
        for_time_continuous,
        quiet,
        _message_prefix
    )
    success || (return false)

    if for_parameterization && for_gradient_optimization
        success &= _check_control_parameter_derivs(
            control;
            tlist,
            for_time_continuous,
            for_hessian,
            quiet,
            _message_prefix
        )
    end

    return success

end


# Relative and absolute tolerance for comparing a derivative with a central
# finite difference (on the level of the norm of all values on a time grid).
# The absolute tolerance is relative to the norm of the values of the original
# object.
const _FD_RTOL = 1e-5
const _FD_ATOL = 1e-8


_fd_step(value) = cbrt(eps(Float64)) * max(1.0, abs(value))


# Central finite differences of `f()` w.r.t. `block[i]` with step sizes `h`
# and `2h`, restoring the original value afterwards. The difference of the two
# estimates the truncation error of the first.
function _central_fd(f, block, i)
    v₀ = block[i]
    h = _fd_step(v₀)
    try
        fds = map((h, 2h)) do δ
            block[i] = v₀ + δ
            f₊ = f()
            δ₊ = block[i] - v₀
            block[i] = v₀ - δ
            f₋ = f()
            δ₋ = v₀ - block[i]
            (f₊ - f₋) / (δ₊ + δ₋)
        end
        return fds
    finally
        block[i] = v₀
    end
end


# Whether the values `vals` of a derivative agree with the finite differences
# `fd` and `fd2` (from `_central_fd`), with `scale` the norm of the values of
# the original object, and `normfunc` the norm for `vals`, `fd`, `fd2`. The
# tolerance includes the estimated truncation error of the finite difference,
# so that the check does not depend on how quickly the object changes with the
# parameter.
function _agrees_with_fd(vals, fd, fd2, scale; normfunc = norm)
    Δ = normfunc(vals - fd)
    tol = (
        _FD_RTOL * max(normfunc(vals), normfunc(fd)) +
        _FD_ATOL * max(1.0, scale) +
        normfunc(fd - fd2)
    )
    return (Δ <= tol, Δ, tol)
end


# Change the values in all `blocks` (deterministically, and by an amount that
# is unlikely to make the values invalid)
function _perturb_parameters!(blocks)
    for block in blocks
        for k = 1:length(block)
            block[k] += 0.1 * (abs(block[k]) + 0.1) * sin(k + 1)
        end
    end
end


_control_values(control, tlist) = [evaluate(control, tlist, n) for n = 1:(length(tlist)-1)]


function _check_control_parameter_derivs(
    control;
    tlist,
    for_time_continuous,
    for_hessian,
    quiet,
    _message_prefix
)

    px = _message_prefix
    success = true

    # guaranteed to work by previous checks
    blocks = get_parameters(control).x
    saved_blocks = [copy(block) for block in blocks]
    derivs = []  # tuples (block, i, d)

    try

        for block in blocks
            for i = 1:length(block)
                local d
                try
                    d = get_parameter_deriv(control, block, i)
                catch exc
                    quiet || @error(
                        "$(px)`get_parameter_deriv(control, p, i)` must be defined for i=$i.",
                        exception = (exc, catch_abbreviated_backtrace())
                    )
                    success = false
                    continue
                end
                if !(d isa Number)
                    valid_deriv = check_control(
                        d;
                        tlist,
                        for_parameterization = true,
                        for_time_continuous,
                        for_gradient_optimization = for_hessian,
                        for_hessian = false,
                        quiet,
                        _message_prefix = "On `d = get_parameter_deriv(control, p, $i)` of type $(typeof(d)): "
                    )
                    if !valid_deriv
                        quiet ||
                            @error "$(px)`get_parameter_deriv(control, p, i)` for i=$i must return a number or a valid control"
                        success = false
                        continue
                    end
                    blocks_d = get_parameters(d).x
                    if !(isempty(blocks_d) || (blocks_d === (block,)))
                        quiet ||
                            @error "$(px)`d = get_parameter_deriv(control, p, i)` with i=$i must hold no parameter block other than the block `p` of `control`"
                        success = false
                        continue
                    end
                end
                push!(derivs, (block, i, d))
            end
        end

        vals_before = Dict{Int,Any}()
        for round = 1:2
            if round == 2
                _perturb_parameters!(blocks)
            end
            scale = norm(_control_values(control, tlist))
            for (k, (block, i, d)) in enumerate(derivs)
                try
                    vals = _control_values(d, tlist)
                    (fd, fd2) = _central_fd(() -> _control_values(control, tlist), block, i)
                    (agrees, _, _) = _agrees_with_fd(vals, fd, fd2, scale)
                    if !agrees
                        changed = (round == 2) ? " after changing the parameter values" : ""
                        msg = "$(px)`evaluate(d, tlist, n)` for `d = get_parameter_deriv(control, p, i)` with i=$i must match the finite difference of `evaluate(control, tlist, n)`$changed"
                        quiet || @error msg maxerror = maximum(abs.(vals - fd))
                        success = false
                    end
                    if round == 1
                        vals_before[k] = vals
                    elseif (vals ≠ vals_before[k]) && isempty(get_parameters(d))
                        quiet ||
                            @error "$(px)`d = get_parameter_deriv(control, p, i)` with i=$i depends on the parameter values, so it must hold the block `p` (`get_parameters(d)` must not be empty)"
                        success = false
                    end
                catch exc
                    quiet || @error(
                        "$(px)`evaluate(d, tlist, n)` must be defined for `d = get_parameter_deriv(control, p, i)` with i=$i.",
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
        d = get_parameter_deriv(control, other_block, 1)
        if !((d isa Number) && iszero(d))
            quiet ||
                @error "$(px)`get_parameter_deriv(control, block, i)` must return 0.0 for a block that `control` does not hold, not $(repr(d))"
            success = false
        end
    catch exc
        quiet || @error(
            "$(px)`get_parameter_deriv(control, block, i)` must be defined for a block that `control` does not hold.",
            exception = (exc, catch_abbreviated_backtrace())
        )
        success = false
    end

    return success

end
