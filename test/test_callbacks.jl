using Test
using QuantumControl: chain_callbacks

@testset "chain_callbacks" begin

    function hook1(wrk, a1, a2, args...)
        return (1,)
    end

    function hook2(wrk, a1, a2, args...)
        return (2,)
    end

    function hook3(wrk, a1, a2, args...)
        @test length(args) == 2
        return (3.1, 3.2)
    end

    function hook4(wrk, a1, a2, args...)
        return nothing
    end

    chained = chain_callbacks(hook1, hook2, hook3, hook4)

    res = chained(nothing, 0, 0)

    @test res == (1, 2, 3.1, 3.2)
    @test res[1] isa Int64
    @test res[3] isa Float64

end
