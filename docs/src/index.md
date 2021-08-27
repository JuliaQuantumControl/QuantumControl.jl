# QuantumControl

Documentation for [QuantumControl](https://github.com/quantumcontrol-jl/QuantumControl.jl).


## Control problems

```@docs
ControlProblem
Objective
```

## Discretization

```@docs
discretize
discretize_on_midpoints
```

## Time dependencies

```@docs
setcontrolvals
setcontrolvals!
getcontrols
```

## Control shapes

```@docs
flattop
box
blackman
```


## Propagation

```@docs
propagate
initpropwrk
propstep!
ChebyWrk
cheby_coeffs!
cheby_coeffs
NewtonWrk
ExpPropWrk
cheby!
newton!
expprop!
```


## Storage

```@docs
init_storage
write_to_storage!
get_from_storage!
map_observable
map_observables
```

## Optimization

```@docs
optimize_pulses
```

## Index

```@index
```
