# Usage: .\check_relaunch.ps1 -Godot <godot_console.exe>
param([string]$Godot = "godot")
& "$PSScriptRoot/tools/verify.ps1" -Godot $Godot -Check relaunch
exit $LASTEXITCODE
