# SPDX-FileCopyrightText: © 2021 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT

using Test
using LinearAlgebra
using QuantumControl: QuantumControl, Trajectory
using QuantumControl.Functionals:
    J_T_sm,
    J_T_re,
    J_T_ss,
    J_a_fluence,
    grad_J_a_fluence,
    J_a_avg_zero,
    grad_J_a_avg_zero,
    make_grad_J_a,
    make_chi,
    make_xi,
    J_b,
    chi_re,
    chi_sm,
    chi_ss,
    gate_functional,
    make_gate_chi
using QuantumControlTestUtils.RandomObjects: random_state_vector, random_dynamic_generator
using QuantumPropagators.Controls: evaluate
using QuantumControlTestUtils.DummyOptimization: dummy_control_problem
using TwoQubitWeylChamber: D_PE, gate_concurrence, unitarity
using StableRNGs: StableRNG
using Zygote
using GRAPE: GrapeWrk
using FiniteDifferences
using IOCapture
using Logging

const 𝕚 = 1im
const ⊗ = kron

N_HILBERT = 10
N = 4
L = 2
N_T = 50
RNG = StableRNG(4290326946)
PROBLEM = dummy_control_problem(;
    N = N_HILBERT,
    n_trajectories = N,
    n_controls = L,
    n_steps = N_T,
    rng = RNG,
    J_T = J_T_sm,
)


@testset "make-chi" begin

    # Test that the routine returned by `make_chi` gives the same result
    # as the Zygote chi

    trajectories = PROBLEM.trajectories
    χ1 = [similar(traj.initial_state) for traj in trajectories]
    χ2 = [similar(traj.initial_state) for traj in trajectories]
    χ3 = [similar(traj.initial_state) for traj in trajectories]
    χ4 = [similar(traj.initial_state) for traj in trajectories]
    χ5 = [similar(traj.initial_state) for traj in trajectories]
    χ6 = [similar(traj.initial_state) for traj in trajectories]
    χ7 = [similar(traj.initial_state) for traj in trajectories]
    χ8 = [similar(traj.initial_state) for traj in trajectories]
    Ψ = [random_state_vector(N_HILBERT; rng = RNG) for k = 1:N]
    τ = [traj.target_state ⋅ Ψ[k] for (k, traj) in enumerate(trajectories)]

    for functional in (J_T_sm, J_T_re, J_T_ss)

        #!format: off
        chi_analytical = make_chi(functional, trajectories; mode=:analytic)
        chi_auto = make_chi(functional, trajectories)
        chi_zyg = make_chi(functional, trajectories; mode=:automatic, automatic=Zygote)
        chi_zyg_states = make_chi(functional, trajectories; mode=:automatic, automatic=Zygote, via=:states)
        chi_zyg_tau = make_chi(functional, trajectories; mode=:automatic, automatic=Zygote, via=:tau)
        chi_fdm = make_chi(functional, trajectories; mode=:automatic, automatic=FiniteDifferences)
        chi_fdm_states = make_chi(functional, trajectories; mode=:automatic, automatic=FiniteDifferences, via=:states)
        chi_fdm_tau = make_chi(functional, trajectories; mode=:automatic, automatic=FiniteDifferences, via=:tau)
        #!format: on

        χ1 = chi_analytical(Ψ, trajectories; τ)
        χ2 = chi_auto(Ψ, trajectories; τ)
        χ3 = chi_zyg(Ψ, trajectories; τ)
        χ4 = chi_zyg_states(Ψ, trajectories)
        χ5 = chi_zyg_tau(Ψ, trajectories; τ)
        χ6 = chi_fdm(Ψ, trajectories; τ)
        χ7 = chi_fdm_states(Ψ, trajectories)
        χ8 = chi_fdm_tau(Ψ, trajectories; τ)

        @test maximum(norm.(χ1 .- χ2)) < 1e-12
        @test maximum(norm.(χ1 .- χ3)) < 1e-12
        @test maximum(norm.(χ1 .- χ4)) < 1e-12
        @test maximum(norm.(χ1 .- χ5)) < 1e-12
        @test maximum(norm.(χ1 .- χ6)) < 1e-12
        @test maximum(norm.(χ1 .- χ7)) < 1e-12
        @test maximum(norm.(χ1 .- χ8)) < 1e-12

    end

