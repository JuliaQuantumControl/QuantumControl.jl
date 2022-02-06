# User Manual

The User Manual describes the API of the `QuantumControl` package by outlining the general procedure for defining and solving quantum control problems. See the [API](@ref) for a detailed reference.

## Setting up control problems

Quantum control problems are described by instantiating [`ControlProblem`](@ref). Remember that a quantum control problem aims to find control parameters in the dynamical generators (Hamiltonians, Liouvillians) of a quantum system to steer the dynamics of the system in some desired way. The dynamics of system are probed by one or more quantum states, each with its particular dynamical generator. To determine how well the system dynamics meet the desired behavior, we formulate an "objective" for each of those quantum states.

Most commonly, this is represented by instantiating an [`Objective`](@ref) which contains the initial state, the generator for that state's dynamics, and a target state. A time grid for the dynamics is part of [`ControlProblem`](@ref) as `tlist`. The objective is fulfilled when the control parameters are chosen such that the initial state evolves into the target state.

A control problem with a single such objective already encodes the common state-to-state problem, e.g. to initialize a system into an entangled state, or to control a chemical reaction. However, there are many control problems that require *simultaneously* solving more than one objective. For example, finding the control parameters that implement a two-qubit quantum gate ``Ô`` on a quantum computer naturally translates into four simultaneous objectives, one for each two-qubit basis state: ``|00⟩ → Ô |00⟩``, ``|01⟩ → Ô |01⟩``, ``|10⟩ → Ô |10⟩``, ``|00⟩ → Ô |11⟩``. By virtue of the linearity of Hilbert space, finding a simultaneous solution to these four objectives means the *any* state ``|Ψ⟩`` will then evolve as ``|Ψ⟩ → Ô |Ψ⟩``.

Some optimal control frameworks treat the optimization of quantum gates by numerically evolving the gate itself, ``Û(t=0) = I → Ô(t=T)``. This is perfectly compatible with our framework: we can have a single objective for an initial "state" ``Û`` with a target "state" ``Ô``. However, this approach does not scale well numerically when the logical subspace of the two-qubit gate is embedded in a significantly larger physical Hilbert space: ``Û`` is quadratically larger than ``|Ψ⟩``. Moreover, the various methods implemented in the `QuantumControl` package are inherently *parallel* with respect to multiple objectives. This is why we emphasize the formulation of the control problem in terms of multiple simultaneous objectives.

Sometimes, some of the objectives may be more important than others. In this case, instead of the standard [`Objective`](@ref), a [`WeightedObjective`](@ref) is available. There are also situations where the notion of a "target state" is not meaningful. Coming back to the example of two-qubit quantum gates, one may wish to maximize the entangling power of the quantum gate, without requiring a *specific* gate. We extract the information about the entangling power of the dynamical generator by tracking the time evolution of a set of states (the Bell basis, as it happens), but there is no meaningful notion of a "target state". In this example, a user may define their own objective as a subtype of [`QuantumControlBase.AbstractControlObjective`](@ref) and include only an initial state and the dynamical generator for that state, but no target state. Indeed, an initial state and a generator are the minimum components that constitute an objective.

