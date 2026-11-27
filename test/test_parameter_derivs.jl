# SPDX-FileCopyrightText: © 2026 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT

using Test
using LinearAlgebra
using ComponentArrays
using QuantumControl: hamiltonian, ControlProblem, Trajectory
using QuantumPropagators: Generator
using QuantumPropagators.Controls: ParameterizedFunction, StaticParameter
using QuantumPropagators.Controls:
    get_parameters, get_controls, evaluate, combine_parameters
using QuantumPropagators.Amplitudes: ShapedAmplitude, LockedAmplitude, GuidedAmplitude
using QuantumPropagators.ParameterizedFunctions: CRABFunction, VariedFrequencyCRABFunction
using QuantumControl.Controls:
    get_parameter_deriv, get_parameter_derivs, get_control_deriv, get_control_derivs
using QuantumControl.PulseParameterizations:
    ParameterizedAmplitude, SquareParameterization, TanhParameterization
using QuantumControl.Interfaces: check_control, check_generator
using StableRNGs: StableRNG
import QuantumPropagators
import QuantumControl


struct GaussianControl <: ParameterizedFunction
    parameters::ComponentVector{
        Float64,
        Vector{Float64},
        Tuple{Axis{(A = 1, t0 = 2, sigma = 3)}}
    }
end

GaussianControl(; A = 1.0, t0 = 0.0, sigma = 1.0) =
    GaussianControl(ComponentVector(; A, t0, sigma))

function (control::GaussianControl)(t)
    u = control.parameters
    return u.A * exp(-(t - u.t0)^2 / (2 * u.sigma^2))
end

struct GaussianControlDeriv{P} <: ParameterizedFunction
    parameters::P
    i::Int
end

function (deriv::GaussianControlDeriv)(t)
    u = deriv.parameters
    g = exp(-(t - u.t0)^2 / (2 * u.sigma^2))
    if deriv.i == 1      # ∂ϵ/∂A
        return g
    elseif deriv.i == 2  # ∂ϵ/∂t₀
        return u.A * g * (t - u.t0) / u.sigma^2
    else                 # ∂ϵ/∂σ
        return u.A * g * (t - u.t0)^2 / u.sigma^3
    end
end

QuantumControl.Controls.get_parameter_deriv(control::GaussianControl, i) =
    GaussianControlDeriv(control.parameters, i)


# Second derivatives of the Gaussian: a type that holds the block of the
# original control (no third derivatives)
struct GaussianControlDeriv2{P} <: ParameterizedFunction
    parameters::P
    i::Int
    j::Int
end

function (deriv::GaussianControlDeriv2)(t)
    u = deriv.parameters
    (i, j) = minmax(deriv.i, deriv.j)
    A, t0, σ = u.A, u.t0, u.sigma
    g = exp(-(t - t0)^2 / (2 * σ^2))
    x = t - t0
    if (i, j) == (1, 1)
        return 0.0
    elseif (i, j) == (1, 2)
        return g * x / σ^2
    elseif (i, j) == (1, 3)
        return g * x^2 / σ^3
    elseif (i, j) == (2, 2)
        return A * g * (x^2 / σ^4 - 1 / σ^2)
    elseif (i, j) == (2, 3)
        return A * g * (x^3 / σ^5 - 2x / σ^3)
    else  # (3, 3)
        return A * g * (x^4 / σ^6 - 3 * x^2 / σ^4)
    end
end

QuantumControl.Controls.get_parameter_deriv(deriv::GaussianControlDeriv, j) =
    GaussianControlDeriv2(deriv.parameters, deriv.i, j)


const σx = ComplexF64[0 1; 1 0]
const σy = ComplexF64[0 -1im; 1im 0]
const σz = ComplexF64[1 0; 0 -1]
const tlist = collect(range(0, 10; length = 101))
const Ψ = ComplexF64[1, 0]


function t_mid(n)
    return QuantumPropagators.Controls.t_mid(tlist, n)
end


# Allocations of `evaluate`. These must not be varargs functions: a varargs
# wrapper may not specialize, and then allocates itself.
_allocs(f, tlist, n) = @allocated evaluate(f, tlist, n)
_allocs(f, t) = @allocated evaluate(f, t)
_allocs(f, tlist, n, vals_dict) = @allocated evaluate(f, tlist, n; vals_dict)


function _fd(f, block, i; h = 1e-6)
    v₀ = block[i]
    block[i] = v₀ + h
    f₊ = f()
    block[i] = v₀ - h
    f₋ = f()
    block[i] = v₀
    return (f₊ - f₋) / 2h
end


# A custom amplitude ϵ², with second derivatives w.r.t. ϵ
struct SquareAmpl
    control
