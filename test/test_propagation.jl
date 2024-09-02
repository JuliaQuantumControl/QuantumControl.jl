using Test
using QuantumPropagators: ExpProp
using QuantumPropagators.Shapes: flattop
using QuantumControl: Trajectory, propagate
using UnicodePlots

@testset "propagate TLS" begin

    # from the first Krotov.jl example

    SHOWPLOT = false

    #! format: off
    σ̂_z = ComplexF64[1 0; 0 -1];
    σ̂_x = ComplexF64[0 1; 1  0];
    #! format: on

    ϵ(t) = 0.2 * flattop(t, T=5, t_rise=0.3, func=:blackman)

    function hamiltonian(Ω=1.0, ϵ=ϵ)
        Ĥ₀ = -0.5 * Ω * σ̂_z
        Ĥ₁ = σ̂_x
        return (Ĥ₀, (Ĥ₁, ϵ))
    end

    function ket(label)
        #! format: off
        result = Dict(
            "0" => Vector{ComplexF64}([1, 0]),
            "1" => Vector{ComplexF64}([0, 1]),
        )
        #! format: on
        return result[string(label)]
    end

    H = hamiltonian()

    traj = Trajectory(ket(0), H, target_state=ket(1))

    tlist = collect(range(0, 5, length=500))

    states =
        propagate(traj.initial_state, traj.generator, tlist, storage=true, method=ExpProp)

    pops = abs.(states) .^ 2
    pop0 = pops[1, :]

    SHOWPLOT && println(lineplot(tlist, pop0, ylim=[0, 1], title="0 population"))

    @test length(pop0) == length(tlist)
    @test pop0[1] ≈ 1.0
    @test abs(pop0[end] - 0.95146) < 1e-4
    @test minimum(pop0) < 0.9

end
