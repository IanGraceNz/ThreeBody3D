# Deterministic TOML persistence for V5-V6 performance benchmark reports.

function _write_performance_definition(
    io::IO,
    definition::PerformanceBenchmarkDefinition,
    heading::AbstractString,
)
    println(io, "[$heading]")
    _write_key_value(io, "benchmark_id", definition.benchmark_id)
    _write_key_value(io, "title", definition.title)
    _write_key_value(io, "description", definition.description)
    _write_key_value(io, "source_path", definition.source_path)
    _write_key_value(io, "classifications", definition.classifications)
    _write_key_value(io, "tags", definition.tags)
    _write_key_value(io, "definition_version", definition.definition_version)
    _write_key_value(io, "required_measurements", definition.required_measurements)
    !isnothing(definition.provenance) &&
        _write_key_value(io, "provenance", definition.provenance)
    println(io)
end

function _write_performance_policy(
    io::IO,
    policy::PerformanceMeasurementPolicy,
    heading::AbstractString,
)
    println(io, "[$heading]")
    _write_key_value(io, "warmup_runs", policy.warmup_runs)
    _write_key_value(io, "sample_runs", policy.sample_runs)
    _write_key_value(io, "collect_elapsed_time", policy.collect_elapsed_time)
    _write_key_value(io, "collect_allocated_bytes", policy.collect_allocated_bytes)
    _write_key_value(io, "collect_allocation_count", policy.collect_allocation_count)
    _write_key_value(io, "collect_gc_time", policy.collect_gc_time)
    _write_key_value(
        io,
        "garbage_collection_before_sample",
        policy.garbage_collection_before_sample,
    )
    _write_key_value(io, "process_isolation", policy.process_isolation)
    _write_key_value(io, "timing_clock", policy.timing_clock)
    println(io)
end

function _write_optional_float(io::IO, key::AbstractString, value)
    isnothing(value) || _write_key_value(io, key, repr(value))
end

function _write_performance_sample(
    io::IO,
    sample::PerformanceSample,
    heading::AbstractString,
)
    println(io, "[[$heading]]")
    _write_key_value(io, "sample_index", sample.sample_index)
    _write_optional_float(io, "elapsed_seconds", sample.elapsed_seconds)
    !isnothing(sample.allocated_bytes) &&
        _write_key_value(io, "allocated_bytes", sample.allocated_bytes)
    !isnothing(sample.allocation_count) &&
        _write_key_value(io, "allocation_count", sample.allocation_count)
    _write_optional_float(io, "gc_seconds", sample.gc_seconds)
    !isnothing(sample.saved_states) && _write_key_value(io, "saved_states", sample.saved_states)
    println(io)
    !isnothing(sample.solver_statistics) &&
        _write_solver_statistics(io, sample.solver_statistics, "$heading.solver_statistics")
    for metric in sample.measurements
        _write_metric(io, metric, "$heading.measurements")
    end
end

function _write_performance_summary(
    io::IO,
    summary::PerformanceSummary,
    heading::AbstractString,
)
    println(io, "[$heading]")
    _write_key_value(io, "sample_count", summary.sample_count)
    for field in (
        :elapsed_minimum,
        :elapsed_median,
        :elapsed_mean,
        :elapsed_maximum,
        :elapsed_standard_deviation,
        :allocated_bytes_median,
        :allocation_count_median,
    )
        _write_optional_float(io, String(field), getfield(summary, field))
    end
    for field in (
        :allocated_bytes_minimum,
        :allocated_bytes_maximum,
        :allocation_count_minimum,
        :allocation_count_maximum,
    )
        value = getfield(summary, field)
        isnothing(value) || _write_key_value(io, String(field), value)
    end
    println(io)
end

function _write_performance_benchmark_body(
    io::IO,
    report::PerformanceBenchmarkReport,
    prefix::AbstractString,
)
    _write_performance_definition(io, report.definition, "$prefix.definition")
    _write_environment(io, report.environment, "$prefix.environment")
    _write_configuration(io, report.configuration, "$prefix.configuration")
    _write_performance_policy(io, report.policy, "$prefix.policy")
    for sample in report.samples
        _write_performance_sample(io, sample, "$prefix.samples")
    end
    _write_performance_summary(io, report.summary, "$prefix.summary")
    _write_execution(io, report.execution, "$prefix.execution")
end

"""Write one deterministic performance benchmark TOML report."""
function write_performance_benchmark(io::IO, report::PerformanceBenchmarkReport)
    _write_key_value(io, "schema_identity", VALIDATION_SCHEMA_IDENTITY)
    _write_key_value(io, "report_kind", "performance_benchmark")
    _write_key_value(io, "schema_version", report.environment.schema_version)
    println(io)
    _write_performance_benchmark_body(io, report, "benchmark")
    nothing
end

