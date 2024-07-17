module QuantumControlZygoteExt

using LinearAlgebra

import Zygote
import QuantumControl.Functionals: make_gate_chi


function make_gate_chi(J_T_U, trajectories, ::Val{:Zygote}; kwargs...)

    function zygote_gate_chi(Ψ, trajectories)
        function _J_T(U)
            -J_T_U(U; kwargs...)
        end
        N = length(trajectories)
        χ = Vector{eltype(Ψ)}(undef, N)
        # We assume that that the initial states of the trajectories are the
        # logical basis states
        U = [trajectories[i].initial_state ⋅ Ψ[j] for i = 1:N, j = 1:N]
        ∇J = Zygote.gradient(gate -> _J_T(gate), U)[1]
        for k = 1:N
            χ[k] = 0.5 * sum([∇J[i, k] * trajectories[i].initial_state for i = 1:N])
        end
        return χ
    end

    return zygote_gate_chi

end

end
