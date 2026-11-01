# Exercise wrappers with controlled process responses and real Godot failures.
# Runs only on disposable project copies; never injects into the working game.
param(
  [Parameter(Mandatory)][string]$Godot,
  [ValidateSet("powershell", "bash")][string]$Shell = "powershell"
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$engine = (Get-Command $Godot -ErrorAction Stop).Source
$root = Join-Path ([IO.Path]::GetTempPath()) ("aod-harness-" + [guid]::NewGuid().ToString("N"))
$project = Join-Path $root "project with spaces"
$count = 0
$oldLogDir = $env:AOD_TEST_LOG_DIR
$oldCase = $env:AOD_FAKE_CASE
$oldTrace = $env:AOD_FAKE_TRACE
function Invoke-Wrapper([string]$Wrapper, [string]$Binary, [string[]]$Extra = @(), [bool]$Pass = $false, [string]$Evidence = "") {
  $extension = if ($Shell -eq "bash") { "sh" } else { "ps1" }
  $path = Join-Path $project "$Wrapper.$extension"
  if ($Shell -eq "bash") {
    $arguments = @($path, $Binary) + $Extra
    $output = & bash @arguments 2>&1 | Out-String
  } else {
    $arguments = @("-NoProfile", "-File", $path, "-Godot", $Binary) + $Extra
    $output = & (Join-Path $PSHOME $(if ($IsLinux -or $IsMacOS) { "pwsh" } else { "pwsh.exe" })) @arguments 2>&1 | Out-String
  }
  $status = $LASTEXITCODE
  if (($status -eq 0) -ne $Pass -or ($Evidence -and $output -notmatch $Evidence)) {
    throw "Unexpected result for $Wrapper / $env:AOD_FAKE_CASE (exit $status):`n$output"
  }
  $script:count++
  Write-Output "HARNESS PASS: $Wrapper / $env:AOD_FAKE_CASE => exit $status"
}
try {
  New-Item -ItemType Directory -Path $project -Force | Out-Null
  Get-ChildItem (Join-Path $PSScriptRoot "..") -Force | Where-Object { $_.Name -ne ".godot" } | Copy-Item -Destination $project -Recurse
  $env:AOD_FAKE_TRACE = Join-Path $root "trace.txt"
  $fake = Join-Path $root $(if ($Shell -eq "bash") { "fake godot.sh" } else { "fake godot.ps1" })
  if ($Shell -eq "bash") {
    @'
#!/usr/bin/env bash
stage=tests
for arg in "$@"; do
  case "$arg" in --import) stage=import;; --phase=write) stage=write;; --phase=verify) stage=verify;; esac
done
echo "$stage" >> "$AOD_FAKE_TRACE"
echo 'Godot Engine v4.5.1.stable.official'
case "$AOD_FAKE_CASE:$stage" in
  import-exit:import) exit 9;;
  import-error:import) echo 'ERROR: injected import diagnostic' >&2; exit 0;;
  runtime-error:tests) printf '\033[31mSCRIPT ERROR: injected runtime error\033[0m\n' >&2;;
  engine-error:tests) echo 'ERROR: injected engine error' >&2;;
  assertion:tests) echo 'FAIL injected assertion'; echo '=== 1 tests, 1 failed ==='; exit 1;;
  false-summary:tests) echo '=== 1 tests, 1 failed ==='; exit 0;;
  empty:tests|empty:verify) exit 0;;
  zero-tests:tests) echo '=== 0 tests, 0 failed ==='; exit 0;;
  write-exit:write) exit 7;;
  verify-exit:verify) echo 'RELAUNCH CHECK FAILED: injected'; exit 8;;
esac
case "$stage" in
  tests) echo '=== 1 tests, 0 failed ===';;
  write) echo shared > "$APPDATA/sentinel"; echo 'RELAUNCH CHECK: wrote slot 2';;
  verify) test -f "$APPDATA/sentinel" || exit 6; echo 'RELAUNCH CHECK PASSED: fake';;
