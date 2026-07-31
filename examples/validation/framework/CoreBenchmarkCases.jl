# Structured adapters for the two pilot package-owned validation benchmarks.

import ThreeBody3D

function _civil_date_from_unix_days(days::Integer)
    shifted_days = days + 719468
    era = fld(shifted_days, 146097)
    day_of_era = shifted_days - era * 146097
    year_of_era = fld(
        day_of_era - fld(day_of_era, 1460) + fld(day_of_era, 36524) - fld(day_of_era, 146096),
        365,
    )
    year = year_of_era + era * 400
    day_of_year = day_of_era - (365 * year_of_era + fld(year_of_era, 4) - fld(year_of_era, 100))
    month_phase = fld(5 * day_of_year + 2, 153)
    day = day_of_year - fld(153 * month_phase + 2, 5) + 1
    month = month_phase + (month_phase < 10 ? 3 : -9)
    year += month <= 2
    (year, month, day)
end

function _current_utc_timestamp()
    unix_seconds = floor(Int, time())
    unix_days, seconds_of_day = fldmod(unix_seconds, 86_400)
    year, month, day = _civil_date_from_unix_days(unix_days)
    hour, remainder = fldmod(seconds_of_day, 3_600)
    minute, second = fldmod(remainder, 60)
    string(
        year, "-", lpad(month, 2, '0'), "-", lpad(day, 2, '0'),
        "T", lpad(hour, 2, '0'), ":", lpad(minute, 2, '0'), ":", lpad(second, 2, '0'), "Z",
    )
end

const VALIDATION_SCHEMA_VERSION = "1.0.0"
const CORE_BENCHMARK_DEFINITION_VERSION = "1.0.0"

"""Collect reproducibility metadata without making Git availability mandatory."""
function current_validation_environment(; timestamp_utc=_current_utc_timestamp())
    package_version = try
        string(Base.pkgversion(ThreeBody3D))
    catch
        "0.4.0"
    end
    ValidationEnvironment(
        VALIDATION_SCHEMA_VERSION,
        package_version,
        nothing,
        nothing,
        string(VERSION),
        string(Sys.KERNEL),
        string(Sys.ARCH),
        Threads.nthreads(),
        timestamp_utc,
    )
end

function figure_eight_case_definition()
    ValidationCaseDefinition(
        :figure_eight,
        "Figure-eight validation benchmark",
        "Strongly coupled periodic equal-mass three-body choreography propagated for ten periods.",
        (:periodic_orbit, :conservation, :reference_state),
        (:figure_eight, :core_benchmark),
        "examples/validation/figure_eight_benchmark.jl",
        (:standard,),
        expected_completed,
        true,
        CORE_BENCHMARK_DEFINITION_VERSION,
        "V0_5_VALIDATION_ARCHITECTURE_DESIGN.md",
    )
end

function hierarchical_triple_case_definition()
    ValidationCaseDefinition(
        :hierarchical_triple,
        "Hierarchical-triple validation benchmark",
        "Long-duration weakly perturbed hierarchical triple with conservation and hierarchy checks.",
        (:hierarchical_system, :conservation, :multiscale),
        (:hierarchical_triple, :core_benchmark),
        "examples/validation/hierarchical_triple_benchmark.jl",
        (:standard,),
        expected_completed,
        true,
        CORE_BENCHMARK_DEFINITION_VERSION,
        "V0_5_VALIDATION_ARCHITECTURE_DESIGN.md",
    )
end

function _benchmark_execution(report)
    report.status == :completed && return ExecutionOutcome(actual_completed; exit_code=0)
    ExecutionOutcome(
        actual_terminated;
        exit_code=1,
        summary="Benchmark returned status $(report.status).",
    )
end

function _record_common_benchmark_metrics!(builder, report)
    record_metric!(builder, ValidationMetric(
        :integration_status, "Integration completed", report.status;
        role=role_acceptance,
    ))
    record_metric!(builder, ValidationMetric(
        :final_time_residual, "Final-time residual",
        abs(report.final_time - report.expected_final_time);
        scale=scale_duration, role=role_acceptance, aggregation=aggregation_final,
    ))
    record_metric!(builder, ValidationMetric(
        :maximum_relative_energy_drift, "Maximum relative energy drift",
        report.diagnostics.maximum_relative_energy_drift;
        scale=scale_relative, role=role_acceptance, aggregation=aggregation_maximum,
    ))
    record_metric!(builder, ValidationMetric(
        :maximum_linear_momentum_drift, "Maximum momentum drift",
        report.diagnostics.maximum_linear_momentum_drift;
        scale=scale_absolute, role=role_acceptance, aggregation=aggregation_maximum,
    ))
    record_metric!(builder, ValidationMetric(
        :maximum_angular_momentum_drift, "Maximum angular-momentum drift",
        report.diagnostics.maximum_angular_momentum_drift;
        scale=scale_absolute, role=role_acceptance, aggregation=aggregation_maximum,
    ))
    record_metric!(builder, ValidationMetric(
        :maximum_center_of_mass_residual, "Maximum centre-of-mass residual",
        report.diagnostics.maximum_center_of_mass_residual;
        scale=scale_absolute, role=role_acceptance, aggregation=aggregation_maximum,
    ))
    record_metric!(builder, ValidationMetric(
        :minimum_pair_separation, "Minimum pair separation",
        report.diagnostics.minimum_separation;
        scale=scale_dimensional, role=role_descriptive, aggregation=aggregation_minimum,
    ))
    builder
end

