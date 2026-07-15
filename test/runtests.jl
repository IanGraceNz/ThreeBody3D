using Test
using LinearAlgebra
using Logging
using StaticArrays
using SciMLBase
import OrdinaryDiffEq
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

@testset "Isolated Levi-Civita oscillator in fixed fictitious time" begin
    circular = LeviCivitaOscillator(1.0, [1.0, 0.0], [0.0, 1.0])
    @test circular.specific_energy ≈ -0.5
    @test circular.u0 ≈ SVector(1.0, 0.0)
    @test circular.uprime0 ≈ SVector(0.0, 0.5)

    u_exact, w_exact = levi_civita_fictitious_state(circular, π)
    @test u_exact ≈ SVector(0.0, 1.0) atol=2e-15
    @test w_exact ≈ SVector(-0.5, 0.0) atol=2e-15
    q_exact, v_exact = levi_civita_cartesian_state(circular, π)
    @test q_exact ≈ SVector(-1.0, 0.0) atol=4e-15
    @test v_exact ≈ SVector(0.0, -1.0) atol=4e-15

    result = integrate_levi_civita_fictitious(
        circular, (0.0, π); saveat=π / 16, reltol=1e-13, abstol=1e-13,
    )
    u_num, w_num = levi_civita_fictitious_state(result, π)
    @test u_num ≈ u_exact atol=2e-12 rtol=2e-12
    @test w_num ≈ w_exact atol=2e-12 rtol=2e-12
    @test length(result.solution.t) == 17

    # Gauge-related initial states remain negatives of one another in
    # regularized space and reconstruct the same Cartesian state.
    circular_negative = LeviCivitaOscillator(
        1.0, [1.0, 0.0], [0.0, 1.0]; branch=-1,
    )
    un, wn = levi_civita_fictitious_state(circular_negative, π / 3)
    up, wp = levi_civita_fictitious_state(circular, π / 3)
    @test un ≈ -up atol=8eps(Float64)
    @test wn ≈ -wp atol=8eps(Float64)
    @test levi_civita_position(un) ≈ levi_civita_position(up) atol=8eps(Float64)

    # Positive-energy state exercises the hyperbolic exact branch.
    hyperbolic = LeviCivitaOscillator(1.0, [1.0, 0.0], [0.0, 2.0])
    @test hyperbolic.specific_energy > 0
    hyper_result = integrate_levi_civita_fictitious(
        hyperbolic, (0.0, 0.5); reltol=1e-13, abstol=1e-13,
    )
    uh_exact, wh_exact = levi_civita_fictitious_state(hyperbolic, 0.5)
    uh_num, wh_num = levi_civita_fictitious_state(hyper_result, 0.5)
    @test uh_num ≈ uh_exact atol=3e-12 rtol=3e-12
    @test wh_num ≈ wh_exact atol=3e-12 rtol=3e-12

    # A radial fall passes through u = 0 at finite fictitious time. The
    # regularized solution remains finite on both sides of the collision.
    radial = LeviCivitaOscillator(1.0, [2.0, 0.0], [0.0, 0.0])
    collision_s = π
    ur, wr = levi_civita_fictitious_state(radial, collision_s)
    @test norm(ur) < 5e-15
    @test all(isfinite, wr)
    radial_result = integrate_levi_civita_fictitious(
        radial, (0.0, 3π / 2); saveat=[collision_s, 3π / 2],
        reltol=1e-13, abstol=1e-13,
    )
    ur_num, wr_num = levi_civita_fictitious_state(radial_result, collision_s)
    @test norm(ur_num) < 3e-12
    @test all(isfinite, wr_num)
    u_after, w_after = levi_civita_fictitious_state(radial_result, 3π / 2)
    @test all(isfinite, u_after)
    @test all(isfinite, w_after)

    # Floating-point evaluation at the analytic collision time is generally
    # only numerically close to u = 0, because π and the trigonometric values
    # are not represented exactly. Verify that the propagated state reaches
    # collision to roundoff without imposing an arbitrary snapping threshold.
    @test norm(ur) ≤ 100eps(Float64)
    @test isfinite(norm(wr))

    # Cartesian velocity reconstruction is singular only at an exact binary
    # collision. Construct that state explicitly so the DomainError test does
    # not depend on floating-point evaluation of the analytic collision time.
    exact_collision = LeviCivitaOscillator{Float64}(
        1.0, radial.specific_energy, SVector(0.0, 0.0), wr, 1,
    )
    @test_throws DomainError levi_civita_cartesian_state(exact_collision, 0.0)

    setprecision(BigFloat, 256) do
        big_circular = LeviCivitaOscillator(
            big"1.0", BigFloat[big"1.0", big"0.0"],
            BigFloat[big"0.0", big"1.0"],
        )
        sb = BigFloat(pi) / 3
        big_result = integrate_levi_civita_fictitious(
            big_circular, (big"0.0", sb);
            reltol=big"1e-40", abstol=big"1e-40",
        )
        ub_exact, wb_exact = levi_civita_fictitious_state(big_circular, sb)
        ub_num, wb_num = levi_civita_fictitious_state(big_result, sb)
        @test norm(ub_num - ub_exact) < big"1e-35"
        @test norm(wb_num - wb_exact) < big"1e-35"
    end

    @test_throws ArgumentError LeviCivitaOscillator(0.0, [1.0, 0.0], [0.0, 1.0])
    @test_throws ArgumentError integrate_levi_civita_fictitious(circular, (0.0, 0.0))
    @test_throws ArgumentError integrate_levi_civita_fictitious(circular, (0.0, 1.0); reltol=0.0)
