<!--
SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>

SPDX-License-Identifier: MIT OR CC-BY-4.0
-->

# QuantumControl.jl

[![Version](https://juliahub.com/docs/General/QuantumControl/stable/version.svg)](https://juliahub.com/ui/Packages/General/QuantumControl)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliaquantumcontrol.github.io/QuantumControl.jl/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliaquantumcontrol.github.io/QuantumControl.jl/dev)
[![Build Status](https://github.com/JuliaQuantumControl/QuantumControl.jl/workflows/CI/badge.svg)](https://github.com/JuliaQuantumControl/QuantumControl.jl/actions)
[![Coverage](https://codecov.io/gh/JuliaQuantumControl/QuantumControl.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaQuantumControl/QuantumControl.jl)
[![REUSE status](https://github.com/JuliaQuantumControl/QuantumControl.jl/actions/workflows/REUSE.yml/badge.svg)](https://github.com/JuliaQuantumControl/QuantumControl.jl/actions/workflows/REUSE.yml)

A Julia Framework for Quantum Dynamics and Control.

The [`QuantumControl`][QuantumControl] package is a high-level interface for the [packages][] in the [JuliaQuantumControl][] organization and provides a coherent [API](https://juliaquantumcontrol.github.io/QuantumControl.jl/dev/api/quantum_control/#QuantumControlAPI) for solving quantum control problems. See the [organization README](https://github.com/JuliaQuantumControl#readme) for details.


## Documentation

The [full documentation](https://juliaquantumcontrol.github.io/QuantumControl.jl/) is available at <https://juliaquantumcontrol.github.io/QuantumControl.jl/>.

Support is also available in the `#quantumcontrol` channel in the [Julia Slack](https://julialang.org/slack/).


## Installation

The [`QuantumControl.jl`][QuantumControl] package can be installed via the [standard Pkg manager](https://docs.julialang.org/en/v1/stdlib/Pkg/):

~~~
pkg> add QuantumControl
~~~

You will also want to install the [`QuantumPropagators` package][QuantumPropagators]

~~~
pkg> add QuantumPropagator
~~~

to access a suitable dynamic solver for your problem (e.g. `using QuantumPropagators: Cheby`); as well as at least one package for a specific optimization method you are planning to use:

~~~
pkg> add Krotov
pkg> add GRAPE
~~~

See the [list of packages][packages] of the [JuliaQuantumControl][] organization.


## License

This package is licensed under the [MIT License](LICENSE). It follows the [REUSE specification](https://reuse.software/) for copyright and licensing information: every file carries its copyright and license via SPDX notices (in the file, in an adjacent `.license` file, or in `REUSE.toml`). The source code is licensed under MIT; prose and documentation are additionally available under [CC-BY-4.0](LICENSES/CC-BY-4.0.txt), and configuration and other trivial files under [CC0-1.0](LICENSES/CC0-1.0.txt). The full license texts are in the [`LICENSES/`](LICENSES) directory.


[JuliaQuantumControl]: https://github.com/JuliaQuantumControl
[QuantumControl]: https://github.com/JuliaQuantumControl/QuantumControl.jl
[QuantumPropagators]: https://github.com/JuliaQuantumControl/QuantumPropagators.jl
[packages]: https://github.com/JuliaQuantumControl#packages
