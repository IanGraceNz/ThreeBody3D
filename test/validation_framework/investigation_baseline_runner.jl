function _baseline_test_process(label, exit_code=0, message="")
    InvestigationProcessRecord(label, 0.25, exit_code, message)
end

@testset "Baseline child operational evidence" begin
    mktempdir() do directory
        environment = performance_test_environment()
        path = joinpath(directory, "synthetic.jl")
        write(path, "# synthetic\n")
        observed = Symbol[]
        valid_runner = function(command, label)
            push!(observed, label)
            profile = label == :figure_eight_fast ? :fast : :accurate
            report = _figure_eight_case_result(profile; environment)
            write_report_atomic(joinpath(directory, string(label) * ".toml"), report)
            _baseline_test_process(label)
        end
        fast = ValidationFramework._run_baseline_case(
            path, :figure_eight, environment, directory;
            point=:fast, process_runner=valid_runner,
        )
        accurate = ValidationFramework._run_baseline_case(
            path, :figure_eight, environment, directory;
            point=:accurate, process_runner=valid_runner,
        )
        @test observed == [:figure_eight_fast, :figure_eight_accurate]
        @test isnothing(fast.failure)
        @test isnothing(accurate.failure)

        terminated = ExecutionOutcome(
            actual_terminated; exit_code=1, summary="Scientific termination.",
        )
        nonzero_runner = function(command, label)
            report = _figure_eight_case_result(:fast; environment, execution=terminated)
            write_report_atomic(joinpath(directory, string(label) * ".toml"), report)
            _baseline_test_process(label, 1, "scientific termination")
        end
        nonzero = ValidationFramework._run_baseline_case(
            path, :figure_eight, environment, directory;
            point=:fast_nonzero, process_runner=nonzero_runner,
        )
        @test isnothing(nonzero.failure)
        @test nonzero.result.execution.actual == actual_terminated

        missing = ValidationFramework._run_baseline_case(
            path, :figure_eight, environment, joinpath(directory, "missing");
            point=:fast,
            process_runner=(command, label) -> _baseline_test_process(label, 7, "child failed"),
        )
        @test missing.failure.outcome == actual_missing_report
        @test missing.failure.exit_code == 7
        @test occursin("child failed", missing.failure.message)

        malformed_directory = joinpath(directory, "malformed")
        mkpath(malformed_directory)
        malformed_runner = function(command, label)
            write(joinpath(malformed_directory, string(label) * ".toml"), "bad = [toml")
            _baseline_test_process(label)
        end
        malformed = ValidationFramework._run_baseline_case(
            path, :figure_eight, environment, malformed_directory;
            point=:fast, process_runner=malformed_runner,
        )
        @test malformed.failure.outcome == actual_malformed_report
        @test !isnothing(malformed.failure.raw_report_path)

        mismatch_directory = joinpath(directory, "mismatch")
        mkpath(mismatch_directory)
        mismatch_runner = function(command, label)
            write_report_atomic(
                joinpath(mismatch_directory, string(label) * ".toml"),
                _figure_eight_case_result(:fast; environment),
            )
            _baseline_test_process(label, 1, "unexpected exit")
        end
        mismatch = ValidationFramework._run_baseline_case(
            path, :figure_eight, environment, mismatch_directory;
            point=:fast, process_runner=mismatch_runner,
        )
        @test mismatch.failure.outcome == actual_malformed_report
        @test occursin("exit code", lowercase(mismatch.failure.message))
    end
end

@testset "Earlier baseline series survive a later operational failure" begin
    environment = performance_test_environment()
    suite, results = _figure_eight_investigation_inputs()
    completed = figure_eight_profile_investigation_series(suite, results)
    failure = InvestigationOperationalFailure(
        :hierarchical_triple_fast, actual_missing_report, 9,
        "Later child report missing.", nothing,
    )
    failed = ValidationFramework._series_operational_failure(
        :close_encounter, environment, failure,
    )
    mktempdir() do directory
        completed_path = write_investigation_series_atomic(
            joinpath(directory, "completed.toml"), completed,
        )
        failed_path = write_investigation_series_atomic(
            joinpath(directory, "failed.toml"), failed,
        )
        @test isfile(completed_path)
        @test isfile(failed_path)
        @test all(point -> point.execution.actual == actual_missing_report, failed.points)
        @test all(point -> point.execution.exit_code == 9, failed.points)
    end
end

function _baseline_command_environment(command)
    Dict(begin
        key, value = split(item, "="; limit=2)
        key => value
    end for item in something(command.env, String[]))
end