end

@testset "Levi-Civita Sundman physical-time reconstruction" begin
    circular = LeviCivitaOscillator(1.0, [1.0, 0.0], [0.0, 1.0])
    @test levi_civita_physical_time(circular, 0.0) == 0.0
    @test levi_civita_physical_time(circular, π / 2) ≈ π / 2 atol=4e-15
    @test levi_civita_physical_time(circular, -π / 2) ≈ -π / 2 atol=4e-15
    @test levi_civita_physical_time(circular, π / 2; initial_time=3.0) ≈ 3.0 + π / 2 atol=4e-15

    result = integrate_levi_civita_sundman(
        circular, (0.0, π); saveat=π / 32, reltol=1e-13, abstol=1e-13,
    )
    @test length(result.solution.t) == 33
    for s in range(0.0, π; length=17)
        u_num, w_num, t_num = levi_civita_sundman_state(result, s)
        u_exact, w_exact = levi_civita_fictitious_state(circular, s)
        t_exact = levi_civita_physical_time(circular, s)
        @test u_num ≈ u_exact atol=3e-12 rtol=3e-12
        @test w_num ≈ w_exact atol=3e-12 rtol=3e-12
        @test t_num ≈ t_exact atol=3e-12 rtol=3e-12
    end

    sampled_times = [levi_civita_sundman_state(result, s)[3] for s in range(0.0, π; length=65)]
    @test all(diff(sampled_times) .>= -32eps(Float64))
    @test sampled_times[end] > sampled_times[1]

    # Circular motion: matched physical time agrees with the independent
    # universal-variable Kepler reference.
    s_match = π / 2
    t_match = levi_civita_physical_time(circular, s_match)
    q_lc, v_lc = levi_civita_cartesian_state(result, s_match)
    reference = KeplerReference(1.0, [1.0, 0.0, 0.0], [0.0, 1.0, 0.0])
    r_kepler, v_kepler = kepler_state(reference, t_match)
    @test q_lc ≈ r_kepler[1:2] atol=5e-12 rtol=5e-12
    @test v_lc ≈ v_kepler[1:2] atol=5e-12 rtol=5e-12

    # Eccentric motion exercises a non-constant Sundman rate.
    eccentric = LeviCivitaOscillator(1.0, [1.0, 0.0], [0.0, 0.5])
    s_ecc = 0.8
    eccentric_result = integrate_levi_civita_sundman(
        eccentric, (0.0, s_ecc); reltol=1e-13, abstol=1e-13,
    )
    _, _, t_ecc_num = levi_civita_sundman_state(eccentric_result, s_ecc)
    t_ecc_exact = levi_civita_physical_time(eccentric, s_ecc)
    @test t_ecc_num ≈ t_ecc_exact atol=4e-12 rtol=4e-12
    q_ecc, v_ecc = levi_civita_cartesian_state(eccentric_result, s_ecc)
    eccentric_reference = KeplerReference(
        1.0, [1.0, 0.0, 0.0], [0.0, 0.5, 0.0],
    )
    r_ecc, v_ecc_reference = kepler_state(eccentric_reference, t_ecc_exact)
    @test q_ecc ≈ r_ecc[1:2] atol=8e-12 rtol=8e-12
    @test v_ecc ≈ v_ecc_reference[1:2] atol=8e-12 rtol=8e-12

    # Physical time remains monotone through a regularized radial collision;
    # its derivative reaches zero at collision but never becomes negative.
    radial = LeviCivitaOscillator(1.0, [2.0, 0.0], [0.0, 0.0])
    radial_result = integrate_levi_civita_sundman(
        radial, (0.0, 3π / 2); saveat=range(0.0, 3π / 2; length=97),
        reltol=1e-13, abstol=1e-13,
    )
    radial_times = [state[5] for state in radial_result.solution.u]
    @test all(diff(radial_times) .>= -64eps(Float64))
    @test levi_civita_physical_time(radial, π) ≈ radial_free_fall_time(1.0, 2.0) atol=8e-14
    _, _, collision_time_num = levi_civita_sundman_state(radial_result, π)
    @test collision_time_num ≈ radial_free_fall_time(1.0, 2.0) atol=5e-12 rtol=5e-12

    setprecision(BigFloat, 256) do
        big_eccentric = LeviCivitaOscillator(
            big"1.0", BigFloat[big"1.0", big"0.0"],
            BigFloat[big"0.0", big"0.5"],
        )
        sb = big"0.75"
        big_result = integrate_levi_civita_sundman(
            big_eccentric, (big"0.0", sb);
            reltol=big"1e-40", abstol=big"1e-40",
        )
        _, _, tb_num = levi_civita_sundman_state(big_result, sb)
        tb_exact = levi_civita_physical_time(big_eccentric, sb)
        @test abs(tb_num - tb_exact) < big"1e-35"
    end

    @test_throws ArgumentError integrate_levi_civita_sundman(circular, (0.1, 1.0))
    @test_throws ArgumentError integrate_levi_civita_sundman(circular, (0.0, 0.0))
    @test_throws ArgumentError integrate_levi_civita_sundman(circular, (0.0, 1.0); initial_time=Inf)
    @test_throws ArgumentError levi_civita_physical_time(circular, Inf)