Mathematically, the control problem is solved by minimizing a functional that is calculated from the time-propagated states in the objectives. By convention, this functional is passed as a keyword argument `J_T` when instantiating the [`ControlProblem`](@ref). Standard functionals are defined in [the `QuantumControl.Functionals` module](@ref QuantumControlFunctionalsAPI). Depending on the control method, there can be additional options, either mandatory (like the ``χ = ∂J_T/∂⟨ϕ|`` required for Krotov's method) or optional, like constraints on the control parameters. See the documentation of the various methods implementing [`optimize`](@ref) for the options required or supported by the different solvers. All of these options can be passed as keyword arguments when instantiating the [`ControlProblem`](@ref)[^1], or they can be passed later to [`optimize`](@ref)/[`@optimize_or_load`](@ref).

[^1]: The solvers that ship with `QuantumControl` ignore options they do not know about. So when setting up a [`ControlProblem`](@ref) it is safe to pass a superset of options for different optimization methods.


## Controls and control parameters

The controls that the `QuantumControl` package optimizes are implicit in the dynamical generator (Hamiltonians, Liouvillians) of the [`Objectives`](@ref Objective) in the [`ControlProblem`](@ref).

The [`getcontrols`](@ref) method extracts the controls from the objectives. Each control is typically time-dependent, e.g. a function ``ϵ(t)`` or a vector of pulse values on a time grid. The *default* format for the dynamical generators is that of a "nested" tuple, e.g. `(Ĥ₀, (Ĥ₁, ϵ₁), (Ĥ₂, ϵ₂))` where `Ĥ₀`, `Ĥ₁` and `Ĥ₂` are (sparse) matrices, and `ϵ₁` and `ϵ₂` are functions of time. The format corresponds to a time-dependent Hamiltonian ``Ĥ₀ + ϵ₁(t) Ĥ₁ + ϵ₂(t) Ĥ₂``.  For *custom* types describing a Hamiltonian or Liouvillian, the [`getcontrols`](@ref) method must be defined to extract the controls.

For each control, [`discretize`](@ref) and [`discretize_on_midpoints`](@ref) discretizes the control to an existing time grid. For controls that are implemented through some custom type, these methods must be defined to enable piecewise-constant time propagation or an optimization that assumes piecewise-constant control (most notably, Krotov's method).

More generally, [`get_control_parameters`](@ref) extracts abstract "control parameters" from a control. For controls that are simple functions, this is equivalent to discretizing them to a time grid. That is, the control parameters are the amplitude of the control field at each point in time, respectively each interval of the time grid. In general, though, the control parameters could be more abstract, e.g. the coefficients in a spectral decomposition, or parameters in an analytic pulse shape. In the context of optimal control, the parameters returned by [`get_control_parameters`](@ref) are those that the optimization should tune, assuming a suitable optimization method such as a gradient-free optimization or a generalized GRAPE (such as GROUP/GOAT).

## Time propagation

The `QuantumControl` package uses (and includes) [`QuantumPropagators.jl`](https://github.com/JuliaQuantumControl/QuantumPropagators.jl) as the numerical back-end for simulating the time evolution of all quantum states. The main high-level function provided from that package is [`propagate`](@ref), which simulates the dynamics of a quantum state over an entire time grid. It does this by looping over calls to [`propstep`](@ref)/[`propstep!`](@ref), which simulate the dynamics for a single time step.

In the context of a [`ControlProblem`](@ref) consisting of one or more [`Objective`](@ref), there is also a [`propagate_objective`](@ref) function that provides a more convenient interface, automatically using the initial state and the dynamical generator from the objective.

A very typical overall workflow is to set up the control problem, then propagate the objectives with the guess control to see how the system behaves, run the optimization, and then propagate the objectives again with the optimized controls, to verify the success of the optimization. For plugging in the optimized controls, [`propagate_objective`](@ref) has a `controls_map` argument.


## Optimization

The most direct way to solve a [`ControlProblem`](@ref) is with the [`optimize`](@ref) routine. It has a mandatory `method` argument that then delegates the optimization to the appropriate sub-package implementing that method. However, if the optimization takes more than a few minutes to complete, you should use [`@optimize_or_load`](@ref) instead of just [`optimize`](@ref). This routine runs the optimization and then write the result to file. When called again, it will then simply load the result instead of rerunning the optimization.

A workflow [`@optimize_or_load`](@ref) using integrates particularly well with using the [DrWatson](https://juliadynamics.github.io/DrWatson.jl/stable/) package to organize your research project[^2]. In fact, [`@optimize_or_load`](@ref) is directly inspired by [`DrWatson.produce_or_load`](https://juliadynamics.github.io/DrWatson.jl/stable/save/#Produce-or-Load-1) and uses it under the hood. Just like `produce_or_load`, [`@optimize_or_load`](@ref) by default chooses an automatic filename that includes the keyword arguments that define the [`ControlProblem`](@ref). That automatic filename is determined by the [`optimization_savename`](@ref) routine.

[^2]: You are encouraged, but not *required* to use [DrWatson](https://juliadynamics.github.io/DrWatson.jl/stable/) for your projects. Here, we merely borrow some concepts from `DrWatson` for automatically storing computational results.

The [`@optimize_or_load`](@ref) also embeds some metadata in the output file, including (by default) the commit hash of the project repository containing the script that called [`@optimize_or_load`](@ref) and the filename of the script and line number where the call was made. This functionality is again borrowed from `DrWatson`.

The output file written by [`@optimize_or_load`](@ref) can be read via the [`load_optimization`](@ref) function. This can recover both the optimization result and the metadata.
