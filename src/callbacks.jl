"""
Construct a method-specific automatic callback for printing iter information.

```julia
print_iters = make_print_iters(Method; kwargs...)
```

constructs the automatic callback to be used by
`optimize(problem; method=Method, print_iters=true)` to print information after
each iteration. The keyword arguments are those used to instantiate `problem`
and those explicitly passed to [`optimize`](@ref).

Optimization methods should implement
`make_print_iters(::Val{:Method}; kwargs...)` where `:Method` is the name
of the module/package implementing the method.
"""
function make_print_iters(method::Module; kwargs...)
    return make_print_iters(nameof(method); kwargs...)
end

function make_print_iters(method::Symbol; kwargs...)
    # Optimization packages must implement
    #
    #   make_print_iters(method::Val{name}; kwargs...)
    #
    return make_print_iters(Val(method); kwargs...)
end


# If a package does not implement make_print_iters, nothing will be printed
function make_print_iters(method::Val; kwargs...)
    return nothing
end


"""Combine multiple `callback` functions.

```julia
chain_callbacks(funcs...)
```

combines `funcs` into a single Function that can be passes as `callback` to
[`ControlProblem`](@ref) or any `optimize`-function.

Each function in `func` must be a suitable `callback` by itself. This means
that it should receive the optimization workspace object as its first
positional parameter, then positional parameters specific to the optimization
method, and then an arbitrary number of data parameters. It must return either
`nothing` or a tuple of "info" objects (which will end up in the `records` field of
the optimization result).

When chaining callbacks, the `funcs` will be called in series, and the "info"
objects will be accumulated into a single result tuple. The combined results
from previous `funcs` will be given to the subsequent `funcs` as data
parameters. This allows for the callbacks in the chain to communicate.

The chain will return the final combined result tuple, or `nothing` if all
`funcs` return `nothing`.

!!! note

    When calling [`optimize`](@ref), any `callback` that is a
    tuple will be automatically processed with `chain_callbacks`. Thus,
    `chain_callbacks` rarely has to be invoked manually.
"""
function chain_callbacks(funcs...)

    function _callback(args...)
        res = Tuple([])
        for f in funcs
            res_f = f(args..., res...)
            if !isnothing(res_f)
                res = (res..., res_f...)
            end
        end
        if length(res) == 0
            return nothing
        else
            return res
        end
    end

    return _callback

end
