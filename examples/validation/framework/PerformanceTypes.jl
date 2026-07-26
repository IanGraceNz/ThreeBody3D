# Core immutable records for V5-V6 performance benchmarking. These records are
# deliberately separate from scientific validation status and criteria.

"""Stable metadata describing one repository performance benchmark."""
struct PerformanceBenchmarkDefinition
    benchmark_id::Symbol
    title::String
    description::String
    source_path::String
    classifications::Tuple{Vararg{Symbol}}
    tags::Tuple{Vararg{Symbol}}
    definition_version::String
    required_measurements::Tuple{Vararg{Symbol}}
    provenance::Union{Nothing,String}

    function PerformanceBenchmarkDefinition(
        benchmark_id,
        title,
        description,
        source_path,
        classifications,
        tags,
        definition_version,
        required_measurements,
        provenance=nothing,
    )
        normalized_classifications = Tuple(
            _validated_identifier(value, "classification") for value in classifications
        )
        normalized_tags = Tuple(_validated_identifier(value, "tag") for value in tags)
        normalized_measurements = Tuple(
            _validated_identifier(value, "required_measurement") for value in required_measurements
        )
        isempty(normalized_classifications) && throw(
            ArgumentError("At least one classification is required."),
        )
        isempty(normalized_measurements) && throw(
            ArgumentError("At least one required measurement is required."),
        )
        _unique_identifiers(normalized_classifications, "classifications")
        _unique_identifiers(normalized_tags, "tags")
        _unique_identifiers(normalized_measurements, "required_measurements")

        new(
            _validated_identifier(benchmark_id, "benchmark_id"),
            _nonempty_string(title, "title"),
            _nonempty_string(description, "description"),
            _validated_source_path(source_path),
            normalized_classifications,
            normalized_tags,
            _validated_version(definition_version, "definition_version"),
            normalized_measurements,
            isnothing(provenance) ? nothing : _nonempty_string(provenance, "provenance"),
        )
    end
end

"""Explicit warm-up, repetition, isolation, and measurement policy."""
struct PerformanceMeasurementPolicy
    warmup_runs::Int
    sample_runs::Int
    collect_elapsed_time::Bool
    collect_allocated_bytes::Bool
    collect_allocation_count::Bool
    collect_gc_time::Bool
    garbage_collection_before_sample::Bool
    process_isolation::Bool
    timing_clock::Symbol

    function PerformanceMeasurementPolicy(;
        warmup_runs::Integer,
        sample_runs::Integer,
        collect_elapsed_time::Bool,
        collect_allocated_bytes::Bool=false,
        collect_allocation_count::Bool=false,
        collect_gc_time::Bool=false,
        garbage_collection_before_sample::Bool=false,
        process_isolation::Bool=true,
        timing_clock=:monotonic,
    )
        warmup_runs >= 1 || throw(ArgumentError("warmup_runs must be at least one."))
        sample_runs >= 1 || throw(ArgumentError("sample_runs must be positive."))
        collect_elapsed_time && sample_runs < 3 && throw(
            ArgumentError("Elapsed-time measurement requires at least three samples."),
        )
        any((
            collect_elapsed_time,
            collect_allocated_bytes,
            collect_allocation_count,
            collect_gc_time,
        )) || throw(ArgumentError("At least one measurement must be collected."))
        normalized_clock = _validated_identifier(timing_clock, "timing_clock")
        collect_elapsed_time && normalized_clock != :monotonic && throw(
            ArgumentError("The initial elapsed-time clock must be monotonic."),
        )

        new(
            Int(warmup_runs),
            Int(sample_runs),
            collect_elapsed_time,
            collect_allocated_bytes,
            collect_allocation_count,
            collect_gc_time,
            garbage_collection_before_sample,
            process_isolation,
            normalized_clock,
        )
    end
end

"""Convenience policy for fast local structural checks."""
QuickBenchmark() = PerformanceMeasurementPolicy(
    warmup_runs=1,
    sample_runs=3,
    collect_elapsed_time=true,
    process_isolation=false,
)

