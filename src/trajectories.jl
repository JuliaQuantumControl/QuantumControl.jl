import Base
import QuantumPropagators
using Printf

using QuantumPropagators.Generators: Generator, Operator
using QuantumPropagators.Controls: _get_parameters
import QuantumPropagators.Controls: substitute, get_controls, get_parameters

"""Description of a state's time evolution.

```julia
Trajectory(
    initial_state,
    generator;
    target_state=nothing,
    weight=1.0,
    kwargs...
)
```

describes the time evolution of the `initial_state` under a time-dependent
dynamical `generator` (e.g., a Hamiltonian or Liouvillian).

Trajectories are central to quantum control problems: an optimization
functional depends on the result of propagating one or more trajectories. For
example, when optimizing for a quantum gate, the optimization considers the
trajectories of all logical basis states.

In addition to the `initial_state` and `generator`, a `Trajectory` may
include data relevant to the propagation and to evaluating a particular
optimization functional. Most functionals have the notion of a "target state"
that the `initial_state` should evolve towards, which can be given as the
`target_state` keyword argument. In some functionals, different trajectories
enter with different weights [GoerzNJP2014](@cite), which can be given as a
`weight` keyword argument. Any other keyword arguments are also available to a
functional as properties of the `Trajectory` .

A `Trajectory` can also be instantiated using all keyword arguments.

# Properties

All keyword arguments used in the instantiation are available as properties of
the `Trajectory`. At a minimum, this includes `initial_state`, `generator`,
`target_state`, and `weight`.

By convention, properties with a `prop_` prefix, e.g., `prop_method`,
will be taken into account when propagating the trajectory. See
[`propagate_trajectory`](@ref) for details.
"""
struct Trajectory{ST,GT}
    initial_state::ST
    generator::GT
    target_state::Union{Nothing,ST}
    weight::Float64
    kwargs::Dict{Symbol,Any}

    function Trajectory(
        initial_state::ST,
        generator::GT;
        target_state::Union{Nothing,ST}=nothing,
        weight=1.0,
        kwargs...
    ) where {ST,GT}
        new{ST,GT}(initial_state, generator, target_state, weight, kwargs)
    end


end

# All-keyword constructor
function Trajectory(; initial_state, generator, kwargs...)
    Trajectory(initial_state, generator; kwargs...)
end


function _show_trajectory(io::IO, traj::Trajectory; multiline=false)
    print(io, "Trajectory(")
    multiline && print(io, ";")
    print(io, multiline ? "\n  initial_state=" : "", traj.initial_state)
    print(io, multiline ? ",\n  generator=" : ", ")
    print(io, traj.generator)
    has_kwargs = false
    has_kwargs |= !isnothing(traj.target_state)
    has_kwargs |= (traj.weight ≠ 1.0)
    has_kwargs |= !isempty(getfield(traj, :kwargs))
    sep = multiline ? ",\n  " : "; "
    if has_kwargs
        if !isnothing(traj.target_state)
            print(io, sep, "target_state=", traj.target_state)
            sep = multiline ? ",\n  " : ", "
        end
        if traj.weight != 1.0
            print(io, sep, "weight=", traj.weight)
            sep = multiline ? ",\n  " : ", "
        end
        for (key, val) in getfield(traj, :kwargs)
            print(io, sep, key, "=", val)
            sep = multiline ? ",\n  " : ", "
        end
    end
    print(io, multiline ? "\n)" : ")")
end


function Base.show(io::IO, traj::Trajectory)
    if get(io, :typeinfo, Any) <: Trajectory
        # printing as part of a vector of trajectories
        summary(io, traj)
    else
        _show_trajectory(io, traj)
    end
end


function Base.summary(io::IO, traj::Trajectory)
    print(
        io,
        "Trajectory with ",
        summary(traj.initial_state),
        " initial state, ",
        summary(traj.generator)
    )
    if isnothing(traj.target_state)
        print(io, ", no target state")
    else
        print(io, ", ", summary(traj.target_state), " target state")
    end
    if traj.weight != 1.0
        print(io, ", weight=", traj.weight)
    end
    n_kwargs = length(getfield(traj, :kwargs))
    if n_kwargs > 0
        print(io, " and $n_kwargs extra kwargs")
    end
end


function Base.show(io::IO, ::MIME"text/plain", traj::Trajectory)
    # This could have been _show_trajectory(…, multiline=true), but the
    # non-code representation with `summary` is more useful
    println(io, typeof(traj))
    println(io, "  initial_state: $(summary(traj.initial_state))")
    println(io, "  generator: $(summary(traj.generator))")
    println(io, "  target_state: $(summary(traj.target_state))")
    if traj.weight != 1.0
        println(io, "  weight: $(traj.weight)")
    end
    for (key, val) in getfield(traj, :kwargs)
        println(io, "  ", key, ": ", repr(val))
    end
