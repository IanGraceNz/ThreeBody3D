using Test
using LinearAlgebra
using Logging
using StaticArrays
using SciMLBase
using ThreeBody3D

const FIG8_POS = 0.97000436
const FIG8_VX = 0.466203685
const FIG8_VY = 0.432365730

function figure_eight_setup()
    system = ThreeBodySystem((1.0, 1.0, 1.0))
    u0 = statevector(
        [-FIG8_POS,  0.24308753, 0.0], [ FIG8_VX,  FIG8_VY, 0.0],
        [ FIG8_POS, -0.24308753, 0.0], [ FIG8_VX,  FIG8_VY, 0.0],
        [0.0, 0.0, 0.0],              [-2FIG8_VX, -2FIG8_VY, 0.0],
    )
    system, u0
end

@testset "ThreeBodySystem" begin
    s = ThreeBodySystem((1, 2.0, 3f0); G=2)
    @test s.masses == SVector(1.0, 2.0, 3.0)
    @test s.G == 2.0
    @test_throws ArgumentError ThreeBodySystem((1.0, 0.0, 1.0))
    @test_throws ArgumentError ThreeBodySystem((1.0, -1.0, 1.0))
    @test_throws ArgumentError ThreeBodySystem((1.0, 1.0, 1.0); G=0)
    @test_throws ArgumentError ThreeBodySystem([1.0, 2.0])
end

@testset "State construction and access" begin
    u = statevector([1,2,3], [4,5,6], [7,8,9], [10,11,12], [13,14,15], [16,17,18])
    @test eltype(u) == Float64
    @test length(u) == STATE_SIZE
    @test body_position(u, 1) == SVector(1.0,2.0,3.0)
    @test velocity(u, 3) == SVector(16.0,17.0,18.0)
    @test_throws BoundsError body_position(u, 0)
    @test_throws ArgumentError statevector([1,2], [1,2,3], [1,2,3], [1,2,3], [1,2,3], [1,2,3])
end

@testset "Physics and invariants" begin
    system, u = figure_eight_setup()
    du = similar(u)
    ThreeBody3D.threebody!(du, u, system, 0.0)
    @test du[1:3] == u[4:6]
    @test du[7:9] == u[10:12]
    @test du[13:15] == u[16:18]
    net_force = sum(system.masses[i] * SVector{3}(du[6(i-1)+4:6(i-1)+6]) for i in 1:3)
    @test norm(net_force) ≤ 50eps(Float64)
    @test norm(linear_momentum(system, u)) ≤ 10eps(Float64)
    @test norm(center_of_mass(system, u)) ≤ 10eps(Float64)
    @test minimum_separation(u) > 0

    collision = copy(u)
    collision[13:15] .= collision[1:3]
    @test_throws DomainError ThreeBody3D.threebody!(similar(u), collision, system, 0.0)
    @test_throws DomainError potential_energy(system, collision)
end

@testset "Integration and diagnostics" begin
    system, u0 = figure_eight_setup()
    result = simulate(system, u0, (0.0, 2.0); saveat=0.01)
    @test SciMLBase.successful_retcode(result.solution)
    @test result.system === result.solution.prob.p
    @test length(result) == length(result.solution)
    @test length(result(0.5)) == STATE_SIZE

    report = diagnostics_report(result)
    @test report.maximum_relative_energy_drift < 1e-8
    @test report.maximum_linear_momentum_drift < 1e-10
    @test report.maximum_angular_momentum_drift < 1e-10
    @test report.maximum_center_of_mass_residual < 1e-10
    @test report.minimum_separation > 0
    @test relative_energy_error(result) == report.maximum_relative_energy_drift
    @test occursin("maximum relative energy drift", sprint(show, report))
end

@testset "Argument validation" begin
    system, u0 = figure_eight_setup()
    @test_throws ArgumentError simulate(system, u0, (1.0, 0.0))
    @test_throws ArgumentError simulate(system, u0, (0.0, 1.0); reltol=0)
    @test_throws ArgumentError simulate(system, u0, (0.0, 1.0); abstol=0)
end