end


@testset "make-grad-J_a" begin
    tlist = PROBLEM.tlist
    wrk = GrapeWrk(PROBLEM)
    pulsevals = wrk.pulsevals

    J_a_val = J_a_fluence(pulsevals, tlist)
    @test J_a_val > 0.0

    G1 = grad_J_a_fluence(pulsevals, tlist)

    grad_J_a_zygote =
        make_grad_J_a(J_a_fluence, tlist; mode = :automatic, automatic = Zygote)
    @test grad_J_a_zygote ≢ grad_J_a_fluence
    G2 = grad_J_a_zygote(pulsevals, tlist)

    grad_J_a_fdm =
        make_grad_J_a(J_a_fluence, tlist; mode = :automatic, automatic = FiniteDifferences)
    @test grad_J_a_fdm ≢ grad_J_a_fluence
    @test grad_J_a_fdm ≢ grad_J_a_zygote
    G3 = grad_J_a_fdm(pulsevals, tlist)

    @test 0.0 ≤ norm(G2 - G1) < 1e-12  # zygote can be exact
    @test 0.0 < norm(G3 - G1) < 1e-12  # fdm should not be exact
    @test 0.0 < norm(G3 - G2) < 1e-10

end


@testset "J_a_fluence non-uniform grid" begin

    # Non-uniform tlist with 4 intervals, 2 controls
    # pulsevals layout: [ϵ₁₁, ϵ₂₁, ϵ₃₁, ϵ₄₁, ϵ₁₂, ϵ₂₂, ϵ₃₂, ϵ₄₂]
    tlist_nu = [0.0, 0.1, 0.3, 0.6, 1.0]
    dt_nu = [0.1, 0.2, 0.3, 0.4]
    pv1 = [1.0, 2.0, 3.0, 4.0]
    pv2 = [0.5, 1.5, 2.5, 3.5]
    pulsevals_nu = vcat(pv1, pv2)

    J_expected = sum(abs2.(pv1) .* dt_nu) + sum(abs2.(pv2) .* dt_nu)
    @test J_a_fluence(pulsevals_nu, tlist_nu) ≈ J_expected

    G_expected = vcat(2 .* pv1 .* dt_nu, 2 .* pv2 .* dt_nu)
    @test grad_J_a_fluence(pulsevals_nu, tlist_nu) ≈ G_expected

    grad_J_a_zygote_nu =
        make_grad_J_a(J_a_fluence, tlist_nu; mode = :automatic, automatic = Zygote)
    @test norm(grad_J_a_zygote_nu(pulsevals_nu, tlist_nu) - G_expected) < 1e-12

end


@testset "J_a_avg_zero" begin

    # Two controls on a non-uniform grid
    tlist_nu = [0.0, 0.1, 0.3, 0.6, 1.0]
    dt_nu = [0.1, 0.2, 0.3, 0.4]           # diff(tlist_nu)
    pv1 = [1.0, -2.0, 3.0, -1.0]           # A₁ = 0.1 - 0.4 + 0.9 - 0.4 = 0.2
    pv2 = [2.0, -1.0, -1.0, 0.0]           # A₂ = 0.2 - 0.2 - 0.3 + 0.0 = -0.3
    pulsevals_nu = vcat(pv1, pv2)

    A1 = dot(pv1, dt_nu)
    A2 = dot(pv2, dt_nu)
    @test J_a_avg_zero(pulsevals_nu, tlist_nu) ≈ A1^2 + A2^2

    # Zero when each control integrates to zero:
    # 1*0.1 + 0*0.2 + 0*0.3 + (-0.25)*0.4 = 0.1 - 0.1 = 0
    pv_zeroA = [1.0, 0.0, 0.0, -0.25]
    @test J_a_avg_zero(vcat(pv_zeroA, pv_zeroA), tlist_nu) ≈ 0.0 atol = 1e-15

    # Analytic gradient matches manual calculation
    G_expected = vcat(2 * A1 .* dt_nu, 2 * A2 .* dt_nu)
    @test grad_J_a_avg_zero(pulsevals_nu, tlist_nu) ≈ G_expected

    # Analytic gradient matches Zygote
    grad_J_a_zygote =
        make_grad_J_a(J_a_avg_zero, tlist_nu; mode = :automatic, automatic = Zygote)
    @test norm(grad_J_a_zygote(pulsevals_nu, tlist_nu) - G_expected) < 1e-12