end

@testset "Levi-Civita bounded physical-time targeting" begin
    circular = LeviCivitaOscillator(1.0, [1.0, 0.0], [0.0, 1.0])
    for target in (0.0, π / 4, π, -π / 3, 8π)
        s = levi_civita_fictitious_time(circular, target)
        @test s ≈ target atol=2e-13 rtol=2e-13
        @test levi_civita_physical_time(circular, s) ≈ target atol=3e-13 rtol=3e-13
    end

    state = levi_civita_state_at_time(circular, π / 2)
    @test state.physical_time == π / 2
    @test state.fictitious_time ≈ π / 2 atol=2e-13
    @test state.position ≈ SVector(0.0, 1.0) atol=5e-13
    @test state.velocity ≈ SVector(-1.0, 0.0) atol=5e-13

    eccentric = LeviCivitaOscillator(1.0, [1.0, 0.0], [0.0, 0.5])
    eccentric_reference = KeplerReference(
        1.0, [1.0, 0.0, 0.0], [0.0, 0.5, 0.0],
    )
    for target in (0.1, 0.5, 1.0, -0.4)
        targeted = levi_civita_state_at_time(eccentric, target)
        @test levi_civita_physical_time(eccentric, targeted.fictitious_time) ≈ target atol=8e-13 rtol=8e-13
        r_ref, v_ref = kepler_state(eccentric_reference, target)
        @test targeted.position ≈ r_ref[1:2] atol=2e-11 rtol=2e-11
        @test targeted.velocity ≈ v_ref[1:2] atol=2e-11 rtol=2e-11
    end

    # The inverse remains well defined at and beyond a radial collision, even
    # though Cartesian velocity reconstruction is singular at exact collision.
    radial = LeviCivitaOscillator(1.0, [2.0, 0.0], [0.0, 0.0])
    collision_time = radial_free_fall_time(1.0, 2.0)
    collision_s = levi_civita_fictitious_time(radial, collision_time)
    collision_u, collision_w = levi_civita_fictitious_state(radial, collision_s)
    # At collision dt/ds = |u|² vanishes, so inversion of t(s) is locally
    # ill-conditioned: a machine-precision physical-time residual does not
    # imply machine-precision fictitious time. Validate the physical target
    # and proximity to the regularized collision instead of π itself.
    @test levi_civita_physical_time(radial, collision_s) ≈ collision_time atol=2e-13 rtol=2e-13
    @test norm(collision_u) ≤ 5e-5
    @test all(isfinite, collision_w)
    after_s = levi_civita_fictitious_time(radial, collision_time + 0.25)
    @test after_s > collision_s
    @test levi_civita_physical_time(radial, after_s) ≈ collision_time + 0.25 atol=3e-13 rtol=3e-13

    setprecision(BigFloat, 256) do
        big_eccentric = LeviCivitaOscillator(
            big"1.0", BigFloat[big"1.0", big"0.0"],
            BigFloat[big"0.0", big"0.5"],
        )
        target = big"0.75"
        s = levi_civita_fictitious_time(
            big_eccentric, target; tolerance=big"1e-60",
        )
        @test abs(levi_civita_physical_time(big_eccentric, s) - target) < big"1e-58"
        targeted = levi_civita_state_at_time(
            big_eccentric, target; tolerance=big"1e-60",
        )
        reference = KeplerReference(
            big"1.0",
            BigFloat[big"1.0", big"0.0", big"0.0"],
            BigFloat[big"0.0", big"0.5", big"0.0"],
        )
        r_ref, v_ref = kepler_state(reference, target; tolerance=big"1e-65")
        @test norm(targeted.position - r_ref[1:2]) < big"1e-55"
        @test norm(targeted.velocity - v_ref[1:2]) < big"1e-55"
    end

    @test_throws ArgumentError levi_civita_fictitious_time(circular, Inf)
    @test_throws ArgumentError levi_civita_fictitious_time(circular, 1.0; initial_step=0.0)
    @test_throws ArgumentError levi_civita_fictitious_time(circular, 1.0; tolerance=0.0)
    @test_throws ArgumentError levi_civita_fictitious_time(circular, 1.0; max_iterations=0)