@testset "Exported API is documented" begin
    for name in names(ThreeBody3D; all=false, imported=false)
        name in (:eval, :include) && continue
        binding = getfield(ThreeBody3D, name)
        @test Docs.doc(binding) !== nothing
    end
end

@testset "Profile accuracy regression" begin
    system, u0 = figure_eight_setup()
    period = 6.32591398
    fast = simulate(system, u0, (0.0, 2period); solver=:fast, saveat=period/50)
    accurate = simulate(system, u0, (0.0, 2period); solver=:accurate, saveat=period/50)

    fast_drift = diagnostics_report(fast).maximum_relative_energy_drift
    accurate_drift = diagnostics_report(accurate).maximum_relative_energy_drift
    @test accurate_drift < fast_drift

    extreme = @test_logs (:warn, r"promoting non-BigFloat inputs") simulate(
        system, u0, (0.0, 0.02); solver=:extreme, precision=128, saveat=0.01
    )
    @test eltype(extreme.solution.u[1]) === BigFloat
    @test precision(extreme.solution.u[1][1]) == 128
end

@testset "BigFloat extreme reference accuracy" begin
    setprecision(BigFloat, 256) do
        system = ThreeBodySystem(
            (big"1.0", big"1.0", big"1.0");
            G=big"1.0",
        )
        u0 = statevector(
            [big"-0.97000436", big"0.24308753", big"0.0"],
            [big"0.466203685", big"0.432365730", big"0.0"],
            [big"0.97000436", big"-0.24308753", big"0.0"],
            [big"0.466203685", big"0.432365730", big"0.0"],
            [big"0.0", big"0.0", big"0.0"],
            [big"-0.93240737", big"-0.86473146", big"0.0"],
        )
        result = simulate(
            system, u0, (big"0.0", big"0.1");
            solver=:extreme,
            precision=256,
            saveat=big"0.01",
        )
        report = diagnostics_report(result)
        @test eltype(result.solution.u[1]) === BigFloat
        @test precision(result.solution.u[1][1]) == 256
        @test report.maximum_relative_energy_drift < big"1e-25"
        @test report.maximum_angular_momentum_drift < big"1e-25"
    end
end


@testset "Continuous close-approach monitoring" begin
    system, u0 = figure_eight_setup()
    threshold = 0.8

    coarse = simulate(system, u0, (0.0, 4.0);
                      solver=:accurate, saveat=2.0,
                      close_approach_threshold=threshold,
                      close_approach_policy=:ignore)
    fine = simulate(system, u0, (0.0, 4.0);
                    solver=:accurate, saveat=0.01,
                    close_approach_threshold=threshold,
                    close_approach_policy=:ignore)

    @test !isempty(coarse.close_approach_events)
    @test !isempty(fine.close_approach_events)
    coarse_event = first(coarse.close_approach_events)
    fine_event = first(fine.close_approach_events)
    @test coarse_event.pair == fine_event.pair
    @test coarse_event.separation ≈ threshold atol=1e-9
    @test fine_event.separation ≈ threshold atol=1e-9
    @test coarse_event.time ≈ fine_event.time atol=1e-9
    @test occursin("CloseApproachEvent", sprint(show, coarse_event))
    @test !terminated_by_close_approach(coarse)

    terminated = simulate(system, u0, (0.0, 4.0);
                          solver=:accurate, saveat=2.0,
                          close_approach_threshold=threshold,
                          close_approach_policy=:terminate)
    @test terminated_by_close_approach(terminated)
    @test length(terminated.close_approach_events) == 1
    @test last(terminated.solution.t) ≈ first(terminated.close_approach_events).time atol=1e-9
    @test last(terminated.solution.t) < 4.0
    @test terminated.close_approach_terminated

    warned = @test_logs min_level=Logging.Warn match_mode=:any (
        :warn, r"Close-approach threshold crossed"
    ) simulate(
        system, u0, (0.0, 4.0);
        solver=:accurate, saveat=2.0,
        close_approach_threshold=threshold,
        close_approach_policy=:warn,
    )
    @test !isempty(warned.close_approach_events)
    @test !terminated_by_close_approach(warned)

    user_event = Ref(false)
    user_condition(u, t, integrator) = t - 0.25
    user_affect!(integrator) = (user_event[] = true)
    user_callback = SciMLBase.ContinuousCallback(user_condition, user_affect!)
    combined = simulate(
        system, u0, (0.0, 4.0);
        solver=:accurate, saveat=2.0,
        close_approach_threshold=threshold,
        close_approach_policy=:ignore,
        callback=user_callback,
    )
    @test user_event[]
    @test !isempty(combined.close_approach_events)

    @test_throws ArgumentError simulate(system, u0, (0.0, 1.0);
                                        close_approach_threshold=0.0)
    @test_throws ArgumentError simulate(system, u0, (0.0, 1.0);
                                        close_approach_threshold=0.8,
                                        close_approach_policy=:invalid)
    @test_throws ArgumentError simulate(system, u0, (0.0, 1.0);
                                        close_approach_threshold=2.0,
                                        close_approach_policy=:terminate)
