# Implementation status

**Last verified: 2026-11-01** on branch `codex/ci-test-hardening`, with the official
**Godot 4.5.1-stable** Linux and Windows builds (headless). Project root: [`game/`](../game/).

Verification levels: **Planned** (design only) · **Implemented** (code present and inspected) ·
**Tested** (automated test executed and passing, command recorded) · **Runtime** (executed in
the engine, not asserted by a test) · **Manual** (a human played it) · **Unverified** (claimed
elsewhere, not inspected here).

## Evidence from the 2026-11-01 session

| Check | Command (run from `game/`) | Observed |
| --- | --- | --- |
| Project imports | `godot --headless --path . --import` | exit 0, no errors |
| Automated tests | `./run_tests.sh <godot>` | `=== 62 tests, 0 failed ===`, no `SCRIPT ERROR` (two expected `WARNING` lines from the save-recovery tests) |
| Boot smoke test | `godot --headless --path . --quit-after 60` | exit 0, no errors |
| Save → quit → relaunch → Continue | `./check_relaunch.sh <godot>` | `RELAUNCH CHECK PASSED` (two separate engine processes; full state document identical after reload; a deliberately tampered snapshot makes it fail) |
| Rendered screenshot tour | `godot --path . res://tools/screenshot_tour.tscn` | **Not run** this session (no display). Last run 2026-10-28: 10 screens, no errors |
| Manual play on Windows | — | **Not done yet.** This is the top open item |

Test breakdown (62): unit 21 (rules, RNG stream, stable hash) · deterministic 9 (world graph,
wilderness, 30-seed constraint sweep) · persistence 13 (versioned write/verify/backup/recovery,
migration gate, 64-bit state round-trip) · integration 19 (core loop, every scene instantiates,
scripted exploration playthrough, defeat → resurrection once, **enemy FSM 7**, **combat physics 4**).

## Playable-prototype checklist (owner's priority list)

| # | Step | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Begin in the starting village (Emberfall) | Tested + Runtime | `test_scenes.gd`, settlement screen (management screen, not walkable) |
| 2 | Working interface | Runtime + Tested | menus, settlement, map, HUD, pause, decision, death screens instantiate in tests |
| 3 | Strategic world map | Tested | 6 fixed landmarks + 6 seeded waypoints, Mist hides undiscovered nodes |
| 4 | Select destination, plan expedition | Tested | Dijkstra routes with an alternative; estimates vs. truth |
| 5 | Enter a procedurally generated area | Tested | seeded wilderness, 4 biomes, constraint repair; same seed → same area |
| 6 | Eight-direction movement | Tested | physics-driven movement test, diagonal normalised |
| 7 | Enemies + real-time combat | **Tested (new)** | `test_enemy_fsm.gd` (detect/chase/windup/strike/cooldown/escape/aggro/death), `test_combat_physics.gd` (hitbox sweep hits front once, not behind; cooldown; i-frames) |
| 8 | Collect resources | Tested | harvest once, haul, regrowth after 10 days |
| 9 | Return to settlement | Tested | returned / retreated / defeated all resolve exactly once |
| 10 | Construct a building | Tested | 4 buildings, all-or-nothing cost, recruits move into housing |
| 11 | Save, quit, reload, continue | **Tested (new)** | in-process persistence tests + `check_relaunch` across a real process restart |

## Systems

