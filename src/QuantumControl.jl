#! format: off
module QuantumControl
include("reexport.jl")

using QuantumPropagators
@reexport_members(QuantumPropagators)

module Generators
    # we need `QuantumPropagators.Generators` to be available under a name that
    # doesn't clash with `QuantumControl.Generators` in order for the
    # `@reexport_members` macro to work correctly
    using QuantumPropagators: Generators as QuantumPropagators_Generators
    using QuantumPropagators.Generators
    include("reexport.jl")
    @reexport_members(QuantumPropagators_Generators)
end


module Controls
    using QuantumPropagators: Controls as QuantumPropagators_Controls
    using QuantumPropagators.Controls
    include("reexport.jl")
    @reexport_members(QuantumPropagators_Controls)
    include("derivs.jl")
    export get_control_deriv, get_control_derivs
end


module Shapes
    using QuantumPropagators: Shapes as QuantumPropagators_Shapes
    using QuantumPropagators.Shapes
    include("reexport.jl")
    @reexport_members(QuantumPropagators_Shapes)
end


module Storage
    using QuantumPropagators: Storage as QuantumPropagators_Storage
    using QuantumPropagators.Storage
    include("reexport.jl")
    @reexport_members(QuantumPropagators_Storage)
end


module Amplitudes
    using QuantumPropagators: Amplitudes as QuantumPropagators_Amplitudes
    using QuantumPropagators.Amplitudes
    include("reexport.jl")
    @reexport_members(QuantumPropagators_Amplitudes)
end


module Interfaces
    using QuantumPropagators.Interfaces: check_state, check_operator, check_control, check_parameterized_function, check_parameterized, supports_inplace
    export check_state, check_operator, check_control, check_parameterized_function, check_parameterized, supports_inplace
    include("interfaces/amplitude.jl")
    include("interfaces/generator.jl")
    export check_generator, check_amplitude
end


include("pulse_parameterizations.jl")  # submodule PulseParameterizations

include("functionals.jl")  # submodule Functionals

include("print_versions.jl")
include("set_default_ad_framework.jl")
include("result.jl")

include("deprecate.jl")

include("atexit.jl")
include("conditionalthreads.jl")
include("trajectories.jl")
include("control_problem.jl")
include("propagate.jl")
include("callbacks.jl")
include("optimize.jl")
export ControlProblem, Trajectory, optimize, propagate_trajectory
export propagate_trajectories


include("workflows.jl")  # submodule Workflows
using .Workflows: run_or_load, @optimize_or_load, save_optimization, load_optimization
export run_or_load, @optimize_or_load, save_optimization, load_optimization


end
