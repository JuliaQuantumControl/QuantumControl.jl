# SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT

using QuantumPropagators.Controls: substitute
using QuantumPropagators.Interfaces: check_state

# from callbacks.jl:
import .make_print_iters

# from check_generator.jl:
import .Interfaces: check_generator


"""Optimize a quantum control problem.

```julia
result = optimize(
    problem;
    method,  # mandatory keyword argument
    check=true,
    callback=nothing,
    print_iters=true,
    kwargs...
)
```

optimizes towards a solution of given [`problem`](@ref ControlProblem) with
the given `method`, which should be a `Module` implementing the method, e.g.,

```julia
using Krotov
result = optimize(problem; method=Krotov)
```

If `check` is true (default), the `initial_state` and `generator` of each
trajectory is checked with [`check_state`](@ref) and [`check_generator`](@ref).
Additional keyword arguments can be passed to these two `check` routines by
passing a named-tuple as `check_state_kwargs` and `check_generator_kwargs`.

The `callback` can be given as a function to be called after each iteration in
order to analyze the progress of the optimization or to modify the state of
the optimizer or the current controls. The signature of `callback` is
method-specific, but callbacks should receive a workspace objects as the first
parameter as the first argument, the iteration number as the second parameter,
and then additional method-specific parameters.

The `callback` function may return a tuple of values, and an optimization
method should store these values fore each iteration in a `records` field in
their `Result` object. The `callback` should be called once with an iteration
number of `0` before the first iteration. The `callback` can also be given as a
tuple of vector of functions, which are automatically combined via
[`chain_callbacks`](@ref).

If `print_iters` is `true` (default), an automatic `callback` is created via
the method-specific [`make_print_iters`](@ref) to print the progress of the
optimization after each iteration. This automatic callback runs after any
manually given `callback`.

All remaining keyword argument are method-specific and temporarily overrides
the corresponding keyword argument in [`problem`](@ref ControlProblem).
To obtain the documentation for which options a particular method uses, run,
e.g.,

```julia
? optimize(problem, ::Val{:Krotov})
```

where `:Krotov` is the name of the module implementing the method. The above is
also the method signature that a `Module` wishing to implement a control method
must define.

Optimization methods typically initialize the propagators for each trajectory
with [`init_prop_trajectory`](@ref), using keyword arguments with a `prop_`
prefix as options for the propagator, e.g., `prop_method`. Methods may also
use more specific prefixes, e.g., `fw_prop_` and `bw_prop_` for the forward
and backward propagation. The same options can be set as properties of each
[`Trajectory`](@ref). The precedence of these options is as follows:

* Keyword arguments (given to `optimize` or stored in `problem`) take
  precedence over the properties of a trajectory, regardless of prefix.
* Among keyword arguments, or among the properties of a trajectory, a more
  specific prefix like `fw_prop_` takes precedence over `prop_`.

For example, for a trajectory with the property `fw_prop_method = ExpProp`,
`optimize(problem; method, prop_method = Cheby)` uses `Cheby` for the forward
propagation. To use different propagation methods for different trajectories,
set them as properties of the trajectories and do not pass the corresponding
keyword argument. A warning is shown if a keyword argument with the `prop_`
prefix overrides a trajectory property with a more specific prefix.

The returned `result` object is specific to the optimization method, but should
be a subtype of [`QuantumControl.AbstractOptimizationResult`](@ref).
"""
function optimize(
    problem::ControlProblem;
    method::Union{Module,Symbol},
    check = get(problem.kwargs, :check, true),
    print_iters = get(problem.kwargs, :print_iters, true),
    callback = get(problem.kwargs, :callback, nothing),
    check_state_kwargs = get(problem.kwargs, :check_state_kwargs, (;)),
    check_generator_kwargs = get(problem.kwargs, :check_generator_kwargs, (;)),
    kwargs...
)

    temp_kwargs = copy(problem.kwargs)
    merge!(temp_kwargs, kwargs)

    callbacks = Any[]
    if !isnothing(callback)
        if callback isa Union{Tuple,Vector}
            @debug "Implicitly combining callback with chain_callbacks"
            append!(callbacks, callback)
        else
            push!(callbacks, callback)
        end
    end

    if print_iters
        push!(callbacks, make_print_iters(method; temp_kwargs...))
    end
    if isempty(callbacks)
        # A `callback = nothing` in `problem.kwargs` must not reach the
        # optimization method, and neither may a callback in `problem.kwargs`
        # if `optimize` was called with an explicit `callback = nothing`.
        delete!(temp_kwargs, :callback)
    elseif length(callbacks) > 1
        temp_kwargs[:callback] = chain_callbacks(callbacks...)
    else
        temp_kwargs[:callback] = callbacks[1]
    end

    _warn_overridden_prop_properties(problem.trajectories, temp_kwargs)

    temp_problem = ControlProblem(;
        trajectories = problem.trajectories,
        tlist = problem.tlist,
        temp_kwargs...
    )

    if check
        # TODO: checks maybe should be method-dependent
        for (i, traj) in enumerate(problem.trajectories)
            if !check_state(traj.initial_state; check_state_kwargs...)
                error("The `initial_state` of trajectory $i is not valid")
            end
            if !check_generator(
                traj.generator;
                check_generator_kwargs...,
                state = traj.initial_state,
                tlist = problem.tlist,
            )
                error("The `generator` of trajectory $i is not valid")
            end
        end
    end

    return optimize(temp_problem, method)

