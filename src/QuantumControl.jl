module QuantumControl

using QuantumPropagators
export propagate, propstep!

using QuantumControlBase
export ControlProblem, Objective, WeightedObjective, liouvillian
export discretize, discretize_on_midpoints, getcontrols, get_control_parameters

module shapes
    using QuantumControlBase
    export flattop, box, blackman
end

module functionals
    using QuantumControlBase
    export F_ss, J_T_ss, chi_ss!, F_sm, J_T_sm, chi_sm!, F_re, J_T_re, chi_re!
    export grad_J_T_sm!
end

using Krotov

include("optimize.jl")
export optimize

end