esac
'@ | Set-Content -LiteralPath $fake -Encoding utf8NoBOM
    & chmod +x $fake
  } else {
    @'
$stage = "tests"
foreach ($arg in $args) {
  switch ($arg) { "--import" { $stage = "import" }; "--phase=write" { $stage = "write" }; "--phase=verify" { $stage = "verify" } }
}
Add-Content -LiteralPath $env:AOD_FAKE_TRACE -Value $stage
Write-Output 'Godot Engine v4.5.1.stable.official'
switch ("${env:AOD_FAKE_CASE}:$stage") {
  'import-exit:import' { exit 9 }
  'import-error:import' { [Console]::Error.WriteLine('ERROR: injected import diagnostic'); exit 0 }
  'runtime-error:tests' { [Console]::Error.WriteLine("$([char]27)[31mSCRIPT ERROR: injected runtime error$([char]27)[0m") }
  'engine-error:tests' { [Console]::Error.WriteLine('ERROR: injected engine error') }
  'assertion:tests' { Write-Output 'FAIL injected assertion'; Write-Output '=== 1 tests, 1 failed ==='; exit 1 }
  'false-summary:tests' { Write-Output '=== 1 tests, 1 failed ==='; exit 0 }
  'empty:tests' { exit 0 }
  'empty:verify' { exit 0 }
  'zero-tests:tests' { Write-Output '=== 0 tests, 0 failed ==='; exit 0 }
  'write-exit:write' { exit 7 }
  'verify-exit:verify' { Write-Output 'RELAUNCH CHECK FAILED: injected'; exit 8 }
}
switch ($stage) {
  tests { Write-Output '=== 1 tests, 0 failed ===' }
  write { Set-Content -LiteralPath (Join-Path $env:APPDATA 'sentinel') -Value 'shared'; Write-Output 'RELAUNCH CHECK: wrote slot 2' }
  verify { if (!(Test-Path (Join-Path $env:APPDATA 'sentinel'))) { exit 6 }; Write-Output 'RELAUNCH CHECK PASSED: fake' }
}
exit 0
'@ | Set-Content -LiteralPath $fake -Encoding utf8NoBOM
    # Invoke the fake as a native process so Console.Error uses the same stderr
    # capture path as Godot, rather than bypassing PowerShell's object pipeline.
    $fakeScript = $fake
    if ($IsWindows) {
      $fake = Join-Path $root "fake godot.cmd"
      ('@"' + (Join-Path $PSHOME 'pwsh.exe') + '" -NoProfile -File "' + $fakeScript + '" %*') | Set-Content -LiteralPath $fake -Encoding ascii
    } else {
      $fake = Join-Path $root "fake godot"
      "#!/usr/bin/env bash`nexec pwsh -NoProfile -File '$fakeScript' `"`$@`"`n" | Set-Content -LiteralPath $fake -Encoding utf8NoBOM
      & chmod +x $fake
    }
  }
  foreach ($wrapper in @("run_tests", "check_relaunch")) {
    $env:AOD_FAKE_CASE = "success"
    Invoke-Wrapper $wrapper $fake -Pass $true
    foreach ($case in @("import-exit", "import-error")) {
      Remove-Item -LiteralPath $env:AOD_FAKE_TRACE -ErrorAction SilentlyContinue
      $env:AOD_FAKE_CASE = $case
      Invoke-Wrapper $wrapper $fake -Evidence '(import failed|CHECK FAILED: import)'
      if (@(Get-Content $env:AOD_FAKE_TRACE).Count -ne 1) { throw "Continued after failed import" }
    }
  }
  foreach ($case in @("runtime-error", "engine-error", "assertion", "false-summary", "empty", "zero-tests")) {
    $env:AOD_FAKE_CASE = $case
    Invoke-Wrapper "run_tests" $fake -Evidence 'CHECK FAILED:'
  }
  foreach ($case in @("write-exit", "verify-exit", "empty")) {
    $env:AOD_FAKE_CASE = $case
    Invoke-Wrapper "check_relaunch" $fake -Evidence 'CHECK FAILED:'
  }
  $env:AOD_FAKE_CASE = "missing-binary"
  Invoke-Wrapper "run_tests" (Join-Path $root "missing-engine")

  # Real engine failures: copied code only. Keep logs outside the temporary copy.
  $env:AOD_FAKE_CASE = "real-assertion"
  $injected = Join-Path $project "tests/unit/test_harness_injected.gd"
  "extends TestCase`nfunc test_injected() -> void:`n`tassert_true(false, `"intentional harness failure`")`n" | Set-Content $injected
  $filter = if ($Shell -eq "bash") { @("--filter=harness_injected") } else { @("-Filter", "harness_injected") }
  Invoke-Wrapper "run_tests" $engine -Extra $filter -Evidence '1 tests, 1 failed'
  $env:AOD_FAKE_CASE = "real-runtime-error"
  "extends TestCase`nfunc test_injected() -> void:`n`tvar target: Variant = null`n`ttarget.missing_method()`n" | Set-Content $injected
  Invoke-Wrapper "run_tests" $engine -Extra $filter -Evidence 'SCRIPT ERROR:'
  $env:AOD_FAKE_CASE = "real-import-error"
  Remove-Item -LiteralPath $injected
  $autoload = Join-Path $project "scripts/services/content_db.gd"
  $autoloadSource = Get-Content -LiteralPath $autoload -Raw
  "extends Node`nthis is deliberately invalid GDScript`n" | Set-Content -LiteralPath $autoload
  Invoke-Wrapper "check_relaunch" $engine -Evidence '(import failed|CHECK FAILED: import)'
  $autoloadSource | Set-Content -LiteralPath $autoload
  $env:AOD_FAKE_CASE = "real-state-mismatch"
  $relaunch = Join-Path $project "tools/relaunch_check.gd"
  $source = Get-Content -LiteralPath $relaunch -Raw
  $source.Replace('var expected = JSON.parse_string(TestCase.read_text(EXPECTED))', "var expected = JSON.parse_string(TestCase.read_text(EXPECTED))`n`texpected[`"universe`"][`"current_day`"] = -999") | Set-Content -LiteralPath $relaunch
  Invoke-Wrapper "check_relaunch" $engine -Evidence 'RELAUNCH CHECK FAILED:.*difference'
  Write-Output "HARNESS SELF-TEST PASSED: $count cases ($Shell)"
} finally {
  $env:AOD_TEST_LOG_DIR = $oldLogDir
  $env:AOD_FAKE_CASE = $oldCase
  $env:AOD_FAKE_TRACE = $oldTrace
  $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
  if ((Split-Path $root -Parent).TrimEnd('\', '/') -eq $parent -and (Split-Path $root -Leaf) -match '^aod-harness-[a-f0-9]{32}$') {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
  }
}
# Do not leak the last intentionally failing child's exit code to CI's pwsh
# epilogue. Unhandled assertion/fixture exceptions above still terminate nonzero.
exit 0
