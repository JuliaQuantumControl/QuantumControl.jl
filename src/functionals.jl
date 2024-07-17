module Functionals

export J_T_ss, J_T_sm, J_T_re
export J_a_fluence
export gate_functional
export make_gate_chi

using QuantumControlBase: QuantumControlBase, make_grad_J_a, make_chi, taus
export make_grad_J_a, make_chi

using LinearAlgebra: axpy!, dot
import QuantumControlBase: make_analytic_grad_J_a, make_analytic_chi


@doc raw"""
Average complex overlap of the target states with forward-propagated states.

```julia
f_tau(Ψ, trajectories; tau=taus(Ψ, trajectories), τ=tau)
```

calculates

```math
f_τ = \frac{1}{N} \sum_{k=1}^{N} w_k τ_k
```

with

```math
τ_k = ⟨Ψ_k^\tgt|Ψ_k(T)⟩
```

in Hilbert space, or

```math
τ_k = \tr[ρ̂_k^{\tgt\,\dagger} ρ̂_k(T)]
```

in Liouville space, where ``|Ψ_k⟩`` or ``ρ̂_k`` are the elements
of `Ψ`, and ``|Ψ_k^\tgt⟩`` or ``ρ̂_k^\tgt`` are the
target states from the `target_state` field of the `trajectories`. If `tau`/`τ`
is given as a keyword argument, it must contain the values `τ_k` according to
the above definition. Otherwise, the ``τ_k`` values will be calculated
internally, see [`QuantumControlBase.taus`](@ref).

``N`` is the number of trajectories, and ``w_k`` is the `weight` attribute for
each trajectory. The weights are not automatically
normalized, they are assumed to have values such that the resulting ``f_τ``
lies in the unit circle of the complex plane. Usually, this means that the
weights should sum to ``N``.

# Reference

* [PalaoPRA2003](@cite) Palao and Kosloff,  Phys. Rev. A 68, 062308 (2003)
"""
function f_tau(Ψ, trajectories; tau=nothing, τ=tau)
    N = length(trajectories)
    if τ === nothing
        # If we did this in the function header, we'd redundandly call `taus`
        # if the function was called with the keyword parameter τ
        τ = taus(Ψ, trajectories)
    end
    f::ComplexF64 = 0
    for (traj, τₖ) in zip(trajectories, τ)
        w = traj.weight
        f += w * τₖ
    end
    return f / N
end


@doc raw"""State-to-state phase-insensitive fidelity.

```julia
F_ss(Ψ, trajectories; tau=taus(Ψ, trajectories), τ=tau)
```

calculates

```math
F_{\text{ss}} = \frac{1}{N} \sum_{k=1}^{N} w_k |τ_k|^2 \quad\in [0, 1]
```

with ``N``, ``w_k`` and ``τ_k`` as in [`f_tau`](@ref).

# Reference

* [PalaoPRA2003](@cite) Palao and Kosloff,  Phys. Rev. A 68, 062308 (2003)
"""
function F_ss(Ψ, trajectories; tau=nothing, τ=tau)
    N = length(trajectories)
    if τ === nothing
        τ = taus(Ψ, trajectories)
    end
    f::Float64 = 0
    for (traj, τₖ) in zip(trajectories, τ)
        w = traj.weight
        f += w * abs2(τₖ)
    end
    return f / N
end

@doc raw"""State-to-state phase-insensitive functional.

```julia
J_T_ss(Ψ, trajectories; tau=taus(Ψ, trajectories); τ=tau)
```

calculates

```math
J_{T,\text{ss}} = 1 - F_{\text{ss}} \in [0, 1].
```

All arguments are passed to [`F_ss`](@ref).

# Reference

* [PalaoPRA2003](@cite) Palao and Kosloff,  Phys. Rev. A 68, 062308 (2003)
"""
function J_T_ss(Ψ, trajectories; tau=nothing, τ=tau)
    return 1.0 - F_ss(Ψ, trajectories; τ=τ)
end


