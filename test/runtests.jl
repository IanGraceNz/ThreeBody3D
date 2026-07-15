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

@testset "Pair-centred coordinate transformations" begin
    system = ThreeBodySystem((2, 3.0, 5f0); G=2)
    u = statevector(
        [1, 2, 3], [4, 5, 6],
        [-2, 1, 7], [3, -4, 2],
        [8, -3, 1], [-1, 2, -5],
    )

    for pair in ((1, 2), (2, 1), (1, 3), (3, 1), (2, 3), (3, 2))
        coordinates = to_pair_coordinates(system, u, pair)
        reconstructed = from_pair_coordinates(system, coordinates)
        @test reconstructed ≈ u rtol=8eps(eltype(u)) atol=8eps(eltype(u))
        @test coordinates.third == only(setdiff(1:3, collect(pair)))

        i, j = pair
        @test coordinates.relative_position == body_position(u, i) - body_position(u, j)
        @test coordinates.relative_velocity == velocity(u, i) - velocity(u, j)

        mi, mj = system.masses[i], system.masses[j]
        @test coordinates.binary_com_position ==
              (mi * body_position(u, i) + mj * body_position(u, j)) / (mi + mj)
        @test coordinates.binary_com_velocity ==
              (mi * velocity(u, i) + mj * velocity(u, j)) / (mi + mj)
    end

    forward = to_pair_coordinates(system, u, (1, 2))
    reverse = to_pair_coordinates(system, u, (2, 1))
    @test reverse.relative_position == -forward.relative_position
    @test reverse.relative_velocity == -forward.relative_velocity
    @test reverse.binary_com_position == forward.binary_com_position
    @test reverse.binary_com_velocity == forward.binary_com_velocity
    @test from_pair_coordinates(system, reverse) ≈ u rtol=8eps(eltype(u)) atol=8eps(eltype(u))

    mixed_system = ThreeBodySystem((big"2.0", 3, 5f0))
    big_u = BigFloat.(u)
    big_coordinates = to_pair_coordinates(mixed_system, big_u, (1, 3))
    @test eltype(big_coordinates.relative_position) === BigFloat
    @test from_pair_coordinates(mixed_system, big_coordinates) ≈ big_u rtol=8eps(BigFloat) atol=8eps(BigFloat)

    @test_throws ArgumentError to_pair_coordinates(system, u, (1, 1))
    @test_throws ArgumentError to_pair_coordinates(system, u, (0, 2))
    @test_throws ArgumentError to_pair_coordinates(system, u, (1, 4))
end

@testset "Analytic Kepler validation harness" begin
    μ = 1.0

    circular = KeplerReference(μ, [1.0, 0.0, 0.0], [0.0, 1.0, 0.0])
    r_quarter, v_quarter = kepler_state(circular, π / 2)
    @test r_quarter ≈ SVector(0.0, 1.0, 0.0) atol=2e-12 rtol=2e-12
    @test v_quarter ≈ SVector(-1.0, 0.0, 0.0) atol=2e-12 rtol=2e-12
    @test kepler_specific_energy(μ, r_quarter, v_quarter) ≈ -0.5 atol=2e-13
    @test kepler_angular_momentum(r_quarter, v_quarter) ≈ SVector(0.0, 0.0, 1.0) atol=2e-13

    eccentricity = 0.5
    semimajor_axis = 2.0
    periapsis = semimajor_axis * (1 - eccentricity)
    periapsis_speed = sqrt(μ * (1 + eccentricity) /
                            (semimajor_axis * (1 - eccentricity)))
    ellipse = KeplerReference(μ, [periapsis, 0.0, 0.0],
                              [0.0, periapsis_speed, 0.0])
    orbital_period = 2π * sqrt(semimajor_axis^3 / μ)
    r_period, v_period = kepler_state(ellipse, orbital_period)
    @test r_period ≈ ellipse.r0 atol=2e-11 rtol=2e-11
    @test v_period ≈ ellipse.v0 atol=2e-11 rtol=2e-11

    near_parabolic = KeplerReference(
        μ, [1.0, 0.0, 0.0], [0.0, sqrt(2.0) * (1 - 1e-8), 0.0]
    )
    rp, vp = kepler_state(near_parabolic, 0.2)
    @test kepler_specific_energy(μ, rp, vp) ≈
          kepler_specific_energy(μ, near_parabolic.r0, near_parabolic.v0) atol=2e-12
    @test kepler_angular_momentum(rp, vp) ≈
          kepler_angular_momentum(near_parabolic.r0, near_parabolic.v0) atol=2e-12

    hyperbolic = KeplerReference(μ, [1.0, 0.0, 0.0], [0.0, 2.0, 0.0])
    rh, vh = kepler_state(hyperbolic, 0.3)
    @test kepler_specific_energy(μ, rh, vh) > 0
    @test kepler_specific_energy(μ, rh, vh) ≈
          kepler_specific_energy(μ, hyperbolic.r0, hyperbolic.v0) atol=2e-12
    @test kepler_angular_momentum(rh, vh) ≈
          kepler_angular_momentum(hyperbolic.r0, hyperbolic.v0) atol=2e-12

    radial_position = SVector(2.0, 0.0, 0.0)
    collision_time = radial_free_fall_time(μ, norm(radial_position))
    comparison_time = collision_time / 2
    radial_reference = KeplerReference(μ, radial_position, zeros(3))
    r_universal, v_universal = kepler_state(radial_reference, comparison_time)
    r_exact, v_exact = radial_free_fall_state(μ, radial_position, comparison_time)
    @test r_universal ≈ r_exact atol=3e-12 rtol=3e-12
    @test v_universal ≈ v_exact atol=3e-12 rtol=3e-12
    @test radial_free_fall_state(μ, radial_position, 0.0) ==
          (radial_position, zero(radial_position))

    setprecision(BigFloat, 256) do
        big_circular = KeplerReference(
            big"1.0",
            BigFloat[big"1.0", big"0.0", big"0.0"],
            BigFloat[big"0.0", big"1.0", big"0.0"],
        )
        rb, vb = kepler_state(big_circular, BigFloat(pi) / 2; tolerance=big"1e-70")
        tolerance = big"1e-60"
        @test norm(rb - SVector(big"0.0", big"1.0", big"0.0")) < tolerance
        @test norm(vb - SVector(big"-1.0", big"0.0", big"0.0")) < tolerance
        @test abs(kepler_specific_energy(big"1.0", rb, vb) + big"0.5") < tolerance
    end

    @test_throws ArgumentError KeplerReference(0.0, [1.0, 0.0, 0.0], zeros(3))
    @test_throws ArgumentError KeplerReference(1.0, zeros(3), zeros(3))
    @test_throws ArgumentError kepler_state(circular, 1.0; tolerance=0.0)
    @test_throws ArgumentError radial_free_fall_time(1.0, 0.0)
    @test_throws ArgumentError radial_free_fall_state(1.0, radial_position, collision_time)
