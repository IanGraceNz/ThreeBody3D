# Descriptive pairwise comparison of immutable performance reports.
# This layer deliberately defines no approved baseline, threshold, regression
# classification, or PASS/FAIL result.

"""One descriptive difference between a reference and candidate measurement."""
struct PerformanceMeasurementDifference
    measurement_id::Symbol
    label::String
    reference_value::Union{Nothing,Float64}
    candidate_value::Union{Nothing,Float64}
    absolute_difference::Union{Nothing,Float64}
    relative_difference::Union{Nothing,Float64}
    percentage_difference::Union{Nothing,Float64}

    function PerformanceMeasurementDifference(
        measurement_id,
        label,
        reference_value,
        candidate_value,
    )
        normalized_reference = isnothing(reference_value) ? nothing : Float64(reference_value)
        normalized_candidate = isnothing(candidate_value) ? nothing : Float64(candidate_value)
        for (name, value) in (("reference_value", normalized_reference), ("candidate_value", normalized_candidate))
            isnothing(value) || isfinite(value) || throw(ArgumentError("$name must be finite or nothing."))
        end
        absolute = if isnothing(normalized_reference) || isnothing(normalized_candidate)
            nothing
        else
            normalized_candidate - normalized_reference
        end
        relative = if isnothing(absolute) || normalized_reference == 0.0
            nothing
        else
            absolute / abs(normalized_reference)
        end
        new(
            _validated_identifier(measurement_id, "measurement_id"),
            _nonempty_string(label, "label"),
            normalized_reference,
            normalized_candidate,
            absolute,
            relative,
            isnothing(relative) ? nothing : 100.0 * relative,
        )
    end
end

"""Complete descriptive comparison between two performance benchmark reports."""
struct PerformanceBenchmarkComparison
    benchmark_id::Symbol
    definition_version::String
    compatible::Bool
    compatibility_issues::Tuple{Vararg{Symbol}}
    environment_override::Bool
    differences::Tuple{Vararg{PerformanceMeasurementDifference}}

    function PerformanceBenchmarkComparison(
        benchmark_id,
        definition_version,
        compatible,
        compatibility_issues,
        environment_override,
        differences,
    )
        normalized_issues = Tuple(
            _validated_identifier(value, "compatibility_issue") for value in compatibility_issues
        )
        _unique_identifiers(normalized_issues, "compatibility_issues")
        normalized_differences = Tuple(differences)
        all(value -> value isa PerformanceMeasurementDifference, normalized_differences) || throw(
            ArgumentError("differences must contain PerformanceMeasurementDifference records."),
        )
        ids = map(value -> value.measurement_id, normalized_differences)
        _unique_identifiers(ids, "differences")
        Bool(compatible) == isempty(normalized_issues) || throw(
            ArgumentError("compatible must agree with compatibility_issues."),
        )
        new(
            _validated_identifier(benchmark_id, "benchmark_id"),
            _validated_version(definition_version, "definition_version"),
            Bool(compatible),
            normalized_issues,
            Bool(environment_override),
            normalized_differences,
        )
    end
end

function _configuration_equal(left::ValidationConfiguration, right::ValidationConfiguration)
    _record_fields_equal(left, right)
end

function _policy_equal(left::PerformanceMeasurementPolicy, right::PerformanceMeasurementPolicy)
    _record_fields_equal(left, right)
end

function _julia_major_minor(version::AbstractString)
    match_result = match(r"^(\d+)\.(\d+)", version)
    isnothing(match_result) && return nothing
    (parse(Int, match_result.captures[1]), parse(Int, match_result.captures[2]))
end

