# Codex issue #3 audit — 2026-11-01

Repository baseline: main `1a2d4ed` (`docs: onboard Codex for shared Godot work`).
Working branch: `codex/issue-3-mist-preview`. Current source was cloned into
`D:\Ashes of Dominion\current-repo`; the untracked prototype at the workspace root was preserved.
Read the onboarding/design/architecture/state documentation and inspected the map, route planner,
session, expedition lifecycle, persistence, generation and test-runner source before correction.

## Reproduction and correction

The map's `_draw()` bypassed its hidden-edge guard whenever `selected_edges.has(eid)` was true.
It passed both real endpoints of every uncharted selected edge to `_dashed`, exposing otherwise
hidden intermediate waypoints. Numeric estimates were already approximate and remain unchanged.

The new renderer test subclasses the actual map script and records accent-colored `_dashed`
commands during engine draw callbacks. A bent graph with two hidden intermediate nodes avoids
depending on a particular generated route. Against original production code: **4 tests, 2 failed**,
including changed preview coordinates after moving a hidden waypoint. An initial test-authoring
parse error (Variant-derived boolean inference) was corrected before this reproduction run.

The fix skips real uncharted selected edges and draws one straight origin-to-destination indication
when any selected edge is unknown. Already charted edges keep their original solid rendering and
highlight. Fully charted and Mist-off selections retain their real edges. Different uncharted
alternatives intentionally share the same visual indication; route buttons and actual expedition
paths still differ. Four tests cover fully/partly uncharted routes, charted/Mist-off behavior,
and unchanged state, world fingerprint, estimates and expedition path selection.

This is a presentation-only change: no schema, generator-version, RNG or save migration changes.
Automated renderer commands were inspected; no screenshots or human gameplay acceptance claimed.

## Executed checks

Engine located in the owner's Downloads tool directory; `--version` returned
`4.5.1.stable.official.f62fdbde1`. Initial sandboxed execution failed to write the original
self-contained editor data and user logs; the runtime crashed after `Could not create directory:
'user://logs'`. These attempts are failures, not project test results.

Copied the existing two Godot executables to a workspace-local tools directory, enabled its
self-contained mode with `._sc_`, and isolated APPDATA. Nothing was downloaded or committed.
Each successful command below ran from `current-repo/game` with:

```powershell
$env:APPDATA = 'D:\Ashes of Dominion\.local-tools\userdata'
$engine = 'D:\Ashes of Dominion\.local-tools\godot\Godot_v4.5.1-stable_win64_console.exe'
```

| Command | Observed result |
| --- | --- |
| `.\run_tests.ps1 -Godot $engine` (before changes) | exit 0; 62 tests, 0 failed; wrapper import clean; two expected recovery warnings |
| `$engine --headless --path . --quit-after 60` (invoked with `&`) | baseline and corrected exit 0, no errors |
| `.\check_relaunch.ps1 -Godot $engine` | baseline and corrected exit 0; `RELAUNCH CHECK PASSED` |
| `.\run_tests.ps1 -Godot $engine -Filter mist_preview` (new tests, original production code) | exit 1; 4 tests, 2 failed, actual hidden coordinates recorded |
| `.\run_tests.ps1 -Godot $engine` (corrected) | exit 0; 66 tests, 0 failed; two expected recovery warnings, no engine/script errors |
| `$engine --headless --path . --import` (invoked with `&`, corrected) | exit 0; log checked, no errors/warnings |
| `git diff --check` | exit 0 |

## Earlier foundation: recovered, statically compared only

Found `AshesOfDominion-unified-foundation.zip` under
`C:\Users\varga\Downloads\g-p-6adfbed081e081919bdaaa684c955f6d`.
SHA-256: `9C207D4CAD732F7E7649AA8460BEA37B494C01B91372A7967A6320B56936781C`.
Read entries directly from the ZIP. Its `AoD/project.godot` declares `0.3.1-m1` and Godot 4.5;
the adjacent report names `milestone/1-physical-checkpoint`. The loose `AshesOfDominion/`
directory instead declares 0.2.0 / feature 4.7, so it was not treated as the exact M1 source.
The local `AUTHORITATIVE_PROJECT.md` points to another `AoD/` checkout; that external note does
not supersede the user's explicit instruction that the GitHub `game/` implementation is current.
Archive tests were **not rerun**; historical counts in its report are not fresh verification.

| Archive source | Current repository counterpart | Reuse assessment |
| --- | --- | --- |
| `AoD/tests/validate.py` | `game/run_tests.ps1`, `game/check_relaunch.ps1` | Isolated APPDATA, per-stage logs, expected success markers and JSON evidence are useful. Current wrappers already reject runtime errors, but do not explicitly propagate import failure. Propose a separate tooling PR with failure injection. |
| `AoD/tests/test_player_foundation.gd` | `game/tests/integration/test_scenes.gd`, `test_combat_physics.gd` | Raw physical-key events and actual navigation/return tests can extend current action-injection tests. Port assertions to current Router/Session contracts rather than copying scenes. |
| `AoD/src/world/village_builder.gd` | `game/scripts/interface/settlement_screen.gd` | Physical village boundaries are a useful reference for Claude's future walkable settlement. Current settlement is a management UI; importing the old scene is outside this fix. |
| `AoD/src/services/game_state_manager.gd::commit_candidate` | `game/scripts/services/game_session.gd` | Detached candidate state activated only after durable write is a useful reliability pattern. Evaluate separately with write-failure tests before changing Session mutation semantics. |
| `AoD/src/save/save_format.gd`, `src/state/character_state.gd` | `game/scripts/models/save_game.gd`, `character_state.gd`, `universe_state.gd` | Incompatible: format-2 envelope with nested session versus schema-1 three-scope document; old health is character-owned, current health universe-owned. No direct save interchange or automatic migration. |

Safe follow-up order: port runner reliability ideas, then raw-input assertions, then evaluate specific
feature contracts with Claude. Any future save conversion needs explicit field/identifier/RNG and
health-ownership mapping, fixture-based migration tests and preservation of original saves. No
wholesale migration, external checkout modification or replacement of `game/` was performed.
