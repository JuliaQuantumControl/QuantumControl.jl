using Test
using DataFrames
using CSV
using Logging
using JLD2: load_object

using QuantumControlTestUtils: QuantumTestLogger

using QuantumControl: run_or_load

load_csv(f) = DataFrame(CSV.File(f))


@testset "run_or_load to csv" begin
    mktempdir() do folder
        file = joinpath(folder, "data", "out.csv")
        run_or_load(file; load=load_csv, force=true, verbose=false) do
            DataFrame(a=rand(100), b=rand(100))
        end
        df = load_csv(file)
        @test names(df) == ["a", "b"]
    end
end


@testset "run_or_load invalid" begin
    mktempdir() do folder
        file = joinpath(folder, "data", "out.csv")
        test_logger = QuantumTestLogger()
        with_logger(test_logger) do                                                                                                                                                                                               #...
            try
                run_or_load(file; load=load_csv, force=true, verbose=false) do
                    # A tuple of vectors is not something that can be written
                    # to a csv file
                    return rand(100), rand(100)
                end
            catch err
                @test occursin("Recover", err.msg)
                rx = r"load_object\(\"(.*)\"\)"
                m = match(rx, err.msg)
                recovery_file = m.captures[1]
                data = load_object(recovery_file)
                rm(recovery_file)
                @test length(data) == 2
            end
        end
        @test "Can't write this data to a CSV file" in test_logger
    end
end
