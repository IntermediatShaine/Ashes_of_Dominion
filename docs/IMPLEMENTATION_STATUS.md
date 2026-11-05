# Implementation status

## Latest evidence — Stage 2 village gameplay, 2026-11-05

Branch `codex/stage2-village-gameplay`, base Claude Stage 1 `0e86cfc`.
Project: `game/`; Windows engine observed as `4.5.1.stable.official.f62fdbde1`.
Implemented: solo Survivor start; four functioning village buildings and L2
upgrades/repair; Workshop crafting/production and staffed Watchpost defense;
three framework-based POIs with persistent resources, rescue, equipment, lore
and morality consequences; supported POI save/Continue and existing death return.
Save schema 3 migrates schemas 1/2 while retaining legacy residents/iron/job costs.
Full interfaces, limitations and presentation tasks:
[`02_CODEX_TO_GEMINI.md`](../game/docs/handoffs/02_CODEX_TO_GEMINI.md).

Commands below were run from `D:\Ashes of Dominion\current-repo\game`, with
`$Godot = 'D:\Ashes of Dominion\.local-tools\ci-godot\Godot_v4.5.1-stable_win64_console.exe'`.

| Executed check | Observed result |
| --- | --- |
| `& $Godot --version` | `4.5.1.stable.official.f62fdbde1` |
| `./run_tests.ps1 -Godot $Godot` before changes | **138 tests, 0 failed**, import passed |
| `./run_tests.ps1 -Godot $Godot` after changes | **157 tests, 0 failed**, import passed; two intentional save-recovery warnings, no script errors |
| `./tools/verify.ps1 -Godot $Godot -Check smoke` | Import and 60-frame startup passed, exit 0 |
| `./check_relaunch.ps1 -Godot $Godot` | Separate write/verify processes passed; whole document identical, including active POI, loot, tools, equipment, recruits, shrine choice and unfinished upgrade |
| Rendered `res://tools/stage2_tour.tscn` with `--rendering-driver opengl3` | Seven PNGs, exit 0, empty stderr; inspected at 1280×720 on NVIDIA OpenGL |
| `git diff --check` | Passed |

Retained strict-runner logs: `D:\Ashes of Dominion\.local-tools\stage2-verification`.
Tour screenshots: `C:\Users\varga\.codex\visualizations\2026\11\05\01a1acff-242a-76f1-bcdb-a4bf42fc8422\stage2`.
The tour was launched hidden with `Start-Process`, private APPDATA/LOCALAPPDATA,
`--path "D:\Ashes of Dominion\current-repo\game" --rendering-driver opengl3 res://tools/stage2_tour.tscn -- --out=<screenshot directory>`.
A direct fixture-generation engine launch initially crashed before printing
startup output; the same command succeeded with isolated application-data paths.
The cause of that environment failure was not established. All reported checks
above used isolated application data.

**Not verified:** human play, other viewport sizes, Stage 2 export/release and
Godot 4.7.2. No Stage 3 dashboard, raids, armies or full generated-wilderness
checkpoint system was added. The new POI demo uses four resources; legacy iron
content remains compatible. Older evidence below is historical.

**Last verified: 2026-11-01** on branch `codex/ci-test-hardening`, with the official
**Godot 4.5.1-stable** Linux and Windows builds (headless). Project root: [`game/`](../game/).
**Last verified: 2026-11-01** on branch `feature/second-decision-reputation` (Phase 2A), with the
official **Godot 4.5.1-stable** Linux build (headless). Project root: [`game/`](../game/).

**Last verified: 2026-11-05** on branch `feature/stage1-village-foundation` (Stage 1: village
architecture and foundation), with the official **Godot 4.5.1-stable** Linux build (headless),
and additionally on **Godot 4.7.2-stable**. Project root: [`game/`](../game/).

Verification levels: **Planned** (design only) · **Implemented** (code present and inspected) ·
**Tested** (automated test executed and passing, command recorded) · **Runtime** (executed in
the engine, not asserted by a test) · **Manual** (a human played it) · **Unverified** (claimed
elsewhere, not inspected here).

## Evidence — Stage 1 village foundation, 2026-11-05 (`feature/stage1-village-foundation`)

Base `main` `eaadfdf`. Code commits `7885a9f` (settlement state, service, save schema 2) and
`9fbdc22` (village, visual registry, framework), plus tests and documentation on the same branch.
Full detail, interfaces and data formats: [`game/docs/handoffs/01_CLAUDE_TO_CODEX.md`](../game/docs/handoffs/01_CLAUDE_TO_CODEX.md).

