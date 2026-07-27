# Ordered accuracy-versus-work series built from immutable performance reports.
# Series are descriptive evidence only and define no universal ranking or status.

"""One labelled point in an accuracy-versus-work series."""
struct PerformanceAccuracyWorkPoint
    point_id::Symbol
    label::String
    report::PerformanceBenchmarkReport
    accuracy_metric_id::Symbol
    accuracy_metric_label::String
    accuracy_median::Float64

    function PerformanceAccuracyWorkPoint(
        point_id,
        label,
        report::PerformanceBenchmarkReport,
        accuracy_metric_id,
    )
        report.execution.actual == actual_completed || throw(ArgumentError(
            "Accuracy-versus-work points require completed performance reports.",
        ))
        metric_id = _validated_identifier(accuracy_metric_id, "accuracy_metric_id")
        observations = Tuple(
            metric for sample in report.samples for metric in sample.measurements
            if metric.metric_id == metric_id
        )
        length(observations) == length(report.samples) || throw(ArgumentError(
            "Accuracy metric $metric_id must be present in every retained sample.",
        ))
        all(metric -> metric.value isa Real, observations) || throw(ArgumentError(
            "Accuracy metric $metric_id must be numeric.",
        ))
        labels = unique(metric.label for metric in observations)
        length(labels) == 1 || throw(ArgumentError(
            "Accuracy metric $metric_id must use one stable label.",
        ))
        values = Float64[metric.value for metric in observations]
        all(isfinite, values) || throw(ArgumentError(
            "Accuracy metric $metric_id must contain finite values.",
        ))
        new(
            _validated_identifier(point_id, "point_id"),
            _nonempty_string(label, "label"),
            report,
            metric_id,
            first(labels),
            _median(values),
        )
    end
end

"""An explicitly ordered set of fixed configurations for one numerical workload."""
struct PerformanceAccuracyWorkSeries
    series_id::Symbol
    title::String
    description::String
    accuracy_metric_id::Symbol
    points::Tuple{Vararg{PerformanceAccuracyWorkPoint}}

    function PerformanceAccuracyWorkSeries(
        series_id,
        title,
        description,
        accuracy_metric_id,
        points,
    )
        normalized_points = Tuple(points)
        length(normalized_points) >= 2 || throw(ArgumentError(
            "An accuracy-versus-work series requires at least two points.",
        ))
        all(point -> point isa PerformanceAccuracyWorkPoint, normalized_points) || throw(
            ArgumentError("points must contain PerformanceAccuracyWorkPoint records."),
        )
        point_ids = map(point -> point.point_id, normalized_points)
        _unique_identifiers(point_ids, "points")
        metric_id = _validated_identifier(accuracy_metric_id, "accuracy_metric_id")
        all(point -> point.accuracy_metric_id == metric_id, normalized_points) || throw(
            ArgumentError("Every point must use the series accuracy metric."),
        )
        environments = map(point -> point.report.environment, normalized_points)
        all(environment -> _record_fields_equal(environment, first(environments)), environments) || throw(
            ArgumentError("Every series point must use the same retained environment."),
        )
        policies = map(point -> point.report.policy, normalized_points)
        all(policy -> _record_fields_equal(policy, first(policies)), policies) || throw(
            ArgumentError("Every series point must use the same measurement policy."),
        )
        new(
            _validated_identifier(series_id, "series_id"),
            _nonempty_string(title, "title"),
            _nonempty_string(description, "description"),
            metric_id,
            normalized_points,
        )
    end
end

"""Build a series from a suite and ordered `(point_id, label, benchmark_id)` specifications."""
function build_accuracy_work_series(
    suite::PerformanceSuiteReport,
    series_id,
    title,
    description,
    accuracy_metric_id,
    specifications,
)
    reports = Dict(report.definition.benchmark_id => report for report in suite.benchmarks)
    points = map(specifications) do specification
        length(specification) == 3 || throw(ArgumentError(
            "Each series specification must contain point_id, label, and benchmark_id.",
        ))
        point_id, label, benchmark_id = specification
        normalized_benchmark_id = _validated_identifier(benchmark_id, "benchmark_id")
        haskey(reports, normalized_benchmark_id) || throw(ArgumentError(
            "Suite does not contain benchmark $normalized_benchmark_id.",
        ))
        PerformanceAccuracyWorkPoint(
            point_id,
            label,
            reports[normalized_benchmark_id],
            accuracy_metric_id,
        )
    end
    PerformanceAccuracyWorkSeries(
        series_id,
        title,
        description,
        accuracy_metric_id,
        Tuple(points),
    )
end

function _series_solver_median(point::PerformanceAccuracyWorkPoint, field::Symbol)
    values = Float64[
        getfield(sample.solver_statistics, field) for sample in point.report.samples
        if !isnothing(sample.solver_statistics) && !isnothing(getfield(sample.solver_statistics, field))
    ]
    isempty(values) ? nothing : _median(values)
end