end

# Warn if a keyword argument `prop_<name>` overrides a trajectory property with
# a more specific prefix, `<x>_prop_<name>` (e.g., `fw_prop_method`). Since
# keyword arguments take precedence over trajectory properties regardless of
# prefix (see `init_prop_trajectory`), the trajectory property has no effect,
# which is unlikely to be intended: prefixes like `fw_prop_` only have a
# meaning in an optimization. There is no warning if the values are equal, or
# if the keyword argument `<x>_prop_<name>` is also given, as that explicitly
# overrides the trajectory property. Overriding a trajectory property with the
# same prefix (e.g., `prop_method`) is intentional and does not warn.
function _warn_overridden_prop_properties(trajectories, kwargs)
    any(key -> startswith(string(key), "prop_"), keys(kwargs)) || return
    overridden = Dict{Tuple{Symbol,Symbol},Vector{Int}}()  # (kw, prop) => [k…]
    for (k, traj) in enumerate(trajectories)
        for name in propertynames(traj)
            m = match(r"^[^_]+_prop_(.+)$", string(name))
            isnothing(m) && continue
            key = Symbol("prop_" * m.captures[1])
            if haskey(kwargs, key) &&
               !haskey(kwargs, name) &&
               !isequal(kwargs[key], getproperty(traj, name))
                push!(get!(overridden, (key, name), Int[]), k)
            end
        end
    end
    isempty(overridden) && return
    lines = String[]
    sorted = sort!(collect(overridden); by = first)
    for ((key, name), indices) in sorted
        trajs = length(indices) == 1 ? "trajectory" : "trajectories"
        push!(lines, "* `$key` overrides `$name` of $trajs $(_fmt_indices(indices))")
    end
    @warn """
    Keyword arguments override trajectory properties with a more specific prefix:
    $(join(lines, "\n"))
    Keyword arguments (including those stored in the ControlProblem) take precedence over the properties of a Trajectory, regardless of prefix. To use the trajectory properties, omit the keyword argument. To use the keyword argument and silence this warning, pass the more specific keyword argument (e.g., `$(sorted[1][1][2])`) explicitly.
    """
end


# Format a sorted list of integers, combining consecutive runs into ranges,
# e.g. [1, 2, 3, 5] -> "1:3, 5"
function _fmt_indices(indices)
    parts = String[]
    i = 1
    while i <= length(indices)
        j = i
        while (j < length(indices)) && (indices[j+1] == indices[j] + 1)
            j += 1
        end
        push!(parts, j > i + 1 ? "$(indices[i]):$(indices[j])" : join(indices[i:j], ", "))
        i = j + 1
    end
    return join(parts, ", ")
end


optimize(problem::ControlProblem, method::Symbol) = optimize(problem, Val(method))
optimize(problem::ControlProblem, method::Module) = optimize(problem, Val(nameof(method)))
#
# Note: Methods *must* be defined in the various optimization packages as e.g.
#
#   optimize(problem, method::Val{:krotov}) = optimize_krotov(problem)
#
