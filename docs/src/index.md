# QuantumControl.jl

[QuantumControl.jl](https://github.com/JuliaQuantumControl/QuantumControl.jl@readme) is a [Julia framework for quantum optimal control](https://github.com/JuliaQuantumControl).

[Quantum optimal control](https://link.springer.com/article/10.1140%2Fepjd%2Fe2015-60464-1) attempts to steer a quantum system in some desired way by finding optimal control parameters or control fields inside the system Hamiltonian or Liouvillian. Typical control tasks are the preparation of a specific quantum state or the realization of a logical gate in a quantum computer (["pulse level control"](https://arxiv.org/abs/2004.06755)). Thus, quantum control theory is a critical part of realizing quantum technologies at the lowest level. Numerical methods of *open-loop* quantum control (methods that do not involve measurement feedback from a physical quantum device) such as [Krotov's method](https://github.com/JuliaQuantumControl/Krotov.jl) and [GRAPE](https://github.com/JuliaQuantumControl/GRAPE.jl) address the control problem by [simulating the dynamics of the system](https://github.com/JuliaQuantumControl/QuantumPropagators.jl) and then iteratively improving the value of a functional that encodes the desired outcome.

The `QuantumControl.jl` package collects the [packages](https://github.com/JuliaQuantumControl#packages) in the [JuliaQuantumControl](https://github.com/JuliaQuantumControl) organization and provides a single coherent [API](@ref QuantumControlAPI) for solving the quantum control problem.


## Getting Started

* See the [installation instructions](https://github.com/JuliaQuantumControl/QuantumControl.jl#installation) on Github.

* Look at a [simple example for a state-to-state transition with Krotov's method](https://juliaquantumcontrol.github.io/Krotov.jl/stable/examples/simple_state_to_state/) to get a feeling for how the `QuantumControl` package is intended to be used, or look at the larger list of [Examples](@ref examples-list).

* Read the [Glossary](@ref) and [User Manual](@ref) to understand the philosophy of the framework.

## Contents

```@contents
Pages = [
    "glossary.md",
    "manual.md",
    "howto.md",
]
Depth = 2
```

### Examples

```@contents
Pages = [
    "examples/index.md",
]
```

### API

```@contents
Pages = [
    "api/quantum_control.md",
]
Depth = 1
```

#### Sub-Packages

```@contents
Pages = [
    "api/quantum_propagators.md",
    "api/quantum_control_base.md",
    "api/krotov.md",
    "api/grape.md",
]
Depth = 1
```

### History

```@contents
Pages = [
    "history.md",
]
Depth = 1
```
