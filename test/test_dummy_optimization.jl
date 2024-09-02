using Test

using QuantumControl: optimize
using QuantumControl.Controls: get_controls, substitute

using QuantumControlTestUtils.DummyOptimization: dummy_control_problem

@testset "dummy optimization" begin

    println("")
    problem = dummy_control_problem(n_trajectories=4, n_controls=3)
    result = optimize(problem; method=:dummymethod)
    @test result.converged

    H = problem.trajectories[1].generator
    H_opt = substitute(
        H,
        Dict(
            ϵ => ϵ_opt for
            (ϵ, ϵ_opt) in zip(get_controls(problem), result.optimized_controls)
        )
    )
    @test get_controls(H_opt)[2] ≡ result.optimized_controls[2]

end
