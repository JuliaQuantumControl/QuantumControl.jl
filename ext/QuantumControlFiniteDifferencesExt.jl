module QuantumControlFiniteDifferencesExt

using LinearAlgebra

import FiniteDifferences
import QuantumControl.Functionals: make_gate_chi


function make_gate_chi(J_T_U, objectives, ::Val{:FiniteDifferences}; kwargs...)

    N = length(objectives)
    basis = [obj.initial_state for obj in objectives]

    function fdm_gate_chi!(χ, ϕ, objectives; τ=nothing)
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
