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

    derived_targeting = compose_regularized_trajectory(
        system, u0, (0.0, 0.8), (1, 2), (0.2, 0.5);
        saveat=0.1,
        cartesian_reltol=1e-13,
        cartesian_abstol=1e-13,
        regularized_initial_step=0.4,
        regularized_reltol=1e-13,
        regularized_abstol=1e-13,
    )
    derived_segment = derived_targeting.regularized_segment
    derived_exit_time = derived_segment.regularized_result.solution(
        derived_segment.exit_fictitious_time,
    )[14]
    @test abs(derived_exit_time - derived_segment.exit_time) ≤ 5e-13
    @test isapprox(
        derived_segment.exit_state,
        composed.regularized_segment.exit_state;
        atol=5e-10,
        rtol=5e-10,
    )

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

@testset "Experimental automatic-switching foundations" begin
    cartesian_mode = CartesianSwitchingMode()
    @test cartesian_mode isa ExperimentalSwitchingMode

    regularized_mode = RegularizedSwitchingMode((2, 1))
    @test regularized_mode isa ExperimentalSwitchingMode
    @test regularized_mode.pair == (2, 1)
    @test_throws ArgumentError RegularizedSwitchingMode((1, 1))
    @test_throws ArgumentError RegularizedSwitchingMode((0, 2))

    parameters = AutomaticSwitchingParameters(
        enter_threshold=0.1,
        exit_threshold=0.2,
    )
    @test parameters.enter_threshold == 0.1
    @test parameters.exit_threshold == 0.2
    @test parameters.ambiguity_threshold == 0.2
    @test parameters.minimum_separation_ratio == 2.0
    @test parameters.maximum_switches == 100
    @test parameters.minimum_time_progress > 0

    promoted = AutomaticSwitchingParameters(
        enter_threshold=big"0.1",
        exit_threshold=big"0.2",
        ambiguity_threshold=big"0.15",
        minimum_separation_ratio=big"3.0",
        maximum_switches=8,
        minimum_time_progress=big"1e-30",
    )
    @test promoted isa AutomaticSwitchingParameters{BigFloat}
    @test promoted.maximum_switches == 8

    @test_throws ArgumentError AutomaticSwitchingParameters(
        enter_threshold=0.0, exit_threshold=0.2,
    )
    @test_throws ArgumentError AutomaticSwitchingParameters(
        enter_threshold=0.2, exit_threshold=0.2,
    )
    @test_throws ArgumentError AutomaticSwitchingParameters(
        enter_threshold=0.2, exit_threshold=0.1,
    )
    @test_throws ArgumentError AutomaticSwitchingParameters(
        enter_threshold=0.1, exit_threshold=0.2, ambiguity_threshold=0.05,
    )
    @test_throws ArgumentError AutomaticSwitchingParameters(
        enter_threshold=0.1, exit_threshold=0.2, minimum_separation_ratio=1.0,
    )
    @test_throws ArgumentError AutomaticSwitchingParameters(
        enter_threshold=0.1, exit_threshold=0.2, maximum_switches=0,
    )
    @test_throws ArgumentError AutomaticSwitchingParameters(
        enter_threshold=0.1, exit_threshold=0.2, minimum_time_progress=0.0,
    )

    failure = AutomaticSwitchingFailure(
        0.25,
        :insufficient_pair_isolation,
        "Two pairs are simultaneously close.";
        pair=(1, 3),
    )
    @test failure.physical_time == 0.25
    @test failure.reason == :insufficient_pair_isolation
    @test failure.pair == (1, 3)
    @test_throws ArgumentError AutomaticSwitchingFailure(
        0.0, :invalid, "";
    )
    @test_throws ArgumentError AutomaticSwitchingFailure(
        0.0, :invalid, "invalid pair"; pair=(2, 2),
    )

    system = ThreeBodySystem((1.0, 1.0, 1.0); G=1.0)
    state = statevector(
        [-1.0, 0.0, 0.0], [0.0, 0.1, 0.0],
        [1.0, 0.0, 0.0], [0.0, -0.1, 0.0],
        [0.0, 3.0, 0.0], [0.0, 0.0, 0.0],
    )
    diagnostics = ThreeBody3D._transition_diagnostics(
        system, state, copy(state), 0.0, (1, 2),
    )
    event = RegularizationSwitchEvent(
        0.0,
        :entry,
        (1, 2),
        (0.1, 2.0, 2.1),
        (-0.2, 0.1, 0.2),
        20.0,
        diagnostics,
    )
    @test event.kind == :entry
    @test event.pair == (1, 2)
    @test event.isolation_ratio == 20.0
    @test event.transition_diagnostics === diagnostics

    @test_throws ArgumentError RegularizationSwitchEvent(
        0.0, :unknown, (1, 2), (0.1, 2.0, 2.1), (-0.2, 0.1, 0.2), 20.0, diagnostics,
    )
    @test_throws ArgumentError RegularizationSwitchEvent(
        0.0, :entry, (1, 2), (0.0, 2.0, 2.1), (-0.2, 0.1, 0.2), 20.0, diagnostics,
    )
    @test_throws ArgumentError RegularizationSwitchEvent(
        0.0, :entry, (1, 2), (0.1, 2.0, 2.1), (-0.2, 0.1, 0.2), 0.5, diagnostics,
    )