end


@testset "J_T without analytic derivative" begin

    QuantumControl.set_default_ad_framework(nothing; quiet = true)
    J_T(ϕ, trajectories; tau = nothing, τ = tau) = 1.0

    trajectories = PROBLEM.trajectories

    capture = IOCapture.capture(rethrow = Union{}) do
        make_chi(J_T, trajectories)
    end
    @test contains(capture.output, "fallback to mode=:automatic")
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        @test contains(capture.value.msg, "no default `automatic`")
    end

    QuantumControl.set_default_ad_framework(Zygote; quiet = true)
    capture = IOCapture.capture() do
        make_chi(J_T, trajectories)
    end
    @test capture.value isa Function
    @test contains(capture.output, "fallback to mode=:automatic")
    @test contains(capture.output, "automatic with Zygote")

    capture = IOCapture.capture(rethrow = Union{}) do
        make_chi(J_T, trajectories; mode = :analytic)
    end
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        @test contains(capture.value.msg, "no analytic gradient")
    end

    QuantumControl.set_default_ad_framework(nothing; quiet = true)

end


@testset "J_a without analytic derivative" begin

    QuantumControl.set_default_ad_framework(nothing; quiet = true)

    J_a(pulsvals, tlist) = 0.0
    tlist = [0.0, 1.0]

    capture = IOCapture.capture(rethrow = Union{}) do
        make_grad_J_a(J_a, tlist)
    end
    @test contains(capture.output, "fallback to mode=:automatic")
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        @test contains(capture.value.msg, "no default `automatic`")
    end

    QuantumControl.set_default_ad_framework(Zygote; quiet = true)
    capture = IOCapture.capture() do
        make_grad_J_a(J_a, tlist)
    end
    @test capture.value isa Function
    @test contains(capture.output, "fallback to mode=:automatic")
    @test contains(capture.output, "automatic with Zygote")

    capture = IOCapture.capture(rethrow = Union{}) do
        make_grad_J_a(J_a, tlist; mode = :analytic)
    end
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        @test contains(capture.value.msg, "no analytic gradient")
    end

    QuantumControl.set_default_ad_framework(nothing; quiet = true)

end


module UnsupportedADFramework end


@testset "Unsupported AD Framework (J_T)" begin

    QuantumControl.set_default_ad_framework(UnsupportedADFramework; quiet = true)
    @test QuantumControl.Functionals.DEFAULT_AD_FRAMEWORK == :UnsupportedADFramework

    J_T(ϕ, trajectories; tau = nothing, τ = tau) = 1.0
    trajectories = PROBLEM.trajectories

    capture = IOCapture.capture(rethrow = Union{}, passthrough = false) do
        make_chi(J_T, trajectories)
    end
    @test contains(capture.output, "fallback to mode=:automatic")
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        msg = "no analytic gradient, and no automatic gradient"
        @test contains(capture.value.msg, msg)
    end

    capture = IOCapture.capture(rethrow = Union{}, passthrough = false) do
        make_chi(J_T, trajectories; automatic = UnsupportedADFramework)
    end
    @test contains(capture.output, "fallback to mode=:automatic")
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        msg = "no analytic gradient, and no automatic gradient"
        @test contains(capture.value.msg, msg)
    end

    capture = IOCapture.capture(rethrow = Union{}, passthrough = false) do
        make_chi(J_T, trajectories; mode = :automatic, automatic = UnsupportedADFramework)
    end
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        msg = ": no automatic gradient"
        @test contains(capture.value.msg, msg)
    end

    QuantumControl.set_default_ad_framework(nothing; quiet = true)
    @test QuantumControl.Functionals.DEFAULT_AD_FRAMEWORK == :nothing

end


