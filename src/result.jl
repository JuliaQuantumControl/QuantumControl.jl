"""
Abstract type for the result object returned by [`optimize`](@ref). Any
optimization method implemented on top of `QuantumControl` should subtype
from `AbstractOptimizationResult`. This enables conversion between the results
of different methods, allowing one method to continue an optimization from
another method.

In order for this to work seamlessly, result objects should use a common set of
field names as much as a possible. When a result object requires fields that
cannot be provided by all other result objects, it should have default values
for these field, which can be defined in a custom `Base.convert` method, as,
e.g.,

```julia
function Base.convert(::Type{MyResult}, result::AbstractOptimizationResult)
    defaults = Dict{Symbol,Any}(
        :f_calls => 0,
        :fg_calls => 0,
    )
    return convert(MyResult, result, defaults)
end
```

Where `f_calls` and `fg_calls` are fields of `MyResult` that are not present in
a given `result` of a different type. The three-argument `convert` is defined
internally for any `AbstractOptimizationResult`.
"""
abstract type AbstractOptimizationResult end

function Base.convert(
    ::Type{Dict{Symbol,Any}},
    result::R
) where {R<:AbstractOptimizationResult}
    return Dict{Symbol,Any}(field => getfield(result, field) for field in fieldnames(R))
end


struct MissingResultDataException{R} <: Exception
    missing_fields::Vector{Symbol}
end


function Base.showerror(io::IO, err::MissingResultDataException{R}) where {R}
    msg = "Missing data for fields $(err.missing_fields) to instantiate $R."
    print(io, msg)
end


struct IncompatibleResultsException{R1,R2} <: Exception
    missing_fields::Vector{Symbol}
end


function Base.showerror(io::IO, err::IncompatibleResultsException{R1,R2}) where {R1,R2}
    msg = "$R2 cannot be converted to $R1: $R2 does not provide required fields $(err.missing_fields). $R1 may need a custom implementation of `Base.convert` that sets values for any field names not provided by all results."
    print(io, msg)
end


function Base.convert(
    ::Type{R},
    data::Dict{Symbol,<:Any},
    defaults::Dict{Symbol,<:Any} = Dict{Symbol,Any}(),
) where {R<:AbstractOptimizationResult}

    function _get(data, field, defaults)
        # Can't use `get`, because that would try to evaluate the non-existing
        # `defaults[field]` for `fields` that actually exist in `data`.
        if haskey(data, field)
            return data[field]
        else
            return defaults[field]
        end
    end

    args = try
        [_get(data, field, defaults) for field in fieldnames(R)]
    catch exc
        if exc isa KeyError
            missing_fields = [
                field for field in fieldnames(R) if
                !(haskey(data, field) || haskey(defaults, field))
            ]
            throw(MissingResultDataException{R}(missing_fields))
        else
            rethrow()
        end
    end
    return R(args...)
end


function Base.convert(
    ::Type{R1},
    result::R2,
    defaults::Dict{Symbol,<:Any} = Dict{Symbol,Any}(),
) where {R1<:AbstractOptimizationResult,R2<:AbstractOptimizationResult}
    data = convert(Dict{Symbol,Any}, result)
    try
        return convert(R1, data, defaults)
    catch exc
        if exc isa MissingResultDataException{R1}
            throw(IncompatibleResultsException{R1,R2}(exc.missing_fields))
        else
            rethrow()
        end
    end
end