end

@testset "Automatic switching pair observables" begin
    u = statevector(
        [0.0, 0.0, 0.0], [1.0, 0.0, 0.0],
        [3.0, 0.0, 0.0], [0.0, 0.0, 0.0],
        [0.0, 4.0, 0.0], [0.0, -2.0, 0.0],
    )
    observables = pair_observables(u)

    @test observables isa PairObservables{Float64}
    @test all(isapprox.(observables.separations, (3.0, 4.0, 5.0)))
    @test all(isapprox.(observables.radial_rates, (-1.0, -2.0, -1.6)))
    @test observables.collisions == (false, false, false)
    @test observables.order == (1, 2, 3)
    @test observables.closest_pair == (1, 2)
    @test observables.second_closest_pair == (1, 3)
    @test observables.isolation_ratio ≈ 4 / 3
    @test pair_separations(u) == observables.separations
    @test pair_radial_rates(u) == observables.radial_rates

    receding = statevector(
        [0.0, 0.0, 0.0], [-1.0, 0.0, 0.0],
        [3.0, 0.0, 0.0], [0.0, 0.0, 0.0],
        [0.0, 4.0, 0.0], [0.0, 2.0, 0.0],
    )
    @test all(isapprox.(pair_radial_rates(receding), (1.0, 2.0, 1.6)))

    tied = statevector(
        [0.0, 0.0, 0.0], [0.0, 0.0, 0.0],
        [1.0, 0.0, 0.0], [0.0, 0.0, 0.0],
        [-1.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )
    tied_observables = pair_observables(tied)
    @test tied_observables.separations == (1.0, 1.0, 2.0)
    @test tied_observables.order == (1, 2, 3)
    @test tied_observables.closest_pair == (1, 2)
    @test tied_observables.second_closest_pair == (1, 3)
    @test tied_observables.isolation_ratio == 1.0

    collision = statevector(
        [0.0, 0.0, 0.0], [1.0, 0.0, 0.0],
        [0.0, 0.0, 0.0], [-1.0, 0.0, 0.0],
        [2.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )
    collision_observables = pair_observables(collision)
    @test collision_observables.collisions == (true, false, false)
    @test collision_observables.radial_rates[1] == 0.0
    @test collision_observables.closest_pair == (1, 2)
    @test isinf(collision_observables.isolation_ratio)
    @test all(isfinite, collision_observables.radial_rates)

    triple_collision = statevector(
        zeros(3), zeros(3), zeros(3), zeros(3), zeros(3), zeros(3),
    )
    triple_observables = pair_observables(triple_collision)
    @test triple_observables.collisions == (true, true, true)
    @test triple_observables.order == (1, 2, 3)
    @test triple_observables.isolation_ratio == 1.0

    permuted = statevector(
        [0.0, 4.0, 0.0], [0.0, -2.0, 0.0],
        [0.0, 0.0, 0.0], [1.0, 0.0, 0.0],
        [3.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )
    permuted_observables = pair_observables(permuted)
    @test all(isapprox.(permuted_observables.separations, (4.0, 5.0, 3.0)))
    @test all(isapprox.(permuted_observables.radial_rates, (-2.0, -1.6, -1.0)))
    @test permuted_observables.closest_pair == (2, 3)
    @test permuted_observables.second_closest_pair == (1, 2)
    @test permuted_observables.isolation_ratio ≈ 4 / 3

    setprecision(BigFloat, 256) do
        big_u = statevector(
            BigFloat[0, 0, 0], BigFloat[1, 0, 0],
            BigFloat[3, 0, 0], BigFloat[0, 0, 0],
            BigFloat[0, 4, 0], BigFloat[0, -2, 0],
        )
        big_observables = pair_observables(big_u)
        @test big_observables isa PairObservables{BigFloat}
        @test big_observables.separations == (big"3", big"4", big"5")
        @test big_observables.radial_rates ==
              (BigFloat(-1), BigFloat(-2), BigFloat(-8) / BigFloat(5))
        @test big_observables.isolation_ratio == big"4" / big"3"
    end

    @test_throws ArgumentError pair_observables(zeros(17))
    @test_throws ArgumentError pair_observables(fill(NaN, 18))
end

@testset "Automatic switching entry and exit decisions" begin
    parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0,
    )

    function decision_state(r2, v2, r3, v3)
        statevector(
            [0.0, 0.0, 0.0], [0.0, 0.0, 0.0],
            r2, v2,
            r3, v3,
        )
    end

    approaching = pair_observables(decision_state(
        [0.2, 0.0, 0.0], [-1.0, 0.0, 0.0],
        [2.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    ))
    entry = automatic_entry_decision(approaching, parameters)
    @test entry.action == :enter
    @test entry.pair == (1, 2)
    @test entry.reason == :unique_approaching_pair

    outside = pair_observables(decision_state(
        [0.21, 0.0, 0.0], [-1.0, 0.0, 0.0],
        [2.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    ))
    @test automatic_entry_decision(outside, parameters).action == :none

    receding_entry = pair_observables(decision_state(
        [0.1, 0.0, 0.0], [1.0, 0.0, 0.0],
        [2.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    ))
    @test automatic_entry_decision(receding_entry, parameters).action == :none

    ambiguous = pair_observables(decision_state(
        [0.1, 0.0, 0.0], [-1.0, 0.0, 0.0],
        [0.25, 0.0, 0.0], [0.0, 0.0, 0.0],
    ))
    ambiguous_decision = automatic_entry_decision(ambiguous, parameters)
    @test ambiguous_decision.action == :failure
    @test ambiguous_decision.reason in (:simultaneous_entry_candidates, :ambiguous_close_pairs)

    weakly_isolated_parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.2,
        minimum_separation_ratio=3.0,
    )
    weakly_isolated = pair_observables(decision_state(
        [0.2, 0.0, 0.0], [-1.0, 0.0, 0.0],
        [0.5, 0.0, 0.0], [0.0, 0.0, 0.0],
    ))
    weak_decision = automatic_entry_decision(weakly_isolated, weakly_isolated_parameters)
    @test weak_decision.action == :failure
    @test weak_decision.reason == :insufficient_pair_isolation

    collision = pair_observables(decision_state(
        [0.0, 0.0, 0.0], [-1.0, 0.0, 0.0],
        [2.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    ))
    collision_decision = automatic_entry_decision(collision, parameters)
    @test collision_decision.action == :failure
    @test collision_decision.reason == :collision_state

    receding = pair_observables(decision_state(
        [0.4, 0.0, 0.0], [1.0, 0.0, 0.0],
        [2.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    ))
    exit = automatic_exit_decision(receding, parameters, (2, 1))
    @test exit.action == :exit
    @test exit.pair == (2, 1)
    @test exit.reason == :isolated_receding_pair

    below_exit = pair_observables(decision_state(
        [0.39, 0.0, 0.0], [1.0, 0.0, 0.0],
        [2.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    ))
    @test automatic_exit_decision(below_exit, parameters, (1, 2)).action == :none

    approaching_exit = pair_observables(decision_state(
        [0.5, 0.0, 0.0], [-1.0, 0.0, 0.0],
        [2.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    ))
    @test automatic_exit_decision(approaching_exit, parameters, (1, 2)).action == :none

    selected_collision = automatic_exit_decision(collision, parameters, (1, 2))
    @test selected_collision.action == :none
    @test selected_collision.reason == :selected_pair_collision

    selected_pair_lost = pair_observables(decision_state(
        [0.5, 0.0, 0.0], [1.0, 0.0, 0.0],
        [0.45, 0.0, 0.0], [0.0, 0.0, 0.0],
    ))
    lost_decision = automatic_exit_decision(selected_pair_lost, parameters, (1, 2))
    @test lost_decision.action == :failure
    @test lost_decision.reason == :selected_pair_lost

    nonselected_collision = pair_observables(decision_state(
        [1.0, 0.0, 0.0], [1.0, 0.0, 0.0],
        [1.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    ))
    nonselected_collision_decision = automatic_exit_decision(
        nonselected_collision, parameters, (1, 2),
    )
    @test nonselected_collision_decision.action == :failure
    @test nonselected_collision_decision.reason == :nonselected_pair_collision

    setprecision(BigFloat, 256) do
        big_parameters = AutomaticSwitchingParameters(
            enter_threshold=big"0.2",
            exit_threshold=big"0.4",
            ambiguity_threshold=big"0.3",
            minimum_separation_ratio=big"2",
        )
        big_observables = pair_observables(statevector(
            BigFloat[0, 0, 0], BigFloat[0, 0, 0],
            BigFloat[big"0.2", 0, 0], BigFloat[-1, 0, 0],
            BigFloat[2, 0, 0], BigFloat[0, 0, 0],
        ))
        big_decision = automatic_entry_decision(big_observables, big_parameters)
        @test big_decision.action == :enter
        @test big_decision.pair == (1, 2)
    end

    @test_throws ArgumentError AutomaticSwitchingDecision(:invalid, nothing, :invalid)
    @test_throws ArgumentError AutomaticSwitchingDecision(:enter, nothing, :missing_pair)
    @test_throws ArgumentError automatic_exit_decision(receding, parameters, (1, 1))
end

@testset "Cartesian automatic entry-event location" begin
    system = ThreeBodySystem((1e-12, 1e-12, 1e-12); G=1.0)
    parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0,
    )
    u0 = statevector(
        [-0.25, 0.0, 0.0], [0.5, 0.0, 0.0],
        [0.25, 0.0, 0.0], [-0.5, 0.0, 0.0],
        [10.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )

    located = locate_cartesian_entry_event(
        system, u0, (0.0, 0.5), parameters; saveat=0.1,
    )
    @test located.status == :entry
    @test located.decision.action == :enter
    @test located.decision.pair == (1, 2)
    @test located.physical_time ≈ 0.3 atol=1e-8
    @test located.observables.separations[1] ≈ parameters.enter_threshold atol=1e-10
    @test located.observables.radial_rates[1] < 0
    @test terminated_by_close_approach(located.simulation)

    irregular = locate_cartesian_entry_event(
        system,
        u0,
        (0.0, 0.5),
        parameters;
        saveat=[0.0, 0.07, 0.19, 0.41, 0.5],
    )
    @test irregular.status == :entry
    @test irregular.decision.pair == located.decision.pair
    @test irregular.physical_time ≈ located.physical_time atol=1e-10
    @test maximum(abs.(irregular.state .- located.state)) < 1e-9

    completed = locate_cartesian_entry_event(
        system, u0, (0.0, 0.1), parameters; saveat=0.02,
    )
    @test completed.status == :completed
    @test completed.decision.action == :none
    @test completed.physical_time == 0.1
    @test !terminated_by_close_approach(completed.simulation)

    inside = statevector(
        [-0.05, 0.0, 0.0], [0.5, 0.0, 0.0],
        [0.05, 0.0, 0.0], [-0.5, 0.0, 0.0],
        [10.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )
    rejected = locate_cartesian_entry_event(system, inside, (0.0, 0.5), parameters)
    @test rejected.status == :failure
    @test rejected.decision.reason == :initial_state_inside_entry_threshold
    @test isnothing(rejected.simulation)

    @test_throws ArgumentError CartesianEntryLocationResult(
        :entry,
        0.0,
        copy(u0),
        nothing,
        AutomaticSwitchingDecision(:none, nothing, :invalid),
        pair_observables(u0),
    )
end


@testset "Regularized automatic exit-event location" begin
    system = ThreeBodySystem((1e-12, 1e-12, 1e-12); G=1.0)
    parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0,
    )
    entry_state = statevector(
        [-0.1, 0.0, 0.0], [0.5, 0.0, 0.0],
        [0.1, 0.0, 0.0], [-0.5, 0.0, 0.0],
        [10.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )

    located = locate_regularized_exit_event(
        system, entry_state, (1, 2), 0.0, 0.8, parameters; saveat=0.05,
    )
    @test located.status == :exit
    @test located.decision.action == :exit
    @test located.decision.pair == (1, 2)
    @test located.decision.evidence.competition.crossing_provenance ==
          :certified_regularized_exit
    @test located.physical_time ≈ 0.6 atol=2e-7
    @test located.observables.separations[1] ≈ parameters.exit_threshold atol=1e-9
    @test located.observables.radial_rates[1] > 0

    dense = locate_regularized_exit_event(
        system, entry_state, (1, 2), 0.0, 0.8, parameters; saveat=0.013,
    )
    @test dense.status == :exit
    @test dense.physical_time ≈ located.physical_time atol=1e-9
    @test dense.fictitious_time ≈ located.fictitious_time atol=1e-9
    @test maximum(abs.(dense.state .- located.state)) < 1e-8

    completed = locate_regularized_exit_event(
        system, entry_state, (1, 2), 0.0, 0.1, parameters,
    )
    @test completed.status == :completed
    @test completed.decision.action == :none
    @test completed.physical_time ≈ 0.1 atol=1e-8

    outside = statevector(
        [-0.25, 0.0, 0.0], [-0.5, 0.0, 0.0],
        [0.25, 0.0, 0.0], [0.5, 0.0, 0.0],
        [10.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )
    rejected = locate_regularized_exit_event(
        system, outside, (1, 2), 0.0, 0.8, parameters,
    )
    @test rejected.status == :failure
    @test rejected.decision.reason == :initial_state_at_or_outside_exit_threshold
    @test isnothing(rejected.problem)

    @test_throws ArgumentError locate_regularized_exit_event(
        system, entry_state, (1, 2), 0.0, 0.0, parameters,
    )
    @test_throws ArgumentError RegularizedExitLocationResult(
        :exit,
        0.0,
        0.0,
        copy(entry_state),
        nothing,
        nothing,
        AutomaticSwitchingDecision(:none, nothing, :invalid),
        pair_observables(entry_state),
    )
end

@testset "Experimental alternating automatic-switching controller" begin
    system = ThreeBodySystem((1e-12, 1e-12, 1e-12); G=1.0)
    parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0,
        maximum_switches=10,
    )

    no_event_state = statevector(
        [-1.0, 0.0, 0.0], [-1.0, 0.0, 0.0],
        [1.0, 0.0, 0.0], [1.0, 0.0, 0.0],
        [10.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )
    no_event = simulate_experimental_switching(
        system, no_event_state, (0.0, 0.5), parameters,
    )
    @test no_event.status == :completed
    @test isnothing(no_event.failure)
    @test length(no_event.segments) == 1
    @test no_event.segments[1] isa AutomaticCartesianSegment
    @test isempty(no_event.switch_events)
    @test no_event.final_time ≈ 0.5

    encounter_state = statevector(
        [-0.5, 0.0, 0.0], [0.5, 0.0, 0.0],
        [0.5, 0.0, 0.0], [-0.5, 0.0, 0.0],
        [10.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )
    cycled = simulate_experimental_switching(
        system,
        encounter_state,
        (0.0, 1.6),
        parameters;
        cartesian_kwargs=(saveat=0.07,),
        regularized_kwargs=(saveat=0.031,),
    )
    @test cycled.status == :completed
    @test isnothing(cycled.failure)
    @test length(cycled.segments) == 3
    @test cycled.segments[1] isa AutomaticCartesianSegment
    @test cycled.segments[2] isa AutomaticRegularizedSegment
    @test cycled.segments[3] isa AutomaticCartesianSegment
    @test [event.kind for event in cycled.switch_events] == [:entry, :exit]
    @test all(event -> event.pair == (1, 2), cycled.switch_events)
    @test cycled.switch_events[1].physical_time ≈ 0.8 atol=2e-7
    @test cycled.switch_events[2].physical_time ≈ 1.4 atol=2e-7
    @test cycled.final_time ≈ 1.6 atol=1e-8

    limited_parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0,
        maximum_switches=1,
    )
    limited = simulate_experimental_switching(
        system, encounter_state, (0.0, 1.6), limited_parameters,
    )
    @test limited.status == :failure
    @test !isnothing(limited.failure)
    @test limited.failure.reason == :maximum_switches_exceeded
    @test length(limited.segments) == 2
    @test length(limited.switch_events) == 1

    @test_throws ArgumentError simulate_experimental_switching(
        system, encounter_state, (1.0, 0.0), parameters,
    )
end

@testset "Experimental automatic-switching validation" begin
    system = ThreeBodySystem((1e-12, 1e-12, 1e-12); G=1.0)
    parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0,
        maximum_switches=10,
    )
    encounter_state = statevector(
        [-0.5, 0.0, 0.0], [0.5, 0.0, 0.0],
        [0.5, 0.0, 0.0], [-0.5, 0.0, 0.0],
        [10.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )
    tspan = (0.0, 1.6)

    automatic = simulate_experimental_switching(
        system,
        encounter_state,
        tspan,
        parameters;
        cartesian_kwargs=(saveat=0.07,),
        regularized_kwargs=(saveat=0.031,),
    )
    @test automatic.status == :completed
    @test length(automatic.switch_events) == 2
    @test [event.kind for event in automatic.switch_events] == [:entry, :exit]

    entry_time = automatic.switch_events[1].physical_time
    exit_time = automatic.switch_events[2].physical_time

    cartesian_before_reference = simulate(
        system,
        encounter_state,
        (tspan[1], entry_time);
        solver=:accurate,
        saveat=[entry_time],
    )
    cartesian_after_reference = simulate(
        system,
        automatic.segments[2].exit_state,
        (exit_time, tspan[2]);
        solver=:accurate,
        saveat=[tspan[2]],
    )

    @test maximum(abs.(automatic.segments[1].exit_state .- cartesian_before_reference.solution.u[end])) < 2e-8
    @test maximum(abs.(automatic.segments[2].entry_state .- automatic.segments[1].exit_state)) < 2e-12
    @test maximum(abs.(automatic.segments[2].exit_state .- automatic.segments[2].location.state)) < 2e-12
    @test maximum(abs.(automatic.segments[3].entry_state .- automatic.segments[2].exit_state)) < 2e-12
    @test maximum(abs.(automatic.final_state .- cartesian_after_reference.solution.u[end])) < 2e-8

    diagnostic_fields = (
        :state_residual,
        :position_residual,
        :velocity_residual,
        :energy_jump,
        :momentum_jump,
        :angular_momentum_jump,
        :center_of_mass_jump,
        :center_of_mass_velocity_jump,
    )
    for event in automatic.switch_events
        diagnostics = event.transition_diagnostics
        @test all(field -> getfield(diagnostics, field) <= 1e-12, diagnostic_fields)
    end

    irregular = simulate_experimental_switching(
        system,
        encounter_state,
        tspan,
        parameters;
        cartesian_kwargs=(saveat=[0.0, 0.11, 0.37, 0.79, 1.03, 1.6],),
        regularized_kwargs=(saveat=0.017,),
    )
    @test irregular.status == :completed
    @test length(irregular.segments) == length(automatic.segments)
    @test [event.kind for event in irregular.switch_events] ==
          [event.kind for event in automatic.switch_events]
    @test [event.pair for event in irregular.switch_events] ==
          [event.pair for event in automatic.switch_events]
    @test all(isapprox.(
        [event.physical_time for event in irregular.switch_events],
        [event.physical_time for event in automatic.switch_events];
        atol=1e-9,
        rtol=0.0,
    ))
    @test maximum(abs.(irregular.final_state .- automatic.final_state)) < 2e-8
end

@testset "Experimental automatic-switching physical-time evaluation" begin
    system = ThreeBodySystem((1e-12, 1e-12, 1e-12); G=1.0)
    parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0,
        maximum_switches=10,
    )
    encounter_state = statevector(
        [-0.5, 0.0, 0.0], [0.5, 0.0, 0.0],
        [0.5, 0.0, 0.0], [-0.5, 0.0, 0.0],
        [10.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )
    trajectory = simulate_experimental_switching(
        system,
        encounter_state,
        (0.0, 1.6),
        parameters;
        cartesian_kwargs=(saveat=0.09,),
        regularized_kwargs=(saveat=0.027,),
    )

    @test trajectory.status == :completed
    @test length(trajectory.segments) == 3
    entry_time = trajectory.switch_events[1].physical_time
    exit_time = trajectory.switch_events[2].physical_time

    @test experimental_switching_state(trajectory, 0.0) == trajectory.segments[1].entry_state
    @test experimental_switching_state(trajectory, entry_time) == trajectory.segments[1].exit_state
    @test trajectory(entry_time) == trajectory.segments[1].exit_state
    @test experimental_switching_state(trajectory, exit_time) == trajectory.segments[2].exit_state
    @test experimental_switching_state(trajectory, 1.6) == trajectory.final_state

    cartesian_before_time = entry_time / 2
    cartesian_before_expected = trajectory.segments[1].location.simulation.solution(cartesian_before_time)
    @test maximum(abs.(
        trajectory(cartesian_before_time) .- cartesian_before_expected
    )) < 2e-12

    regularized_time = (entry_time + exit_time) / 2
    default_regularized_state = experimental_switching_state(
        trajectory,
        regularized_time,
    )
    strict_regularized_state = experimental_switching_state(
        trajectory,
        regularized_time;
        regularized_kwargs=(
            tolerance=1e-14,
            max_iterations=256,
        ),
    )
    @test maximum(abs.(
        default_regularized_state .- strict_regularized_state
    )) < 1e-10

    @test_throws ArgumentError experimental_switching_state(
        trajectory,
        regularized_time;
        regularized_kwargs=(initial_step=0.1,),
    )
    @test_throws ArgumentError experimental_switching_state(
        trajectory,
        regularized_time;
        regularized_kwargs=(tolerance=0.0,),
    )
    @test_throws ArgumentError experimental_switching_state(
        trajectory,
        regularized_time;
        regularized_kwargs=(max_iterations=0,),
    )

    cartesian_after_time = (exit_time + trajectory.final_time) / 2
    cartesian_after_expected = trajectory.segments[3].location.simulation.solution(cartesian_after_time)
    @test maximum(abs.(
        trajectory(cartesian_after_time) .- cartesian_after_expected
    )) < 2e-12

    @test_throws ArgumentError trajectory(-eps())
    @test_throws ArgumentError trajectory(trajectory.final_time + eps(trajectory.final_time))
    @test_throws ArgumentError trajectory(Inf)

    no_switch_state = statevector(
        [-1.0, 0.0, 0.0], [0.0, 0.1, 0.0],
        [1.0, 0.0, 0.0], [0.0, -0.1, 0.0],
        [0.0, 3.0, 0.0], [0.0, 0.0, 0.0],
    )
    no_switch = simulate_experimental_switching(
        system,
        no_switch_state,
        (0.0, 0.2),
        parameters;
        cartesian_kwargs=(saveat=0.07,),
    )
    @test no_switch.status == :completed
    @test length(no_switch.segments) == 1
    @test maximum(abs.(
        no_switch(0.11) .- no_switch.segments[1].location.simulation.solution(0.11)
    )) < 2e-12
end

@testset "Experimental automatic-switching unified sampling" begin
    system = ThreeBodySystem((1e-12, 1e-12, 1e-12); G=1.0)
    parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0,
        maximum_switches=10,
    )
    encounter_state = statevector(
        [-0.5, 0.0, 0.0], [0.5, 0.0, 0.0],
        [0.5, 0.0, 0.0], [-0.5, 0.0, 0.0],
        [10.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )
    trajectory = simulate_experimental_switching(
        system,
        encounter_state,
        (0.0, 1.6),
        parameters;
        cartesian_kwargs=(saveat=0.09,),
        regularized_kwargs=(saveat=0.027,),
    )
    @test trajectory.status == :completed

    entry_time = trajectory.switch_events[1].physical_time
    exit_time = trajectory.switch_events[2].physical_time
    evaluation_kwargs = (
        tolerance=1e-14,
        max_iterations=256,
    )
    explicit = sample_experimental_switching(
        trajectory,
        [0.0, 0.3, 0.9, 1.5, 1.6];
        regularized_kwargs=evaluation_kwargs,
    )
    @test explicit isa ExperimentalSwitchingSamples
    @test length(explicit) == length(explicit.times) == length(explicit.states)
    @test issorted(explicit.times)
    @test all(diff(explicit.times) .> 0)
    @test count(==(entry_time), explicit.times) == 1
    @test count(==(exit_time), explicit.times) == 1
    @test first(explicit.times) == 0.0
    @test last(explicit.times) == 1.6
    @test explicit[1] == trajectory.segments[1].entry_state
    @test explicit[end] == trajectory.final_state

    for index in eachindex(explicit.times)
        @test maximum(abs.(
            explicit.states[index] .-
            experimental_switching_state(
                trajectory,
                explicit.times[index];
                regularized_kwargs=evaluation_kwargs,
            )
        )) < 2e-12
    end

    without_switches = sample_experimental_switching(
        trajectory,
        [0.0, 0.8, 1.6];
        include_switches=false,
    )
    @test without_switches.times == [0.0, 0.8, 1.6]

    uniform = sample_experimental_switching(
        trajectory;
        dt=0.23,
        regularized_kwargs=evaluation_kwargs,
    )
    @test first(uniform.times) == trajectory.tspan[1]
    @test last(uniform.times) == trajectory.final_time
    @test count(==(entry_time), uniform.times) == 1
    @test count(==(exit_time), uniform.times) == 1
    @test all(diff(uniform.times) .> 0)

    @test_throws ArgumentError sample_experimental_switching(trajectory, Float64[])
    @test_throws ArgumentError sample_experimental_switching(trajectory, [0.0, 0.0])
    @test_throws ArgumentError sample_experimental_switching(trajectory, [0.2, 0.1])
    @test_throws ArgumentError sample_experimental_switching(trajectory, [-0.1, 0.2])
    @test_throws ArgumentError sample_experimental_switching(trajectory, [0.0, Inf])
    @test_throws ArgumentError sample_experimental_switching(trajectory; dt=0.0)
    @test_throws ArgumentError sample_experimental_switching(trajectory; dt=Inf)
    @test_throws ArgumentError sample_experimental_switching(
        trajectory; dt=1e-9, maximum_samples=100,
    )
end

@testset "Experimental automatic-switching visualization" begin
    system = ThreeBodySystem((1e-12, 1e-12, 1e-12); G=1.0)
    parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0,
        maximum_switches=10,
    )
    encounter_state = statevector(
        [-0.5, 0.0, 0.0], [0.5, 0.0, 0.0],
        [0.5, 0.0, 0.0], [-0.5, 0.0, 0.0],
        [10.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )
    trajectory = simulate_experimental_switching(
        system, encounter_state, (0.0, 1.6), parameters;
        cartesian_kwargs=(saveat=0.09,),
        regularized_kwargs=(saveat=0.027,),
    )
    @test trajectory.status == :completed

    fig = plot_trajectory(trajectory; show=false, npoints=80)
    @test fig !== nothing

    @test_throws ArgumentError plot_trajectory(
        trajectory;
        show=false,
        npoints=1,
    )

    animation_figure, animation_index, animation_frames =
        ThreeBody3D._animation_scene(
            trajectory;
            fps=10,
            duration=0.1,
            markersize=12,
            bodycolors=(:red, :green, :blue),
            margin=0.05,
        )

    @test animation_figure !== nothing
    @test animation_index[] == 1
    @test animation_frames == 2

    @test_throws ArgumentError record_animation(
        trajectory,
        "not-an-mp4.gif";
        duration=0.1,
    )

    pair_figure, pair_index, pair_frames = ThreeBody3D._animation_scene(
        trajectory;
        fps=10,
        duration=0.1,
        markersize=12,
        bodycolors=(:red, :green, :blue),
        margin=0.05,
        view=:pair_centered,
        pair=(1, 2),
        zoom_radius=0.6,
    )
    @test pair_figure !== nothing
    @test pair_index[] == 1
    @test pair_frames == 2

    _, raw_points = ThreeBody3D._sample_solution(trajectory, 5)
    centered = ThreeBody3D._pair_centered_points(trajectory, raw_points, (1, 2))
    m1, m2 = trajectory.system.masses[1], trajectory.system.masses[2]
    for k in eachindex(centered[1])
        pair_com = (m1 .* centered[1][k] .+ m2 .* centered[2][k]) ./ (m1 + m2)
        @test maximum(abs.(Tuple(pair_com))) < 2f-6
    end

    @test_throws ArgumentError ThreeBody3D._animation_scene(
        trajectory; fps=10, duration=0.1, markersize=12,
        bodycolors=(:red, :green, :blue), margin=0.05, view=:invalid,
    )
    @test_throws ArgumentError ThreeBody3D._animation_scene(
        trajectory; fps=10, duration=0.1, markersize=12,
        bodycolors=(:red, :green, :blue), margin=0.05,
        view=:pair_centered, pair=(1, 1), zoom_radius=0.6,
    )
    @test_throws ArgumentError ThreeBody3D._animation_scene(
        trajectory; fps=10, duration=0.1, markersize=12,
        bodycolors=(:red, :green, :blue), margin=0.05,
        view=:pair_centered, pair=(1, 2), zoom_radius=0.0,
    )


end
@testset "Experimental automatic-switching diagnostics" begin
    system = ThreeBodySystem((1e-12, 1e-12, 1e-12); G=1.0)
    parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0,
        maximum_switches=10,
    )
    u0 = statevector(
        [-0.5, 0.0, 0.0], [0.5, 0.0, 0.0],
        [0.5, 0.0, 0.0], [-0.5, 0.0, 0.0],
        [10.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )
    trajectory = simulate_experimental_switching(
        system, u0, (0.0, 1.6), parameters;
        cartesian_kwargs=(saveat=0.09,),
        regularized_kwargs=(saveat=0.027,),
    )
    samples = sample_experimental_switching(trajectory; dt=0.05)
    report = diagnostics_report(trajectory, samples)

    @test report isa ExperimentalSwitchingDiagnosticsReport
    @test report.sample_count == length(samples)
    @test report.segment_count == length(trajectory.segments)
    @test report.switch_count == length(trajectory.switch_events) == 2
    @test report.initial_energy == total_energy(system, first(samples.states))
    @test report.final_energy == total_energy(system, last(samples.states))
    @test report.minimum_separation <= parameters.enter_threshold
    @test report.maximum_relative_energy_drift >= 0
    @test report.maximum_center_of_mass_velocity_drift >= 0
    @test report.maximum_transition_state_residual >= 0
    @test report.maximum_transition_energy_jump >= 0
    @test occursin("experimental switching diagnostics", sprint(show, report))

    keyword_report = diagnostics_report(trajectory; dt=0.05)
    @test keyword_report.sample_count == report.sample_count
    @test keyword_report.switch_count == report.switch_count
    @test keyword_report.maximum_relative_energy_drift ≈ report.maximum_relative_energy_drift

    truncated = sample_experimental_switching(
        trajectory, [0.1, trajectory.final_time]; include_switches=false,
    )
    @test_throws ArgumentError diagnostics_report(trajectory, truncated)
end

@testset "Validation benchmark framework" begin
    @test :figure_eight in validation_benchmark_names()
    @test FIGURE_EIGHT_PERIOD > 0

    report = run_validation_benchmark(
        :figure_eight;
        periods=1,
        solver=:accurate,
        saveat=0.05,
    )

    @test report isa ValidationBenchmarkReport
    @test report.name == :figure_eight
    @test report.status == :completed
    @test report.profile == :accurate
    @test report.initial_time == 0.0
    @test isapprox(report.final_time, report.expected_final_time; atol=1e-14, rtol=0)
    @test report.saved_states > 2
    @test report.accepted_steps > 0
    @test report.rejected_steps >= 0
    @test report.rhs_evaluations > 0
    @test report.diagnostics.maximum_relative_energy_drift < 1e-10
    @test report.diagnostics.maximum_linear_momentum_drift < 1e-12
    @test report.diagnostics.maximum_angular_momentum_drift < 1e-11
    @test report.diagnostics.maximum_center_of_mass_residual < 1e-11
    @test report.diagnostics.minimum_separation > 0
    @test report.periodicity_error < 1e-5
    @test occursin("validation benchmark: figure_eight", sprint(show, report))

    @test_throws ArgumentError run_validation_benchmark(:unknown)
    @test_throws ArgumentError run_validation_benchmark(:figure_eight; periods=0)
    @test_throws ArgumentError run_validation_benchmark(:figure_eight; saveat=0.0)
    @test_throws ArgumentError run_validation_benchmark(:figure_eight; solver=:invalid)
end

@testset "Hierarchical-triple validation benchmark" begin
    @test validation_benchmark_names() == (:figure_eight, :hierarchical_triple)
    @test HIERARCHICAL_TRIPLE_DURATION > 0

    report = run_validation_benchmark(
        :hierarchical_triple;
        duration=5.0,
        solver=:accurate,
        saveat=0.05,
    )

    @test report isa ValidationBenchmarkReport
    @test report.name == :hierarchical_triple
    @test report.status == :completed
    @test report.profile == :accurate
    @test report.initial_time == 0.0
    @test isapprox(report.final_time, 5.0; atol=1e-14, rtol=0)
    @test isnan(report.periodicity_error)
    @test isapprox(report.benchmark_metrics.initial_hierarchy_ratio, 10.0; atol=1e-12, rtol=0)
    @test report.benchmark_metrics.minimum_hierarchy_ratio > 5
    @test report.benchmark_metrics.final_hierarchy_ratio > 5
    @test report.diagnostics.maximum_relative_energy_drift < 1e-9
    @test report.diagnostics.maximum_linear_momentum_drift < 1e-11
    @test report.diagnostics.maximum_angular_momentum_drift < 1e-10
    @test report.diagnostics.maximum_center_of_mass_residual < 1e-10
    @test occursin("validation benchmark: hierarchical_triple", sprint(show, report))
    @test occursin("minimum hierarchy ratio", sprint(show, report))

    @test_throws ArgumentError run_validation_benchmark(
        :hierarchical_triple; duration=0.0,
    )
    @test_throws ArgumentError run_validation_benchmark(
        :figure_eight; duration=1.0,
    )
end

include("automatic_switching_policy_inventory.jl")
include("automatic_switching_decision_evidence.jl")
include("automatic_switching_competition_evidence.jl")
include("automatic_switching_threshold_policies.jl")
include("automatic_switching_progress.jl")

include("ks/runtests.jl")

include("validation_framework/runtests.jl")
