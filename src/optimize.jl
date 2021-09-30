import Krotov

"""Optimize a quantum control problem.

```julia
opt_result = optimize(problem; method=<method>, kwargs...)
```

optimizes towards a solution of given `problem` with the given optimization
`method`. All keyword arguments update (overwrite) parameters in `problem`
"""
function optimize(problem; method, kwargs...)
    return optimize(problem, method; kwargs...)
end

optimize(problem, method::Symbol; kwargs...) = optimize(problem, Val(method); kwargs...)

"""
```julia
opt_result = optimize(problem; method=:krotov, kwargs...)
```

optimizes `problem` using Krotov's method, see
[`Krotov.optimize_pulses`](@ref).
"""
optimize(problem, method::Val{:krotov}; kwargs...) = Krotov.optimize_pulses(problem, kwargs...)
