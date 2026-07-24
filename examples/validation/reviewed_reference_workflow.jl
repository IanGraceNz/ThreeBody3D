# Canonical reviewed-reference validation workflow.
#
# Usage from the repository root:
#
#   julia --project=. examples/validation/reviewed_reference_workflow.jl \
#       path/to/reviewed-reference.toml \
#       validation_reports/current-suite.toml \
#       validation_reports/reference-comparison.toml
#
# The reviewed reference is read-only. This example never creates or updates a
# baseline; reference approval remains an explicit human-reviewed operation.
# Run with --help to print the prerequisite and command forms without executing
# the validation suite.

include(joinpath(@__DIR__, "run_validation_suite.jl"))


const REVIEWED_REFERENCE_USAGE = """
Usage:
  julia --project=. examples/validation/reviewed_reference_workflow.jl REFERENCE
  julia --project=. examples/validation/reviewed_reference_workflow.jl REFERENCE SUITE_REPORT
  julia --project=. examples/validation/reviewed_reference_workflow.jl REFERENCE SUITE_REPORT COMPARISON_REPORT

REFERENCE must be an existing, immutable ValidationReferenceRecord TOML file
that has already completed the project's scientific and code-review process.
This command does not create, approve, replace, or update a reference baseline.

To run the validation suite without a reviewed reference, use:
  julia --project=. examples/validation/run_validation_suite.jl

See VALIDATION_WORKFLOW.md for candidate-reference preparation and approval.
"""

reviewed_reference_usage() = REVIEWED_REFERENCE_USAGE

"""
    run_reviewed_reference_workflow(reference_path;
        suite_report_path=nothing,
        comparison_report_path=nothing,
        comparison_io=stdout)

Run the complete scientific validation suite, optionally write its deterministic
suite report, compare it with one immutable reviewed reference, render the
PASS/FAIL/ERROR comparison, optionally write a deterministic comparison
artifact, and return the complete high-level runner result.
"""
function run_reviewed_reference_workflow(
    reference_path::AbstractString;
    suite_report_path=nothing,
    comparison_report_path=nothing,
    comparison_io::IO=stdout,
)
    isfile(reference_path) || throw(ArgumentError(
        "Reviewed reference does not exist: $(abspath(reference_path))",
    ))

    run = run_validation_suite(
        ;
        report_path=suite_report_path,
        reference_source=reference_path,
        comparison_io,
    )
    isnothing(run.comparison) && error("The reviewed-reference comparison was not produced.")

    written_comparison = isnothing(comparison_report_path) ? nothing :
        write_report_atomic(comparison_report_path, run.comparison)
    !isnothing(written_comparison) && println(
        "Reference comparison artifact: ",
        written_comparison,
    )

    merge(run, (; comparison_report_path=written_comparison))
end

if abspath(PROGRAM_FILE) == @__FILE__
    if isempty(ARGS) || ARGS[1] in ("-h", "--help")
        print(stderr, reviewed_reference_usage())
        isempty(ARGS) && exit(2)
        exit(0)
    end
    length(ARGS) <= 3 || throw(ArgumentError(
        "Too many arguments. Run with --help for the accepted command forms.",
    ))
    reference_path = ARGS[1]
    suite_report_path = length(ARGS) >= 2 ? ARGS[2] : nothing
    comparison_report_path = length(ARGS) >= 3 ? ARGS[3] : nothing
    workflow = run_reviewed_reference_workflow(
        reference_path;
        suite_report_path,
        comparison_report_path,
    )
    workflow.passed || exit(1)
end