end

@testset "Perturbed planar Levi-Civita binary" begin
    system = ThreeBodySystem((1.0, 1.0, 0.01))
    relative_speed = sqrt(2.0)
    u0 = statevector(
        [0.5, 0.0, 0.0], [0.0, relative_speed / 2, 0.0],
        [-0.5, 0.0, 0.0], [0.0, -relative_speed / 2, 0.0],
        [8.0, 0.5, 0.0], [0.0, 0.35, 0.0],
    )

    problem = PerturbedLeviCivitaProblem(system, u0, (1, 2))
    @test problem.pair == (1, 2)
    @test problem.third == 3
    @test problem.initial_time == 0.0

    # Initial reconstruction is algebraically identical to the Cartesian state.
    result = integrate_perturbed_levi_civita(
        problem, (0.0, 0.15); reltol=1e-13, abstol=1e-13,
    )
    initial = perturbed_levi_civita_state(result, 0.0)
    @test initial.physical_time == 0.0
    @test initial.physical_state ≈ u0 atol=2e-14 rtol=2e-14

    # Compare the regularized integration with the independent Cartesian
    # three-body integrator at the same reconstructed physical time.
    final = perturbed_levi_civita_state(result, 0.15)
    @test final.physical_time > 0.0
    cartesian = simulate(
        system, u0, (0.0, final.physical_time);
        solver=:accurate, reltol=1e-13, abstol=1e-13,
    )
    cartesian_final = cartesian.solution(final.physical_time)
    @test final.physical_state ≈ cartesian_final atol=3e-10 rtol=3e-10

    # The evolved energy variable agrees with the selected binary's physical
    # osculating Kepler energy reconstructed from the regularized state.
    pair_final = to_pair_coordinates(system, final.physical_state, (1, 2))
    q = pair_final.relative_position
    qdot = pair_final.relative_velocity
    μ = system.G * (system.masses[1] + system.masses[2])
    physical_binary_energy = dot(qdot, qdot) / 2 - μ / norm(q)
    @test final.binary_specific_energy ≈ physical_binary_energy atol=2e-10 rtol=2e-10

    # Reversing the ordered pair changes the regularized orientation but not
    # the reconstructed initial physical state.
    reverse_problem = PerturbedLeviCivitaProblem(system, u0, (2, 1); branch=-1)
    reverse_result = integrate_perturbed_levi_civita(
        reverse_problem, (0.0, 0.05); reltol=1e-13, abstol=1e-13,
    )
    @test perturbed_levi_civita_state(reverse_result, 0.0).physical_state ≈
          u0 atol=2e-14 rtol=2e-14

    # The regularized right-hand side remains finite at a selected binary
    # collision when the third body is distinct from the binary centre.
    collision_state = SVector{14,Float64}(
        0.0, 0.0, 0.4, 0.0,
        0.0, 0.0, 0.0, 0.0,
        8.0, 0.5, 0.0, 0.35,
        -1.0, 0.0,
    )
    collision_derivative = ThreeBody3D._perturbed_lc_rhs(collision_state, problem, 0.0)
    @test all(isfinite, collision_derivative)
    @test collision_derivative[14] == 0.0

    setprecision(BigFloat, 256) do
        big_system = ThreeBodySystem(
            (big"1.0", big"1.0", big"0.01"); G=big"1.0",
        )
        big_relative_speed = sqrt(big"2.0")
        big_u0 = statevector(
            BigFloat[big"0.5", big"0.0", big"0.0"],
            BigFloat[big"0.0", big_relative_speed / 2, big"0.0"],
            BigFloat[big"-0.5", big"0.0", big"0.0"],
            BigFloat[big"0.0", -big_relative_speed / 2, big"0.0"],
            BigFloat[big"8.0", big"0.5", big"0.0"],
            BigFloat[big"0.0", big"0.35", big"0.0"],
        )
        big_problem = PerturbedLeviCivitaProblem(big_system, big_u0, (1, 2))
        big_result = integrate_perturbed_levi_civita(
            big_problem, (big"0.0", big"0.03");
            reltol=big"1e-35", abstol=big"1e-35",
        )
        big_final = perturbed_levi_civita_state(big_result, big"0.03")
        @test eltype(big_final.physical_state) === BigFloat
        @test big_final.physical_time > zero(BigFloat)
        @test all(isfinite, big_final.physical_state)
    end

    nonplanar = copy(u0)
    nonplanar[3] = 1e-3
    @test_throws ArgumentError PerturbedLeviCivitaProblem(system, nonplanar, (1, 2))
    @test_throws ArgumentError PerturbedLeviCivitaProblem(system, u0, (1, 1))
    @test_throws ArgumentError PerturbedLeviCivitaProblem(system, u0, (1, 2); branch=0)
    @test_throws ArgumentError integrate_perturbed_levi_civita(problem, (0.1, 0.2))
    @test_throws ArgumentError integrate_perturbed_levi_civita(problem, (0.0, 0.0))
