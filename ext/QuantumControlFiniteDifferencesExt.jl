module QuantumControlFiniteDifferencesExt

using LinearAlgebra

import FiniteDifferences
import QuantumControl.Functionals: make_gate_chi


function make_gate_chi(J_T_U, trajectories, ::Val{:FiniteDifferences}; kwargs...)

    N = length(trajectories)
    basis = [traj.initial_state for traj in trajectories]

    function fdm_gate_chi!(χ, ϕ, trajectories; τ=nothing)
        function _J_T(U)
            -J_T_U(U; kwargs...)
        end
        U = [basis[i] ⋅ ϕ[j] for i = 1:N, j = 1:N]
        fdm = FiniteDifferences.central_fdm(5, 1)
        ∇J = FiniteDifferences.grad(fdm, gate -> _J_T(gate), U)[1]
        for k = 1:N
            χ[k] .= 0.5 * sum([∇J[i, k] * basis[i] for i = 1:N])
        end
    end

    return fdm_gate_chi!

end

end