end

@testset "Visualization smoke tests" begin
    system, u0 = figure_eight_setup()
    result = simulate(system, u0, (0.0, 0.2); saveat=0.02)
    fig = plot_trajectory(result; show=false)
    @test fig !== nothing
    @test_throws ArgumentError record_animation(result, "not-an-mp4.gif"; duration=0.1)
end

@testset "Accuracy profiles and numerical validation" begin
    fast = accuracy_profile(:fast)
    accurate = accuracy_profile()
    extreme = accuracy_profile(:extreme)
    @test fast.name == :fast
    @test accurate.name == :accurate
    @test extreme.name == :extreme
    @test fast.reltol > accurate.reltol > extreme.reltol
    @test occursin("Vern9", string(typeof(extreme.algorithm)))
    @test extreme.reltol isa BigFloat
    @test_throws ArgumentError accuracy_profile(:unknown)
    @test_throws ArgumentError accuracy_profile(:extreme; precision=32)

    system, u0 = figure_eight_setup()
    result = simulate(system, u0, (0.0, 0.2); solver=:fast, saveat=0.01)
    @test periodicity_error(result, 0.1) >= 0
    @test periodicity_error(result, 0.1; relative=false) >= 0
    @test_throws ArgumentError periodicity_error(result, 0.0)
    @test_throws ArgumentError periodicity_error(result, 1.0)

    close = close_approach_report(result; threshold=10.0)
    sampled_close = close_approach_report(result; threshold=10.0, refine=false)
    @test close.detected
    @test close.minimum_separation > 0
    @test close.minimum_separation <= sampled_close.minimum_separation
    @test close.pair in ((1, 2), (1, 3), (2, 3))
    @test first(result.solution.t) <= close.time <= last(result.solution.t)
    @test occursin("minimum_separation", sprint(show, close))
    @test_throws ArgumentError close_approach_report(result; threshold=0.0)

    benchmarks = benchmark_solvers(system, u0, (0.0, 0.1);
                                   profiles=(:fast,), saveat=0.02)
    @test length(benchmarks) == 1
    @test benchmarks[1].profile == :fast
    @test benchmarks[1].saved_states >= 2
    @test benchmarks[1].accepted_steps > 0
    @test benchmarks[1].rhs_evaluations > 0
    @test benchmarks[1].elapsed_seconds >= 0
    @test benchmarks[1].maximum_relative_energy_drift >= 0
    @test occursin("accepted internal steps", sprint(show, benchmarks[1]))
    @test_throws ArgumentError benchmark_solvers(system, u0, (0.0, 0.1);
                                                  profiles=(), saveat=0.02)

    hp = benchmark_extreme_solvers(
        system, u0, (0.0, 0.01);
        algorithms=(:vern9,), precision=128,
        reltol="1e-20", abstol="1e-20", saveat=0.005,
    )
    @test length(hp) == 1
    @test hp[1].profile == :vern9
    @test hp[1].maximum_relative_energy_drift isa BigFloat
    @test hp[1].elapsed_seconds >= 0
    @test_throws ArgumentError benchmark_extreme_solvers(
        system, u0, (0.0, 0.01); algorithms=(:unknown,), precision=128
    )
end
