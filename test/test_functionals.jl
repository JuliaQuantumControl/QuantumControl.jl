using Test
using LinearAlgebra
using QuantumControl: QuantumControl, Trajectory
using QuantumControl.Functionals:
    J_T_sm,
    J_T_re,
    J_T_ss,
    J_a_fluence,
    grad_J_a_fluence,
    make_grad_J_a,
    make_chi,
    chi_re,
    chi_sm,
    chi_ss,
    gate_functional,
    make_gate_chi
using QuantumControlTestUtils.RandomObjects: random_state_vector
using QuantumControlTestUtils.DummyOptimization: dummy_control_problem
using TwoQubitWeylChamber: D_PE, gate_concurrence, unitarity
using StableRNGs: StableRNG
using Zygote
using GRAPE: GrapeWrk
using FiniteDifferences
using IOCapture

const 𝕚 = 1im
const ⊗ = kron

N_HILBERT = 10
N = 4
L = 2
N_T = 50
RNG = StableRNG(4290326946)
PROBLEM = dummy_control_problem(;
    N=N_HILBERT,
    n_trajectories=N,
    n_controls=L,
    n_steps=N_T,
    rng=RNG,
    J_T=J_T_sm,
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
    Ψ = [random_state_vector(N_HILBERT; rng=RNG) for k = 1:N]
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

    grad_J_a_zygote = make_grad_J_a(J_a_fluence, tlist; mode=:automatic, automatic=Zygote)
    @test grad_J_a_zygote ≢ grad_J_a_fluence
    G2 = grad_J_a_zygote(pulsevals, tlist)

    grad_J_a_fdm =
        make_grad_J_a(J_a_fluence, tlist; mode=:automatic, automatic=FiniteDifferences)
    @test grad_J_a_fdm ≢ grad_J_a_fluence
    @test grad_J_a_fdm ≢ grad_J_a_zygote
    G3 = grad_J_a_fdm(pulsevals, tlist)

    @test 0.0 ≤ norm(G2 - G1) < 1e-12  # zygote can be exact
    @test 0.0 < norm(G3 - G1) < 1e-12  # fdm should not be exact
    @test 0.0 < norm(G3 - G2) < 1e-10

end


@testset "J_T without analytic derivative" begin

    QuantumControl.set_default_ad_framework(nothing; quiet=true)
    J_T(ϕ, trajectories; tau=nothing, τ=tau) = 1.0

    trajectories = PROBLEM.trajectories

    capture = IOCapture.capture(rethrow=Union{}) do
        make_chi(J_T, trajectories)
    end
    @test contains(capture.output, "fallback to mode=:automatic")
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        @test contains(capture.value.msg, "no default `automatic`")
    end

    QuantumControl.set_default_ad_framework(Zygote; quiet=true)
    capture = IOCapture.capture() do
        make_chi(J_T, trajectories)
    end
    @test capture.value isa Function
    @test contains(capture.output, "fallback to mode=:automatic")
    @test contains(capture.output, "automatic with Zygote")

    capture = IOCapture.capture(rethrow=Union{}) do
        make_chi(J_T, trajectories; mode=:analytic)
    end
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        @test contains(capture.value.msg, "no analytic gradient")
    end

    QuantumControl.set_default_ad_framework(nothing; quiet=true)

end


@testset "J_a without analytic derivative" begin

    QuantumControl.set_default_ad_framework(nothing; quiet=true)

    J_a(pulsvals, tlist) = 0.0
    tlist = [0.0, 1.0]

    capture = IOCapture.capture(rethrow=Union{}) do
        make_grad_J_a(J_a, tlist)
    end
    @test contains(capture.output, "fallback to mode=:automatic")
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        @test contains(capture.value.msg, "no default `automatic`")
    end

    QuantumControl.set_default_ad_framework(Zygote; quiet=true)
    capture = IOCapture.capture() do
        make_grad_J_a(J_a, tlist)
    end
    @test capture.value isa Function
    @test contains(capture.output, "fallback to mode=:automatic")
    @test contains(capture.output, "automatic with Zygote")

    capture = IOCapture.capture(rethrow=Union{}) do
        make_grad_J_a(J_a, tlist; mode=:analytic)
    end
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        @test contains(capture.value.msg, "no analytic gradient")
    end

    QuantumControl.set_default_ad_framework(nothing; quiet=true)

end


module UnsupportedADFramework end


@testset "Unsupported AD Framework (J_T)" begin

    QuantumControl.set_default_ad_framework(UnsupportedADFramework; quiet=true)
    @test QuantumControl.Functionals.DEFAULT_AD_FRAMEWORK == :UnsupportedADFramework

    J_T(ϕ, trajectories; tau=nothing, τ=tau) = 1.0
    trajectories = PROBLEM.trajectories

    capture = IOCapture.capture(rethrow=Union{}, passthrough=false) do
        make_chi(J_T, trajectories)
    end
    @test contains(capture.output, "fallback to mode=:automatic")
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        msg = "no analytic gradient, and no automatic gradient"
        @test contains(capture.value.msg, msg)
    end

    capture = IOCapture.capture(rethrow=Union{}, passthrough=false) do
        make_chi(J_T, trajectories; automatic=UnsupportedADFramework)
    end
    @test contains(capture.output, "fallback to mode=:automatic")
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        msg = "no analytic gradient, and no automatic gradient"
        @test contains(capture.value.msg, msg)
    end

    capture = IOCapture.capture(rethrow=Union{}, passthrough=false) do
        make_chi(J_T, trajectories; mode=:automatic, automatic=UnsupportedADFramework)
    end
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        msg = ": no automatic gradient"
        @test contains(capture.value.msg, msg)
    end

    QuantumControl.set_default_ad_framework(nothing; quiet=true)
    @test QuantumControl.Functionals.DEFAULT_AD_FRAMEWORK == :nothing

end


@testset "Unsupported AD Framework (J_a)" begin

    QuantumControl.set_default_ad_framework(UnsupportedADFramework; quiet=true)
    @test QuantumControl.Functionals.DEFAULT_AD_FRAMEWORK == :UnsupportedADFramework

    J_a(pulsvals, tlist) = 0.0
    tlist = [0.0, 1.0]

    capture = IOCapture.capture(rethrow=Union{}, passthrough=false) do
        make_grad_J_a(J_a, tlist)
    end
    @test contains(capture.output, "fallback to mode=:automatic")
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        msg = "no analytic gradient, and no automatic gradient"
        @test contains(capture.value.msg, msg)
    end

    capture = IOCapture.capture(rethrow=Union{}, passthrough=false) do
        make_grad_J_a(J_a, tlist; automatic=UnsupportedADFramework)
    end
    @test contains(capture.output, "fallback to mode=:automatic")
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        msg = "no analytic gradient, and no automatic gradient"
        @test contains(capture.value.msg, msg)
    end

    capture = IOCapture.capture(rethrow=Union{}, passthrough=false) do
        make_grad_J_a(J_a, tlist; mode=:automatic, automatic=UnsupportedADFramework)
    end
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        msg = ": no automatic gradient"
        @test contains(capture.value.msg, msg)
    end

    QuantumControl.set_default_ad_framework(nothing; quiet=true)
    @test QuantumControl.Functionals.DEFAULT_AD_FRAMEWORK == :nothing

end


@testset "invalid functional" begin

    QuantumControl.set_default_ad_framework(Zygote; quiet=true)

    J_T(ϕ, trajectories) = 1.0  # no τ keyword argument
    trajectories = PROBLEM.trajectories
    @test_throws ErrorException begin
        IOCapture.capture() do
            make_chi(J_T, trajectories)
        end
    end

    function J_T_xxx(ϕ, trajectories; tau=nothing, τ=tau)
        throw(DomainError("XXX"))
    end

    @test_throws DomainError begin
        IOCapture.capture() do
            make_chi(J_T_xxx, trajectories)
        end
    end

    @test_throws DomainError begin
        IOCapture.capture() do
            make_chi(J_T_xxx, trajectories; mode=:automatic)
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

    QuantumControl.set_default_ad_framework(nothing; quiet=true)

end


@testset "functionals-tau-no-tau" begin

    # Test that the various chi routines give the same result whether they are
    # called with ϕ states or with τ values

    trajectories = PROBLEM.trajectories
    Ψ = [random_state_vector(N_HILBERT; rng=RNG) for k = 1:N]
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

    function ket(i::Int64; N=N)
        Ψ = zeros(ComplexF64, N)
        Ψ[i+1] = 1
        return Ψ
    end

    function ket(indices::Int64...; N=N)
        Ψ = ket(indices[1]; N=N)
        for i in indices[2:end]
            Ψ = Ψ ⊗ ket(i; N=N)
        end
        return Ψ
    end

    function ket(label::AbstractString; N=N)
        indices = [parse(Int64, digit) for digit in label]
        return ket(indices...; N=N)
    end

    basis = [ket("00"), ket("01"), ket("10"), ket("11")]


    J_T_C(U; w=0.5) = w * (1 - gate_concurrence(U)) + (1 - w) * (1 - unitarity(U))

    @test 0.6 < gate_concurrence(CPHASE_lossy) < 0.8
    @test 0.97 < unitarity(CPHASE_lossy) < 0.99
    @test 0.1 < J_T_C(CPHASE_lossy) < 0.2


    J_T = gate_functional(J_T_C)
    Ψ = transpose(CPHASE_lossy) * basis
    trajectories = [Trajectory(Ψ, nothing) for Ψ ∈ basis]
    @test J_T(Ψ, trajectories) ≈ J_T_C(CPHASE_lossy)

    chi_J_T = make_chi(J_T, trajectories; mode=:automatic, automatic=Zygote)
    χ = chi_J_T(Ψ, trajectories)

    J_T2 = gate_functional(J_T_C; w=0.1)
    @test (J_T2(Ψ, trajectories) - J_T_C(CPHASE_lossy)) < -0.1

    chi_J_T2 = make_chi(J_T2, trajectories; mode=:automatic, automatic=Zygote)
    χ2 = chi_J_T2(Ψ, trajectories)

    QuantumControl.set_default_ad_framework(nothing; quiet=true)

    capture = IOCapture.capture(rethrow=Union{}, passthrough=true) do
        make_gate_chi(J_T_C, trajectories)
    end
    @test capture.value isa ErrorException
    if capture.value isa ErrorException
        @test contains(capture.value.msg, "no default `automatic`")
    end

    QuantumControl.set_default_ad_framework(Zygote; quiet=true)
    capture = IOCapture.capture() do
        make_gate_chi(J_T_C, trajectories)
    end
    @test contains(capture.output, "automatic with Zygote")
    chi_J_T_C_zyg = capture.value
    χ_zyg = chi_J_T_C_zyg(Ψ, trajectories)

    QuantumControl.set_default_ad_framework(FiniteDifferences; quiet=true)
    capture = IOCapture.capture() do
        make_gate_chi(J_T_C, trajectories)
    end
    @test contains(capture.output, "automatic with FiniteDifferences")
    chi_J_T_C_fdm = capture.value
    χ_fdm = chi_J_T_C_fdm(Ψ, trajectories)

    @test maximum(norm.(χ_zyg .- χ)) < 1e-12
    @test maximum(norm.(χ_zyg .- χ_fdm)) < 1e-12

    QuantumControl.set_default_ad_framework(nothing; quiet=true)

    chi_J_T_C_zyg2 = make_gate_chi(J_T_C, trajectories; automatic=Zygote, w=0.1)
    χ_zyg2 = chi_J_T_C_zyg2(Ψ, trajectories)

    chi_J_T_C_fdm2 = make_gate_chi(J_T_C, trajectories; automatic=FiniteDifferences, w=0.1)
    χ_fdm2 = chi_J_T_C_fdm2(Ψ, trajectories)

    @test maximum(norm.(χ_zyg2 .- χ2)) < 1e-12
    @test maximum(norm.(χ_zyg2 .- χ_fdm2)) < 1e-12

end
