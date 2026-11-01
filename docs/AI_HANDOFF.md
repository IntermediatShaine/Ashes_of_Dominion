# AI collaboration handoff

## Project and source of truth

**Ashes of Dominion** is a Windows Godot 4 / GDScript game with a comprehensive specification in
`GAME_DESIGN.md`. This repository is the shared reference for Claude, ChatGPT and any other
coding agent: work is synchronized through commits here, not through conversation memory.

The Godot project lives in [`game/`](../game/) (open `game/project.godot`). Its own docs
(`game/docs/`, `game/README.md`) are the detailed technical reference and are kept with the code;
the files in this `docs/` folder are the cross-assistant summary.

## Current state (2026-11-01)

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
   bumps `SaveGame.SCHEMA_VERSION` and adds a `SaveMigrator` step plus a test.
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
declare expeditions atomic), generation versioning, a second decision with
faction-relation consequences.

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

## Handoff record template

- Date and commit/branch:
- Files changed:
- Working behavior:
- Test commands and observed results:
- Untested behavior or known limitations:
- Save/schema/determinism implications:
- Decisions requiring owner review:
- Next smallest actionable change:
