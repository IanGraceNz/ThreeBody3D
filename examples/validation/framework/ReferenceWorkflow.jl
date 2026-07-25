# Explicit orchestration for comparing completed suites with reviewed references.

"""
    run_reference_comparison(io, suite, source)
    run_reference_comparison(suite, source)

Load one immutable reviewed reference from `source`, compare it with a completed
validation suite, render the complete comparison report, and return the
structured comparison result.

`source` may be a path or an `IO`, as accepted by `read_reference_record`.
This workflow never creates, updates, or writes a reference record.
"""
function run_reference_comparison(
    io::IO,
    suite::ValidationSuiteResult,
    source,
)
    reference = read_reference_record(source)
    comparison = compare_reference(suite, reference)
    render_reference_report(io, comparison)
    comparison
end

run_reference_comparison(suite::ValidationSuiteResult, source) =
    run_reference_comparison(stdout, suite, source)

"""
    run_approved_scientific_reference_comparison(io, suite, source)
    run_approved_scientific_reference_comparison(suite, source)

Load one immutable approved scientific reference from `source`, compare its
embedded observation with a completed validation suite through the existing
reference-comparison engine, render approval metadata and numerical evidence,
and return both records in a named tuple.

`source` may be a path or an `IO`, as accepted by
`read_approved_scientific_reference`. This workflow is read-only: it never
creates, approves, replaces, updates, or writes a scientific reference.
"""
function run_approved_scientific_reference_comparison(
    io::IO,
    suite::ValidationSuiteResult,
    source,
)
    approved_reference = read_approved_scientific_reference(source)
    comparison = compare_reference(suite, approved_reference.observation)
    render_approved_scientific_reference_report(io, approved_reference, comparison)
    (; approved_reference, comparison)
end

run_approved_scientific_reference_comparison(
    suite::ValidationSuiteResult,
    source,
) = run_approved_scientific_reference_comparison(stdout, suite, source)