@testset "Unsupported AD Framework (J_a)" begin

    QuantumControl.set_default_ad_framework(UnsupportedADFramework; quiet = true)
    @test QuantumControl.Functionals.DEFAULT_AD_FRAMEWORK == :UnsupportedADFramework

    J_a(pulsvals, tlist) = 0.0
    tlist = [0.0, 1.0]

    capture = IOCapture.capture(rethrow = Union{}, passthrough = false) do
        make_grad_J_a(J_a, tlist)
    end
    @test contains(capture.output, "fallback to mode=:automatic")
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        msg = "no analytic gradient, and no automatic gradient"
        @test contains(capture.value.msg, msg)
    end

    capture = IOCapture.capture(rethrow = Union{}, passthrough = false) do
        make_grad_J_a(J_a, tlist; automatic = UnsupportedADFramework)
    end
    @test contains(capture.output, "fallback to mode=:automatic")
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        msg = "no analytic gradient, and no automatic gradient"
        @test contains(capture.value.msg, msg)
    end

    capture = IOCapture.capture(rethrow = Union{}, passthrough = false) do
        make_grad_J_a(J_a, tlist; mode = :automatic, automatic = UnsupportedADFramework)
    end
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        msg = ": no automatic gradient"
        @test contains(capture.value.msg, msg)
    end

    QuantumControl.set_default_ad_framework(nothing; quiet = true)
    @test QuantumControl.Functionals.DEFAULT_AD_FRAMEWORK == :nothing

end


@testset "invalid functional" begin

    QuantumControl.set_default_ad_framework(Zygote; quiet = true)

    J_T(ϕ, trajectories) = 1.0  # no τ keyword argument
    trajectories = PROBLEM.trajectories
    @test_throws ErrorException begin
        IOCapture.capture() do
            make_chi(J_T, trajectories)
        end
    end

    function J_T_xxx(ϕ, trajectories; tau = nothing, τ = tau)
        throw(DomainError("XXX"))
    end

    @test_throws Exception begin
        IOCapture.capture() do
            make_chi(J_T_xxx, trajectories)
        end
    end

    @test_throws Exception begin
        IOCapture.capture() do
            make_chi(J_T_xxx, trajectories; mode = :automatic)
        end
    end

    function J_a_xxx(pulsevals, tlist)
        throw(DomainError("XXX"))
    end

    tlist = [0.0, 1.0]
    capture = IOCapture.capture() do
        make_grad_J_a(J_a_xxx, tlist)
    end
    grad_J_a = capture.value
    @test_throws DomainError begin
        grad_J_a(1, tlist)
    end

    QuantumControl.set_default_ad_framework(nothing; quiet = true)

end


@testset "functionals-tau-no-tau" begin

    # Test that the various chi routines give the same result whether they are
    # called with ϕ states or with τ values

    trajectories = PROBLEM.trajectories
    Ψ = [random_state_vector(N_HILBERT; rng = RNG) for k = 1:N]
    τ = [traj.target_state ⋅ Ψ[k] for (k, traj) in enumerate(trajectories)]

    @test J_T_re(Ψ, trajectories) ≈ J_T_re(nothing, trajectories; τ)
    χ1 = chi_re(Ψ, trajectories)
    χ2 = chi_re(Ψ, trajectories; τ)
    @test maximum(norm.(χ1 .- χ2)) < 1e-12

    @test J_T_sm(Ψ, trajectories) ≈ J_T_sm(nothing, trajectories; τ)
    χ1 = chi_sm(Ψ, trajectories)
    χ2 = chi_sm(Ψ, trajectories; τ)
    @test maximum(norm.(χ1 .- χ2)) < 1e-12

    @test J_T_ss(Ψ, trajectories) ≈ J_T_ss(nothing, trajectories; τ)
    χ1 = chi_ss(Ψ, trajectories)
    χ2 = chi_ss(Ψ, trajectories; τ)
    @test maximum(norm.(χ1 .- χ2)) < 1e-12

end