end
struct ScaledAmpl
    c::Float64
    control
end
QuantumPropagators.Controls.get_controls(a::SquareAmpl) = (a.control,)
QuantumPropagators.Controls.get_controls(a::ScaledAmpl) = (a.control,)
QuantumPropagators.Controls.evaluate(a::SquareAmpl, args...; vals_dict = IdDict()) =
    evaluate(a.control, args...; vals_dict)^2
QuantumPropagators.Controls.evaluate(a::ScaledAmpl, args...; vals_dict = IdDict()) =
    a.c * evaluate(a.control, args...; vals_dict)
QuantumPropagators.Controls.substitute(a::SquareAmpl, replacements) =
    SquareAmpl(get(replacements, a.control, a.control))
QuantumPropagators.Controls.substitute(a::ScaledAmpl, replacements) =
    ScaledAmpl(a.c, get(replacements, a.control, a.control))
QuantumControl.Controls.get_control_deriv(a::SquareAmpl, control) =
    (control ≡ a.control) ? ScaledAmpl(2.0, control) : 0.0
QuantumControl.Controls.get_control_deriv(a::ScaledAmpl, control) =
    (control ≡ a.control) ? a.c : 0.0


# A control 2Δ, with a constant derivative of 2.0
struct ScaledStatic <: ParameterizedFunction
    parameters::Vector{Float64}
end
(f::ScaledStatic)(t) = 2 * f.parameters[1]
QuantumControl.Controls.get_parameter_deriv(::ScaledStatic, i) = 2.0


@testset "Gaussian example" begin
    ϵ = GaussianControl(A = 2.0, t0 = 5.0, sigma = 0.5)
    H = hamiltonian(σz, (σx, ϵ))
    u = get_parameters(H)
    p = ϵ.parameters  # the block
    @test u.x === (p,)
    @test u === get_parameters(ϵ)
    derivs = get_parameter_derivs(H, u)
    @test length(derivs) == 3
    D = derivs[3]
    @test D isa Generator
    @test Array(evaluate(D, 4.5)) ≈ 2.4261226388505337 * σx
    @test Array(evaluate(D, tlist, 46)) ≈ 2.161004867181458 * σx
    @test get_controls(D)[1] isa GaussianControlDeriv
    @test get_controls(D)[1].parameters === p
    @test get_parameters(D) === u
    @test get_parameter_deriv(H, p, 3).amplitudes[1].i == 3
    @test_throws ArgumentError get_parameter_deriv(H, u, 3)  # not a block
    # `get_parameter_derivs` accepts a single block, and an empty block
    derivs_p = get_parameter_derivs(H, p)
    @test length(derivs_p) == 3
    @test Array(evaluate(derivs_p[3], 4.5)) ≈ Array(evaluate(derivs[3], 4.5))
    @test get_parameter_derivs(H, Float64[]) == []
    @test get_parameter_deriv(H, Float64[], 1) ≡ nothing
    p.sigma = 0.8
    @test Array(evaluate(D, 4.5)) ≈ 0.8032984007799457 * σx
    p.sigma = 0.5
    @test get_parameter_deriv(H, copy(p), 3) ≡ nothing
    @test all(isnothing, get_parameter_derivs(H, copy(u)))
    @test get_parameter_deriv(ϵ, copy(p), 3) ≡ 0.0
    @test check_control(ϵ; tlist)
    @test check_control(ϵ; tlist, for_hessian = true)
    @test check_generator(H; state = Ψ, tlist, for_parameterization = true)
    @test check_generator(
        H;
        state = Ψ,
        tlist,
        for_parameterization = true,
        for_hessian = true
    )
    # Second derivatives
    D23 = get_parameter_deriv(D, p, 2)
    @test D23 isa Generator
    @test get_controls(D23)[1] isa GaussianControlDeriv2
    @test get_parameters(D23) === u
end


@testset "composition with get_control_deriv" begin
    ϵ1 = GaussianControl(A = 2.0, t0 = 5.0, sigma = 0.5)
    ϵ2 = GaussianControl(A = 1.0, t0 = 4.0, sigma = 1.5)
    H = hamiltonian(σz, (σx, ϵ1), (σy, ShapedAmplitude(ϵ2; shape = t -> 0.5)))
    u = get_parameters(H)
    @test length(u) == 6
    derivs = get_parameter_derivs(H, u)
    controls = get_controls(H)
    μ = get_control_derivs(H, controls)
    J = [get_parameter_derivs(ϵ, u) for ϵ in controls]
    @test J[1][4] ≡ 0.0
    @test J[2][1] ≡ 0.0
    for n = 1:6, k in (1, 37, 100)
        val = sum(evaluate(J[l][n], tlist, k) * Array(evaluate(μ[l], tlist, k)) for l = 1:2)
        @test Array(evaluate(derivs[n], tlist, k)) ≈ val
    end
    @test check_generator(H; state = Ψ, tlist, for_parameterization = true)
