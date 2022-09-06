#! format: off
module QuantumControl
include("reexport.jl")

using QuantumPropagators
@reexport_members(QuantumPropagators)

using QuantumControlBase
@reexport_members(QuantumControlBase)

module Controls
    # we need `QuantumPropagators.Controls` to be available under a name that
    # doesn't clash with `QuantumControl.Controls` in order for the
    # `@reexport_members` macro to work correctly
    using QuantumPropagators: Controls as QuantumPropagators_Controls
    using QuantumPropagators.Controls
    include("reexport.jl")
    @reexport_members(QuantumPropagators_Controls)
end

module Shapes
    using QuantumControlBase: Shapes as QuantumControlBase_Shapes
    using QuantumControlBase.Shapes
    include("reexport.jl")
    @reexport_members(QuantumControlBase_Shapes)
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
