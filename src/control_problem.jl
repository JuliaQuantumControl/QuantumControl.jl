import QuantumPropagators.Controls: get_controls, get_parameters, substitute


"""A full control problem with multiple trajectories.

```julia
ControlProblem(
   trajectories,
   tlist;
   kwargs...
)
```

The `trajectories` are a list of [`Trajectory`](@ref) instances,
each defining an initial state and a dynamical generator for the evolution of
that state. Usually, the trajectory will also include a target state (see
[`Trajectory`](@ref)) and possibly a weight. The `trajectories` may also be
given together with `tlist` as a mandatory keyword argument.

The `tlist` is the time grid on which the time evolution of the initial states
of each trajectory should be propagated. It may also be given as a (mandatory)
keyword argument.

The remaining `kwargs` are keyword arguments that are passed directly to the
optimal control method. These typically include e.g. the optimization
functional.

The control problem is solved by finding a set of controls that minimize an
optimization functional over all trajectories.
"""
struct ControlProblem
    trajectories::Vector{<:Trajectory}
    tlist::Vector{Float64}
    kwargs::Dict{Symbol,Any}
    function ControlProblem(trajectories, tlist; kwargs...)
        kwargs_dict = Dict{Symbol,Any}(kwargs)
        new(trajectories, tlist, kwargs_dict)
    end
end

ControlProblem(trajectories; tlist, kwargs...) =
    ControlProblem(trajectories, tlist; kwargs...)

ControlProblem(; trajectories, tlist, kwargs...) =
    ControlProblem(trajectories, tlist; kwargs...)


function Base.summary(io::IO, problem::ControlProblem)
    N = length(problem.trajectories)
    nt = length(problem.tlist)
    print(io, "ControlProblem with $N trajectories and $nt time steps")
end


function Base.show(io::IO, mime::MIME"text/plain", problem::ControlProblem)
    println(io, summary(problem))
    println(io, "  trajectories:")
    for traj in problem.trajectories
        println(io, "    ", summary(traj))
    end
    t = problem.tlist
    if length(t) > 5
        println(io, "  tlist: [", t[begin], ", ", t[begin+1], " … ", t[end], "]")
    else
        print(io, "  tlist: ")
        show(io, t)
        print(io, "\n")
    end
    if !isempty(problem.kwargs)
        println(io, "  kwargs:")
        buffer = IOBuffer()
        show(buffer, mime, problem.kwargs)
        for line in split(String(take!(buffer)), "\n")[2:end]
            println(io, "  ", line)
        end

    end
end

function Base.copy(problem::ControlProblem)
    return ControlProblem(problem.trajectories, problem.tlist; problem.kwargs...)
end


"""
```julia
controls = get_controls(problem)
```

extracts the controls from `problem.trajectories`.
"""
get_controls(problem::ControlProblem) = get_controls(problem.trajectories)


"""
```julia
parameters = get_parameters(problem)
```

extracts the `parameters` from `problem.trajectories`.
"""
get_parameters(problem::ControlProblem) = get_parameters(problem.trajectories)


"""
```julia
problem = substitute(problem::ControlProblem, replacements)
```

substitutes in `problem.trajectories`
"""
function substitute(problem::ControlProblem, replacements)
    return ControlProblem(
        substitute(problem.trajectories, replacements),
        problem.tlist;
        problem.kwargs...
    )

end