function _baseline_synthetic_performance_report(entry, environment)
    samples = Tuple(begin
        measurements = Tuple(ValidationMetric(
            measurement, replace(string(measurement), '_' => ' '),
            measurement == :minimum_pair_separation ? 0.75 : 1.0e-10;
            role=role_descriptive,
        ) for measurement in entry.definition.required_measurements if measurement ∉ (
            :elapsed_time, :allocated_bytes, :allocation_count, :gc_time,
            :solver_statistics, :saved_states,
        ))
        PerformanceSample(
            index; elapsed_seconds=0.1 * index,
            solver_statistics=SolverStatistics(
                accepted_steps=100, rejected_steps=2, rhs_evaluations=800,
                saved_states=315,
            ),
            saved_states=315, measurements,
        )
    end for index in 1:entry.policy.sample_runs)
    build_performance_benchmark_report(
        entry.definition, environment, entry.configuration, entry.policy, samples,
        ExecutionOutcome(actual_completed; exit_code=0),
    )
end

function _baseline_close_series()
    result, reports = _close_investigation_inputs()
    close_encounter_representation_investigation_series(result, reports)
end

function _baseline_ks_series()
    result = _ks_investigation_result()
    samples = ValidationFramework.ThreeBody3D.ExperimentalSwitchingSamples(
        [0.0, 1.6], [zeros(18), ones(18)],
    )
    vector = (0.0, 0.0, 0.0)
    diagnostics = ValidationFramework.ThreeBody3D.ExperimentalSwitchingDiagnosticsReport(
        1.0, 1.0, 1e-12, 2e-13, 3e-13, 4e-13, 5e-13, 0.1,
        vector, vector, vector, vector, 2, 1, 0,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    )
    backend_report = backend -> ValidationFramework.KSSwitchingBackendReport(
        backend, result.definition, result.configuration, result.environment,
        ExecutionOutcome(actual_completed; exit_code=0), 1.6, samples, diagnostics,
        SolverStatistics(
            accepted_steps=10, rejected_steps=1, rhs_evaluations=70,
            saved_states=2, segment_count=1, switch_count=0,
        ), (), (), backend == :ks ? 1e-9 : 1.1e-9, nothing, nothing,
    )
    ks = backend_report(:ks)
    levi_civita = backend_report(:levi_civita)
    ks_switching_backend_investigation_series(result, (levi_civita, ks))
end

@testset "Child investigation contract validation" begin
    environment = performance_test_environment()
    process = _baseline_test_process(:synthetic_child)
    execution = (; process, failure=nothing)
    close = _baseline_close_series()
    ks = _baseline_ks_series()
    mktempdir() do directory
        wrong_family_path = write_investigation_series_atomic(
            joinpath(directory, "wrong-family.toml"), ks,
        )
        rejected, failure = ValidationFramework._read_child_series(
            wrong_family_path, :close_encounter, environment, execution,
        )
        @test failure.outcome == actual_malformed_report
        @test rejected.series_id == :close_encounter_representation
        @test isempty(first(rejected.points).metrics)

        reordered = InvestigationMeasurementSeries(
            close.series_id, close.title, close.description, close.definition,
            reverse(close.points),
        )
        reordered_path = write_investigation_series_atomic(
            joinpath(directory, "reordered.toml"), reordered,
        )
        _, reordered_failure = ValidationFramework._read_child_series(
            reordered_path, :close_encounter, environment, execution,
        )
        @test reordered_failure.outcome == actual_malformed_report

        point = close.points[1]
        wrong_value = InvestigationMeasurementPoint(
            point.point_id, point.definition, point.configuration,
            ValidationParameter(point.definition.independent_variable, :wrong_value),
            point.environment, point.execution, point.metrics, point.solver_statistics;
            supporting_evidence=point.supporting_evidence, notes=point.notes,
        )
        wrong_independent = InvestigationMeasurementSeries(
            close.series_id, close.title, close.description, close.definition,
            (wrong_value, close.points[2:end]...),
        )
        wrong_value_path = write_investigation_series_atomic(
            joinpath(directory, "wrong-value.toml"), wrong_independent,
        )
        _, value_failure = ValidationFramework._read_child_series(
            wrong_value_path, :close_encounter, environment, execution,
        )
        @test value_failure.outcome == actual_malformed_report
    end
end

