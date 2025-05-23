module Functionals

export J_T_ss, J_T_sm, J_T_re
export J_a_fluence
export gate_functional
export make_gate_chi
export make_grad_J_a, make_chi

using LinearAlgebra: axpy!, dot


# default for `via` argument of `make_chi`
function _default_chi_via(trajectories)
    if any(isnothing(traj.target_state) for traj in trajectories)
        return :states
    else
        return :tau
    end
end


"""Overlaps of target states with propagates states

```julia
τ = taus(Ψ, trajectories)
```

calculates a vector of values ``τ_k = ⟨Ψ_k^{tgt}|Ψ_k⟩`` where ``|Ψ_k^{tgt}⟩``
is the `traj.target_state` of the ``k``'th element of `trajectories` and
``|Ψₖ⟩`` is the ``k``'th element of `Ψ`.

The definition of the τ values with ``Ψ_k^{tgt}`` on the left (overlap of
target states with propagated states, as opposed to overlap of propagated
states with target states) matches Refs. [PalaoPRA2003](@cite)
and [GoerzQ2022](@cite).

The function requires that each trajectory defines a target state.
See also [`taus!`](@ref) for an in-place version that includes well-defined
error handling for any trajectories whose `target_state` property is `nothing`.
"""
function taus(Ψ, trajectories)
    # This function does not delegate to `taus!`, in order to make it
    # compatible with automatic differentiation, which doesn't support
    # mutation.
    return [dot(traj.target_state, Ψₖ) for (traj, Ψₖ) in zip(trajectories, Ψ)]
end


"""Overlaps of target states with propagates states, calculated in-place.

```julia
taus!(τ, Ψ, trajectories; ignore_missing_target_state=false)
```

overwrites the complex vector `τ` with the results of
[`taus(Ψ, trajectories)`](@ref taus).

Throws an `ArgumentError` if any of trajectories have a `target_state` of
`nothing`. If `ignore_missing_target_state=true`, values in `τ` instead will
remain unchanged for any trajectories with a missing target state.
"""
function taus!(τ::Vector{ComplexF64}, Ψ, trajectories; ignore_missing_target_state=false)
    for (k, (traj, Ψₖ)) in enumerate(zip(trajectories, Ψ))
        if !isnothing(traj.target_state)
            τ[k] = dot(traj.target_state, Ψₖ)
        else
            # With `ignore_missing_target_state=true`, we just skip the value.
            # This makes `taus!` convenient for calculating τ values in
            # Krotov/GRAPE if and only if the function is based on target
            # states
            if !ignore_missing_target_state
                msg = "trajectory[$k] has no `target_state`. Cannot calculate τ = ⟨Ψ_tgt|Ψ⟩"
                throw(ArgumentError(msg))
            end
        end
    end

end


