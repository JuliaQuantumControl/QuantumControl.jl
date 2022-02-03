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

The most direct way to solve a [`ControlProblem`](@ref) is with the [`optimize`](@ref) routine. It has a mandatory `method` argument that then delegates the optimization to the appropriate sub-package implementing that method. However, if the optimization takes more than a few minutes to complete, you should use [`@optimize_or_load`](@ref) instead of just [`optimize`](@ref). This routine runs the optimization and then write the result to file. When called again, it will then simply load the result instead of rerunning the optimization.

A workflow [`@optimize_or_load`](@ref) using integrates particularly well with using the [DrWatson](https://juliadynamics.github.io/DrWatson.jl/stable/) package to organize your research project[^1]. In fact, [`@optimize_or_load`](@ref) is directly inspired by [`DrWatson.produce_or_load`](https://juliadynamics.github.io/DrWatson.jl/stable/save/#Produce-or-Load-1) and uses it under the hood. Just like `produce_or_load`, [`@optimize_or_load`](@ref) by default chooses an automatic filename that includes the keyword arguments that define the [`ControlProblem`](@ref). That automatic filename is determined by the [`optimization_savename`](@ref) routine.

[^1]: You are encouraged, but not *required* to use [DrWatson](https://juliadynamics.github.io/DrWatson.jl/stable/) for your projects. Here, we merely borrow some concepts from `DrWatson` for automatically storing computational results.

The [`@optimize_or_load`](@ref) also embeds some metadata in the output file, including (by default) the commit hash of the project repository containing the script that called [`@optimize_or_load`](@ref) and the filename of the script and line number where the call was made. This functionality is again borrowed from `DrWatson`.

The output file written by [`@optimize_or_load`](@ref) can be read via the [`load_optimization`](@ref) function. This can recover both the optimization result and the metadata.
