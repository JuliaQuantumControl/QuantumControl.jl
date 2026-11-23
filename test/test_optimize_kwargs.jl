# SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT

using Test
import QuantumControl
using QuantumControl: ControlProblem, Trajectory

@testset "optimize-kwargs" begin

    # test that we can call optimize with kwargs that override the kwargs of
    # the `problem` without permanently changing `problem`


    struct Result
        iter_stop::Int
        flag::Bool
    end

    function optimize_kwargstest(problem)
        return Result(problem.kwargs[:iter_stop], problem.kwargs[:flag])
    end

    QuantumControl.optimize(problem, method::Val{:kwargstest}) =
        optimize_kwargstest(problem)

    problem = ControlProblem(
        [Trajectory(nothing, nothing)],
        pulse_options = Dict(),
        tlist = [0.0, 10.0],
        iter_stop = 2,
        flag = false
    )

    res = QuantumControl.optimize(problem; method = :kwargstest, check = false)
    @test res.iter_stop == 2
    @test !res.flag

    res2 = QuantumControl.optimize(
        problem;
        method = :kwargstest,
        iter_stop = 10,
        flag = true,
        check = false
    )
    @test res2.iter_stop == 10
    @test res2.flag
    @test problem.kwargs[:iter_stop] == 2
    @test !problem.kwargs[:flag]

end


@testset "optimize-callback-nothing" begin

    # A `callback = nothing` stored in the problem must not reach the
    # optimization method, and an explicit `callback = nothing` must remove a
    # callback stored in the problem.

    optimize_cbtest(problem) = Dict(problem.kwargs)
    QuantumControl.optimize(problem, method::Val{:cbtest}) = optimize_cbtest(problem)

    traj = Trajectory(nothing, nothing)
    tlist = [0.0, 10.0]

    problem = ControlProblem([traj], tlist; callback = nothing)
    kwargs = QuantumControl.optimize(
        problem;
        method = :cbtest,
        check = false,
        print_iters = false
    )
    @test !haskey(kwargs, :callback)

    mycallback(args...) = nothing
    problem = ControlProblem([traj], tlist; callback = mycallback)
    kwargs = QuantumControl.optimize(
        problem;
        method = :cbtest,
        check = false,
        print_iters = false
    )
    @test kwargs[:callback] === mycallback
    kwargs = QuantumControl.optimize(
        problem;
        method = :cbtest,
        check = false,
        print_iters = false,
        callback = nothing
    )
    @test !haskey(kwargs, :callback)
    @test problem.kwargs[:callback] === mycallback

end


@testset "optimize-prop-precedence-warning" begin

    QuantumControl.optimize(problem, method::Val{:proptest}) = nothing
    tlist = [0.0, 10.0]
    run(problem; kwargs...) = QuantumControl.optimize(
        problem;
        method = :proptest,
        check = false,
        print_iters = false,
        kwargs...
    )

    trajs = [
        Trajectory(nothing, nothing; fw_prop_method = :expprop),
        Trajectory(nothing, nothing; fw_prop_method = :expprop),
        Trajectory(nothing, nothing; fw_prop_method = :cheby),
        Trajectory(nothing, nothing; bw_prop_method = :expprop),
    ]

    # A less specific keyword argument overrides more specific properties
    problem = ControlProblem(trajs, tlist)
    msg =
        r"`prop_method` overrides `bw_prop_method` of trajectory 4\n\* `prop_method` overrides `fw_prop_method` of trajectories 1, 2"
    @test_logs (:warn, msg) run(problem; prop_method = :cheby)

    # The same, with the keyword argument stored in the problem
    problem = ControlProblem(trajs, tlist; prop_method = :cheby)
    @test_logs (:warn, msg) run(problem)

    # No warning if the specific keyword arguments are also given
    @test_logs run(problem; fw_prop_method = :cheby, bw_prop_method = :cheby,)

    # No warning for overriding a property with the same prefix
    problem = ControlProblem(
        [Trajectory(nothing, nothing; prop_method = :expprop)],
        tlist;
        prop_method = :cheby
    )
    @test_logs run(problem)

    # No warning if the values are the same
    problem = ControlProblem(
        [Trajectory(nothing, nothing; fw_prop_method = :cheby)],
        tlist;
        prop_method = :cheby
    )
    @test_logs run(problem)

    # Consecutive trajectories are combined into a range
    problem = ControlProblem(
        [Trajectory(nothing, nothing; fw_prop_inplace = false) for _ = 1:5],
        tlist;
        prop_inplace = true
    )
    @test_logs (:warn, r"`prop_inplace` overrides `fw_prop_inplace` of trajectories 1:5") run(
        problem
    )

end
