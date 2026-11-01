# Implementation status

Verification levels (directive §24.2): **Implemented** (files exist) · **Static** (parses, imports) ·
**Auto-tested** (automated tests pass) · **Runtime** (executed in the engine) · **Manual** (a
human played it). Everything below was run on Godot 4.5.1-stable headless (tests) and under a
virtual display with software OpenGL (screenshot tour). **Nothing has been manually played on a
real Windows machine yet** — that is the first thing to do (see development_roadmap.md).

Last test run: `=== 51 tests, 0 failed ===`, no engine errors; smoke test `--quit-after 60` exit 0;
screenshot tour: 10 screens rendered, no errors.

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
| 11 | Encounter a basic enemy (detect / chase / attack) | Runtime (hound hit the player during the tour); FSM auto-tested only for strike/hit entry points |
| 12 | Attack and defeat it | Auto (take_hit path) — the live hitbox sweep is runtime-only |
| 13 | Collect a resource | Auto + runtime |
| 14 | Return to the settlement | Auto + runtime |
| 15 | Spend resources on an improvement | Auto + runtime |
| 16 | Save | Auto + runtime (autosave + button) |
| 17 | Exit | Runtime |
| 18 | Reload | Auto (load_slot / continue) |
| 19 | Continue with correct persisted state | Auto (core-loop + persistence tests) |

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
| Combat (player melee, damage rules, variance on combat stream, i-frames, knockback) | Auto (rules) + runtime | one moveset |
| Enemy AI (4 archetypes, idle/patrol/chase/windup/cooldown/dead) | Runtime | FSM transitions not unit-tested |
| Rewards (drops on rewards stream, XP, level-up, class unlock evaluation) | Auto-tested | |
| Resource nodes + harvest persistence + regrowth | Auto-tested | |
| Expedition lifecycle (active/completed/aborted/defeated, resolve once) | Auto-tested | |
| Death → resurrection → transition, pending recovery | Auto-tested | only `return_home` outcome |
| Settlement (stats, storage cap, 4 buildings, construction all-or-nothing, daily production/food) | Auto-tested | governance policies: schema only |
| World simulation tick (per day on expedition resolution) | Auto-tested | production + food + morale only |
| Morality (character) vs reputation (universe), ancestry attitudes, mixed-ancestry penalty | Auto-tested | |
| One narrative decision with persistent consequences | Auto + runtime | "stranded survivor": help / rob / ignore |
| Two factions, territory, relations | Auto-tested | no faction AI; relations never change yet |
| Grace period + awareness bands | Auto-tested | information only; no raids |
| Difficulty: 6 presets + custom, 4 functional parameters, validation, frozen per universe | Auto + runtime | 6 parameters flagged "not yet functional" in UI |
| Main menu / new game / load / settings / settlement / map / HUD / pause / decision / death | Runtime | placeholder visuals, code-built UI |
| Debug overlay (F3) | Runtime | |
| Test runner + 51 tests | Runtime | `run_tests.ps1` / `run_tests.sh` |

## Not started

Walkable settlement scene · companions · armies · faction AI / diplomacy · raids · universe
transfer rules · equipment / inventory · skills · class switching UI · audio · real pixel art ·
save during exploration · multiple settlements · dungeon-specific generation (the "crypt" biome
is a palette + density variant, not a dungeon layout).

## Acceptance scenarios (directive §32)

1 Fresh game ✔ auto · 2 Stable generation ✔ auto · 3 Variable wilderness ✔ auto · 4 Exploration ✔
auto+runtime · 5 Combat ✔ runtime (no script errors in tour) · 6 Resources ✔ auto · 7 Construction
✔ auto (invalid attempts consume nothing) · 8 Save/reload ✔ auto (exit+relaunch not yet exercised
by a human) · 9 Morality vs reputation ✔ auto · 10 Grace period ✔ auto · 11 Universe transfer ✖
rules undefined (character-survives-replacement is tested) · 12 Resurrection idempotency ✔ auto ·
13 Save recovery ✔ auto · 14 Content extensibility ✔ by construction (data-driven, referential checks).
