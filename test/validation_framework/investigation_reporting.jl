@testset "Deterministic investigation series serialization" begin
    suite, results = _figure_eight_investigation_inputs()
    series = figure_eight_profile_investigation_series(suite, results)
    text = investigation_series_report_text(series)
    @test text == investigation_series_report_text(series)
    @test occursin("report_kind = \"investigation_series\"", text)
    restored = read_investigation_series(IOBuffer(text))
    @test restored.series_id == series.series_id
    @test map(point -> point.point_id, restored.points) == (:fast, :accurate)
    @test map(point -> point.independent_value.value, restored.points) == (:fast, :accurate)
    @test map(point -> map(metric -> metric.metric_id, point.metrics), restored.points) ==
        map(point -> map(metric -> metric.metric_id, point.metrics), series.points)
    @test map(point -> length(point.performance_report.samples), restored.points) == (3, 3)

    mktempdir() do directory
        path = joinpath(directory, "series.toml")
        @test write_investigation_series_atomic(path, series) == abspath(path)
        @test investigation_series_report_text(read_investigation_series(path)) == text
    end

    point = first(series.points)
    unsupported = InvestigationMeasurementPoint(
        point.point_id, point.definition, point.configuration, point.independent_value,
        point.environment, point.execution, point.metrics, point.solver_statistics;
        performance_report=point.performance_report, supporting_evidence=(raw=true,),
    )
    malformed = InvestigationMeasurementSeries(
        series.series_id, series.title, series.description, series.definition,
        (unsupported, series.points[2]),
    )
    @test_throws ArgumentError investigation_series_report_text(malformed)
end

function _reporting_metric_value(metric, value)
    ValidationMetric(
        metric.metric_id, metric.label, value;
        kind=metric.kind, scale=metric.scale, role=metric.role,
        aggregation=metric.aggregation, units=metric.units,
        description=metric.description,
    )
end

function _reporting_point(point; metric_values=Dict{Symbol,Any}(),
    execution=point.execution, solver_statistics=point.solver_statistics,
    performance_report=point.performance_report,
    independent_value=point.independent_value, notes=point.notes)
    metrics = Tuple(
        haskey(metric_values, metric.metric_id) ?
            _reporting_metric_value(metric, metric_values[metric.metric_id]) : metric
        for metric in point.metrics
    )
    InvestigationMeasurementPoint(
        point.point_id, point.definition, point.configuration,
        independent_value, point.environment, execution, metrics,
        solver_statistics; performance_report, notes,
    )
end

function _reporting_performance_report(report;
    policy=report.policy, samples=report.samples, execution=report.execution)
    build_performance_benchmark_report(
        report.definition, report.environment, report.configuration,
        policy, samples, execution,
    )
end

function _reporting_series(series, points)
    InvestigationMeasurementSeries(
        series.series_id, series.title, series.description,
        series.definition, Tuple(points),
    )
end

@testset "Investigation baseline Markdown" begin
    figure_suite, figure_results = _figure_eight_investigation_inputs()
    hierarchical_suite, hierarchical_results = _hierarchical_investigation_inputs()
    figure = figure_eight_profile_investigation_series(figure_suite, figure_results)
    hierarchical = hierarchical_triple_profile_investigation_series(
        hierarchical_suite, hierarchical_results,
    )
    # Both synthetic fixtures intentionally use the same deterministic environment.
    text = investigation_baseline_markdown((figure, hierarchical))
    @test occursin("# ThreeBody3D Investigation 1 Baseline Report", text)
    @test occursin("## Direct numerical measurements", text)
    @test occursin("## Interpretation", text)
    @test occursin("do not support conclusions about tolerance convergence", text)
    @test occursin("Minimum sampled separation is not periapsis error", text)
    @test occursin("A second equivalent execution was not performed", text)
    @test occursin("run_investigation_1_baseline.jl validation_reports/investigation_1", text)
end

