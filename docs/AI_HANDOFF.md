# AI collaboration handoff

## Latest handoff — Stage 2, 2026-11-05

Codex branch `codex/stage2-village-gameplay` builds on Claude's Stage 1 at
`0e86cfc`. Open **`D:\Ashes of Dominion\current-repo\game\project.godot`**
on this workstation; sibling project copies were not modified.
Read [`game/docs/handoffs/02_CODEX_TO_GEMINI.md`](../game/docs/handoffs/02_CODEX_TO_GEMINI.md)
for mechanics, API extensions, schema-3 data, visuals and Gemini's presentation tasks.

Verified on Windows Godot 4.5.1: baseline 138/0, final **157/0**, import/startup,
extended two-process relaunch and seven rendered screenshots. Exact commands
and limitations are in `IMPLEMENTATION_STATUS.md`. No human playtest or Stage 2
export was performed. Stage 3 remains Gemini's assignment.

Important changes: actual new games have zero residents; regression staffing
fixtures explicitly retain six. New village upgrade costs use salvage, while
legacy iron and old job costs remain valid. Workshop tools/equipment are in
universe state, shrine morality/lore in character state and shrine consequence
in map flags. POI rewards/guard defeats are once-only saved events. No generator
or named RNG behavior changed; original resurrection bookkeeping is reused.

Next: review this branch, then have Gemini connect the final management UI to
the existing service snapshots/requests. Test human input feel and readability
before treating placeholder combat balance as final. Historical entries follow.

## Project and source of truth

**Ashes of Dominion** is a Windows Godot 4 / GDScript game with a comprehensive specification in
`GAME_DESIGN.md`. This repository is the shared reference for Claude, ChatGPT and any other
coding agent: work is synchronized through commits here, not through conversation memory.

The Godot project lives in [`game/`](../game/) (open `game/project.godot`). Its own docs
(`game/docs/`, `game/README.md`) are the detailed technical reference and are kept with the code;
the files in this `docs/` folder are the cross-assistant summary.

## Current state (2026-11-05) — Stage 1 of the Claude → Codex → Gemini sequence

Branch `feature/stage1-village-foundation` (base `main` `eaadfdf`): the home scene is a
**walkable village** on a shared exploration framework, backed by one authoritative settlement
state behind `SettlementService`, with every image reached through a **visual registry**. Save
schema is **2** (migration from 1 tested on a real save). `138 tests, 0 failed` on Godot 4.5.1
and on 4.7.2; smoke, two-process relaunch and an exported Linux build checked. **Not played by a
person.**

**The hand-over document for the next assistant is
[`game/docs/handoffs/01_CLAUDE_TO_CODEX.md`](../game/docs/handoffs/01_CLAUDE_TO_CODEX.md)** —
files, data formats, the service API and signals, choices, evidence, open problems, how to
continue. Art swapping: [`game/docs/ART_SWAP_GUIDE.md`](../game/docs/ART_SWAP_GUIDE.md).

What follows below is the state as recorded on 2026-11-01, kept for history; where it says the
settlement is a management screen or that a walkable village is not started, Stage 1 supersedes it.

## State recorded 2026-11-01

- **Engine:** verified on Godot **4.5.1-stable (official)**; `project.godot` declares feature
  `4.5`. The "4.7.2" mentioned in the design document does not exist. 4.4 will probably open it;
  older than 4.3 will not.
- **What works (automated evidence):** the complete expedition loop — new game (3 archetypes,
  difficulty, seed, Mist toggle) → Emberfall settlement screen → strategic map → route choice →
  seeded wilderness → 8-direction movement → enemy FSM + melee hitbox combat → resource harvest →
  survivor decision (morality vs reputation) → return / retreat / defeat (resurrection) →
  construction → autosave → quit → relaunch → Continue. See `IMPLEMENTATION_STATUS.md` for the
  exact commands and results (62 tests, smoke test, two-process relaunch check).
- **What is placeholder:** all visuals are code-drawn shapes; the settlement is a management
  screen, not a walkable scene; UI is built in code via `UiKit`.
- **What is not started:** walkable village, companions, armies, faction AI/raids, universe
  transfer rules, inventory/equipment, skills, audio, pixel art.

## Save architecture (implemented and tested — verified in code, not just discussed)

Three scopes in one JSON document per slot (`SaveGame`): `CharacterState` (identity, ancestry,
XP/level, attributes, class unlocks, morality + log, reserved lore/flags), `UniverseState`
(seed, generation version, frozen difficulty, day, discovery, world modifications, settlement,
factions, threat, expeditions, decisions, protagonist health, id counters, six named RNG stream
states) and `MultiverseState` (transfer counters, resolved resurrection outcomes keyed by death
id and written **before** the outcome is applied, one explicit pending transition record,
completed transition ids). Write protocol: temp → read-back validate → rotate backup → promote;
load order primary → `.bak` → orphaned `.tmp`; `Session.load_slot` finishes an interrupted
transition exactly once. Details: `game/docs/game_state.md`, `game/docs/technical_decisions.md`.