"""Default policy for registered process-isolated benchmark suites."""
StandardBenchmark() = PerformanceMeasurementPolicy(
    warmup_runs=1,
    sample_runs=5,
    collect_elapsed_time=true,
    process_isolation=true,
)

"""Higher-repetition policy for deliberately retained benchmark evidence."""
PublicationBenchmark() = PerformanceMeasurementPolicy(
    warmup_runs=2,
    sample_runs=15,
    collect_elapsed_time=true,
    collect_allocated_bytes=true,
    collect_allocation_count=true,
    collect_gc_time=true,
    garbage_collection_before_sample=true,
    process_isolation=true,
)

function _optional_nonnegative_float(value, label::AbstractString)
    isnothing(value) && return nothing
    value isa Real || throw(ArgumentError("$label must be real or nothing."))
    isfinite(value) && value >= 0 || throw(
        ArgumentError("$label must be finite and nonnegative."),
    )
    Float64(value)
end

function _optional_nonnegative_int(value, label::AbstractString)
    isnothing(value) && return nothing
    value isa Integer || throw(ArgumentError("$label must be an integer or nothing."))
    value >= 0 || throw(ArgumentError("$label must be nonnegative."))
    Int(value)
end

"""One retained post-warm-up performance observation."""
struct PerformanceSample
    sample_index::Int
    elapsed_seconds::Union{Nothing,Float64}
    allocated_bytes::Union{Nothing,Int}
    allocation_count::Union{Nothing,Int}
    gc_seconds::Union{Nothing,Float64}
    solver_statistics::Union{Nothing,SolverStatistics}
    saved_states::Union{Nothing,Int}
    measurements::Tuple{Vararg{AbstractValidationMetric}}

    function PerformanceSample(
        sample_index::Integer;
        elapsed_seconds=nothing,
        allocated_bytes=nothing,
        allocation_count=nothing,
        gc_seconds=nothing,
        solver_statistics=nothing,
        saved_states=nothing,
        measurements=(),
    )
        sample_index > 0 || throw(ArgumentError("sample_index must be positive."))
        isnothing(solver_statistics) || solver_statistics isa SolverStatistics || throw(
            ArgumentError("solver_statistics must be a SolverStatistics record or nothing."),
        )
        normalized_measurements = Tuple(measurements)
        all(metric -> metric isa AbstractValidationMetric, normalized_measurements) || throw(
            ArgumentError("measurements must contain validation metric records."),
        )
        all(metric -> metric.role in (role_performance, role_descriptive), normalized_measurements) || throw(
            ArgumentError("Performance-sample metrics must be descriptive or performance metrics."),
        )
        metric_ids = map(metric -> metric.metric_id, normalized_measurements)
        _unique_identifiers(metric_ids, "measurements")

        new(
            Int(sample_index),
            _optional_nonnegative_float(elapsed_seconds, "elapsed_seconds"),
            _optional_nonnegative_int(allocated_bytes, "allocated_bytes"),
            _optional_nonnegative_int(allocation_count, "allocation_count"),
            _optional_nonnegative_float(gc_seconds, "gc_seconds"),
            solver_statistics,
            _optional_nonnegative_int(saved_states, "saved_states"),
            normalized_measurements,
        )
    end
end

"""Deterministic descriptive statistics computed only from raw samples."""
struct PerformanceSummary
    sample_count::Int
    elapsed_minimum::Union{Nothing,Float64}
    elapsed_median::Union{Nothing,Float64}
    elapsed_mean::Union{Nothing,Float64}
    elapsed_maximum::Union{Nothing,Float64}
    elapsed_standard_deviation::Union{Nothing,Float64}
    allocated_bytes_minimum::Union{Nothing,Int}
    allocated_bytes_median::Union{Nothing,Float64}
    allocated_bytes_maximum::Union{Nothing,Int}
    allocation_count_minimum::Union{Nothing,Int}
    allocation_count_median::Union{Nothing,Float64}
    allocation_count_maximum::Union{Nothing,Int}
