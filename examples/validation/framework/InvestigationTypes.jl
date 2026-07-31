# Immutable records for descriptive numerical investigations. These records
# compose the existing validation schema without adding acceptance semantics.

"""Definition of one controlled numerical investigation experiment."""
struct InvestigationDefinition
    family_id::Symbol
    title::String
    description::String
    benchmark::ValidationCaseDefinition
    independent_variable::Symbol
    fixed_controls::Tuple{Vararg{ValidationParameter}}
    required_metric_ids::Tuple{Vararg{Symbol}}
    optional_metric_ids::Tuple{Vararg{Symbol}}
    definition_version::String

    function InvestigationDefinition(
        family_id,
        title,
        description,
        benchmark::ValidationCaseDefinition,
        independent_variable,
        fixed_controls,
        required_metric_ids,
        optional_metric_ids,
        definition_version,
    )
        variable = _validated_identifier(independent_variable, "independent_variable")
        controls = Tuple(fixed_controls)
        all(control -> control isa ValidationParameter, controls) || throw(
            ArgumentError("fixed_controls must contain ValidationParameter records."),
        )
        control_ids = map(control -> control.parameter_id, controls)
        _unique_identifiers(control_ids, "fixed_controls")
        variable in control_ids && throw(
            ArgumentError("The independent variable must not also be a fixed control."),
        )

        required = Tuple(
            _validated_identifier(metric_id, "required_metric_id")
            for metric_id in required_metric_ids
        )
        optional = Tuple(
            _validated_identifier(metric_id, "optional_metric_id")
            for metric_id in optional_metric_ids
        )
        _unique_identifiers(required, "required_metric_ids")
        _unique_identifiers(optional, "optional_metric_ids")
        isempty(intersect(Set(required), Set(optional))) || throw(
            ArgumentError("Required and optional metric identifiers must not overlap."),
        )

        new(
            _validated_identifier(family_id, "family_id"),
            _nonempty_string(title, "title"),
            _nonempty_string(description, "description"),
            benchmark,
            variable,
            controls,
            required,
            optional,
            _validated_version(definition_version, "definition_version"),
        )
    end
end

"""
Immutable evidence from one completed or attempted investigation measurement.

An unsuccessful attempt may retain no metrics or solver statistics; its
[`ExecutionOutcome`](@ref) preserves the failure status and factual summary.
"""
struct InvestigationMeasurementPoint
    point_id::Symbol
    definition::InvestigationDefinition
    configuration::ValidationConfiguration
    independent_value::ValidationParameter
    environment::ValidationEnvironment
    execution::ExecutionOutcome
    metrics::Tuple{Vararg{AbstractValidationMetric}}
    solver_statistics::Union{Nothing,SolverStatistics}
    notes::Union{Nothing,String}

    function InvestigationMeasurementPoint(
        point_id,
        definition::InvestigationDefinition,
        configuration::ValidationConfiguration,
        independent_value::ValidationParameter,
        environment::ValidationEnvironment,
        execution::ExecutionOutcome,
        metrics,
        solver_statistics::Union{Nothing,SolverStatistics}=nothing;
        notes=nothing,
    )
        independent_value.parameter_id == definition.independent_variable || throw(
            ArgumentError("independent_value must use the definition's independent variable."),
        )
        normalized_metrics = Tuple(metrics)
        all(metric -> metric isa AbstractValidationMetric, normalized_metrics) || throw(
            ArgumentError("metrics must contain validation metric records."),
        )
        metric_ids = map(metric -> metric.metric_id, normalized_metrics)
        _unique_identifiers(metric_ids, "metrics")
        declared_metric_ids = union(
            Set(definition.required_metric_ids),
            Set(definition.optional_metric_ids),
        )
        all(metric_id -> metric_id in declared_metric_ids, metric_ids) || throw(
            ArgumentError("Every metric must be declared by the investigation definition."),
        )
        if execution.actual == actual_completed
            all(metric_id -> metric_id in metric_ids, definition.required_metric_ids) || throw(
                ArgumentError("Completed points must retain every required metric."),
            )
        end

        new(
            _validated_identifier(point_id, "point_id"),
            definition,
            configuration,
            independent_value,
            environment,
            execution,
            normalized_metrics,
            solver_statistics,
            isnothing(notes) ? nothing : _nonempty_string(notes, "notes"),
        )
    end
end

"""Explicitly ordered immutable measurement points for one experiment."""
struct InvestigationMeasurementSeries
    series_id::Symbol
    title::String
    description::String
    definition::InvestigationDefinition
    points::Tuple{Vararg{InvestigationMeasurementPoint}}

    function InvestigationMeasurementSeries(
        series_id,
        title,
        description,
        definition::InvestigationDefinition,
        points,
    )
        normalized_points = Tuple(points)
        isempty(normalized_points) && throw(
            ArgumentError("An investigation series requires at least one point."),
        )
        all(point -> point isa InvestigationMeasurementPoint, normalized_points) || throw(
            ArgumentError("points must contain InvestigationMeasurementPoint records."),
        )
        point_ids = map(point -> point.point_id, normalized_points)
        _unique_identifiers(point_ids, "points")
        all(
            point -> _record_fields_equal(point.definition, definition),
            normalized_points,
        ) || throw(ArgumentError("Every point must use the series definition."))

        new(
            _validated_identifier(series_id, "series_id"),
            _nonempty_string(title, "title"),
            _nonempty_string(description, "description"),
            definition,
            normalized_points,
        )
    end
end
