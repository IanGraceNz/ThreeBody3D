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
    finalize_validation_suite(
        io,
        suite;
        report_path=nothing,
        reference_source=nothing,
        approved_reference_source=nothing,
    )
    finalize_validation_suite(
        suite;
        report_path=nothing,
        reference_source=nothing,
        approved_reference_source=nothing,
    )

Finalize one completed validation suite by optionally writing its deterministic
suite report and optionally comparing it with either an immutable reviewed
reference or an approved scientific reference.

The returned named tuple contains the overall `passed` decision, the original
`suite`, the written `report_path`, and the structured reference `comparison` (or `nothing` when no reference was requested), and the loaded
`approved_reference` (or `nothing` unless an approved reference was requested).
A requested comparison participates in the overall pass/fail decision and is
rendered to `io` through the established presentation APIs.

`reference_source` and `approved_reference_source` are mutually exclusive. This
workflow never creates, approves, updates, or writes a reference record.
"""
function finalize_validation_suite(
    io::IO,
    suite::ValidationSuiteResult;
    report_path=nothing,
    reference_source=nothing,
    approved_reference_source=nothing,
)
    !isnothing(reference_source) && !isnothing(approved_reference_source) && throw(
        ArgumentError(
            "reference_source and approved_reference_source are mutually exclusive.",
        ),
    )

    written_report = write_validation_suite_report(suite, report_path)
    approved_reference = nothing
    comparison = if !isnothing(approved_reference_source)
        result = run_approved_scientific_reference_comparison(
            io,
            suite,
            approved_reference_source,
        )
        approved_reference = result.approved_reference
        result.comparison
    elseif !isnothing(reference_source)
        run_reference_comparison(io, suite, reference_source)
    else
        nothing
    end
    reference_passed = isnothing(comparison) ||
                       comparison.status == reference_comparison_pass
    (
        passed=suite.status == suite_pass && reference_passed,
        suite,
        report_path=written_report,
        comparison,
        approved_reference,
    )
end

finalize_validation_suite(
    suite::ValidationSuiteResult;
    report_path=nothing,
    reference_source=nothing,
    approved_reference_source=nothing,
) = finalize_validation_suite(
    stdout,
    suite;
    report_path,
    reference_source,
    approved_reference_source,
)
