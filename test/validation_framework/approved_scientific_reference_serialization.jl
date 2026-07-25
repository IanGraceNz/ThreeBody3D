function _approved_reference_serialization_fixture(; known_limitations="Synthetic scope only.")
    suite = _reference_record_suite()
    observation = build_reference_record(
        suite,
        (
            ValidationMetricReferencePolicy(
                :reference_case,
                :energy_drift,
                reference_tolerance;
                absolute_tolerance=1.0e-14,
                relative_tolerance=1.0e-2,
            ),
            ValidationMetricReferencePolicy(
                :reference_case,
                :completed,
                reference_exact,
            ),
            ValidationMetricReferencePolicy(
                :reference_case,
                :saved_states,
                reference_exact,
            ),
        );
        source_commit="be9e52e",
        provenance="Candidate generated from the reviewed synthetic validation case.",
    )
    ApprovedScientificReference(
        "reference-suite-v1",
        "1.0.0",
        observation;
        benchmark_scope="Synthetic reference-record behaviour.",
        methodology="Structured validation suite with deliberately retained metrics.",
        reviewer="Scientific reviewer",
        approval_date="2026-07-25",
        approval_rationale="The observation and policies were reviewed and accepted.",
        known_limitations=known_limitations,
    )
end

@testset "Deterministic approved scientific reference serialization" begin
    reference = _approved_reference_serialization_fixture()
    first_text = approved_scientific_reference_text(reference)
    second_text = approved_scientific_reference_text(reference)

    @test first_text == second_text
    @test occursin("report_kind = \"approved_scientific_reference\"", first_text)
    @test occursin("[observation]", first_text)
    @test occursin("[[observation.metrics]]", first_text)

    restored = read_approved_scientific_reference(IOBuffer(first_text))
    @test restored.reference_id == reference.reference_id
    @test restored.reference_schema_version == reference.reference_schema_version
    @test restored.benchmark_scope == reference.benchmark_scope
    @test restored.methodology == reference.methodology
    @test restored.reviewer == reference.reviewer
    @test restored.approval_date == reference.approval_date
    @test restored.approval_rationale == reference.approval_rationale
    @test restored.known_limitations == reference.known_limitations
    @test restored.observation.suite_id == reference.observation.suite_id
    @test restored.observation.schema_version == reference.observation.schema_version
    @test restored.observation.source_commit == reference.observation.source_commit
    @test restored.observation.provenance == reference.observation.provenance
    @test map(metric -> (metric.case_id, metric.metric_id), restored.observation.metrics) ==
          map(metric -> (metric.case_id, metric.metric_id), reference.observation.metrics)
    @test restored.observation.metrics[1].value === 1.25e-12
    @test restored.observation.metrics[1].absolute_tolerance === 1.0e-14
    @test restored.observation.metrics[1].relative_tolerance === 1.0e-2
    @test restored.observation.metrics[2].value === true
    @test restored.observation.metrics[3].value === 101
    @test approved_scientific_reference_text(restored) == first_text
end

@testset "Approved scientific reference serialization without limitations" begin
    reference = _approved_reference_serialization_fixture(known_limitations=nothing)
    text = approved_scientific_reference_text(reference)
    @test !occursin("known_limitations", text)
    restored = read_approved_scientific_reference(IOBuffer(text))
    @test isnothing(restored.known_limitations)
    @test approved_scientific_reference_text(restored) == text
end

@testset "Atomic approved scientific reference writing and malformed input" begin
    reference = _approved_reference_serialization_fixture()
    valid = approved_scientific_reference_text(reference)

    mktempdir() do directory
        path = joinpath(directory, "approved_reference.toml")
        @test write_report_atomic(path, reference) == abspath(path)
        @test isfile(path)
        @test !isfile(path * ".tmp")
        restored = read_approved_scientific_reference(path)
        @test approved_scientific_reference_text(restored) == valid
    end

    @test_throws ArgumentError read_approved_scientific_reference(IOBuffer(replace(
        valid,
        "report_kind = \"approved_scientific_reference\"" => "report_kind = \"reference\"",
    )))
    @test_throws KeyError read_approved_scientific_reference(IOBuffer(replace(
        valid,
        "reviewer = \"Scientific reviewer\"\n" => "",
    )))
    @test_throws ArgumentError read_approved_scientific_reference(IOBuffer(replace(
        valid,
        "approval_date = \"2026-07-25\"" => "approval_date = \"25-07-2026\"",
    )))
    @test_throws ArgumentError read_approved_scientific_reference(IOBuffer(replace(
        valid,
        "comparison = \"tolerance\"" => "comparison = \"unknown\"";
        count=1,
    )))
    @test_throws ArgumentError read_approved_scientific_reference(IOBuffer(replace(
        valid,
        "[observation]\n" => "[missing_observation]\n",
    )))
end
