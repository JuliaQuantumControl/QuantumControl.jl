import QuantumControl
import Documenter


"""Return a list of symbols for the names directly defined in `pkg`.

This filters out re-exported names and sub-modules. By default, for `all=true`,
both public (exported) and private names are included. With `all=false`, the
list is filtered to include only exported names.
"""
function get_local_members(pkg; all=true)
    return [
        m for m in names(pkg, all=all)
        if !(
            (startswith(String(m), "#")) ||       # compiler-generated names
            (m == Symbol(pkg)) ||                 # the package itself
            (m == :eval) ||                       # compiler-injected "eval"
            (m == :include) ||                    # compiler-injected "include"
            ((getfield(pkg, m)) isa Module) ||    # sub-modules
            (parentmodule(getfield(pkg, m))) ≠ pkg  # re-exported
       )
    ]
end

"""Return a list of symbols for all the sub-modules of `pkg`.
"""
function get_submodules(pkg)
    return [
        m for m in names(pkg, all=true)
        if  (getfield(pkg, m) isa Module) && !(m == Symbol(pkg))
    ]
end



quantum_control_members = [
    m for m in names(QuantumControl)
    if m ≠ :QuantumControl
]

quantum_control_local_members = get_local_members(QuantumControl, all=false)

quantum_control_reexported_members = [
    m for m in quantum_control_members
    if m ∉ quantum_control_local_members
]

quantum_control_sub_modules = get_submodules(QuantumControl)


subpackages = [
    :QuantumPropagators,
    :QuantumControlBase,
    :Krotov,
    :GRAPE,
]


open(joinpath(@__DIR__, "src", "api.md"), "w") do out
    write(out, """
    # API

    ```@contents
    Pages = ["api.md"]
    Depth = 4
    ```

    ## QuantumControl
    """)

    if length(quantum_control_local_members) > 0
        println(out, "```@docs")
        for name ∈ quantum_control_local_members
            println(out, name)
        end
        println(out, "```")
    end
    write(out, """

    QuantumControl re-exports the following members:

    """)
    for name ∈ quantum_control_reexported_members
        println(out, "* [`$name`](@ref)")
    end

    for submod in quantum_control_sub_modules
        write(out, "\n\n### `Quantumcontrol.$submod`\n\n")
        for name in names(getfield(QuantumControl, submod))
            if name ≠ submod
                println(out, "* [`QuantumControl.$submod.$name`](@ref $submod.$name)")
            end
        end
    end

    write(out, "\n\n## Sub-Packages\n\n")

    for pkgname::Symbol in subpackages
        pkg = getfield(QuantumControl, pkgname)
        all_local_members = get_local_members(pkg)
        public_members = get_local_members(pkg, all=false)
        documented_members = [
            k.var for k in keys(Documenter.DocSystem.getmeta(pkg))
        ]
        documented_private_members = [
            name for name in documented_members
            if (name ∉ public_members) && (name ∈ all_local_members)
        ]
        write(out, "\n\n### $pkgname\n\n")
        if length(public_members) > 0
            write(out, "\n#### Public\n\n")
            write(out, "```@docs\n")
            for name in public_members
                write(out, "$pkgname.$name\n")
            end
            write(out, "```\n\n")
        end
        if length(documented_private_members) > 0
            write(out, "\n#### Private\n\n")
            write(out, "```@docs\n")
            for name in documented_private_members
                write(out, "$pkgname.$name\n")
            end
            write(out, "```\n\n")
        end
    end

end
