module QuantumControlZygoteExt

using LinearAlgebra

import Zygote
import QuantumControl.Functionals: make_gate_chi


function make_gate_chi(J_T_U, objectives, ::Val{:Zygote}; kwargs...)

    N = length(objectives)
    basis = [obj.initial_state for obj in objectives]

    function zygote_gate_chi!(χ, ϕ, objectives; τ=nothing)
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
