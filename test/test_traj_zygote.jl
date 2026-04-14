using Test
using StableRNGs
using IOCapture
using QuantumControl: Trajectory
using LinearAlgebra: dot, norm
using Random: rand
using Zygote


function J_T(Ψ; Ψtgt, N)
    return 1 - (abs2(dot(Ψ, Ψtgt)) / N)
end



@testset "Gradient w.r.t. trajectory.initial_state" begin

    function f(traj; Ψtgt, N)
        return J_T(traj.initial_state; Ψtgt, N)
    end

    rng = StableRNG(3143162815)
    N = 4
    H = nothing
    Ψ = rand(rng, ComplexF64, N)
    Ψ ./ norm(Ψ)
    Ψtgt = zeros(ComplexF64, N)
    Ψtgt[1] = 1.0
    traj = Trajectory(Ψ, H)
    @test f(traj; Ψtgt, N) > 0.0
    grad = Zygote.gradient(traj -> f(traj; Ψtgt, N), traj)[1]
    @test grad isa NamedTuple
    @test grad.initial_state isa Vector

end


@testset "Gradient w.r.t. trajectory.x" begin

    function f(traj; Ψtgt, N)
        return J_T(traj.x; Ψtgt, N)
    end

    rng = StableRNG(3143162816)
    N = 4
    H = nothing
    Ψ = rand(rng, ComplexF64, N)
    Ψ ./ norm(Ψ)
    Ψtgt = zeros(ComplexF64, N)
    Ψtgt[1] = 1.0
    x = Ψ
    traj = Trajectory(Ψ, H; x)
    @test f(traj; Ψtgt, N) > 0.0
    captured = IOCapture.capture(rethrow = Union{}) do
        # Without the custom `rrule` in `QuantumControlchainRulesCoreExt`, this
        # test would show a potentially very confusing error, and throw an
        # `UndefRefError`. See also: https://discourse.julialang.org/t/136704/
        Zygote.gradient(traj -> f(traj; Ψtgt, N), traj)[1]
    end
    grad = captured.value
    @test grad isa NamedTuple
    if grad isa NamedTuple
        @test grad.initial_state isa Nothing
        @test grad.kwargs[:x] isa Vector
    end

end
