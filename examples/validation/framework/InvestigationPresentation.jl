# Deterministic human-readable presentation for the Investigation 1 pilots.

const INVESTIGATION_REGENERATION_COMMAND =
    "julia --project=. examples/validation/run_investigation_1_baseline.jl validation_reports/investigation_1"

_markdown_value(value) = isnothing(value) ? "Not available" :
    replace(string(value), "|" => "\\|")

function _point_metric(point, id)
    match = findfirst(metric -> metric.metric_id == id, point.metrics)
    isnothing(match) ? nothing : point.metrics[match].value
end

function _numeric_relationship(left, right; rtol=1e-12, atol=0.0)
    left isa Real && right isa Real || return :unavailable
    all(isfinite, (left, right)) || return :anomalous
    isapprox(left, right; rtol, atol) && return :equal
    left < right ? :lower : :higher
end

function _relationship_sentence(left_point, right_point, metric_id)
    left = _point_metric(left_point, metric_id)
    right = _point_metric(right_point, metric_id)
    relationship = _numeric_relationship(left, right)
    label = replace(string(metric_id), '_' => ' ')
    if relationship == :unavailable
        return "$label comparison is unavailable."
    elseif relationship == :anomalous
        return "$label contains non-finite or anomalous evidence."
    elseif relationship == :equal
        return "$label is equal within the fixed report comparison rule ($(left))."
    end
    qualifier = relationship == :lower ? "lower" : "higher"
    "$(left_point.point_id) recorded $qualifier $label than $(right_point.point_id) ($left versus $right)."
end

function _work_value(point, name)
    isnothing(point.solver_statistics) ? nothing : getfield(point.solver_statistics, name)
end

function _timing_summary(point)
    report = point.performance_report
    isnothing(report) && return (nothing, nothing)
    isempty(report.samples) && return (0, nothing)
    (length(report.samples), report.summary.elapsed_median)
end

function _write_unsuccessful_points(io, series)
    unsuccessful = Tuple(
        (item, point) for item in series for point in item.points
        if point.execution.actual != actual_completed
    )
    println(io, "## Unsuccessful and operational points\n")
    if isempty(unsuccessful)
        println(io, "No unsuccessful points were recorded.\n")
        return
    end
    println(io, "| Series | Point | Execution status | Exit code | Factual summary or notes |")
    println(io, "|---|---|---|---:|---|")
    for (item, point) in unsuccessful
        summary = !isnothing(point.execution.summary) ? point.execution.summary : point.notes
        println(io, "| ", item.series_id, " | ", point.point_id, " | ",
            stable_string(point.execution.actual), " | ",
            _markdown_value(point.execution.exit_code), " | ",
            _markdown_value(summary), " |")
    end
    println(io)
end

function _write_interpretation(io, series)
    println(io, "## Interpretation\n")
    println(io, "These statements are computed from the recorded values. They compare only like-named evidence within one series; they do not create a combined score or rank incomparable metrics. Execution status remains separate from numerical interpretation.\n")
    for item in series
        println(io, "### ", item.title, "\n")
        if item.series_id == :figure_eight_profile
            first_point, second_point = item.points
            println(io, "- ", _relationship_sentence(
                first_point, second_point, :periodicity_error,
            ))
            println(io, "- ", _relationship_sentence(
                first_point, second_point, :maximum_relative_energy_drift,
            ))
            println(io, "- This is a profile-only comparison; it is not evidence of tolerance convergence.")
        elseif item.series_id == :hierarchical_triple_profile
            first_point, second_point = item.points
            println(io, "- ", _relationship_sentence(
                first_point, second_point, :maximum_relative_energy_drift,
            ))
            println(io, "- ", _relationship_sentence(
                first_point, second_point, :minimum_hierarchy_ratio,
            ))
            println(io, "- This is a profile-only comparison; it is not evidence of tolerance convergence.")
        elseif item.series_id == :close_encounter_representation
            for left_index in 1:length(item.points)-1
                println(io, "- ", _relationship_sentence(
                    item.points[left_index], item.points[left_index + 1],
                    :maximum_state_error,
                ))
            end
            println(io, "- Periapsis error remains distinct from minimum sampled separation.")
        elseif item.series_id == :ks_switching_backend
            first_point, second_point = item.points
            println(io, "- ", _relationship_sentence(
                first_point, second_point, :maximum_relative_energy_drift,
            ))
            println(io, "- The shared backend state-discrepancy measurement is ",
                _markdown_value(_point_metric(
                    first_point, :maximum_scaled_backend_state_discrepancy,
                )), ".")
        else
            println(io, "- No series-specific interpretation rule is declared.")
        end
        println(io)
    end
end

function _write_reproducibility(io, result)
    println(io, "## Reproducibility result\n")
    if isnothing(result) || !result.performed
        println(io, "A second equivalent execution was not performed; reproducibility is not claimed.\n")
        return
    end
    println(io, "A second equivalent execution was performed.")
    println(io, "- Exact match required: series and point identity/order, definitions, configurations, execution outcomes, metric identities, and deterministic solver-work counts.")
    println(io, "- Numerical rule: `isapprox` with `rtol = ", result.relative_tolerance,
        "` and `atol = ", result.absolute_tolerance, "` for numerical metrics and structured supporting evidence.")
    println(io, "- Timing rule: sample elapsed seconds, sample GC seconds, and elapsed-time summary statistics are environment-dependent and excluded from equality requirements. Performance definitions, configurations, policies, execution outcomes, sample structure/order, deterministic measurements, and solver-work evidence are compared.")
    println(io, "- Result: ", result.passed ? "PASS" : "FAIL")
    if isempty(result.mismatches)
        println(io, "- Mismatches: none")
    else
        println(io, "- Mismatches:")
        for mismatch in result.mismatches
            println(io, "  - ", mismatch)
        end
    end
    println(io)
