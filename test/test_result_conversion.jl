using Test
using IOCapture

using QuantumControl:
    AbstractOptimizationResult, MissingResultDataException, IncompatibleResultsException

struct _TestOptimizationResult1 <: AbstractOptimizationResult
    iter_start::Int64
    iter_stop::Int64
end

struct _TestOptimizationResult2 <: AbstractOptimizationResult
    iter_start::Int64
    J_T::Float64
    J_T_prev::Float64
end

struct _TestOptimizationResult3 <: AbstractOptimizationResult
    iter_start::Int64
    iter_stop::Int64
end

@testset "Dict conversion" begin

    R = _TestOptimizationResult1(0, 100)

    data = convert(Dict{Symbol,Any}, R)
    @test data isa Dict{Symbol,Any}
    @test Set(keys(data)) == Set((:iter_stop, :iter_start))
    @test data[:iter_start] == 0
    @test data[:iter_stop] == 100

    @test _TestOptimizationResult1(0, 100) ≠ _TestOptimizationResult1(0, 50)

    _R = convert(_TestOptimizationResult1, data)
    @test _R == R

    captured = IOCapture.capture(; passthrough = false, rethrow = Union{}) do
        convert(_TestOptimizationResult2, data)
    end
    @test captured.value isa MissingResultDataException
    msg = begin
        io = IOBuffer()
        showerror(io, captured.value)
        String(take!(io))
    end
    @test startswith(msg, "Missing data for fields [:J_T, :J_T_prev]")
    @test contains(msg, "_TestOptimizationResult2")

end


@testset "Result conversion" begin

    R = _TestOptimizationResult1(0, 100)

    _R = convert(_TestOptimizationResult1, R)
    @test _R == R

    _R = convert(_TestOptimizationResult3, R)
    @test _R isa _TestOptimizationResult3
    @test convert(Dict{Symbol,Any}, _R) == convert(Dict{Symbol,Any}, R)

    captured = IOCapture.capture(; passthrough = false, rethrow = Union{}) do
        convert(_TestOptimizationResult2, R)
    end
    @test captured.value isa IncompatibleResultsException
    msg = begin
        io = IOBuffer()
        showerror(io, captured.value)
        String(take!(io))
    end
    @test contains(msg, "does not provide required fields [:J_T, :J_T_prev]")

    R2 = _TestOptimizationResult2(0, 0.1, 0.4)
    captured = IOCapture.capture(; passthrough = false, rethrow = Union{}) do
        convert(_TestOptimizationResult1, R2)
    end
    @test captured.value isa IncompatibleResultsException
    msg = begin
        io = IOBuffer()
        showerror(io, captured.value)
        String(take!(io))
    end
    @test contains(msg, "does not provide required fields [:iter_stop]")

end
