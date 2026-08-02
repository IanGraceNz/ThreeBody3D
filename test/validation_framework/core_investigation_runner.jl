function _workflow_tolerance_series(family, algorithm, environment)
    executions = Tuple(_core_fixture_execution(family, algorithm, tolerance)
        for tolerance in CORE_TOLERANCE_VALUES)
    core_tolerance_investigation_series(
        _core_performance_suite(family, algorithm, environment),
        map(_core_attempt, executions))
end

function _workflow_duration_series(kind, family, environment)
    values = ValidationFramework._core_duration_sampling_values(kind, family)
    attempts = Tuple(_duration_sampling_attempt(
        _duration_sampling_observation(kind, family, value)) for value in values)
    core_duration_sampling_investigation_series(
        _duration_sampling_suite(kind, family, environment), attempts)
end

function _workflow_precision_series(assessment, environment)
    attempts = Tuple(_precision_attempt(_precision_fixture_evidence(bits))
        for bits in FIGURE_EIGHT_PRECISION_BITS)
    figure_eight_precision_investigation_series(
        assessment, _precision_suite(environment), attempts)
end

function _workflow_runners(environment, trigger_mode, calls, work_roots;
    fail_series=nothing, fail_precision=false, malformed=false, missing=false,
    direct_mode=nothing)
    tolerance_runner = function(family, algorithm, parent_environment, directory)
        @test parent_environment === environment
        push!(calls, (:tolerance, family, algorithm))
        push!(work_roots, dirname(directory))
        series_id = Symbol(family, :_, algorithm, :_tolerance)
        series_id == fail_series && error("injected mandatory failure")
        series = if family == :figure_eight && algorithm == :vern9
            trigger_mode == :triggered ? _precision_source_series(1.0, 1.0, 10.0, 1.0) :
            trigger_mode == :not_triggered ? _precision_source_series(2.0, 1.0, 10.0, 1.0) :
            _precision_source_series(1.0, 1.0, 10.0, 1.0;
                missing=[:periodicity_error])
        else
            _workflow_tolerance_series(family, algorithm, environment)
        end
        if (malformed || missing) && series_id == :figure_eight_tsit5_tolerance
            points = collect(series.points)
            point = points[1]
            outcome = malformed ? actual_malformed_report : actual_missing_report
            performance_execution = ExecutionOutcome(outcome; exit_code=7,
                summary=malformed ? "malformed child report" : "missing child report")
            execution = direct_mode == :terminated ? ExecutionOutcome(
                actual_terminated; exit_code=5, summary="direct scientific termination") :
                direct_mode == :errored ? ExecutionOutcome(
                    actual_errored; exit_code=9, summary="direct execution error") :
                performance_execution
            report = _core_performance_report(
                core_tolerance_configuration(family, algorithm, first(CORE_TOLERANCE_VALUES)),
                environment; execution=performance_execution)
            points[1] = InvestigationMeasurementPoint(point.point_id, series.definition,
                point.configuration, point.independent_value, point.environment, execution,
                point.metrics, point.solver_statistics; performance_report=report,
                notes=execution.summary)
            series = InvestigationMeasurementSeries(series.series_id, series.title,
                series.description, series.definition, Tuple(points))
            if malformed
                report_directory = joinpath(directory, "performance")
                mkpath(report_directory)
                open(joinpath(report_directory,
                    string(report.definition.benchmark_id, ".toml")), "w") do io
                    write(io, UInt8[0x00, 0x41, 0xff, 0x0a])
                end
            end
        end
        series
    end
    duration_runner = function(kind, family, parent_environment, directory)
        @test parent_environment === environment
        push!(calls, (kind, family, nothing))
        push!(work_roots, dirname(directory))
        series_id = Symbol(family, :_, kind)
        series_id == fail_series && error("injected mandatory failure")
        _workflow_duration_series(kind, family, environment)
    end
    precision_calls = Ref(0)
    precision_runner = function(assessment, parent_environment, directory)
        @test parent_environment === environment
        precision_calls[] += 1
        push!(work_roots, dirname(directory))
        fail_precision && error("injected precision failure")
        _workflow_precision_series(assessment, environment)
    end
    (; tolerance_runner, duration_runner, precision_runner, precision_calls)
