# Scientific validation workflow

This document is the canonical contributor workflow for comparing a current
ThreeBody3D validation run with an immutable, human-reviewed reference record.
It completes validation-framework milestone VF-4.

## Workflow

```text
Run validation suite
        |
        v
Generate structured suite result
        |
        v
Load reviewed reference record
        |
        v
Compare retained metrics
        |
        v
Render PASS / FAIL / ERROR report
        |
        v
Optionally write deterministic CI artifacts
```

The workflow never creates or updates a reviewed scientific reference
automatically. Reference approval is a separate, explicit scientific review
operation.

## Prerequisite: an approved reference

The canonical command is intentionally not self-contained: its first argument
must identify an existing reviewed `ValidationReferenceRecord` TOML file. The
repository may contain no approved reference yet while the project is still
defining and reviewing its initial baseline. In that situation, run the ordinary
validation suite instead:

```powershell
julia --project=. examples/validation/run_validation_suite.jl
```

Do not create an arbitrary reference merely to make the reviewed-reference
example pass. Preparing a candidate and approving it are separate operations
described below.

The example's prerequisite and accepted command forms can be displayed without
running the suite:

```powershell
julia --project=. examples/validation/reviewed_reference_workflow.jl --help
```

## Canonical command

After an approved reference exists, run from the repository root:

```powershell
julia --project=. examples/validation/reviewed_reference_workflow.jl `
    path/to/reviewed-reference.toml `
    validation_reports/current-suite.toml `
    validation_reports/reference-comparison.toml
```

The first argument is required and must name an existing approved reference
record. The suite-report and comparison-report paths are optional. The process
exits with a nonzero status when either the validation suite or
reviewed-reference comparison does not pass.

The command performs these operations in order:

1. Executes every registered validation case in a separate Julia process.
2. Builds one immutable `ValidationSuiteResult`.
3. Writes the suite report when a suite-report path is supplied.
4. Loads the reviewed `ValidationReferenceRecord` from disk.
5. Produces a structured `ValidationSuiteReferenceComparison`.
6. Prints the deterministic hierarchical comparison report.
7. Writes the deterministic comparison TOML artifact when requested.

The reviewed reference file is only read.

## Programmatic use

```julia
include("examples/validation/reviewed_reference_workflow.jl")

run = run_reviewed_reference_workflow(
    "path/to/reviewed-reference.toml";
    suite_report_path="validation_reports/current-suite.toml",
    comparison_report_path="validation_reports/reference-comparison.toml",
)

run.passed
run.result
run.comparison
run.report_path
run.comparison_report_path
```

For a suite that has already been executed, the lower-level workflow is:

```julia
comparison = run_reference_comparison(
    suite_result,
    "path/to/reviewed-reference.toml",
)

write_report_atomic(
    "validation_reports/reference-comparison.toml",
    comparison,
)
```

## Deterministic artifacts

Three deterministic TOML artifact kinds are relevant:

- `suite`: the complete structured result of a validation run;
- `reference`: the compact immutable reviewed baseline;
- `reference_comparison`: the comparison outcome, including retained reference
  and observed values, comparison policies, absolute differences, allowed
  differences, errors, and derived statuses.

Comparison artifacts can be read back with:

```julia
comparison = read_reference_comparison(
    "validation_reports/reference-comparison.toml",
)
```

Retained suite, case, and metric ordering is preserved. Output contains no ANSI
colour codes, timestamps added by the formatter, or presentation-dependent
scientific decisions.

## Interpreting status

- `PASS`: every retained comparison passed.
- `FAIL`: at least one retained value was validly compared but exceeded its
  approved policy.
- `ERROR`: at least one retained comparison could not be evaluated, for
  example because a case or metric was missing or had an incompatible value.

An `ERROR` takes precedence over `FAIL`, and `FAIL` takes precedence over
`PASS`, at both case and suite levels.

## Preparing and approving a candidate reference

Reference creation is deliberately not part of the routine regression command.
There is no command that silently promotes the latest suite result to an
approved scientific reference. A contributor preparing a candidate scientific
reference must complete all seven review steps below.

### 1. Run and retain the full suite report

Supply an explicit report path and run the ordinary suite:

```powershell
New-Item -ItemType Directory -Force validation_reports/vf4-temporary | Out-Null
$env:THREEBODY3D_VALIDATION_SUITE_REPORT = "validation_reports/vf4-temporary/current-suite.toml"
julia --project=. examples/validation/run_validation_suite.jl
Remove-Item Env:THREEBODY3D_VALIDATION_SUITE_REPORT
```

### 2. Confirm every required case passes

Review the runner summary. Candidate preparation must stop unless the overall
status is `PASS` and every required case passed.

### 3. Review actual retained metric values

Do not review metric names alone. Inspect each case, metric value, kind, role,
scale, aggregation, and unit from the structured report:

```powershell
julia --project=. examples/validation/inspect_suite_report.jl `
    validation_reports/vf4-temporary/current-suite.toml |
    Tee-Object validation_reports/vf4-temporary/metric-review.txt
```

