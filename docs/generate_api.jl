#! format: off
import QuantumControl
import Documenter


"""Return a list of symbols for the names directly defined in `pkg`.

This filters out re-exported names and sub-modules. By default, for `all=true`,
both public (exported) and private names are included. With `all=false`, the
list is filtered to include only exported names.
"""
function get_local_members(pkg; all=true)
    return [
        m for m in names(pkg, all=all) if !(
            (startswith(String(m), "#")) ||       # compiler-generated names
            (getfield(pkg, m) isa Union{Dict,Array,Set}) ||  # global variable
            (m == Symbol(pkg)) ||                 # the package itself
            (m == :eval) ||                       # compiler-injected "eval"
            (m == :include) ||                    # compiler-injected "include"
            ((getfield(pkg, m)) isa Module) ||    # sub-modules
            (_parentmodule(getfield(pkg, m), pkg)) ≠ pkg  # re-exported
        )
    ]
end

function _parentmodule(m, pkg)
    try
        parentmodule(m)
    catch
        return pkg
    end
end


"""Return a list of symbols for all the sub-modules of `pkg`.
"""
function get_submodules(pkg)
    return [
        m for m in names(pkg, all=true)
        if (getfield(pkg, m) isa Module) && !(m == Symbol(pkg))
    ]
end


"""Return the canonical fully qualified name of an object (function, type).

Given e.g. a function object, it returns a string containing the canonical
fully qualified name of the original function definition.
"""
function canonical_name(obj)
    mod = parentmodule(obj)
    modpath = fullname(mod)
    modname = join((String(sym) for sym in modpath), ".")
    objname = String(nameof(obj))
    return "$modname.$objname"
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
    (:QuantumPropagators, "quantum_propagators.md"),
    (:QuantumControlBase, "quantum_control_base.md"),
]


outfile = joinpath(@__DIR__, "src", "api", "quantum_control.md")
println("Generating API for QuantumControl in $outfile")
open(outfile, "w") do out
    write(out, "```@meta\n")
    write(out, "EditURL = \"../../generate_api.jl\"\n")
    write(out, "```\n\n")
    write(out, "# [QuantumControl](@id QuantumControlAPI)\n\n")
    _quantum_control_local_members  = filter(
        member -> !(member in QuantumControl.DEPRECATED),
        quantum_control_local_members
    )
    if length(_quantum_control_local_members) > 0
        error("QuantumControl has local members. We don't want this")
    end
    write(out, """

    QuantumControl (re-)exports the following symbols:


    """)
    for name ∈ quantum_control_reexported_members
        obj = getfield(QuantumControl, name)
        ref = canonical_name(obj)
        println(out, "* [`$name`](@ref $ref)")
    end

    write(out, """

    It also defines the following unexported functions:

    * [`QuantumControl.set_default_ad_framework`](@ref)
    * [`QuantumControl.print_versions`](@ref)

    """)

    for submod in quantum_control_sub_modules
        write(out, "\n\n### [`QuantumControl.$submod`](@id QuantumControl$(submod)API)\n\n")
        for name in names(getfield(QuantumControl, submod))
            if name ≠ submod
                obj = getfield(getfield(QuantumControl, submod), name)
                ref = canonical_name(obj)
                println(out, "* [`QuantumControl.$submod.$name`](@ref $ref)")
            end
        end
    end

    write(out, """

    ### Subpackages

    `QuantumControl` contains the following sub-packages from the
    [JuliaQuantumControl](https://github.com/JuliaQuantumControl)
    organization:

    """)
    for (pkgname::Symbol, outfilename) in subpackages
        local outfile = joinpath(@__DIR__, "src", "api", outfilename)
        write(out, "* [`$pkgname`](@ref $(pkgname)Package)\n")
    end
end


local_submodules = [:Functionals, :PulseParameterizations, :Workflows]

local_module_api_id(mod) = replace("$mod", "." => "") * "LocalAPI"

function write_module_api(out, mod, description="")

    members = [
        m for m in names(mod)
        if !(
            (String(Symbol(mod)) |> endswith(".$m")) ||
            m == Symbol(mod)
        )
    ]

    public_members = get_local_members(mod, all=false)

    all_local_members = get_local_members(mod, all=true)

    documented_members = [
        k.var for k in keys(Documenter.DocSystem.getmeta(mod))
    ]
    documented_private_members = [
        name for name in documented_members
        if (name ∉ public_members) && (name ∈ all_local_members)
    ]

    reexported_members = [
        m for m in members
        if m ∉ public_members
    ]

    write(out, "\n\n## [`$mod`](@id $(local_module_api_id(mod)))\n\n")
    if length(description) > 0
        write(out, "\n\n")
        write(out, description)
        write(out, "\n\n")
    end
    if length(public_members) > 0
        write(out, "\nPublic Members:\n\n")
        for name ∈ public_members
            println(out, "* [`$name`](@ref $mod.$name)")
        end
        write(out, "\n")
    end
    if length(reexported_members) > 0
        write(out, "\nRe-exported Members:\n\n")
        for name ∈ reexported_members
            obj = getfield(mod, name)
            ref = canonical_name(obj)
            println(out, "* [`$name`](@ref $ref)")
        end
        write(out, "\n")
    end
    if length(documented_private_members) > 0
        write(out, "\nPrivate Members:\n")
        for name ∈ documented_private_members
            println(out, "* [`$name`](@ref $mod.$name)")
        end
        write(out, "\n")
    end
    if length(public_members) > 0
        write(out, "\n\n#### Public members\n\n")
        println(out, "```@docs")
        for name ∈ public_members
            println(out, "$mod.$name")
        end
        println(out, "```")
    end
    if length(documented_private_members) > 0
        write(out, "\n\n#### Private members\n\n")
        println(out, "```@docs")
        for name ∈ documented_private_members
            println(out, "$mod.$name")
        end
        println(out, "```")
    end

