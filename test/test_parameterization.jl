using ComponentArrays
using RecursiveArrayTools  # to ensure extension is loaded
using UnPack: @unpack
using QuantumPropagators: hamiltonian
using QuantumPropagators.Controls: ParameterizedFunction, get_parameters
using QuantumControl: ControlProblem, Trajectory
using Test


struct GaussianControl <: ParameterizedFunction
    parameters::ComponentVector{Float64,Vector{Float64},Tuple{Axis{(A=1, t₀=2, σ=3)}}}
    GaussianControl(; kwargs...) = new(ComponentVector(; kwargs...))
end

function (control::GaussianControl)(t)
    @unpack A, t₀, σ = control.parameters
    return A * exp(-(t - t₀)^2 / (2 * σ^2))
end


const 𝕚 = 1im


function total_enantiomer_ham(parameters; sign, a, independent_parameters=false, kwargs...)

    μ = (sign == "-" ? -1 : 1)
    H₁Re = μ * ComplexF64[0 1 0; 1 0 0; 0  0 0]
    H₁Im = μ * ComplexF64[0 𝕚 0; -𝕚 0 0; 0  0 0]
    H₂Re = μ * ComplexF64[0 0 0; 0 0 1; 0  1 0]
    H₂Im = μ * ComplexF64[0 0 0; 0 0 𝕚; 0 -𝕚 0]
    H₃Re = μ * ComplexF64[0 0 1; 0 0 0; 1  0 0]
    H₃Im = μ * ComplexF64[0 0 𝕚; 0 0 0; -𝕚  0 0]

    if independent_parameters
        # This doesn't make sense physically, but it's a good way to test
        # collecting multiple parameter arrays
        return hamiltonian(
            (H₁Re, TEH_field1Re(copy(parameters), a)),
            (H₁Im, TEH_field1Im(copy(parameters), a)),
            (H₂Re, TEH_field2Re(copy(parameters), a)),
            (H₂Im, TEH_field2Im(copy(parameters), a)),
            (H₃Re, TEH_field3Re(copy(parameters), a)),
            (H₃Im, TEH_field3Im(copy(parameters), a));
            kwargs...
        )
    else
        return hamiltonian(
            (H₁Re, TEH_field1Re(parameters, a)),
            (H₁Im, TEH_field1Im(parameters, a)),
            (H₂Re, TEH_field2Re(parameters, a)),
            (H₂Im, TEH_field2Im(parameters, a)),
            (H₃Re, TEH_field3Re(parameters, a)),
            (H₃Im, TEH_field3Im(parameters, a));
            kwargs...
        )
    end

end

struct TEH_field1Re <: ParameterizedFunction
    parameters::ComponentVector{
        Float64,
        Vector{Float64},
        Tuple{Axis{(ΔT₁=1, ΔT₂=2, ΔT₃=3, ϕ₁=4, ϕ₂=5, ϕ₃=6, E₀₁=7, E₀₂=8, E₀₃=9)}}
    }
    a::Float64
end

function (E::TEH_field1Re)(t)
    @unpack E₀₁, ΔT₁, ϕ₁ = E.parameters
    _tanhfield(t; E₀=E₀₁, t₁=0.0, t₂=ΔT₁, a=E.a) * cos(ϕ₁)
end

struct TEH_field2Re <: ParameterizedFunction
    parameters::ComponentVector{
        Float64,
        Vector{Float64},
        Tuple{Axis{(ΔT₁=1, ΔT₂=2, ΔT₃=3, ϕ₁=4, ϕ₂=5, ϕ₃=6, E₀₁=7, E₀₂=8, E₀₃=9)}}
    }
    a::Float64
end

function (E::TEH_field2Re)(t)
    @unpack E₀₂, ΔT₁, ΔT₂, ϕ₂ = E.parameters
    _tanhfield(t; E₀=E₀₂, t₁=ΔT₁, t₂=(ΔT₁ + ΔT₂), a=E.a) * cos(ϕ₂)
end

struct TEH_field3Re <: ParameterizedFunction
    parameters::ComponentVector{
        Float64,
        Vector{Float64},
        Tuple{Axis{(ΔT₁=1, ΔT₂=2, ΔT₃=3, ϕ₁=4, ϕ₂=5, ϕ₃=6, E₀₁=7, E₀₂=8, E₀₃=9)}}
    }
    a::Float64
end

function (E::TEH_field3Re)(t)
    @unpack E₀₃, ΔT₁, ΔT₂, ΔT₃, ϕ₃ = E.parameters
    _tanhfield(t; E₀=E₀₃, t₁=(ΔT₁ + ΔT₂), t₂=(ΔT₁ + ΔT₂ + ΔT₃), a=E.a) * cos(ϕ₃)
end

struct TEH_field1Im <: ParameterizedFunction
    parameters::ComponentVector{
        Float64,
        Vector{Float64},
        Tuple{Axis{(ΔT₁=1, ΔT₂=2, ΔT₃=3, ϕ₁=4, ϕ₂=5, ϕ₃=6, E₀₁=7, E₀₂=8, E₀₃=9)}}
    }
    a::Float64
end

