# API

```@contents
Pages = ["api.md"]
Depth = 4
```

## QuantumControl

```@docs
optimize
```

All other types and methods in `QuantumControl` or its submodules are re-exported from lower level packages (`QuantumControlBase`, `QuantumPropagators`, etc.):

* [`ControlProblem`](@ref)
* [`Objective`](@ref)
* [`WeightedObjective`](@ref)
* [`discretize`](@ref)
* [`discretize_on_midpoints`](@ref)
* [`getcontrols`](@ref)
* [`get_control_parameters`](@ref)
* [`liouvillian`](@ref)
* [`propagate`](@ref)
* [`propstep!`](@ref)



### `QuantumControl.shapes`

* [`QuantumControl.shapes.flattop`](@ref flattop)
* [`QuantumControl.shapes.box`](@ref box)
* [`QuantumControl.shapes.blackman`](@ref blackman)

### `QuantumControl.functionals`

* [`QuantumControl.functionals.F_ss`](@ref F_ss)
* [`QuantumControl.functionals.J_T_ss`](@ref J_T_ss)
* [`QuantumControl.functionals.chi_ss!`](@ref chi_ss!)
* [`QuantumControl.functionals.F_sm`](@ref F_sm)
* [`QuantumControl.functionals.J_T_sm`](@ref J_T_sm)
* [`QuantumControl.functionals.chi_sm!`](@ref chi_sm!)
* [`QuantumControl.functionals.F_re`](@ref F_re)
* [`QuantumControl.functionals.J_T_re`](@ref J_T_re)
* [`QuantumControl.functionals.chi_re!`](@ref chi_re!)


## Krotov

### Public

```@docs
Krotov.SquareParametrization
Krotov.TanhParametrization
Krotov.TanhSqParametrization
Krotov.LogisticParametrization,
Krotov.LogisticSqParametrization
Krotov.optimize_pulses
```

### Private

```@autodocs
Modules = [Krotov]
Private = true
Public = false
```

## QuantumControlBase

### Public

```@autodocs
Modules = [QuantumControlBase]
Private = false
Public = true
```

### Private

```@docs
QuantumControlBase.AbstractControlObjective
QuantumControlBase.adjoint
QuantumControlBase.f_tau
QuantumControlBase.initobjpropwrk
```

## QuantumPropagators

### Public

```@docs
specrange
cheby_coeffs
cheby_coeffs!
ChebyWrk
cheby!
NewtonWrk
newton!
ExpPropWrk
expprop!
init_storage
map_observables
map_observable
write_to_storage!
get_from_storage!
initpropwrk
propstep!
propagate
```

### Private

```@autodocs
Modules = [QuantumPropagators]
Private = true
Public = false
```

## Index

```@index
```
