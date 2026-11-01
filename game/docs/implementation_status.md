# Implementation status

Verification levels (directive §24.2): **Implemented** (files exist) · **Static** (parses, imports) ·
**Auto-tested** (automated tests pass) · **Runtime** (executed in the engine) · **Manual** (a
human played it). Everything below was run on Godot 4.5.1-stable headless (tests) and under a
virtual display with software OpenGL (screenshot tour). **Nothing has been manually played on a
real Windows machine yet** — that is the first thing to do (see development_roadmap.md).

Last test run (2026-11-01, Godot 4.5.1-stable official, Linux headless, branch
`feature/second-decision-reputation`): `=== 78 tests, 0 failed ===`, no `SCRIPT ERROR`; smoke test
`--quit-after 60` exit 0; two-process relaunch check (`check_relaunch.sh`) PASSED. The screenshot tour (10 screens, no
errors) was last run on 2026-10-28 and was not repeated on 2026-11-01 (no display available).

## Checkpoint loop (directive §5.2)

| # | Step | Status |
| --- | --- | --- |
| 1 | Launch the application | Runtime (smoke test, tour) |
| 2 | Main menu | Runtime + auto (scene test) |
| 3 | Start a new game | Auto + runtime |
| 4 | Create / select a starting character | Auto + runtime (3 archetypes, name, difficulty, seed, slot) |
| 5 | Enter the starting settlement | Auto + runtime |
| 6 | Open the strategic world map | Auto + runtime |
| 7 | Select a destination | Auto + runtime |
| 8 | Plan an expedition (route A/B, estimates) | Auto + runtime |
| 9 | Enter an explorable area | Auto + runtime |
| 10 | Move the protagonist (8-dir, collision, camera) | Auto (physics test) + runtime (tour) |
| 11 | Encounter a basic enemy (detect / chase / attack) | Auto (`test_enemy_fsm.gd`: every FSM transition driven by real physics frames) + runtime |
| 12 | Attack and defeat it | Auto (`test_combat_physics.gd`: physics-driven hitbox sweep, once-per-swing, cooldown, i-frames) + runtime |
| 13 | Collect a resource | Auto + runtime |
| 14 | Return to the settlement | Auto + runtime |
| 15 | Spend resources on an improvement | Auto + runtime |
| 16 | Save | Auto + runtime (autosave + button) |
| 17 | Exit | Auto (relaunch check: the engine process exits after saving) |
| 18 | Reload | Auto (load_slot / continue; relaunch check uses the Continue path in a fresh process) |
| 19 | Continue with correct persisted state | Auto (core-loop + persistence tests; relaunch check compares the full state document field by field) |

## Systems