function (E::TEH_field1Im)(t)
    @unpack E₀₁, ΔT₁, ϕ₁ = E.parameters
    _tanhfield(t; E₀=E₀₁, t₁=0.0, t₂=ΔT₁, a=E.a) * sin(ϕ₁)
end

struct TEH_field2Im <: ParameterizedFunction
    parameters::ComponentVector{
        Float64,
        Vector{Float64},
        Tuple{Axis{(ΔT₁=1, ΔT₂=2, ΔT₃=3, ϕ₁=4, ϕ₂=5, ϕ₃=6, E₀₁=7, E₀₂=8, E₀₃=9)}}
    }
    a::Float64
end

function (E::TEH_field2Im)(t)
    @unpack E₀₂, ΔT₁, ΔT₂, ϕ₂ = E.parameters
    _tanhfield(t; E₀=E₀₂, t₁=ΔT₁, t₂=(ΔT₁ + ΔT₂), a=E.a) * sin(ϕ₂)
end

struct TEH_field3Im <: ParameterizedFunction
    parameters::ComponentVector{
        Float64,
        Vector{Float64},
        Tuple{Axis{(ΔT₁=1, ΔT₂=2, ΔT₃=3, ϕ₁=4, ϕ₂=5, ϕ₃=6, E₀₁=7, E₀₂=8, E₀₃=9)}}
    }
    a::Float64
end

function (E::TEH_field3Im)(t)
    @unpack E₀₃, ΔT₁, ΔT₂, ΔT₃, ϕ₃ = E.parameters
    _tanhfield(t; E₀=E₀₃, t₁=(ΔT₁ + ΔT₂), t₂=(ΔT₁ + ΔT₂ + ΔT₃), a=E.a) * sin(ϕ₃)
end

_tanhfield(t; E₀, t₁, t₂, a) = (E₀ / 2) * (tanh(a * (t - t₁)) - tanh(a * (t - t₂)));

_ENANTIOMER_PARAMETERS = ComponentVector(
    ΔT₁=0.3,
    ΔT₂=0.4,
    ΔT₃=0.3,
    ϕ₁=0.0,
    ϕ₂=0.0,
    ϕ₃=0.0,
    E₀₁=4.5,
    E₀₂=4.0,
    E₀₃=5.0
)


@testset "enantiomer problem - dependent parameters" begin
    H₊ = total_enantiomer_ham(_ENANTIOMER_PARAMETERS; sign="+", a=100)
    H₋ = total_enantiomer_ham(_ENANTIOMER_PARAMETERS; sign="-", a=100)
    tlist = [0.0, 0.5, 1.0]
    Ψ₀ = ComplexF64[1, 0, 0]
    Ψ₊tgt = ComplexF64[1, 0, 0]
    Ψ₋tgt = ComplexF64[0, 0, 1]
    problem = ControlProblem(
        [Trajectory(Ψ₀, H₊; target_state=Ψ₊tgt), Trajectory(Ψ₀, H₋; target_state=Ψ₋tgt)],
        tlist;
    )
    p = get_parameters(problem)
    @test p isa AbstractVector
    @test eltype(p) == Float64
    @test length(p) == 9
    @test p === _ENANTIOMER_PARAMETERS
end


@testset "enantiomer problem - partially independent parameters" begin
    H₊ = total_enantiomer_ham(copy(_ENANTIOMER_PARAMETERS); sign="+", a=100)
    H₋ = total_enantiomer_ham(copy(_ENANTIOMER_PARAMETERS); sign="-", a=100)
    tlist = [0.0, 0.5, 1.0]
    Ψ₀ = ComplexF64[1, 0, 0]
    Ψ₊tgt = ComplexF64[1, 0, 0]
    Ψ₋tgt = ComplexF64[0, 0, 1]
    problem = ControlProblem(
        [Trajectory(Ψ₀, H₊; target_state=Ψ₊tgt), Trajectory(Ψ₀, H₋; target_state=Ψ₋tgt)],
        tlist;
    )
    p = get_parameters(problem)
    @test p isa AbstractVector
    @test eltype(p) == Float64
    @test length(p) == 18
    @test p[2] == 0.4
    @test length(p.x) == 2
    @test length(p.x[1]) == 9
end


@testset "enantiomer problem - fully independent parameters" begin
    H₊ = total_enantiomer_ham(
        copy(_ENANTIOMER_PARAMETERS);
        independent_parameters=true,
        sign="+",
        a=100
    )
    H₋ = total_enantiomer_ham(
        copy(_ENANTIOMER_PARAMETERS);
        independent_parameters=true,
        sign="-",
        a=100
    )
    tlist = [0.0, 0.5, 1.0]
    Ψ₀ = ComplexF64[1, 0, 0]
    Ψ₊tgt = ComplexF64[1, 0, 0]
    Ψ₋tgt = ComplexF64[0, 0, 1]
    problem = ControlProblem(
        [Trajectory(Ψ₀, H₊; target_state=Ψ₊tgt), Trajectory(Ψ₀, H₋; target_state=Ψ₋tgt)],
        tlist;
    )
    p = get_parameters(problem)
    @test p isa AbstractVector
    @test eltype(p) == Float64
    @test length(p) == 108
    @test p[2] == 0.4
    @test length(p.x) == 2
    @test length(p.x[1]) == 54
    @test length(p.x[1].x) == 6
end
