# Runs the automated test suite headless on Windows.
# Usage:  .\run_tests.ps1 -Godot "C:\path\to\Godot_v4.5.1-stable_win64_console.exe" [-Filter save]
param(
  [string]$Godot = "godot",
  [string]$Filter = ""
)
Set-Location $PSScriptRoot
& $Godot --headless --path . --import | Out-Null
$args = @("--headless", "--path", ".", "res://tests/test_runner.tscn")
if ($Filter -ne "") { $args += "--"; $args += "--filter=$Filter" }
$out = & $Godot @args 2>&1 | Out-String
$status = $LASTEXITCODE
Write-Output ($out -split "`n" | Where-Object { $_.Trim() -ne "" })
if ($out -match "SCRIPT ERROR" -or $out -match "(?m)^ERROR:") {
  Write-Output "!!! engine errors were reported above - treating as failure"
  exit 1
}
exit $status
