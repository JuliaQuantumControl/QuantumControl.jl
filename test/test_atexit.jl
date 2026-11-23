# SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT

using Test
using QuantumControl: set_atexit_save_optimization, remove_atexit_save_optimization
using QuantumControl: load_optimization

mutable struct Result
    msg::String
end


@testset "Test set_atexit_save_optimization" begin

    result = Result("Started")

    filename = tempname()

    n_atexit_hooks = length(Base.atexit_hooks)

    hook = set_atexit_save_optimization(filename, result; msg_property = :msg)

    @test length(Base.atexit_hooks) == n_atexit_hooks + 1
    @test Base.atexit_hooks[1] === hook

    @test !isfile(filename)
    hook()
    @test isfile(filename)

    result_recovered = load_optimization(filename)
    @test result_recovered.msg == "Abort: ATEXIT"

    remove_atexit_save_optimization(hook)
    @test length(Base.atexit_hooks) == n_atexit_hooks
    @test all(h -> h !== hook, Base.atexit_hooks)

end


@testset "Test remove_atexit_save_optimization" begin

    result = Result("Started")
    filename = tempname()
    n_atexit_hooks = length(Base.atexit_hooks)

    hook = set_atexit_save_optimization(filename, result; msg_property = :msg)
    # A hook registered after ours comes before it in `Base.atexit_hooks`
    other_hook_called = Ref(false)
    other_hook = () -> (other_hook_called[] = true)
    atexit(other_hook)
    @test length(Base.atexit_hooks) == n_atexit_hooks + 2
    @test Base.atexit_hooks[1] === other_hook

    remove_atexit_save_optimization(hook)
    @test length(Base.atexit_hooks) == n_atexit_hooks + 1
    @test Base.atexit_hooks[1] === other_hook
    @test all(h -> h !== hook, Base.atexit_hooks)

    # Removing twice, or removing `nothing`, does nothing
    remove_atexit_save_optimization(hook)
    remove_atexit_save_optimization(nothing)
    @test length(Base.atexit_hooks) == n_atexit_hooks + 1

    # clean up
    filter!(h -> h !== other_hook, Base.atexit_hooks)
    @test length(Base.atexit_hooks) == n_atexit_hooks
    @test !other_hook_called[]
    @test !isfile(filename)

end


@testset "Test atexit hook removal after exception" begin

    result = Result("Started")
    filename = tempname()
    n_atexit_hooks = length(Base.atexit_hooks)

    function failing_optimization(atexit_filename)
        hook = nothing
        if !isnothing(atexit_filename)
            hook =
                set_atexit_save_optimization(atexit_filename, result; msg_property = :msg)
        end
        try
            # e.g., a package loaded during the optimization registers a hook
            atexit(other_hook)
            error("Optimization failed")
        finally
            remove_atexit_save_optimization(hook)
        end
    end

    other_hook = () -> nothing
    try
        @test_throws ErrorException failing_optimization(filename)
        @test length(Base.atexit_hooks) == n_atexit_hooks + 1
        @test Base.atexit_hooks[1] === other_hook
    finally
        filter!(h -> h !== other_hook, Base.atexit_hooks)
    end
    @test length(Base.atexit_hooks) == n_atexit_hooks
    try
        @test_throws ErrorException failing_optimization(nothing)
        @test length(Base.atexit_hooks) == n_atexit_hooks + 1
    finally
        filter!(h -> h !== other_hook, Base.atexit_hooks)
    end
    @test length(Base.atexit_hooks) == n_atexit_hooks
    @test !isfile(filename)

end


@testset "Test removal of identical atexit hooks" begin

    # Closures with identical captured values are `===`
    result = Result("Started")
    filename = tempname()
    n_atexit_hooks = length(Base.atexit_hooks)

    hook1 = set_atexit_save_optimization(filename, result; msg_property = :msg)
    hook2 = set_atexit_save_optimization(filename, result; msg_property = :msg)
    @test hook1 === hook2
    @test length(Base.atexit_hooks) == n_atexit_hooks + 2

    remove_atexit_save_optimization(hook1)
    @test length(Base.atexit_hooks) == n_atexit_hooks + 1
    remove_atexit_save_optimization(hook2)
    @test length(Base.atexit_hooks) == n_atexit_hooks

end
