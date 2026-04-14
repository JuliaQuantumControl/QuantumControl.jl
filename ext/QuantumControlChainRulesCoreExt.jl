module QuantumControlChainRulesCoreExt

using ChainRulesCore: ChainRulesCore, NoTangent
using QuantumControl: Trajectory


# Allow to differentiate w.r.t. to a trajectory. See `test_traj_zygote.jl` for
# an example. Evaluating a gradient with Zygote returns a NamedTuple with
# the fields of the trajectory. Unfortunately, Zygote gets confused about the
# custom `getproperty` method that is defined for a Trajectory, and we need a
# special method to differential through `getproperty`
function ChainRulesCore.rrule(::typeof(getproperty), traj::Trajectory, name::Symbol)
    val = getproperty(traj, name)
    if name in (:initial_state, :generator, :target_state, :weight)
        function field_pullback(Δ)
            dt = ChainRulesCore.Tangent{typeof(traj)}(; (name => Δ,)...)
            return NoTangent(), dt, NoTangent()
        end
        return val, field_pullback
    else
        # kwargs-stored property: route gradient back into the kwargs Dict
        function kwargs_pullback(Δ)
            dkwargs = Dict{Symbol,Any}(name => Δ)
            dt = ChainRulesCore.Tangent{typeof(traj)}(; kwargs = dkwargs)
            return NoTangent(), dt, NoTangent()
        end
        return val, kwargs_pullback
    end
end


end
