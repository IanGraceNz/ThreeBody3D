# Hierarchical-triple adapter for the second Investigation 1 pilot series.

const HIERARCHICAL_TRIPLE_INVESTIGATION_DEFINITION_VERSION = "1.0.0"
const HIERARCHICAL_TRIPLE_INVESTIGATION_PROFILES = (:fast, :accurate)
const HIERARCHICAL_TRIPLE_INVESTIGATION_DURATION = 100.0
const HIERARCHICAL_TRIPLE_INVESTIGATION_SAVEAT = 0.02
const HIERARCHICAL_TRIPLE_INVESTIGATION_METRICS = (
    :minimum_hierarchy_ratio,
    :maximum_relative_energy_drift,
    :maximum_linear_momentum_drift,
    :maximum_angular_momentum_drift,
    :maximum_center_of_mass_residual,
    :minimum_pair_separation,
)

"""Define the fixed-profile hierarchical-triple Investigation 1 experiment."""
function hierarchical_triple_profile_investigation_definition()
    InvestigationDefinition(
        :hierarchical_triple_profile,
        "Hierarchical-triple solver-profile comparison",
        "Compare the package-owned fast and accurate solver profiles over the fixed 100-time-unit hierarchical-triple workload.",
        hierarchical_triple_case_definition(),
        :solver_profile,
        (
            ValidationParameter(
                :duration,
                HIERARCHICAL_TRIPLE_INVESTIGATION_DURATION,
            ),
            ValidationParameter(:saveat, HIERARCHICAL_TRIPLE_INVESTIGATION_SAVEAT),
        ),
        HIERARCHICAL_TRIPLE_INVESTIGATION_METRICS,
        (),
        HIERARCHICAL_TRIPLE_INVESTIGATION_DEFINITION_VERSION,
    )
end

function _hierarchical_triple_performance_configuration(profile::Symbol)
    tolerances = _hierarchical_triple_profile_tolerances(profile)
    hierarchical_triple_performance_configuration(;
        duration=HIERARCHICAL_TRIPLE_INVESTIGATION_DURATION,
        solver=profile,
        saveat=HIERARCHICAL_TRIPLE_INVESTIGATION_SAVEAT,
        tolerances...,
    )
end

function _validate_hierarchical_triple_performance_report(
    report::PerformanceBenchmarkReport,
    profile::Symbol,
)
    expected_definition = hierarchical_triple_accuracy_work_definition(profile)
    _record_fields_equal(report.definition, expected_definition) || throw(ArgumentError(
        "Hierarchical-triple performance benchmark definition does not match profile $profile.",
    ))
    _record_fields_equal(
        report.configuration,
        _hierarchical_triple_performance_configuration(profile),
    ) || throw(ArgumentError(
        "Hierarchical-triple performance configuration does not match the approved fixed controls.",
    ))
    report
end

function _validate_hierarchical_triple_case_result(
    result::ValidationCaseResult,
    environment::ValidationEnvironment,
    profile::Symbol,
)
    _record_fields_equal(
        result.definition,
        hierarchical_triple_case_definition(),
    ) || throw(ArgumentError(
        "Hierarchical-triple validation benchmark definition or version does not match the approved experiment.",
    ))
    _record_fields_equal(result.environment, environment) || throw(ArgumentError(
        "Hierarchical-triple validation and performance provenance must match.",
    ))
    configuration = result.configuration
    configuration.solver == profile || throw(ArgumentError(
        "Hierarchical-triple validation configuration does not match profile $profile.",
    ))
    tolerances = _hierarchical_triple_profile_tolerances(profile)
    configuration.absolute_tolerance == tolerances.abstol &&
        configuration.relative_tolerance == tolerances.reltol || throw(ArgumentError(
        "Hierarchical-triple validation tolerances do not match the approved profile configuration.",
    ))
    configuration.time_interval ==
        (0.0, HIERARCHICAL_TRIPLE_INVESTIGATION_DURATION) || throw(ArgumentError(
        "Hierarchical-triple validation time interval does not match the approved duration.",
    ))
    configuration.sampling ==
        "saveat=$(HIERARCHICAL_TRIPLE_INVESTIGATION_SAVEAT)" || throw(ArgumentError(
        "Hierarchical-triple validation sampling does not match the approved saveat.",
    ))
    map(parameter -> parameter.parameter_id, configuration.parameters) ==
        (:duration,) || throw(ArgumentError(
        "Hierarchical-triple validation parameters do not match the approved controls.",
    ))
    _parameter_value(configuration.parameters, :duration) ==
        HIERARCHICAL_TRIPLE_INVESTIGATION_DURATION || throw(ArgumentError(
        "Hierarchical-triple validation duration does not match the approved fixed control.",
    ))
    result