function _declare_common_benchmark_criteria!(builder;
    final_time_limit,
    energy_limit,
    momentum_limit,
    angular_momentum_limit,
    center_of_mass_limit,
)
    declare_criterion!(builder, AcceptanceCriterionSpecification(
        :integration_completed, "Integration completed", :integration_status,
        relation_expected_status; expected_value=:completed,
    ))
    for (criterion_id, label, metric_id, limit) in (
        (:final_time_within_limit, "Final-time residual", :final_time_residual, final_time_limit),
        (:energy_drift_within_limit, "Maximum relative energy drift", :maximum_relative_energy_drift, energy_limit),
        (:momentum_drift_within_limit, "Maximum momentum drift", :maximum_linear_momentum_drift, momentum_limit),
        (:angular_momentum_drift_within_limit, "Maximum angular-momentum drift", :maximum_angular_momentum_drift, angular_momentum_limit),
        (:center_of_mass_within_limit, "Maximum centre-of-mass residual", :maximum_center_of_mass_residual, center_of_mass_limit),
    )
        declare_criterion!(builder, AcceptanceCriterionSpecification(
            criterion_id, label, metric_id, relation_less_than_or_equal;
            expected_value=limit,
        ))
    end
    builder
end

function build_figure_eight_case_result(
    report,
    environment::ValidationEnvironment;
    energy_limit,
    momentum_limit,
    angular_momentum_limit,
    center_of_mass_limit,
    periodicity_limit,
    final_time_limit,
)
    builder = ValidationCaseResultBuilder(figure_eight_case_definition(), environment)
    record_configuration!(builder, ValidationConfiguration(
        solver=report.profile,
        time_interval=(report.initial_time, report.expected_final_time),
        sampling="saveat=0.02",
        thresholds=(
            ValidationParameter(:energy_drift_limit, energy_limit),
            ValidationParameter(:momentum_drift_limit, momentum_limit),
            ValidationParameter(:angular_momentum_drift_limit, angular_momentum_limit),
            ValidationParameter(:center_of_mass_residual_limit, center_of_mass_limit),
            ValidationParameter(:periodicity_error_limit, periodicity_limit),
            ValidationParameter(:final_time_residual_limit, final_time_limit),
        ),
        parameters=(ValidationParameter(:periods, 10),),
    ))
    _record_common_benchmark_metrics!(builder, report)
    record_metric!(builder, ValidationMetric(
        :periodicity_error, "Ten-period state periodicity error", report.periodicity_error;
        scale=scale_absolute, role=role_acceptance, aggregation=aggregation_final,
    ))
    _declare_common_benchmark_criteria!(builder;
        final_time_limit,
        energy_limit,
        momentum_limit,
        angular_momentum_limit,
        center_of_mass_limit,
    )
    declare_criterion!(builder, AcceptanceCriterionSpecification(
        :periodicity_within_limit,
        "Ten-period state periodicity error",
        :periodicity_error,
        relation_less_than_or_equal;
        expected_value=periodicity_limit,
    ))
    record_solver_statistics!(builder, SolverStatistics(
        accepted_steps=report.accepted_steps,
        rejected_steps=report.rejected_steps,
        rhs_evaluations=report.rhs_evaluations,
        saved_states=report.saved_states,
    ))
    evaluate_criteria!(builder)
    finish_execution!(builder, _benchmark_execution(report))
    build_case_result(builder)
end

function build_hierarchical_triple_case_result(
    report,
    environment::ValidationEnvironment;
    energy_limit,
    momentum_limit,
    angular_momentum_limit,
    center_of_mass_limit,
    minimum_ratio_limit,
    final_time_limit,
)
    builder = ValidationCaseResultBuilder(hierarchical_triple_case_definition(), environment)
    record_configuration!(builder, ValidationConfiguration(
        solver=report.profile,
        absolute_tolerance=1e-13,
        relative_tolerance=1e-13,
        time_interval=(report.initial_time, report.expected_final_time),
        sampling="saveat=0.02",
        thresholds=(
            ValidationParameter(:energy_drift_limit, energy_limit),
            ValidationParameter(:momentum_drift_limit, momentum_limit),
            ValidationParameter(:angular_momentum_drift_limit, angular_momentum_limit),
            ValidationParameter(:center_of_mass_residual_limit, center_of_mass_limit),
            ValidationParameter(:minimum_hierarchy_ratio_limit, minimum_ratio_limit),
            ValidationParameter(:final_time_residual_limit, final_time_limit),
        ),
        parameters=(ValidationParameter(:duration, 100.0),),
    ))
    _record_common_benchmark_metrics!(builder, report)
    record_metric!(builder, ValidationMetric(
        :minimum_hierarchy_ratio, "Minimum hierarchy ratio",
        report.benchmark_metrics.minimum_hierarchy_ratio;
        scale=scale_dimensionless, role=role_acceptance, aggregation=aggregation_minimum,
    ))
    _declare_common_benchmark_criteria!(builder;
        final_time_limit,
        energy_limit,
        momentum_limit,
        angular_momentum_limit,
        center_of_mass_limit,
    )
    declare_criterion!(builder, AcceptanceCriterionSpecification(
        :hierarchy_ratio_within_limit,
        "Minimum hierarchy ratio",
        :minimum_hierarchy_ratio,
        relation_greater_than_or_equal;
        expected_value=minimum_ratio_limit,
    ))
    record_solver_statistics!(builder, SolverStatistics(
        accepted_steps=report.accepted_steps,
        rejected_steps=report.rejected_steps,
        rhs_evaluations=report.rhs_evaluations,
        saved_states=report.saved_states,
    ))
    evaluate_criteria!(builder)
    finish_execution!(builder, _benchmark_execution(report))
    build_case_result(builder)
end
