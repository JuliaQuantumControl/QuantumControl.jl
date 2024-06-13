using QuantumControl
using QuantumPropagators
using IOCapture
using Test
using SafeTestsets

@testset "QuantumControl versions" begin
    captured = IOCapture.capture(passthrough=true) do
        QuantumControl.print_versions()
    end
    @test occursin("QuantumControlBase", captured.output)
    qp_exports = QuantumControl._exported_names(QuantumPropagators)
    @test :propagate ∈ qp_exports
    @test :QuantumControl ∉ qp_exports
end

# Note: comment outer @testset to stop after first @safetestset failure
@time @testset verbose = true "QuantumControl" begin


    println("\n* Functionals (test_functionals.jl):")
    @time @safetestset "Functionals" begin
        include("test_functionals.jl")
    end

    println("\n* Run-or-load (test_run_or_load.jl):")
    @time @safetestset "Run-or-load" begin
        include("test_run_or_load.jl")
    end

    println("\n* Optimize-or-load (test_optimize_or_load.jl):")
    @time @safetestset "Optimize-or-load" begin
        include("test_optimize_or_load.jl")
    end

    println("\n* Pulse Parameterizations (test_pulse_parameterizations.jl):")
    @time @safetestset "Pulse Parameterizations" begin
        include("test_pulse_parameterizations.jl")
    end

    print("\n")

end;
nothing
