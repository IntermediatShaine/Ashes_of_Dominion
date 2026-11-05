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

## Autoloads

| Autoload | Responsibility |
| --- | --- |
| `Content` | Loads every `data/*.json` once, strips `_comment`, validates cross-references (including building levels, the village layout and the map registry), exposes `table()`, `get_def()`, `ids()`, `balance()`. Read-only. |
| `Visuals` | The visual registry (`data/visuals/visual_registry.json`): visual id → texture/region/frames/offset. `resolve()`, `make_sprite()`, `apply()`, `reload()`. The only code that touches image paths. See `ART_SWAP_GUIDE.md`. |
| `Session` | Owns the loaded `SaveGame`; binds `WorldGraph` (derived), `RngRegistry`, `ExpeditionService`, `TransitionService`, `SettlementService` (`settlement_service`) and `MapTravelService` (`travel`); `new_game / load_slot / continue_latest / save_game`. Emits `state_changed`, `saving`. |
| `Telemetry` | Opt-in local diagnostics (see `../../docs/DIAGNOSTIC_TELEMETRY.md`). |
| `Router` | `go(key)` scene changes by key, app settings (`user://settings.json`), F3 debug overlay, `navigation_hook` for tests. |

## Scene structure

Every screen is one `.tscn` with a root node + script; the script builds its controls in `_ready`
through `UiKit`. (Hand-written `.tscn` trees for complex UI are error-prone without the editor;
this keeps the scenes editable later.)

- `bootstrap` → checks `Content.load_errors` → `main_menu`
- `main_menu` → `new_game` / `load_game` / `settings`
- `settlement` — the walkable village (`scenes/village/village.tscn`, Node2D) ↔ `world_map`
  (Node2D + CanvasLayer panel) → `exploration`
- `exploration` (Node2D): `TerrainRenderer` (draw + StaticBody2D), `Entities` (y-sorted:
  player, enemies, resource nodes, survivor NPC, exit zone), `ExplorationHud` (CanvasLayer)
- `settlement_legacy` — the management screen that was "home" before the village
  (`scenes/settlement/settlement.tscn`). Not reachable in play; kept until the village interface
  shows everything it did.

## Explorable maps: one framework, three kinds of place

```
                       ExplorationKit                 PlayerController
                 (entity layer, player spawn,     (8-direction movement, camera,
                  static bodies, physics layers)   interaction range, combat)
                              │                              │
        ┌─────────────────────┴───────────┬──────────────────┘
        │                                 │
 exploration_controller.gd         MapSceneBase  ← MapDefinition (static layout JSON)
 generated expedition area         hand-authored map: ground, border, props, exits,
 (WildernessMap from the seed)     entries, arrival position, position on save
                                          │
                                 village_controller.gd      (later: POI scenes)
                                 sites + VillageHud, wired to SettlementService
```

- **Interaction protocol** (all three): an `Area2D` on physics layer 6 in the group
  `interactables` with `interaction_prompt()` and `interact(player)`. `InteractableArea` packages
  it; the older expedition objects implement it by hand.
- **Where the player is**: `UniverseState.location` (`MapLocation`): current map id, the entry
  to appear at, a stack of return destinations, and optionally the exact spot. Written by
  `MapTravelService` and by `ExpeditionService` (start → `wilderness:<landmark>`, resolve → home
  at the gate, or at the hearth after a defeat).
- **What exists**: `data/maps/maps.json` (`MapRegistry`). Expedition areas are not listed; their
  id is `wilderness:<landmark_id>`. `lumber_camp`, `ruined_watchtower`, `forgotten_shrine` are
  registered with status `reserved`.
- **What the player changed on a map**: `UniverseState.world_modifications[map_id]`
  (`MapStateStore` for flags and once-only events; expedition areas keep `harvested` there).

## The village

Static: `data/village/village_layouts.json` (sites, entries, exit, ground, props) and
`data/buildings.json`. Changing: `SettlementState`. Between them: `SettlementService`.

```
 village_site_view.gd ─┐                                   ┌─ BuildingRules / SiteRules
 village_hud.gd ───────┼─ refresh(snapshot / inspect_site) │  ConstructionJobRules
                       │                                   │  PopulationRules / SettlementRules
 village_controller.gd ┴──► SettlementService ─────────────┴──► SettlementState (+ universe clock, threat)
        ▲   request_improvement / assign_worker / advance_time        │
        └──────────────── settlement_changed(reason) ◄────────────────┘
```

Views hold no settlement values: they are rebuilt from a fresh snapshot on every
`settlement_changed`. The HUD only emits what the player asked for; the controller calls the
service. A site's collision box and interaction area are its footprint from the layout; what it
looks like is a visual id chosen by `VillageVisuals` from its state and resolved by `Visuals`.

## Data flow of the core loop

1. `NewGame` screen → `Session.new_game(options, slot)` → `CharacterFactory` + `UniverseFactory`
   (+ fresh `MultiverseState`) → `SaveRepository.write` → `settlement`.
2. `WorldMap` → `ExpeditionService.plan_routes(dest)` (RoutePlanner on the derived WorldGraph) →
   `RoutePlanner.estimate` for display → `ExpeditionService.start(dest, route)`.
3. `Exploration` → `ExpeditionService.build_area()` → `WildernessGenerator` (seeded by
   universe seed + destination id + generation version, plus the universe's harvest history) →
   entities spawned from the map. Gameplay events call back:
   `collect_resource`, `on_enemy_defeated` (rewards stream), `DecisionRules.resolve`.
   The area's single decision NPC is chosen by `DecisionRules.select_for_area` (biome, optional
   landmark list, `priority`); the HUD builds the dialog from `prompt_for` / `visible_options` /
   `blocking_reason`, which read faction reputation (universe scope) and never morality.
4. Exit / retreat → `ExpeditionService.finish(reason)` → `resolve()` once: haul → settlement
   (storage cap), discovery, `WorldSimulation.advance_days`, recruits, threat, history.
   Defeat → `TransitionService.on_protagonist_defeated()` (see game_state.md).
5. `Session.save_game()` (autosave) → `settlement` (the village) shows the summary; the player
   stands at the gate, or by the hearth after a defeat.
6. In the village: interact with a site → inspection card → `SettlementService.request_*` →
   cost paid, building raised at once or a construction job started → jobs advance one unit of
   work per in-game day (resting at the hearth, or the days an expedition takes).

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

- `Session` → everything; nothing depends on `Session` except scene scripts, `ExplorationKit`
  and `Router`'s overlay.
- `SettlementService` and `MapTravelService` need a `SaveGame` and a content provider only, so
  tests build them without `Session`.
- `ExpeditionService` needs `SaveGame`, `WorldGraph`, `RngRegistry`, and a content provider
  (duck-typed so tests can pass `Content`).
- `TransitionService` needs `ExpeditionService` (defeat resolves the expedition).
- `RngStream` wraps `RandomNumberGenerator`; internal calls must use `self.` (see technical_decisions).
