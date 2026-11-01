# Architecture

## Layers

```
scenes/ + scripts/interface/, scripts/gameplay/exploration/   presentation & input (Godot nodes)
                    │  calls into
scripts/services/   Content (definitions)  Session (state owner + bound services)  Router (navigation)
                    │  owns / delegates to
scripts/gameplay/   pure rules: *Rules classes (static funcs), ExpeditionService, TransitionService,
                    WorldSimulation, UniverseFactory, CharacterFactory — no Node dependencies
scripts/generation/ WorldGraphGenerator, WildernessGenerator, RoutePlanner — pure, seed-driven
scripts/persistence/ SaveRepository / SaveValidator / SaveMigrator — JSON on disk
scripts/models/     state objects with to_dict / from_dict / validate
scripts/core/       StableHash, RngStream, RngRegistry, IdFactory, OpResult, DictUtil
data/*.json         content definitions (never runtime instances)
```

Rules never import scene scripts. Scene scripts never serialize anything; they call services and
redraw from state. Tests exercise everything below the presentation layer without a scene, and the
scene layer with `tests/integration/test_scenes.gd`.

## Autoloads (only three)

| Autoload | Responsibility |
| --- | --- |
| `Content` | Loads every `data/*.json` once, strips `_comment`, validates cross-references, exposes `table()`, `get_def()`, `ids()`, `balance()`. Read-only. |
| `Session` | Owns the loaded `SaveGame`; binds `WorldGraph` (derived), `RngRegistry`, `ExpeditionService`, `TransitionService`; `new_game / load_slot / continue_latest / save_game / construct_building`. Emits `state_changed`. |
| `Router` | `go(key)` scene changes by key, app settings (`user://settings.json`), F3 debug overlay, `navigation_hook` for tests. |

## Scene structure

Every screen is one `.tscn` with a root node + script; the script builds its controls in `_ready`
through `UiKit`. (Hand-written `.tscn` trees for complex UI are error-prone without the editor;
this keeps the scenes editable later.)

- `bootstrap` → checks `Content.load_errors` → `main_menu`
- `main_menu` → `new_game` / `load_game` / `settings`
- `settlement` (Control) ↔ `world_map` (Node2D + CanvasLayer panel) → `exploration`
- `exploration` (Node2D): `TerrainRenderer` (draw + StaticBody2D), `Entities` (y-sorted:
  player, enemies, resource nodes, survivor NPC, exit zone), `ExplorationHud` (CanvasLayer)

## Data flow of the core loop

1. `NewGame` screen → `Session.new_game(options, slot)` → `CharacterFactory` + `UniverseFactory`
   (+ fresh `MultiverseState`) → `SaveRepository.write` → `settlement`.
2. `WorldMap` → `ExpeditionService.plan_routes(dest)` (RoutePlanner on the derived WorldGraph) →
   `RoutePlanner.estimate` for display → `ExpeditionService.start(dest, route)`.
3. `Exploration` → `ExpeditionService.build_area()` → `WildernessGenerator` (seeded by
   universe seed + destination id + generation version, plus the universe's harvest history) →
   entities spawned from the map. Gameplay events call back:
   `collect_resource`, `on_enemy_defeated` (rewards stream), `DecisionRules.resolve`.
4. Exit / retreat → `ExpeditionService.finish(reason)` → `resolve()` once: haul → settlement
   (storage cap), discovery, `WorldSimulation.advance_days`, recruits, threat, history.
   Defeat → `TransitionService.on_protagonist_defeated()` (see game_state.md).
5. `Session.save_game()` (autosave) → `settlement` shows the summary.

## Physics layers

1 world · 2 player body · 3 enemy body · 4 (reserved player hurtbox) · 5 enemy hurtbox · 6 interactable.
Player hitbox is an Area2D masking layer 5; interaction range masks layer 6; enemies strike by
distance check against the player (no hurtbox needed yet).

## World layers (generation)

| Layer | Where | Persisted? |
| --- | --- | --- |
| Narrative landmark layer | `data/regions/landmarks.json` fixed positions | definitions only |
| Strategic graph (waypoints + edges) | `WorldGraphGenerator(world_seed, version)` | no — derived |
| Terrain / navigation / resource / encounter / event layers of an area | `WildernessGenerator(world_seed, area_id, version, …)` | no — derived |
| Discovery layer | `UniverseState.discovered_landmark_ids`, `revealed_edge_ids` | yes |
| Mutable world state | `UniverseState.world_modifications[area_id].harvested`, `decision_log`, settlements, factions | yes |

Changing a biome palette or adding a waypoint rule invalidates nothing persisted; changing the
noise or placement algorithm must bump `UniverseState.CURRENT_GENERATION_VERSION`.

## Important dependencies

- `Session` → everything; nothing depends on `Session` except scene scripts and `Router`'s overlay.
- `ExpeditionService` needs `SaveGame`, `WorldGraph`, `RngRegistry`, and a content provider
  (duck-typed so tests can pass `Content`).
- `TransitionService` needs `ExpeditionService` (defeat resolves the expedition).
- `RngStream` wraps `RandomNumberGenerator`; internal calls must use `self.` (see technical_decisions).
