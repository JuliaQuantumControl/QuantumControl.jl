#! format: off
module QuantumControl
include("reexport.jl")

using QuantumPropagators
@reexport_members(QuantumPropagators)

using QuantumControlBase
@reexport_members(QuantumControlBase)


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
    using QuantumControlBase: get_control_deriv, get_control_derivs
    export get_control_deriv, get_control_derivs
end


module Shapes
    using QuantumPropagators: Shapes as QuantumPropagators_Shapes
    using QuantumPropagators.Shapes
    include("reexport.jl")
    @reexport_members(QuantumPropagators_Shapes)
end


module Amplitudes
    using QuantumPropagators: Amplitudes as QuantumPropagators_Amplitudes
    using QuantumPropagators.Amplitudes
    include("reexport.jl")
    @reexport_members(QuantumPropagators_Amplitudes)
end


module PulseParametrizations
    using QuantumControlBase: PulseParametrizations as QuantumControlBase_PulseParametrizations
    using QuantumControlBase.PulseParametrizations
    include("reexport.jl")
    @reexport_members(QuantumControlBase_PulseParametrizations)
end


module Functionals
    using QuantumControlBase: Functionals as QuantumControlBase_Functionals
    using QuantumControlBase.Functionals
    include("reexport.jl")
    @reexport_members(QuantumControlBase_Functionals)
end

module WeylChamber
    using QuantumControlBase: WeylChamber as QuantumControlBase_WeylChamber
    using QuantumControlBase.WeylChamber
    include("reexport.jl")
    @reexport_members(QuantumControlBase_WeylChamber)
end

using Krotov
using GRAPE

include("print_versions.jl")

end
