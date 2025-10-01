# Control Methods

All optimizations in the `QuantumControl` package are done by calling `QuantumControl.optimize`, or preferably the high-level wrapper [`@optimize_or_load`](@ref). The actual control methods are implemented in separate packages. The module implementing a particular method should be passed to `optimize` as the `method` keyword argument.

```@docs; canonical=false
optimize(::ControlProblem; method=:any)
```

The following methods of optimal control are implemented by packages in the [JuliaQuantumControl organization](https://github.com/JuliaQuantumControl):

```@contents
Pages = ["methods.md"]
Depth = 2:2
```

## Krotov's Method

See the [documentation](@extref Krotov :doc:`index`)  of the [`Krotov` package](https://github.com/JuliaQuantumControl/Krotov.jl) for more details.

```@docs; canonical=false
optimize(::ControlProblem, ::Val{:Krotov})
```

## GRAPE

The Gradient Ascent Pulse Engineering (GRAPE) method is implemented in the [`GRAPE` package](https://github.com/JuliaQuantumControl/GRAPE.jl). See the [`GRAPE` documentation](@extref GRAPE :doc:`index`) for details.

```@docs; canonical=false
optimize(::ControlProblem, ::Val{:GRAPE})
```

```@docs
GRAPE.optimize
```