| Check | Command (run from `game/`) | Observed |
| --- | --- | --- |
| Baseline before changes (`main`) | `./run_tests.sh <godot>`, `tools/verify.sh smoke`, `./check_relaunch.sh` | `=== 84 tests, 0 failed ===`; smoke and relaunch passed |
| Project imports (fresh clone, no `.godot/`) | `tools/verify.sh import <godot>` | `CHECK PASSED: import`, no error lines |
| Automated tests, Godot 4.5.1 | `./run_tests.sh <godot>` | `=== 138 tests, 0 failed ===`, `CHECK PASSED: tests` (the two expected recovery `WARNING` lines only) |
| Automated tests, Godot 4.7.2 | same, on a copy of the project | `=== 138 tests, 0 failed ===` |
| Boot smoke test | `tools/verify.sh smoke <godot>` | `CHECK PASSED: smoke` on both engines |
| Save → quit → relaunch → Continue, now including village state | `./check_relaunch.sh <godot>` | `RELAUNCH CHECK PASSED … 3 buildings` on both engines (hearth, a camp with a worker, an unfinished upgrade with a builder, time of day, player position) |
| Rendered tour | `xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/screenshot_tour.tscn` | 16 screens, no script errors; village screens inspected |
| Exported Linux build (official 4.5.1 templates) | `--export-release "Linux/X11"`, then the binary: `--headless --quit-after 60`; `relaunch_check` write + verify; screenshot tour under Xvfb | export clean; exit 0; relaunch passed; tour completed through the village |
| Hosted CI on PR #10, commit `301ae19` | [Godot reliability run 42064300085](https://github.com/IntermediatShaine/Ashes_of_Dominion/actions/runs/42064300085), [Build downloadable game run 42064300302](https://github.com/IntermediatShaine/Ashes_of_Dominion/actions/runs/42064300302) | Windows and Linux: 138 tests, 0 failed; relaunch check passed; harness self-test 20 cases per shell; exports built and the exported Windows game launched. (The PowerShell harness was not run locally — no `pwsh`.) |
| Manual play | — | **Not done** |

New tests (54): `unit/test_settlement_service.gd` (19), `persistence/test_settlement_persistence.gd` (5),
`unit/test_visual_registry.gd` (9), `unit/test_map_framework.gd` (8),
`integration/test_village_scene.gd` (13). The 84 earlier tests pass with one line changed in
`test_scenes.gd` (the old management screen is now reached through the router key
`settlement_legacy`). Each new group was run against deliberate breakage and failed as it should.

Stage 1 hand-over checks:

| # | Check | Status | Evidence |
| --- | --- | --- | --- |
| 1 | The Godot project opens | Runtime | import + smoke on a fresh clone; rendered tour; exported build |
| 2 | The player can move around the village | Tested | 8 directions, equal speed, facing; collision with buildings and border |
| 3 | All four buildings are interactable | Tested | walk up → interaction target → inspection card, as ruins and built; the four plots too |
| 4 | Building information matches the settlement state | Tested | card and view compared with `SettlementService.inspect_site` and the state |
| 5 | Leaving and returning preserves the village | Tested | gate → world map → back; a full expedition and back |
| 6 | Saving and loading restores village progress | Tested | in-process round trip, real schema-1 migration, two-process relaunch |
| 7 | Changing a visual registry entry changes appearance without gameplay changes | Tested | registry file swapped at runtime: texture changes; state, collision and interaction unchanged |

## Evidence — Phase 2A, 2026-11-01 (`feature/second-decision-reputation`)

| Check | Command (run from `game/`) | Observed |
| --- | --- | --- |
| Project imports | `godot --headless --path . --import` | exit 0, no errors |
| Automated tests | `./run_tests.sh <godot>` | `=== 78 tests, 0 failed ===`, no `SCRIPT ERROR` (two expected `WARNING` lines from the save-recovery tests) |
| Boot smoke test | `godot --headless --path . --quit-after 60` | exit 0 |
| Save → quit → relaunch → Continue | `./check_relaunch.sh <godot>` | `RELAUNCH CHECK PASSED` |
| Manual play | — | **Not done** |

