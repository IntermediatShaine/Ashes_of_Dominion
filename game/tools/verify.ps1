# Shared strict runner. Each invocation owns private application data; relaunch
# phases share that directory. No external PowerShell modules required.
param(
  [string]$Godot = "godot",
  [ValidateSet("import", "tests", "smoke", "relaunch")][string]$Check = "tests",
  [string]$Filter = ""
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$result = 1
$runDir = $null
$oldLocation = Get-Location
$savedEnv = @{}
try {
  $engine = (Get-Command $Godot -ErrorAction Stop).Source
  $runDir = Join-Path ([IO.Path]::GetTempPath()) ("aod-check-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $runDir | Out-Null
  $logDir = Join-Path $runDir "logs"
  if ($env:AOD_TEST_LOG_DIR) {
    $logDir = Join-Path ([IO.Path]::GetFullPath($env:AOD_TEST_LOG_DIR)) (Split-Path $runDir -Leaf)
  }
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  foreach ($key in @("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME")) {
    $savedEnv[$key] = [Environment]::GetEnvironmentVariable($key, "Process")
    $directory = Join-Path $runDir $key
    New-Item -ItemType Directory -Path $directory | Out-Null
    [Environment]::SetEnvironmentVariable($key, $directory, "Process")
  }
  Set-Location (Join-Path $PSScriptRoot "..")
  Write-Output "CHECK: $Check; isolated application data: $runDir"
  function Invoke-Stage([string]$Name, [string[]]$EngineArgs, [string]$Marker = "") {
    $global:LASTEXITCODE = 0
    # Continue lets Windows PS 5.1 capture native stderr; classify it explicitly.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { $output = (& $engine @EngineArgs 2>&1 | Out-String) }
    finally { $ErrorActionPreference = $previousPreference }
    $status = $LASTEXITCODE
    $output = $output -replace '\x1b\[[0-9;]*m', ''
    $output | Set-Content -LiteralPath (Join-Path $logDir "$Name.log") -Encoding utf8
    Write-Output $output
    if ($status -ne 0 -or $output -match '(?m)^\s*(SCRIPT ERROR:|ERROR:|FAIL\b|RELAUNCH CHECK FAILED:)') {
      throw "$Name failed (engine exit $status)"
    }
    if ($Marker -and $output -notmatch $Marker) { throw "$Name did not report successful completion" }
    Write-Output "CHECK PASSED: $Name"
  }
  Invoke-Stage "import" @("--headless", "--path", ".", "--import") 'Godot Engine v'
  switch ($Check) {
    "tests" {
      $engineArgs = @("--headless", "--path", ".", "res://tests/test_runner.tscn")
      if ($Filter) { $engineArgs += @("--", "--filter=$Filter") }
      Invoke-Stage "tests" $engineArgs '=== [1-9][0-9]* tests, 0 failed ==='
    }
    "smoke" { Invoke-Stage "smoke" @("--headless", "--path", ".", "--quit-after", "60") 'Godot Engine v' }
    "relaunch" {
      Invoke-Stage "write" @("--headless", "--path", ".", "res://tools/relaunch_check.tscn", "--", "--phase=write") 'RELAUNCH CHECK: wrote slot '
      Invoke-Stage "verify" @("--headless", "--path", ".", "res://tools/relaunch_check.tscn", "--", "--phase=verify") 'RELAUNCH CHECK PASSED:'
    }
  }
  $result = 0
} catch {
  Write-Output "CHECK FAILED: $_"
} finally {
  Set-Location $oldLocation
  foreach ($key in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($key, $savedEnv[$key], "Process") }
  if ($runDir) {
    # Delete only the exact GUID directory created by this invocation under temp.
    $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    if ((Split-Path $runDir -Parent).TrimEnd('\', '/') -eq $parent -and (Split-Path $runDir -Leaf) -match '^aod-check-[a-f0-9]{32}$') {
      Remove-Item -LiteralPath $runDir -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
exit $result
