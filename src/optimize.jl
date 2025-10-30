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
Any other keyword argument temporarily overrides the corresponding keyword
argument in [`problem`](@ref ControlProblem). These arguments are available to
the optimizer, see each optimization package's documentation for details.

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

All remaining keyword argument are method-specific.
To obtain the documentation for which options a particular method uses, run,
e.g.,

```julia
? optimize(problem, ::Val{:Krotov})
```

where `:Krotov` is the name of the module implementing the method. The above is
also the method signature that a `Module` wishing to implement a control method
must define.

The returned `result` object is specific to the optimization method, but should
be a subtype of [`QuantumControl.AbstractOptimizationResult`](@ref).
"""
function optimize(
    problem::ControlProblem;
    method::Union{Module,Symbol},
    check = get(problem.kwargs, :check, true),
    print_iters = get(problem.kwargs, :print_iters, true),
    callback = get(problem.kwargs, :callback, nothing),
    for_expval = true, # undocumented
    for_pwc = true,  # undocumented
    for_time_continuous = false,  # undocumented
    for_parameterization = false, # undocumented
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
    if !isempty(callbacks)
        if length(callbacks) > 1
            temp_kwargs[:callback] = chain_callbacks(callbacks...)
        else
            temp_kwargs[:callback] = callbacks[1]
        end
    end

    temp_problem = ControlProblem(;
        trajectories = problem.trajectories,
        tlist = problem.tlist,
        temp_kwargs...
    )

    if check
        # TODO: checks will have to be method-dependent, and then we may not
        # need all the `for_...` keyword arguments
        for (i, traj) in enumerate(problem.trajectories)
            if !check_state(traj.initial_state)
                error("The `initial_state` of trajectory $i is not valid")
            end
            if !check_generator(
                traj.generator;
                state = traj.initial_state,
                tlist = problem.tlist,
                for_expval,
                for_pwc,
                for_time_continuous,
                for_parameterization,
            )
                error("The `generator` of trajectory $i is not valid")
            end
        end
    end

    return optimize(temp_problem, method)

end

optimize(problem::ControlProblem, method::Symbol) = optimize(problem, Val(method))
optimize(problem::ControlProblem, method::Module) = optimize(problem, Val(nameof(method)))
#
# Note: Methods *must* be defined in the various optimization packages as e.g.
#
#   optimize(problem, method::Val{:krotov}) = optimize_krotov(problem)
#
