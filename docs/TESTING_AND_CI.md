# Phase 2B — testing and CI

The authoritative project is `game/`. Compatibility target: official Godot
`4.5.1.stable.official.f62fdbde1`. No gameplay/content changes are part of this milestone.

## Running checks

From `game/`, Windows PowerShell:

```powershell
$engine = 'C:\path\to\Godot_v4.5.1-stable_win64_console.exe'
.\tools\verify.ps1 -Godot $engine -Check import
.\run_tests.ps1 -Godot $engine
.\tools\verify.ps1 -Godot $engine -Check smoke
.\check_relaunch.ps1 -Godot $engine
# Optional focused test run:
.\run_tests.ps1 -Godot $engine -Filter mist_preview
```

Linux/Bash:

```bash
bash tools/verify.sh import /absolute/path/to/godot
bash run_tests.sh /absolute/path/to/godot
bash tools/verify.sh smoke /absolute/path/to/godot
bash check_relaunch.sh /absolute/path/to/godot
bash run_tests.sh /absolute/path/to/godot --filter=mist_preview
```

Each command imports first and rejects a nonzero process exit or engine/script diagnostics
on either output stream, including import errors reported with exit 0. Tests must report a
positive test count and zero failures; a filter matching no tests fails. Relaunch must report
both a completed write and successful comparison from a second process. Warnings remain visible
and do not fail the run (the two persistence-recovery warnings are expected).

Each invocation uses a new temporary application-data directory (APPDATA, LOCALAPPDATA, XDG data,
config and cache). Write/verify share that invocation's private directory, then it is removed.
PowerShell restores the caller's environment and working directory. Project `.godot/` cache is
still local to the checkout; avoid concurrent imports in the same checkout. Self-contained Godot
builds can still keep editor configuration next to their executable; use a dedicated engine copy
if that directory is read-only. macOS-specific Godot application-data behavior is not verified.

Set `AOD_TEST_LOG_DIR` to retain per-stage logs in a unique run subdirectory; otherwise logs are
printed and the temporary copy is removed. CI retains logs for seven days even after a failure.
The checks do not copy or use personal save slots. Do not commit local logs, caches or binaries.

## Deliberate failure detection

PowerShell 7 (also installed on both hosted runners) runs the harness self-test:

```powershell
.\tools\test_harness.ps1 -Godot $engine -Shell powershell
# On Linux, verify the independent Bash wrappers too:
./tools/test_harness.ps1 -Godot $engine -Shell bash
```

The self-test copies the project to a temporary directory with spaces, excluding `.godot/`.
It never injects failures into the active project. Twenty cases exercise each shell:

- Two successful fake-engine controls, including shared isolated data across relaunch processes.
- Both wrappers: nonzero import and diagnostic-only import; trace confirms no subsequent stage.
- Test wrapper: runtime script error with ANSI decoration, engine error on stderr, failed
  assertion/nonzero exit, failing summary despite exit 0, missing summary, zero tests.
- Relaunch wrapper: failed write, failed verification, missing success marker.
- Missing executable.
- Four real-Godot cases: failing assertion, runtime null-method error, malformed referenced
  autoload rejected at import, and tampered expected day rejected by the full-state comparison.

An unreferenced malformed script is not guaranteed to be compiled during Godot's editor import;
the import fixture deliberately corrupts the copied Content autoload. The full test run remains
necessary to load test scripts and validate runtime paths.

## GitHub Actions

