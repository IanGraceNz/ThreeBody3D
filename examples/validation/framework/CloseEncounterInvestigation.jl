# Close-encounter adapter for the first Stage I1-D pilot series.

const CLOSE_ENCOUNTER_INVESTIGATION_DEFINITION_VERSION = "1.0.0"
const CLOSE_ENCOUNTER_INVESTIGATION_REPRESENTATIONS = (
    :cartesian,
    :automatic_switching,
    :explicit_regularized,
)
const CLOSE_ENCOUNTER_INVESTIGATION_METRICS = (
    :integration_status,
    :final_time_residual,
    :maximum_position_error,
    :maximum_velocity_error,
    :maximum_state_error,
    :final_position_error,
    :final_velocity_error,
    :final_state_error,
    :maximum_relative_energy_drift,
    :maximum_linear_momentum_drift,
    :maximum_angular_momentum_drift,
    :maximum_center_of_mass_residual,
    :minimum_pair_separation,
    :periapsis_time_error,
    :periapsis_separation_error,
)
const CLOSE_ENCOUNTER_INVESTIGATION_OPTIONAL_METRICS = (:transition_state_residual,)

function _close_encounter_initial_state()
    m1, m2, m3 = 1.0, 1.0, 0.001
    apoapsis, periapsis = 1.0, 0.0001
    semimajor_axis = (apoapsis + periapsis) / 2
    relative_speed = sqrt((m1 + m2) * (2 / apoapsis - 1 / semimajor_axis))
    binary_com_x = -(m3 / (m1 + m2 + m3)) * 10.0
    third_x = binary_com_x + 10.0
    (
        binary_com_x + apoapsis / 2, 0.0, 0.0, 0.0, relative_speed / 2, 0.0,
        binary_com_x - apoapsis / 2, 0.0, 0.0, 0.0, -relative_speed / 2, 0.0,
        third_x, 0.0, 0.0, 0.0, 0.0, 0.0,
    )
end

function _close_encounter_investigation_configuration()
    _close_encounter_configuration(
        initial_state=_close_encounter_initial_state(),
        masses=(1.0, 1.0, 0.001),
        gravitational_constant=1.0,
        apoapsis=1.0,
        nominal_periapsis=0.0001,
        third_body_offset=10.0,
    )
end

function _close_encounter_fixed_controls()
    configuration = _close_encounter_investigation_configuration()
    (
        ValidationParameter(:solver, configuration.solver),
        ValidationParameter(:absolute_tolerance, configuration.absolute_tolerance),
        ValidationParameter(:relative_tolerance, configuration.relative_tolerance),
        ValidationParameter(:reference_precision_bits, configuration.precision_bits),
        ValidationParameter(:time_interval, configuration.time_interval),
        ValidationParameter(:sampling, configuration.sampling),
        ValidationParameter(:selected_pair, configuration.selected_pair),
        configuration.thresholds...,
        configuration.parameters...,
    )
end

"""Define the fixed close-encounter propagation-representation experiment."""
function close_encounter_representation_investigation_definition()
    InvestigationDefinition(
        :close_encounter_representation,
        "Close-encounter propagation-representation comparison",
        "Compare Cartesian, automatic-switching, and explicit regularized propagation for the existing fixed close-encounter problem and independent BigFloat reference.",
        close_encounter_case_definition(),
        :representation_mode,
        _close_encounter_fixed_controls(),
        CLOSE_ENCOUNTER_INVESTIGATION_METRICS,
        CLOSE_ENCOUNTER_INVESTIGATION_OPTIONAL_METRICS,
        CLOSE_ENCOUNTER_INVESTIGATION_DEFINITION_VERSION,
    )
end

function _close_encounter_representation_id(report)
    hasproperty(report, :name) || throw(ArgumentError(
        "Every close-encounter method report must retain its method name.",
    ))
    report.name == "Cartesian" && return :cartesian
    report.name == "Automatic switching" && return :automatic_switching
    report.name == "Explicit regularized" && return :explicit_regularized
    throw(ArgumentError("Unsupported close-encounter method report: $(report.name)."))