end


@testset "amplitudes" begin
    ϵ = GaussianControl(A = 2.0, t0 = 5.0, sigma = 0.5)
    u = ϵ.parameters  # the block

    ampl = ShapedAmplitude(ϵ; shape = t -> 0.5 * sin(t)^2)
    a = get_parameter_deriv(ampl, u, 2)
    @test a isa QuantumControl.Controls.SumOfProductsAmplitude
    @test evaluate(a, tlist, 10) ≈
          0.5 * sin(t_mid(10))^2 * GaussianControlDeriv(u, 2)(t_mid(10))
    @test get_parameter_deriv(ampl, copy(u), 2) ≡ 0.0
    H = hamiltonian(σz, (σx, ampl))
    @test check_generator(H; state = Ψ, tlist, for_parameterization = true)
    @test check_generator(
        H;
        state = Ψ,
        tlist,
        for_parameterization = true,
        for_hessian = true
    )
    # Evaluating the sum of products does not allocate. With a `vals_dict`,
    # it allocates nothing beyond what evaluating its factors allocates (a
    # lookup in a non-empty `IdDict` may allocate).
    factors = a.terms[1][2]
    @test length(factors) == 2
    evaluate(a, tlist, 46)
    evaluate(a, 4.6)
    @test _allocs(a, tlist, 46) == 0
    @test _allocs(a, 4.6) == 0
    vals_dict = IdDict(ϵ => 0.3)
    allocs = [_allocs(f, tlist, 46, vals_dict) for f in (a, factors...)]
    allocs = [_allocs(f, tlist, 46, vals_dict) for f in (a, factors...)]
    @test allocs[1] <= allocs[2] + allocs[3]

    # A shape on the midpoints of the time grid: only `evaluate(…, tlist, n)`
    shape = [0.5 * sin(t)^2 for t in QuantumPropagators.Controls.get_tlist_midpoints(tlist)]
    ampl = ShapedAmplitude(ϵ; shape)
    a = get_parameter_deriv(ampl, u, 3)
    @test evaluate(a, tlist, 46) ≈ shape[46] * GaussianControlDeriv(u, 3)(t_mid(46))
    H = hamiltonian(σz, (σx, ampl))
    @test check_generator(H; state = Ψ, tlist, for_parameterization = true)

    # Non-linear amplitude: ∂(ϵ²)/∂u = 2ϵ ∂ϵ/∂u
    ampl = ParameterizedAmplitude(ϵ; parameterization = SquareParameterization())
    a = get_parameter_deriv(ampl, u, 3)
    @test a isa QuantumControl.Controls.SumOfProductsAmplitude
    @test Set(objectid.(get_controls(a))) == Set(objectid.((ϵ, GaussianControlDeriv(u, 3))))
    @test length(get_controls(a)) == 2
    @test get_parameters(a) === get_parameters(ϵ)
    t = t_mid(46)
    @test evaluate(a, tlist, 46) ≈ 2 * ϵ(t) * GaussianControlDeriv(u, 3)(t)
    ϵ_val = 0.3
    vals_dict = IdDict(ϵ => ϵ_val)
    @test evaluate(a, tlist, 46; vals_dict) ≈ 2 * ϵ_val * GaussianControlDeriv(u, 3)(t)
    @test evaluate(a, t; vals_dict) ≈ 2 * ϵ_val * GaussianControlDeriv(u, 3)(t)
    H = hamiltonian(σz, (σx, ampl))
    @test check_generator(H; state = Ψ, tlist, for_parameterization = true)

    # Second derivatives through the product rule (requires the second
    # derivative of the amplitude w.r.t. the control)
    ampl = SquareAmpl(ϵ)
    a = get_parameter_deriv(ampl, u, 3)
    @test a isa QuantumControl.Controls.SumOfProductsAmplitude
    a23 = get_parameter_deriv(a, u, 2)
    @test a23 isa QuantumControl.Controls.SumOfProductsAmplitude
    @test length(a23.terms) == 2  # 2 ∂ϵ/∂t₀ ∂ϵ/∂σ + 2ϵ ∂²ϵ/∂t₀∂σ
    fd = _fd(() -> evaluate(get_parameter_deriv(ampl, u, 3), tlist, 46), u, 2)
    @test evaluate(a23, tlist, 46) ≈ fd rtol = 1e-6
    H = hamiltonian(σz, (σx, ampl))
    @test check_generator(
        H;
        state = Ψ,
        tlist,
        for_parameterization = true,
        for_hessian = true
    )

    # A non-linear amplitude without second derivatives
    ampl = ParameterizedAmplitude(ϵ; parameterization = TanhParameterization(-1, 1))
    H = hamiltonian(σz, (σx, ampl))
    @test check_generator(H; state = Ψ, tlist, for_parameterization = true)

    # Locked amplitudes and controls without parameters
    @test get_parameter_deriv(LockedAmplitude(t -> 1.0), u, 1) ≡ 0.0
    @test get_parameter_deriv(t -> 1.0, u, 1) ≡ 0.0
    @test get_parameter_deriv(rand(10), u, 1) ≡ 0.0
