# Glossary

In the context of the JuliaQuantumControl ecosystem, we apply the following nomenclature.

----

##### Generator

Dynamical generator (Hamiltonian / Liouvillian) for the time evolution of a state, i.e., the right-hand-side of the equation of motion (up to a factor of ``i``) such that ``|Ψ(t+dt)⟩ = e^{-i Ĥ dt} |Ψ(t)⟩`` in the infinitesimal limit. We use the symbols ``G``, ``Ĥ``, or ``L``, depending on the context (general, Hamiltonian, Liouvillian).

Examples for supported forms a Hamiltonian are the following, from the most general case to simplest and most common case of linear controls,

```@raw html
<img src="../assets/controlhams.svg" width="80%"/>
```

In Eq. (G1), ``Ĥ_0`` is the [Drift Term](@ref) (which may be zero) and each term under the sum over ``l`` is a [Control Term](@ref). Each control term is a Hamiltonian that depends on a set of [control functions](#Control-Function) (or simply "controls"). The controls are the functions directly tunable via optimal control.
The control term may also contain an explicit time dependence outside of the controls. This most general form (G1) is supported only via custom user-implemented generator objects, see the documentation of the [QuantumPropagators package](https://juliaquantumcontrol.github.io/QuantumPropagators.jl/stable/).

More commonly, each control term is separable into the [Control Amplitude](@ref) ``a_l(t)`` and the [Control Operator](@ref) ``Ĥ_l``, as in Eq. (G2). This is the most general form supported by the built-in [`Generator`](@ref) object, which can be initialized via the [`hamiltonian`](@ref) or [`liouvillian`](@ref) functions. The control amplitude ``a_l(t)`` depends in turn on one ore more function ``\{ϵ_{l'}(t)\}``, where each ``ϵ_{l'}(t)`` is as [Control Function](@ref). It may also contain an explicit time dependence.

In the most common case, ``a_l ≡ ϵ_l``, as in Eq. (G3). The control may further depend on a set of [Control Parameters](@ref), ``ϵ_l(t) = ϵ_l({u_n})``.

In an open quantum system, the structure of Eqs. (G1–G3) is the same, but with Liouvillian (super-)operators acting on density matrices instead of Hamiltonians acting on state vectors. See [`liouvillian`](@ref) with `convention=:TDSE`.


----

##### Operator

A static, non-time-dependent object that can be multiplied to a state. An operator can be obtained from a time-dependent [Generator](@ref) by plugging in values for the controls and potentially any explicit time dependence. For example, an [`Operator`](@ref) is obtained from a [`Generator`](@ref) via [`QuantumControl.Controls.evaluate`](@ref).

----

##### Drift Term

A term in the dynamical generator that does not depend on any controls.

----

##### Control Term

A term in the dynamical generator that depends on one or more controls.

----

##### Control Function

(aka "**Control**") A function ``ϵ_l(t)`` in the [Generator](@ref) that is directly tuned by an optimal control method, either as [Pulse](@ref) values or via [Control Parameters](@ref).

----

##### Control Field

A function that corresponds directly to some kind of *physical* drive (laser amplitude, microwave pulse, etc.). The term can be ambiguous in that it usually corresponds to the [Control Amplitude](@ref) ``a(t)``, but depending on how the control problem is formulated, it can also correspond to the [Control Function](@ref) ``ϵ(t)``

----

##### Control Operator

(aka "control Hamiltonian/Liouvillian"). The operator ``Ĥ_l`` in Eqs. (G2, G3). This is a *static* operator which forms the [Control Term](@ref) together with a [Control Amplitude](@ref). The control generator is not a well-defined concept in the most general case of non-separable controls terms, Eq. (G1).


----


##### Control Amplitude

The time-dependent coefficient ``a_l(t)`` for the [Control Operator](@ref) in Eq. (G2). A control amplitude may depend on on or more control functions, as well as have an explicit time dependency. Some conceptual examples for control amplitudes and how they may depend on a [Control Function](@ref) are the following:

* Non-linear coupling of a control field to the operator, e.g., the quadratic coupling of the laser field to a Stark shift operator
* [Pulse Parameterization](@ref) as a way to enforce bounds on a [Control Field](@ref)
* Transfer functions, e.g., to model the response of an electronic device to the optimal control field ``ϵ(t)``.
* Noise in the amplitude of the control function
* Non-controllable aspects of the control amplitude, e.g. a "guided" control amplitude ``a_l(t) = R(t) + ϵ_l(t)`` or a non-controllable envelope ``S(t)`` in ``a_l(t) = S(t) ϵ(t)`` that ensures switch-on- and switch-off in a CRAB pulse `ϵ(t)`.

In [Qiskit Dynamics](https://qiskit.org/documentation/dynamics/index.html), the "control amplitude" is called ["Signal"](https://qiskit.org/documentation/dynamics/apidocs/signals.html), see [Connecting Qiskit Pulse with Qiskit Dynamics](https://qiskit.org/documentation/dynamics/tutorials/qiskit_pulse.html), where a Qiskit "pulse" corresponds roughly to our [Control Function](@ref).


----

##### Control Parameters

Non-time-dependent parameters that a [Control Function](@ref) depends on, ``ϵ(t) = ϵ(\{u_n\}, t)``. One common parameterization of a control field is as a [Pulse](@ref), where the control parameters are the amplitude of the field at discrete points of a time grid. Parameterization as a "pulse" is implicit in Krotov's method and standard GRAPE.

More generally, the control parameters could also be spectral coefficients (CRAB) or simple parameters for an analytic pulse shape (e.g., position, width, and amplitude of a Gaussian shape). All optimal control methods find optimized control fields by varying the control parameters.

----

##### Pulse

(aka "control pulse") A control field discretized to a time grid, usually on the midpoints of the time grid, in a piecewise-constant approximation. Stored as a vector of floating point values. The parameterization of a control field as a "pulse" is implicit for Krotov's method and standard GRAPE. One might think of these methods to optimize the control fields *directly*, but a conceptually cleaner understanding is to think of the discretized "pulse" as a vector of control parameters for the time-continuous control field.


----

##### Pulse Parameterization

A special case of a [Control Amplitude](@ref) where ``a(t) = a(ϵ(t))`` at every point in time. The purpose of this is to constrain the amplitude of the control amplitude ``a(t)``. See e.g. [`QuantumControl.PulseParameterizations.SquareParameterization`](@ref), where ``a(t) = ϵ^2(t)`` to ensure that ``a(t)`` is positive. Since Krotov's method inherently has no constraints on the optimized control fields, pulse parameterization is a method of imposing constraints on the amplitude in this context.

----

##### Control Derivative

The derivative of the dynamical [Generator](@ref) with respect to the control ``ϵ(t)``. In the case of linear controls terms in Eq. (G3), the control derivative is the [Control Operator](@ref) coupling to ``ϵ(t)``. In general, however, for non-linear control terms, the control derivatives still depends on the control fields and is thus time dependent. We commonly use the symbol ``μ`` for the control derivative (reminiscent of the dipole operator)

----

##### Parameter Derivative

The derivative of a control with respect to a single control parameter. The derivative of the dynamical [Generator](@ref) with respect to that control parameter is then the product of the [Control Derivative](@ref) and the parameter derivative.

----

##### Gradient


The derivative of the optimization functional with respect to *all* [Control Parameters](@ref), i.e. the vector of all parameter derivatives.

----

!!! note

    The above nomenclature does not consistently extend throughout the quantum control literature: the terms "control"/"control term"/"control Hamiltonian", and "control"/"control field"/"control function"/"control pulse"/"pulse" are generally somewhat ambiguous. In particular, the distinction between "control field" and "pulse" (as a parameterization of the control field in terms of amplitudes on a time grid) here is somewhat artifcial and borrowed from the [Krotov Python package](https://qucontrol.github.io/krotov). However, the terminology defined in this glossary is consistently applied within the `JuliaQuantumControl` organization, both in the documentation and in the names of members and methods.
