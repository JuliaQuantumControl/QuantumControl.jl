```@meta
# SPDX-FileCopyrightText: © 2026 Michael Goerz <mail@michaelgoerz.net>
# SPDX-License-Identifier: MIT OR CC-BY-4.0
```

# [Controls and Derivatives](@id ControlsAndDerivatives)

```@example control-diagrams
using Main.ControlDiagrams: diagram, legend  # hide
nothing  # hide
```

Gradient-based optimal control needs the derivative of the dynamical [Generator](@ref) with respect to whatever the optimization tunes. There are two kinds of derivatives, corresponding to the two ways of tuning a control:

* [Krotov's method](@extref Krotov :doc:`index`) and [GRAPE](@extref GRAPE :doc:`index`) tune the [Control Function](@ref) ``ϵ_l(t)`` on a time grid. They need the [Control Derivative](@ref) ``∂Ĥ(t)/∂ϵ_l(t)``, obtained from [`get_control_deriv`](@ref QuantumControl.Controls.get_control_deriv).
* Methods that tune [Control Parameters](@ref) ``u_n`` inside an analytic ``ϵ_l(\{u_n\}, t)`` need the [Parameter Derivative](@ref) ``∂Ĥ(t)/∂u_n``, obtained from [`get_parameter_deriv`](@ref QuantumControl.Controls.get_parameter_deriv). Examples are GOAT [MachnesPRL2018](@cite), which propagates the derivatives of the states under a gradient generator, and the evaluation of the gradient from one forward and one backward propagation, as in GROUP [SorensenPRA2018](@cite) and GRAFS [LucarelliPRA2018](@cite).

The data structures of controls, amplitudes, generators, and parameter blocks are defined in [QuantumPropagators](@extref QuantumPropagators :doc:`index`), and explained on the page [Time-Dependent Controls](@extref QuantumPropagators TimeDependentControls). The top half of the diagrams below match the diagrams from that page, with the lower half extending to the derivatives that QuantumControl adds.


## [Control Derivatives](@id ControlDerivatives)

```@example control-diagrams
legend(:functions; part = :full)  # hide
```

```@example control-diagrams
diagram(:control_functions; part = :full)  # hide
```

A *control derivative* is the derivative ``∂Ĥ(t)/∂ϵ_l(t)`` of the generator with respect to a control, obtained by [`get_control_deriv`](@ref QuantumControl.Controls.get_control_deriv). For a linear control term, it is the control operator ``Ĥ_l``. Otherwise, it depends on time, and possibly on the controls.

The function `get_control_deriv(H, ϵ)` returns a static operator, a [`Generator`](@ref), or `nothing`. For an amplitude, it returns `1.0` if the amplitude is the control, `0.0` if it does not depend on it, a [`LockedAmplitude`](@ref QuantumControl.Amplitudes.LockedAmplitude), or another amplitude. The function [`get_control_derivs(H, controls)`](@ref QuantumControl.Controls.get_control_derivs) returns a vector of these, one for each control.


## [Parameter Derivatives](@id ParameterDerivatives)

```@example control-diagrams
legend(:parameters; part = :full)  # hide
```

For the built-in [`Generator`](@ref), only the controls hold [parameter blocks](@extref QuantumPropagators ParameterBlocks):

```@example control-diagrams
diagram(:parameters_generator; part = :full)  # hide
```

A custom generator type can hold a block in its own fields, in addition to the blocks that it inherits from its controls:

```@example control-diagrams
diagram(:parameters_custom; part = :full)  # hide
```

The derivatives with respect to the parameters are obtained via [`get_parameter_deriv(object, block, i)`](@ref QuantumControl.Controls.get_parameter_deriv), which returns the derivative with respect to the parameter `(block, i)`. For a derivative generator, `get_parameters` returns an `ArrayPartition` whose only block is the block `u` (respectively `z`) of the original, which it aliases: the derivative adds no new block.


### Identifying a Parameter

A control is identified by object identity, and [`get_control_deriv(generator, control)`](@ref QuantumControl.Controls.get_control_deriv) relies on that. A parameter is a `Float64` inside a block. It has no identity of its own. A parameter is therefore identified by the pair `(block, i)`, that is, the combination of a block and a linear index into it. Blocks are compared with `===` to determine their identity. This enables sharing without further rules: two controls that hold an identical block, by definition, depend on the same parameters.


### Parameter Derivative Functions

There are two functions:

* [`get_parameter_deriv(object, block, i)`](@ref QuantumControl.Controls.get_parameter_deriv) returns the derivative of `object` with respect to the parameter `block[i]`.
* [`get_parameter_derivs(object, parameters)`](@ref QuantumControl.Controls.get_parameter_derivs) returns the derivatives of `object` with respect to every element of `parameters`.

The `object` can be a control, an amplitude, or a generator, and its derivative is an object of the same kind:

| `object`  | Derivative | Return value of `get_parameter_deriv(object, block, i)` |
|:----------|:-----------|:--------------------------------------------------------|
| Control ``ϵ_l(t)`` | ``∂ϵ_l(t)/∂u`` | `0.0` if the control does not depend on the parameter, otherwise a number, a function of `t` without parameters, or a control that holds `block` |
| Amplitude ``a_l(t)`` | ``∂a_l(t)/∂u`` | `0.0`, a number, or an amplitude |
| Generator ``Ĥ(t)`` | ``∂Ĥ(t)/∂u`` | `nothing` if the generator does not depend on the parameter, otherwise a static operator or a [`Generator`](@ref) |

In [`get_parameter_derivs`](@ref QuantumControl.Controls.get_parameter_derivs), the `parameters` are the parameters of any object, as returned by [`get_parameters`](@ref QuantumControl.Controls.get_parameters): an [`ArrayPartition`](@extref `RecursiveArrayTools.ArrayPartition`) of all the blocks that the object holds or inherits. The result is a vector of the same length, whose element `n` is the derivative with respect to `parameters[n]`. The function calls `get_parameter_deriv` for every parameter `(block, i)` in the blocks `parameters.x`. A single block is also accepted as `parameters`.


### [Evaluating Derivatives](@id EvaluatingParameterDerivatives)

A derivative is evaluated with [`evaluate`](@ref QuantumControl.Controls.evaluate), with the same arguments as the object itself: `evaluate(D, t)` or `evaluate(D, tlist, n)`, with an optional `vals_dict`. On a time grid, ``∂Ĥ(t)/∂u_n`` and ``Ĥ(t)`` are thus evaluated at the same midpoints. The `vals_dict` argument supplies values of controls, never values of parameters.

Since a derivative references the parameter blocks of the original object, it automatically uses updated parameter values when it is evaluated. For example, for the `GaussianControl` from [How to define a parameterized control](@extref QuantumPropagators howto_parameterized), with the derivative method defined in [Implementing Parameter Derivatives](@ref ImplementingParameterDerivatives) below:

```julia
ϵ = GaussianControl(A=2.0, t0=5.0, sigma=0.5)
H = hamiltonian(σz, (σx, ϵ))

u = get_parameters(H)                # contains the single block ϵ.parameters
derivs = get_parameter_derivs(H, u)  # three generators, each with the single term (σx, ∂ϵ/∂uₙ)
∂H╱∂σ = derivs[3]                    # equivalent to get_parameter_deriv(H, ϵ.parameters, 3)

evaluate(∂H╱∂σ, 4.5)                 # Operator for 2.426 σx
ϵ.parameters.sigma = 0.8             # plug in a new value
evaluate(∂H╱∂σ, 4.5)                 # Operator for 0.803 σx: the existing object follows the new value
```

Writing to `u` instead, as an optimizer does with `copyto!(u, x)`, has the same effect, since `u` aliases the block. Access by name (like `sigma`) goes through the block, here `ϵ.parameters`; see [How to work with control parameters](@extref QuantumPropagators howto_parameters).


### Derivatives of Generators

For a [`Generator`](@ref), the derivative is assembled from the derivatives of its amplitudes,

```math
\frac{∂Ĥ(t)}{∂u} = \sum_l Ĥ_l \frac{∂a_l(t)}{∂u}\,,
```

and the derivative of an amplitude follows from the chain rule over its controls,

```math
\frac{∂a_l(t)}{∂u} = \sum_{l'} \frac{∂a_l(t)}{∂ϵ_{l'}(t)} \frac{∂ϵ_{l'}(t)}{∂u}\,,
```

where the first factor is [`get_control_deriv(ampl, control)`](@ref QuantumControl.Controls.get_control_deriv). For a non-linear amplitude, the derivative depends on the controls. For example, for `ParameterizedAmplitude(ϵ; parameterization=SquareParameterization())`,

```math
a(t) = ϵ^2(t)\,,
\qquad
\frac{∂a(t)}{∂u_n} = 2ϵ(t)\frac{∂ϵ(t)}{∂u_n}\,,
```

so the derivative is an amplitude with two controls: ``ϵ(t)`` and its derivative.

Thus, the derivative of a generator is the chain rule with the control derivatives,

```math
\frac{∂Ĥ(t)}{∂u_n} = \sum_l \frac{∂Ĥ(t)}{∂ϵ_l(t)} \frac{∂ϵ_l(t)}{∂u_n}\,,
```

and both factors are available separately:

```julia
controls = get_controls(H)
μ = get_control_derivs(H, controls)                 # one generator or operator per control
J = [get_parameter_derivs(ϵ, u) for ϵ in controls]  # J[l][n] is ∂ϵₗ/∂uₙ, or 0.0
```

A consumer can use the derivatives from `get_parameter_derivs(H, u)` as opaque generators, which works for any generator, or use the factors. With ``M`` parameters and ``L`` controls, the factored form applies ``L`` operators to a state and forms ``M`` linear combinations, where the opaque derivatives apply up to ``M L`` operators. The factored form is valid only if the generator does not hold blocks itself, which holds for the built-in [`Generator`](@ref).

Since the derivative of a control holds at most the block of the original control (see the table above), the derivative of any object contains new controls (the derivatives of its controls), but no new blocks. A derivative generator inherits a subset of the blocks of the original, possibly in a different order. Its parameters are joined from those blocks like the parameters of any other object, so they are the same as those of the original only if it inherits every block in the same order. Nothing depends on that, since a parameter is identified by `(block, i)`.


### Trajectories and Control Problems

As for [`get_control_derivs`](@ref QuantumControl.Controls.get_control_derivs), there are no methods for a [`Trajectory`](@ref) or a [`ControlProblem`](@ref). The pattern is:

```julia
u = get_parameters(problem)
for traj in problem.trajectories
    derivs = get_parameter_derivs(traj.generator, u)
    # length(derivs) == length(u); `nothing` where traj.generator does not depend on u[n]
end
```

There is only one index space, the flat index of whatever vector is passed in. Nothing translates indices between a control, a generator, and the problem: the blocks of `u` are `u.x`, and each generator recognizes the blocks that it holds or inherits by identity. This requires `get_parameters(problem)` to contain every block exactly once, which [`combine_parameters`](@ref QuantumControl.Controls.combine_parameters) ensures. A *copy* of the parameters is not recognized, so all derivatives with respect to a copy are `nothing`.

All of these functions are meant for setting up an optimization. The call `u = get_parameters(problem)` combines the blocks into one [`ArrayPartition`](@extref `RecursiveArrayTools.ArrayPartition`) without copying values. The call `get_parameter_derivs(traj.generator, u)` builds one derivative per parameter without creating any new block. During the optimization, an optimizer writes its iterate into the blocks with `copyto!(u, x)`, and the propagation evaluates the derivatives that were built during the setup. The gradient is a vector indexed like `u`.


### [Implementing Parameter Derivatives](@id ImplementingParameterDerivatives)

The author of a [`ParameterizedFunction`](@ref QuantumControl.Controls.ParameterizedFunction) implements the two-argument method `get_parameter_deriv(control, i)`, which returns the derivative with respect to `control.parameters[i]`. For the Gaussian control from the how-to [How to define a parameterized control](@extref QuantumPropagators howto_parameterized), this could be

```julia
using ComponentArrays
using QuantumControl.Controls: ParameterizedFunction
import QuantumControl.Controls: get_parameter_deriv

struct GaussianControl <: ParameterizedFunction
    parameters::ComponentVector{Float64,Vector{Float64},Tuple{Axis{(A=1, t0=2, sigma=3)}}}
end

GaussianControl(; A=1.0, t0=0.0, sigma=1.0) = GaussianControl(ComponentVector(; A, t0, sigma))

function (control::GaussianControl)(t)
    u = control.parameters
    return u.A * exp(-(t - u.t0)^2 / (2 * u.sigma^2))
end

# The derivative ∂ϵ/∂uᵢ is a control that holds the same block
struct GaussianControlDeriv{P} <: ParameterizedFunction
    parameters::P  # the block of the original control, not a copy
    i::Int
end

function (deriv::GaussianControlDeriv)(t)
    u = deriv.parameters  # the values are read when the derivative is called
    g = exp(-(t - u.t0)^2 / (2 * u.sigma^2))
    if deriv.i == 1      # ∂ϵ/∂A
        return g
    elseif deriv.i == 2  # ∂ϵ/∂t₀
        return u.A * g * (t - u.t0) / u.sigma^2
    else                 # ∂ϵ/∂σ
        return u.A * g * (t - u.t0)^2 / u.sigma^3
    end
end

get_parameter_deriv(control::GaussianControl, i) = GaussianControlDeriv(control.parameters, i)
```

The derivative holds the block of the original control, not a copy, and reads the values from it when it is called. This is what makes the existing derivative follow new parameter values, as shown in [Evaluating Derivatives](@ref EvaluatingParameterDerivatives).

The two-argument method returns a number for a constant derivative (including `0.0` for an element of a shared block that the control does not use), any function of `t` for a derivative that does not depend on the parameters (which is the case for every parameter that enters linearly), or a [`ParameterizedFunction`](@ref QuantumControl.Controls.ParameterizedFunction) that holds the block of the original control, like `GaussianControlDeriv` above. [`QuantumControl.Interfaces.check_control`](@ref) verifies these requirements, and compares the derivatives with finite differences. The two-argument method is for authors only. Consumers always call the three-argument method.

There is no fallback: a `ParameterizedFunction` without the two-argument method raises a `MethodError`, instead of silently having a zero derivative, and fails `check_control` unless it is called with `for_gradient_optimization=false`. How a type obtains its derivatives is up to the author. For example, a type that wraps a function `f(t, u)` can apply automatic differentiation to that function. Everything else is generic: amplitudes (including [`ShapedAmplitude`](@ref QuantumControl.Amplitudes.ShapedAmplitude), [`GuidedAmplitude`](@ref QuantumControl.Amplitudes.GuidedAmplitude), the amplitudes in [`QuantumControl.PulseParameterizations`](@ref QuantumControlPulseParameterizationsAPI), and any custom amplitude that supports [`get_control_deriv`](@ref QuantumControl.Controls.get_control_deriv)) and the built-in [`Generator`](@ref) need no new methods. The [`CRABFunction`](@ref QuantumPropagators.ParameterizedFunctions.CRABFunction), [`VariedFrequencyCRABFunction`](@ref QuantumPropagators.ParameterizedFunctions.VariedFrequencyCRABFunction), and [`StaticParameter`](@ref QuantumControl.Controls.StaticParameter) have parameter derivatives of any order.


### Higher Derivatives

A derivative is a control, an amplitude, or a generator that inherits blocks of the original object. Hence, `get_parameter_deriv` applies to it again:

```julia
∂²H╱∂σ∂t₀ = get_parameter_deriv(∂H╱∂σ, ϵ.parameters, 2)
```

Whether a particular higher derivative exists depends on the objects involved, and supporting it is optional. For a control, the type that the two-argument method returns needs a two-argument method of its own (for `GaussianControlDeriv` in the example). If the first derivative is a number or a function without parameters, all further derivatives are `0.0`, so a control that is linear in its parameters has higher derivatives without any additional code. For an amplitude that is not linear in its controls, the control derivative must in turn have a control derivative. A [`Generator`](@ref) needs nothing new. With `for_hessian=true`, `check_control` and `check_generator` also verify the second derivatives.


### Static Parameters and Custom Generators

The built-in [`Generator`](@ref) holds no blocks. A tunable parameter of the drift or of a dissipator is therefore a control that is constant in time, a [`StaticParameter`](@ref QuantumControl.Controls.StaticParameter). For example, for a detuning ``Δ``:

```julia
Δ = StaticParameter([0.3])
H = hamiltonian((σz, Δ), (σx, ϵ))
get_parameter_derivs(H, get_parameters(H))[1]  # ∂H/∂Δ: the matrix σz
```

A custom generator type can hold blocks in its own fields. Its [`get_parameters`](@ref QuantumControl.Controls.get_parameters) method combines these blocks with the parameters of its controls, e.g., `get_parameters(G::TransmonGenerator) = combine_parameters(G.w, get_parameters(G.control))` for the `TransmonGenerator` in the diagram above, using [`combine_parameters`](@ref QuantumControl.Controls.combine_parameters) (public, but not exported). See [How to implement a generator with its own parameters](@extref QuantumPropagators howto_custom_parameters) for the complete implementation. For gradient-based optimization, such a type also needs its own three-argument `get_parameter_deriv` method, which recognizes the blocks that it holds by identity. For example, for a type that holds the block `[Δ, Ω]` and evaluates to `Δ * σz + Ω * σx`, that method returns the matrix `σz` for the first element of the block, the matrix `σx` for the second, and `nothing` for any other block. A custom generator type that contains parameterized controls needs the three-argument method as well, as it needs its own `get_control_deriv` method: the generic assembly covers only the built-in [`Generator`](@ref). For the blocks of its controls, the method applies the chain rule. [`QuantumControl.Interfaces.check_generator`](@ref) with `for_parameterization=true` verifies the parameter derivatives of a generator.