end


@testset "shared blocks and static parameters" begin
    u = ComponentVector(A = 2.0, t0 = 5.0, sigma = 0.5)
    ϵ = GaussianControl(u)
    A = StaticParameter(u, 1)
    H = hamiltonian((σz, A), (σx, ϵ))
    @test get_parameters(H).x === (u,)
    derivs = get_parameter_derivs(H, u)
    @test length(derivs) == 3
    @test derivs[1] isa Generator  # σz + σx ∂ϵ/∂A
    @test Array(evaluate(derivs[1], tlist, 10)) ≈
          σz + GaussianControlDeriv(u, 1)(t_mid(10)) * σx
    @test derivs[2] isa Generator
    @test length(derivs[2].ops) == 1
    @test get_parameter_deriv(A, u, 1) ≡ 1.0
    @test get_parameter_deriv(A, u, 2) ≡ 0.0
    @test check_control(A; tlist, for_hessian = true)
    @test check_generator(H; state = Ψ, tlist, for_parameterization = true)

    # Detuning example
    Δ = StaticParameter([0.3])
    ϵ2 = GaussianControl(A = 2.0, t0 = 5.0, sigma = 0.5)
    H = hamiltonian((σz, Δ), (σx, ϵ2))
    u = get_parameters(H)
    @test length(u) == 4
    @test u.x[1] === Δ.parameters
    ∂H╱∂Δ = get_parameter_derivs(H, u)[1]
    @test ∂H╱∂Δ isa Matrix
    @test ∂H╱∂Δ == σz
    @test check_generator(
        H;
        state = Ψ,
        tlist,
        for_parameterization = true,
        for_hessian = true
    )

    # Scaled operator for a derivative that is a number other than one
    H = hamiltonian(σx, (σz, ScaledStatic(Δ.parameters)))
    D = get_parameter_derivs(H, Δ.parameters)[1]
    @test D isa Matrix
    @test D ≈ 2 * σz
    @test check_generator(H; state = Ψ, tlist, for_parameterization = true)
end


@testset "trajectories and control problems" begin
    ϵ1 = GaussianControl(A = 2.0, t0 = 5.0, sigma = 0.5)
    ϵ2 = GaussianControl(A = 1.0, t0 = 3.0, sigma = 1.0)
    ϵ3 = GaussianControl(A = 1.5, t0 = 7.0, sigma = 0.7)
    H1 = hamiltonian(σz, (σx, ϵ1), (σy, ϵ2))
    H2 = hamiltonian(σz, (σx, ϵ2), (σy, ϵ3))
    problem = ControlProblem(
        [Trajectory(Ψ, H1; target_state = Ψ), Trajectory(Ψ, H2; target_state = Ψ)],
        tlist
    )
    u = get_parameters(problem)
    @test length(u) == 9
    blocks = u.x
    @test length(blocks) == 3
    @test blocks[1] === ϵ1.parameters
    @test blocks[2] === ϵ2.parameters
    @test blocks[3] === ϵ3.parameters
    derivs = [get_parameter_derivs(traj.generator, u) for traj in problem.trajectories]
    @test all(length(d) == 9 for d in derivs)
    @test all(isnothing, derivs[1][7:9])
    @test all(isnothing, derivs[2][1:3])
    @test all(!isnothing, derivs[1][1:6])
    @test all(!isnothing, derivs[2][4:9])
    @test Array(evaluate(derivs[1][4], tlist, 10)) ≈
          GaussianControlDeriv(ϵ2.parameters, 1)(t_mid(10)) * σy
    @test Array(evaluate(derivs[2][4], tlist, 10)) ≈
          GaussianControlDeriv(ϵ2.parameters, 1)(t_mid(10)) * σx
    u_x = copy(u)
    u_x[5] = 2.0
    copyto!(u, u_x)
    @test ϵ2.parameters.t0 == 2.0
    @test Array(evaluate(derivs[2][4], tlist, 10)) ≈
          GaussianControlDeriv(ϵ2.parameters, 1)(t_mid(10)) * σx