end


function Base.propertynames(traj::Trajectory, private::Bool=false)
    return (
        :initial_state,
        :generator,
        :target_state,
        :weight,
        keys(getfield(traj, :kwargs))...
    )
end


function Base.setproperty!(traj::Trajectory, name::Symbol, value)
    error("setproperty!: immutable struct of type Trajectory cannot be changed")
end


function Base.getproperty(traj::Trajectory, name::Symbol)
    if name in (:initial_state, :generator, :target_state, :weight)
        return getfield(traj, name)
    else
        kwargs = getfield(traj, :kwargs)
        return get(kwargs, name) do
            error("type Trajectory has no property $name")
        end
    end
end


"""
```julia
trajectory = substitute(trajectory::Trajectory, replacements)
trajectories = substitute(trajectories::Vector{<:Trajectory}, replacements)
```

recursively substitutes the `initial_state`, `generator`, and `target_state`.
"""
function substitute(traj::Trajectory, replacements)
    initial_state = substitute(traj.initial_state, replacements)
    ST = typeof(initial_state)
    generator = substitute(traj.generator, replacements)
    target_state::Union{Nothing,ST} = nothing
    if !isnothing(traj.target_state)
        target_state = substitute(traj.target_state, replacements)
    end
    weight = traj.weight
    kwargs = getfield(traj, :kwargs)
    return Trajectory(initial_state, generator; target_state, weight, kwargs...)
end

function substitute(trajs::Vector{<:Trajectory}, replacements)
    return [substitute(traj, replacements) for traj ∈ trajs]
end


# adjoint for the nested-tuple dynamical generator (e.g. `(H0, (H1, ϵ))`)
function dynamical_generator_adjoint(G::Tuple)
    result = []
    for part in G
        # `copy` materializes the `adjoint` view, so we don't end up with
        # unnecessary `Adjoint{Matrix}` instead of Matrix, for example
        if isa(part, Tuple)
            push!(result, (copy(Base.adjoint(part[1])), part[2]))
        else
            push!(result, copy(Base.adjoint(part)))
        end
    end
    return Tuple(result)
end

function dynamical_generator_adjoint(G::Generator)
    ops = [dynamical_generator_adjoint(op) for op in G.ops]
    return Generator(ops, G.amplitudes)
end

function dynamical_generator_adjoint(G::Operator)
    ops = [dynamical_generator_adjoint(op) for op in G.ops]
    coeffs = [Base.adjoint(c) for c in G.coeffs]
    return Operator(ops, G.coeffs)
end

# fallback adjoint
dynamical_generator_adjoint(G) = copy(Base.adjoint(G))


"""Construct the adjoint of a [`Trajectory`](@ref).

```julia
adj_trajectory = adjoint(trajectory)
```

The adjoint trajectory contains the adjoint of
the dynamical generator `traj.generator`. All other fields contain a copy of
the original field value.

The primary purpose of this adjoint is to facilitate the backward propagation
under the adjoint generator that is central to gradient-based optimization
methods such as GRAPE and Krotov's method.
"""
function Base.adjoint(traj::Trajectory)
    initial_state = traj.initial_state
    generator = dynamical_generator_adjoint(traj.generator)
    target_state = traj.target_state
    weight = traj.weight
    kwargs = getfield(traj, :kwargs)
    Trajectory(initial_state, generator; target_state, weight, kwargs...)
end


"""
```julia
controls = get_controls(trajectories)
```

extracts the controls from a list of [trajectories](@ref Trajectory) (i.e.,
from each trajectory's `generator`). Controls that occur multiple times in the
different trajectories will occur only once in the result.
"""
function get_controls(trajectories::Vector{<:Trajectory})
    controls = []
    seen_control = IdDict{Any,Bool}()
    for traj in trajectories
        traj_controls = get_controls(traj.generator)
        for control in traj_controls
            if !haskey(seen_control, control)
                push!(controls, control)
                seen_control[control] = true
            end
        end
    end
    return Tuple(controls)
end


"""
```julia
parameters = get_parameters(trajectories)
```

collects and combines get parameter arrays from all the generators in
[`trajectories`](@ref Trajectory). Note that this allows any custom generator
type to define a custom `get_parameters` method to override the default of
obtaining the parameters recursively from the controls inside the generator.
"""
function get_parameters(trajectories::Vector{<:Trajectory})
    return _get_parameters(trajectories; via=(trajs -> [traj.generator for traj in trajs]))
end