end

@testset "Investigation 2 core orchestration" begin
    environment = _pilot_environment()
    expected_ids = Tuple(ValidationFramework._core_series_id(item...)
        for item in ValidationFramework.CORE_INVESTIGATION_SERIES_ORDER)
    expected_values = (
        CORE_TOLERANCE_VALUES, CORE_TOLERANCE_VALUES,
        CORE_TOLERANCE_VALUES, CORE_TOLERANCE_VALUES,
        CORE_DURATION_PERIODS, CORE_DURATION_VALUES,
        CORE_DIAGNOSTIC_SAVEATS, CORE_DIAGNOSTIC_SAVEATS,
    )

    @testset "complete not-triggered workflow" begin
        calls = Tuple{Symbol,Symbol,Any}[]
        roots = String[]
        runners = _workflow_runners(environment, :not_triggered, calls, roots)
        mktempdir() do directory
    @testset "parent provenance" begin
        observed = ValidationEnvironment[]
        failing_tolerance = (family, algorithm, parent, directory) -> begin
            push!(observed, parent)
            error("stop after provenance observation")
        end
        failing_duration = (kind, family, parent, directory) -> begin
            push!(observed, parent)
            error("stop after provenance observation")
        end
        mktempdir() do directory
            result = run_investigation_2_core(; output_directory=directory,
                project_root=normpath(joinpath(@__DIR__, "..", "..")),
                tolerance_runner=failing_tolerance,
                duration_sampling_runner=failing_duration)
            @test result.exit_code == 1
            @test length(observed) == 8
            @test all(item -> item === first(observed), observed)
            expected = ValidationFramework._baseline_environment(
                normpath(joinpath(@__DIR__, "..", "..")))
            @test first(observed).repository_commit == expected.repository_commit
            @test first(observed).repository_dirty == expected.repository_dirty
        end
    end

            result = run_investigation_2_core(; output_directory=directory,
                environment, tolerance_runner=runners.tolerance_runner,
                duration_sampling_runner=runners.duration_runner,
                precision_runner=runners.precision_runner)
            @test result.exit_code == 0
            @test result.trigger.status == :not_triggered
            @test runners.precision_calls[] == 0
            @test calls == collect(ValidationFramework.CORE_INVESTIGATION_SERIES_ORDER)
            @test map(series -> series.series_id, result.series) == expected_ids
            @test sum(length(series.points) for series in result.series) == 35
            for (series, values) in zip(result.series, expected_values)
                @test Tuple(point.independent_value.value for point in series.points) == values
                path = joinpath(directory, ValidationFramework._owned_series_filename(series.series_id))
                @test ValidationFramework._record_fields_equal(
                    read_investigation_series(path), series)
            end
            @test ValidationFramework._record_fields_equal(
                read_figure_eight_precision_trigger(joinpath(directory,
                    ValidationFramework.CORE_PRECISION_TRIGGER_FILENAME)), result.trigger)
            @test length(unique(roots)) == 1
            @test !startswith(only(unique(roots)), abspath(directory))
            expected_files = [ValidationFramework._owned_series_filename(id) for id in expected_ids]
            push!(expected_files, ValidationFramework.CORE_PRECISION_TRIGGER_FILENAME)
            @test Set(readdir(directory)) == Set(expected_files)
        end
    end

    @testset "trigger branches and stale precision reconciliation" begin
        mktempdir() do directory
            calls, roots = Tuple{Symbol,Symbol,Any}[], String[]
            triggered = _workflow_runners(environment, :triggered, calls, roots)
            first_result = run_investigation_2_core(; output_directory=directory,
                environment, tolerance_runner=triggered.tolerance_runner,
                duration_sampling_runner=triggered.duration_runner,
                precision_runner=triggered.precision_runner)
            precision_path = joinpath(directory,
                ValidationFramework._owned_series_filename(:figure_eight_precision_confirmation))
            @test first_result.exit_code == 0
            @test first_result.trigger.status == :triggered
            @test triggered.precision_calls[] == 1
            @test isfile(precision_path)
            @test read_investigation_series(precision_path).series_id ==
                :figure_eight_precision_confirmation

            not_triggered = _workflow_runners(environment, :not_triggered,
                Tuple{Symbol,Symbol,Any}[], String[])
            second_result = run_investigation_2_core(; output_directory=directory,
                environment, tolerance_runner=not_triggered.tolerance_runner,
                duration_sampling_runner=not_triggered.duration_runner,
                precision_runner=not_triggered.precision_runner)
            @test second_result.exit_code == 0
            @test second_result.trigger.status == :not_triggered
            @test not_triggered.precision_calls[] == 0
            @test !isfile(precision_path)

            unavailable = _workflow_runners(environment, :unavailable,
                Tuple{Symbol,Symbol,Any}[], String[])
            third_result = run_investigation_2_core(; output_directory=directory,
                environment, tolerance_runner=unavailable.tolerance_runner,
                duration_sampling_runner=unavailable.duration_runner,
                precision_runner=unavailable.precision_runner)
            @test third_result.exit_code == 1
            @test third_result.trigger.status == :unavailable
            @test unavailable.precision_calls[] == 0
            @test !isfile(precision_path)
        end
    end

    @testset "failed outputs cannot remain stale" begin
        mktempdir() do directory
            clean = _workflow_runners(environment, :triggered,
                Tuple{Symbol,Symbol,Any}[], String[])
            @test run_investigation_2_core(; output_directory=directory, environment,
                tolerance_runner=clean.tolerance_runner,
                duration_sampling_runner=clean.duration_runner,
                precision_runner=clean.precision_runner).exit_code == 0

            failed = _workflow_runners(environment, :triggered,
                Tuple{Symbol,Symbol,Any}[], String[];
                fail_series=:figure_eight_duration, fail_precision=true)
            result = run_investigation_2_core(; output_directory=directory, environment,
                tolerance_runner=failed.tolerance_runner,
                duration_sampling_runner=failed.duration_runner,
                precision_runner=failed.precision_runner)
            @test result.exit_code == 1
            @test !isfile(joinpath(directory,
                ValidationFramework._owned_series_filename(:figure_eight_duration)))
            @test !isfile(joinpath(directory,
                ValidationFramework._owned_series_filename(:figure_eight_precision_confirmation)))
            @test any(failure -> !isnothing(failure.diagnostic_path), result.failures)

            no_source = _workflow_runners(environment, :triggered,
                Tuple{Symbol,Symbol,Any}[], String[];
                fail_series=:figure_eight_vern9_tolerance)
            result = run_investigation_2_core(; output_directory=directory, environment,
                tolerance_runner=no_source.tolerance_runner,
                duration_sampling_runner=no_source.duration_runner,
                precision_runner=no_source.precision_runner)
            @test result.exit_code == 1
            @test isnothing(result.trigger)
            @test !isfile(joinpath(directory, ValidationFramework.CORE_PRECISION_TRIGGER_FILENAME))
        end
    end

    @testset "operational evidence retention and cleanup" begin
        mktempdir() do directory
            malformed = _workflow_runners(environment, :not_triggered,
                Tuple{Symbol,Symbol,Any}[], String[]; malformed=true)
            result = run_investigation_2_core(; output_directory=directory, environment,
                tolerance_runner=malformed.tolerance_runner,
                duration_sampling_runner=malformed.duration_runner,
                precision_runner=malformed.precision_runner)
            retained = only(filter(failure ->
                failure.outcome == actual_malformed_report, result.failures))
            @test result.exit_code == 1
            @test !isnothing(retained.raw_report_path)
            @test isnothing(retained.diagnostic_path)
            @test read(retained.raw_report_path) == UInt8[0x00, 0x41, 0xff, 0x0a]

            clean = _workflow_runners(environment, :not_triggered,
                Tuple{Symbol,Symbol,Any}[], String[])
            @test run_investigation_2_core(; output_directory=directory, environment,
                tolerance_runner=clean.tolerance_runner,
                duration_sampling_runner=clean.duration_runner,
                precision_runner=clean.precision_runner).exit_code == 0
            evidence_directory = joinpath(directory,
                ValidationFramework.CORE_OPERATIONAL_EVIDENCE_DIRECTORY)
            @test !isdir(evidence_directory) || isempty(readdir(evidence_directory))

            missing = _workflow_runners(environment, :not_triggered,
                Tuple{Symbol,Symbol,Any}[], String[]; missing=true)
            result = run_investigation_2_core(; output_directory=directory, environment,
                tolerance_runner=missing.tolerance_runner,
                duration_sampling_runner=missing.duration_runner,
                precision_runner=missing.precision_runner)
            retained = only(filter(failure ->
                failure.outcome == actual_missing_report, result.failures))
            @test result.exit_code == 1
            @test isnothing(retained.raw_report_path)
            @test isnothing(retained.diagnostic_path)
        end
    end

    @testset "independent direct and performance failures" begin
        mktempdir() do directory
            runners = _workflow_runners(environment, :not_triggered,
                Tuple{Symbol,Symbol,Any}[], String[]; malformed=true,
                direct_mode=:terminated)
            result = run_investigation_2_core(; output_directory=directory,
                environment, tolerance_runner=runners.tolerance_runner,
                duration_sampling_runner=runners.duration_runner,
                precision_runner=runners.precision_runner)
            series = only(filter(item ->
                item.series_id == :figure_eight_tsit5_tolerance, result.series))
            @test first(series.points).execution.actual == actual_terminated
            failures = filter(failure -> occursin("performance", string(failure.label)),
                result.failures)
            @test length(failures) == 1
            failure = only(failures)
            @test failure.outcome == actual_malformed_report
            @test failure.exit_code == 7
            @test !isnothing(failure.raw_report_path)
            @test read(failure.raw_report_path) == UInt8[0x00, 0x41, 0xff, 0x0a]
            @test result.exit_code == 1
        end

        mktempdir() do directory
            runners = _workflow_runners(environment, :not_triggered,
                Tuple{Symbol,Symbol,Any}[], String[]; missing=true,
                direct_mode=:errored)
            result = run_investigation_2_core(; output_directory=directory,
                environment, tolerance_runner=runners.tolerance_runner,
                duration_sampling_runner=runners.duration_runner,
                precision_runner=runners.precision_runner)
            relevant = filter(failure -> startswith(string(failure.label),
                "figure_eight_tsit5_tolerance__"), result.failures)
            @test length(relevant) == 2
            @test count(failure -> endswith(string(failure.label), "__direct"),
                relevant) == 1
            @test count(failure -> endswith(string(failure.label), "__performance"),
                relevant) == 1
            @test Set(failure.exit_code for failure in relevant) == Set((7, 9))
            @test all(failure -> isnothing(failure.raw_report_path), relevant)
            @test result.exit_code == 1
        end
    end

    @testset "precision persistence precedes retention" begin
        mktempdir() do directory
            runners = _workflow_runners(environment, :triggered,
                Tuple{Symbol,Symbol,Any}[], String[])
            precision_path = joinpath(directory,
                ValidationFramework._owned_series_filename(
                    :figure_eight_precision_confirmation))
            failing_writer = function(assessment, parent, work_directory)
                series = runners.precision_runner(assessment, parent, work_directory)
                mkpath(precision_path * ".tmp")
                series
            end
            result = run_investigation_2_core(; output_directory=directory,
                environment, tolerance_runner=runners.tolerance_runner,
                duration_sampling_runner=runners.duration_runner,
                precision_runner=failing_writer)
            @test result.exit_code == 1
            @test all(series -> series.series_id !=
                :figure_eight_precision_confirmation, result.series)
            @test all(path -> path != abspath(precision_path), result.report_paths)
            @test any(failure -> failure.label ==
                :figure_eight_precision_confirmation &&
                isnothing(failure.exit_code), result.failures)
        end
    end
end
