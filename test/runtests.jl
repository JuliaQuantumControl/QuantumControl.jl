using QuantumControl
using IOCapture
using Test

@testset "QuantumControl.jl" begin
    captured = IOCapture.capture() do
        QuantumControl.print_versions()
    end
    println(captured.output)
    @test occursin("QuantumControlBase", captured.output)
    @test occursin("Krotov", captured.output)
end
