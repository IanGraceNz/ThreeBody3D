@testset "Performance observations" begin
    metric = ValidationMetric(:work, "Work", 12; scale=scale_count, role=role_performance)
    observation = PerformanceObservation(
        solver_statistics=SolverStatistics(rhs_evaluations=12),
        saved_states=4,
        measurements=(metric,),
    )
    @test observation.saved_states == 4
    @test observation.measurements == (metric,)
    @test PerformanceObservation(nothing).measurements == ()

    @test_throws ArgumentError PerformanceObservation(saved_states=-1)
    @test_throws ArgumentError PerformanceObservation(measurements=(
        ValidationMetric(:bad, "Bad", true; role=role_acceptance),
    ))
    @test_throws ArgumentError PerformanceObservation(measurements=(metric, metric))
end

function synthetic_collector_factory(records)
    calls = Ref(0)
    collector = function(operation)
        calls[] += 1
        value = operation()
        record = records[calls[]]
        merge((value=value,), record)
    end
    collector, calls
end

@testset "Single performance sample measurement" begin
    observation = PerformanceObservation(
        solver_statistics=SolverStatistics(accepted_steps=8, rhs_evaluations=40),
        saved_states=5,
        measurements=(ValidationMetric(
            :rhs_evaluations,
            "RHS evaluations",
            40;
            scale=scale_count,
            role=role_performance,
        ),),
    )
    collector, calls = synthetic_collector_factory((
        (elapsed_seconds=1.25, allocated_bytes=128, allocation_count=3, gc_seconds=0.05),
    ))
    policy = PerformanceMeasurementPolicy(
        warmup_runs=1,
        sample_runs=3,
        collect_elapsed_time=true,
        collect_allocated_bytes=true,
        collect_allocation_count=true,
        collect_gc_time=true,
    )
    sample = measure_performance_sample(() -> observation, 1, policy; collector=collector)
    @test calls[] == 1
    @test sample.sample_index == 1
    @test sample.elapsed_seconds == 1.25
    @test sample.allocated_bytes == 128
    @test sample.allocation_count == 3
    @test sample.gc_seconds == 0.05
    @test sample.saved_states == 5
    @test sample.solver_statistics.rhs_evaluations == 40

    timing_only, _ = synthetic_collector_factory((
        (elapsed_seconds=0.5, allocated_bytes=999, allocation_count=9, gc_seconds=0.2),
    ))
    quick_sample = measure_performance_sample(() -> nothing, 1, QuickBenchmark(); collector=timing_only)
    @test quick_sample.elapsed_seconds == 0.5
    @test quick_sample.allocated_bytes === nothing
    @test quick_sample.allocation_count === nothing
    @test quick_sample.gc_seconds === nothing
end

@testset "Warm-up and retained measurement protocol" begin
    operation_calls = Ref(0)
    operation = function()
        operation_calls[] += 1
        PerformanceObservation(saved_states=operation_calls[])
    end
    collector_calls = Ref(0)
    collector = function(operation)
        collector_calls[] += 1
        (
            value=operation(),
            elapsed_seconds=0.1 * collector_calls[],
            allocated_bytes=100 * collector_calls[],
            allocation_count=collector_calls[],
            gc_seconds=0.01 * collector_calls[],
        )
    end
    gc_calls = Ref(0)
    policy = PerformanceMeasurementPolicy(
        warmup_runs=2,
        sample_runs=3,
        collect_elapsed_time=true,
        collect_allocated_bytes=true,
        collect_allocation_count=true,
        collect_gc_time=true,
        garbage_collection_before_sample=true,
    )
    result = run_performance_measurements(
        operation,
        policy;
        collector=collector,
        gc_collect=() -> (gc_calls[] += 1),
    )
    @test result.execution.actual == actual_completed
    @test result.execution.exit_code == 0
    @test length(result.samples) == 3
    @test map(sample -> sample.sample_index, result.samples) == (1, 2, 3)
    @test collect(map(sample -> sample.elapsed_seconds, result.samples)) ≈ [0.1, 0.2, 0.3]
    @test map(sample -> sample.saved_states, result.samples) == (3, 4, 5)
    @test operation_calls[] == 5
    @test collector_calls[] == 3
    @test gc_calls[] == 3

    warmup_calls = Ref(0)
    warmup_failure = run_performance_measurements(
        () -> begin
            warmup_calls[] += 1
            error("warm-up fixture")
        end,
        QuickBenchmark();
        collector=collector,
    )
    @test warmup_failure.execution.actual == actual_errored
    @test isempty(warmup_failure.samples)
    @test occursin("Warm-up 1 failed", warmup_failure.execution.summary)

    retained_calls = Ref(0)
    sample_failure_collector = function(operation)
        retained_calls[] += 1
        retained_calls[] == 2 && error("sample fixture")
        (
            value=operation(),
            elapsed_seconds=0.25,
            allocated_bytes=0,
            allocation_count=0,
            gc_seconds=0.0,
        )
    end
    sample_failure = run_performance_measurements(
        () -> nothing,
        QuickBenchmark();
        collector=sample_failure_collector,
    )
    @test sample_failure.execution.actual == actual_errored
    @test length(sample_failure.samples) == 1
    @test occursin("Sample 2 failed", sample_failure.execution.summary)
end

@testset "Unavailable requested measurements become protocol errors" begin
    unavailable_collector = operation -> (
        value=operation(),
        elapsed_seconds=0.1,
        allocated_bytes=10,
        allocation_count=nothing,
        gc_seconds=0.0,
    )
    result = run_performance_measurements(
        () -> nothing,
        PublicationBenchmark();
        collector=unavailable_collector,
        gc_collect=() -> nothing,
    )
    @test result.execution.actual == actual_errored
    @test isempty(result.samples)
    @test occursin("allocation_count is unavailable", result.execution.summary)
end