end


outfile = joinpath(@__DIR__, "src", "api", "quantum_control_reference.md")
println("Generating local reference for QuantumControl in $outfile")
open(outfile, "w") do out
    write(out, "```@meta\n")
    write(out, "EditURL = \"../../generate_api.jl\"\n")
    write(out, "```\n\n")
    write(out, raw"""
    # Local Submodules

    The following submodules of `QuantumControl` are defined *locally* (as
    opposed to being re-exported from sub-packages).

    ``\gdef\tgt{\text{tgt}}``
    ``\gdef\tr{\operatorname{tr}}``
    ``\gdef\Re{\operatorname{Re}}``
    ``\gdef\Im{\operatorname{Im}}``
    """)
    for name in local_submodules
        write(out, "* [`QuantumControl.$name`](#$(local_module_api_id(getfield(QuantumControl, name))))\n")
    end
    write(out, raw"""

    `QuantumControl` also locally defines some unexported functions:

    * [`QuantumControl` local unexported functions](#quantumcontrol-local-functions)


    """)
    for name in local_submodules
        write_module_api(out, getfield(QuantumControl, name))
    end
    write(out, raw"""

    ## [`QuantumControl` local unexported functions](@id quantumcontrol-local-functions)

    ```@docs
    QuantumControl.set_default_ad_framework
    QuantumControl.print_versions
    ```

    ```@example
    import QuantumControl
    QuantumControl.print_versions()
    ```

    """)
end


outfile = joinpath(@__DIR__, "src", "api", "quantum_control_index.md")
println("Generating index for QuantumControl in $outfile")
open(outfile, "w") do out
    write(out, "```@meta\n")
    write(out, "EditURL = \"../../generate_api.jl\"\n")
    write(out, "```\n\n")
    write(out, raw"""
    # API Index

    ```@index
    ```
    """)
end


for (pkgname::Symbol, outfilename) in subpackages

    local outfile = joinpath(@__DIR__, "src", "api", outfilename)
    println("Generating API for $pkgname in $outfile")
    open(outfile, "w") do out

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
        write(out, "```@meta\n")
        write(out, "EditURL = \"../../generate_api.jl\"\n")
        write(out, "```\n\n")
        write(out, "\n\n# [$pkgname Package](@id $(pkgname)Package)\n\n")
        write(out, "## Package Index\n\n")
        write(out, raw"""
        ``\gdef\tgt{\text{tgt}}``
        ``\gdef\tr{\operatorname{tr}}``
        ``\gdef\Re{\operatorname{Re}}``
        ``\gdef\Im{\operatorname{Im}}``
        """)
        write(out, """

        ```@index
        Pages   = ["$outfilename"]
        ```

        """)
        write(out, "\n\n## [`$pkgname`](@id $(pkgname)API)\n\n")
        if length(public_members) > 0
            write(out, "\nPublic Members:\n\n")
            for name in public_members
                write(out, "* [`$name`](@ref $pkgname.$name)\n")
            end
        end
        if length(documented_private_members) > 0
            write(out, "\nPrivate Members:\n\n")
            for name in documented_private_members
                write(out, "* [`$name`](@ref $pkgname.$name)\n")
            end
        end

        sub_modules = get_submodules(pkg)
        if length(sub_modules) > 0
            write(out, "\nSubmodules:\n\n")
            for submodname in sub_modules
                write(out, "* [`$pkgname.$submodname`](#$(pkgname)$(submodname)API)\n")
            end
        end

        if length(public_members) + length(documented_private_members) > 0
            write(out, "\n### Reference\n\n")
            write(out, "\n```@docs\n")
            for name in public_members
                write(out, "$pkgname.$name\n")
            end
            for name in documented_private_members
                write(out, "$pkgname.$name\n")
            end
            write(out, "```\n\n")
        end

        for submodname in sub_modules
            submod = getfield(pkg, submodname)
            all_local_members = get_local_members(submod)
            public_members = get_local_members(submod, all=false)
            documented_members = [
                k.var for k in keys(Documenter.DocSystem.getmeta(submod))
            ]
            documented_private_members = [
                name for name in documented_members
                if (name ∉ public_members) && (name ∈ all_local_members)
            ]
            if length(public_members) + length(documented_private_members) > 0
                write(out, "\n## [`$pkgname.$submodname`](@id $(pkgname)$(submodname)API)\n\n")
            end
            if length(public_members) > 0
                write(out, "\nPublic:\n\n")
                for name in public_members
                    write(out, "* [`$name`](@ref $pkgname.$submodname.$name)\n")
                end
            end
            if length(documented_private_members) > 0
                write(out, "\nPrivate:\n\n")
                for name in documented_private_members
                    write(out, "* [`$name`](@ref $pkgname.$submodname.$name)\n")
                end
            end
            if length(public_members) +  length(documented_private_members) > 0
                write(out, "\n### Reference\n\n")
                write(out, "\n```@docs\n")
                for name in public_members
                    write(out, "$pkgname.$submodname.$name\n")
                end
                for name in documented_private_members
                    write(out, "$pkgname.$submodname.$name\n")
                end
                write(out, "```\n\n")
            end
        end

    end

end