end

@testset "Perturbed Levi-Civita physical-time targeting" begin
    system = ThreeBodySystem((1.0, 1.0, 0.01))
    relative_speed = sqrt(2.0)
    u0 = statevector(
        [0.5, 0.0, 0.0], [0.0, relative_speed / 2, 0.0],
        [-0.5, 0.0, 0.0], [0.0, -relative_speed / 2, 0.0],
        [8.0, 0.5, 0.0], [0.0, 0.35, 0.0],
    )
    problem = PerturbedLeviCivitaProblem(system, u0, (1, 2))

    initial = perturbed_levi_civita_state_at_time(
        problem, 0.0; reltol=1e-13, abstol=1e-13,
    )
    @test initial.fictitious_time == 0.0
    @test initial.physical_time == 0.0
    @test initial.physical_state ≈ u0 atol=2e-14 rtol=2e-14

    for target in (0.1, 0.5)
        targeted = perturbed_levi_civita_state_at_time(
            problem, target;
            initial_step=0.5, tolerance=1e-11,
            reltol=1e-13, abstol=1e-13,
        )
        @test targeted.physical_time ≈ target atol=2e-11 rtol=2e-11
        @test targeted.fictitious_time > 0.0
        cartesian = simulate(
            system, u0, (0.0, target);
            solver=:accurate, reltol=1e-13, abstol=1e-13,
        )
        @test targeted.physical_state ≈ cartesian.solution(target) atol=5e-10 rtol=5e-10
    end

    backward = perturbed_levi_civita_state_at_time(
        problem, -0.1;
        initial_step=0.2, tolerance=1e-11,
        reltol=1e-13, abstol=1e-13,
    )
    @test backward.physical_time ≈ -0.1 atol=2e-11 rtol=2e-11
    @test backward.fictitious_time < 0.0
    # The production Cartesian solver intentionally accepts only increasing
    # physical-time spans. Validate the backward regularized target by
    # integrating its reconstructed physical state forward from -0.1 to 0.0.
    backward_cartesian = simulate(
        system, backward.physical_state, (-0.1, 0.0);
        solver=:accurate, reltol=1e-13, abstol=1e-13,
    )
    @test backward_cartesian.solution(0.0) ≈ u0 atol=5e-10 rtol=5e-10

    reverse_problem = PerturbedLeviCivitaProblem(system, u0, (2, 1); branch=-1)
    reverse_target = perturbed_levi_civita_state_at_time(
        reverse_problem, 0.1;
        initial_step=0.2, tolerance=1e-11,
        reltol=1e-13, abstol=1e-13,
    )
    forward_target = perturbed_levi_civita_state_at_time(
        problem, 0.1;
        initial_step=0.2, tolerance=1e-11,
        reltol=1e-13, abstol=1e-13,
    )
    @test reverse_target.physical_state ≈ forward_target.physical_state atol=5e-10 rtol=5e-10

    setprecision(BigFloat, 256) do
        big_system = ThreeBodySystem(
            (big"1.0", big"1.0", big"0.01"); G=big"1.0",
        )
        big_relative_speed = sqrt(big"2.0")
        big_u0 = statevector(
            BigFloat[big"0.5", big"0.0", big"0.0"],
            BigFloat[big"0.0", big_relative_speed / 2, big"0.0"],
            BigFloat[big"-0.5", big"0.0", big"0.0"],
            BigFloat[big"0.0", -big_relative_speed / 2, big"0.0"],
            BigFloat[big"8.0", big"0.5", big"0.0"],
            BigFloat[big"0.0", big"0.35", big"0.0"],
        )
        big_problem = PerturbedLeviCivitaProblem(big_system, big_u0, (1, 2))
        target = big"0.03"
        big_targeted = perturbed_levi_civita_state_at_time(
            big_problem, target;
            initial_step=big"0.05", tolerance=big"1e-28",
            reltol=big"1e-35", abstol=big"1e-35",
        )
        @test eltype(big_targeted.physical_state) === BigFloat
        @test abs(big_targeted.physical_time - target) < big"1e-27"
        @test all(isfinite, big_targeted.physical_state)
    end

    @test_throws ArgumentError perturbed_levi_civita_fictitious_time(problem, Inf)
    @test_throws ArgumentError perturbed_levi_civita_fictitious_time(problem, 0.1; initial_step=0.0)
    @test_throws ArgumentError perturbed_levi_civita_fictitious_time(problem, 0.1; tolerance=0.0)
    @test_throws ArgumentError perturbed_levi_civita_fictitious_time(problem, 0.1; max_iterations=0)
