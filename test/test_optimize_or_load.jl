using Test

using IOCapture
using QuantumControl: @optimize_or_load, load_optimization, save_optimization, optimize
using QuantumControlTestUtils.DummyOptimization:
    dummy_control_problem, DummyOptimizationResult

@testset "metadata" begin

    problem = dummy_control_problem()
    outdir = mktempdir()
    outfile = joinpath(outdir, "optimization_with_metadata.jld2")
    captured = IOCapture.capture(passthrough = false) do
        result = @optimize_or_load(
            outfile,
            problem;
            method = :dummymethod,
            metadata = Dict("testset" => "metadata", "method" => :dummymethod,)
        )
    end
    result = captured.value
    @test result.converged
    @test isfile(outfile)
    result_load, metadata = load_optimization(outfile; return_metadata = true)
    @test result_load isa DummyOptimizationResult
    @test result_load.message == "Reached maximum number of iterations"
    @test metadata["testset"] == "metadata"
    @test metadata["method"] == :dummymethod

    outfile2 = joinpath(outdir, "optimization_with_metadata2.jld2")
    save_optimization(outfile2, result_load; metadata)
    @test isfile(outfile2)
    result_load2, metadata2 = load_optimization(outfile2; return_metadata = true)
    @test result_load2 isa DummyOptimizationResult
    @test result_load2.message == "Reached maximum number of iterations"
    @test metadata2["testset"] == "metadata"
    @test metadata2["method"] == :dummymethod

end


@testset "continue_from" begin
    problem = dummy_control_problem()
    outdir = mktempdir()
    outfile = joinpath(outdir, "optimization_stage1.jld2")
    println("")
    captured = IOCapture.capture(passthrough = false, color = true) do
        @optimize_or_load(outfile, problem; iter_stop = 5, method = :dummymethod)
    end
    result = captured.value
    @test result.converged
    result1 = load_optimization(outfile)
    captured = IOCapture.capture(passthrough = false, color = true) do
        optimize(problem; method = :dummymethod, iter_stop = 15, continue_from = result1)
    end
    result2 = captured.value
    @test result2.iter == 15
end


@testset "captured output" begin
    problem = dummy_control_problem(verbose = true)
    outdir = mktempdir()
    outfile = joinpath(outdir, "optimization_with_output.jld2")
    captured = IOCapture.capture(passthrough = false) do
        result =
            @optimize_or_load(outfile, problem; iter_stop = 300, method = :dummymethod,)
    end
    @test contains(captured.output, "\n   200\t7.")
    captured = IOCapture.capture(passthrough = false) do
        result =
            @optimize_or_load(outfile, problem; iter_stop = 300, method = :dummymethod,)
    end
    @test contains(captured.output, "Info: Loading data")
    @test !contains(captured.output, "\n   200\t7.")
    @test contains(captured.output, "\n    6…")
end


@testset "optimization logfile" begin
    problem = dummy_control_problem(verbose = true)
    outdir = mktempdir()
    outfile = joinpath(outdir, "optimization_with_logfile.jld2")
    logfile = joinpath(outdir, "oct.log")
    captured = IOCapture.capture(passthrough = false) do
        result = @optimize_or_load(
            outfile,
            problem;
            iter_stop = 300,
            method = :dummymethod,
            logfile,
        )
    end
    @test !contains(captured.output, "# iter\tJ_T\n")
    @test isfile(logfile)
    if isfile(logfile)
        logfile_text = read(logfile, String)
        @test startswith(logfile_text, "# iter\tJ_T\n")
        @test contains(logfile_text, "\n   200\t7.")  # not truncated
    end
    captured = IOCapture.capture(passthrough = false) do
        result = @optimize_or_load(
            outfile,
            problem;
            iter_stop = 300,
            method = :dummymethod,
            logfile,
        )
    end
    @test !contains(captured.output, "# iter\tJ_T\n")
    @test isfile(logfile)
    if isfile(logfile)
        logfile_text = read(logfile, String)
        @test startswith(logfile_text, "# iter\tJ_T\n")
        @test contains(logfile_text, "\n   200\t7.")  # not truncated
    end
end
