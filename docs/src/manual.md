# User Manual

The User Manual describes the API of the `QuantumControl` package by outlining the general procedure for defining and solving quantum control problems. See the [API](@ref) for a detailed reference.

## Setting up control problems

* [`ControlProblem`](@ref)
* [`Objective`](@ref)

## Nomenclature

In the context of the JuliaQuantumControl ecosystem, we apply the following nomenclature. We assume that the dynamical generator takes the form

```math
H = H_0 + \sum_l f(ϵ_l(t))) H_l
```

We call the total ``H`` the "generator" ("Hamiltonian/Liouvillian"). It generates the equation of motion as ``Ψ(t+dt) = e^{-i H dt} Ψ(t)``, in the limit of ``dt → 0`` if ``H`` is time-dependent. We also use the symbol ``G`` in the general case encompassing Hamiltonians and Liouvillians. For the individual terms, ``H_0`` is the "drift" ("drift generator/Hamiltonian/Liouvillian"), ``H_l`` is the "control generator" ("control Hamiltonian/Liouvillian"), and ``f(ϵ_l(t))`` the "control", or sometimes "control function" — but the controls need not be functions: they might also be arrays of pulse values, or custom objects. Lastly, the product ``f(ϵ_l(t)) H_l`` is the "control term". Method names should reflect this terminology.

In most cases, we have linear controls, i.e., ``f(ϵ_l(t)) == ϵ_l(t)``, but this is not a requirement. Sometimes, we may write ``ϵ(u_l(t))`` instead of ``f(ϵ_l(t))``. These are equivalent, with the small semantic distinction that e.g. ``ϵ(t) = u_l²(t))`` is an "artificial" parametrization to ensure that the physical control field ``ϵ(t)`` is positive, e.g. as the envelope of a pulse in the rotating wave approximation. In contrast, we may also have a *physical* non-linear control ``ϵ²(t)``, e.g. for the quadratic Stark shift. The control ``ϵ_l(t)`` may further depend on a finite set of "control parameters", which are generally not functions of time (see below).

An important expression in gradient based quantum control is ``μ = \frac{∂H}{∂ϵ_l(t)} = \frac{∂f}{∂ϵ_l}\frac{∂H}{∂f} = \frac{∂f}{∂ϵ_l} H_l``. We call ``μ`` the "control derivative" and ``\frac{∂f}{∂ϵ_l}`` the "non-linearity". In the standard case of linear controls, the non-linearity is one and ``μ=\frac{∂H}{∂ϵ_l(t)}`` is simply the control generator. For a non-unit control derivative, however, ``μ`` is a function of the control and thus time-dependent.

## Controls and control parameters

The controls that the `QuantumControl` package optimizes are implicit in the dynamical generator (Hamiltonians, Liouvillians) of the [`Objectives`](@ref Objective) in the [`ControlProblem`](@ref).

The [`getcontrols`](@ref) method extracts the controls from the objectives. Each control is typically time-dependent, e.g. a function ``ϵ(t)`` or a vector of pulse values on a time grid. The *default* format for the dynamical generators is that of a "nested" tuple, e.g. `(Ĥ₀, (Ĥ₁, ϵ₁), (Ĥ₂, ϵ₂))` where `Ĥ₀`, `Ĥ₁` and `Ĥ₂` are (sparse) matrices, and `ϵ₁` and `ϵ₂` are functions of time. The format corresponds to a time-dependent Hamiltonian ``Ĥ₀ + ϵ₁(t) Ĥ₁ + ϵ₂(t) Ĥ₂``.  For *custom* types describing a Hamiltonian or Liouvillian, the [`getcontrols`](@ref) method must be defined to extract the controls.

For each control, [`discretize`](@ref) and [`discretize_on_midpoints`](@ref) discretizes the control to an existing time grid. For controls that are implemented through some custom type, these methods must be defined to enable piecewise-constant time propagation or an optimization that assumes piecewise-constant control (most notably, Krotov's method).

More generally, [`get_control_parameters`](@ref) extracts abstract "control parameters" from a control. For controls that are simple functions, this is equivalent to discretizing them to a time grid. That is, the control parameters are the amplitude of the control field at each point in time, respectively each interval of the time grid. In general, though, the control parameters could be more abstract, e.g. the coefficients in a spectral decomposition, or parameters in an analytic pulse shape. In the context of optimal control, the parameters returned by [`get_control_parameters`](@ref) are those that the optimization should tune, assuming a suitable optimization method such as a gradient-free optimization or a generalized GRAPE (such as GROUP/GOAT).

## Time propagation

* [`propagate`](@ref)


## Optimization

* [`optimize_pulses`](@ref)