Workflow: [Godot reliability](https://github.com/IntermediatShaine/Ashes_of_Dominion/actions/workflows/game-tests.yml).
It runs on pushes and pull requests affecting `game/**`, its workflow, or `.gitattributes`,
and supports manual dispatch once available on the default branch. Matrix: Ubuntu 24.04 and
Windows Server 2022, with independent 20-minute job limits. Linux runs the Bash game wrappers;
Windows runs PowerShell. Both run PowerShell failure injection; Linux additionally runs Bash
failure injection. Import, full tests, 60-frame startup, and two-process save consistency are
separate required job steps. A hung engine is bounded by the CI job timeout; local wrappers do
not impose their own process timeout.

Actions are pinned to full commit SHAs. `install_ci_godot.ps1` downloads from the
[official 4.5.1 release](https://github.com/godotengine/godot-builds/releases/tag/4.5.1-stable),
checks archive SHA-512 against committed pins from that release's `SHA512-SUMS.txt`, then verifies
the executable's exact version. No export templates are needed. The workflow uses read-only
repository permissions, no persisted checkout credentials and no project secrets. Branch
protection requiring this workflow is an owner setting, not enabled by this PR.

## Execution record — 2026-11-01

Base: `aec6ce9` (merged Mist PR #4); branch: `codex/ci-test-hardening`.
Local engine: `D:\Ashes of Dominion\.local-tools\godot\Godot_v4.5.1-stable_win64_console.exe`.
Baseline ran the original wrappers with isolated APPDATA as documented in the issue #3 audit:
66 tests, 0 failed; headless boot and two-process relaunch passed.

After hardening, executed from `game/` with that engine as `$engine`:

| Command | Actual result |
| --- | --- |
| `.\run_tests.ps1 -Godot $engine` | exit 0; import accepted; 66 tests, 0 failed; only two expected recovery warnings |
| `.\run_tests.ps1 -Godot $engine -Filter mist_preview` | exit 0; 4 tests, 0 failed |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1 -Godot $engine -Filter mist_preview` | Windows PowerShell 5.1: exit 0; 4 tests, 0 failed |
| `.\tools\verify.ps1 -Godot $engine -Check smoke` | exit 0; import and 60-frame boot accepted |
| `.\check_relaunch.ps1 -Godot $engine` | exit 0; write and fresh-process state comparison accepted |
| `.\tools\test_harness.ps1 -Godot $engine` | exit 0; 20/20 controlled cases accepted; all 18 negative cases returned nonzero |
| `install_ci_godot.ps1 -Destination <workspace-local tools>` | official Windows archive checksum and exact executable version verified |
| `bash -n game/tools/verify.sh game/run_tests.sh game/check_relaunch.sh` | exit 0 via Git Bash outside sandbox (MSYS initialization is blocked inside sandbox) |
| `git diff --check` | exit 0 |

The first fake stderr fixture bypassed PowerShell's object pipeline; it was corrected to run as
a native process before the passing 20-case run. The first real import fixture was unreferenced
and did not compile during import; corrected to a referenced autoload as described above.
These were fixture-development failures, not passing checks.

The initial [hosted attempt](https://github.com/IntermediatShaine/Ashes_of_Dominion/actions/runs/41330707244)
failed workflow validation because job-level `env` cannot reference `runner.temp`; moved that
configuration into a step via `GITHUB_ENV`. No checks ran in that failed attempt.
The [next hosted attempt](https://github.com/IntermediatShaine/Ashes_of_Dominion/actions/runs/41330853999)
passed game import, all 66 tests, boot, relaunch and 20 PowerShell harness cases on both operating
systems. It then failed because the self-test leaked the last intentionally failing child's
exit code to GitHub's PowerShell epilogue. Added explicit success exit after all assertions and
cleanup; exceptions still terminate nonzero. Bash failure injection was skipped in that attempt.
The [following attempt](https://github.com/IntermediatShaine/Ashes_of_Dominion/actions/runs/41331100145)
passed PowerShell failure injection, then exposed a self-test message mismatch: Bash correctly
returned 1 for import failure but said `CHECK FAILED: import` instead of `import failed`.
The self-test now accepts either explicit stage-specific message; nonzero status is still required.
Final tested engineering revision: `76d89d3a1df3cf53ccd16b55e5a58a90af116845`.
[PR workflow run 41331300938](https://github.com/IntermediatShaine/Ashes_of_Dominion/actions/runs/41331300938)
completed successfully on **both** Ubuntu 24.04 and Windows Server 2022:

| Hosted check | Ubuntu 24.04 | Windows Server 2022 |
| --- | --- | --- |
| SHA-512 engine archive + exact version | passed | passed |
| Headless import | passed | passed |
| Game tests | 66 tests, 0 failed | 66 tests, 0 failed |
| Startup smoke test | passed | passed |
| Two-process save/relaunch comparison | passed | passed |
| PowerShell harness cases | 20/20, including 18 rejected failures | 20/20, including 18 rejected failures |
| Bash harness cases | 20/20, including 18 rejected failures | intentionally not scheduled |
| Log artifact upload | passed | passed |

No human/manual play acceptance is inferred from automated results. The regression suite
still includes the four Mist renderer tests, nine deterministic generation tests and thirteen
save-system tests. `game/scripts/`, `game/scenes/`, `game/data/`, `game/tests/`, and the relaunch
scene/script are unchanged; no save schema, RNG, generator or scene-reference changes.

## Reverification — 2026-11-06

The repeated Phase 2B assignment is already implemented and merged in
[PR #5](https://github.com/IntermediatShaine/Ashes_of_Dominion/pull/5), merge
`a3b24a154b8914568b9a7e41eeba48706f0d703a`. Fetched current main and created
`codex/ci-test-hardening-verification` in a separate worktree at
`efa32c815fcccc0e147fc3c4307ed05f9cf83eee`; the existing village branch was preserved.
The four wrappers, shared runners, failure-injection harness and reliability workflow
are unchanged from that merge. Their implementation satisfies this assignment;
no replacement or gameplay changes were necessary.

Fresh commands from the worktree root, using
`$engine = 'D:\Ashes of Dominion\.local-tools\godot\Godot_v4.5.1-stable_win64_console.exe'`:

| Command | Observed result |
| --- | --- |
| `& $engine --version` | `4.5.1.stable.official.f62fdbde1` |
| `& ./game/run_tests.ps1 -Godot $engine` | import passed from a fresh project cache; 157 tests, 0 failed; expected two save-recovery warnings |
| `& ./game/run_tests.ps1 -Godot $engine -Filter mist_preview` | import passed; 4 tests, 0 failed |
| `& ./game/tools/verify.ps1 -Godot $engine -Check smoke` | import and 60-frame startup passed |
| `& ./game/check_relaunch.ps1 -Godot $engine` | write and fresh-process comparison passed: day 12, level 1, morality 25, 4 buildings |
| `& ./game/tools/test_harness.ps1 -Godot $engine` | 20/20 cases passed; both positive controls accepted, all 18 intentional failures returned exit 1 |

The negative cases include failed imports (nonzero exit and diagnostic-only exit 0),
script/engine errors, assertions, failing/missing/empty summaries, unsuccessful
relaunch stages, missing executable, and real Godot assertion/runtime/import/state
mismatch injections into disposable copies. Imports stop subsequent stages on failure.
The full suite includes 4 Mist renderer, 9 deterministic generation, 5 RNG stream,
13 save-system and 5 settlement-persistence tests. The map's Mist rendering fix is
retained; later map additions are POI buttons/departure and telemetry. This verification
changes no RNG code, save schema, content, scene references or test implementation.

The GitHub connector independently confirmed PR #5 is merged and both jobs of
[run 41331592525](https://github.com/IntermediatShaine/Ashes_of_Dominion/actions/runs/41331592525)
passed, including Linux Bash failure injection and Windows/ Linux PowerShell failure
injection. These are historical hosted results, not a new hosted run of today's main.
The connector returned no PR workflow runs for current main's merge SHA; this is not
proof that all push workflows are absent. Bash/Linux were not rerun locally today;
Bash is not on this session's PATH. This documentation-only follow-up does not match
the reliability workflow's path filters. Existing limitations remain: no macOS or
human gameplay acceptance, no local process timeout, and branch protection is an
owner setting. No unreviewed changes were merged in this session.