The inspector is read-only and preserves suite and metric ordering. Scientific
review must consider whether each proposed value is meaningful, numerically
stable across justified reruns, portable across supported environments, and
appropriate for long-term regression tracking.

### 4. Declare policies explicitly

For every metric selected for retention, declare either:

- `reference_exact` for discrete values that must match exactly; or
- `reference_tolerance` for finite floating-point scalar values, with a
  scientifically justified absolute and/or relative tolerance.

Policy selection is a human scientific decision. It must not be inferred from
the latest observed value merely to guarantee a passing comparison.

For a disposable VF-4 walkthrough only, the repository includes a deliberately
small policy set in `prepare_temporary_reference.jl`. Those policies are test
fixtures, not an approved project baseline.

### 5. Build the candidate with provenance

For the temporary walkthrough, record the current commit and build the
explicitly labelled disposable reference:

```powershell
$sourceCommit = git rev-parse HEAD
julia --project=. examples/validation/prepare_temporary_reference.jl `
    validation_reports/vf4-temporary/current-suite.toml `
    validation_reports/vf4-temporary/temporary-reference.toml `
    $sourceCommit
```

A real candidate should call `build_reference_record` with its reviewed policy
set and record both the exact source commit and meaningful provenance. The
helper above must not be used to approve a production baseline.

### 6. Inspect and exercise the deterministic reference

Inspect the complete candidate TOML before using it:

```powershell
Get-Content validation_reports/vf4-temporary/temporary-reference.toml
```

Then exercise the complete reviewed-reference workflow:

```powershell
julia --project=. examples/validation/reviewed_reference_workflow.jl `
    validation_reports/vf4-temporary/temporary-reference.toml `
    validation_reports/vf4-temporary/comparison-suite.toml `
    validation_reports/vf4-temporary/comparison-report.toml
```

The comparison should pass when the retained temporary metrics remain within
the declared demonstration policies. This run still does not approve or update
the candidate.

### 7. Obtain review or delete the temporary artifacts

A real candidate may replace an approved reference only after the project's
required scientific and code review. For the disposable walkthrough, delete all
generated artifacts instead:

```powershell
Remove-Item -Recurse -Force validation_reports/vf4-temporary
```

Confirm that no temporary scientific reference or report is staged:

```powershell
git status --short
```

Never update a reference merely to make a regression pass. A changed result
must first be explained as an intended scientific improvement, an approved
policy change, or a defect.

## CI use

A CI job can invoke the canonical example and archive both supplied output
paths. The Julia process exit status is sufficient for the job result:

```powershell
julia --project=. examples/validation/reviewed_reference_workflow.jl `
    validation_references/approved.toml `
    validation_reports/current-suite.toml `
    validation_reports/reference-comparison.toml
```

The approved reference should be version-controlled and treated as read-only by
the CI job. The current-suite and reference-comparison files are generated
artifacts suitable for inspection and historical retention.
