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