## Previous-work recovery record

- The code committed in `game/` is the project that was at `D:\Ashes of Dominion` on the owner's
  PC (created in the 2026-10-28 Claude session that rebuilt the foundation from the design
  document + directive). It was staged file-by-file and verified in the engine before commit.
- The earlier "Milestone 1" code and the "v0.3 addendum" referenced in older chats were never
  available as files; `game/docs/technical_decisions.md` §1 records the decision to rebuild.
- **Not reconciled:** a Codex-owned project ("AshesOfDominion-unified-foundation" v0.3.1-m1) and
  Claude's later M2 / M2b / M2.1 packages (walkable village, world engine checkpoint, backend-first
  corrections) exist outside this repository. They could not be inspected on 2026-11-01. The
  owner must decide whether they supersede, merge into, or are superseded by `game/`. Until then,
  `game/` is the only implementation in the repository and the only one with recorded test results.

## Working rules for the next assistant

1. Read `AGENTS.md`, this file, `IMPLEMENTATION_STATUS.md`, then `game/docs/*.md`.
2. Run the checks before and after changing anything (from `game/`):
   `godot --headless --path . --import`, `./run_tests.sh <godot>` (or `run_tests.ps1`),
   `godot --headless --path . --quit-after 60`, `./check_relaunch.sh <godot>`.
3. Keep rules out of scene scripts (`scripts/gameplay/*` is pure; scenes call services).
4. Any generator change bumps `UniverseState.CURRENT_GENERATION_VERSION`; any save layout change
   bumps `SaveGame.SCHEMA_VERSION` and adds a `SaveMigrator` step plus a test (schema is 2 since
   Stage 1; `_migrate_1_to_2` and its fixture are the pattern to follow).
   Settlement values change only through `SettlementService`; images are named only in
   `game/data/visuals/visual_registry.json`.
5. Never draw from `randf()`/global RNG in gameplay; use the named `RngStream`s.
6. Godot 4.5 pitfalls recorded in `game/docs/known_issues.md` (no `:=` from Variant; `self.`
   inside `RngStream`; lambdas capture locals by value — use a Dictionary for counters in tests).
7. Update `IMPLEMENTATION_STATUS.md`, this file and `CHANGELOG.md` with evidence, then commit on
   a branch and open a PR.

## Next smallest actionable change

**Manual verification on the owner's Windows machine** (nothing has been played by a human):
open `game/project.godot` in Godot 4.5.1, F5, play the loop once (new game → build → map →
expedition → fight → gather → survivor → return → build → save → quit → relaunch → Continue),
run `run_tests.ps1` and `check_relaunch.ps1`, record findings in `game/docs/known_issues.md` and
tune `game/data/balance.json` / `enemies.json` if controls or combat feel wrong.

After that, in order (from `game/docs/development_roadmap.md`): save during exploration (or
declare expeditions atomic), generation versioning, hostile patrols as combat encounters and a
decision that changes faction–faction relations (Phase 2A delivered the second decision and
reputation-gated reactions).

## Handoff record — Stage 1 (village architecture and foundation), 2026-11-05

- **Date and commit/branch:** 2026-11-05, `feature/stage1-village-foundation`, base `eaadfdf`,
  pull request #10 (hosted CI green on Windows and Linux at `301ae19`).
- **Files changed:** see the file tables in `game/docs/handoffs/01_CLAUDE_TO_CODEX.md` §2. Not
  touched: the test/relaunch wrappers, the harness, the CI workflows, `tests/test_runner.gd`.
- **Working behavior:** walkable village (hearth, shelter, workshop, stockpile, watchpost, four
  plots, gate); inspection cards; construction, upgrade and repair with jobs that advance per
  in-game day; worker assignment; Village Management (Overview / Buildings) at the hearth or
  with V; visual registry and theme; travel with return destinations; three reserved POI ids.
- **Test commands and observed results:** `IMPLEMENTATION_STATUS.md`, Stage 1 evidence table.
- **Untested behavior or known limitations:** never played by a person; Windows only through CI;
  Workshop and most worker slots have no effect; no real-time clock; full list in the handoff
  §7 and `game/docs/known_issues.md`.
- **Save/schema/determinism implications:** `SCHEMA_VERSION` 1 → 2 with `_migrate_1_to_2`
  (tested on a real `main` save). `generation_version` unchanged (no generator touched). No
  runtime RNG stream is drawn by anything new; resident names come from `StableHash`.
- **Decisions requiring owner review:** `DECISIONS.md` 2026-11-05 entries — the village starts as
  ruins; free "rest until dawn"; the old management screen kept but unreachable; engine pin.
