# QuantumControl.jl

[![Version](https://juliahub.com/docs/QuantumControl/version.svg)](https://juliahub.com/ui/Packages/QuantumControl/no1zM)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliaquantumcontrol.github.io/QuantumControl.jl/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliaquantumcontrol.github.io/QuantumControl.jl/dev)
[![Build Status](https://github.com/JuliaQuantumControl/QuantumControl.jl/workflows/CI/badge.svg)](https://github.com/JuliaQuantumControl/QuantumControl.jl/actions)
[![Coverage](https://codecov.io/gh/JuliaQuantumControl/QuantumControl.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaQuantumControl/QuantumControl.jl)

A Julia Framework for Quantum Dynamics and Control.

The [`QuantumControl`][QuantumControl] package collects the [packages][] in the [JuliaQuantumControl][] organization and provides a single coherent [API](https://juliaquantumcontrol.github.io/QuantumControl.jl/dev/api/quantum_control/#QuantumControlAPI) for solving quantum control problems. See the [organization README](https://github.com/JuliaQuantumControl#readme) for details.

The [`QuantumControl`][QuantumControl] package provides a framework for solving quantum control problems. It exposes the [packages][] in the [JuliaQuantumControl][] organization in a single coherent [API](https://juliaquantumcontrol.github.io/QuantumControl.jl/dev/api/quantum_control/#QuantumControlAPI). Specifically, it subsumes the [`QuantumPropagators`][QuantumPropagators] package to simulate quantum dynamics.


## Documentation

The [full documentation](https://juliaquantumcontrol.github.io/QuantumControl.jl/) is available at <https://juliaquantumcontrol.github.io/QuantumControl.jl/>.

Support is also available in the `#quantumcontrol` channel in the [Julia Slack](https://julialang.org/slack/).

## Installation

The [`QuantumControl.jl`][QuantumControl] package can be installed via the [standard Pkg manager](https://docs.julialang.org/en/v1/stdlib/Pkg/):

~~~
pkg> add QuantumControl
~~~

This will also install [all the packages][packages] of the [JuliaQuantumControl][] organization as dependencies.


[JuliaQuantumControl]: https://github.com/JuliaQuantumControl
[QuantumControl]: https://github.com/JuliaQuantumControl/QuantumControl.jl
[QuantumPropagators]: https://github.com/JuliaQuantumControl/QuantumPropagators.jl
[packages]: https://github.com/JuliaQuantumControl#packages