@doc raw"""Backward boundary states ``|χ⟩`` for functional [`J_T_ss`](@ref).

```julia
χ = chi_ss(Ψ, trajectories; tau=taus(Ψ, trajectories), τ=tau)
```

calculates the vector of states `χ` according to

```math
|χ_k⟩
= -\frac{∂ J_{T,\text{ss}}}{∂ ⟨Ψ_k(T)|}
= \frac{1}{N} w_k τ_k |Ψ^{\tgt}_k⟩\,,
```

with ``|Ψ^{\tgt}_k⟩``, ``τ_k`` and ``w_k`` as defined in [`f_tau`](@ref).

Note: this function can be obtained with `make_chi(J_T_ss, trajectories)`.
"""
function chi_ss(Ψ, trajectories; tau=nothing, τ=tau)
    N = length(trajectories)
    if τ === nothing
        τ = taus(Ψ, trajectories)
    end
    χ = Vector{eltype(Ψ)}(undef, length(Ψ))
    for (k, traj) in enumerate(trajectories)
        w = traj.weight
        Ψₖ_tgt = traj.target_state
        χ[k] = (τ[k] * w) / N * Ψₖ_tgt
    end
    return χ
end

make_analytic_chi(::typeof(J_T_ss), trajectories) = chi_ss
# TODO: consider an in-place version of `chi_ss` if the states are mutable


@doc raw"""Square-modulus fidelity.

```julia
F_sm(Ψ, trajectories; tau=taus(Ψ, trajectories), τ=tau)
```

calculates

```math
F_{\text{sm}}
    = |f_τ|^2
    = \left\vert\frac{1}{N} \sum_{k=1}^{N} w_k τ_k\right\vert^2
    = \frac{1}{N^2} \sum_{k=1}^{N} \sum_{j=1}^{N} w_k w_j τ̄_k τ_j
    \quad\in [0, 1]\,,
```

with ``w_k`` the weight for the k'th trajectory and ``τ_k`` the overlap of the
k'th propagated state with the k'th target state, ``τ̄_k`` the complex conjugate
of ``τ_k``, and ``N`` the number of trajectories.

All arguments are passed to [`f_tau`](@ref) to evaluate ``f_τ``.

# Reference

* [PalaoPRA2003](@cite) Palao and Kosloff,  Phys. Rev. A 68, 062308 (2003)
"""
function F_sm(Ψ, trajectories; tau=nothing, τ=tau)
    return abs2(f_tau(Ψ, trajectories; τ=τ))
end


@doc raw"""Square-modulus functional.

```julia
J_T_sm(Ψ, trajectories; tau=taus(Ψ, trajectories), τ=tau)
```

calculates

```math
J_{T,\text{sm}} = 1 - F_{\text{sm}} \quad\in [0, 1].
```

All arguments are passed to [`f_tau`](@ref) while evaluating ``F_{\text{sm}}``
in [`F_sm`](@ref).

# Reference

* [PalaoPRA2003](@cite) Palao and Kosloff,  Phys. Rev. A 68, 062308 (2003)
"""
function J_T_sm(Ψ, trajectories; tau=nothing, τ=tau)
    return 1.0 - F_sm(Ψ, trajectories; τ=τ)
end


@doc raw"""Backward boundary states ``|χ⟩`` for functional [`J_T_sm`](@ref).

```julia
χ = chi_sm(Ψ, trajectories; tau=taus(Ψ, trajectories), τ=tau)
```

calculates the vector of states `χ` according to

```math
|χ_k⟩
= -\frac{\partial J_{T,\text{sm}}}{\partial ⟨Ψ_k(T)|}
= \frac{1}{N^2} w_k \sum_{j}^{N} w_j τ_j |Ψ_k^{\tgt}⟩
```

with ``|Ψ^{\tgt}_k⟩``, ``τ_j`` and ``w_k`` as defined in [`f_tau`](@ref).

Note: this function can be obtained with `make_chi(J_T_sm, trajectories)`.
"""
function chi_sm(Ψ, trajectories; tau=nothing, τ=tau)
    N = length(trajectories)
    if τ === nothing
        τ = taus(Ψ, trajectories)
    end
    w = [traj.weight for traj in trajectories]
    a = sum(w .* τ) / N^2
    χ = Vector{eltype(Ψ)}(undef, length(Ψ))
    for (k, traj) in enumerate(trajectories)
        Ψₖ_tgt = traj.target_state
        χ[k] = w[k] * a * Ψₖ_tgt
    end
    return χ
end

make_analytic_chi(::typeof(J_T_sm), trajectories) = chi_sm
# TODO: consider in-place version