@testset "gate functional" begin

    CPHASE_lossy = [
        0.99  0    0    0
        0     0.99 0    0
        0     0    0.99 0
        0     0    0   0.99𝕚
    ]

    function ket(i::Int64; N = N)
        Ψ = zeros(ComplexF64, N)
        Ψ[i+1] = 1
        return Ψ
    end

    function ket(indices::Int64...; N = N)
        Ψ = ket(indices[1]; N = N)
        for i in indices[2:end]
            Ψ = Ψ ⊗ ket(i; N = N)
        end
        return Ψ
    end

    function ket(label::AbstractString; N = N)
        indices = [parse(Int64, digit) for digit in label]
        return ket(indices...; N = N)
    end

    basis = [ket("00"), ket("01"), ket("10"), ket("11")]


    J_T_C(U; w = 0.5) = w * (1 - gate_concurrence(U)) + (1 - w) * (1 - unitarity(U))

    @test 0.6 < gate_concurrence(CPHASE_lossy) < 0.8
    @test 0.97 < unitarity(CPHASE_lossy) < 0.99
    @test 0.1 < J_T_C(CPHASE_lossy) < 0.2


    J_T = gate_functional(J_T_C)
    Ψ = transpose(CPHASE_lossy) * basis
    trajectories = [Trajectory(Ψ, nothing) for Ψ ∈ basis]
    @test J_T(Ψ, trajectories) ≈ J_T_C(CPHASE_lossy)

    chi_J_T = make_chi(J_T, trajectories; mode = :automatic, automatic = Zygote)
    χ = chi_J_T(Ψ, trajectories)

    J_T2 = gate_functional(J_T_C; w = 0.1)
    @test (J_T2(Ψ, trajectories) - J_T_C(CPHASE_lossy)) < -0.1

    chi_J_T2 = make_chi(J_T2, trajectories; mode = :automatic, automatic = Zygote)
    χ2 = chi_J_T2(Ψ, trajectories)

    QuantumControl.set_default_ad_framework(nothing; quiet = true)

    capture = IOCapture.capture(rethrow = Union{}, passthrough = true) do
        make_gate_chi(J_T_C, trajectories)
    end
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        @test contains(capture.value.msg, "no default `automatic`")
    end

    QuantumControl.set_default_ad_framework(Zygote; quiet = true)
    capture = IOCapture.capture() do
        make_gate_chi(J_T_C, trajectories)
    end
    @test contains(capture.output, "automatic with Zygote")
    chi_J_T_C_zyg = capture.value
    χ_zyg = chi_J_T_C_zyg(Ψ, trajectories)

    QuantumControl.set_default_ad_framework(FiniteDifferences; quiet = true)
    capture = IOCapture.capture() do
        make_gate_chi(J_T_C, trajectories)
    end
    @test contains(capture.output, "automatic with FiniteDifferences")
    chi_J_T_C_fdm = capture.value
    χ_fdm = chi_J_T_C_fdm(Ψ, trajectories)

    @test maximum(norm.(χ_zyg .- χ)) < 1e-12
    @test maximum(norm.(χ_zyg .- χ_fdm)) < 1e-12

    QuantumControl.set_default_ad_framework(nothing; quiet = true)

    chi_J_T_C_zyg2 = make_gate_chi(J_T_C, trajectories; automatic = Zygote, w = 0.1)

    χ_zyg2 = chi_J_T_C_zyg2(Ψ, trajectories)

    chi_J_T_C_fdm2 =
        make_gate_chi(J_T_C, trajectories; automatic = FiniteDifferences, w = 0.1)
    χ_fdm2 = chi_J_T_C_fdm2(Ψ, trajectories)

    @test maximum(norm.(χ_zyg2 .- χ2)) < 1e-12
    @test maximum(norm.(χ_zyg2 .- χ_fdm2)) < 1e-12

end


