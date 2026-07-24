# High-level finalization for completed scientific validation suites.

const VALIDATION_REFERENCE_ENV = "THREEBODY3D_VALIDATION_REFERENCE"

"""Resolve the optional reviewed-reference path requested for a validation run."""
function resolve_validation_reference_path(; environment=ENV)
    value = get(environment, VALIDATION_REFERENCE_ENV, nothing)
    isnothing(value) && return nothing
    text = String(value)
    isempty(strip(text)) && throw(ArgumentError(
        "Environment variable $VALIDATION_REFERENCE_ENV must not be empty.",
    ))
    abspath(text)
end

"""
    finalize_validation_suite(io, suite; report_path=nothing, reference_source=nothing)
    finalize_validation_suite(suite; report_path=nothing, reference_source=nothing)

Finalize one completed validation suite by optionally writing its deterministic
suite report and optionally comparing it with an immutable reviewed reference.

The returned named tuple contains the overall `passed` decision, the original
`suite`, the written `report_path`, and the structured reference `comparison`
(or `nothing` when no reference was requested). A requested reference
comparison participates in the overall pass/fail decision and is rendered to
`io` through the established reference-presentation API.

This workflow never creates, updates, or writes a reference record.
"""
function finalize_validation_suite(
    io::IO,
    suite::ValidationSuiteResult;
    report_path=nothing,
    reference_source=nothing,
)
    written_report = write_validation_suite_report(suite, report_path)
    comparison = isnothing(reference_source) ? nothing :
                 run_reference_comparison(io, suite, reference_source)
    reference_passed = isnothing(comparison) ||
                       comparison.status == reference_comparison_pass
    (
        passed=suite.status == suite_pass && reference_passed,
        suite,
        report_path=written_report,
        comparison,
    )
end

finalize_validation_suite(
    suite::ValidationSuiteResult;
    report_path=nothing,
    reference_source=nothing,
) = finalize_validation_suite(
    stdout,
    suite;
    report_path,
    reference_source,
)