end

function investigation_baseline_markdown(series_collection; reproducibility=nothing)
    series = Tuple(series_collection)
    isempty(series) && throw(ArgumentError(
        "The baseline requires at least one investigation series.",
    ))
    environments = Tuple(point.environment for item in series for point in item.points)
    environment = first(environments)
    all(item -> _record_fields_equal(item, environment), environments) || throw(ArgumentError(
        "Every baseline point must use the same parent environment.",
    ))
    io = IOBuffer()
    println(io, "# ThreeBody3D Investigation 1 Baseline Report\n")
    println(io, "## Scope\n")
    println(io, "This report records direct measurements from the four approved pilot series. The two core series are profile-only. Execution outcomes and descriptive numerical evidence are reported separately. No solver, switching, or regularisation change is proposed.\n")
    println(io, "## Repository and environment provenance\n")
    println(io, "- Repository commit: ", _markdown_value(environment.repository_commit))
    println(io, "- Repository dirty: ", _markdown_value(environment.repository_dirty))
    println(io, "- Package version: ", environment.package_version)
    println(io, "- Julia: ", environment.julia_version)
    println(io, "- Platform: ", environment.operating_system, " / ", environment.architecture)
    println(io, "- Threads: ", environment.thread_count)
    println(io, "- Recorded UTC time: ", environment.timestamp_utc, "\n")
    println(io, "## Regeneration\n")
    println(io, "```powershell\n", INVESTIGATION_REGENERATION_COMMAND, "\n```\n")
    println(io, "Generated files:")
    for item in series
        println(io, "- `", item.series_id, ".toml`")
    end
    println(io, "- `INVESTIGATION_1_BASELINE_REPORT.md`\n")
    println(io, "## Experimental-series summary\n")
    println(io, "| Series | Independent variable | Points | Completed | Unsuccessful |")
    println(io, "|---|---|---:|---:|---:|")
    for item in series
        completed = count(point -> point.execution.actual == actual_completed, item.points)
        println(io, "| ", item.series_id, " | ", item.definition.independent_variable,
            " | ", length(item.points), " | ", completed, " | ",
            length(item.points) - completed, " |")
    end
    println(io)
    _write_unsuccessful_points(io, series)
    println(io, "## Direct numerical measurements\n")
    println(io, "These tables contain measurements, not interpretation. State error remains distinct from invariant drift. Minimum sampled separation is not periapsis error. Missing or inapplicable evidence is shown as ‘Not available’, never as zero.\n")
    for item in series
        println(io, "### ", item.title, "\n")
        metric_ids = (
            item.definition.required_metric_ids...,
            item.definition.optional_metric_ids...,
        )
        println(io, "| Point | Execution | ", join(string.(metric_ids), " | "), " |")
        println(io, "|---|---|", join(fill("---:", length(metric_ids)), "|"), "|")
        for point in item.points
            values = [_markdown_value(_point_metric(point, id)) for id in metric_ids]
            println(io, "| ", point.point_id, " | ", stable_string(point.execution.actual),
                " | ", join(values, " | "), " |")
        end
        println(io)
    end
    println(io, "## Solver work and retained timing evidence\n")
    println(io, "| Series | Point | Accepted | Rejected | RHS evaluations | Saved states | Segments | Switches | Retained timing samples | Median seconds |")
    println(io, "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for item in series, point in item.points
        work = [_markdown_value(_work_value(point, name)) for name in (
            :accepted_steps, :rejected_steps, :rhs_evaluations,
            :saved_states, :segment_count, :switch_count,
        )]
        sample_count, median = _timing_summary(point)
        println(io, "| ", item.series_id, " | ", point.point_id, " | ",
            join((work..., _markdown_value(sample_count), _markdown_value(median)), " | "), " |")
    end
    println(io)
    _write_interpretation(io, series)
    println(io, "No convergence, secular growth, error floor, or causal mechanism is inferred from these data.\n")
    println(io, "## Limitations\n")
    println(io, "- The two profile-only core series do not support conclusions about tolerance convergence.")
    println(io, "- The current data do not support conclusions about duration-dependent growth, secular behaviour, or error floors.")
    println(io, "- Timing is environment-dependent; retained samples and deterministic work counts must be considered together.")
    println(io, "- State error and invariant drift answer different questions and are not substitutes.")
    println(io, "- Minimum sampled separation is distinct from periapsis error.")
    println(io, "- Close-encounter and switching observations apply only to their fixed cases and policies.\n")
    _write_reproducibility(io, reproducibility)
    println(io, "## Questions transferred to Investigation 2\n")
    println(io, "- Which mechanisms account for the largest observed state errors in each fixed regime?")
    println(io, "- Why do state error and invariant drift differ in their ordering where they do?")
    println(io, "- Which switching or representation effects explain observed backend discrepancies and transition residuals?")
    println(io, "- Which controlled tolerance, duration, encounter-severity, or hierarchy series should test convergence and growth hypotheses?\n")
    String(take!(io))
end

function write_investigation_baseline_atomic(
    path::AbstractString, series_collection; reproducibility=nothing,
)
    final_path = abspath(path)
    mkpath(dirname(final_path))
    temporary_path = final_path * ".tmp"
    try
        open(temporary_path, "w") do io
            write(io, investigation_baseline_markdown(
                series_collection; reproducibility,
            ))
        end
        mv(temporary_path, final_path; force=true)
    catch
        isfile(temporary_path) && rm(temporary_path; force=true)
        rethrow()
    end
    final_path
end
