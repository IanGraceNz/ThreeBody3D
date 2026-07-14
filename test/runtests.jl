using Test
using LinearAlgebra
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
    extreme = simulate(system, u0, (0.0, 2period); solver=:extreme, saveat=period/50)

    fast_drift = diagnostics_report(fast).maximum_relative_energy_drift
    accurate_drift = diagnostics_report(accurate).maximum_relative_energy_drift
    extreme_drift = diagnostics_report(extreme).maximum_relative_energy_drift

    @test accurate_drift < fast_drift
    @test extreme_drift <= 10 * accurate_drift
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
    @test_throws ArgumentError accuracy_profile(:unknown)

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
    @test benchmarks[1].maximum_relative_energy_drift >= 0
    @test occursin("accepted internal steps", sprint(show, benchmarks[1]))
    @test_throws ArgumentError benchmark_solvers(system, u0, (0.0, 0.1);
                                                  profiles=(), saveat=0.02)
end