@doc raw"""Real-part fidelity.

```julia
F_re(Ψ, trajectories; tau=taus(Ψ, trajectories), τ=tau)
```

calculates

```math
F_{\text{re}}
    = \Re[f_{τ}]
    = \Re\left[
        \frac{1}{N} \sum_{k=1}^{N} w_k τ_k
    \right]
    \quad\in \begin{cases}
    [-1, 1] & \text{in Hilbert space} \\
    [0, 1] & \text{in Liouville space.}
\end{cases}
```

with ``w_k`` the weight for the k'th trajectory and ``τ_k`` the overlap of the
k'th propagated state with the k'th target state, and ``N`` the number of
trajectories.

All arguments are passed to [`f_tau`](@ref) to evaluate ``f_τ``.

# Reference

* [PalaoPRA2003](@cite) Palao and Kosloff,  Phys. Rev. A 68, 062308 (2003)
"""
function F_re(Ψ, trajectories; tau=nothing, τ=tau)
    return real(f_tau(Ψ, trajectories; τ=τ))
end


@doc raw"""Real-part functional.

```julia
J_T_re(Ψ, trajectories; tau=taus(Ψ, trajectories), τ=tau)
```

calculates

```math
J_{T,\text{re}} = 1 - F_{\text{re}} \quad\in \begin{cases}
    [0, 2] & \text{in Hilbert space} \\
    [0, 1] & \text{in Liouville space.}
\end{cases}
```

All arguments are passed to [`f_tau`](@ref) while evaluating ``F_{\text{re}}``
in [`F_re`](@ref).

# Reference

* [PalaoPRA2003](@cite) Palao and Kosloff,  Phys. Rev. A 68, 062308 (2003)
"""
function J_T_re(Ψ, trajectories; tau=nothing, τ=tau)
    return 1.0 - F_re(Ψ, trajectories; τ=τ)
end


@doc raw"""Backward boundary states ``|χ⟩`` for functional [`J_T_re`](@ref).

```julia
χ chi_re(Ψ, trajectories; tau=taus(Ψ, trajectories), τ=tau)
```

calculates the vector of states `χ` according to


```math
|χ_k⟩
= -\frac{∂ J_{T,\text{re}}}{∂ ⟨Ψ_k(T)|}
= \frac{1}{2N} w_k |Ψ^{\tgt}_k⟩
```

with ``|Ψ^{\tgt}_k⟩`` and ``w_k`` as defined in [`f_tau`](@ref).

Note: this function can be obtained with `make_chi(J_T_re, trajectories)`.
"""
function chi_re(Ψ, trajectories; tau=nothing, τ=tau)
    N = length(trajectories)
    if τ === nothing
        τ = taus(Ψ, trajectories)
    end
    χ = Vector{eltype(Ψ)}(undef, length(Ψ))
    for (k, traj) in enumerate(trajectories)
        Ψₖ_tgt = traj.target_state
        w = traj.weight
        χ[k] = (w / (2N)) * Ψₖ_tgt
    end
    return χ
end

make_analytic_chi(::typeof(J_T_re), trajectories) = chi_re
# TODO: consider in-place version


"""Convert a functional from acting on a gate to acting on propagated states.

```
J_T = gate_functional(J_T_U; kwargs...)
```

constructs a functional `J_T` that meets the requirements for
for Krotov/GRAPE and [`make_chi`](@ref). That is, the output `J_T` takes
positional positional arguments `Ψ` and `trajectories`. The input functional
`J_T_U` is assumed to have the signature `J_T_U(U; kwargs...)` where `U` is a
matrix with elements ``U_{ij} = ⟨Ψ_i|Ψ_j⟩``, where ``|Ψ_i⟩`` is the
`initial_state` of the i'th `trajectories` (assumed to be the i'th canonical
basis state) and ``|Ψ_j⟩`` is the result of forward-propagating ``|Ψ_j⟩``. That
is, `U` is the projection of the time evolution operator into the subspace
defined by the basis in the `initial_states` of the  `trajectories`.

# See also

* [`make_gate_chi`](@ref) — create a corresponding `chi` function that acts
  more efficiently than the general [`make_chi`](@ref).
"""
function gate_functional(J_T_U; kwargs...)

    function J_T(Ψ, trajectories)
        N = length(trajectories)
        U = [dot(trajectories[i].initial_state, Ψ[j]) for i = 1:N, j = 1:N]
        return J_T_U(U; kwargs...)
    end

    return J_T