| System | Status | Notes |
| --- | --- | --- |
| StableHash / RngStream / RngRegistry (6 named streams, state persisted as strings) | Tested | FNV-1a 64 + splitmix seeds, engine PCG32 streams |
| Three state scopes: CharacterState / UniverseState / MultiverseState | Tested | see `game/docs/game_state.md` |
| Versioned saves: temp → verify → backup → promote; recovery from backup / orphaned temp; migration hook | Tested | schema v1, 3 slots |
| Resolved resurrection outcomes stored before use; explicit pending transition; crash recovery on load | Tested | only `return_home`; no universe transfer rules |
| World graph + route planning (Mist-aware) | Tested | |
| Wilderness generation (terrain, resources, enemies, decision NPC, repair) | Tested | |
| Combat rules, player melee, enemy FSM (4 archetypes) | Tested | one moveset; tuning values unplayed |
| Rewards, XP, level-up, class unlock evaluation | Tested | class switching has no UI/effect |
| Settlement (stats, storage cap, 4 buildings, daily production/food, morale) | Tested | governance policies are schema only |
| Morality (character) vs faction reputation (universe) | Tested | distinct, event-id idempotent |
| One narrative decision with persistent consequences | Tested | "stranded survivor" |
| Two factions, territory, grace period / awareness bands | Tested | no faction AI, no raids |
| Difficulty presets + custom, frozen per universe | Tested | 6 of 10 parameters are stored but unused |
| Main menu, new game, load, settings, settlement, map, HUD, pause, death | Runtime | code-built UI, placeholder `_draw()` visuals |
| Walkable settlement, companions, armies, faction AI, raids, universe transfer rules, inventory/equipment, skills, audio, pixel art | Planned | not started |

## Known limitations

See [`game/docs/known_issues.md`](../game/docs/known_issues.md) (authoritative, kept with the
code). Headline items: no manual verification on Windows; combat numbers unplayed; no save during
an expedition; old generation versions are not preserved. Mist route-preview waypoint disclosure
is corrected and covered by renderer integration tests (issue #3).

## Unreconciled material

- A separate line of work (OpenAI Codex, "AshesOfDominion-unified-foundation" v0.3.1-m1, plus
  Claude's M2/M2b/M2.1 zips) exists outside this repository and was **not inspected** on
  2026-11-01 (folder access was not available). Its relationship to `game/` is an owner decision;
  see `docs/AI_HANDOFF.md` and `docs/DECISIONS.md`. Codex subsequently located and statically
  inspected the exact v0.3.1-m1 archive; see [`CODEX_ISSUE_3_AUDIT.md`](CODEX_ISSUE_3_AUDIT.md).

## Codex independent verification — issue #3 (2026-11-01)

Base `1a2d4ed`; branch `codex/issue-3-mist-preview`. Full commands, environment setup and
archive comparison are in [`CODEX_ISSUE_3_AUDIT.md`](CODEX_ISSUE_3_AUDIT.md).

| Check | Baseline | After correction |
| --- | --- | --- |
| Headless import | wrapper import completed without diagnostics after data-path isolation | explicit import exit 0, no errors/warnings |
| Automated suite | 62 tests, 0 failed | 66 tests, 0 failed; only two expected recovery warnings |
| New renderer regression suite against original code | 4 tests, 2 failed (uncharted and partly charted geometry) | all 4 pass within full suite |
| Headless boot, 60 frames | exit 0 | exit 0 |
| Two-process save/relaunch | passed | passed |

No generator, RNG, save-schema or route-selection changes. No manual play or screenshot review.

## Phase 2B — automated testing and CI

`codex/ci-test-hardening`, base `aec6ce9`: four wrappers now reject failed imports, diagnostics,
missing completion markers and empty test selections; tests use isolated application data.
Local Windows Godot 4.5.1: **66 tests, 0 failed**, Mist **4/4**, import/boot/relaunch passed;
**20/20 harness cases** including 18 intentional failures rejected. Linux/Windows workflow
added with pinned action SHAs and SHA-512-verified engine. Hosted status and exact commands:
[`TESTING_AND_CI.md`](TESTING_AND_CI.md). Gameplay source and save format unchanged.
Hosted engineering revision `76d89d3`: [run 41331300938](https://github.com/IntermediatShaine/Ashes_of_Dominion/actions/runs/41331300938)
**passed on Linux and Windows**, including 66 tests per platform, import/boot/relaunch,
20 PowerShell harness cases per platform and 20 Bash cases on Linux.

## How to update status

For every meaningful change record the commit SHA, affected file(s), exact test command(s),
observed outcomes and any unverified behavior. Never infer test success from design documents.