end

function _validate_close_encounter_method_report(
    report,
    result::ValidationCaseResult,
)
    all(
        field -> hasproperty(report, field),
        (:definition, :configuration, :environment, :execution),
    ) || throw(ArgumentError(
        "Close-encounter method reports must retain definition, configuration, environment, and execution records.",
    ))
    report.definition isa ValidationCaseDefinition || throw(ArgumentError(
        "Close-encounter method report definition must be a ValidationCaseDefinition record.",
    ))
    report.configuration isa ValidationConfiguration || throw(ArgumentError(
        "Close-encounter method report configuration must be a ValidationConfiguration record.",
    ))
    report.environment isa ValidationEnvironment || throw(ArgumentError(
        "Close-encounter method report environment must be a ValidationEnvironment record.",
    ))
    report.execution isa ExecutionOutcome || throw(ArgumentError(
        "Close-encounter method report execution must be an ExecutionOutcome record.",
    ))
    _record_fields_equal(report.definition, result.definition) || throw(ArgumentError(
        "Close-encounter method report benchmark definition or version does not match.",
    ))
    _record_fields_equal(report.configuration, result.configuration) || throw(ArgumentError(
        "Close-encounter method report configuration does not match the benchmark report.",
    ))
    _record_fields_equal(report.environment, result.environment) || throw(ArgumentError(
        "Close-encounter method report provenance does not match the benchmark report.",
    ))
    report
end

function _close_encounter_execution(report, result::ValidationCaseResult)
    method_execution = report.execution
    method_execution.actual == actual_completed ? result.execution : method_execution
end

function _push_close_metric!(metrics, source, field, metric_id, label; kwargs...)
    hasproperty(source, field) || return
    push!(metrics, ValidationMetric(metric_id, label, getproperty(source, field); kwargs...))
end

function _close_encounter_method_metrics(report, execution::ExecutionOutcome, configuration)
    metrics = AbstractValidationMetric[]
    push!(metrics, ValidationMetric(
        :integration_status,
        "Integration status",
        Symbol(stable_string(execution.actual));
        role=role_diagnostic,
    ))
    if hasproperty(report, :final_time)
        push!(metrics, ValidationMetric(
            :final_time_residual,
            "Final-time residual",
            abs(report.final_time - last(configuration.time_interval));
            scale=scale_duration,
            role=role_diagnostic,
            aggregation=aggregation_final,
        ))
    end
    if hasproperty(report, :errors)
        errors = report.errors
        for (field, metric_id, label, aggregation) in (
            (:maximum_position, :maximum_position_error, "Maximum position error", aggregation_maximum),
            (:maximum_velocity, :maximum_velocity_error, "Maximum velocity error", aggregation_maximum),
            (:maximum_combined, :maximum_state_error, "Maximum state error", aggregation_maximum),
            (:final_position, :final_position_error, "Final position error", aggregation_final),
            (:final_velocity, :final_velocity_error, "Final velocity error", aggregation_final),
            (:final_combined, :final_state_error, "Final state error", aggregation_final),
        )
            _push_close_metric!(
                metrics, errors, field, metric_id, label;
                scale=scale_absolute, role=role_descriptive, aggregation,
            )
        end
    end
    if hasproperty(report, :conservation)
        conservation = report.conservation
        for (field, metric_id, label, scale) in (
            (:maximum_relative_energy_drift, :maximum_relative_energy_drift, "Maximum relative energy drift", scale_relative),
            (:maximum_momentum_drift, :maximum_linear_momentum_drift, "Maximum linear-momentum drift", scale_absolute),
            (:maximum_angular_momentum_drift, :maximum_angular_momentum_drift, "Maximum angular-momentum drift", scale_absolute),
            (:maximum_com_residual, :maximum_center_of_mass_residual, "Maximum centre-of-mass residual", scale_absolute),
            (:minimum_separation, :minimum_pair_separation, "Minimum pair separation", scale_absolute),
        )
            aggregation = field == :minimum_separation ? aggregation_minimum : aggregation_maximum
            _push_close_metric!(
                metrics, conservation, field, metric_id, label;
                scale, role=role_descriptive, aggregation,
            )
        end
    end
    _push_close_metric!(
        metrics, report, :periapsis_time_error,
        :periapsis_time_error, "Periapsis time error";
        scale=scale_duration, role=role_descriptive, aggregation=aggregation_final,
    )
    _push_close_metric!(
        metrics, report, :periapsis_separation_error,
        :periapsis_separation_error, "Periapsis separation error";
        scale=scale_absolute, role=role_descriptive, aggregation=aggregation_final,
    )
    _push_close_metric!(
        metrics, report, :transition_residual,
        :transition_state_residual, "Transition state residual";
        scale=scale_absolute, role=role_descriptive, aggregation=aggregation_maximum,
    )
    Tuple(metrics)
