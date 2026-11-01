# Save -> quit -> relaunch -> Continue, as two separate engine processes (Windows).
# Usage:  .\check_relaunch.ps1 -Godot "C:\path\to\Godot_v4.5.1-stable_win64_console.exe"
param([string]$Godot = "godot")
Set-Location $PSScriptRoot
& $Godot --headless --path . --import | Out-Null
foreach ($phase in @("write", "verify")) {
  $out = & $Godot --headless --path . res://tools/relaunch_check.tscn -- "--phase=$phase" 2>&1 | Out-String
  $status = $LASTEXITCODE
  Write-Output ($out -split "`n" | Where-Object { $_.Trim() -ne "" })
  if ($status -ne 0 -or $out -match "SCRIPT ERROR" -or $out -match "(?m)^ERROR:") {
    Write-Output "!!! relaunch check failed in phase '$phase'"
    exit 1
  }
}