- **Next smallest actionable change:** play it once on Windows. Then Stage 2 (Codex) starts from
  the handoff's §8.

## Claude handoff — Phase 2A (second decision + faction reactivity), 2026-11-01

- Branch `feature/second-decision-reputation`, based on main `aec6ce9` (after Codex PR #4, which is
  untouched).
- `game/data/decisions.json`: new `crown_patrol` (marches; `appears_at_landmarks` crossroads + border
  fort; `priority` 20 after the survivor's 10); five options with distinct consequences.
- `DecisionRules`: `select_for_area`, `reputation_gate_passes`, `prompt_for`, `visible_options`,
  `blocking_reason` (pack then reputation), `health` effect (floor 1). `ExpeditionService.build_area`
  uses the selector; `ExplorationHud.show_decision` takes the universe; `ExplorationController` mirrors
  a dialogue wound onto the live body; `SurvivorNpc` takes colour/prompt from the definition;
  `ContentDb` validates decision references.
- Tests: `unit/test_decisions.gd` (9), `integration/test_crown_patrol.gd` (3); `test_core_loop.gd`
  assertion updated (resolved decision → next decision, not "no NPC"). Full suite 78/0; smoke and
  relaunch checks pass. Human play still unverified.
- Next recommended: hostile patrols as real combat (spawn riders from a decision outcome on the
  encounter stream), then a decision that moves faction–faction relations / territory.

## Codex handoff — issue #3, 2026-11-01

- Branch: `codex/issue-3-mist-preview`, based on main `1a2d4ed`.
- `world_map_screen.gd`: selected uncharted geometry is replaced by one direct dashed indication;
  charted edges remain solid. Planning, estimates, seeds and save format are unchanged.
- New `test_mist_preview.gd` captures actual renderer commands: four tests, two reproduced
  failures before the fix; full suite after fix **66 tests, 0 failed** on official Windows
  Godot 4.5.1. Import, boot and two-process relaunch passed. Human play remains unverified.
- Exact commands and environment failures/recovery: `docs/CODEX_ISSUE_3_AUDIT.md`.
- Located the v0.3.1-m1 ZIP in Downloads and inspected source without importing it. It has
  incompatible save/state contracts. Comparison and bounded reuse proposals are in the audit;
  no older source or saves were copied into `game/`. Earlier non-recovery notes above are historical.
- Next: owner visual review of Mist preview and gameplay; consider isolated test-runner improvements
  separately from Claude's feature work.

## Handoff record — 2026-11-01

- **Branch / commit:** `feature/import-godot-project` (SHA in the PR).
- **Files changed:** `game/` imported (project.godot, 56 scripts, 8 scenes, 12 JSON tables,
  tests, tools, docs); new `game/tests/integration/test_enemy_fsm.gd`,
  `game/tests/integration/test_combat_physics.gd`, `game/tools/relaunch_check.gd/.tscn`,
  `game/check_relaunch.sh/.ps1`; repo docs updated.
- **Working behavior:** full expedition loop, automated (see status).
- **Test commands and results:** see `IMPLEMENTATION_STATUS.md` evidence table.
- **Untested:** rendered tour not re-run (no display); nothing played manually on Windows.
- **Save/schema/determinism implications:** none (no schema or generator changes).
- **Decisions requiring owner review:** `DECISIONS.md` 2026-11-01 entries (engine version,
  `game/` as project root, unreconciled Codex/M2 line of work).

## Phase 2B — test harness and CI (2026-11-01)

- Branch `codex/ci-test-hardening`, based on `aec6ce9` (PR #4 merged).
- Hardened four wrappers through native shared PowerShell/Bash runners: import failures,
  engine diagnostics and missing positive completion evidence now fail; each invocation uses
  isolated application data. Optional retained logs use `AOD_TEST_LOG_DIR`.
- Added checksum-pinned Godot 4.5.1 Linux/Windows CI and a 20-case-per-shell self-test with real
  failure injection in disposable project copies. Local PowerShell: 20/20 harness cases;
  66 game tests; focused Mist 4/4; import, smoke and relaunch pass.
- See `docs/TESTING_AND_CI.md` for exact commands, fixture corrections and hosted status.
- Hosted engineering revision `76d89d3`: [run 41331300938](https://github.com/IntermediatShaine/Ashes_of_Dominion/actions/runs/41331300938)
  passed Linux and Windows: 66 game tests each; 20 PowerShell harness cases each plus 20 Bash
  cases on Linux; import, startup, relaunch and log upload successful.
- Gameplay, content, RNG, save schemas and scenes untouched; Claude's narrative/faction work
  remains independent. Human play and branch-protection configuration remain owner actions.

## Handoff record template

- Date and commit/branch:
- Files changed:
- Working behavior:
- Test commands and observed results:
- Untested behavior or known limitations:
- Save/schema/determinism implications:
- Decisions requiring owner review:
- Next smallest actionable change:
