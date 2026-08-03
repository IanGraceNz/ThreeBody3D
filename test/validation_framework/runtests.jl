using Test

include(joinpath(@__DIR__, "..", "..", "examples", "validation", "framework", "ValidationFramework.jl"))
using .ValidationFramework

include("types.jl")

include("performance_types.jl")

include("criteria.jl")

include("case_results.jl")

include("suite_results.jl")

include("serialization.jl")

include("performance_serialization.jl")

include("performance_measurement.jl")

include("performance_comparison.jl")

include("performance_series.jl")

include("investigation_types.jl")

include("figure_eight_investigation.jl")

include("hierarchical_triple_investigation.jl")

include("close_encounter_investigation.jl")

include("performance_presentation.jl")

include("console_presentation.jl")

include("case_protocol.jl")

include("performance_protocol.jl")
include("performance_runner.jl")
include("performance_benchmarks.jl")

include("suite_runner.jl")

include("reference_records.jl")

include("approved_scientific_reference_serialization.jl")

include("approval_workflow.jl")

include("reference_comparison.jl")

include("reference_comparison_serialization.jl")

include("reference_workflow.jl")

include("approved_scientific_reference_workflow.jl")

include("validation_run_workflow.jl")

include("validation_runner.jl")

include("reviewed_reference_workflow.jl")

include("candidate_reference_examples.jl")

include("core_benchmark_cases.jl")

include("close_encounter_case.jl")

include("triple_collision_case.jl")

include("randomized_regression_case.jl")

include("ks_kepler_case.jl")

include("ks_collision_continuation_case.jl")

include("ks_levi_civita_comparison_case.jl")

include("ks_hierarchical_triple_case.jl")

include("ks_switching_comparison_case.jl")
include("ks_switching_investigation.jl")
include("investigation_reporting.jl")
include("investigation_baseline_runner.jl")
include("core_tolerance_investigation.jl")
include("core_duration_sampling_investigation.jl")
include("figure_eight_precision_investigation.jl")
include("close_encounter_experiment.jl")
include("close_encounter_cartesian_investigation.jl")
include("close_encounter_regularized_experiment.jl")
include("close_encounter_regularized_investigation.jl")
include("close_encounter_threshold_scale_investigation.jl")
include("core_investigation_runner.jl")
