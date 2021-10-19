# Glossary

In the context of the JuliaQuantumControl ecosystem, we apply the following nomenclature.

----

##### Generator

Dynamical generator (Hamiltonian / Liouvillian) for the time evolution of a state, i.e., the right-hand-side of the equation of motion (up to a factor of ``i``) such that ``|Ψ(t+dt)⟩ = e^{-i Ĥ dt} |Ψ(t)⟩`` in the infinitesimal limit. We use the symbols ``G``, ``Ĥ``, or ``L``, depending on the context (general, Hamiltonian, Liouvillian).

Examples for supported forms of dynamical generators are the following, from most general to simplest (and most common)

* ``Ĥ = Ĥ₀ + \sum_l Ĥ_l(\{ϵ_{l'}(t)\})``    —  general non-separable control terms (G1)
* ``Ĥ = Ĥ₀ + \sum_l f(ϵ_l(t)\}) Ĥ_l``    —  nonlinear separable control terms (G2)
* ``Ĥ = Ĥ₀ + \sum_l ϵ_l(t) Ĥ_l``             — linear control terms (G3)

The above equations are written for Hamiltonians, but Liouvillians would follow the exact same form, see [`liouvillian`](@ref) with `convention=:TDSE`.

----

##### Control

(aka "control field") A function ``ϵ_l(t)`` in the [Generator](@ref), typically corresponding to some kind of physical field (laser amplitude, microwave pulse, etc.). Conceptually a function, but may be specified in terms of [Control Parameters](@ref).

----

##### Control Term

A term in the dynamical generator that depends on one or more controls, e.g. ``Ĥ_l(\{ϵ_{l'}(t)\})`` or ``f(ϵ_l(t)\}) Ĥ_l`` or ``ϵ_l(t) Ĥ_l`` in Eqs. (G1-G3) of the [Generator](@ref). Conceptually, the control term is a time-dependent operator.

----

##### Drift

A term in the dynamics generator that does not depend on any controls. Conceptually, a static operator.

----

##### Control Function

In Eq. (G3), the ``f(ϵ(t))`` expressing a possible non-linear physical dependency on the control field. An example is the quadratic coupling of a Stark shift operator to the laser field. Note that in the most common case of a linear control term, there is no strict distinction between "control"/"control field"/"control function".

----

##### Control Generator

(aka "control Hamiltonian/Liouvillian"). The operator ``Ĥ_l`` in Eqs. (G2, G3). This is a *static* operator which forms the [Control Term](@ref) together with a [Control Function](@ref). The control generator is not a well-defined concept in the most general case of non-separable controls terms, Eq. (G1)

----

##### Control Parameters

Non-time-dependent parameters that a control field depends on. One common parametrization of a control field is as a [Pulse](@ref), where the control parameters are the amplitude of the field at discrete points of a time grid. Parametrization as a "pulse" is implicit in Krotov's method and standard GRAPE.

More generally, the control parameters could also be spectral coefficients (CRAB) or simple parameters for an analytic pulse shape (e.g., position, width, and amplitude of a Gaussian shape). All optimal control methods find optimized control fields by varying the control parameters.

----

##### Pulse

(aka "control pulse") A control field discretized to a time grid, usually on the midpoints of the time grid, in a piecewise-constant approximation. Stored as a vector of floating point values. The parametrization of a control field as a "pulse" is implicit for Krotov's method and standard GRAPE. One might think of these methods to optimize the control fields *directly*, but a conceptually cleaner understanding is to think of the discretized "pulse" as a vector of control parameters for the time-continuous control field.


----

##### Amplitude Parametrization

The use of a function ``u(t)`` such that ``ϵ(t) = ϵ(u(t))`` for the purpose of constraining the amplitude of the control field ``ϵ(t)``. See e.g. [`SquareParametrization`](@ref), where ``ϵ(t) = u^2(t)`` to ensure that ``ϵ(t)`` is positive. Since Krotov's method inherently has no constraints on the optimized control fields, amplitude parameterization is a method of imposing constraints on the amplitude in this context. This is different from, albeit related to, a [Control Function](@ref) ``f(ϵ(t)) = ϵ^2(t)`` in that the amplitude parameterization does not reflect how the control field *physically* couples to the control Hamiltonian. Note that "parameterization" here has nothing to do with the "parametrization" in terms of [Control Parameters](@ref): the amplitude parametrization is a parametrization with a *function*, whereas the control parameters are *values*.

----

##### Control Derivative

The derivative of the dynamical [Generator](@ref) with respect to the control field ``ϵ(t)``. In the case of linear controls terms in Eq. (G3), the control derivative is the [Control Generator](@ref) coupling to ``ϵ(t)``. In general, however, for non-linear control terms, the control derivatives still depends on the control fields and is thus time dependent. We commonly use the symbol ``μ`` for the control derivative (reminiscent of the dipole operator)

----

##### Parameter Derivative

The derivative of a control with respect to a single control parameter. The derivative of the dynamical [Generator](@ref) with respect to that control parameter is then the product of the [Control Derivative](@ref) and the parameter derivative.

----

##### Gradient


The derivative of the optimization functional with respect to *all* [Control Parameters](@ref), i.e. the vector of all parameter derivatives.

----

!!! note

    The above nomenclature does not consistently extend throughout the quantum control literature: the terms "control"/"control term"/"control Hamiltonian", and "control"/"control field"/"control function"/"control pulse"/"pulse" are generally somewhat ambiguous. In particular, the distinction between "control field" and "pulse" (as a parametrization of the control field in terms of amplitudes on a time grid) here is somewhat artifcial (although it is also used in the [Krotov Python package](https://qucontrol.github.io/krotov)). However, the terminology defined in this glossary is consistently applied within the `JuliaQuantumControl` organization, both in the documentation and in the names of fields and methods.
