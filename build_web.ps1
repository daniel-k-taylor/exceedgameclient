# Exports the web (HTML5) client and deploys it into the local server's public/
# folder so it can be played in a browser against a locally running server.
#
# The debug export matters: GlobalSettings.get_server_url() returns the Azure URL
# whenever OS.is_debug_build() is false, so a release web build would ignore the
# local server entirely. Keep -Release for checking a production-like build only.
#
# The server replaces public/ with the build from Azure blob storage on startup
# and every 10 minutes, so SKIP_GAME_ZIP_DOWNLOAD=1 must be set in the server's
# .env or the local build will be wiped mid-session.
#
# Usage:
#   .\build_web.ps1                          # debug build -> ..\exceedgameserver\public
#   .\build_web.ps1 -ServerRepo D:\srv       # deploy elsewhere
#   .\build_web.ps1 -NoDeploy                # just export to .\export

[CmdletBinding()]
param(
	[string] $Godot = ".\godotexe\Godot_v4.4.1-stable_win64_console.exe",
	[string] $ServerRepo = "..\exceedgameserver",
	[switch] $Release,
	[switch] $NoDeploy
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Godot)) {
	Write-Error "Godot executable not found at '$Godot'. Pass -Godot <path>."
}

$exportDir = Join-Path $PSScriptRoot "export"
New-Item -ItemType Directory -Force -Path $exportDir | Out-Null

$mode = if ($Release) { "--export-release" } else { "--export-debug" }
Write-Host "Exporting HTML5Export ($mode)..." -ForegroundColor Cyan

$log = & $Godot --headless $mode "HTML5Export" 2>&1
$indexPath = Join-Path $exportDir "index.html"
if (-not (Test-Path $indexPath)) {
	$log | Select-Object -Last 40
	Write-Error "Export failed: $indexPath was not produced."
}

$errors = $log | Select-String -Pattern "SCRIPT ERROR|Parse Error|Export failed"
if ($errors) {
	$errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
	Write-Error "Export reported errors."
}

Write-Host "Export OK:" -ForegroundColor Green
Get-ChildItem $exportDir | Select-Object Name, @{n = 'MB'; e = { [math]::Round($_.Length / 1MB, 2) } } | Format-Table -AutoSize

if ($NoDeploy) { return }

$publicDir = Join-Path $ServerRepo "public"
if (-not (Test-Path $ServerRepo)) {
	Write-Error "Server repo not found at '$ServerRepo'. Pass -ServerRepo <path> or use -NoDeploy."
}

$envPath = Join-Path $ServerRepo ".env"
if ((Test-Path $envPath) -and -not (Select-String -Path $envPath -Pattern "^\s*SKIP_GAME_ZIP_DOWNLOAD\s*=\s*\S" -Quiet)) {
	Write-Warning "SKIP_GAME_ZIP_DOWNLOAD is not set in $envPath - the server will overwrite public/ with the Azure build."
}

New-Item -ItemType Directory -Force -Path $publicDir | Out-Null
Get-ChildItem $publicDir -Filter "index.*" | Remove-Item -Force -Recurse
# The editor imports any PNG living under the project root, so export/ picks up
# .import sidecars that are not part of the build.
Get-ChildItem $exportDir -File | Where-Object { $_.Extension -ne ".import" } | Copy-Item -Destination $publicDir -Force

Write-Host "Deployed to $publicDir" -ForegroundColor Green
if ($Release) {
	Write-Host "NOTE: release build - it will connect to the Azure server, not localhost." -ForegroundColor Yellow
} else {
	Write-Host "Start the server (npm start in $ServerRepo) and open http://localhost:8080" -ForegroundColor Cyan
}
