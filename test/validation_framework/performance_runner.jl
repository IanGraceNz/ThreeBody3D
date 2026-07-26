function _performance_runner_environment(timestamp="2026-07-26T10:00:00Z")
    ValidationEnvironment(
        "1.0.0", "0.5.0", "89101df", false, "1.12.5", "Windows", "x86_64", 1,
        timestamp,
    )
end

function _performance_runner_definition(id=:synthetic_performance)
    PerformanceBenchmarkDefinition(
        id,
        "Synthetic performance benchmark",
        "Synthetic benchmark used to test isolated suite orchestration.",
        "examples/validation/performance/synthetic.jl",
        (:synthetic,),
        (:performance_runner,),
        "1.0.0",
        (:elapsed_time,),
    )
end

function _performance_runner_report(definition, environment, configuration, policy)
    samples = Tuple(
        PerformanceSample(index; elapsed_seconds=0.1 * index) for index in 1:policy.sample_runs
    )
    build_performance_benchmark_report(
        definition,
        environment,
        configuration,
        policy,
        samples,
        ExecutionOutcome(actual_completed; exit_code=0, elapsed_seconds=0.5),
    )
end

@testset "Performance benchmark registry entries" begin
    definition = _performance_runner_definition()
    configuration = ValidationConfiguration()
    policy = StandardBenchmark()
    entry = PerformanceBenchmarkEntry(definition, configuration, policy, @__FILE__)

    @test entry.definition === definition
    @test entry.configuration === configuration
    @test entry.policy === policy
    @test isabspath(entry.path)
    @test_throws ArgumentError PerformanceBenchmarkEntry(
        definition,
        configuration,
        QuickBenchmark(),
        @__FILE__,
    )

    record = PerformanceProcessRecord(entry, 1.25, 0, "complete")
    @test record.elapsed_seconds == 1.25
    @test record.exit_code == 0
    @test record.message == "complete"
    @test_throws ArgumentError PerformanceProcessRecord(entry, -1.0, 0)
end

@testset "Process-isolated performance entry execution" begin
    mktempdir() do directory
        script = joinpath(directory, "synthetic.jl")
        write(script, "# synthetic child script\n")
        report_directory = joinpath(directory, "reports")
        definition = _performance_runner_definition()
        configuration = ValidationConfiguration()
        policy = StandardBenchmark()
        entry = PerformanceBenchmarkEntry(definition, configuration, policy, script)
        suite_environment = _performance_runner_environment()
        child_environment = _performance_runner_environment("2026-07-26T10:00:01Z")
        child_report = _performance_runner_report(
            definition, child_environment, configuration, policy,
        )

        process_runner = function(command, requested_entry)
            @test requested_entry === entry
            write_report_atomic(
                joinpath(report_directory, "synthetic_performance.toml"),
                child_report,
            )
            PerformanceProcessRecord(requested_entry, 1.5, 0)
        end

        report, process = run_performance_entry(
            entry,
            suite_environment,
            report_directory;
            project_root=directory,
            process_runner,
        )
        @test report.execution.actual == actual_completed
        @test ValidationFramework._record_fields_equal(report.environment, suite_environment)
        @test collect(map(sample -> sample.elapsed_seconds, report.samples)) ≈
              collect(map(sample -> sample.elapsed_seconds, child_report.samples))
        @test process.elapsed_seconds == 1.5
    end
end

