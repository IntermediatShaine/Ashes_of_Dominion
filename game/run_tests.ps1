# Usage: .\run_tests.ps1 -Godot <godot_console.exe> [-Filter save]
param([string]$Godot = "godot", [string]$Filter = "")
& "$PSScriptRoot/tools/verify.ps1" -Godot $Godot -Check tests -Filter $Filter
exit $LASTEXITCODE