@doc raw"""Return a function that calculates ``|χ_k⟩ = -∂J_T/∂⟨Ψ_k|``.

```julia
chi = make_chi(
    J_T,
    trajectories;
    mode=:any,
    automatic=:default,
    via=(any(isnothing(t.target_state) for t in trajectories) ? :states : :tau),
)
```

creates a function `chi(Ψ, trajectories; τ)` that returns
a vector of states `χ` with ``|χ_k⟩ = -∂J_T/∂⟨Ψ_k|``, where ``|Ψ_k⟩`` is the
k'th element of `Ψ`. These are the states used as the boundary condition for
the backward propagation propagation in Krotov's method and GRAPE. Each
``|χₖ⟩`` is defined as a matrix calculus
[Wirtinger derivative](https://www.ekinakyurek.me/complex-derivatives-wirtinger/),

```math
|χ_k(T)⟩ = -\frac{∂J_T}{∂⟨Ψ_k|} = -\frac{1}{2} ∇_{Ψ_k} J_T\,;\qquad
∇_{Ψ_k} J_T ≡ \frac{∂J_T}{\Re[Ψ_k]} + i \frac{∂J_T}{\Im[Ψ_k]}\,.
```

The function `J_T` must take a vector of states `Ψ` and a vector of
`trajectories` as positional parameters. If `via=:tau`, it must also a vector
`tau` as a keyword argument, see e.g. `J_T_sm`).
that contains the overlap of the states `Ψ` with the target states from the `trajectories`

The derivative can be calculated analytically of automatically (via automatic
differentiation) depending on the value of `mode`. For `mode=:any`, an analytic
derivative is returned if available, with a fallback to an automatic derivative.

If `mode=:analytic`, return an analytically known ``-∂J_T/∂⟨Ψ_k|``, e.g.,

* [`QuantumControl.Functionals.J_T_sm`](@ref) → [`QuantumControl.Functionals.chi_sm`](@ref),
* [`QuantumControl.Functionals.J_T_re`](@ref) → [`QuantumControl.Functionals.chi_re`](@ref),
* [`QuantumControl.Functionals.J_T_ss`](@ref) → [`QuantumControl.Functionals.chi_ss`](@ref).

and throw an error if no analytic derivative is known.

If `mode=:automatic`, return an automatic derivative (even if an analytic
derivative is known). The calculation of an automatic derivative  (whether via
`mode=:any` or `mode=:automatic`) requires that a suitable framework (e.g.,
`Zygote` or `FiniteDifferences`) has been loaded. The loaded module must be
passed as `automatic` keyword argument. Alternatively, it can be registered as
a default value for `automatic` by calling
`QuantumControl.set_default_ad_framework`.

When evaluating ``|χ_k⟩`` automatically, if `via=:states` is given , ``|χ_k(T)⟩``
is calculated directly as defined above from the gradient with respect to
the states ``\{|Ψ_k(T)⟩\}``.

If `via=:tau` is given instead, the functional ``J_T`` is considered a function
of overlaps ``τ_k = ⟨Ψ_k^\tgt|Ψ_k(T)⟩``. This requires that all `trajectories`
define a `target_state` and that `J_T` calculates the value of the functional
solely based on the values of `tau` passed as a keyword argument.  With only
the complex conjugate ``τ̄_k = ⟨Ψ_k(T)|Ψ_k^\tgt⟩`` having an explicit dependency
on ``⟨Ψ_k(T)|``,  the chain rule in this case is

```math
|χ_k(T)⟩
= -\frac{∂J_T}{∂⟨Ψ_k|}
= -\left(
    \frac{∂J_T}{∂τ̄_k}
    \frac{∂τ̄_k}{∂⟨Ψ_k|}
  \right)
= - \frac{1}{2} (∇_{τ_k} J_T) |Ψ_k^\tgt⟩\,.
```

Again, we have used the definition of the Wirtinger derivatives,

```math
\begin{align*}
    \frac{∂J_T}{∂τ_k}
    &≡ \frac{1}{2}\left(
        \frac{∂ J_T}{∂ \Re[τ_k]}
        - i \frac{∂ J_T}{∂ \Im[τ_k]}
    \right)\,,\\
    \frac{∂J_T}{∂τ̄_k}
    &≡ \frac{1}{2}\left(
        \frac{∂ J_T}{∂ \Re[τ_k]}
        + i \frac{∂ J_T}{∂ \Im[τ_k]}
    \right)\,,
\end{align*}
```

and the definition of the Zygote gradient with respect to a complex scalar,

```math
∇_{τ_k} J_T = \left(
    \frac{∂ J_T}{∂ \Re[τ_k]}
    + i \frac{∂ J_T}{∂ \Im[τ_k]}
\right)\,.
```

!!! tip

    In order to extend `make_chi` with an analytic implementation for a new
    `J_T` function, define a new method `make_analytic_chi` like so:

    ```julia
    QuantumControl.Functionals.make_analytic_chi(::typeof(J_T_sm), trajectories) = chi_sm
    ```

    which links `make_chi` for [`QuantumControl.Functionals.J_T_sm`](@ref)
    to [`QuantumControl.Functionals.chi_sm`](@ref).


!!! warning

    Zygote is notorious for being buggy (silently returning incorrect
    gradients). Always test automatic derivatives against finite differences
    and/or other automatic differentiation frameworks.
"""
function make_chi(
    J_T,
    trajectories;
    mode=:any,
    automatic=:default,
    via=_default_chi_via(trajectories),
)
    if mode == :any
        try
            chi = make_analytic_chi(J_T, trajectories)
            @debug "make_chi for J_T=$(J_T) -> analytic"
            # TODO: call chi to compile it and ensure required properties
            return chi
        catch exception
            if exception isa MethodError
                @info "make_chi for J_T=$(J_T): fallback to mode=:automatic"
                try
                    chi = make_automatic_chi(J_T, trajectories, automatic; via)
                    # TODO: call chi to compile it and ensure required properties
                    return chi
                catch exception
                    if exception isa MethodError
                        msg = "make_chi for J_T=$(J_T): no analytic gradient, and no automatic gradient with `automatic=$(repr(automatic))`."
                        error(msg)
                    else
                        rethrow()
                    end
                end
            else
                rethrow()
            end
        end
    elseif mode == :analytic
        try
            chi = make_analytic_chi(J_T, trajectories)
            # TODO: call chi to compile it and ensure required properties
            return chi
        catch exception
            if exception isa MethodError
                msg = "make_chi for J_T=$(J_T): no analytic gradient. Implement `QuantumControl.Functionals.make_analytic_chi(::typeof(J_T), trajectories)`"
                error(msg)
            else
                rethrow()
            end
        end
    elseif mode == :automatic
        try
            chi = make_automatic_chi(J_T, trajectories, automatic; via)
            # TODO: call chi to compile it and ensure required properties
            return chi
        catch exception
            if exception isa MethodError
                msg = "make_chi for J_T=$(J_T): no automatic gradient with `automatic=$(repr(automatic))`."
                error(msg)
            else
                rethrow()
            end
        end
    else
        msg = "`mode=$(repr(mode))` must be one of :any, :analytic, :automatic"
        throw(ArgumentError(msg))
    end