@testset "make-xi" begin

    # Test that make_xi via Zygote and FiniteDifferences both match the known
    # analytic derivative for g_b(Ψ, traj, tlist, n) = real(⟨Ψ|traj.D|Ψ⟩),
    # which has analytic xi = -∂g_b/∂⟨Ψ| = -traj.D|Ψ⟩.
    # Each trajectory carries its own distinct D matrix as a custom property,
    # verifying that xi correctly closes over `traj` and not just `Ψ`.

    tlist = PROBLEM.tlist
    Ψ = [random_state_vector(N_HILBERT; rng = RNG) for k = 1:N]

    # Build trajectories with per-trajectory positive-semidefinite D matrices
    trajectories = [
        Trajectory(
            traj.initial_state,
            traj.generator;
            target_state = traj.target_state,
            D = let A = randn(RNG, ComplexF64, N_HILBERT, N_HILBERT)
                A * A' / N_HILBERT
            end
        ) for traj in PROBLEM.trajectories
    ]
    # Confirm D matrices are genuinely distinct across trajectories
    @test norm(trajectories[1].D - trajectories[2].D) > 1e-2

    function g_b(Ψ, traj, tlist, n)
        return real(dot(Ψ, traj.D * Ψ))
    end

    xi_zyg = make_xi(g_b; mode = :automatic, automatic = Zygote)
    xi_fdm = make_xi(g_b; mode = :automatic, automatic = FiniteDifferences)

    for k = 1:N
        ξ_analytic = -trajectories[k].D * Ψ[k]
        ξ_zyg = xi_zyg(Ψ[k], trajectories[k], tlist, 1)
        ξ_fdm = xi_fdm(Ψ[k], trajectories[k], tlist, 1)
        @test norm(ξ_zyg - ξ_analytic) < 1e-12
        @test norm(ξ_fdm - ξ_analytic) < 1e-10
    end

    # make_xi with mode=:any falls back to :automatic when no analytic xi exists
    QuantumControl.set_default_ad_framework(Zygote; quiet = true)
    capture = IOCapture.capture() do
        make_xi(g_b)
    end
    @test capture.value isa Function
    @test contains(capture.output, "fallback to mode=:automatic")
    QuantumControl.set_default_ad_framework(nothing; quiet = true)

    # make_xi with mode=:analytic errors when no analytic xi is implemented
    capture = IOCapture.capture(rethrow = Union{}) do
        make_xi(g_b; mode = :analytic)
    end
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        @test contains(capture.value.msg, "no analytic gradient")
    end

end


@testset "make-xi (time-dependent-discrete D)" begin

    tlist = PROBLEM.tlist
    N_intervals = length(tlist) - 1
    Ψ = [random_state_vector(N_HILBERT; rng = RNG) for k = 1:N]

    trajectories = [
        Trajectory(
            traj.initial_state,
            traj.generator;
            target_state = traj.target_state,
            D = let H = random_dynamic_generator(
                    N_HILBERT,
                    tlist;
                    rng = RNG,
                    hermitian = true,
                    complex = true,
                )
                D_int = [Array(evaluate(H, tlist, n)) for n = 1:N_intervals]
                D_tl = Vector{Matrix{ComplexF64}}(undef, length(tlist))
                # We use the same interpolation method as in `discretize` for
                # converting between controls on the intervals of the time
                # grid to controls on the time grid points
                D_tl[1] = D_int[1]
                D_tl[end] = D_int[end]
                for n = 2:N_intervals
                    D_tl[n] = 0.5 .* (D_int[n-1] .+ D_int[n])
                end
                D_tl
            end
        ) for traj in PROBLEM.trajectories
    ]
    # D varies across trajectories and across time steps within a trajectory
    @test norm(trajectories[1].D[1] - trajectories[2].D[1]) > 1e-2
    @test norm(trajectories[1].D[1] - trajectories[1].D[end]) > 1e-2

    function g_b_td(Ψ, traj, tlist, n)
        return real(dot(Ψ, traj.D[n] * Ψ))
    end

    xi_zyg = make_xi(g_b_td; mode = :automatic, automatic = Zygote)
    xi_fdm = make_xi(g_b_td; mode = :automatic, automatic = FiniteDifferences)

    # Check several time points including the first and last
    for k = 1:N
        for n in [1, length(tlist) ÷ 2, length(tlist)]
            ξ_analytic = -trajectories[k].D[n] * Ψ[k]
            ξ_zyg = xi_zyg(Ψ[k], trajectories[k], tlist, n)
            ξ_fdm = xi_fdm(Ψ[k], trajectories[k], tlist, n)
            @test norm(ξ_zyg - ξ_analytic) < 1e-12
            @test norm(ξ_fdm - ξ_analytic) < 1e-10
        end
    end

