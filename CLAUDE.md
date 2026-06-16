<!--
SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>

SPDX-License-Identifier: MIT OR CC0-1.0
-->

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Contributor Workflow

This package follows the organization-wide contributor workflow (running tests, building docs, formatting, and the release process). Read these shared guidelines and act in line with how a human contributor would:

@../.github/CONTRIBUTING.md

If the `@`-reference above did not load its contents (the org-wide `.github` checkout is not present), fetch the guidelines from <https://raw.githubusercontent.com/JuliaQuantumControl/.github/master/CONTRIBUTING.md> instead.

Key commands:

- `make test` — run the full test suite (or `julia --project=test -e 'include("test/runtests.jl")'`)
- `make devrepl` — start the development REPL (Revise, JuliaFormatter, coverage helpers); alternatively `julia -i --banner=no devrepl.jl`
- `make docs` — build the documentation
- `make codestyle` — apply JuliaFormatter (version pinned in `test/Project.toml`)
- `make clean` / `make distclean` — remove build/test artifacts

## Package Architecture

### Core Framework Structure
QuantumControl.jl is a high-level interface package that provides a coherent API for quantum dynamics and control. It re-exports functionality from QuantumPropagators.jl and organizes quantum control workflows.

### Key Components

**Main Module Structure:**
- `src/QuantumControl.jl` - Main module with submodules for Generators, Controls, Shapes, Storage, Amplitudes, and Interfaces
- Re-exports QuantumPropagators functionality through organized submodules
- Each submodule uses `@reexport_members` macro to expose underlying functionality

**Core Abstractions:**
- `ControlProblem` (`src/control_problem.jl`) - Defines multi-trajectory optimization problems
- `Trajectory` (`src/trajectories.jl`) - Describes time evolution of quantum states under generators
- `optimize` (`src/optimize.jl`) - Main optimization interface that delegates to specific methods (Krotov, GRAPE, etc.)

**Supporting Infrastructure:**
- `src/functionals.jl` - Optimization functionals submodule
- `src/pulse_parameterizations.jl` - Pulse parameterization utilities
- `src/workflows.jl` - High-level workflow utilities (run_or_load, save/load optimization)
- `src/callbacks.jl` - Optimization callback system
- `src/interfaces/` - Interface validation for amplitudes and generators

### Development Environment
- Uses `devrepl.jl` for development setup with automatic package installation
- Test environment in `test/` with comprehensive suite covering all major functionality
- Documentation system uses Documenter.jl with custom themes and API generation

### Dependencies and Extensions
- Core dependency: QuantumPropagators.jl for propagation functionality
- Optional extensions for FiniteDifferences.jl and Zygote.jl for automatic differentiation
- Integration with optimization packages (Krotov.jl, GRAPE.jl) via method dispatch

### Testing Strategy
- Comprehensive test suite with SafeTestsets for isolation
- Tests for interfaces, propagation, optimization, parameterization, and workflows
- Coverage reporting and CI integration
- Downstream testing of Krotov and GRAPE packages

## Changelog

`CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) / [SemVer](https://semver.org/). Non-obvious conventions:

* Record user-facing changes under `## [Unreleased]` as bullets with an inline category prefix (`Added:`/`Changed:`/`Deprecated:`/`Removed:`/`Fixed:`/`Security:`), not `###` subsections; link issues/PRs as `[[#123]]`, issue before its resolving PR (`[[#91], [#93]]`). Exclude CI, dependency bumps, formatting, and internal-only changes — a leading underscore (e.g. `_helper`) marks a name as internal.
* Pre-1.0, Julia treats every `v0.x.0` as breaking, so non-breaking changes go into a `v0.x.y` bugfix release.
* Version links point to the release page (`[vX.Y.Z]: …/releases/tag/vX.Y.Z`); only `[Unreleased]` uses a compare link (`…/compare/v<latest>..HEAD`).
* `pull/` vs `issues/` can't be verified by loading the URL (GitHub redirects between them); confirm the category with `gh api repos/JuliaQuantumControl/QuantumControl.jl/issues/<N> --jq 'if has("pull_request") then "pull" else "issue" end'`.
* Releasing on a `release-*` branch: rename `## [Unreleased]` to `## [vX.Y.Z] — YYYY-MM-DD` and point `[Unreleased]` at `…/compare/vX.Y.Z..HEAD`, but do **not** add a fresh `## [Unreleased]` heading — re-add it when merging back to `master`.
* `make check-changelog` validates links (textual, no network; also run in CI via `make codestyle`); `make changelog` additionally fills in missing `[#N]` targets, so you can just write `[[#123]]`. Neither verifies that links resolve — check that, and the issue/PR category, manually.
