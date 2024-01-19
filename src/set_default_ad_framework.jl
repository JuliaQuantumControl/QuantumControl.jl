import QuantumControlBase

"""Set the default provider for automatic differentiation.

```julia
QuantumControl.set_default_ad_framework(mod; quiet=false)
```

registers the given module (package) as the default AD framework.

This determines the default setting for the `automatic` parameter in the
following functions:

* [`QuantumControl.Functionals.make_chi`](@ref QuantumControlBase.make_chi)
* [`QuantumControl.Functionals.make_gate_chi`](@ref)
* [`QuantumControl.Functionals.make_grad_J_a`](@ref QuantumControlBase.make_grad_J_a)

The given `mod` must be a supported AD framework, e.g.,

```julia
import Zygote
QuantumControl.set_default_ad_framework(Zygote)
```

Currently, there is built-in support for `Zygote` and `FiniteDifferences`.

For other packages to be used as the default AD framework, the appropriate
methods for `make_chi` etc. must be defined.

Unless `quiet=true`, calling `set_default_ad_framework` will show a message to
confirm the setting.

To unset the default AD framework, use

```julia
QuantumControl.set_default_ad_framework(nothing)
```
"""
function set_default_ad_framework(mod::Module; quiet=false)
    QuantumControlBase._set_default_ad_framework(mod; quiet=true)
    if !quiet
        @info "QuantumControl: Setting $mod as the default provider for automatic differentiation. This determines the default `automatic` setting for `QuantumControl.Functionals.make_chi`, `QuantumControl.Functionals.make_gate_chi`, and `QuantumControl.Functionals.make_grad_J_a`"
    end
    return nothing
end

function set_default_ad_framework(::Nothing; quiet=false)
    QuantumControlBase._set_default_ad_framework(nothing; quiet)
end