end


@testset "CRAB functions" begin
    rng = StableRNG(2365128745)
    shape(t) = sin(π * t / 10)^2
    guess(t) = 0.2 * cos(0.3 * t)
    for parity in (:even, :odd, :evenodd), g in (nothing, guess), S in (nothing, shape)
        crab = CRABFunction(3; max_frequency = 2.0, rng, parity, guess = g, shape = S)
        u = crab.parameters  # the block
        @test check_control(crab; tlist, for_hessian = true)
        for i in eachindex(u)
            d = get_parameter_deriv(crab, u, i)
            @test d isa Function
            @test isempty(get_parameters(d))
            fd = _fd(() -> crab(1.3), u, i)
            @test d(1.3) ≈ fd rtol = 1e-6
        end
        vf = VariedFrequencyCRABFunction(
            2;
            max_frequency = 2.0,
            rng,
            parity,
            guess = g,
            shape = S
        )
        u = vf.parameters  # the block
        u[vf.r_indices] .= [0.9, 1.2]  # rᵢ
        @test check_control(vf; tlist, for_hessian = true)
        for i in eachindex(u)
            d = get_parameter_deriv(vf, u, i)
            fd = _fd(() -> vf(1.3), u, i)
            @test evaluate(d, 1.3) ≈ fd rtol = 1e-6
            if !(d isa Number)
                # third derivatives
                @test check_control(d; tlist, for_hessian = true)
            end
        end
        # Explicit third derivatives
        r₁ = first(vf.r_indices)
        # :cos for :even/:evenodd, :sin for :odd
        c₁ = first(isempty(vf.cos_indices) ? vf.sin_indices : vf.cos_indices)
        for (i, j, k) in ((r₁, r₁, r₁), (c₁, r₁, r₁), (r₁, c₁, r₁))
            d2 = get_parameter_deriv(get_parameter_deriv(vf, u, i), u, j)
            d3 = get_parameter_deriv(d2, u, k)
            fd = _fd(() -> evaluate(d2, 1.3), u, k)
            @test evaluate(d3, 1.3) ≈ fd rtol = 1e-6
            @test get_parameters(d3) === get_parameters(vf)
        end
        # vanishing derivatives
        @test get_parameter_deriv(get_parameter_deriv(vf, u, c₁), u, c₁) ≡ 0.0
        @test get_parameter_deriv(get_parameter_deriv(vf, u, r₁), u, r₁ + 1) ≡ 0.0
        if !isnothing(g)
            @test get_parameter_deriv(vf, u, 1)(1.3) ≈ g(1.3)
            @test get_parameter_deriv(get_parameter_deriv(vf, u, 1), u, 1) ≡ 0.0
            @test get_parameter_deriv(get_parameter_deriv(vf, u, r₁), u, 1) ≡ 0.0
        end
    end
    crab = CRABFunction(3; max_frequency = 2.0, rng)
    @test get_parameter_deriv(crab, copy(crab.parameters), 1) ≡ 0.0
    @test_throws BoundsError get_parameter_deriv(crab, 7)
end


# A custom generator `Δ σz + Ω σx + ϵ(t) σy` that holds the block `[Δ, Ω]`
# and contains a parameterized control. The `bug` field selects a faulty
# implementation of the parameter derivatives, for testing the checks.
struct MyGenerator{C}
    parameters::Vector{Float64}
    control::C
    bug::Symbol
end

MyGenerator(parameters, control) = MyGenerator(parameters, control, :none)

QuantumPropagators.Controls.get_controls(G::MyGenerator) = (G.control,)

QuantumPropagators.Controls.get_parameters(G::MyGenerator) =
    combine_parameters(G.parameters, get_parameters(G.control))

function QuantumPropagators.Controls.evaluate(G::MyGenerator, args...; vals_dict = IdDict())
    Δ, Ω = G.parameters
    return Δ * σz + Ω * σx + evaluate(G.control, args...; vals_dict) * σy
end

function QuantumPropagators.Controls.evaluate!(op, G::MyGenerator, args...; kwargs...)
    return copyto!(op, evaluate(G, args...; kwargs...))
end

QuantumPropagators.Controls.substitute(G::MyGenerator, replacements) =
    MyGenerator(G.parameters, get(replacements, G.control, G.control), G.bug)

QuantumControl.Controls.get_control_deriv(G::MyGenerator, control) =
    (control ≡ G.control) ? σy : nothing

