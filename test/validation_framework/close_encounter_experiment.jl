using Test

struct CloseSyntheticStats
    naccept::Int
    nreject::Int
    nf::Int
end

struct CloseSyntheticSolution{T,F}
    t::Vector{T}
    u::Vector{Vector{T}}
    stats::CloseSyntheticStats
    state_at_time::F
end

(solution::CloseSyntheticSolution)(time) = solution.state_at_time(time)

function synthetic_close_state(::Type{T}, time) where {T}
    t = T(time)
    center = parse(T, "0.8")
    separation = (t - center)^2
    separation_rate = T(2) * (t - center)
    state = zeros(T, 18)
    state[1] = separation / T(2)
    state[7] = -separation / T(2)
    state[4] = separation_rate / T(2)
    state[10] = -separation_rate / T(2)
    state[13] = parse(T, "10")
    state
end

function synthetic_close_reference()
    setprecision(BigFloat, 256) do
        problem = ValidationFramework.close_encounter_problem(BigFloat)
        times = ValidationFramework.close_encounter_sample_times((0.0, 1.6))
        states = [synthetic_close_state(BigFloat, BigFloat(time)) for time in times]
        nodes = collect(range(parse(BigFloat, "0"); step=parse(BigFloat, "0.01"),
            stop=parse(BigFloat, "1.6")))
        solution = CloseSyntheticSolution(
            nodes, [synthetic_close_state(BigFloat, time) for time in nodes],
            CloseSyntheticStats(160, 0, 1600),
            time -> synthetic_close_state(BigFloat, time),
        )
        boundaries = ValidationFramework.close_encounter_reference_boundaries(
            solution, nodes, problem.tspan,
        )
        tolerance = parse(BigFloat, "1e-30")
        ValidationFramework.CloseEncounterReferenceExecution(
            problem, solution, times, states, boundaries, 256,
            tolerance, tolerance, :extreme, true, true,
        )
    end
end