@testset "Missing and malformed performance child reports" begin
    mktempdir() do directory
        script = joinpath(directory, "synthetic.jl")
        write(script, "# synthetic child script\n")
        definition = _performance_runner_definition()
        configuration = ValidationConfiguration()
        policy = StandardBenchmark()
        entry = PerformanceBenchmarkEntry(definition, configuration, policy, script)
        environment = _performance_runner_environment()

        missing_runner = (command, requested_entry) ->
            PerformanceProcessRecord(requested_entry, 0.25, 1, "child failed")
        missing, process = run_performance_entry(
            entry,
            environment,
            joinpath(directory, "missing");
            project_root=directory,
            process_runner=missing_runner,
        )
        @test missing.execution.actual == actual_missing_report
        @test occursin("did not write", something(missing.execution.summary))
        @test isempty(missing.samples)
        @test process.exit_code == 1

        malformed_directory = joinpath(directory, "malformed")
        malformed_runner = function(command, requested_entry)
            mkpath(malformed_directory)
            write(joinpath(malformed_directory, "synthetic_performance.toml"), "not = [valid")
            PerformanceProcessRecord(requested_entry, 0.3, 0)
        end
        malformed, _ = run_performance_entry(
            entry,
            environment,
            malformed_directory;
            project_root=directory,
            process_runner=malformed_runner,
        )
        @test malformed.execution.actual == actual_malformed_report
        @test isempty(malformed.samples)

        mismatch_directory = joinpath(directory, "mismatch")
        mismatch_runner = function(command, requested_entry)
            write_report_atomic(
                joinpath(mismatch_directory, "synthetic_performance.toml"),
                _performance_runner_report(
                    definition, environment, configuration, policy,
                ),
            )
            PerformanceProcessRecord(requested_entry, 0.35, 1, "unexpected exit")
        end
        mismatch, _ = run_performance_entry(
            entry,
            environment,
            mismatch_directory;
            project_root=directory,
            process_runner=mismatch_runner,
        )
        @test mismatch.execution.actual == actual_malformed_report
        @test occursin("exit code", something(mismatch.execution.summary))

        absent_entry = PerformanceBenchmarkEntry(
            definition,
            configuration,
            policy,
            joinpath(directory, "absent.jl"),
        )
        absent, absent_process = run_performance_entry(
            absent_entry,
            environment,
            joinpath(directory, "absent_reports");
            project_root=directory,
            process_runner=missing_runner,
        )
        @test absent.execution.actual == actual_missing_report
        @test absent_process.elapsed_seconds == 0.0
    end
end

@testset "Sequential performance suite orchestration" begin
    mktempdir() do directory
        environment = _performance_runner_environment()
        configuration = ValidationConfiguration()
        policy = StandardBenchmark()
        entries = map((:first_performance, :second_performance)) do id
            script = joinpath(directory, string(id) * ".jl")
            write(script, "# synthetic child script\n")
            PerformanceBenchmarkEntry(
                _performance_runner_definition(id),
                configuration,
                policy,
                script,
            )
        end
        observed = Symbol[]
        report_directory = joinpath(directory, "reports")
        process_runner = function(command, entry)
            push!(observed, entry.definition.benchmark_id)
            child_environment = _performance_runner_environment("2026-07-26T10:00:01Z")
            report = _performance_runner_report(
                entry.definition,
                child_environment,
                entry.configuration,
                entry.policy,
            )
            write_report_atomic(
                joinpath(report_directory, string(entry.definition.benchmark_id) * ".toml"),
                report,
            )
            PerformanceProcessRecord(entry, length(observed) / 10, 0)
        end

        suite_path = joinpath(directory, "performance_suite.toml")
        result = run_performance_suite(
            entries;
            environment,
            report_directory,
            project_root=directory,
            process_runner,
            report_path=suite_path,
        )
        @test observed == [:first_performance, :second_performance]
        @test map(report -> report.definition.benchmark_id, result.suite.benchmarks) ==
              (:first_performance, :second_performance)
        @test performance_suite_complete(result.suite)
        @test length(result.processes) == 2
        @test isfile(suite_path)
        restored = read_performance_suite(suite_path)
        @test map(report -> report.definition.benchmark_id, restored.benchmarks) ==
              (:first_performance, :second_performance)
        @test all(
            report -> ValidationFramework._record_fields_equal(report.environment, environment),
            result.suite.benchmarks,
        )

        @test_throws ArgumentError run_performance_suite((); environment)
        @test_throws ArgumentError run_performance_suite(
            (entries[1], entries[1]);
            environment,
            report_directory,
            project_root=directory,
            process_runner,
        )
    end
end
