# COV_EXCL_START
OBJECTIVE_MSG = """
`Objective` has been renamed to `Trajectory`. This also affects related
parts of the API. for examples, `propagate_objectives` has been renamed to
`propagate_trajectories` and the `objectives` keyword argument in
`ControlProblem` is now as `trajectories` keyword or positional argument.
"""

DEPRECATED = [:Objective, :propagate_objectives]

function Objective(args...; kwargs...)
    @error OBJECTIVE_MSG
    return Trajectory(args...; kwargs...)
end

function propagate_objectives(args...; kwargs...)
    @error OBJECTIVE_MSG
    return propagate_trajectories(args...; kwargs...)
end

export Objective
export propagate_objectives
# COV_EXCL_STOP