end


# Generic placeholder
function make_analytic_chi end


# Module to Symbol-Val
function make_automatic_chi(J_T, trajectories, automatic::Module; via)
    return make_automatic_chi(J_T, trajectories, Val(nameof(automatic)); via)
end

# Symbol to Symbol-Val
function make_automatic_chi(J_T, trajectories, automatic::Symbol; via)
    return make_automatic_chi(J_T, trajectories, Val(automatic); via)
end


DEFAULT_AD_FRAMEWORK = :nothing

function make_automatic_chi(J_T, trajectories, ::Val{:default}; via)
    if DEFAULT_AD_FRAMEWORK == :nothing
        msg = "make_chi: no default `automatic`. You must run `QuantumControl.set_default_ad_framework` first, e.g. `import Zygote; QuantumControl.set_default_ad_framework(Zygote)`."
        error(msg)
    else
        automatic = DEFAULT_AD_FRAMEWORK
        chi = make_automatic_chi(J_T, trajectories, DEFAULT_AD_FRAMEWORK; via)
        (string(automatic) == "default") && error("automatic fallback")
        @info "make_chi for J_T=$(J_T): automatic with $automatic"
        return chi
    end
end


# There is a user-facing wrapper `QuantumControl.set_default_ad_framework`.
# See the documentation there.
function _set_default_ad_framework(mod::Module; quiet=false)
    global DEFAULT_AD_FRAMEWORK
    automatic = nameof(mod)
    if !quiet
        @info "QuantumControl: Setting $automatic as the default provider for automatic differentiation."
    end
    DEFAULT_AD_FRAMEWORK = automatic
    return nothing
end


function _set_default_ad_framework(::Nothing; quiet=false)
    global DEFAULT_AD_FRAMEWORK
    if !quiet
        @info "Unsetting the default provider for automatic differentiation."
    end
    DEFAULT_AD_FRAMEWORK = :nothing
    return nothing
end



