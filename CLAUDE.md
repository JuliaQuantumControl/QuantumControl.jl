# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Testing and Development
- `make test` - Run the complete test suite in a subprocess with coverage
- `julia --project=test --banner=no --startup-file=yes -e 'include("devrepl.jl"); test()'` - Run tests directly
- `include("test/runtests.jl")` - Run tests from within Julia REPL

### Code Quality and Formatting
- `make codestyle` - Apply JuliaFormatter to the entire project

### Documentation
- `make docs` - Build the documentation using Documenter.jl
- `include("docs/make.jl")` - Build docs from within Julia REPL

### Maintenance
- `make clean` - Clean up build/doc/testing artifacts
- `make distclean` - Restore to a clean checkout state

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