end

@testset "Planar Levi-Civita coordinate maps" begin
    u = SVector(1.2, -0.7)
    udot = SVector(0.3, 0.4)
    coordinates = LeviCivitaCoordinates(u, udot)
    q, qdot = from_levi_civita(coordinates)

    @test q ≈ SVector(0.95, -1.68) atol=8eps(Float64) rtol=8eps(Float64)
    @test qdot ≈ SVector(1.28, 0.54) atol=8eps(Float64) rtol=8eps(Float64)
    @test levi_civita_position(-u) == q
    @test levi_civita_velocity(-u, -udot) == qdot

    for branch in (-1, 1)
        recovered = to_levi_civita(q, qdot; branch=branch)
        qr, qdotr = from_levi_civita(recovered)
        @test qr ≈ q atol=16eps(Float64) rtol=16eps(Float64)
        @test qdotr ≈ qdot atol=16eps(Float64) rtol=16eps(Float64)
        @test sign(recovered.u[1] == 0 ? recovered.u[2] : recovered.u[1]) == branch *
              sign(to_levi_civita(q, qdot; branch=1).u[1] == 0 ?
                   to_levi_civita(q, qdot; branch=1).u[2] :
                   to_levi_civita(q, qdot; branch=1).u[1])
    end

    positive = to_levi_civita(q, qdot; branch=1)
    negative = to_levi_civita(q, qdot; branch=-1)
    @test negative.u == -positive.u
    @test negative.udot == -positive.udot

    quadrant_cases = (
        (SVector(2.0, 1.0), SVector(-0.2, 0.5)),
        (SVector(-2.0, 1.0), SVector(0.7, -0.4)),
        (SVector(-2.0, -1.0), SVector(-0.6, -0.3)),
        (SVector(2.0, -1.0), SVector(0.1, 0.9)),
        (SVector(-2.0, 0.0), SVector(0.4, -0.8)),
    )
    for (position, velocity_value) in quadrant_cases
        lc = to_levi_civita(position, velocity_value)
        reconstructed_position, reconstructed_velocity = from_levi_civita(lc)
        @test reconstructed_position ≈ position atol=16eps(Float64) rtol=16eps(Float64)
        @test reconstructed_velocity ≈ velocity_value atol=16eps(Float64) rtol=16eps(Float64)
    end

    collision = LeviCivitaCoordinates(zeros(2), [3.0, -4.0])
    collision_position, collision_velocity = from_levi_civita(collision)
    @test iszero(collision_position)
    @test iszero(collision_velocity)
    @test_throws DomainError to_levi_civita(zeros(2), zeros(2))

    setprecision(BigFloat, 256) do
        qb = SVector(big"-1.75", big"0.625")
        qdotb = SVector(big"0.125", big"-0.875")
        lcb = to_levi_civita(qb, qdotb; branch=-1)
        rb, vb = from_levi_civita(lcb)
        tolerance = big"1e-70"
        @test eltype(lcb.u) === BigFloat
        @test norm(rb - qb) < tolerance
        @test norm(vb - qdotb) < tolerance
    end

    @test_throws ArgumentError LeviCivitaCoordinates([1.0], [0.0, 0.0])
    @test_throws ArgumentError levi_civita_position([1.0])
    @test_throws ArgumentError levi_civita_velocity([1.0, 0.0], [1.0])
    @test_throws ArgumentError to_levi_civita([1.0, 0.0], [0.0, 0.0]; branch=0)
    @test_throws ArgumentError to_levi_civita([Inf, 0.0], [0.0, 0.0])
end