"""
Return a function to evaluate ``∂J_a/∂ϵ_{ln}`` for a pulse value running cost.

```julia
grad_J_a = make_grad_J_a(
    J_a,
    tlist;
    mode=:any,
    automatic=:default,
)
```

returns a function so that `∇J_a = grad_J_a(pulsevals, tlist)` sets
that returns a vector `∇J_a` containing the vectorized elements
``∂J_a/∂ϵ_{ln}``. The function `J_a` must have the interface `J_a(pulsevals,
tlist)`, see, e.g., [`J_a_fluence`](@ref).

The parameters `mode` and `automatic` are handled as in [`make_chi`](@ref),
where `mode` is one of `:any`, `:analytic`, `:automatic`, and `automatic` is
he loaded module of an automatic differentiation framework, where `:default`
refers to the framework set with `QuantumControl.set_default_ad_framework`.

!!! tip

    In order to extend `make_grad_J_a` with an analytic implementation for a
    new `J_a` function, define a new method `make_analytic_grad_J_a` like so:

    ```julia
    make_analytic_grad_J_a(::typeof(J_a_fluence), tlist) = grad_J_a_fluence
    ```

    which links `make_grad_J_a` for [`J_a_fluence`](@ref) to
    [`grad_J_a_fluence`](@ref).
"""
function make_grad_J_a(J_a, tlist; mode=:any, automatic=:default)
    if mode == :any
        try
            grad_J_a = make_analytic_grad_J_a(J_a, tlist)
            @debug "make_grad_J_a for J_a=$(J_a) -> analytic"
            return grad_J_a
        catch exception
            if exception isa MethodError
                @info "make_grad_J_a for J_a=$(J_a): fallback to mode=:automatic"
                try
                    grad_J_a = make_automatic_grad_J_a(J_a, tlist, automatic)
                    return grad_J_a
                catch exception
                    if exception isa MethodError
                        msg = "make_grad_J_a for J_a=$(J_a): no analytic gradient, and no automatic gradient with `automatic=$(repr(automatic))`."
                        error(msg)
                    else
                        rethrow()
                    end
                end
            else
                rethrow()
            end
        end
    elseif mode == :analytic
        try
            return make_analytic_grad_J_a(J_a, tlist)
        catch exception
            if exception isa MethodError
                msg = "make_grad_J_a for J_a=$(J_a): no analytic gradient. Implement `QuantumControl.Functionals.make_analytic_grad_J_a(::typeof(J_a), tlist)`"
                error(msg)
            else
                rethrow()
            end
        end
    elseif mode == :automatic
        try
            return make_automatic_grad_J_a(J_a, tlist, automatic)
        catch exception
            if exception isa MethodError
                msg = "make_grad_J_a for J_a=$(J_a): no automatic gradient with `automatic=$(repr(automatic))`."
                error(msg)
            else
                rethrow()
            end
        end
    else
        msg = "`mode=$(repr(mode))` must be one of :any, :analytic, :automatic"
        throw(ArgumentError(msg))
    end
end


function make_automatic_grad_J_a(J_a, tlist, ::Val{:default})
    if DEFAULT_AD_FRAMEWORK == :nothing
        msg = "make_automatic_grad_J_a: no default `automatic`. You must run `set_default_ad_framework` first, e.g. `import Zygote; QuantumControl.set_default_ad_framework(Zygote)`."
        error(msg)
    else
        automatic = DEFAULT_AD_FRAMEWORK
        grad_J_a = make_automatic_grad_J_a(J_a, tlist, DEFAULT_AD_FRAMEWORK)
        @info "make_grad_J_a for J_a=$(J_a): automatic with $automatic"
        return grad_J_a
    end
end

# Generic placeholder
function make_analytic_grad_J_a end

# Module to Symbol-Val
function make_automatic_grad_J_a(J_a, tlist, automatic::Module)
    return make_automatic_grad_J_a(J_a, tlist, Val(nameof(automatic)))
end

# Symbol to Symbol-Val
function make_automatic_grad_J_a(J_a, tlist, automatic::Symbol)
    return make_automatic_grad_J_a(J_a, tlist, Val(automatic))
end




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
internally, see [`taus`](@ref).

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
        if DEFAULT_AD_FRAMEWORK == :nothing
            msg = "make_gate_chi: no default `automatic`. You must run `set_default_ad_framework` first, e.g. `import Zygote; QuantumControl.set_default_ad_framework(Zygote)`."
            error(msg)
        else
            automatic = DEFAULT_AD_FRAMEWORK
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
∇J_a = grad_J_a_fluence(pulsevals, tlist)
```

returns the `∇J_a`, which contains the (vectorized) elements ``2 ϵ_{nl} dt``,
where ``ϵ_{nl}`` are the (vectorized) elements of `pulsevals` and ``dt`` is the
time step, taken from the first time interval of `tlist` and assumed to be
uniform.
"""
function grad_J_a_fluence(pulsevals, tlist)
    dt = tlist[begin+1] - tlist[begin]
    return (2 * dt) * pulsevals
end


make_analytic_grad_J_a(::typeof(J_a_fluence), tlist) = grad_J_a_fluence

end