end

function _median(values)
    ordered = sort(collect(values))
    count = length(ordered)
    isodd(count) && return Float64(ordered[(count + 1) ÷ 2])
    Float64(ordered[count ÷ 2] + ordered[count ÷ 2 + 1]) / 2
end

function _mean(values)
    isempty(values) && return nothing
    sum(Float64(value) for value in values) / length(values)
end

function _sample_standard_deviation(values)
    count = length(values)
    count <= 1 && return 0.0
    average = _mean(values)
    sqrt(sum((Float64(value) - average)^2 for value in values) / (count - 1))
end

function _optional_series_summary(values)
    isempty(values) && return (nothing, nothing, nothing)
    (minimum(values), _median(values), maximum(values))
end

"""Build a deterministic summary from retained samples without mutation."""
function build_performance_summary(samples)
    normalized_samples = Tuple(samples)
    all(sample -> sample isa PerformanceSample, normalized_samples) || throw(
        ArgumentError("samples must contain PerformanceSample records."),
    )

    elapsed = Float64[
        sample.elapsed_seconds for sample in normalized_samples if !isnothing(sample.elapsed_seconds)
    ]
    bytes = Int[
        sample.allocated_bytes for sample in normalized_samples if !isnothing(sample.allocated_bytes)
    ]
    allocations = Int[
        sample.allocation_count for sample in normalized_samples if !isnothing(sample.allocation_count)
    ]
    bytes_minimum, bytes_median, bytes_maximum = _optional_series_summary(bytes)
    allocations_minimum, allocations_median, allocations_maximum =
        _optional_series_summary(allocations)

    PerformanceSummary(
        length(normalized_samples),
        isempty(elapsed) ? nothing : minimum(elapsed),
        isempty(elapsed) ? nothing : _median(elapsed),
        _mean(elapsed),
        isempty(elapsed) ? nothing : maximum(elapsed),
        isempty(elapsed) ? nothing : _sample_standard_deviation(elapsed),
        bytes_minimum,
        bytes_median,
        bytes_maximum,
        allocations_minimum,
        allocations_median,
        allocations_maximum,
    )
end

function _record_fields_equal(left::T, right::T) where {T}
    all(field -> getfield(left, field) == getfield(right, field), fieldnames(T))
end

_performance_summary_equal(left::PerformanceSummary, right::PerformanceSummary) =
    _record_fields_equal(left, right)

function _sample_has_measurement(sample::PerformanceSample, measurement::Symbol)
    measurement == :elapsed_time && return !isnothing(sample.elapsed_seconds)
    measurement == :allocated_bytes && return !isnothing(sample.allocated_bytes)
    measurement == :allocation_count && return !isnothing(sample.allocation_count)
    measurement == :gc_time && return !isnothing(sample.gc_seconds)
    measurement == :solver_statistics && return !isnothing(sample.solver_statistics)
    measurement == :saved_states && return !isnothing(sample.saved_states)
    any(metric -> metric.metric_id == measurement, sample.measurements)
end

function _validate_policy_measurements(policy::PerformanceMeasurementPolicy, samples)
    checks = (
        (:elapsed_seconds, policy.collect_elapsed_time),
        (:allocated_bytes, policy.collect_allocated_bytes),
        (:allocation_count, policy.collect_allocation_count),
        (:gc_seconds, policy.collect_gc_time),
    )
    for (field, collected) in checks
        availability = map(sample -> !isnothing(getfield(sample, field)), samples)
        if collected
            all(availability) || throw(ArgumentError("Collected measurement $field is missing from a sample."))
        else
            any(availability) && throw(ArgumentError("Unrequested measurement $field is present in a sample."))
        end
    end
end