end

@testset "Explicit regularized segment handoff" begin
    system = ThreeBodySystem((1.0, 1.0, 0.01))
    relative_speed = sqrt(2.0)
    u0 = statevector(
        [0.5, 0.0, 0.0], [0.0, relative_speed / 2, 0.0],
        [-0.5, 0.0, 0.0], [0.0, -relative_speed / 2, 0.0],
        [8.0, 0.5, 0.0], [0.0, 0.35, 0.0],
    )

    segment = propagate_regularized_segment(
        system, u0, (1, 2), 0.0, 0.5;
        initial_step=0.5, tolerance=1e-11,
        reltol=1e-13, abstol=1e-13,
    )
    @test segment.pair == (1, 2)
    @test segment.entry_time == 0.0
    @test segment.exit_time == 0.5
    @test segment.exit_fictitious_time > 0.0
    @test segment.entry_state ≈ u0 atol=0 rtol=0

    for diagnostics in (segment.entry_diagnostics, segment.exit_diagnostics)
        @test diagnostics.state_residual ≤ 5e-15
        @test diagnostics.position_residual ≤ 5e-15
        @test diagnostics.velocity_residual ≤ 5e-15
        @test diagnostics.energy_jump ≤ 5e-14
        @test diagnostics.momentum_jump ≤ 5e-14
        @test diagnostics.angular_momentum_jump ≤ 5e-14
        @test diagnostics.center_of_mass_jump ≤ 5e-15
        @test diagnostics.center_of_mass_velocity_jump ≤ 5e-15
    end

    cartesian = simulate(
        system, u0, (0.0, 0.5);
        solver=:accurate, reltol=1e-13, abstol=1e-13,
    )
    @test segment.exit_state ≈ cartesian.solution(0.5) atol=6e-10 rtol=6e-10

    # Dense-output targeting is independent of the stored save grid.
    sparse = propagate_regularized_segment(
        system, u0, (1, 2), 0.0, 0.5;
        initial_step=0.5, tolerance=1e-11,
        reltol=1e-13, abstol=1e-13, saveat=0.2,
    )
    dense = propagate_regularized_segment(
        system, u0, (1, 2), 0.0, 0.5;
        initial_step=0.5, tolerance=1e-11,
        reltol=1e-13, abstol=1e-13, saveat=0.01,
    )
    @test sparse.exit_state ≈ dense.exit_state atol=2e-11 rtol=2e-11
    @test sparse.exit_fictitious_time ≈ dense.exit_fictitious_time atol=2e-11 rtol=2e-11

    reverse = propagate_regularized_segment(
        system, u0, (2, 1), 0.0, 0.5;
        branch=-1, initial_step=0.5, tolerance=1e-11,
        reltol=1e-13, abstol=1e-13,
    )
    @test reverse.exit_state ≈ segment.exit_state atol=8e-10 rtol=8e-10

    # A regularized segment can begin at a nonzero physical epoch.
    entry_at_one = simulate(
        system, u0, (0.0, 0.1);
        solver=:accurate, reltol=1e-13, abstol=1e-13,
    ).solution(0.1)
    shifted = propagate_regularized_segment(
        system, entry_at_one, (1, 2), 0.1, 0.2;
        initial_step=0.2, tolerance=1e-11,
        reltol=1e-13, abstol=1e-13,
    )
    reference_shifted = simulate(
        system, entry_at_one, (0.1, 0.2);
        solver=:accurate, reltol=1e-13, abstol=1e-13,
    )
    @test shifted.exit_state ≈ reference_shifted.solution(0.2) atol=5e-10 rtol=5e-10

    setprecision(BigFloat, 256) do
        big_system = ThreeBodySystem(
            (big"1.0", big"1.0", big"0.01"); G=big"1.0",
        )
        big_relative_speed = sqrt(big"2.0")
        big_u0 = statevector(
            BigFloat[big"0.5", big"0.0", big"0.0"],
            BigFloat[big"0.0", big_relative_speed / 2, big"0.0"],
            BigFloat[big"-0.5", big"0.0", big"0.0"],
            BigFloat[big"0.0", -big_relative_speed / 2, big"0.0"],
            BigFloat[big"8.0", big"0.5", big"0.0"],
            BigFloat[big"0.0", big"0.35", big"0.0"],
        )
        big_segment = propagate_regularized_segment(
            big_system, big_u0, (1, 2), big"0.0", big"0.03";
            initial_step=big"0.05", tolerance=big"1e-28",
            reltol=big"1e-35", abstol=big"1e-35",
        )
        @test eltype(big_segment.exit_state) === BigFloat
        @test big_segment.entry_diagnostics.state_residual < big"1e-70"
        @test big_segment.exit_diagnostics.state_residual < big"1e-70"
        @test big_segment.entry_diagnostics.energy_jump < big"1e-65"
        @test big_segment.exit_diagnostics.energy_jump < big"1e-65"
    end

    @test_throws ArgumentError propagate_regularized_segment(system, u0, (1, 1), 0.0, 0.5)
    @test_throws ArgumentError propagate_regularized_segment(system, u0, (1, 2), 0.0, 0.0)
    @test_throws ArgumentError propagate_regularized_segment(system, u0, (1, 2), NaN, 0.5)