end

function _hierarchical_triple_metrics(result::ValidationCaseResult)
    metrics = Tuple(
        metric for metric_id in HIERARCHICAL_TRIPLE_INVESTIGATION_METRICS
        for metric in result.metrics if metric.metric_id == metric_id
    )
    metric_ids = map(metric -> metric.metric_id, metrics)
    _unique_identifiers(metric_ids, "hierarchical-triple investigation metrics")
    if result.execution.actual == actual_completed &&
       metric_ids != HIERARCHICAL_TRIPLE_INVESTIGATION_METRICS
        throw(ArgumentError(
            "Hierarchical-triple validation result does not retain the complete investigation metrics.",
        ))
    end
    metrics
end

function _hierarchical_triple_investigation_point(
    result::ValidationCaseResult,
    report::PerformanceBenchmarkReport,
    definition::InvestigationDefinition,
    profile::Symbol,
)
    _validate_hierarchical_triple_performance_report(report, profile)
    _validate_hierarchical_triple_case_result(result, report.environment, profile)
    InvestigationMeasurementPoint(
        profile,
        definition,
        report.configuration,
        ValidationParameter(:solver_profile, profile),
        report.environment,
        _investigation_execution(result, report),
        _hierarchical_triple_metrics(result),
        _retained_solver_statistics(result, report);
        performance_report=report,
        notes=_investigation_notes(result, report),
    )
end

"""
Build the ordered fast/accurate hierarchical-triple Investigation 1 series.

An unsuccessful core outcome takes precedence as the point's primary
execution; otherwise the performance outcome is primary. The complete
performance report is retained independently in either case.
"""
function hierarchical_triple_profile_investigation_series(
    suite::PerformanceSuiteReport,
    case_results,
)
    reports = _performance_reports_by_id(suite.benchmarks)
    normalized_results = Tuple(case_results)
    all(result -> result isa ValidationCaseResult, normalized_results) || throw(
        ArgumentError("case_results must contain ValidationCaseResult records."),
    )
    results = Dict{Symbol,ValidationCaseResult}()
    for result in normalized_results
        profile = result.configuration.solver
        profile isa Symbol || throw(ArgumentError(
            "Every hierarchical-triple case result must declare a solver profile.",
        ))
        haskey(results, profile) && throw(ArgumentError(
            "Duplicate hierarchical-triple case result for profile $profile.",
        ))
        results[profile] = result
    end

    definition = hierarchical_triple_profile_investigation_definition()
    points = map(HIERARCHICAL_TRIPLE_INVESTIGATION_PROFILES) do profile
        benchmark_id = Symbol("hierarchical_triple_accuracy_work_", profile)
        haskey(reports, benchmark_id) || throw(ArgumentError(
            "Performance suite does not contain benchmark $benchmark_id.",
        ))
        haskey(results, profile) || throw(ArgumentError(
            "Core validation results do not contain profile $profile.",
        ))
        _hierarchical_triple_investigation_point(
            results[profile],
            reports[benchmark_id],
            definition,
            profile,
        )
    end
    InvestigationMeasurementSeries(
        :hierarchical_triple_profile,
        "Hierarchical-triple solver-profile comparison",
        "Ordered Investigation 1 measurements for the fast and accurate solver profiles.",
        definition,
        Tuple(points),
    )
end
