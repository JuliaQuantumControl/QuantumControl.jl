using JLD2: jldopen

"""
Register a callback to dump a running optimization to disk on unexpected exit.

A long-running optimization routine may use

```julia
if !isnothing(atexit_filename)
    set_atexit_save_optimization(
        atexit_filename, result; msg_property=:message, msg="Abort: ATEXIT"
    )
    # ...
    popfirst!(Base.atexit_hooks)  # remove callback
end
```

to register a callback that writes the given `result` object to the given
`filename` in JLD2 format in the event that the program terminates
unexpectedly. The idea is to avoid data loss if the user presses `CTRL-C` in a
non-interactive program (`SIGINT`), or if the process receives a `SIGTERM` from
an HPC scheduler because the process has reached its allocated runtime limit.
Note that the callback cannot protect against data loss in all possible
scenarios, e.g., a `SIGKILL` will terminate the program without giving the
callback a chance to run (as will yanking the power cord).

As in the above example, the optimization routine should make
`set_atexit_save_optimization` conditional on an `atexit_filename` keyword
argument, which is what `QuantumControl.@optimize_or_load` will pass to the
optimization routine. The optimization routine must remove the callback from
`Base.atexit_hooks` when it exits normally. Note that in an interactive
context, `CTRL-C` will throw an `InterruptException`, but not cause a shutdown.
Optimization routines that want to prevent data loss in this situation should
handle the `InterruptException` and return `result`, in addition to using
`set_atexit_save_optimization`.

If `msg_property` is not `nothing`, the given `msg` string will be stored in
the corresponding property of the (mutable) `result` object before it is
written out.

The resulting JLD2 file is compatible with `QuantumControl.load_optimization`.
"""
function set_atexit_save_optimization(
    filename,
    result;
    msg_property=:message,
    msg="Abort: ATEXIT"
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

end
