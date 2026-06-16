<!--
SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>

SPDX-License-Identifier: MIT OR CC0-1.0
-->

# Release Notes

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v0.11.4] — 2026-06-16

* Added: `J_a_avg_zero`, a running cost that penalizes a non-zero average pulse value [[#109]]
* Added: A derivative for `GuidedAmplitude` [[#107]]
* Added: Support for state-dependent running costs [[#103]]
* Added: Support for optimization gradients with respect to trajectories [[#101]]
* Added: `check_state_kwargs` and `check_generator_kwargs` keyword arguments to `optimize` [[#100]]
* Changed: `J_a_fluence` now also works on non-uniform time grids [[#108]]
* Changed: `J_b` is now evaluated using the trapezoidal rule [[#105]]
* Fixed: Compatibility with Zygote 0.7
* Fixed: Properly declare minimum supported Julia version as 1.10
* Updated: Require `QuantumPropagators v0.9`
* Fixed: Properly declare the minimum supported versions of the `ChainRulesCore`, `FileIO`, `FiniteDifferences`, `JLD2`, and `Zygote` dependencies
* Added: The project now follows the [REUSE specification](https://reuse.software/) for copyright and licensing information, with SPDX headers on all files

## [v0.11.3] — 2025-09-30

* Changed: `make_chi` now introspects `J_T` to determine the default `via` argument [[#90]]

## [v0.11.2] — 2025-08-25

* Changed: Support for JLD2 0.6
* Changed: Documentation improvements

## [v0.11.1] — 2024-09-24

* Added: `AbstractOptimizationResult`, defining the general structure of an optimization result [[#78]]

## [v0.11.0] — 2024-09-04

* Removed: The dependency on `QuantumControlBase`; functionality is now provided directly
* Changed: `grad_J_a` now acts not-in-place

## [v0.10.0] — 2024-07-27

* Added: `QuantumControl.Interfaces.supports_inplace` is now exported
* Changed: The `chi` functions now act not-in-place
* Changed: Normalized the spelling of `PulseParametrization`
* Fixed: The constructor for `ParametrizedAmplitude`

## [v0.9.1] — 2024-04-22

* Added: `check_parameterized` is now exported
* Changed: Improved log messages

## [v0.9.0] — 2024-01-23

* Removed: Krotov and GRAPE are no longer bundled as sub-packages; they are now separate dependencies
* Changed: Renamed "objective" to "trajectory" (`Objective` → `Trajectory`)
* Changed: Automatic-differentiation gradients were moved into an extension module

## [v0.8.3] — 2024-01-17

* Added: Support for the `JULIA_CAPTURE_COLOR` environment variable
* Changed: `@optimize_or_load` now captures output

## [v0.8.2] — 2024-01-08

* Changed: Documentation improvements

## [v0.8.1] — 2023-10-18

* Added: `check_amplitude` is now exported
* Changed: The minimum supported Julia version is now 1.9

## [v0.8.0] — 2023-05-16

* Added: `Interfaces` module with interface-checking routines
* Fixed: Instantiation of `ParametrizedAmplitude` without a shape

## [v0.7.0] — 2023-04-04

* Removed: The dependency on `DrWatson

## [v0.6.2] — 2023-03-19

* Added: `save_optimization` function in the workflows submodule
* Changed: Unpinned Zygote

## [v0.6.1] — 2023-03-15

* Added: References to the documentation
* Changed: Improved error handling in `run_or_load`

## [v0.6.0] — 2023-02-16

* Changed: Major restructuring of the package

## [v0.5.0] — 2022-12-01

* Added: `Controls`, `Amplitudes`, and `PulseParametrizations` submodules
* Changed: Adapted to the new `Generator`/`Operator` structure and the generalized `evaluate`/`substitute` from QuantumPropagators

## [v0.4.0] — 2022-10-02

* Revised: Documentation improvements

## [v0.3.1] — 2022-09-26

* Revised: Documentation updates

## [v0.3.0] — 2022-09-08

* Removed: `get_control_parameters` (temporarily)
* Changed: Adapted to the new QuantumPropagators propagation interface

## [v0.2.0] — 2022-03-23

* Added: Re-export of the `WeylChamber` submodule

## [v0.1.0] — 2022-02-15

Initial public release.

[Unreleased]: https://github.com/JuliaQuantumControl/QuantumControl.jl/compare/v0.11.4..HEAD
[v0.11.4]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.11.4
[v0.11.3]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.11.3
[v0.11.2]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.11.2
[v0.11.1]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.11.1
[v0.11.0]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.11.0
[v0.10.0]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.10.0
[v0.9.1]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.9.1
[v0.9.0]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.9.0
[v0.8.3]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.8.3
[v0.8.2]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.8.2
[v0.8.1]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.8.1
[v0.8.0]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.8.0
[v0.7.0]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.7.0
[v0.6.2]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.6.2
[v0.6.1]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.6.1
[v0.6.0]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.6.0
[v0.5.0]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.5.0
[v0.4.0]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.4.0
[v0.3.1]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.3.1
[v0.3.0]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.3.0
[v0.2.0]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.2.0
[v0.1.0]: https://github.com/JuliaQuantumControl/QuantumControl.jl/releases/tag/v0.1.0
[#78]: https://github.com/JuliaQuantumControl/QuantumControl.jl/pull/78
[#90]: https://github.com/JuliaQuantumControl/QuantumControl.jl/pull/90
[#100]: https://github.com/JuliaQuantumControl/QuantumControl.jl/pull/100
[#101]: https://github.com/JuliaQuantumControl/QuantumControl.jl/pull/101
[#103]: https://github.com/JuliaQuantumControl/QuantumControl.jl/pull/103
[#105]: https://github.com/JuliaQuantumControl/QuantumControl.jl/pull/105
[#107]: https://github.com/JuliaQuantumControl/QuantumControl.jl/pull/107
[#108]: https://github.com/JuliaQuantumControl/QuantumControl.jl/pull/108
[#109]: https://github.com/JuliaQuantumControl/QuantumControl.jl/pull/109
