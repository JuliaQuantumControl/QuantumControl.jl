using Test
using LinearAlgebra
using QuantumControl: Trajectory
using QuantumControlTestUtils.DummyOptimization: dummy_control_problem


@testset "Sparse trajectory adjoint" begin

    traj = dummy_control_problem().trajectories[1]
    adj = adjoint(traj)

    @test norm(adj.initial_state - traj.initial_state) ≈ 0
    @test norm(adj.target_state - traj.target_state) ≈ 0
    @test norm(adj.generator[1] - traj.generator[1]') ≈ 0
    @test norm(adj.generator[2][1] - traj.generator[2][1]') ≈ 0
    @test adj.generator[2][2] == traj.generator[2][2]

end

@testset "Dense trajectory adjoint" begin

    traj = dummy_control_problem(density = 1.0).trajectories[1]
    adj = adjoint(traj)

    @test norm(adj.initial_state - traj.initial_state) ≈ 0
    @test norm(adj.target_state - traj.target_state) ≈ 0
    @test norm(adj.generator[1] - traj.generator[1]') ≈ 0
    @test norm(adj.generator[1] - traj.generator[1]) ≈ 0
    @test norm(adj.generator[2][1] - traj.generator[2][1]') ≈ 0
    @test adj.generator[2][2] == traj.generator[2][2]

end

@testset "Non-Hermitian trajectory adjoint" begin

    traj = dummy_control_problem(sparsity = 1.0, hermitian = false).trajectories[1]
    adj = adjoint(traj)

    @test norm(adj.initial_state - traj.initial_state) ≈ 0
    @test norm(adj.target_state - traj.target_state) ≈ 0
    @test norm(adj.generator[1] - traj.generator[1]') ≈ 0
    @test norm(adj.generator[1] - traj.generator[1]) > 0
    @test norm(adj.generator[2][1] - traj.generator[2][1]') ≈ 0
    @test norm(adj.generator[2][1] - traj.generator[2][1]) > 0
    @test adj.generator[2][2] == traj.generator[2][2]

end


@testset "weighted trajectory adjoint" begin

    traj0 = dummy_control_problem().trajectories[1]
    traj = Trajectory(
        initial_state = traj0.initial_state,
        generator = traj0.generator,
        target_state = traj0.target_state,
        weight = 0.2
    )
    adj = adjoint(traj)

    @test adj.weight == traj.weight

end

@testset "custom trajectory adjoint" begin

    traj0 = dummy_control_problem(hermitian = false).trajectories[1]

    traj = Trajectory(
        initial_state = traj0.initial_state,
        generator = traj0.generator,
        gate = "CNOT",
        weight = 0.5,
        coeff = 1im
    )

    @test propertynames(traj) ==
          (:initial_state, :generator, :target_state, :weight, :coeff, :gate)
    kwargs = getfield(traj, :kwargs)
    @test :coeff ∈ keys(kwargs)
    @test isnothing(traj.target_state)
    @test traj.gate == "CNOT"
    @test traj.coeff == 1im

    adj = adjoint(traj)

    @test norm(adj.initial_state - traj.initial_state) ≈ 0
    @test norm(adj.generator[1] - traj.generator[1]') ≈ 0
    @test norm(adj.generator[1] - traj.generator[1]) > 0
    @test adj.gate == "CNOT"
    @test adj.weight == 0.5
    @test adj.coeff == 1im

end
