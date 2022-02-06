#! format: off
module QuantumControl
include("reexport.jl")

using QuantumPropagators
@reexport_members(QuantumPropagators)

using QuantumControlBase
@reexport_members(QuantumControlBase)

module Shapes
    # we need `QuantumControlBase.Shapes` to be available under a name that
    # doesn't clash with `QuantumControl.Shapes` in order for the
    # `@reexport_members` macro to work correctly
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

using Krotov
using GRAPE

include("print_versions.jl")

end