"""Write one deterministic performance suite TOML report."""
function write_performance_suite(io::IO, report::PerformanceSuiteReport)
    _write_key_value(io, "schema_identity", VALIDATION_SCHEMA_IDENTITY)
    _write_key_value(io, "report_kind", "performance_suite")
    _write_key_value(io, "schema_version", report.schema_version)
    _write_key_value(io, "suite_id", report.suite_id)
    _write_key_value(io, "title", report.title)
    println(io)
    _write_environment(io, report.environment, "environment")
    for benchmark in report.benchmarks
        println(io, "[[benchmarks]]")
        println(io)
        _write_performance_benchmark_body(io, benchmark, "benchmarks")
    end
    nothing
end

performance_benchmark_text(report::PerformanceBenchmarkReport) =
    _report_text(write_performance_benchmark, report)
performance_suite_text(report::PerformanceSuiteReport) =
    _report_text(write_performance_suite, report)

function _read_performance_definition(table)
    PerformanceBenchmarkDefinition(
        Symbol(table["benchmark_id"]),
        table["title"],
        table["description"],
        table["source_path"],
        Symbol.(table["classifications"]),
        Symbol.(table["tags"]),
        table["definition_version"],
        Symbol.(table["required_measurements"]),
        get(table, "provenance", nothing),
    )
end

function _read_performance_policy(table)
    PerformanceMeasurementPolicy(
        warmup_runs=table["warmup_runs"],
        sample_runs=table["sample_runs"],
        collect_elapsed_time=table["collect_elapsed_time"],
        collect_allocated_bytes=table["collect_allocated_bytes"],
        collect_allocation_count=table["collect_allocation_count"],
        collect_gc_time=table["collect_gc_time"],
        garbage_collection_before_sample=table["garbage_collection_before_sample"],
        process_isolation=table["process_isolation"],
        timing_clock=Symbol(table["timing_clock"]),
    )
end

_read_optional_float(table, key::AbstractString) =
    haskey(table, key) ? parse(Float64, table[key]) : nothing

function _read_performance_sample(table)
    PerformanceSample(
        table["sample_index"];
        elapsed_seconds=_read_optional_float(table, "elapsed_seconds"),
        allocated_bytes=get(table, "allocated_bytes", nothing),
        allocation_count=get(table, "allocation_count", nothing),
        gc_seconds=_read_optional_float(table, "gc_seconds"),
        solver_statistics=haskey(table, "solver_statistics") ?
            _read_solver_statistics(table["solver_statistics"]) : nothing,
        saved_states=get(table, "saved_states", nothing),
        measurements=Tuple(_read_metric(value) for value in get(table, "measurements", Any[])),
    )
end

function _read_performance_summary(table)
    PerformanceSummary(
        table["sample_count"],
        _read_optional_float(table, "elapsed_minimum"),
        _read_optional_float(table, "elapsed_median"),
        _read_optional_float(table, "elapsed_mean"),
        _read_optional_float(table, "elapsed_maximum"),
        _read_optional_float(table, "elapsed_standard_deviation"),
        get(table, "allocated_bytes_minimum", nothing),
        _read_optional_float(table, "allocated_bytes_median"),
        get(table, "allocated_bytes_maximum", nothing),
        get(table, "allocation_count_minimum", nothing),
        _read_optional_float(table, "allocation_count_median"),
        get(table, "allocation_count_maximum", nothing),
    )
end

function _read_performance_benchmark_table(table)
    PerformanceBenchmarkReport(
        _read_performance_definition(table["definition"]),
        _read_environment(table["environment"]),
        _read_configuration(table["configuration"]),
        _read_performance_policy(table["policy"]),
        Tuple(_read_performance_sample(value) for value in get(table, "samples", Any[])),
        _read_performance_summary(table["summary"]),
        _read_execution(table["execution"]),
    )
end

"""Read and strictly validate one deterministic performance benchmark report."""
function read_performance_benchmark(source)
    data = source isa IO ? TOML.parse(read(source, String)) : TOML.parsefile(source)
    _validate_report_header(data, "performance_benchmark")
    report = _read_performance_benchmark_table(data["benchmark"])
    report.environment.schema_version == data["schema_version"] || throw(
        ArgumentError("Performance benchmark schema versions differ."),
    )
    report
end

"""Read and strictly validate one deterministic performance suite report."""
function read_performance_suite(source)
    data = source isa IO ? TOML.parse(read(source, String)) : TOML.parsefile(source)
    _validate_report_header(data, "performance_suite")
    environment = _read_environment(data["environment"])
    report = PerformanceSuiteReport(
        Symbol(data["suite_id"]),
        data["title"],
        data["schema_version"],
        environment,
        Tuple(_read_performance_benchmark_table(value) for value in get(data, "benchmarks", Any[])),
    )
    report.environment.schema_version == report.schema_version || throw(
        ArgumentError("Performance suite schema versions differ."),
    )
    report
end
