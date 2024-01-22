# User Manual

The User Manual describes the API of the `QuantumControl` package by outlining the general procedure for defining and solving quantum control problems. See the [API](@ref) for a detailed reference.

## Setting up control problems

Quantum control problems are described by instantiating [`ControlProblem`](@ref). Remember that a quantum control problem aims to find control parameters in the dynamical generators ([Hamiltonians](@ref hamiltonian), [Liouvillians](@ref liouvillian)) of a quantum system to steer the dynamics of the system in some desired way. The dynamics of system are probed by one or more quantum states, each with its particular dynamical generator, which we encode as a [`Trajectory`](@ref) object.

To determine how well the system dynamics meet the desired behavior, a [`Trajectory`](@ref) can have additional properties that are taken into account in the optimization functional. Most commonly, this is represented by a `target_state` property of the [`Trajectory`](@ref). The objective is fulfilled when the control parameters are chosen such that the initial state of each [`Trajectory`](@ref) evolves into the target state, on the time grid given as `tlist` in the [`ControlProblem`](@ref).

A control problem with a single such trajectory already encodes the common state-to-state problem, e.g., to initialize a system into an entangled state, or to control a chemical reaction. However, there are many control problems that require *simultaneously* solving more than one trajectory. For example, finding the control parameters that implement a two-qubit quantum gate ``Ô`` on a quantum computer naturally translates to four simultaneous trajectories, one for each two-qubit basis state: ``|00⟩ → Ô |00⟩``, ``|01⟩ → Ô |01⟩``, ``|10⟩ → Ô |10⟩``, ``|00⟩ → Ô |11⟩``. By virtue of the linearity of Hilbert space, finding a simultaneous solution to these four trajectories means the *any* state ``|Ψ⟩`` will then evolve as ``|Ψ⟩ → Ô |Ψ⟩``.

Some optimal control frameworks treat the optimization of quantum gates by numerically evolving the gate itself, ``Û(t=0) = I → Ô(t=T)``. This is perfectly compatible with our framework: we can have a single trajectory for an initial "state" ``Û`` with a target "state" ``Ô``. However, this approach does not scale well numerically when the logical subspace of the two-qubit gate is embedded in a significantly larger physical Hilbert space: ``Û`` is quadratically larger than ``|Ψ⟩``. Moreover, the various methods implemented in the `QuantumControl` package are inherently *parallel* with respect to multiple trajectories. This is why we emphasize the formulation of the control problem in terms of multiple simultaneous trajectories.

Sometimes, some of the trajectories may be more important than others. In this case, the [`Trajectory`](@ref) can be instantiated with a `weight` attribute. There are also situations where the notion of a "target state" is not meaningful. Coming back to the example of two-qubit quantum gates, one may wish to maximize the entangling power of the quantum gate, without requiring a *specific* gate. We extract the information about the entangling power of the dynamical generator by tracking the time evolution of a set of states (the Bell basis, as it happens), but there is no meaningful notion of a "target state". In this example, an [`Trajectory`](@ref) may be instantiated without the `target_state` attribute, i.e., containing only the `initial_state` and the `generator`. These are the minimal required attributes for any optimization.

Mathematically, the control problem is solved by minimizing a functional that is calculated from the time-propagated trajectory states. By convention, this functional is passed as a keyword argument `J_T` when instantiating the [`ControlProblem`](@ref). Standard functionals are defined in [the `QuantumControl.Functionals` module](@ref QuantumControlFunctionalsAPI). Depending on the control method, there can be additional options. See the documentation of the various methods implementing [`optimize`](@ref) for the options required or supported by the different solvers. All of these options can be passed as keyword arguments when instantiating the [`ControlProblem`](@ref)[^1], or they can be passed later to [`optimize`](@ref)/[`@optimize_or_load`](@ref).

[^1]: The solvers that ship with `QuantumControl` ignore options they do not know about. So when setting up a [`ControlProblem`](@ref) it is safe to pass a superset of options for different optimization methods.


## Controls and control parameters

The controls that the `QuantumControl` package optimizes are implicit in the dynamical generator ([`hamiltonian`](@ref), [`liouvillian`](@ref)) of the [`Trajectories`](@ref Trajectory) in the [`ControlProblem`](@ref).

The [`QuantumControl.Controls.get_controls`](@ref) method extracts the controls from the trajectories. Each control is typically time-dependent, e.g., a function ``ϵ(t)`` or a vector of pulse values on a time grid. For each control, [`QuantumControl.Controls.discretize`](@ref) and [`QuantumControl.Controls.discretize_on_midpoints`](@ref) discretizes the control to an existing time grid. For controls that are implemented through some custom type, these methods must be defined to enable piecewise-constant time propagation or an optimization that assumes piecewise-constant control (most notably, Krotov's method). See [`QuantumControl.Interfaces.check_control`](@ref) for the full interface required of a control.

See also the [section on Dynamical Generators in the `QuantumPropagators` documentation](https://juliaquantumcontrol.github.io/QuantumPropagators.jl/stable/generators/) and [`QuantumControl.Interfaces.check_generator`](@ref) for details on how generators and controls relate.

## Time propagation

The `QuantumControl` package uses (and includes) [`QuantumPropagators.jl`](https://github.com/JuliaQuantumControl/QuantumPropagators.jl) as the numerical back-end for simulating the time evolution of all quantum states. The main high-level function provided from that package is [`propagate`](@ref), which simulates the dynamics of a quantum state over an entire time grid. In the context of a [`ControlProblem`](@ref) consisting of one or more [`Trajectory`](@ref), there is also a [`propagate_trajectory`](@ref) function that provides a more convenient interface, automatically using the initial state and the dynamical generator from the trajectory.

A very typical overall workflow is to set up the control problem, then propagate the trajectories with the guess control to see how the system behaves, run the optimization, and then propagate the trajectories again with the optimized controls, to verify the success of the optimization. For plugging in the optimized controls, [`QuantumControl.Controls.substitute`](@ref) can be used.


## Optimization

The most direct way to solve a [`ControlProblem`](@ref) is with the [`optimize`](@ref) routine. It has a mandatory `method` argument that then delegates the optimization to the appropriate sub-package implementing that method.

However, if the optimization takes more than a few minutes to complete, you should use [`@optimize_or_load`](@ref) instead of just [`optimize`](@ref). This routine runs the optimization and then writes the result to file. When called again, it will then simply load the result instead of rerunning the optimization. The [`@optimize_or_load`](@ref) also embeds some metadata in the output file, including (by default) the commit hash of the project repository containing the script that called [`@optimize_or_load`](@ref) and the filename of the script and line number where the call was made.

The output file written by [`@optimize_or_load`](@ref) can be read via the [`load_optimization`](@ref) function. This can recover both the optimization result and the metadata.
