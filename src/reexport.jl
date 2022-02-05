# I'm aware of Reexport.jl, but it doesn't work for QuantumControl.jl
#
# For one thing, `@reexport using QuantumControlBase` re-exports not just the
# members of `QuantumControlBase`, but also `QuantumControlBase` itself. Also,
# as far as I can tell `@reexport using QuantumControlBase.Shapes` does not
# work when it's inside a module also called `Shapes`, as we're doing.
#
# Besides, the macro below is pretty trivial

macro reexport_members(modname::Symbol)
    mod = getfield(__module__, modname)
    member_names = _exported_names(mod)
    Expr(:export, member_names...)
end

function _exported_names(m::Module)
    return filter!(
        x -> (Base.isexported(m, x) && (x != nameof(m))),
        names(m; all=true, imported=true)
    )
end
