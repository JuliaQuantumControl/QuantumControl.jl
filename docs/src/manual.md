# User Manual

The User Manual describes the API of the `QuantumControl` package by outlining the general procedure for defining and solving quantum control problems. See the [API](@ref) for a detailed reference.

## Setting up control problems

* [`ControlProblem`](@ref)
* [`Objective`](@ref)
* [`WeightedObjective`](@ref)

## Controls and control parameters

The controls that the `QuantumControl` package optimizes are implicit in the dynamical generator (Hamiltonians, Liouvillians) of the [`Objectives`](@ref Objective) in the [`ControlProblem`](@ref).

The [`getcontrols`](@ref) method extracts the controls from the objectives. Each control is typically time-dependent, e.g. a function ``ϵ(t)`` or a vector of pulse values on a time grid. The *default* format for the dynamical generators is that of a "nested" tuple, e.g. `(Ĥ₀, (Ĥ₁, ϵ₁), (Ĥ₂, ϵ₂))` where `Ĥ₀`, `Ĥ₁` and `Ĥ₂` are (sparse) matrices, and `ϵ₁` and `ϵ₂` are functions of time. The format corresponds to a time-dependent Hamiltonian ``Ĥ₀ + ϵ₁(t) Ĥ₁ + ϵ₂(t) Ĥ₂``.  For *custom* types describing a Hamiltonian or Liouvillian, the [`getcontrols`](@ref) method must be defined to extract the controls.

For each control, [`discretize`](@ref) and [`discretize_on_midpoints`](@ref) discretizes the control to an existing time grid. For controls that are implemented through some custom type, these methods must be defined to enable piecewise-constant time propagation or an optimization that assumes piecewise-constant control (most notably, Krotov's method).

More generally, [`get_control_parameters`](@ref) extracts abstract "control parameters" from a control. For controls that are simple functions, this is equivalent to discretizing them to a time grid. That is, the control parameters are the amplitude of the control field at each point in time, respectively each interval of the time grid. In general, though, the control parameters could be more abstract, e.g. the coefficients in a spectral decomposition, or parameters in an analytic pulse shape. In the context of optimal control, the parameters returned by [`get_control_parameters`](@ref) are those that the optimization should tune, assuming a suitable optimization method such as a gradient-free optimization or a generalized GRAPE (such as GROUP/GOAT).

## Time propagation

* [`propagate`](@ref)
* [`propagate_objective`](@ref)


## Optimization

* [`optimize`](@ref)
