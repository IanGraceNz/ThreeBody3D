# Run the ThreeBody3D RP-4 fresh-environment installation test.
#
# Run from any directory:
#   powershell -ExecutionPolicy Bypass -File tools\run_fresh_environment_test.ps1

[CmdletBinding()]
param(
    [string]$Julia = "julia",
    [string]$Report = "fresh_environment_report.md",
    [switch]$KeepTemporaryProject
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$reportPath = if ([IO.Path]::IsPathRooted($Report)) {
    $Report
} else {
    Join-Path $repoRoot $Report
}

$tempProject = Join-Path ([IO.Path]::GetTempPath()) (
    "ThreeBody3D-fresh-" + [Guid]::NewGuid().ToString("N")
)
New-Item -ItemType Directory -Force -Path $tempProject | Out-Null

$juliaScript = Join-Path $tempProject "fresh_environment_test.jl"
$stdoutPath = Join-Path $tempProject "fresh_environment_stdout.log"
$stderrPath = Join-Path $tempProject "fresh_environment_stderr.log"
$combinedLogPath = Join-Path $tempProject "fresh_environment_test.log"

function Convert-ToJuliaRawString {
    param([Parameter(Mandatory = $true)][string]$Value)
    return $Value.Replace('"', '\"')
}

$repoForJulia = Convert-ToJuliaRawString $repoRoot
$tempForJulia = Convert-ToJuliaRawString $tempProject

$juliaTemplate = @'
using Pkg

const REPOSITORY = raw"__REPOSITORY__"
const TEMPORARY_PROJECT = raw"__TEMPORARY_PROJECT__"

Pkg.activate(TEMPORARY_PROJECT)
Pkg.develop(path = REPOSITORY)
Pkg.instantiate()

using ThreeBody3D

system = ThreeBodySystem((1.0, 1.0, 1.0))
u0 = statevector(
    [-0.97000436,  0.24308753, 0.0], [ 0.466203685,  0.432365730, 0.0],
    [ 0.97000436, -0.24308753, 0.0], [ 0.466203685,  0.432365730, 0.0],
    [ 0.0,         0.0,        0.0], [-0.93240737,  -0.86473146, 0.0],
)

result = simulate(
    system,
    u0,
    (0.0, 0.2);
    solver = :accurate,
    saveat = 0.02,
)

report = diagnostics_report(result)
figure = plot_trajectory(result; show = false)

@assert result.solution.t[1] == 0.0
@assert isapprox(result.solution.t[end], 0.2; atol = 1e-12, rtol = 0)
@assert all(isfinite, reduce(vcat, result.solution.u))
@assert isfinite(report.maximum_relative_energy_drift)
@assert isfinite(report.minimum_separation)

println("ThreeBody3D fresh-environment test")
println("  Julia version:                 ", VERSION)
println("  temporary project:             ", Base.active_project())
println("  package version:               ", pkgversion(ThreeBody3D))
println("  saved states:                  ", length(result.solution.t))
println("  final integration time:        ", result.solution.t[end])
println("  maximum relative energy drift: ", report.maximum_relative_energy_drift)
println("  minimum pair separation:       ", report.minimum_separation)
println("  trajectory figure type:        ", typeof(figure))
println("  status:                         PASS")
'@

$juliaSource = $juliaTemplate.Replace("__REPOSITORY__", $repoForJulia)
$juliaSource = $juliaSource.Replace("__TEMPORARY_PROJECT__", $tempForJulia)
Set-Content -Path $juliaScript -Value $juliaSource -Encoding UTF8

$started = Get-Date
$previousShowPlots = $env:THREEBODY3D_SHOW_PLOTS
$exitCode = 1

try {
    $env:THREEBODY3D_SHOW_PLOTS = "false"

    $arguments = @(
        "--startup-file=no",
        "--project=$tempProject",
        $juliaScript
    )

    $process = Start-Process `
        -FilePath $Julia `
        -ArgumentList $arguments `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -NoNewWindow `
        -Wait `
        -PassThru

    $exitCode = $process.ExitCode
}
finally {
    $env:THREEBODY3D_SHOW_PLOTS = $previousShowPlots
}

$stdoutText = if (Test-Path $stdoutPath) {
    Get-Content -Raw -Path $stdoutPath
} else {
    ""
}
$stderrText = if (Test-Path $stderrPath) {
    Get-Content -Raw -Path $stderrPath
} else {
    ""
}

$logParts = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrWhiteSpace($stdoutText)) {
    $logParts.Add($stdoutText.TrimEnd())
}
if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
    $logParts.Add($stderrText.TrimEnd())
}
$logText = if ($logParts.Count -gt 0) {
    $logParts -join [Environment]::NewLine
} else {
    "No process log was produced."
}
Set-Content -Path $combinedLogPath -Value $logText -Encoding UTF8

$elapsed = ((Get-Date) - $started).TotalSeconds
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss K"

$branch = (& git -C $repoRoot branch --show-current).Trim()
$commit = (& git -C $repoRoot rev-parse --short HEAD).Trim()
$dirtyText = ((& git -C $repoRoot status --porcelain) -join "`n")
$dirty = -not [string]::IsNullOrWhiteSpace($dirtyText)
$status = if ($exitCode -eq 0) { "PASS" } else { "FAIL" }

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# ThreeBody3D fresh-environment test")
$lines.Add("")
$lines.Add("- Date: $timestamp")
$lines.Add("- Branch: $branch")
$lines.Add("- Commit: $commit")
$lines.Add("- Working tree dirty: $($dirty.ToString().ToLowerInvariant())")
$lines.Add("- Temporary project: $tempProject")
$lines.Add("- Elapsed seconds: $([math]::Round($elapsed, 3))")
$lines.Add("- Overall status: **$status**")
$lines.Add("")
$lines.Add("## Scope")
$lines.Add("")
$lines.Add("The test used a newly created Julia project and verified that a fresh user can:")
$lines.Add("")
$lines.Add("1. develop and instantiate ThreeBody3D from the repository;")
$lines.Add("2. load the package;")
$lines.Add("3. construct a system and Cartesian state;")
$lines.Add("4. run simulate with the documented :accurate profile;")
$lines.Add("5. compute a diagnostics_report;")
$lines.Add("6. construct a trajectory plot with display suppressed.")
$lines.Add("")
$lines.Add("## Process log")
$lines.Add("")
$lines.Add('```text')
foreach ($line in ($logText -split "`r?`n")) {
    $lines.Add($line)
}
$lines.Add('```')

Set-Content -Path $reportPath -Value $lines -Encoding UTF8

Write-Host ""
Write-Host ("Fresh-environment report written to " + $reportPath) -ForegroundColor Green

if ($KeepTemporaryProject) {
    Write-Host ("Temporary project retained at " + $tempProject) -ForegroundColor Yellow
} else {
    Remove-Item -Recurse -Force $tempProject
}

if ($exitCode -ne 0) {
    Write-Host ("Fresh-environment test failed with exit code " + $exitCode + ".") -ForegroundColor Red
    exit $exitCode
}

Write-Host "Fresh-environment installation test passed." -ForegroundColor Green
