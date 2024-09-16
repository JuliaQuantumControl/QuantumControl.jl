# Extension of QuantumPropagators.propagate for trajectories

using Logging
import QuantumPropagators
using QuantumPropagators.Controls: substitute, get_controls
# from conditionalthreads.jl: @threadsif


"""Propagate a [`Trajectory`](@ref).

```julia
propagate_trajectory(
    traj,
    tlist;
    initial_state=traj.initial_state,
    kwargs...
)
```

propagates `initial_state` under the dynamics described by `traj.generator`. It
takes the same keyword arguments as [`QuantumPropagators.propagate`](@ref),
with default values from any property of `traj` with a `prop_` prefix
(`prop_method`, `prop_inplace`, `prop_callback`, …).
See [`init_prop_trajectory`](@ref) for details.

Note that `method` (a mandatory keyword argument in
[`QuantumPropagators.propagate`](@ref)) must be specified, either as a property
`prop_method` of the trajectory, or by passing a `method` keyword argument
explicitly.
"""
function propagate_trajectory(
    traj,
    tlist;
    _prefixes=["prop_"],
    initial_state=traj.initial_state,
    kwargs...
)

    propagator = init_prop_trajectory(traj, tlist; initial_state, kwargs...)

    kwargs = Dict(kwargs...)
    prop_kwargs = Dict{Symbol,Any}()
    for name in (:storage, :observables, :show_progress, :callback)
        for prefix in _prefixes
            _traj_name = Symbol(prefix * string(name))
            if hasproperty(traj, _traj_name)
                prop_kwargs[name] = getproperty(traj, _traj_name)
            end
        end
        if haskey(kwargs, name)
            prop_kwargs[name] = kwargs[name]
        end
    end

    @debug "propagate_trajectory: propagate(propagator, …) with kwargs=$(prop_kwargs)"

    return QuantumPropagators.propagate(propagator; prop_kwargs...)

end


"""Initialize a propagator for a given [`Trajectory`](@ref).

```
propagator = init_prop_trajectory(
    traj,
    tlist;
    initial_state=traj.initial_state,
    kwargs...
)
```

initializes a [`Propagator`](@ref QuantumPropagators.AbstractPropagator) for
the propagation of the `initial_state` under the dynamics described by
`traj.generator`.

All keyword arguments are forwarded to [`QuantumPropagators.init_prop`](@ref),
with default values from any property of `traj` with a `prop_` prefix. That is,
the keyword arguments for the underlying [`QuantumPropagators.init_prop`](@ref)
are determined as follows:

* For any property of `traj` whose name starts with the prefix `prop_`, strip
  the prefix and use that property as a keyword argument for `init_prop`. For
  example, if `traj.prop_method` is defined, `method=traj.prop_method` will be
  passed to `init_prop`. Similarly, `traj.prop_inplace` would be passed as
  `inplace=traj.prop_inplace`, etc.
* Any explicitly keyword argument to `init_prop_trajectory` overrides the values
  from the properties of `traj`.

Note that the propagation `method` in particular must be specified, as it is a
mandatory keyword argument in [`QuantumPropagators.propagate`](@ref)). Thus,
either `traj` must have a property `prop_method` of the trajectory, or `method`
must be given as an explicit keyword argument.
"""
function init_prop_trajectory(
    traj::Trajectory,
    tlist;
    _prefixes=["prop_"],
    _msg="Initializing propagator for trajectory",
    _filter_kwargs=false,
    _kwargs_dict::Dict{Symbol,Any}=Dict{Symbol,Any}(),
    initial_state=traj.initial_state,
    verbose=false,
    kwargs...
)
    #
    # The private keyword arguments, `_prefixes`, `_msg`, `_filter_kwargs`,
    # `_kwargs_dict` are for internal use when setting up optimal control
    # workspace objects (see, e.g., Krotov.jl and GRAPE.jl)
    #
    # * `_prefixes`: which prefixes to translate into `init_prop` kwargs. For
    #   example, in Krotov/GRAPE, we have propagators both for the forward and
    #   backward propagation of each trajectory, and we allow prefixes
    #   "fw_prop_"/"bw_prop_" in addition to the standard "prop_" prefix.
    # * `msg`: The message to show via @debug/@info. This could be customized
    #    to e.g. "Initializing fw-propagator for trajectory 1/N"
    # * `_filter_kwargs`: Whether to filter `kwargs` to `_prefixes`. This
    #    allows to pass the keyword arguments from `optimize` directly to
    #    `init_prop_trajectory`. By convention, these use the same
    #    `prop`/`fw_prop`/`bw_prop` prefixes as the properties of `traj`.
    # * `_kwargs_dict`: A dictionary Symbol => Any that collects the arguments
    #   for `init_prop`. This allows to keep a copy of those arguments,
    #   especially for arguments that cannot be obtained from the resulting
    #   propagator, like the propagation callback.
    #
    empty!(_kwargs_dict)
    for prefix in _prefixes
        for key in propertynames(traj)
            if startswith(string(key), prefix)
                _kwargs_dict[Symbol(string(key)[length(prefix)+1:end])] =
                    getproperty(traj, key)
            end
        end
    end
    if _filter_kwargs
        for prefix in _prefixes
            for (key, val) in kwargs
                if startswith(string(key), prefix)
                    _kwargs_dict[Symbol(string(key)[length(prefix)+1:end])] = val
                end
            end
        end
    else
        merge!(_kwargs_dict, kwargs)
    end
    level = verbose ? Logging.Info : Logging.Debug
    @logmsg level _msg kwargs = _kwargs_dict
    try
        return init_prop(initial_state, traj.generator, tlist; verbose, _kwargs_dict...)
    catch exception
        msg = "Cannot initialize propagation for trajectory"
        @error msg exception kwargs = _kwargs_dict
        rethrow()
    end
end


"""Propagate multiple trajectories in parallel.

```julia
result = propagate_trajectories(
    trajectories, tlist; use_threads=true, kwargs...
)
```

runs [`propagate_trajectory`](@ref) for every trajectory in `trajectories`,
collects and returns a vector of results. The propagation happens in parallel
if `use_threads=true` (default). All keyword parameters are passed to
[`propagate_trajectory`](@ref), except that if `initial_state` is given, it
must be a vector of initial states, one for each trajectory. Likewise, to pass
pre-allocated storage arrays to `storage`, a vector of storage arrays must be
passed. A simple `storage=true` will still work to return a vector of storage
results.
"""
function propagate_trajectories(
    trajectories,
    tlist;
    use_threads=true,
    storage=nothing,
    initial_state=[traj.initial_state for traj in trajectories],
    kwargs...
)
    result = Vector{Any}(undef, length(trajectories))
    @threadsif use_threads for (k, traj) in collect(enumerate(trajectories))
        if isnothing(storage) || (storage isa Bool)
            result[k] = propagate_trajectory(
                traj,
                tlist;
                storage=storage,
                initial_state=initial_state[k],
                kwargs...
            )
        else
            result[k] = propagate_trajectory(
                traj,
                tlist;
                storage=storage[k],
                initial_state=initial_state[k],
                kwargs...
            )
        end
    end
    return [result...]  # chooses an automatic eltype
end
