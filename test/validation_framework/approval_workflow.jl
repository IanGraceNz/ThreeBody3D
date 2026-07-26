function _manual_approval_fixture()
    _approved_reference_serialization_fixture().observation
end

function _manual_approval_kwargs(; known_limitations="Synthetic benchmark only.")
    (
        reference_id="manual-reference-v1",
        reference_schema_version="1.0.0",
        benchmark_scope="Synthetic validation reference workflow.",
        methodology="Manual review of retained validation metrics and comparison policies.",
        reviewer="Scientific reviewer",
        approval_date="2026-07-26",
        approval_rationale="The retained evidence and policies were reviewed and accepted.",
        known_limitations=known_limitations,
    )
end

@testset "Manual approved scientific reference creation" begin
    record = _manual_approval_fixture()
    metadata = _manual_approval_kwargs()
    approved = approve_validation_reference(record; metadata...)

    @test approved isa ApprovedScientificReference
    @test approved.observation === record
    @test approved.reference_id == metadata.reference_id
    @test approved.reference_schema_version == metadata.reference_schema_version
    @test approved.benchmark_scope == metadata.benchmark_scope
    @test approved.methodology == metadata.methodology
    @test approved.reviewer == metadata.reviewer
    @test approved.approval_date == metadata.approval_date
    @test approved.approval_rationale == metadata.approval_rationale
    @test approved.known_limitations == metadata.known_limitations

    without_limitations = approve_validation_reference(
        record;
        _manual_approval_kwargs(known_limitations=nothing)...,
    )
    @test isnothing(without_limitations.known_limitations)

    @test_throws UndefKeywordError approve_validation_reference(
        record;
        reference_id="manual-reference-v1",
        reference_schema_version="1.0.0",
        benchmark_scope="Synthetic validation reference workflow.",
        methodology="Manual review.",
        reviewer="Scientific reviewer",
        approval_date="2026-07-26",
    )
    invalid_metadata = merge(_manual_approval_kwargs(), (reviewer="",))
    @test_throws ArgumentError approve_validation_reference(
        record;
        invalid_metadata...,
    )
end

@testset "Manual approved scientific reference persistence and overwrite protection" begin
    record = _manual_approval_fixture()
    metadata = _manual_approval_kwargs()

    mktempdir() do directory
        path = joinpath(directory, "approved_reference.toml")
        result = approve_validation_reference(path, record; metadata...)

        @test result.reference isa ApprovedScientificReference
        @test result.path == abspath(path)
        @test isfile(path)
        @test !isfile(path * ".tmp")
        original_text = read(path, String)
        @test approved_scientific_reference_text(result.reference) == original_text

        @test_throws ArgumentError approve_validation_reference(
            path,
            record;
            metadata...,
        )
        @test read(path, String) == original_text
        @test !isfile(path * ".tmp")

        replacement_metadata = merge(
            metadata,
            (
                reference_id="manual-reference-v2",
                approval_rationale="A later explicit review superseded the previous approval.",
            ),
        )
        replacement = approve_validation_reference(
            path,
            record;
            overwrite=true,
            replacement_metadata...,
        )
        restored = read_approved_scientific_reference(path)
        @test replacement.reference.reference_id == "manual-reference-v2"
        @test restored.reference_id == "manual-reference-v2"
        @test restored.approval_rationale == replacement_metadata.approval_rationale
        @test read(path, String) != original_text
        @test !isfile(path * ".tmp")
    end
end