end


@doc raw"""
Return a function to evaluate ``|χ_k⟩ = -∂J_T(Û)/∂⟨Ψ_k|`` via the chain rule.

```julia
chi = make_gate_chi(J_T_U, trajectories; automatic=:default, kwargs...)
```

returns a function equivalent to

```julia
chi = make_chi(
    gate_functional(J_T_U; kwargs...),
    trajectories;
    mode=:automatic,
    automatic,
)
```

```math
\begin{split}
    |χ_k⟩
    &= -\frac{∂}{∂⟨Ψ_k|} J_T \\
    &= - \frac{1}{2} \sum_i (∇_U J_T)_{ik} \frac{∂ U_{ik}}{∂⟨Ψ_k|} \\
    &= - \frac{1}{2} \sum_i (∇_U J_T)_{ik} |Ψ_i⟩
\end{split}
```

where ``|Ψ_i⟩`` is the basis state stored as the `initial_state` of the i'th
trajectory, see [`gate_functional`](@ref).

The gradient ``∇_U J_T`` is obtained via automatic differentiation (AD). This
requires that an AD package has been loaded (e.g., `using Zygote`). This
package must either be passed as the `automatic` keyword argument, or the
package must be set as the default AD provider using
[`QuantumControl.set_default_ad_framework`](@ref).

Compared to the more general [`make_chi`](@ref) with `mode=:automatic`,
`make_gate_chi` will generally have a slightly smaller numerical overhead, as
it pushes the use of automatic differentiation down by one level.
"""
function make_gate_chi(J_T_U, trajectories; automatic=:default, kwargs...)
    if automatic == :default
        if QuantumControlBase.DEFAULT_AD_FRAMEWORK == :nothing
            msg = "make_gate_chi: no default `automatic`. You must run `set_default_ad_framework` first, e.g. `import Zygote; QuantumControl.set_default_ad_framework(Zygote)`."
            error(msg)
        else
            automatic = QuantumControlBase.DEFAULT_AD_FRAMEWORK
            chi = make_gate_chi(J_T_U, trajectories, automatic; kwargs...)
            @info "make_gate_chi for J_T_U=$(J_T_U): automatic with $automatic"
            return chi
        end
    else
        return make_gate_chi(J_T_U, trajectories, automatic; kwargs...)
    end
end

function make_gate_chi(J_T_U, trajectories, automatic::Module; kwargs...)
    return make_gate_chi(J_T_U, trajectories, Val(nameof(automatic)); kwargs...)
end

function make_gate_chi(J_T_U, trajectories, automatic::Symbol; kwargs...)
    return make_gate_chi(J_T_U, trajectories, Val(automatic); kwargs...)
end


@doc raw"""Running cost for the pulse fluence.

```julia
J_a = J_a_fluence(pulsevals, tlist)
```

calculates

```math
J_a = \sum_l \int_0^T |ϵ_l(t)|^2 dt = \left(\sum_{nl} |ϵ_{nl}|^2 \right) dt
```

where ``ϵ_{nl}`` are the values in the (vectorized) `pulsevals`, `n` is the
index of the intervals of the time grid, and ``dt`` is the time step, taken
from the first time interval of `tlist` and assumed to be uniform.
"""
function J_a_fluence(pulsevals, tlist)
    dt = tlist[begin+1] - tlist[begin]
    return sum(abs2.(pulsevals)) * dt
end


"""Analytic derivative for [`J_a_fluence`](@ref).

```julia
grad_J_a_fluence!(∇J_a, pulsevals, tlist)
```

sets the (vectorized) elements of `∇J_a` to ``2 ϵ_{nl} dt``, where
``ϵ_{nl}`` are the (vectorized) elements of `pulsevals` and ``dt`` is the time
step, taken from the first time interval of `tlist` and assumed to be uniform.
"""
function grad_J_a_fluence!(∇J_a, pulsevals, tlist)
    dt = tlist[begin+1] - tlist[begin]
    axpy!(2 * dt, pulsevals, ∇J_a)
end


make_analytic_grad_J_a(::typeof(J_a_fluence), tlist) = grad_J_a_fluence!

end
