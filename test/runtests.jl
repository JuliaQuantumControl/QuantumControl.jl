using QuantumControl
using QuantumPropagators
using IOCapture
using Test

@testset "QuantumControl.jl" begin
    captured = IOCapture.capture() do
        QuantumControl.print_versions()
    end
    println(captured.output)
    @test occursin("QuantumControlBase", captured.output)
    @test occursin("Krotov", captured.output)
    qp_exports = QuantumControl._exported_names(QuantumPropagators)
    @test :propagate ∈ qp_exports
    @test :QuantumControl ∉ qp_exports
end