@testset "Data-driven and failure-safe Markdown interpretation" begin
    suite, results = _figure_eight_investigation_inputs()
    base = figure_eight_profile_investigation_series(suite, results)
    fast, accurate = base.points

    expected = investigation_baseline_markdown((base,))
    @test occursin("fast recorded higher periodicity error than accurate", expected)

    reversed = _reporting_series(base, (
        _reporting_point(fast; metric_values=Dict(:periodicity_error => 1e-9)),
        _reporting_point(accurate; metric_values=Dict(:periodicity_error => 1e-6)),
    ))
    reversed_text = investigation_baseline_markdown((reversed,))
    @test occursin("fast recorded lower periodicity error than accurate", reversed_text)

    equal = _reporting_series(base, (
        _reporting_point(fast; metric_values=Dict(:periodicity_error => 1e-9)),
        _reporting_point(accurate; metric_values=Dict(:periodicity_error => 1e-9)),
    ))
    @test occursin("periodicity error is equal", investigation_baseline_markdown((equal,)))

    terminated = ExecutionOutcome(
        actual_terminated; exit_code=17, summary="Core point terminated factually.",
    )
    unavailable_point = InvestigationMeasurementPoint(
        fast.point_id, fast.definition, fast.configuration, fast.independent_value,
        fast.environment, terminated, (), nothing;
        performance_report=nothing, notes="No numerical evidence retained.",
    )
    unavailable = _reporting_series(base, (unavailable_point, accurate))
    unavailable_text = investigation_baseline_markdown((unavailable,))
    @test occursin("periodicity error comparison is unavailable", unavailable_text)
    @test occursin("Core point terminated factually", unavailable_text)
    @test occursin("| 17 |", unavailable_text)
    @test occursin("Not available", unavailable_text)

    failure = ExecutionOutcome(
        actual_missing_report; exit_code=19, summary="No child report was retained.",
    )
    failure_points = Tuple(InvestigationMeasurementPoint(
        point.point_id, point.definition, point.configuration, point.independent_value,
        point.environment, failure, (), nothing; performance_report=nothing,
    ) for point in base.points)
    failure_only = _reporting_series(base, failure_points)
    failure_text = investigation_baseline_markdown((failure_only,))
    declared_ids = (
        base.definition.required_metric_ids...,
        base.definition.optional_metric_ids...,
    )
    for metric_id in declared_ids
        @test occursin(string(metric_id), failure_text)
    end
    @test count(occursin("Not available"), eachline(IOBuffer(failure_text))) >=
        length(failure_points)
    @test !occursin("| Point | Execution |  |", failure_text)
end

