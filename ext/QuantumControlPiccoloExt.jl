module QuantumControlPiccoloExt

import QuantumControl

using Piccolo: QuantumSystem

function QuantumControl.optimize(problem, method::Val{:Piccolo})
    return piccolo_optimize(problem.trajectories, problem.tlist; problem.kwargs...)
end


function piccolo_optimize(trajectories, tlist; kwargs...)

    if length(trajectories) == 1
        return piccolo_optimize1(trajectories[1], tlist; kwargs...)
    else
        error("Multiple trajectories are currently not implemented for Piccolo")
    end

end

function piccolo_optimize1(trajectory, tlist; kwargs...)
    sys = QuantumSystem(H_drift, H_drives, drive_bounds)
end

end
