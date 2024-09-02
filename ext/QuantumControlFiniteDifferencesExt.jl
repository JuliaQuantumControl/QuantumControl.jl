module QuantumControlFiniteDifferencesExt

using LinearAlgebra

import FiniteDifferences
import QuantumControl.Functionals:
    _default_chi_via, make_gate_chi, make_automatic_chi, make_automatic_grad_J_a


function make_automatic_chi(
    J_T,
    trajectories,
    ::Val{:FiniteDifferences};
    via=_default_chi_via(trajectories)
)

    # TODO: Benchmark if χ should be closure, see QuantumControlZygoteExt.jl

    function fdm_chi_via_states(Ψ, trajectories)
        function _J_T(Ψ...)
            -J_T(Ψ, trajectories)
        end
        fdm = FiniteDifferences.central_fdm(5, 1)
        χ = Vector{eltype(Ψ)}(undef, length(Ψ))
        ∇J = FiniteDifferences.grad(fdm, _J_T, Ψ...)
        for (k, ∇Jₖ) ∈ enumerate(∇J)
            χ[k] = 0.5 * ∇Jₖ  # ½ corrects for gradient vs Wirtinger deriv
            # axpby!(0.5, ∇Jₖ, false, χ[k])
        end
        return χ
    end

    function fdm_chi_via_tau(Ψ, trajectories; tau=nothing, τ=tau)
        if isnothing(τ)
            msg = "`chi` returned by `make_chi` with `via=:tau` requires keyword argument tau/τ"
            throw(ArgumentError(msg))
        end
        function _J_T(τ...)
            -J_T(Ψ, trajectories; tau=τ)
        end
        fdm = FiniteDifferences.central_fdm(5, 1)
        χ = Vector{eltype(Ψ)}(undef, length(Ψ))
        ∇J = FiniteDifferences.grad(fdm, _J_T, τ...)
        for (k, traj) ∈ enumerate(trajectories)
            ∂J╱∂τ̄ₖ = 0.5 * ∇J[k]  # ½ corrects for gradient vs Wirtinger deriv
            χ[k] = ∂J╱∂τ̄ₖ * traj.target_state
            # axpby!(∂J╱∂τ̄ₖ, traj.target_state, false, χ[k])
        end
        return χ
    end

    if via ≡ :states
        return fdm_chi_via_states
    elseif via ≡ :tau
        Ψ_tgt = [traj.target_state for traj in trajectories]
        if any(isnothing.(Ψ_tgt))
            error("`via=:tau` requires that all trajectories define a `target_state`")
        end
        τ_tgt = ones(ComplexF64, length(trajectories))
        Ψ_undef = similar(Ψ_tgt)
        if abs(J_T(Ψ_tgt, trajectories) - J_T(Ψ_undef, trajectories; tau=τ_tgt)) > 1e-12
            msg = "`via=:tau` in `make_chi` requires that `J_T`=$(repr(J_T)) can be evaluated solely via `tau`"
            error(msg)
        end
        return fdm_chi_via_tau
    else
        msg = "`via` must be either `:states` or `:tau`, not $(repr(via))"
        throw(ArgumentError(msg))
    end

end


function make_automatic_grad_J_a(J_a, tlist, ::Val{:FiniteDifferences})
    function automatic_grad_J_a!(∇J_a, pulsevals, tlist)
        func = pulsevals -> J_a(pulsevals, tlist)
        fdm = FiniteDifferences.central_fdm(5, 1)
        ∇J_a_fdm = FiniteDifferences.grad(fdm, func, pulsevals)[1]
        copyto!(∇J_a, ∇J_a_fdm)
    end
    return automatic_grad_J_a!
end

function make_gate_chi(J_T_U, trajectories, ::Val{:FiniteDifferences}; kwargs...)

    function fdm_gate_chi(Ψ, trajectories)
        function _J_T(U)
            -J_T_U(U; kwargs...)
        end
        N = length(trajectories)
        χ = Vector{eltype(Ψ)}(undef, N)
        # We assume that that the initial states of the trajectories are the
        # logical basis states
        U = [trajectories[i].initial_state ⋅ Ψ[j] for i = 1:N, j = 1:N]
        fdm = FiniteDifferences.central_fdm(5, 1)
        ∇J = FiniteDifferences.grad(fdm, gate -> _J_T(gate), U)[1]
        for k = 1:N
            χ[k] = 0.5 * sum([∇J[i, k] * trajectories[i].initial_state for i = 1:N])
        end
        return χ
    end

    return fdm_gate_chi

end

end