@testset "Close-encounter shared experiment foundation" begin
    float_problem = ValidationFramework.close_encounter_problem(Float64)
    @test Tuple(float_problem.system.masses) == (1.0, 1.0, 0.001)
    @test float_problem.system.G == 1.0
    @test float_problem.physical_parameters.apoapsis == 1.0
    @test float_problem.nominal_periapsis == 0.0001
    @test float_problem.physical_parameters.third_body_offset == 10.0
    @test float_problem.tspan == (0.0, 1.6)

    setprecision(BigFloat, 256) do
        big_problem = ValidationFramework.close_encounter_problem(BigFloat)
        @test big_problem.system.masses[3] == parse(BigFloat, "0.001")
        @test big_problem.nominal_periapsis == parse(BigFloat, "0.0001")
        @test big_problem.tspan == (parse(BigFloat, "0"), parse(BigFloat, "1.6"))
        @test precision(big_problem.u0[1]) == 256
    end

    times = ValidationFramework.close_encounter_sample_times((0.0, 1.6))
    @test length(times) == 801
    @test first(times) == 0.0
    @test last(times) == 1.6
    @test all(index -> times[index] < times[index + 1], 1:800)

    reference = synthetic_close_reference()
    boundaries = reference.boundaries
    @test boundaries.entry_time < boundaries.periapsis_time < boundaries.exit_time
    @test boundaries.entry_time < parse(BigFloat, "0.8")
    @test boundaries.periapsis_time == parse(BigFloat, "0.8")
    @test boundaries.exit_time ≈ parse(BigFloat, "1.3") atol=big"1e-60"
    @test boundaries.entry_residual == boundaries.entry_separation - parse(BigFloat, "0.1")
    @test boundaries.exit_residual == boundaries.exit_separation - parse(BigFloat, "0.25")
    @test precision(boundaries.entry_time) == 256

    @test_throws ArgumentError ValidationFramework.close_encounter_reference_boundaries(
        reference.solution, BigFloat[], reference.problem.tspan,
    )
    bad_nodes = setprecision(BigFloat, 256) do
        BigFloat[parse(BigFloat, "0"), parse(BigFloat, "0.2"), parse(BigFloat, "1.6")]
    end
    @test_throws ArgumentError ValidationFramework.close_encounter_reference_boundaries(
        reference.solution, bad_nodes, reference.problem.tspan,
    )
    @test_throws ArgumentError ValidationFramework.close_encounter_periapsis(
        reference.solution, parse(BigFloat, "0.81"), parse(BigFloat, "0.9"),
    )

    augmented = ValidationFramework.close_encounter_augmented_times(reference)
    @test issorted(augmented)
    @test allunique(augmented)
    @test boundaries.entry_time in augmented
    @test boundaries.periapsis_time in augmented
    @test boundaries.exit_time in augmented
    @test last(augmented) == ValidationFramework.close_encounter_reference_time(reference, 1.6)
    setprecision(BigFloat, 256) do
        @test BigFloat(0.002) != parse(BigFloat, "0.002")
        @test BigFloat(0.8) != parse(BigFloat, "0.8")
        @test ValidationFramework.close_encounter_reference_time(reference, 0.002) ==
            BigFloat(0.002)
        @test ValidationFramework.close_encounter_reference_time(reference, 0.002) in augmented
        @test BigFloat(0.8) in augmented
        @test parse(BigFloat, "0.8") in augmented
    end

    original_precision = precision(BigFloat)
    state_low, augmented_low = setprecision(BigFloat, 96) do
        state = ValidationFramework.close_encounter_reference_state(reference, 0.8)
        grid = ValidationFramework.close_encounter_augmented_times(reference)
        @test precision(BigFloat) == 96
        state, grid
    end
    @test precision(BigFloat) == original_precision
    @test all(value -> precision(value) == 256, state_low)
    @test all(value -> precision(value) == 256, augmented_low)

    b = boundaries
    setprecision(BigFloat, 256) do
        @test_throws ArgumentError ValidationFramework.CloseEncounterReferenceBoundaries(
            b.entry_time, parse(BigFloat, "0.2"), parse(BigFloat, "0.1"),
            b.periapsis_time, b.periapsis_separation, b.periapsis_residual,
            b.exit_time, b.exit_separation, b.exit_residual,
        )
        @test_throws ArgumentError ValidationFramework.CloseEncounterReferenceBoundaries(
            b.entry_time, b.entry_separation, b.entry_residual,
            b.periapsis_time, b.periapsis_separation, parse(BigFloat, "0.1"),
            b.exit_time, b.exit_separation, b.exit_residual,
        )
        @test_throws ArgumentError ValidationFramework.CloseEncounterReferenceBoundaries(
            b.entry_time, b.entry_separation, b.entry_residual,
            b.periapsis_time, b.periapsis_separation, b.periapsis_residual,
            b.exit_time, parse(BigFloat, "0.35"), parse(BigFloat, "0.1"),
        )
    end

    state = zeros(Float64, 18)
    reference_state = zeros(BigFloat, 18)
    state[1] = 3.0
    state[4] = 4.0
    state[7] = 1.0
    state[10] = 1.0
    reference_state[1] = 2.0
    reference_state[4] = 2.0
    reference_state[7] = 1.0
    reference_state[10] = 1.0
    errors = ValidationFramework.close_encounter_state_errors(state, reference_state)
    @test errors.position == 1.0
    @test errors.velocity == 2.0
    @test errors.full_state == 2.0
    @test errors.position isa Float64

    conservation = ValidationFramework.close_encounter_conservation(
        float_problem.system, [0.0], [float_problem.u0],
    )
    @test conservation.maximum_relative_energy_drift == 0.0
    @test conservation.maximum_momentum_drift == 0.0
    @test conservation.minimum_separation > 0

    work = ValidationFramework.close_encounter_solution_work(reference.solution)
    @test work == (saved_states=161, accepted_steps=160, rejected_steps=0,
        rhs_evaluations=1600)
end