function performance_comparison_issues(
    reference::PerformanceBenchmarkReport,
    candidate::PerformanceBenchmarkReport;
    allow_environment_mismatch::Bool=false,
)
    issues = Symbol[]
    reference.definition.benchmark_id == candidate.definition.benchmark_id || push!(issues, :benchmark_id_mismatch)
    reference.definition.definition_version == candidate.definition.definition_version || push!(issues, :definition_version_mismatch)
    _configuration_equal(reference.configuration, candidate.configuration) || push!(issues, :configuration_mismatch)
    _policy_equal(reference.policy, candidate.policy) || push!(issues, :measurement_policy_mismatch)

    if !allow_environment_mismatch
        _julia_major_minor(reference.environment.julia_version) ==
            _julia_major_minor(candidate.environment.julia_version) || push!(issues, :julia_version_mismatch)
        reference.environment.thread_count == candidate.environment.thread_count || push!(issues, :thread_count_mismatch)
        reference.environment.architecture == candidate.environment.architecture || push!(issues, :architecture_mismatch)
    end
    Tuple(issues)
end

function _metric_values(report::PerformanceBenchmarkReport)
    values = Dict{Symbol,Vector{Float64}}()
    for sample in report.samples, metric in sample.measurements
        metric.value isa Real || continue
        push!(get!(values, metric.metric_id, Float64[]), Float64(metric.value))
    end
    values
end

function _median_metric_values(report::PerformanceBenchmarkReport)
    Dict(key => _median(value) for (key, value) in _metric_values(report))
end

function _summary_measurements(report::PerformanceBenchmarkReport)
    values = Dict{Symbol,Tuple{String,Union{Nothing,Float64}}}(
        :elapsed_median_seconds => ("Elapsed median seconds", report.summary.elapsed_median),
        :allocated_bytes_median => ("Allocated bytes median", report.summary.allocated_bytes_median),
        :allocation_count_median => ("Allocation count median", report.summary.allocation_count_median),
    )
    solver_fields = (
        (:accepted_steps_median, "Accepted steps median", :accepted_steps),
        (:rejected_steps_median, "Rejected steps median", :rejected_steps),
        (:rhs_evaluations_median, "RHS evaluations median", :rhs_evaluations),
        (:saved_states_median, "Saved states median", :saved_states),
    )
    for (identifier, label, field) in solver_fields
        observations = Float64[
            getfield(sample.solver_statistics, field) for sample in report.samples
            if !isnothing(sample.solver_statistics) && !isnothing(getfield(sample.solver_statistics, field))
        ]
        values[identifier] = (label, isempty(observations) ? nothing : _median(observations))
    end
    metrics = _median_metric_values(report)
    for key in sort!(collect(keys(metrics)); by=string)
        values[key] = (replace(string(key), '_' => ' '), metrics[key])
    end
    values
end

"""Compare two reports descriptively after enforcing compatibility invariants."""
function compare_performance_reports(
    reference::PerformanceBenchmarkReport,
    candidate::PerformanceBenchmarkReport;
    allow_environment_mismatch::Bool=false,
    require_compatible::Bool=true,
)
    issues = performance_comparison_issues(
        reference,
        candidate;
        allow_environment_mismatch=allow_environment_mismatch,
    )
    require_compatible && !isempty(issues) && throw(ArgumentError(
        "Performance reports are incompatible: $(join(string.(issues), ", ")).",
    ))

    reference_values = _summary_measurements(reference)
    candidate_values = _summary_measurements(candidate)
    identifiers = sort!(collect(union(keys(reference_values), keys(candidate_values))); by=string)
    differences = map(identifiers) do identifier
        reference_label, reference_value = get(reference_values, identifier, (replace(string(identifier), '_' => ' '), nothing))
        candidate_label, candidate_value = get(candidate_values, identifier, (reference_label, nothing))
        PerformanceMeasurementDifference(
            identifier,
            isempty(reference_label) ? candidate_label : reference_label,
            reference_value,
            candidate_value,
        )
    end

    PerformanceBenchmarkComparison(
        reference.definition.benchmark_id,
        reference.definition.definition_version,
        isempty(issues),
        issues,
        allow_environment_mismatch,
        Tuple(differences),
    )
end

function performance_difference(
    comparison::PerformanceBenchmarkComparison,
    measurement_id::Symbol,
)
    index = findfirst(value -> value.measurement_id == measurement_id, comparison.differences)
    isnothing(index) ? nothing : comparison.differences[index]
end
