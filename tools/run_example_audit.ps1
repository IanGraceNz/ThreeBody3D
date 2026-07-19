# Run and record the complete ThreeBody3D example audit required by RP-3.
#
# Run from the repository root:
#   powershell -ExecutionPolicy Bypass -File tools\run_example_audit.ps1
#
# The script suppresses automatic plot display during the batch run. Interactive
# plotting, animation, and MP4 recording remain separate manual checks because
# they require a working desktop/OpenGL/encoder environment.

[CmdletBinding()]
param(
    [string]$Julia = "julia",
    [string]$Report = "example_audit_report.md",
    [string]$LogDirectory = "example_audit_logs"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

$topLevelExamples = @(
    "examples/analytic_kepler_validation.jl",
    "examples/automatic_regularization.jl",
    "examples/close_approach_policies.jl",
    "examples/composed_regularized_trajectory.jl",
    "examples/explicit_regularized_segment.jl",
    "examples/figure_eight.jl",
    "examples/hierarchical_triple.jl",
    "examples/high_precision_reference.jl",
    "examples/levi_civita_fictitious_time.jl",
    "examples/levi_civita_physical_time_target.jl",
    "examples/levi_civita_sundman_time.jl",
    "examples/long_duration_switching_validation.jl",
    "examples/manual_regularized_composition.jl",
    "examples/numerical_validation.jl",
    "examples/perturbed_planar_binary.jl",
    "examples/perturbed_planar_binary_physical_time.jl"
)

$validationFiles = @(
    "examples/validation/AcceptanceCriteria.jl",
    "examples/validation/close_encounter_comparison.jl",
    "examples/validation/equilateral_triple_collision_reference.jl",
    "examples/validation/figure_eight_benchmark.jl",
    "examples/validation/hierarchical_triple_benchmark.jl",
    "examples/validation/ks_collision_continuation.jl",
    "examples/validation/ks_hierarchical_triple.jl",
    "examples/validation/ks_kepler_validation.jl",
    "examples/validation/ks_levi_civita_comparison.jl",
    "examples/validation/ks_switching_comparison.jl",
    "examples/validation/randomized_regression_validation.jl",
    "examples/validation/run_validation_suite.jl"
)

$allFiles = Get-ChildItem -Recurse examples -Filter *.jl |
    ForEach-Object { $_.FullName.Substring($repoRoot.Length + 1).Replace("\", "/") } |
    Sort-Object
$expectedFiles = @($topLevelExamples + $validationFiles) | Sort-Object

$missingFromInventory = @($expectedFiles | Where-Object { $_ -notin $allFiles })
$unexpectedFiles = @($allFiles | Where-Object { $_ -notin $expectedFiles })
if ($missingFromInventory.Count -gt 0 -or $unexpectedFiles.Count -gt 0) {
    Write-Host "Example inventory does not match the audited manifest." -ForegroundColor Red
    if ($missingFromInventory.Count -gt 0) {
        Write-Host "Missing files:" -ForegroundColor Red
        $missingFromInventory | ForEach-Object { Write-Host "  $_" }
    }
    if ($unexpectedFiles.Count -gt 0) {
        Write-Host "Unexpected files:" -ForegroundColor Red
        $unexpectedFiles | ForEach-Object { Write-Host "  $_" }
    }
    exit 1
}

New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null
$results = New-Object System.Collections.Generic.List[object]

function Invoke-Example {
    param([string]$Path)

    $safeName = ($Path -replace '[\\/:*?"<>|]', '_')
    $logPath = Join-Path $LogDirectory ($safeName + ".log")
    Write-Host "Running $Path" -ForegroundColor Cyan

    $started = Get-Date

    # Merge the native process streams inside cmd.exe. Windows PowerShell turns
    # native stderr records into NativeCommandError objects; with
    # $ErrorActionPreference = "Stop", harmless Julia warnings would otherwise
    # abort the audit before the native exit code can be inspected.
    $command = "chcp 65001 >nul & `"$Julia`" --project=. `"$Path`" 2>&1"
    & $env:ComSpec /d /s /c $command | Tee-Object -FilePath $logPath
    $exitCode = $LASTEXITCODE
    $elapsed = ((Get-Date) - $started).TotalSeconds
    $status = if ($exitCode -eq 0) { "PASS" } else { "FAIL" }

    $results.Add([pscustomobject]@{
        Path = $Path
        Status = $status
        Seconds = [math]::Round($elapsed, 3)
        Log = $logPath.Replace("\", "/")
    })
}

$previousShowPlots = $env:THREEBODY3D_SHOW_PLOTS
$previousAnimate = $env:THREEBODY3D_ANIMATE
$previousRecord = $env:THREEBODY3D_RECORD_MP4
try {
    $env:THREEBODY3D_SHOW_PLOTS = "false"
    $env:THREEBODY3D_ANIMATE = "false"
    $env:THREEBODY3D_RECORD_MP4 = "false"

    foreach ($example in $topLevelExamples) {
        Invoke-Example $example
    }

    # The suite executes all standalone validation cases in isolated Julia
    # processes. AcceptanceCriteria.jl is a support file included by those cases.
    Invoke-Example "examples/validation/run_validation_suite.jl"
}
finally {
    $env:THREEBODY3D_SHOW_PLOTS = $previousShowPlots
    $env:THREEBODY3D_ANIMATE = $previousAnimate
    $env:THREEBODY3D_RECORD_MP4 = $previousRecord
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss K"
$commit = (& git rev-parse --short HEAD).Trim()
$branch = (& git branch --show-current).Trim()
$failed = @($results | Where-Object { $_.Status -eq "FAIL" })

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# ThreeBody3D example audit")
$lines.Add("")
$lines.Add("- Date: $timestamp")
$lines.Add("- Branch: ``$branch``")
$lines.Add("- Commit: ``$commit``")
$lines.Add("- Julia command: ``$Julia --project=.``")
$lines.Add("- Automatic plot display: suppressed during batch execution")
$lines.Add("")
$lines.Add("## Standalone execution results")
$lines.Add("")
$lines.Add("| File | Status | Seconds | Log |")
$lines.Add("|---|---:|---:|---|")
foreach ($result in $results) {
    $lines.Add("| ``$($result.Path)`` | $($result.Status) | $($result.Seconds) | ``$($result.Log)`` |")
}

$lines.Add("")
$lines.Add("## Validation support-file coverage")
$lines.Add("")
$lines.Add("``examples/validation/AcceptanceCriteria.jl`` is **NOT STANDALONE**. It is included by the scientific validation cases executed through ``examples/validation/run_validation_suite.jl``.")
$lines.Add("")
$lines.Add("The following validation programs are exercised by the suite:")
$lines.Add("")
foreach ($path in $validationFiles | Where-Object { $_ -notmatch 'AcceptanceCriteria|run_validation_suite' }) {
    $lines.Add("- ``$path``")
}

$lines.Add("")
$lines.Add("## Manual graphics checks")
$lines.Add("")
$lines.Add("These checks require a Windows desktop session with a working OpenGL environment. MP4 recording also requires the bundled or system FFmpeg path to function.")
$lines.Add("")
$lines.Add("- [ ] ``julia --project=. examples/figure_eight.jl`` displays a trajectory figure.")
$lines.Add("- [ ] ``julia --project=. examples/hierarchical_triple.jl`` displays a trajectory figure.")
$lines.Add("- [ ] With ``THREEBODY3D_ANIMATE=true``, ``examples/automatic_regularization.jl`` displays and plays an animation.")
$lines.Add("- [ ] With ``THREEBODY3D_RECORD_MP4=true``, ``examples/automatic_regularization.jl`` writes a playable MP4.")
$lines.Add("- [ ] ``animate_collision_ejection_reference()`` works after loading ``examples/validation/equilateral_triple_collision_reference.jl`` interactively.")

$lines.Add("")
$lines.Add("## Overall batch status")
$lines.Add("")
if ($failed.Count -eq 0) {
    $lines.Add("**PASS** - all standalone batch examples and the complete scientific validation suite exited successfully.")
} else {
    $lines.Add("**FAIL** - $($failed.Count) command(s) failed. Review the linked logs before continuing release preparation.")
}

Set-Content -Path $Report -Value $lines -Encoding UTF8
Write-Host ""
Write-Host "Audit report written to $Report" -ForegroundColor Green
if ($failed.Count -gt 0) {
    Write-Host "$($failed.Count) audit command(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host "All batch audit commands passed." -ForegroundColor Green