function QuantumControl.Controls.get_parameter_deriv(G::MyGenerator, block, i)
    if (G.bug == :foreign) || (block === G.parameters)
        if G.bug == :wrong_value
            return (i == 1) ? 2 * σz : σx
        elseif G.bug == :new_block
            return Generator([σz], [StaticParameter(copy(G.parameters), i)])
        else
            return (i == 1) ? σz : σx
        end
    else
        ∂ϵ╱∂u = get_parameter_deriv(G.control, block, i)
        if (∂ϵ╱∂u isa Number)
            return iszero(∂ϵ╱∂u) ? nothing : ∂ϵ╱∂u * σy
        else
            return Generator([σy], [∂ϵ╱∂u])
        end
    end
end


@testset "custom generator" begin
    ϵ = GaussianControl(A = 2.0, t0 = 5.0, sigma = 0.5)
    G = MyGenerator([0.3, 0.1], ϵ)
    u = get_parameters(G)
    @test length(u) == 5
    @test u.x[1] === G.parameters
    derivs = get_parameter_derivs(G, u)
    @test derivs[1] == σz
    @test derivs[2] == σx
    @test derivs[3] isa Generator
    @test get_parameters(derivs[3]) === get_parameters(ϵ)
    @test check_generator(G; state = Ψ, tlist, for_parameterization = true)
    @test check_generator(
        G;
        state = Ψ,
        tlist,
        for_parameterization = true,
        for_hessian = true
    )
    problem = ControlProblem([Trajectory(Ψ, G; target_state = Ψ)], tlist)
    @test get_parameters(problem) === u
end


struct NoDerivControl <: ParameterizedFunction
    parameters::Vector{Float64}
end
(f::NoDerivControl)(t) = f.parameters[1]^2 * t

# `bug` selects a faulty derivative
struct BuggyControl <: ParameterizedFunction
    parameters::Vector{Float64}
    bug::Symbol
end
(f::BuggyControl)(t) = f.parameters[1]^2 * t

# A correct first derivative, without second derivatives
struct BuggyControlDeriv <: ParameterizedFunction
    parameters::Vector{Float64}
end
(f::BuggyControlDeriv)(t) = 2 * f.parameters[1] * t

function QuantumControl.Controls.get_parameter_deriv(f::BuggyControl, i)
    if f.bug == :wrong_value
        return t -> 3.0 * t
    elseif f.bug == :copy
        p = copy(f.parameters)
        return t -> 2 * p[1] * t
    elseif f.bug == :closure
        p = f.parameters
        return t -> 2 * p[1] * t
    elseif f.bug == :new_block
        return BuggyControlDeriv(copy(f.parameters))
    else  # :none, :foreign
        return BuggyControlDeriv(f.parameters)
    end
end

function QuantumControl.Controls.get_parameter_deriv(f::BuggyControl, block, i)
    if (f.bug == :foreign) || (block === f.parameters)
        return get_parameter_deriv(f, i)
    else
        return 0.0
    end
end

@testset "invalid parameter derivatives of controls" begin
    f = NoDerivControl([0.5])
    @test !check_control(f; tlist, quiet = true)
    @test check_control(f; tlist, for_gradient_optimization = false)
    @test check_control(f; tlist, for_parameterization = false)
    @test QuantumPropagators.Interfaces.check_control(f; tlist)
    @test_throws MethodError get_parameter_deriv(f, f.parameters, 1)
    @test_logs (:error, r"must be defined for i=1") match_mode = :any begin
        check_control(f; tlist)
    end

    @test check_control(BuggyControl([0.5], :none); tlist)

    f = BuggyControl([0.5], :wrong_value)
    @test_logs (:error, r"must match the finite difference") match_mode = :any begin
        @test !check_control(f; tlist)
    end

    f = BuggyControl([0.5], :copy)
    @test_logs (:error, r"after changing the parameter values") match_mode = :any begin
        @test !check_control(f; tlist)
    end
    @test f.parameters == [0.5]  # restored

    f = BuggyControl([0.5], :closure)
    @test_logs (:error, r"must not be empty") match_mode = :any begin
        @test !check_control(f; tlist)
    end

    f = BuggyControl([0.5], :new_block)
    @test_logs (:error, r"must hold no parameter block other than") match_mode = :any begin
        @test !check_control(f; tlist)
    end

    f = BuggyControl([0.5], :foreign)
    @test_logs (:error, r"must return 0.0 for a block") match_mode = :any begin
        @test !check_control(f; tlist)
    end

    # No second derivatives
    f = BuggyControl([0.5], :none)
    @test check_control(f; tlist, for_hessian = false)
    @test_logs (:error, r"must return a number or a valid control") match_mode = :any begin
        @test !check_control(f; tlist, for_hessian = true)
    end

    # Large parameter values (relative to the scale on which the function
    # changes) must not cause false negatives
    ϵ = GaussianControl(A = 1.0, t0 = 500.0, sigma = 0.5)
    @test check_control(ϵ; tlist = collect(range(490, 510; length = 401)))
    vf = VariedFrequencyCRABFunction(
        1;
        frequencies = [30.0],
        parity = :even,
        scale_guess = false
    )
    @test check_control(vf; tlist = collect(range(0, 100; length = 4001)))

    # The checks in `check_generator`
    H = hamiltonian(σz, (σx, BuggyControl([0.5], :copy)))
    @test check_generator(H; state = Ψ, tlist, for_parameterization = false)
    @test check_generator(H; state = Ψ, tlist, for_gradient_optimization = false)
    @test_logs (:error, r"must pass check_control") match_mode = :any begin
        @test !check_generator(H; state = Ψ, tlist, for_parameterization = true)
    end
    H = hamiltonian(σz, (σx, BuggyControl([0.5], :none)))
    @test check_generator(H; state = Ψ, tlist, for_parameterization = true)
    @test_logs (:error, r"must return a number or a valid control") match_mode = :any begin
        @test !check_generator(
            H;
            state = Ψ,
            tlist,
            for_parameterization = true,
            for_hessian = true
        )
    end