end

function _close_encounter_solver_statistics(report)
    hasproperty(report, :work) || return nothing
    work = report.work
    SolverStatistics(
        accepted_steps=hasproperty(work, :accepted_steps) ? work.accepted_steps : nothing,
        rejected_steps=hasproperty(work, :rejected_steps) ? work.rejected_steps : nothing,
        rhs_evaluations=hasproperty(work, :rhs_evaluations) ? work.rhs_evaluations : nothing,
        saved_states=hasproperty(work, :saved_states) ? work.saved_states : nothing,
        elapsed_seconds=hasproperty(report, :elapsed) ? report.elapsed : nothing,
        segment_count=hasproperty(report, :segments) ? report.segments : nothing,
        switch_count=hasproperty(report, :switches) ? report.switches : nothing,
    )
end

function _close_encounter_notes(report, result::ValidationCaseResult)
    summaries = String[]
    if !isnothing(report.execution.summary)
        push!(summaries, report.execution.summary)
    end
    !isnothing(result.execution.summary) && push!(summaries, result.execution.summary)
    isempty(summaries) ? nothing : join(summaries, " ")
end

"""
Build the explicitly ordered close-encounter representation series.

An unsuccessful method outcome is primary for its point. Otherwise an
unsuccessful combined benchmark outcome takes precedence; when both complete,
the combined benchmark outcome is retained.
"""
function close_encounter_representation_investigation_series(
    result::ValidationCaseResult,
    method_reports,
)
    _record_fields_equal(result.definition, close_encounter_case_definition()) ||
        throw(ArgumentError(
            "Close-encounter benchmark definition or version does not match the approved experiment.",
        ))
    _record_fields_equal(
        result.configuration,
        _close_encounter_investigation_configuration(),
    ) || throw(ArgumentError(
        "Close-encounter benchmark configuration does not match the approved fixed controls.",
    ))

    reports = Dict{Symbol,Any}()
    for report in Tuple(method_reports)
        point_id = _close_encounter_representation_id(report)
        haskey(reports, point_id) && throw(ArgumentError(
            "Duplicate close-encounter method report for point $point_id.",
        ))
        reports[point_id] = _validate_close_encounter_method_report(report, result)
    end

    definition = close_encounter_representation_investigation_definition()
    points = map(CLOSE_ENCOUNTER_INVESTIGATION_REPRESENTATIONS) do point_id
        haskey(reports, point_id) || throw(ArgumentError(
            "Close-encounter method reports do not contain required point $point_id.",
        ))
        report = reports[point_id]
        execution = _close_encounter_execution(report, result)
        InvestigationMeasurementPoint(
            point_id,
            definition,
            result.configuration,
            ValidationParameter(:representation_mode, point_id),
            result.environment,
            execution,
            _close_encounter_method_metrics(report, execution, result.configuration),
            _close_encounter_solver_statistics(report);
            notes=_close_encounter_notes(report, result),
        )
    end
    InvestigationMeasurementSeries(
        :close_encounter_representation,
        "Close-encounter propagation-representation comparison",
        "Ordered Investigation 1 measurements for Cartesian, automatic-switching, and explicit regularized propagation.",
        definition,
        Tuple(points),
    )
end