end


@testset "make-xi (time-dependent-continuous D)" begin

    # Each trajectory has two random Hermitian matrices D1 and D2.
    # The operator D(t) = cos(t)² D1 + sin(t)² D2 is a smooth, Hermitian
    # combination that varies continuously over time (the coefficients form a
    # partition of unity: cos²+sin²=1). g_b uses tlist[n] directly to evaluate
    # the analytic formula. The analytic xi is -(cos(t)² D1 + sin(t)² D2)|Ψ⟩.

    tlist = PROBLEM.tlist
    Ψ = [random_state_vector(N_HILBERT; rng = RNG) for k = 1:N]

    trajectories = [
        Trajectory(
            traj.initial_state,
            traj.generator;
            target_state = traj.target_state,
            D1 = let A = randn(RNG, ComplexF64, N_HILBERT, N_HILBERT)
                A + A'
            end,
            D2 = let A = randn(RNG, ComplexF64, N_HILBERT, N_HILBERT)
                A + A'
            end,
        ) for traj in PROBLEM.trajectories
    ]
    @test norm(trajectories[1].D1 - trajectories[2].D1) > 1e-2
    @test norm(trajectories[1].D1 - trajectories[1].D2) > 1e-2

    function g_b_analytic_td(Ψ, traj, tlist, n)
        t = tlist[n]
        D = cos(t)^2 * traj.D1 + sin(t)^2 * traj.D2
        return real(dot(Ψ, D * Ψ))
    end

    xi_zyg = make_xi(g_b_analytic_td; mode = :automatic, automatic = Zygote)
    xi_fdm = make_xi(g_b_analytic_td; mode = :automatic, automatic = FiniteDifferences)

    for k = 1:N
        for n in [1, length(tlist) ÷ 2, length(tlist)]
            t = tlist[n]
            D = cos(t)^2 * trajectories[k].D1 + sin(t)^2 * trajectories[k].D2
            ξ_analytic = -D * Ψ[k]
            ξ_zyg = xi_zyg(Ψ[k], trajectories[k], tlist, n)
            ξ_fdm = xi_fdm(Ψ[k], trajectories[k], tlist, n)
            @test norm(ξ_zyg - ξ_analytic) < 1e-12
            @test norm(ξ_fdm - ξ_analytic) < 1e-10
        end
    end

end


@testset "make-xi (analytic path)" begin

    # Register an analytic xi for a custom g_b function.
    function g_b_with_xi(Ψ, traj, tlist, n)
        return real(dot(Ψ, Ψ))
    end
    function xi_for_g_b(Ψ, traj, tlist, n)
        return -Ψ
    end
    QuantumControl.Functionals.make_analytic_xi(::typeof(g_b_with_xi)) = xi_for_g_b

    tlist = PROBLEM.tlist
    Ψ = random_state_vector(N_HILBERT; rng = RNG)
    traj = PROBLEM.trajectories[1]

    xi = make_xi(g_b_with_xi; mode = :analytic)
    @test xi ≡ xi_for_g_b
    @test xi(Ψ, traj, tlist, 1) ≈ -Ψ

    # mode=:any uses the analytic path and emits a @debug message
    captured = IOCapture.capture() do
        Logging.with_logger(Logging.ConsoleLogger(stderr, Logging.Debug)) do
            make_xi(g_b_with_xi)
        end
    end
    @test captured.value isa Function
    @test contains(captured.output, "make_xi for g_b=")
    @test contains(captured.output, "-> analytic")

end


@testset "g_b without analytic derivative" begin

    QuantumControl.set_default_ad_framework(nothing; quiet = true)

    function g_b_no_xi(Ψ, traj, tlist, n)
        return real(dot(Ψ, Ψ))
    end

    captured = IOCapture.capture(rethrow = Union{}) do
        make_xi(g_b_no_xi)
    end
    @test contains(captured.output, "fallback to mode=:automatic")
    @test captured.value isa ErrorException
    if captured.value isa ErrorException
        @test contains(captured.value.msg, "no default `automatic`")
    end

    QuantumControl.set_default_ad_framework(Zygote; quiet = true)
    captured = IOCapture.capture() do
        make_xi(g_b_no_xi)
    end
    @test captured.value isa Function
    @test contains(captured.output, "fallback to mode=:automatic")

    captured = IOCapture.capture(rethrow = Union{}) do
        make_xi(g_b_no_xi; mode = :analytic)
    end
    @test captured.value isa ErrorException
    if captured.value isa ErrorException
        @test contains(captured.value.msg, "no analytic gradient")
    end

    QuantumControl.set_default_ad_framework(nothing; quiet = true)