@testset "Complete baseline orchestration preserves partial evidence" begin
    environment = performance_test_environment()
    observed = Symbol[]
    mktempdir() do output
        performance_runner = function(command, entry)
            child_environment = ValidationEnvironment(
                environment.schema_version, environment.package_version,
                environment.repository_commit, environment.repository_dirty,
                environment.julia_version, environment.operating_system,
                environment.architecture, environment.thread_count,
                environment.timestamp_utc,
            )
            report = _baseline_synthetic_performance_report(entry, child_environment)
            report_path = _baseline_command_environment(command)[PERFORMANCE_REPORT_ENV]
            write_report_atomic(report_path, report)
            PerformanceProcessRecord(entry, 0.01, 0)
        end
        case_runner = function(command, label)
            push!(observed, label)
            env = _baseline_command_environment(command)
            if label == :close_encounter_comparison
                occurrence = count(==(label), observed)
                if occurrence == 1
                    write_investigation_series_atomic(
                        env[ValidationFramework.INVESTIGATION_SERIES_REPORT_ENV],
                        _baseline_close_series(),
                    )
                    return _baseline_test_process(label, 31, "Injected missing case report.")
                end
                write(env[VALIDATION_REPORT_ENV], "bad = [case")
                write(env[ValidationFramework.INVESTIGATION_SERIES_REPORT_ENV], "bad = [series")
                return _baseline_test_process(label, 0, "Injected malformed second execution.")
            end
            result = if label == :figure_eight_fast
                _figure_eight_case_result(:fast; environment)
            elseif label == :figure_eight_accurate
                _figure_eight_case_result(:accurate; environment)
            elseif label == :hierarchical_triple_fast
                _hierarchical_case_result(:fast; environment)
            elseif label == :hierarchical_triple_accurate
                _hierarchical_case_result(:accurate; environment)
            else
                @assert label == :ks_switching_comparison
                if count(==(label), observed) == 1
                    write(env[VALIDATION_REPORT_ENV], "bad = [case")
                    write_investigation_series_atomic(
                        env[ValidationFramework.INVESTIGATION_SERIES_REPORT_ENV],
                        _baseline_ks_series(),
                    )
                    return _baseline_test_process(label)
                end
                _build_ks_switching_comparison_case()
            end
            write_report_atomic(env[VALIDATION_REPORT_ENV], result)
            if label == :ks_switching_comparison
                write_investigation_series_atomic(
                    env[ValidationFramework.INVESTIGATION_SERIES_REPORT_ENV],
                    _baseline_ks_series(),
                )
            end
            _baseline_test_process(label, validation_exit_code(result))
        end

        result = run_investigation_1_baseline(
            output; environment, policy=StandardBenchmark(),
            case_process_runner=case_runner,
            performance_process_runner=performance_runner,
        )
        declared_order = (
            :figure_eight_fast, :figure_eight_accurate,
            :hierarchical_triple_fast, :hierarchical_triple_accurate,
            :close_encounter_comparison, :ks_switching_comparison,
        )
        @test observed == collect((declared_order..., declared_order...))
        @test map(series -> series.series_id, result.series) == (
            :figure_eight_profile, :hierarchical_triple_profile,
            :close_encounter_representation, :ks_switching_backend,
        )
        @test all(point -> point.execution.actual == actual_completed, result.series[1].points)
        close = result.series[3]
        @test all(point -> !isempty(point.metrics), close.points)
        @test all(point -> !isnothing(point.solver_statistics), close.points)
        @test all(point -> point.execution.actual == actual_missing_report, close.points)
        @test all(point -> occursin("retained child-series point status", point.notes), close.points)
        ks = result.series[4]
        @test all(point -> point.execution.actual == actual_malformed_report, ks.points)
        @test all(point -> point.supporting_evidence isa
            ValidationFramework.KSSwitchingBackendReport, ks.points)
        @test all(point -> point.supporting_evidence.execution.actual == actual_completed, ks.points)
        @test all(isfile, result.report_paths)
        @test length(unique(result.report_paths)) == 4
        @test basename.(result.report_paths) == (
            "figure_eight_profile.toml", "hierarchical_triple_profile.toml",
            "close_encounter_representation.toml", "ks_switching_backend.toml",
        )
        @test isfile(result.markdown_path)
        @test result.exit_code != 0
        @test !result.reproducibility.passed
        @test any(message -> occursin("execution incomplete", lowercase(message)),
            result.reproducibility.mismatches)
        second_evidence = joinpath(output, "operational_evidence", "second_execution")
        @test isdir(second_evidence)
        @test length(readdir(second_evidence)) >= 2
        @test any(name -> occursin("close_encounter_comparison", name), readdir(second_evidence))
        @test any(name -> occursin("close_encounter_representation", name), readdir(second_evidence))
    end
end
