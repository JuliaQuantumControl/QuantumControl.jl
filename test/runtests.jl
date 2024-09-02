using QuantumControl
using QuantumPropagators
using IOCapture
using Test
using SafeTestsets

@testset "QuantumControl versions" begin
    captured = IOCapture.capture(passthrough=true) do
        QuantumControl.print_versions()
    end
    qp_exports = QuantumControl._exported_names(QuantumPropagators)
    @test :propagate ∈ qp_exports
    @test :QuantumControl ∉ qp_exports
end

# Note: comment outer @testset to stop after first @safetestset failure
@time @testset verbose = true "QuantumControl" begin

    println("* Propagation (test_propagation.jl):")
    @time @safetestset "Propagation" begin
        include("test_propagation.jl")
    end

    println("* Derivatives (test_derives.jl):")
    @time @safetestset "Derivatives" begin
        include("test_derivs.jl")
    end

    println("\n* Parameterization (test_parameterization.jl):")
    @time @safetestset "Parameterization" begin
        include("test_parameterization.jl")
    end

    println("\n* Functionals (test_functionals.jl):")
    @time @safetestset "Functionals" begin
        include("test_functionals.jl")
    end

    println("* Callbacks (test_callbacks.jl):")
    @time @safetestset "Callbacks" begin
        include("test_callbacks.jl")
    end

    println("* Optimize-kwargs (test_optimize_kwargs.jl):")
    @time @safetestset "Optimize-kwargs" begin
        include("test_optimize_kwargs.jl")
    end

    println("* Dummy Optimization (test_dummy_optimization.jl):")
    @time @safetestset "Dummy Optimization" begin
        include("test_dummy_optimization.jl")
    end

    println("* Atexit dumps (test_atexit.jl):")
    @time @safetestset "Atexit dumps" begin
        include("test_atexit.jl")
    end

    println("* Trajectories (test_trajectories.jl):")
    @time @safetestset "Trajectories" begin
        include("test_trajectories.jl")
    end

    println("* Adjoint Trajectories (test_adjoint_trajectory.jl):")
    @time @safetestset "Adjoint Trajectories" begin
        include("test_adjoint_trajectory.jl")
    end

    println("* Control problems (test_control_problems.jl):")
    @time @safetestset "Control problems" begin
        include("test_control_problems.jl")
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

    println("* Invalid interfaces (test_invalid_interfaces.jl):")
    @time @safetestset "Invalid interfaces" begin
        include("test_invalid_interfaces.jl")
    end

    print("\n")

end;
nothing
