module QuantumControl

using QuantumPropagators
export propagate, propstep!, propstep

using QuantumControlBase
export ControlProblem, Objective, WeightedObjective, liouvillian
export discretize, discretize_on_midpoints, getcontrols, get_control_parameters
export get_tlist_midpoints
export propagate_objective
export optimize

module Shapes
    using QuantumControlBase.Shapes
    export flattop, box, blackman
end

module Functionals
    using QuantumControlBase.Functionals
    export F_ss, J_T_ss, chi_ss!, F_sm, J_T_sm, chi_sm!, F_re, J_T_re, chi_re!
    export grad_J_T_sm!
end

using Krotov
using GRAPE

using Pkg
using UUIDs

"""Print the versions of the packages constituting QuantumControl."""
function print_versions()
    project_toml = Pkg.TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))
    version = project_toml["version"]
    direct_deps = project_toml["deps"]
    deps = Pkg.dependencies()
    pkg_names = [name for name in keys(direct_deps) if name ∉ ["Pkg", "UUIDs"]]
    col_width = maximum([length(name) for name in pkg_names])
    for name in reverse(pkg_names)
        pkginfo = deps[UUIDs.UUID(direct_deps[name])]
        if pkginfo.is_tracking_path
            println("$(rpad(name, col_width)): $(pkginfo.version) ($(pkginfo.source))")
        else
            println("$(rpad(name, col_width)): $(pkginfo.version)")
        end
    end
    println("$(rpad("QuantumControl", col_width)): $version")
end

end
