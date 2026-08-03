function _close_workflow_fixture_series(environment, reference)
    cartesian_configurations = Tuple(close_encounter_cartesian_configuration(value)
        for value in CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES)
    float_runner = synthetic_float_runner(reference)
    cartesian_attempts = Tuple(attempt_close_encounter_cartesian(configuration,
        reference; runner=float_runner) for configuration in cartesian_configurations)
    cartesian = close_encounter_cartesian_investigation_series(
        synthetic_close_performance_suite(cartesian_configurations, environment),
        cartesian_attempts)

    regularized_attempts = Tuple(synthetic_regularized_attempt(reference, value)
        for value in ValidationFramework.CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES)
    regularized = close_encounter_regularized_investigation_series(
        synthetic_regularized_suite(environment), regularized_attempts)

    threshold_attempts = Tuple(synthetic_threshold_attempt(reference, value)
        for value in ValidationFramework.CLOSE_ENCOUNTER_THRESHOLD_SCALES)
    threshold = close_encounter_threshold_investigation_series(
        synthetic_threshold_suite(environment), threshold_attempts)
    (cartesian=cartesian, regularized=regularized, threshold=threshold,
        cartesian_attempts=cartesian_attempts,
        regularized_attempts=regularized_attempts,
        threshold_attempts=threshold_attempts)
end

function _close_workflow_point(point; definition=point.definition,
    configuration=point.configuration, environment=point.environment,
    execution=point.execution, performance_report=point.performance_report,
    supporting_evidence=point.supporting_evidence, metrics=point.metrics,
    solver_statistics=point.solver_statistics, notes=point.notes)
    InvestigationMeasurementPoint(point.point_id, definition, configuration,
        point.independent_value, environment, execution, metrics, solver_statistics;
        performance_report, supporting_evidence, notes)
end

function _close_workflow_series(series; series_id=series.series_id,
    definition=series.definition, points=series.points)
    InvestigationMeasurementSeries(series_id, series.title, series.description,
        definition, Tuple(points))
end

function _close_workflow_foreign_environment(environment)
    ValidationEnvironment(environment.schema_version, environment.package_version,
        environment.repository_commit, environment.repository_dirty,
        environment.julia_version, environment.operating_system,
        environment.architecture, environment.thread_count,
        environment.timestamp_utc * "-foreign")
end

function _close_workflow_alternate_reference(reference)
    setprecision(BigFloat, 256) do
        boundaries = reference.boundaries
        altered = ValidationFramework.CloseEncounterReferenceBoundaries(
            boundaries.entry_time + parse(BigFloat, "1e-60"),
            boundaries.entry_separation, boundaries.entry_residual,
            boundaries.periapsis_time, boundaries.periapsis_separation,
            boundaries.periapsis_residual, boundaries.exit_time,
            boundaries.exit_separation, boundaries.exit_residual,
            boundaries.arithmetic, boundaries.precision_bits)
        ValidationFramework.CloseEncounterReferenceExecution(reference.problem,
            reference.solution, reference.sample_times, reference.sampled_states,
            altered, reference.precision_bits, reference.relative_tolerance,
            reference.absolute_tolerance, reference.solver_selector,
            reference.dense, reference.save_everystep)
    end
end

function _close_workflow_runners(fixtures; fail_group=nothing,
    cartesian_series=fixtures.cartesian, calls=Symbol[], directories=String[])
    cartesian = function(reference, environment, directory, project_root)
        push!(calls, :cartesian)
        push!(directories, directory)
        fail_group == :cartesian && error("injected Cartesian group failure")
        cartesian_series
    end
    regularized = function(reference, environment, directory, project_root)
        push!(calls, :regularized_tolerance)
        push!(directories, directory)
        fail_group == :regularized_tolerance && error(
            "injected regularized-tolerance group failure")
        fixtures.regularized
    end
    threshold = function(reference, environment, directory, project_root)
        push!(calls, :threshold_scale)
        push!(directories, directory)
        fail_group == :threshold_scale && error("injected threshold group failure")
        fixtures.threshold
    end
    (; cartesian, regularized, threshold, calls, directories)
