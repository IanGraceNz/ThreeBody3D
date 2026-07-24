module InspectSuiteReportTestHarness

include(joinpath(
    @__DIR__,
    "..",
    "..",
    "examples",
    "validation",
    "inspect_suite_report.jl",
))

end

module TemporaryReferenceTestHarness

include(joinpath(
    @__DIR__,
    "..",
    "..",
    "examples",
    "validation",
    "prepare_temporary_reference.jl",
))

end

@testset "Candidate-reference review examples" begin
    inspector = InspectSuiteReportTestHarness
    temporary = TemporaryReferenceTestHarness

    @test occursin("metric identifier, value, kind, role", inspector.inspect_suite_usage())
    @test occursin("does not create or modify", inspector.inspect_suite_usage())

    policies = temporary.temporary_reference_policies()
    @test length(policies) == 4
    @test map(policy -> (policy.case_id, policy.metric_id), policies) == (
        (:figure_eight, :integration_status),
        (:figure_eight, :maximum_relative_energy_drift),
        (:hierarchical_triple, :integration_status),
        (:switching_diagnostics, :process_completed),
    )
    @test occursin("not scientifically approved", temporary.prepare_temporary_reference_usage())
    @test occursin("must not be committed", temporary.prepare_temporary_reference_usage())
end