@testset "Investigation reproducibility comparison" begin
    suite, results = _figure_eight_investigation_inputs()
    series = figure_eight_profile_investigation_series(suite, results)
    matching = compare_investigation_baselines((series,), (series,))
    @test matching.performed
    @test matching.passed
    @test isempty(matching.mismatches)

    fast, accurate = series.points
    changed = _reporting_series(series, (
        _reporting_point(fast; metric_values=Dict(:periodicity_error => 0.5)),
        accurate,
    ))
    mismatch = compare_investigation_baselines((series,), (changed,))
    @test mismatch.performed
    @test !mismatch.passed
    @test any(message -> occursin("periodicity_error", message), mismatch.mismatches)

    changed_independent = _reporting_series(series, (
        _reporting_point(fast; independent_value=ValidationParameter(:solver_profile, :other)),
        accurate,
    ))
    @test !compare_investigation_baselines((series,), (changed_independent,)).passed

    report = fast.performance_report
    changed_policy = PerformanceMeasurementPolicy(
        warmup_runs=2, sample_runs=report.policy.sample_runs,
        collect_elapsed_time=report.policy.collect_elapsed_time,
        collect_allocated_bytes=report.policy.collect_allocated_bytes,
        collect_allocation_count=report.policy.collect_allocation_count,
        collect_gc_time=report.policy.collect_gc_time,
        garbage_collection_before_sample=report.policy.garbage_collection_before_sample,
        process_isolation=report.policy.process_isolation,
        timing_clock=report.policy.timing_clock,
    )
    policy_series = _reporting_series(series, (
        _reporting_point(fast; performance_report=_reporting_performance_report(
            report; policy=changed_policy,
        )), accurate,
    ))
    @test !compare_investigation_baselines((series,), (policy_series,)).passed

    partial_execution = ExecutionOutcome(
        actual_terminated; exit_code=2, summary="Partial performance samples.",
    )
    partial_report = _reporting_performance_report(
        report; samples=report.samples[1:end-1], execution=partial_execution,
    )
    partial_series = _reporting_series(series, (
        _reporting_point(fast; performance_report=partial_report), accurate,
    ))
    @test !compare_investigation_baselines((series,), (partial_series,)).passed

    ordered_samples = Tuple(PerformanceSample(
        sample.sample_index; elapsed_seconds=sample.elapsed_seconds,
        allocated_bytes=sample.allocated_bytes, allocation_count=sample.allocation_count,
        gc_seconds=sample.gc_seconds, solver_statistics=sample.solver_statistics,
        saved_states=300 + sample.sample_index, measurements=sample.measurements,
    ) for sample in report.samples)
    reversed_samples = Tuple(PerformanceSample(
        index; elapsed_seconds=sample.elapsed_seconds,
        allocated_bytes=sample.allocated_bytes, allocation_count=sample.allocation_count,
        gc_seconds=sample.gc_seconds, solver_statistics=sample.solver_statistics,
        saved_states=sample.saved_states, measurements=sample.measurements,
    ) for (index, sample) in enumerate(reverse(ordered_samples)))
    ordered_series = _reporting_series(series, (
        _reporting_point(fast; performance_report=_reporting_performance_report(
            report; samples=ordered_samples,
        )), accurate,
    ))
    reversed_series = _reporting_series(series, (
        _reporting_point(fast; performance_report=_reporting_performance_report(
            report; samples=reversed_samples,
        )), accurate,
    ))
    @test !compare_investigation_baselines((ordered_series,), (reversed_series,)).passed

    samples = collect(report.samples)
    first_sample = samples[1]
    changed_statistics = SolverStatistics(
        accepted_steps=first_sample.solver_statistics.accepted_steps + 1,
        rejected_steps=first_sample.solver_statistics.rejected_steps,
        rhs_evaluations=first_sample.solver_statistics.rhs_evaluations,
        saved_states=first_sample.solver_statistics.saved_states,
        segment_count=first_sample.solver_statistics.segment_count,
        switch_count=first_sample.solver_statistics.switch_count,
    )
    samples[1] = PerformanceSample(
        first_sample.sample_index; elapsed_seconds=first_sample.elapsed_seconds,
        allocated_bytes=first_sample.allocated_bytes,
        allocation_count=first_sample.allocation_count,
        gc_seconds=first_sample.gc_seconds, solver_statistics=changed_statistics,
        saved_states=first_sample.saved_states, measurements=first_sample.measurements,
    )
    work_series = _reporting_series(series, (
        _reporting_point(fast; performance_report=_reporting_performance_report(
            report; samples=Tuple(samples),
        )), accurate,
    ))
    @test !compare_investigation_baselines((series,), (work_series,)).passed

    timed_samples = Tuple(PerformanceSample(
        sample.sample_index; elapsed_seconds=sample.elapsed_seconds + 1.0,
        allocated_bytes=sample.allocated_bytes, allocation_count=sample.allocation_count,
        gc_seconds=isnothing(sample.gc_seconds) ? nothing : sample.gc_seconds + 1.0,
        solver_statistics=sample.solver_statistics, saved_states=sample.saved_states,
        measurements=sample.measurements,
    ) for sample in report.samples)
    timing_series = _reporting_series(series, (
        _reporting_point(fast; performance_report=_reporting_performance_report(
            report; samples=timed_samples,
        )), accurate,
    ))
    @test compare_investigation_baselines((series,), (timing_series,)).passed
    markdown = investigation_baseline_markdown((series,); reproducibility=mismatch)
    @test occursin("A second equivalent execution was performed", markdown)
    @test occursin("Result: FAIL", markdown)
    @test occursin("sample elapsed seconds", markdown)
    @test occursin("sample GC seconds", markdown)
end