"""Complete report for one fixed benchmark configuration and policy."""
struct PerformanceBenchmarkReport
    definition::PerformanceBenchmarkDefinition
    environment::ValidationEnvironment
    configuration::ValidationConfiguration
    policy::PerformanceMeasurementPolicy
    samples::Tuple{Vararg{PerformanceSample}}
    summary::PerformanceSummary
    execution::ExecutionOutcome

    function PerformanceBenchmarkReport(
        definition::PerformanceBenchmarkDefinition,
        environment::ValidationEnvironment,
        configuration::ValidationConfiguration,
        policy::PerformanceMeasurementPolicy,
        samples,
        summary::PerformanceSummary,
        execution::ExecutionOutcome,
    )
        normalized_samples = Tuple(samples)
        all(sample -> sample isa PerformanceSample, normalized_samples) || throw(
            ArgumentError("samples must contain PerformanceSample records."),
        )
        indices = map(sample -> sample.sample_index, normalized_samples)
        indices == Tuple(1:length(normalized_samples)) || throw(
            ArgumentError("Performance sample indices must be positive and contiguous."),
        )
        length(normalized_samples) <= policy.sample_runs || throw(
            ArgumentError("A report cannot contain more samples than requested by its policy."),
        )
        expected_summary = build_performance_summary(normalized_samples)
        _performance_summary_equal(summary, expected_summary) || throw(
            ArgumentError("Performance summary is inconsistent with the retained samples."),
        )

        if execution.actual == actual_completed
            length(normalized_samples) == policy.sample_runs || throw(
                ArgumentError("A completed report must contain the requested number of samples."),
            )
            _validate_policy_measurements(policy, normalized_samples)
            for measurement in definition.required_measurements
                all(sample -> _sample_has_measurement(sample, measurement), normalized_samples) || throw(
                    ArgumentError("Required measurement $measurement is missing from a completed report."),
                )
            end
        end

        new(
            definition,
            environment,
            configuration,
            policy,
            normalized_samples,
            summary,
            execution,
        )
    end
end

"""Construct a benchmark report and derive its summary from raw samples."""
function build_performance_benchmark_report(
    definition::PerformanceBenchmarkDefinition,
    environment::ValidationEnvironment,
    configuration::ValidationConfiguration,
    policy::PerformanceMeasurementPolicy,
    samples,
    execution::ExecutionOutcome,
)
    normalized_samples = Tuple(samples)
    PerformanceBenchmarkReport(
        definition,
        environment,
        configuration,
        policy,
        normalized_samples,
        build_performance_summary(normalized_samples),
        execution,
    )
end

"""Ordered collection of performance reports from one runner invocation."""
struct PerformanceSuiteReport
    suite_id::Symbol
    title::String
    schema_version::String
    environment::ValidationEnvironment
    benchmarks::Tuple{Vararg{PerformanceBenchmarkReport}}

    function PerformanceSuiteReport(
        suite_id,
        title,
        schema_version,
        environment::ValidationEnvironment,
        benchmarks,
    )
        normalized_benchmarks = Tuple(benchmarks)
        all(benchmark -> benchmark isa PerformanceBenchmarkReport, normalized_benchmarks) || throw(
            ArgumentError("benchmarks must contain PerformanceBenchmarkReport records."),
        )
        benchmark_ids = map(benchmark -> benchmark.definition.benchmark_id, normalized_benchmarks)
        _unique_identifiers(benchmark_ids, "benchmarks")
        all(
            benchmark -> _record_fields_equal(benchmark.environment, environment),
            normalized_benchmarks,
        ) || throw(
            ArgumentError("Every benchmark report must use the suite environment."),
        )

        new(
            _validated_identifier(suite_id, "suite_id"),
            _nonempty_string(title, "title"),
            _validated_version(schema_version, "schema_version"),
            environment,
            normalized_benchmarks,
        )
    end
end

"""Return whether every benchmark process completed and produced full evidence."""
performance_suite_complete(report::PerformanceSuiteReport) =
    all(benchmark -> benchmark.execution.actual == actual_completed, report.benchmarks)
