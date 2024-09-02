using Test
using QuantumControl: set_atexit_save_optimization
using QuantumControl: load_optimization

mutable struct Result
    msg::String
end


@testset "Test set_atexit_save_optimization" begin

    result = Result("Started")

    filename = tempname()

    n_atexit_hooks = length(Base.atexit_hooks)

    set_atexit_save_optimization(filename, result; msg_property=:msg)

    @test length(Base.atexit_hooks) == n_atexit_hooks + 1

    @test !isfile(filename)
    Base.atexit_hooks[1]()
    @test isfile(filename)

    result_recovered = load_optimization(filename)
    @test result_recovered.msg == "Abort: ATEXIT"

    popfirst!(Base.atexit_hooks)

end