New in Phase 2A: `unit/test_decisions.gd` (9) and `integration/test_crown_patrol.gd` (3) — selection
priority, reputation bands and threshold edges, every Crown-patrol choice, once-only resolution,
save/load of the choice, hostile reaction for a Hunted character, survivor regression. One existing
assertion in `test_core_loop.gd` was updated: a resolved decision now gives way to the next one
(the Crown patrol) instead of leaving the area without an NPC.

## Evidence — import session, 2026-11-01

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
| 1 | Begin in the starting village (Emberfall) | Tested + Runtime | **walkable village since Stage 1** — `test_village_scene.gd` |
| 2 | Working interface | Runtime + Tested | menus, settlement, map, HUD, pause, decision, death screens instantiate in tests |
| 3 | Strategic world map | Tested | 6 fixed landmarks + 6 seeded waypoints, Mist hides undiscovered nodes |
| 4 | Select destination, plan expedition | Tested | Dijkstra routes with an alternative; estimates vs. truth |
| 5 | Enter a procedurally generated area | Tested | seeded wilderness, 4 biomes, constraint repair; same seed → same area |
| 6 | Eight-direction movement | Tested | physics-driven movement test, diagonal normalised |
| 7 | Enemies + real-time combat | **Tested (new)** | `test_enemy_fsm.gd` (detect/chase/windup/strike/cooldown/escape/aggro/death), `test_combat_physics.gd` (hitbox sweep hits front once, not behind; cooldown; i-frames) |
| 8 | Collect resources | Tested | harvest once, haul, regrowth after 10 days |
| 9 | Return to settlement | Tested | returned / retreated / defeated all resolve exactly once |
| 10 | Construct a building | Tested | 9 definitions on village sites, upgrade levels, construction jobs, all-or-nothing cost, recruits move into housing |
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
| Settlement (stats, storage cap, daily production/food, morale) | Tested | governance policies are schema only |
| Settlement state v2: building level / condition / site, residents and worker assignments, construction jobs, persistent event log | Tested | `SettlementState`; `population` derived from residents; save schema 2 with migration from 1 |
| `SettlementService`: snapshots, inspections, validation, construction / upgrade / repair requests, workers, time, signals | Tested | the only way UI and village objects touch the settlement |
| Walkable village: hearth, shelter, workshop, stockpile, watchpost, four plots, gate, spawn | Tested + Runtime | data-driven layout; buildings start as ruins; Workshop has no mechanical effect yet |
| Visual registry (`Visuals`), `VisualSprite`, placeholder art, `village_theme.tres` | Tested + Runtime | village, protagonist and interface icons; expedition terrain/enemies still code-drawn (see `game/docs/ART_SWAP_GUIDE.md`) |
| Shared exploration framework: `MapDefinition`, `MapSceneBase`, `ExplorationKit`, `InteractableArea`, `MapTravelService`, `MapStateStore`, map registry | Tested | village built on it; `lumber_camp`, `ruined_watchtower`, `forgotten_shrine` registered as reserved ids, not built |
| Village Management interface (Overview / Buildings) | Tested + Runtime | minimal by design |
| In-game time of day | Tested | advances only by resting or expeditions; no real-time clock |
| Morality (character) vs faction reputation (universe) | Tested | distinct, event-id idempotent |
| Narrative decisions with persistent consequences (2) | Tested | "stranded survivor"; **"Crown patrol"** (Phase 2A) at the Ashen Crossroads / Aurel Border Fort: escort / trade / bribe / defy / fight, each with distinct morality, reputation, haul, recruit or health effects |
| Faction reactivity (Phase 2A) | Tested | the Crown patrol's prompt and options depend on Crown standing only: Friendly (≥ 20) unlocks the escort job, Distrusted/Hunted (≤ −20) refuses trade and exposes "fight"; morality never enters the gate |
| Two factions, territory, grace period / awareness bands | Tested | no faction AI, no raids, no faction–faction relation changes |
| Difficulty presets + custom, frozen per universe | Tested | 6 of 10 parameters are stored but unused |
| Main menu, new game, load, settings, map, HUD, pause, death | Runtime | code-built UI, placeholder `_draw()` visuals |
| Companions, armies, faction AI, raids, universe transfer rules, inventory/equipment, skills, audio, final pixel art, POI locations | Planned | not started |

## Known limitations

See [`game/docs/known_issues.md`](../game/docs/known_issues.md) (authoritative, kept with the
code). Headline items: no manual verification on Windows — the village has never been played by
a person; combat numbers unplayed; no save during an expedition; old generation versions are not
preserved; the Workshop and most worker slots have no effect yet. Mist route-preview waypoint disclosure
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
