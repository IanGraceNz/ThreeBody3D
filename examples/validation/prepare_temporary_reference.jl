# Build a disposable reference record for exercising the VF-4 workflow.
#
# This example is intentionally NOT a baseline-approval command. It retains a
# small, explicit policy set solely so contributors can test reference loading,
# comparison, presentation, and serialization before deleting the artifact.
#
# Usage from the repository root:
#
#   julia --project=. examples/validation/prepare_temporary_reference.jl \
#       validation_reports/vf4-temporary/current-suite.toml \
#       validation_reports/vf4-temporary/temporary-reference.toml \
#       SOURCE_COMMIT

include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

const TEMPORARY_REFERENCE_USAGE = """
Usage:
  julia --project=. examples/validation/prepare_temporary_reference.jl SUITE_REPORT OUTPUT_REFERENCE SOURCE_COMMIT

Build a disposable ValidationReferenceRecord containing a small, explicit set
of demonstration policies. The output is for VF-4 workflow testing only. It is
not scientifically approved and must not be committed as an approved baseline.
"""

prepare_temporary_reference_usage() = TEMPORARY_REFERENCE_USAGE

function temporary_reference_policies()
    (
        ValidationMetricReferencePolicy(
            :figure_eight,
            :integration_status,
            reference_exact,
        ),
        ValidationMetricReferencePolicy(
            :figure_eight,
            :maximum_relative_energy_drift,
            reference_tolerance;
            absolute_tolerance=1.0e-10,
        ),
        ValidationMetricReferencePolicy(
            :hierarchical_triple,
            :integration_status,
            reference_exact,
        ),
        ValidationMetricReferencePolicy(
            :switching_diagnostics,
            :process_completed,
            reference_exact,
        ),
    )
end

function prepare_temporary_reference(
    suite_source,
    output_path,
    source_commit;
    provenance="Disposable VF-4 workflow exercise; not an approved baseline.",
)
    suite = read_suite_report(suite_source)
    suite.status == suite_pass || throw(ArgumentError(
        "Temporary references may only be built from a passing suite report.",
    ))
    record = build_reference_record(
        suite,
        temporary_reference_policies();
        source_commit,
        provenance,
    )
    written = write_report_atomic(output_path, record)
    println("Temporary reference written: ", written)
    println("Retained metrics: ", length(record.metrics))
    println("This file is not approved and must not be committed as a baseline.")
    record
end

if abspath(PROGRAM_FILE) == @__FILE__
    if isempty(ARGS) || ARGS[1] in ("-h", "--help")
        print(stderr, prepare_temporary_reference_usage())
        isempty(ARGS) && exit(2)
        exit(0)
    end
    length(ARGS) == 3 || throw(ArgumentError(
        "Expected SUITE_REPORT, OUTPUT_REFERENCE, and SOURCE_COMMIT. Run with --help for usage.",
    ))
    prepare_temporary_reference(ARGS[1], ARGS[2], ARGS[3])
end