end


@testset "Unsupported AD Framework (make_xi)" begin

    QuantumControl.set_default_ad_framework(UnsupportedADFramework; quiet = true)

    function g_b_no_xi(Ψ, traj, tlist, n)
        return real(dot(Ψ, Ψ))
    end

    captured = IOCapture.capture(rethrow = Union{}, passthrough = false) do
        make_xi(g_b_no_xi)
    end
    @test contains(captured.output, "fallback to mode=:automatic")
    @test captured.value isa ErrorException
    if captured.value isa ErrorException
        @test contains(
            captured.value.msg,
            "no analytic gradient, and no automatic gradient"
        )
    end

    captured = IOCapture.capture(rethrow = Union{}, passthrough = false) do
        make_xi(g_b_no_xi; automatic = UnsupportedADFramework)
    end
    @test contains(captured.output, "fallback to mode=:automatic")
    @test captured.value isa ErrorException
    if captured.value isa ErrorException
        @test contains(
            captured.value.msg,
            "no analytic gradient, and no automatic gradient"
        )
    end

    captured = IOCapture.capture(rethrow = Union{}, passthrough = false) do
        make_xi(g_b_no_xi; mode = :automatic, automatic = UnsupportedADFramework)
    end
    @test captured.value isa ErrorException
    if captured.value isa ErrorException
        @test contains(captured.value.msg, "no automatic gradient")
    end

    QuantumControl.set_default_ad_framework(nothing; quiet = true)

end


@testset "make-xi (invalid g_b interface)" begin

    # A g_b with wrong signature: only takes Ψ, not (Ψ, traj, tlist, n).
    function bad_g_b(Ψ)
        return 1.0
    end

    # make_xi itself succeeds (no interface validation at construction time)
    xi_bad = make_xi(bad_g_b; mode = :automatic, automatic = Zygote)
    @test xi_bad isa Function

    tlist = PROBLEM.tlist
    traj = PROBLEM.trajectories[1]
    Ψ = random_state_vector(N_HILBERT; rng = RNG)

    # Calling the returned xi fails because g_b has the wrong interface
    captured = IOCapture.capture(rethrow = Union{}) do
        xi_bad(Ψ, traj, tlist, 1)
    end
    @test captured.value isa MethodError
    if captured.value isa MethodError
        @test contains(sprint(showerror, captured.value), "bad_g_b")
    end

end


@testset "J_b" begin

    # Test that J_b correctly integrates g_b over all trajectories and time.
    # Uses simple storage (vector of vectors) and a constant g_b = |Ψ| = 1
    # whose integral is fully determined by the time grid and number of
    # trajectories.

    tlist = PROBLEM.tlist
    T = tlist[end]
    trajectories = PROBLEM.trajectories
    N = length(trajectories)
    N_tl = length(tlist)

    # Build fake storage: each trajectory gets a vector of random states
    storage = [[random_state_vector(N_HILBERT; rng = RNG) for _ = 1:N_tl] for _ = 1:N]

    function g_b_const(Ψ, traj, tlist, n)
        return norm(Ψ)
    end

    J_b_val = J_b(storage, trajectories, tlist; g_b = g_b_const)

    # Trapezoidal rule for integral should return the exact result
    @test J_b_val ≈ T * N

    # With g_b ∝ n, J_b should reflect the weighted sum over time indices
    function g_b_index(Ψ, traj, tlist, n)
        return Float64(n)
    end

    J_b_idx = J_b(storage, trajectories, tlist; g_b = g_b_index)

    # Again, the integral should be exact
    @test J_b_idx ≈ ((N_tl - 1) / 2 + 1) * T * N

end