| System | Status | Notes |
| --- | --- | --- |
| StableHash / RngStream / RngRegistry (6 streams) | Auto-tested | FNV-1a 64 + splitmix finalizer; PCG32 via RandomNumberGenerator; state persisted |
| Character / Universe / Multiverse separation | Auto-tested | see game_state.md |
| Versioned saves, 3 slots, temp→verify→backup→promote, recovery (backup, orphaned temp), migration hook | Auto-tested | all 10 mandatory save tests exist and pass |
| State validation | Auto-tested | invalid saves rejected; invalid in-memory state refused on write |
| Strategic world graph (6 landmarks + 6 procedural waypoints, forced connectivity) | Auto-tested | same seed → same graph; landmarks never move |
| Route planning (Dijkstra, alternatives, estimates vs truth, Mist-aware) | Auto-tested | one alternative; magical shortcuts: edge `kind` reserved only |
| Wilderness generation (noise terrain, 4 biomes, resources, enemies, NPC, repair) | Auto-tested | 30 seeds × constraints; repair carves L-corridors |
| Mist of Discovery (undiscovered hidden; charted edges; toggle) | Auto + runtime | discovery persists; resets per universe by construction |
| 8-direction movement, collision, camera, facing | Auto + runtime | diagonal speed normalized |
| Combat (player melee, damage rules, variance on combat stream, i-frames, knockback) | Auto (rules + physics hitbox sweep) + runtime | one moveset |
| Enemy AI (4 archetypes, idle/patrol/chase/windup/cooldown/dead) | Auto-tested (all transitions, strike timing, dodge, aggro-on-hit, death-once, deterministic patrol off the persisted streams) + runtime | tuning values still guesses |
| Rewards (drops on rewards stream, XP, level-up, class unlock evaluation) | Auto-tested | |
| Resource nodes + harvest persistence + regrowth | Auto-tested | |
| Expedition lifecycle (active/completed/aborted/defeated, resolve once) | Auto-tested | |
| Death → resurrection → transition, pending recovery | Auto-tested | only `return_home` outcome |
| Settlement (stats, storage cap, 4 buildings, construction all-or-nothing, daily production/food) | Auto-tested | governance policies: schema only |
| World simulation tick (per day on expedition resolution) | Auto-tested | production + food + morale only |
| Morality (character) vs reputation (universe), ancestry attitudes, mixed-ancestry penalty | Auto-tested | |
| Narrative decisions with persistent consequences (2) | Auto-tested + runtime | "stranded survivor" (help / rob / ignore); "Crown patrol" at the Ashen Crossroads / Aurel Border Fort (escort / trade / bribe / defy / fight) — `test_decisions.gd`, `test_crown_patrol.gd` |
| Faction reactivity: reputation-gated prompts and options (`requires_reputation`, `prompts_by_reputation`) | Auto-tested + runtime | the Crown patrol reads Crown standing only (never morality): Friendly ≥ 20 unlocks the escort job, Distrusted ≤ −20 refuses trade and exposes "fight"; thresholds = `ReputationRules.label` bands |
| Per-area decision selection (`DecisionRules.select_for_area`: biome, optional landmarks, priority) | Auto-tested | one NPC per area; the next unresolved decision replaces a resolved one |
| Two factions, territory, relations | Auto-tested | no faction AI; faction–faction relations never change yet (player reputation does) |
| Grace period + awareness bands | Auto-tested | information only; no raids |
| Difficulty: 6 presets + custom, 4 functional parameters, validation, frozen per universe | Auto + runtime | 6 parameters flagged "not yet functional" in UI |
| Main menu / new game / load / settings / settlement / map / HUD / pause / decision / death | Runtime | placeholder visuals, code-built UI |
| Debug overlay (F3) | Runtime | |
| Test runner + 78 tests | Runtime | `run_tests.ps1` / `run_tests.sh` |
| Two-process save → quit → relaunch → Continue check | Runtime (passes) | `check_relaunch.ps1` / `check_relaunch.sh` → `tools/relaunch_check.tscn` |

## Not started

Walkable settlement scene · companions · armies · faction AI / diplomacy · raids · universe
transfer rules · equipment / inventory · skills · class switching UI · audio · real pixel art ·
save during exploration · multiple settlements · dungeon-specific generation (the "crypt" biome
is a palette + density variant, not a dungeon layout).

## Acceptance scenarios (directive §32)

1 Fresh game ✔ auto · 2 Stable generation ✔ auto · 3 Variable wilderness ✔ auto · 4 Exploration ✔
auto+runtime · 5 Combat ✔ runtime (no script errors in tour) · 6 Resources ✔ auto · 7 Construction
✔ auto (invalid attempts consume nothing) · 8 Save/reload ✔ auto incl. a real process restart (`check_relaunch`); not yet exercised by a human · 9 Morality vs reputation ✔ auto · 10 Grace period ✔ auto · 11 Universe transfer ✖
rules undefined (character-survives-replacement is tested) · 12 Resurrection idempotency ✔ auto ·
13 Save recovery ✔ auto · 14 Content extensibility ✔ by construction (data-driven, referential checks).
