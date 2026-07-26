# Explicit manual creation and persistence of approved scientific references.

"""
    approve_validation_reference(record; reference_id, reference_schema_version,
        benchmark_scope, methodology, reviewer, approval_date,
        approval_rationale, known_limitations=nothing)

Create one `ApprovedScientificReference` from a reviewed
`ValidationReferenceRecord` and explicit human approval metadata.

This function performs no scientific inference and writes no files. Every
approval decision must be supplied by the caller. Validation runs never invoke
this function automatically.
"""
function approve_validation_reference(
    record::ValidationReferenceRecord;
    reference_id,
    reference_schema_version,
    benchmark_scope,
    methodology,
    reviewer,
    approval_date,
    approval_rationale,
    known_limitations=nothing,
)
    ApprovedScientificReference(
        reference_id,
        reference_schema_version,
        record;
        benchmark_scope,
        methodology,
        reviewer,
        approval_date,
        approval_rationale,
        known_limitations,
    )
end

"""
    approve_validation_reference(path, record; overwrite=false, kwargs...)

Create and atomically persist one approved scientific reference at `path`.
Existing files are rejected unless `overwrite=true` is supplied explicitly.
The returned named tuple contains the approved reference and the absolute path.

The overwrite check occurs before construction or writing, and no validation
runner calls this method automatically.
"""
function approve_validation_reference(
    path::AbstractString,
    record::ValidationReferenceRecord;
    overwrite::Bool=false,
    kwargs...,
)
    final_path = abspath(path)
    isfile(final_path) && !overwrite && throw(ArgumentError(
        "Approved scientific reference already exists at $final_path; pass overwrite=true to replace it explicitly.",
    ))
    reference = approve_validation_reference(record; kwargs...)
    written_path = write_report_atomic(final_path, reference)
    (; reference, path=written_path)
end