end

@testset "Manual multi-segment regularized composition" begin
    system = ThreeBodySystem((1.0, 1.0, 0.01))
    relative_speed = sqrt(2.0)
    u0 = statevector(
        [0.5, 0.0, 0.0], [0.0, relative_speed / 2, 0.0],
        [-0.5, 0.0, 0.0], [0.0, -relative_speed / 2, 0.0],
        [8.0, 0.5, 0.0], [0.0, 0.35, 0.0],
    )

    composed = compose_regularized_trajectory(
        system, u0, (0.0, 0.8), (1, 2), (0.2, 0.5);
        saveat=0.1,
        cartesian_reltol=1e-13,
        cartesian_abstol=1e-13,
        regularized_initial_step=0.4,
        regularized_tolerance=1e-11,
        regularized_reltol=1e-13,
        regularized_abstol=1e-13,
    )

    @test composed.pair == (1, 2)
    @test composed.tspan == (0.0, 0.8)
    @test composed.regularized_interval == (0.2, 0.5)
    @test first(composed.times) == 0.0
    @test last(composed.times) == 0.8
    @test length(composed.states) == length(composed.times)
    @test composed(0.2) ≈ composed.regularized_segment.entry_state atol=0 rtol=0
    @test composed(0.5) ≈ composed.regularized_segment.exit_state atol=0 rtol=0

    for diagnostics in (composed.entry_continuity, composed.exit_continuity)
        @test diagnostics.state_residual ≤ 5e-15
        @test diagnostics.position_residual ≤ 5e-15
        @test diagnostics.velocity_residual ≤ 5e-15
        @test diagnostics.energy_jump ≤ 5e-14
        @test diagnostics.momentum_jump ≤ 5e-14
        @test diagnostics.angular_momentum_jump ≤ 5e-14
        @test diagnostics.center_of_mass_jump ≤ 5e-15
        @test diagnostics.center_of_mass_velocity_jump ≤ 5e-15
    end

    @test length(composed.solver_statistics) == 3
    @test all(statistics -> statistics.saved_states ≥ 2, composed.solver_statistics)
    @test all(statistics -> statistics.accepted_steps > 0, composed.solver_statistics)
    @test all(statistics -> statistics.rhs_evaluations > 0, composed.solver_statistics)

    reference = simulate(
        system, u0, (0.0, 0.8);
        solver=:accurate, reltol=1e-13, abstol=1e-13,
    )
    for time in (0.1, 0.2, 0.35, 0.5, 0.7, 0.8)
        @test composed(time) ≈ reference.solution(time) atol=1.5e-9 rtol=1.5e-9
    end

    sparse = compose_regularized_trajectory(
        system, u0, (0.0, 0.8), (1, 2), (0.2, 0.5);
        saveat=0.2,
        cartesian_reltol=1e-13, cartesian_abstol=1e-13,
        regularized_initial_step=0.4, regularized_tolerance=1e-11,
        regularized_reltol=1e-13, regularized_abstol=1e-13,
    )
    dense = compose_regularized_trajectory(
        system, u0, (0.0, 0.8), (1, 2), (0.2, 0.5);
        saveat=0.02,
        cartesian_reltol=1e-13, cartesian_abstol=1e-13,
        regularized_initial_step=0.4, regularized_tolerance=1e-11,
        regularized_reltol=1e-13, regularized_abstol=1e-13,
    )
    @test sparse(0.2) ≈ dense(0.2) atol=2e-11 rtol=2e-11
    @test sparse(0.5) ≈ dense(0.5) atol=2e-11 rtol=2e-11
    @test sparse(0.8) ≈ dense(0.8) atol=2e-11 rtol=2e-11

    reversed = compose_regularized_trajectory(
        system, u0, (0.0, 0.8), (2, 1), (0.2, 0.5);
        branch=-1, saveat=0.1,
        cartesian_reltol=1e-13, cartesian_abstol=1e-13,
        regularized_initial_step=0.4, regularized_tolerance=1e-11,
        regularized_reltol=1e-13, regularized_abstol=1e-13,
    )
    @test reversed(0.8) ≈ composed(0.8) atol=2e-9 rtol=2e-9

    setprecision(BigFloat, 256) do
        big_system = ThreeBodySystem(
            (big"1.0", big"1.0", big"0.01"); G=big"1.0",
        )
        speed = sqrt(big"2.0")
        big_u0 = statevector(
            BigFloat[big"0.5", big"0.0", big"0.0"],
            BigFloat[big"0.0", speed / 2, big"0.0"],
            BigFloat[big"-0.5", big"0.0", big"0.0"],
            BigFloat[big"0.0", -speed / 2, big"0.0"],
            BigFloat[big"8.0", big"0.5", big"0.0"],
            BigFloat[big"0.0", big"0.35", big"0.0"],
        )
        big_composed = compose_regularized_trajectory(
            big_system, big_u0, (big"0.0", big"0.06"), (1, 2),
            (big"0.02", big"0.04");
            saveat=big"0.02",
            cartesian_solver=OrdinaryDiffEq.Vern9(),
            cartesian_reltol=big"1e-32", cartesian_abstol=big"1e-32",
            regularized_algorithm=OrdinaryDiffEq.Vern9(),
            regularized_initial_step=big"0.03",
            regularized_tolerance=big"1e-28",
            regularized_reltol=big"1e-32", regularized_abstol=big"1e-32",
        )
        @test eltype(big_composed.states[1]) === BigFloat
        @test big_composed.entry_continuity.state_residual < big"1e-70"
        @test big_composed.exit_continuity.state_residual < big"1e-70"
        @test all(isfinite, big_composed(big"0.03"))
    end

    @test_throws ArgumentError compose_regularized_trajectory(
        system, u0, (0.0, 0.8), (1, 2), (0.0, 0.5),
    )
    @test_throws ArgumentError compose_regularized_trajectory(
        system, u0, (0.0, 0.8), (1, 2), (0.5, 0.5),
    )
    @test_throws ArgumentError compose_regularized_trajectory(
        system, u0, (0.0, 0.8), (1, 1), (0.2, 0.5),
    )
    @test_throws ArgumentError composed_regularized_state(composed, -0.1)
    @test_throws ArgumentError composed_regularized_state(composed, 0.3; tolerance=0.0)
end
