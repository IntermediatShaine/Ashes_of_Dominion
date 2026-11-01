# CI-only bootstrap: immutable release name, reviewed SHA-512 pins, no third-party installer.
param([Parameter(Mandatory)][string]$Destination)
$ErrorActionPreference = "Stop"
if ($IsLinux) {
  $asset = "Godot_v4.5.1-stable_linux.x86_64.zip"
  $expected = "5bccbed65a94b82c7c319fdb15719ee8113a6e503976cc54e16f1c61fe95f3d74e5e40b8449b5bb89ff7f424574c20af01a4f5ef08b389e4dc338b245185b0b9"
  $executable = "Godot_v4.5.1-stable_linux.x86_64"
} elseif ($IsWindows) {
  $asset = "Godot_v4.5.1-stable_win64.exe.zip"
  $expected = "ab84df90ead5a888530faaabe744a27678ef7635068883900174fae37f7fc6178d033b551d88963c7dc2466580915a582bbc79aca97c19085900655761f56a27"
  $executable = "Godot_v4.5.1-stable_win64_console.exe"
} else { throw "CI bootstrap supports Linux x86_64 and Windows x64 only" }
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
$destinationPath = (Resolve-Path $Destination).Path
$archive = Join-Path $destinationPath $asset
Invoke-WebRequest "https://github.com/godotengine/godot-builds/releases/download/4.5.1-stable/$asset" -OutFile $archive
if ((Get-FileHash $archive -Algorithm SHA512).Hash.ToLowerInvariant() -ne $expected) { throw "Godot archive SHA-512 mismatch" }
Expand-Archive -LiteralPath $archive -DestinationPath $destinationPath -Force
$engine = Join-Path $destinationPath $executable
if ($IsLinux) { & chmod +x $engine; if ($LASTEXITCODE) { throw "chmod failed" } }
$version = & $engine --version | Out-String
if ($LASTEXITCODE -ne 0 -or $version.Trim() -ne "4.5.1.stable.official.f62fdbde1") { throw "Unexpected Godot build: $version" }
Write-Output "Verified Godot: $version"
"GODOT=$engine" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
