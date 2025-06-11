# [How-to Guides](@id howto)

**Contents**

```@contents
Pages=[
 "howto.md"
]
Depth = 2:2
```

Also see the following how-to guides from the [QuantumPropagators documentation](@extref QuantumPropagators :doc:howto):

```@eval
using Markdown
using DocInventories

inventory = Inventory("https://juliaquantumcontrol.github.io/QuantumPropagators.jl/stable/objects.inv")

howtos = [item for item in inventory if item.role == "label" && startswith(item.uri, "howto") && item.name != "Howtos"]

lines = ["* [$(DocInventories.dispname(item))]($(DocInventories.uri(inventory, DocInventories.spec(item))))" for item in howtos]

Markdown.parse(join(lines, "\n"))
```

## How to define a functional ``J_T`` that depends on more than just target states

All of the optimization methods in the [JuliaQuantumControl organization](https://github.com/JuliaQuantumControl) target a final-time functional ``J_T`` via an argument `J_T`, see [`QuantumControl.optimize`](@ref), that has the interface

> `J_T`: A function `J_T(Ψ, trajectories)` that evaluates the final time functional from a list `Ψ` of forward-propagated states and `problem.trajectories`. The function `J_T` may also take a keyword argument `tau`. If it does, a vector containing the complex overlaps of the target states (`target_state` property of each trajectory in `problem.trajectories`) with the propagated states will be passed to `J_T`.

If the functional does not depend solely on a set of states `Ψ` and a set of corresponding target states, that raises the question of how to include additional information in `J_T`, within the constraints of the API that does not allow for additional arguments to `J_T`. For example, we might want to reference an operator in `J_T` whose expectation value should be maximized or minimized. There are three fundamental approaches:

1. Hard-code the relevant data inside the definition of `J_T`. This is the most straightforward, but not very flexible.
2. Attach the data to the function `J_T`. This makes sense when the data is independent of the `trajectories`. Typically, this is done via a [closure](https://en.wikipedia.org/wiki/Closure_(computer_programming)), e.g., via a `make_J_T(op)` function that returns a function `J_T(Ψ, trajectories)` that references `J_T`, or, in trivial cases, with an [anonymous function](@extref Julia :label:`man-anonymous-functions`) for the keyword argument `J_T` of [`optimize`](@ref). This is often the most flexible approach, but be aware of the [performance implications of closures](https://discourse.julialang.org/t/can-someone-explain-closures-to-me/105605).
3. Attach the data to the `trajectories`. Each [`Trajectory`](@ref) takes arbitrary keyword arguments that can be used to attach any data as attributes that a custom `J_T` function may then reference. This makes sense when the data is unique to each `trajectory`. In fact, the standard (but optional!) `target_state` itself is an example of this; for functionals where a `target_state` does not make sense, it can be omitted and replaced by arbitrary other data, like maybe a `target_op`. Note that if that `target_op` is the same for all trajectories, it would be less redundant to associate it with `J_T`, see item 2.


## How to deal with long-running calculations

For any calculation that runs for more than a couple of minutes, use the [`QuantumControl.run_or_load`](@ref) function. A particular case of a long-running calculation is a call to [`QuantumControl.optimize`](@ref) for a system of non-trivial size. For optimizations in particular, there is [`QuantumControl.@optimize_or_load`](@ref) that uses `run_or_load` around `optimize`, and stores the optimization result together with the (truncated) output from the optimization.

As an alternative to [`QuantumControl.run_or_load`](@ref), you might also consider the use of the [DrWatson package](@extref DrWatson :doc:`index`), which provides [`DrWatson.produce_or_load`](@extref). It has a slightly more opinionated approach to saving and uses automatic file names based on parameters in a `config` data structure. In contrast, [`QuantumControl.run_or_load`](@ref) gives more control over the filename and does not force you to organize parameters in a `config`.
