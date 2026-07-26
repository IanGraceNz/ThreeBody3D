# Warm-up and retained-sample measurement helpers for performance benchmarks.

"""Optional structured observations returned by one benchmark operation."""
struct PerformanceObservation
    solver_statistics::Union{Nothing,SolverStatistics}
    saved_states::Union{Nothing,Int}
    measurements::Tuple{Vararg{AbstractValidationMetric}}

    function PerformanceObservation(;
        solver_statistics=nothing,
        saved_states=nothing,
        measurements=(),
    )
        isnothing(solver_statistics) || solver_statistics isa SolverStatistics || throw(
            ArgumentError("solver_statistics must be a SolverStatistics record or nothing."),
        )
        isnothing(saved_states) || (saved_states isa Integer && saved_states >= 0) || throw(
            ArgumentError("saved_states must be a nonnegative integer or nothing."),
        )
        normalized_measurements = Tuple(measurements)
        all(metric -> metric isa AbstractValidationMetric, normalized_measurements) || throw(
            ArgumentError("measurements must contain validation metric records."),
        )
        all(metric -> metric.role in (role_performance, role_descriptive), normalized_measurements) || throw(
            ArgumentError("Performance observations may contain only descriptive or performance metrics."),
        )
        _unique_identifiers(map(metric -> metric.metric_id, normalized_measurements), "measurements")
        new(
            solver_statistics,
            isnothing(saved_states) ? nothing : Int(saved_states),
            normalized_measurements,
        )
    end
end

PerformanceObservation(::Nothing) = PerformanceObservation()
PerformanceObservation(observation::PerformanceObservation) = observation

"""Retained outcome of one warm-up and sample measurement sequence."""
struct PerformanceMeasurementResult
    samples::Tuple{Vararg{PerformanceSample}}
    execution::ExecutionOutcome

    function PerformanceMeasurementResult(samples, execution::ExecutionOutcome)
        normalized_samples = Tuple(samples)
        all(sample -> sample isa PerformanceSample, normalized_samples) || throw(
            ArgumentError("samples must contain PerformanceSample records."),
        )
        map(sample -> sample.sample_index, normalized_samples) == Tuple(1:length(normalized_samples)) || throw(
            ArgumentError("Measured sample indices must be positive and contiguous."),
        )
        new(normalized_samples, execution)
    end
end

function _timed_allocation_count(gcstats)
    names = (:malloc, :realloc, :poolalloc, :bigalloc)
    all(name -> hasproperty(gcstats, name), names) || return nothing
    values = map(name -> getproperty(gcstats, name), names)
    all(value -> value isa Integer && value >= 0, values) || return nothing
    sum(Int, values)
end

function _default_performance_collector(operation)
    timed = @timed operation()
    (
        value=timed.value,
        elapsed_seconds=Float64(timed.time),
        allocated_bytes=Int(timed.bytes),
        allocation_count=_timed_allocation_count(timed.gcstats),
        gc_seconds=Float64(timed.gctime),
    )
end

function _collector_field(measurement, name::Symbol)
    hasproperty(measurement, name) || throw(ArgumentError(
        "Performance collector result is missing field $name.",
    ))
    getproperty(measurement, name)
end

function _requested_collector_field(measurement, name::Symbol, requested::Bool)
    requested || return nothing
    value = _collector_field(measurement, name)
    isnothing(value) && throw(ArgumentError(
        "Requested performance measurement $name is unavailable on this runtime.",
    ))
    value
end

"""
    measure_performance_sample(operation, sample_index, policy; collector=...)

Execute one retained sample. `operation` may return `nothing` or a
`PerformanceObservation`. Timing instrumentation is supplied by `collector`,
which is injectable so protocol tests need not rely on wall-clock behaviour.
"""
function measure_performance_sample(
    operation,
    sample_index::Integer,
    policy::PerformanceMeasurementPolicy;
    collector=_default_performance_collector,
)
    measurement = collector(operation)
    observation = PerformanceObservation(_collector_field(measurement, :value))
    PerformanceSample(
        sample_index;
        elapsed_seconds=_requested_collector_field(
            measurement, :elapsed_seconds, policy.collect_elapsed_time,
        ),
        allocated_bytes=_requested_collector_field(
            measurement, :allocated_bytes, policy.collect_allocated_bytes,
        ),
        allocation_count=_requested_collector_field(
            measurement, :allocation_count, policy.collect_allocation_count,
        ),
        gc_seconds=_requested_collector_field(
            measurement, :gc_seconds, policy.collect_gc_time,
        ),
        solver_statistics=observation.solver_statistics,
        saved_states=observation.saved_states,
        measurements=observation.measurements,
    )
end

function _failure_summary(stage::AbstractString, error)
    message = sprint(showerror, error)
    "$stage failed: $message"
end

"""
    run_performance_measurements(operation, policy; collector=..., gc_collect=GC.gc)

Run all warm-ups, discard their outputs, then retain sequential samples. Any
exception becomes an errored `ExecutionOutcome`; already completed samples are
retained for diagnosis. This helper performs no rendering or serialization.
"""
function run_performance_measurements(
    operation,
    policy::PerformanceMeasurementPolicy;
    collector=_default_performance_collector,
    gc_collect=GC.gc,
)
    started = time_ns()
    samples = PerformanceSample[]

    for warmup_index in 1:policy.warmup_runs
        try
            operation()
        catch error
            elapsed = (time_ns() - started) / 1.0e9
            return PerformanceMeasurementResult(
                (),
                ExecutionOutcome(
                    actual_errored;
                    exit_code=1,
                    elapsed_seconds=elapsed,
                    summary=_failure_summary("Warm-up $warmup_index", error),
                ),
            )
        end
    end

    for sample_index in 1:policy.sample_runs
        try
            policy.garbage_collection_before_sample && gc_collect()
            push!(samples, measure_performance_sample(
                operation,
                sample_index,
                policy;
                collector=collector,
            ))
        catch error
            elapsed = (time_ns() - started) / 1.0e9
            return PerformanceMeasurementResult(
                Tuple(samples),
                ExecutionOutcome(
                    actual_errored;
                    exit_code=1,
                    elapsed_seconds=elapsed,
                    summary=_failure_summary("Sample $sample_index", error),
                ),
            )
        end
    end

    elapsed = (time_ns() - started) / 1.0e9
    PerformanceMeasurementResult(
        Tuple(samples),
        ExecutionOutcome(actual_completed; exit_code=0, elapsed_seconds=elapsed),
    )
end