end

@testset "Investigation 2 close-encounter orchestration" begin
    environment = _pilot_environment()
    reference = synthetic_close_reference()
    fixtures = _close_workflow_fixture_series(environment, reference)
    expected_ids = ValidationFramework.CLOSE_ENCOUNTER_INVESTIGATION_SERIES_ORDER
    expected_filenames = Tuple(getproperty(
        ValidationFramework.CLOSE_ENCOUNTER_INVESTIGATION_FILENAMES, id)
        for id in expected_ids)

    @testset "direct groups share reference and preserve registrations" begin
        references = Any[]
        cartesian_values = Float64[]
        regularized_values = Float64[]
        threshold_values = Float64[]
        registrations = Vector{Vector{Symbol}}()
        report_directories = String[]
        roots = String[]

        cartesian_attempt = function(configuration, observed_reference)
            push!(references, observed_reference)
            push!(cartesian_values, configuration.relative_tolerance)
            index = findfirst(==(configuration.relative_tolerance),
                CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES)
            fixtures.cartesian_attempts[index]
        end
        regularized_attempt = function(configuration, observed_reference)
            push!(references, observed_reference)
            push!(regularized_values, configuration.regularized_relative_tolerance)
            index = findfirst(==(configuration.regularized_relative_tolerance),
                ValidationFramework.CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES)
            fixtures.regularized_attempts[index]
        end
        threshold_attempt = function(configuration, observed_reference)
            push!(references, observed_reference)
            push!(threshold_values, configuration.threshold_scale)
            index = findfirst(==(configuration.threshold_scale),
                ValidationFramework.CLOSE_ENCOUNTER_THRESHOLD_SCALES)
            fixtures.threshold_attempts[index]
        end
        function performance_runner(suite, entries; environment, report_directory, project_root)
            push!(registrations,
                Symbol[entry.definition.benchmark_id for entry in entries])
            push!(report_directories, report_directory)
            push!(roots, project_root)
            (; suite, processes=())
        end
        mktempdir() do work_root
            project_root = normpath(joinpath(@__DIR__, "..", ".."))
            cartesian = ValidationFramework._run_close_encounter_cartesian_group(
                reference, environment, joinpath(work_root, "cartesian"), project_root;
                attempt_runner=cartesian_attempt,
                performance_runner=(entries; kwargs...) -> performance_runner(
                    synthetic_close_performance_suite(Tuple(
                        close_encounter_cartesian_configuration(value)
                        for value in CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES), environment),
                    entries; kwargs...))
            regularized = ValidationFramework._run_close_encounter_regularized_group(
                reference, environment, joinpath(work_root, "regularized_tolerance"),
                project_root; attempt_runner=regularized_attempt,
                performance_runner=(entries; kwargs...) -> performance_runner(
                    synthetic_regularized_suite(environment), entries; kwargs...))
            threshold = ValidationFramework._run_close_encounter_threshold_group(
                reference, environment, joinpath(work_root, "threshold_scale"), project_root;
                attempt_runner=threshold_attempt,
                performance_runner=(entries; kwargs...) -> performance_runner(
                    synthetic_threshold_suite(environment), entries; kwargs...))

            @test cartesian.series_id == expected_ids[1]
            @test (regularized.automatic.series_id, regularized.explicit.series_id) ==
                expected_ids[2:3]
            @test (threshold.automatic.series_id, threshold.explicit.series_id) ==
                expected_ids[4:5]
            @test length(references) == 12
            @test all(item -> item === reference, references)
            @test Tuple(cartesian_values) == CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES
            @test Tuple(regularized_values) ==
                ValidationFramework.CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES
            @test Tuple(threshold_values) ==
                ValidationFramework.CLOSE_ENCOUNTER_THRESHOLD_SCALES
            @test map(length, registrations) == [5, 8, 6]
            @test registrations[1] == Symbol[
                ValidationFramework.close_encounter_cartesian_performance_benchmark_id(value)
                for value in CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES]
            @test registrations[2] == Symbol[
                ValidationFramework.close_encounter_regularized_performance_benchmark_id(
                    method, value) for method in (:automatic, :explicit)
                    for value in ValidationFramework.CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES]
            @test registrations[3] == Symbol[
                ValidationFramework.close_encounter_threshold_performance_benchmark_id(
                    method, value) for method in (:automatic, :explicit)
                    for value in ValidationFramework.CLOSE_ENCOUNTER_THRESHOLD_SCALES]
            @test basename.(dirname.(report_directories)) ==
                ["cartesian", "regularized_tolerance", "threshold_scale"]
            @test length(unique(dirname.(dirname.(report_directories)))) == 1
            @test all(==(project_root), roots)
            @test all(index -> regularized.automatic.points[index].supporting_evidence.comparison ===
                regularized.explicit.points[index].supporting_evidence.comparison, 1:4)
            @test all(index -> threshold.automatic.points[index].supporting_evidence.comparison ===
                threshold.explicit.points[index].supporting_evidence.comparison, 1:3)
        end
    end

    @testset "trusted series contracts" begin
        for series in (fixtures.cartesian, fixtures.regularized.automatic,
            fixtures.regularized.explicit, fixtures.threshold.automatic,
            fixtures.threshold.explicit)
            @test ValidationFramework._validate_close_encounter_workflow_series(
                series, series.series_id, environment, reference.boundaries) === series
        end
        @test_throws ArgumentError ValidationFramework._validate_close_encounter_workflow_series(
            _close_workflow_series(fixtures.cartesian;
                series_id=:close_encounter_automatic_regularized_tolerance),
            :close_encounter_cartesian_tolerance, environment, reference.boundaries)
        original_definition = fixtures.cartesian.definition
        altered_definition = InvestigationDefinition(original_definition.family_id,
            original_definition.title * " altered", original_definition.description,
            original_definition.benchmark, original_definition.independent_variable,
            original_definition.fixed_controls, original_definition.required_metric_ids,
            original_definition.optional_metric_ids, original_definition.definition_version)
        altered_definition_points = Tuple(_close_workflow_point(point;
            definition=altered_definition) for point in fixtures.cartesian.points)
        @test_throws ArgumentError ValidationFramework._validate_close_encounter_workflow_series(
            _close_workflow_series(fixtures.cartesian; definition=altered_definition,
                points=altered_definition_points), expected_ids[1], environment,
            reference.boundaries)
        @test_throws ArgumentError ValidationFramework._validate_close_encounter_paired_group(
            (automatic=fixtures.regularized.automatic,), expected_ids[2:3],
            environment, reference.boundaries)
        @test_throws ArgumentError ValidationFramework._validate_close_encounter_paired_group(
            (automatic=fixtures.regularized.explicit,
                explicit=fixtures.regularized.automatic), expected_ids[2:3],
            environment, reference.boundaries)

        reordered = _close_workflow_series(fixtures.cartesian;
            points=reverse(fixtures.cartesian.points))
        @test_throws ArgumentError ValidationFramework._validate_close_encounter_workflow_series(
            reordered, expected_ids[1], environment, reference.boundaries)

        foreign = _close_workflow_foreign_environment(environment)
        foreign_points = collect(fixtures.cartesian.points)
        foreign_points[1] = _close_workflow_point(foreign_points[1]; environment=foreign)
        @test_throws ArgumentError ValidationFramework._validate_close_encounter_workflow_series(
            _close_workflow_series(fixtures.cartesian; points=foreign_points),
            expected_ids[1], environment, reference.boundaries)

        wrong_configuration = collect(fixtures.cartesian.points)
        wrong_configuration[1] = _close_workflow_point(wrong_configuration[1];
            configuration=fixtures.threshold.automatic.points[1].configuration)
        @test_throws ArgumentError ValidationFramework._validate_close_encounter_workflow_series(
            _close_workflow_series(fixtures.cartesian; points=wrong_configuration),
            expected_ids[1], environment, reference.boundaries)

        alternate_reference = _close_workflow_alternate_reference(reference)
        alternate = _close_workflow_fixture_series(environment, alternate_reference).cartesian
        @test_throws ArgumentError ValidationFramework._validate_close_encounter_workflow_series(
            alternate, expected_ids[1], environment, reference.boundaries)
    end

    @testset "successful deterministic persistence" begin
        calls = Symbol[]
        directories = String[]
        runners = _close_workflow_runners(fixtures; calls, directories)
        environment_calls = Ref(0)
        reference_calls = Ref(0)
        mktempdir() do directory
            unrelated = joinpath(directory, "user-created.txt")
            write(unrelated, "preserve me")
            result = run_investigation_2_close_encounter(; output_directory=directory,
                project_root=normpath(joinpath(@__DIR__, "..", "..")),
                environment_runner=root -> begin
                    environment_calls[] += 1
                    environment
                end,
                reference_runner=() -> begin
                    reference_calls[] += 1
                    reference
                end,
                cartesian_runner=runners.cartesian,
                regularized_runner=runners.regularized,
                threshold_runner=runners.threshold)
            @test environment_calls[] == 1
            @test reference_calls[] == 1
            @test runners.calls == [:cartesian, :regularized_tolerance, :threshold_scale]
            @test basename.(runners.directories) ==
                ["cartesian", "regularized_tolerance", "threshold_scale"]
            @test length(unique(dirname.(runners.directories))) == 1
            @test result.exit_code == 0
            @test isempty(result.failures)
            @test Tuple(series.series_id for series in result.series) == expected_ids
            @test basename.(result.report_paths) == expected_filenames
            @test map(series -> length(series.points), result.series) == (5, 4, 4, 3, 3)
            for (series, path) in zip(result.series, result.report_paths)
                restored = read_investigation_series(path)
                @test restored.series_id == series.series_id
                @test investigation_series_report_text(restored) == read(path, String)
            end
            @test read(unrelated, String) == "preserve me"
        end
    end

    @testset "parent-environment evidence is workflow-owned" begin
        mktempdir() do directory
            evidence_directory = joinpath(directory,
                ValidationFramework.CLOSE_ENCOUNTER_OPERATIONAL_EVIDENCE_DIRECTORY)
            mkpath(evidence_directory)
            unrelated_path = joinpath(evidence_directory, "unrelated_i2_evidence.bin")
            unrelated_bytes = UInt8[0x00, 0x42, 0xff, 0x0a]
            write(unrelated_path, unrelated_bytes)

            failed = run_investigation_2_close_encounter(; output_directory=directory,
                environment_runner=root -> error("injected environment failure"),
                reference_runner=() -> error("reference must not run"))
            @test failed.exit_code == 1
            @test isempty(failed.series)
            @test isempty(failed.report_paths)
            @test length(failed.failures) == 1
            @test only(failed.failures).label == :close_encounter_parent_environment
            @test !isnothing(only(failed.failures).diagnostic_path)
            diagnostic_path = only(failed.failures).diagnostic_path
            @test isfile(diagnostic_path)
            @test all(filename -> !isfile(joinpath(directory, filename)),
                expected_filenames)

            runners = _close_workflow_runners(fixtures)
            successful = run_investigation_2_close_encounter(;
                output_directory=directory, environment,
                reference_runner=() -> reference,
                cartesian_runner=runners.cartesian,
                regularized_runner=runners.regularized,
                threshold_runner=runners.threshold)
            @test successful.exit_code == 0
            @test Tuple(series.series_id for series in successful.series) == expected_ids
            @test basename.(successful.report_paths) == expected_filenames
            @test length(successful.series) == length(successful.report_paths) == 5
            @test isempty(successful.failures)
            @test !isfile(diagnostic_path)
            @test readdir(evidence_directory) == [basename(unrelated_path)]
            @test read(unrelated_path) == unrelated_bytes

            invalid = run_investigation_2_close_encounter(; output_directory=directory,
                environment_runner=root -> :not_an_environment,
                reference_runner=() -> error("reference must not run"))
            @test invalid.exit_code == 1
            @test only(invalid.failures).label == :close_encounter_parent_environment
            invalid_diagnostic = only(invalid.failures).diagnostic_path
            @test isfile(invalid_diagnostic)
            ValidationFramework._clear_close_encounter_owned_outputs(directory)
            @test !isfile(invalid_diagnostic)
            @test read(unrelated_path) == unrelated_bytes
        end
    end

    @testset "group and reference failure reconciliation" begin
        mktempdir() do directory
            clean = _close_workflow_runners(fixtures)
            @test run_investigation_2_close_encounter(; output_directory=directory,
                environment, reference_runner=() -> reference,
                cartesian_runner=clean.cartesian,
                regularized_runner=clean.regularized,
                threshold_runner=clean.threshold).exit_code == 0

            failed = _close_workflow_runners(fixtures; fail_group=:regularized_tolerance)
            result = run_investigation_2_close_encounter(; output_directory=directory,
                environment, reference_runner=() -> reference,
                cartesian_runner=failed.cartesian,
                regularized_runner=failed.regularized,
                threshold_runner=failed.threshold)
            @test result.exit_code == 1
            @test Tuple(series.series_id for series in result.series) ==
                (expected_ids[1], expected_ids[4], expected_ids[5])
            @test !isfile(joinpath(directory, expected_filenames[2]))
            @test !isfile(joinpath(directory, expected_filenames[3]))
            @test isfile(joinpath(directory, expected_filenames[4]))
            @test length(result.failures) == 1
            @test !isnothing(only(result.failures).diagnostic_path)

            group_calls = Ref(0)
            blocking = (args...) -> (group_calls[] += 1; error("group must not run"))
            result = run_investigation_2_close_encounter(; output_directory=directory,
                environment, reference_runner=() -> error("reference unavailable"),
                cartesian_runner=blocking, regularized_runner=blocking,
                threshold_runner=blocking)
            @test result.exit_code == 1
            @test isempty(result.series)
            @test isempty(result.report_paths)
            @test group_calls[] == 0
            @test all(filename -> !isfile(joinpath(directory, filename)), expected_filenames)
            @test length(result.failures) == 1
            @test only(result.failures).label == :close_encounter_shared_reference
        end
    end

    @testset "persistence and operational evidence" begin
        mktempdir() do directory
            runners = _close_workflow_runners(fixtures)
            failing_writer = function(path, series)
                series.series_id == expected_ids[3] && error("injected atomic write failure")
                write_investigation_series_atomic(path, series)
            end
            result = run_investigation_2_close_encounter(; output_directory=directory,
                environment, reference_runner=() -> reference,
                cartesian_runner=runners.cartesian,
                regularized_runner=runners.regularized,
                threshold_runner=runners.threshold, series_writer=failing_writer)
            @test result.exit_code == 1
            @test Tuple(series.series_id for series in result.series) ==
                (expected_ids[1], expected_ids[2], expected_ids[4], expected_ids[5])
            @test !isfile(joinpath(directory, expected_filenames[3]))
            @test all(path -> basename(path) != expected_filenames[3], result.report_paths)
            @test any(failure -> failure.label == expected_ids[3] &&
                !isnothing(failure.diagnostic_path), result.failures)
        end

        configuration = close_encounter_cartesian_configuration(
            first(CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES))
        original = first(fixtures.cartesian.points)
        malformed_execution = ExecutionOutcome(actual_malformed_report; exit_code=7,
            summary="malformed performance report")
        malformed_report = synthetic_close_performance_report(configuration, environment;
            execution=malformed_execution)
        direct_execution = ExecutionOutcome(actual_errored; exit_code=9,
            summary="direct scientific error")
        altered_point = _close_workflow_point(original; execution=direct_execution,
            performance_report=malformed_report, notes=direct_execution.summary)
        altered_points = Base.setindex(fixtures.cartesian.points, altered_point, 1)
        altered_series = _close_workflow_series(fixtures.cartesian; points=altered_points)

        mktempdir() do directory
            malformed_runner = function(reference, parent, work_directory, project_root)
                report_directory = joinpath(work_directory, "performance")
                mkpath(report_directory)
                open(joinpath(report_directory,
                    string(malformed_report.definition.benchmark_id, ".toml")), "w") do io
                    write(io, UInt8[0x00, 0x41, 0xff, 0x0a])
                end
                altered_series
            end
            runners = _close_workflow_runners(fixtures;
                cartesian_series=altered_series)
            result = run_investigation_2_close_encounter(; output_directory=directory,
                environment, reference_runner=() -> reference,
                cartesian_runner=malformed_runner,
                regularized_runner=runners.regularized,
                threshold_runner=runners.threshold)
            relevant = filter(failure -> startswith(string(failure.label),
                string(expected_ids[1], "__")), result.failures)
            @test result.exit_code == 1
            @test length(relevant) == 2
            @test count(failure -> endswith(string(failure.label), "__direct"),
                relevant) == 1
            @test count(failure -> endswith(string(failure.label), "__performance"),
                relevant) == 1
            malformed = only(filter(failure ->
                failure.outcome == actual_malformed_report, relevant))
            @test read(malformed.raw_report_path) == UInt8[0x00, 0x41, 0xff, 0x0a]
            retained = only(filter(series -> series.series_id == expected_ids[1], result.series))
            @test length(first(retained.points).metrics) == length(original.metrics)

            clean = _close_workflow_runners(fixtures)
            @test run_investigation_2_close_encounter(; output_directory=directory,
                environment, reference_runner=() -> reference,
                cartesian_runner=clean.cartesian,
                regularized_runner=clean.regularized,
                threshold_runner=clean.threshold).exit_code == 0
            evidence_directory = joinpath(directory,
                ValidationFramework.CLOSE_ENCOUNTER_OPERATIONAL_EVIDENCE_DIRECTORY)
            @test !isdir(evidence_directory) || isempty(readdir(evidence_directory))
        end

        missing_execution = ExecutionOutcome(actual_missing_report; exit_code=8,
            summary="missing performance report")
        missing_report = synthetic_close_performance_report(configuration, environment;
            execution=missing_execution)
        missing_point = _close_workflow_point(original; execution=missing_execution,
            performance_report=missing_report, notes=missing_execution.summary)
        missing_series = _close_workflow_series(fixtures.cartesian;
            points=Base.setindex(fixtures.cartesian.points, missing_point, 1))
        mktempdir() do directory
            runners = _close_workflow_runners(fixtures;
                cartesian_series=missing_series)
            result = run_investigation_2_close_encounter(; output_directory=directory,
                environment, reference_runner=() -> reference,
                cartesian_runner=runners.cartesian,
                regularized_runner=runners.regularized,
                threshold_runner=runners.threshold)
            failure = only(filter(item -> item.outcome == actual_missing_report,
                result.failures))
            @test result.exit_code == 1
            @test isnothing(failure.raw_report_path)
            @test isnothing(failure.diagnostic_path)
            @test length(first(result.series).points[1].metrics) == length(original.metrics)
        end
    end

    @testset "CLI rejects excess arguments" begin
        project_root = normpath(joinpath(@__DIR__, "..", ".."))
        script = joinpath(project_root, "examples", "validation",
            "run_investigation_2_close_encounter.jl")
        command = `$(Base.julia_cmd()) --project=$project_root $script first second`
        process = run(pipeline(ignorestatus(command), stdout=devnull, stderr=devnull))
        @test process.exitcode == 2
    end
end
