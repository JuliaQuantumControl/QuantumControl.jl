module QuantumControlZygoteExt

using LinearAlgebra

import Zygote
import QuantumControl.Functionals: make_gate_chi


function make_gate_chi(J_T_U, trajectories, ::Val{:Zygote}; kwargs...)

    N = length(trajectories)
    basis = [traj.initial_state for traj in trajectories]

    function zygote_gate_chi!(χ, ϕ, trajectories; τ=nothing)
        function _J_T(U)
            -J_T_U(U; kwargs...)
        end
        U = [basis[i] ⋅ ϕ[j] for i = 1:N, j = 1:N]
        ∇J = Zygote.gradient(gate -> _J_T(gate), U)[1]
        for k = 1:N
            χ[k] .= 0.5 * sum([∇J[i, k] * basis[i] for i = 1:N])
        end
    end

    return zygote_gate_chi!

end

end
