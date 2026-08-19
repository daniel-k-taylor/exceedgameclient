# Runs the GUT test suite and fails on runtime script errors.
#
# GUT only fails a test when an assert fails. A GDScript runtime error (for
# example passing a String into a typed int parameter) aborts the test method
# but GUT still reports it as passing, just with fewer asserts. That means a
# real bug can sit in the suite indefinitely looking green. This wrapper scans
# the run output and fails if the engine reported any error.
#
# Usage:
#   .\run_tests.ps1                     # whole suite
#   .\run_tests.ps1 -Select test_umina_dreamlands_ui.gd
#
# Note: the filter flag is -gselect (a filename glob). -gtest does NOT filter.

[CmdletBinding()]
param(
	[string] $Select = "",
	[string] $Godot = ".\godotexe\Godot_v4.4.1-stable_win64_console.exe",
	[string] $Dir = "res://test/unit",
	[string] $LogPath = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Godot)) {
	Write-Error "Godot executable not found at '$Godot'. Pass -Godot <path>."
}

if (-not $LogPath) {
	$LogPath = Join-Path ([System.IO.Path]::GetTempPath()) "gut_run_$(Get-Date -Format yyyyMMdd_HHmmss).txt"
}

$gutArgs = @("-s", "addons/gut/gut_cmdln.gd", "-gdir=$Dir", "-gexit")
if ($Select) { $gutArgs += "-gselect=$Select" }

Write-Host "Running: $Godot $($gutArgs -join ' ')"
Write-Host "Log: $LogPath"

& $Godot @gutArgs *>&1 | Tee-Object -FilePath $LogPath
$godotExit = $LASTEXITCODE

$output = Get-Content -LiteralPath $LogPath

# Engine-level failures GUT will happily report as passing tests.
$errorPatterns = @(
	"SCRIPT ERROR",
	"USER SCRIPT ERROR",
	"Parse Error",
	"Cannot call method",
	"Invalid call\. Nonexistent function"
)
$pattern = ($errorPatterns -join "|")
$scriptErrors = $output | Select-String -Pattern $pattern

Write-Host ""
Write-Host "======================================================"

$summary = $output | Select-String -Pattern "^(Totals|Tests|Passing|Failing|Asserts|Pending)" -SimpleMatch:$false
if ($summary) { $summary | ForEach-Object { Write-Host $_.Line } }

if ($scriptErrors) {
	Write-Host ""
	Write-Host "FAILED: $($scriptErrors.Count) runtime script error(s) in the test run." -ForegroundColor Red
	Write-Host "These abort a test method silently - GUT still counts the test as passing." -ForegroundColor Red
	Write-Host ""
	$scriptErrors | Select-Object -First 40 | ForEach-Object {
		Write-Host ("  line {0}: {1}" -f $_.LineNumber, $_.Line.Trim())
	}
	if ($scriptErrors.Count -gt 40) {
		Write-Host "  ... and $($scriptErrors.Count - 40) more. See $LogPath"
	}
	exit 1
}

if ($godotExit -ne 0) {
	Write-Host "FAILED: test run exited with code $godotExit." -ForegroundColor Red
	exit $godotExit
}

Write-Host "OK: no runtime script errors." -ForegroundColor Green
exit 0
