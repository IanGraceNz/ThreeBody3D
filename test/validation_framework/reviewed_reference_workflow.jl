module ReviewedReferenceWorkflowTestHarness

include(joinpath(
    @__DIR__,
    "..",
    "..",
    "examples",
    "validation",
    "reviewed_reference_workflow.jl",
))

end

@testset "Reviewed-reference example guidance" begin
    workflow = ReviewedReferenceWorkflowTestHarness
    usage = workflow.reviewed_reference_usage()

    @test occursin("REFERENCE must be an existing", usage)
    @test occursin("does not create, approve, replace, or update", usage)
    @test occursin("run_validation_suite.jl", usage)
    @test occursin("VALIDATION_WORKFLOW.md", usage)

    missing_reference = joinpath(mktempdir(), "missing-reference.toml")
    @test_throws ArgumentError workflow.run_reviewed_reference_workflow(
        missing_reference;
        comparison_io=IOBuffer(),
    )
end
