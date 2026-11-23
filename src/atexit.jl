# SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT

using JLD2: jldopen

"""
Register a callback to dump a running optimization to disk on unexpected exit.

```julia
hook = set_atexit_save_optimization(
    filename, result; msg_property=:message, msg="Abort: ATEXIT"
)
```

registers a callback via `atexit` that writes the given `result` object to the
given `filename` in JLD2 format in the event that the program terminates
unexpectedly, and returns that callback. The idea is to avoid data loss if the
user presses `CTRL-C` in a non-interactive program (`SIGINT`), or if the
process receives a `SIGTERM` from an HPC scheduler because the process has
reached its allocated runtime limit. Note that the callback cannot protect
against data loss in all possible scenarios, e.g., a `SIGKILL` will terminate
the program without giving the callback a chance to run (as will yanking the
power cord).

A long-running optimization routine should use

```julia
hook = nothing
if !isnothing(atexit_filename)
    hook = set_atexit_save_optimization(atexit_filename, result)
end
try
    # ... optimization ...
finally
    remove_atexit_save_optimization(hook)
end
```

That is, the optimization routine should make `set_atexit_save_optimization`
conditional on an `atexit_filename` keyword argument, which is what
[`@optimize_or_load`](@ref) will pass to the optimization
routine. The optimization routine must remove the callback with
[`remove_atexit_save_optimization`](@ref QuantumControl.remove_atexit_save_optimization)
when it exits, both normally and by throwing an exception. Otherwise, in an
interactive session, the callback remains registered and overwrites `filename`
with the (partial) `result` when Julia eventually exits. To ensure this,
register the callback immediately before the `try` block, with no code in
between that might throw. Since an exception removes the callback, the
callback does not write `filename` if the optimization fails with an
exception, even if that exception ends the program. A `SIGINT` or `SIGTERM`
in a non-interactive program terminates Julia without running the `finally`
block, so the callback still runs in that case. Note that in an
interactive context, `CTRL-C` will throw an `InterruptException`, but not cause
a shutdown. Optimization routines that want to prevent data loss in this
situation should handle the `InterruptException` and return `result`, in
addition to using `set_atexit_save_optimization`.

If `msg_property` is not `nothing`, the given `msg` string will be stored in
the corresponding property of the (mutable) `result` object before it is
written out.

The resulting JLD2 file is compatible with `QuantumControl.load_optimization`.
"""
function set_atexit_save_optimization(
    filename,
    result;
    msg_property = :message,
    msg = "Abort: ATEXIT"
)

    function dump_on_exit()
        if !isnothing(msg_property)
            setproperty!(result, msg_property, msg)
        end
        jldopen(filename, "w") do data
            data["result"] = result
        end
    end

    # the callback might not have very much time to run, so it's best to
    # precompile and save a few seconds later on when it matters.
    precompile(dump_on_exit, ())

    atexit(dump_on_exit)

    return dump_on_exit

end


"""
Remove a callback registered by `set_atexit_save_optimization`.

```julia
remove_atexit_save_optimization(hook)
```

removes `hook`, as returned by
[`set_atexit_save_optimization`](@ref QuantumControl.set_atexit_save_optimization),
from `Base.atexit_hooks`, regardless of its position, so any `atexit` hooks
registered after it are unaffected. Only a single entry equal (`===`) to `hook`
is removed. If `hook` is not registered (e.g., because it was already removed),
or if `hook` is `nothing`, this does nothing.
"""
function remove_atexit_save_optimization(hook)
    isnothing(hook) && return nothing
    if isdefined(Base, :_atexit_hooks_lock)
        Base.@lock Base._atexit_hooks_lock begin
            _remove_first!(Base.atexit_hooks, hook)
        end
    else
        _remove_first!(Base.atexit_hooks, hook)
    end
    return nothing
end

# The `dump_on_exit` closures from two calls to `set_atexit_save_optimization`
# with the same arguments are `===`, so we must not remove all matches.
function _remove_first!(hooks, hook)
    i = findfirst(h -> h === hook, hooks)
    isnothing(i) || deleteat!(hooks, i)
    return hooks
end