end


# A generator with a broken `get_parameter_derivs`
struct ShortDerivsGenerator
    G::MyGenerator
end
QuantumPropagators.Controls.get_controls(H::ShortDerivsGenerator) = get_controls(H.G)
QuantumPropagators.Controls.get_parameters(H::ShortDerivsGenerator) = get_parameters(H.G)
QuantumPropagators.Controls.evaluate(H::ShortDerivsGenerator, args...; kwargs...) =
    evaluate(H.G, args...; kwargs...)
QuantumPropagators.Controls.evaluate!(op, H::ShortDerivsGenerator, args...; kwargs...) =
    QuantumPropagators.Controls.evaluate!(op, H.G, args...; kwargs...)
QuantumPropagators.Controls.substitute(H::ShortDerivsGenerator, replacements) =
    ShortDerivsGenerator(QuantumPropagators.Controls.substitute(H.G, replacements))
QuantumControl.Controls.get_control_deriv(H::ShortDerivsGenerator, control) =
    get_control_deriv(H.G, control)
QuantumControl.Controls.get_parameter_deriv(H::ShortDerivsGenerator, block, i) =
    get_parameter_deriv(H.G, block, i)
QuantumControl.Controls.get_parameter_derivs(H::ShortDerivsGenerator, u) =
    get_parameter_derivs(H.G, u)[1:(end-1)]

struct NoParamDerivGenerator
    G::MyGenerator
end
QuantumPropagators.Controls.get_controls(H::NoParamDerivGenerator) = get_controls(H.G)
QuantumPropagators.Controls.evaluate(H::NoParamDerivGenerator, args...; kwargs...) =
    evaluate(H.G, args...; kwargs...)
QuantumPropagators.Controls.evaluate!(op, H::NoParamDerivGenerator, args...; kwargs...) =
    QuantumPropagators.Controls.evaluate!(op, H.G, args...; kwargs...)
QuantumPropagators.Controls.substitute(H::NoParamDerivGenerator, replacements) =
    NoParamDerivGenerator(QuantumPropagators.Controls.substitute(H.G, replacements))
QuantumControl.Controls.get_control_deriv(H::NoParamDerivGenerator, control) =
    get_control_deriv(H.G, control)


# A generator that holds a block, without a `get_parameter_deriv` method
struct OwnBlockGenerator
    parameters::Vector{Float64}
end
QuantumPropagators.Controls.get_controls(::OwnBlockGenerator) = ()
QuantumPropagators.Controls.get_parameters(H::OwnBlockGenerator) =
    combine_parameters(H.parameters)


# A generator Δ² σz, which holds the block [Δ]. With `copy = true`, the
# derivative copies the value of Δ when it is created.
struct SquareGenerator
    parameters::Vector{Float64}
    copy::Bool
end
QuantumPropagators.Controls.get_controls(::SquareGenerator) = ()
QuantumPropagators.Controls.get_parameters(H::SquareGenerator) =
    combine_parameters(H.parameters)
QuantumPropagators.Controls.evaluate(H::SquareGenerator, args...; kwargs...) =
    H.parameters[1]^2 * σz
QuantumPropagators.Controls.evaluate!(op, H::SquareGenerator, args...; kwargs...) =
    copyto!(op, evaluate(H, args...; kwargs...))
QuantumPropagators.Controls.substitute(H::SquareGenerator, replacements) = H
QuantumControl.Controls.get_control_deriv(::SquareGenerator, control) = nothing
function QuantumControl.Controls.get_parameter_deriv(H::SquareGenerator, block, i)
    if block === H.parameters
        if H.copy
            return 2 * H.parameters[1] * σz
        else
            return Generator([σz], [ScaledStatic(H.parameters)])
        end
    else
        return nothing
    end
end


# An amplitude ϵ₁ ϵ₂
struct ProductAmpl
    control1
    control2
end
QuantumPropagators.Controls.get_controls(a::ProductAmpl) = (a.control1, a.control2)
QuantumPropagators.Controls.evaluate(a::ProductAmpl, args...; vals_dict = IdDict()) =
    evaluate(a.control1, args...; vals_dict) * evaluate(a.control2, args...; vals_dict)
function QuantumControl.Controls.get_control_deriv(a::ProductAmpl, control)
    ∂ = 0.0
    (control ≡ a.control1) && (∂ += 1.0)
    (control ≡ a.control2) && (∂ += 1.0)
    if ∂ == 0.0
        return 0.0
    elseif a.control1 ≡ a.control2
        return ScaledAmpl(2.0, control)
    else
        return (control ≡ a.control1) ? a.control2 : a.control1
    end
end


@testset "invalid parameter derivatives of generators" begin
    ϵ = GaussianControl(A = 2.0, t0 = 5.0, sigma = 0.5)
    chk(G; kw...) = check_generator(G; state = Ψ, tlist, for_parameterization = true, kw...)

    G = MyGenerator([0.3, 0.1], ϵ, :wrong_value)
    @test chk(G; for_parameterization = false)
    @test_logs (:error, r"must match the finite difference") match_mode = :any begin
        @test !chk(G)
    end
    @test G.parameters == [0.3, 0.1]  # restored

    G = MyGenerator([0.3, 0.1], ϵ, :foreign)
    @test_logs (:error, r"must return `nothing` for a block") match_mode = :any begin
        @test !chk(G)
    end

    G = MyGenerator([0.3, 0.1], ϵ, :new_block)
    @test_logs (:error, r"must be parameter blocks of `generator`") match_mode = :any begin
        @test !chk(G)
    end

    H = ShortDerivsGenerator(MyGenerator([0.3, 0.1], ϵ))
    @test_logs (:error, r"must return a derivative for every element") match_mode = :any begin
        @test !chk(H)
    end

    # A custom generator type without its own `get_parameter_deriv` method
    H = NoParamDerivGenerator(MyGenerator([0.3, 0.1], ϵ))
    @test_throws ErrorException get_parameter_deriv(H, ϵ.parameters, 1)
    @test !chk(H; quiet = true)

    # ... and one that holds a block itself: no silent zero
    H = OwnBlockGenerator([0.3])
    @test_throws MethodError get_parameter_deriv(H, H.parameters, 1)
    @test_throws MethodError get_parameter_derivs(H, get_parameters(H))
    @test get_parameter_deriv(H, [0.0], 1) ≡ 0.0  # a foreign block

    # A derivative that copies the parameter values when it is created
    H = SquareGenerator([0.3], false)
    @test chk(H)
    @test chk(H; for_hessian = true)
    H = SquareGenerator([0.3], true)
    @test_logs (:error, r"after changing the parameter values") match_mode = :any begin
        @test !chk(H)
    end
    @test H.parameters == [0.3]  # restored
end


@testset "parameter derivatives of other objects" begin
    @test get_parameter_deriv(
        2.0 * QuantumPropagators.Generators.Operator([σz], [1.0]),
        [0.0],
        1
    ) ≡ nothing
    # A control that `get_controls` lists twice is counted once
    ϵ = StaticParameter([0.3])
    ampl = ProductAmpl(ϵ, ϵ)
    @test get_controls(ampl) == (ϵ, ϵ)
    @test evaluate(get_parameter_deriv(ampl, ϵ.parameters, 1), 0.0) ≈ 0.6
    # GuidedAmplitude
    ϵ = GaussianControl(A = 2.0, t0 = 5.0, sigma = 0.5)
    ampl = GuidedAmplitude(ϵ; shape = t -> 0.5, guide = t -> 0.1 * t)
    a = get_parameter_deriv(ampl, ϵ.parameters, 3)
    @test evaluate(a, tlist, 46) ≈ 0.5 * GaussianControlDeriv(ϵ.parameters, 3)(t_mid(46))
    H = hamiltonian(σz, (σx, ampl))
    @test check_generator(H; state = Ψ, tlist, for_parameterization = true)
end
