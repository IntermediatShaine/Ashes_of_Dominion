# Handoff 01 — Claude → Codex

**Stage 1 of 3: Village architecture and foundation.** Written 2026-11-05.
Branch `feature/stage1-village-foundation`, based on `main` at `eaadfdf`.
Pull request: https://github.com/IntermediatShaine/Ashes_of_Dominion/pull/10

**Status: READY FOR CODEX**, on automated evidence (below). Nothing here has been played by a
person; that is the main open item and it is listed under *Unresolved*.

Stage 2 (Codex) implements the gameplay mechanics on top of this; Stage 3 (Gemini) the management
interface and visual customization. This document is everything Stage 2 needs to know that is not
already obvious from the code.

---

## 1. What exists now

- **A walkable village.** The home scene (router key `settlement`) is a three-quarter top-down
  map: player spawn point, Village Hearth, Shelter, Workshop, Stockpile, Watchpost, four free
  building plots, a gate to the world map, scenery, a closed tree-line border. Eight-direction
  movement and collision are the expedition scene's own player controller.
- **One authoritative settlement state** per universe, with building levels and condition,
  residents, worker assignments, construction jobs and a persistent event log; the clock and
  threat level stay universe-wide and are exposed alongside it.
- **`SettlementService`** — read-only snapshots and inspections, validation, requests, worker
  assignment, time, signals. UI and village objects go through it and hold no settlement values.
- **A visual registry** — every image is reached by a stable visual id; see `docs/ART_SWAP_GUIDE.md`.
- **A shared exploration framework** the village is built on and POIs can be built on, plus
  travel with return destinations and persistent per-map state.
- **Three reserved POI ids**: `lumber_camp`, `ruined_watchtower`, `forgotten_shrine`.
- **A minimal management interface**: Overview and Buildings, opened at the hearth or with **V**.
- **Save schema 2** with a migration from schema 1.

How the village starts: all five named buildings are **ruins** (nothing is built, exactly as
before this stage — the starting numbers in `balance.json` are untouched). Rebuilding them is the
first thing the player does. With the starting stock (6 wood, 2 stone) the hearth (4 wood) or the
stockpile (6 wood, 2 stone) can be afforded; everything else needs an expedition first.

## 2. Files

New unless marked *(changed)*. Paths are relative to `game/`.

**State and rules**

| File | Role |
| --- | --- |
| `scripts/models/settlement_state.gd` *(changed)* | the settlement's changing values; `population` is now derived from `residents` |
| `scripts/models/universe_state.gd` *(changed)* | + `time_of_day_minutes`, `location` |
| `scripts/models/map_location.gd` | the `location` record: current map, entry, return stack, resume position |
| `scripts/models/save_game.gd` *(changed)* | `SCHEMA_VERSION = 2` |
| `scripts/persistence/save_migrator.gd` *(changed)* | `_migrate_1_to_2` |
| `scripts/gameplay/settlement/building_rules.gd` | levels, effects by level, condition, upgrade/repair validation |
| `scripts/gameplay/settlement/site_rules.gd` | which building may stand on which site; site state |
| `scripts/gameplay/settlement/construction_job_rules.gd` | build / upgrade / repair requests, jobs, daily work, cancel |
| `scripts/gameplay/settlement/population_rules.gd` | resident names, worker assignment |
| `scripts/gameplay/settlement/settlement_rules.gd` *(changed)* | effects read through `BuildingRules`; daily tick also runs jobs |
| `scripts/gameplay/settlement/construction_rules.gd` *(changed)* | instances carry level/condition/site; pending jobs count toward `max_count` |
| `scripts/gameplay/world/universe_factory.gd`, `expedition_service.gd`, `world_simulation.gd` *(changed)* | founders are residents; expeditions record where to come back to; tick gets the day |

**Services**

| File | Role |
| --- | --- |
| `scripts/services/settlement_service.gd` | `SettlementService` — `Session.settlement_service` |
| `scripts/services/map_travel_service.gd` | `MapTravelService` — `Session.travel` |
| `scripts/services/game_session.gd` *(changed)* | binds both; `saving` signal; `construct_building` delegates to the service |
| `scripts/services/content_db.gd` *(changed)* | tables `residents`, `village_layouts`, `maps`; validation of levels, layouts, maps |
| `scripts/services/scene_router.gd` *(changed)* | `settlement` → village scene; `settlement_legacy` → the old screen |

**Framework and village**

| File | Role |
| --- | --- |
| `scripts/gameplay/exploration/framework/map_definition.gd` | parsed static layout + geometry (`MapDefinition`) |
| `…/framework/map_scene_base.gd` | base scene for hand-authored maps (`MapSceneBase`) |
| `…/framework/exploration_kit.gd` | player spawn, entity layer, static bodies (`ExplorationKit`) |
| `…/framework/interactable_area.gd` | `[E]`-interactable base (`InteractableArea`) |
| `…/framework/map_ground_renderer.gd` | tiled ground from visual ids |
| `…/framework/map_registry.gd` | helpers over `data/maps/maps.json` (`MapRegistry`) |
| `…/framework/map_state_store.gd` | persistent per-map flags (`MapStateStore`) |
| `scripts/gameplay/village/village_controller.gd` | the village scene (`extends MapSceneBase`) |
| `scripts/gameplay/village/village_site_view.gd` | one building site: sprite, collision, interaction |
| `scripts/gameplay/village/village_visuals.gd` | site state → visual id (`VillageVisuals`) |
| `scenes/village/village.tscn` | scene root |
| `scripts/gameplay/exploration/player_controller.gd` *(changed)* | registry sprite, `combat_enabled`, `BODY_RADIUS`/`BODY_OFFSET` |
| `scripts/gameplay/exploration/exploration_controller.gd` *(changed)* | spawns the player through `ExplorationKit` |
| `scripts/gameplay/exploration/enemy_controller.gd`, `resource_node.gd`, `survivor_npc.gd` *(changed)* | use a registry sprite if one is registered, else unchanged |

**Visuals and interface**

| File | Role |
| --- | --- |
| `data/visuals/visual_registry.json` | visual id → image |
| `scripts/visuals/VisualResolver.gd` | autoload `Visuals` |
| `scripts/visuals/visual_sprite.gd` | `VisualSprite` |
| `assets/placeholders/**` | 40 placeholder PNGs (+ `.import`) |
| `assets/pixellab/README.md` | where final art goes |
| `ui/themes/village_theme.tres` | interface theme |
| `scripts/interface/village_hud.gd` | status bar, inspection card, management panel, pause menu |
| `scripts/interface/expedition_summary.gd` | return-summary text shared by village and old screen |
| `docs/ART_SWAP_GUIDE.md` | how to swap art and restyle the interface |

**Data**

| File | Role |
| --- | --- |
| `data/buildings.json` *(changed)* | + five village buildings, upgrade levels, build times, worker slots, placement |
| `data/balance.json` *(changed)* | + job, repair, event-log, condition-band and time settings |
| `data/village/village_layouts.json` | the village map: size, ground, entries, exit, sites, props |
| `data/maps/maps.json` | map registry incl. the three reserved POI ids |
| `data/residents.json` | resident name pool |

**Tests and tools**

| File | Role |
| --- | --- |
| `tests/unit/test_settlement_service.gd` (19) | state, rules, service, signals |
| `tests/persistence/test_settlement_persistence.gd` (5) | round trip, migration, validation |
| `tests/unit/test_visual_registry.gd` (9) | registry, fallback, live swap |
| `tests/unit/test_map_framework.gd` (8) | layout, walkability, registry, travel, map state |
| `tests/integration/test_village_scene.gd` (13) | the scene as played |
| `tests/fixtures/save_schema1_main_eaadfdf.json` | a real schema-1 save written by `main` before this stage |
| `tests/integration/test_scenes.gd` *(changed, one line)* | old screen now instantiated via `settlement_legacy` |
| `tools/relaunch_check.gd` *(changed)* | also covers village state across a process restart |
| `tools/screenshot_tour.gd` *(changed)* | village screens |
| `tools/build_village_theme.gd` | regenerates the theme (overwrites it) |
| `tools/placeholder_art/generate_placeholders.py` | regenerates the placeholder PNGs (Pillow) |

Housekeeping: the four `.gd.uid` files Godot generates for scripts merged earlier
(`diagnostic_log.gd`, `telemetry.gd` and their two tests) were missing from the repository and
are added here, so an import no longer leaves untracked files behind.

Not touched: `tools/verify.*`, `tools/test_harness.ps1`, `tools/install_ci_godot.ps1`,
`run_tests.*`, `check_relaunch.*`, `.github/workflows/*`, `tests/test_runner.gd`. The harness
still finds the line it patches in `relaunch_check.gd`.

## 3. Data formats

### 3.1 Settlement state (save schema 2)

`universe.settlements[<id>]`, written by `SettlementState.to_dict()`:

```jsonc
{
  "settlement_id": "stl_emberfall", "display_name": "Emberfall", "landmark_id": "emberfall",
  "base_population_capacity": 8, "base_storage_capacity": 40,
  "loyalty": 50, "morale": 40, "productivity": 50, "freedom": 60, "discipline": 30, "military_strength": 0,
  "resources": {"wood": 6, "stone": 2, "food": 8, "iron": 0},
  "pending_recruits": 0, "policies": {},
  "buildings": [
    {"instance_id": "bld_000001", "definition_id": "shelter", "built_day": 1,
     "level": 2, "condition": 100, "site_id": "site_shelter"}
  ],
  "residents": [
    {"resident_id": "res_000001", "name": "Aldric", "origin": "founder", "joined_day": 1,
     "assigned_to": ""}            // "" idle | building instance id | job id
  ],
  "construction_jobs": [
    {"job_id": "job_000001", "kind": "upgrade",        // build | upgrade | repair
     "definition_id": "shelter", "site_id": "site_shelter", "instance_id": "bld_000001",
     "target_level": 3, "work_required": 2, "work_done": 0, "started_day": 3,
     "cost": {"wood": 22, "stone": 12, "iron": 2}}
  ],
  "events": [
    {"event_id": "sev_000001", "day": 1, "minute": 0, "type": "building_constructed",
     "data": {"instance_id": "bld_000001", "definition_id": "shelter", "site_id": "site_shelter", "level": 1}}
  ],
  "resident_counter": 6, "job_counter": 1, "event_counter": 1
}
```

Rules worth knowing:

- **`population` is not stored.** It is `residents.size()`. `SettlementState.population` is still
  a readable/assignable property for older callers; assigning it adds or removes residents.
- A **building instance exists only once built**; `level` ≥ 1. A ruin is a reserved site with no
  instance. A building whose `condition` is 0 is *destroyed*: it keeps its level and site but has
  no effects until repaired.
- A **build job reserves its `instance_id`** when created, so finishing needs no counter.
- Building instance ids come from `universe.id_counters["bld"]` (as before); resident, job and
  event ids from the settlement's own counters.
- `events` is capped at `balance.settlement.event_log_limit` (200); ids keep counting.
- Event types written today: `building_constructed`, `building_upgraded`, `building_repaired`,
  `building_damaged`, `job_started`, `job_completed`, `job_cancelled`, `worker_assigned`,
  `worker_unassigned`, `resident_joined`.
- `SettlementState.validate()` rejects: duplicate ids, two buildings or two jobs on one site, a
  build job on an occupied site, level < 1, condition outside 0–100, finished or negative job
  progress, unknown job kind, a resident assigned to something that does not exist.

Universe additions:

```jsonc
"time_of_day_minutes": 480,                       // 0..1439; with current_day this is the clock
"location": {"map_id": "village_emberfall", "entry_id": "spawn", "return_stack": [],
             "position": [512, 640]}              // position optional: exact resume spot
```

**In-game time and threat level are not copied into the settlement.** They are universe-wide
(`current_day` + `time_of_day_minutes`, `threat_state`) and the service returns them in every
snapshot. Duplicating them would have created exactly the competing copies this stage forbids.

### 3.2 Building definitions (`data/buildings.json`)

Level 1 is the definition's own `cost` / `build_days` / `requires` / `effects`. Each entry of
`upgrades` is the next level; **its `effects` replace the previous level's** (they are totals, not
deltas).

```jsonc
"watchpost": {
  "name": "Watchpost", "category": "defense", "description": "…",
  "cost": {"wood": 10, "stone": 4}, "build_days": 1,     // 0 or absent = built at once
  "max_count": 1, "requires": [],
  "placement": "reserved",                               // only on its reserved site; absent = any plot
  "effects": {"military_strength": 2, "worker_slots": 1},
  "upgrades": [
    {"cost": {"wood": 16, "stone": 10, "iron": 2}, "days": 2,
     "effects": {"military_strength": 5, "worker_slots": 2}}
  ]
}
```

Effect keys understood by the rules: `population_capacity`, `storage_capacity`,
`military_strength` (summed over buildings), `production` (`{resource: per day}`),
`worker_slots`, `production_per_worker` (`{resource: per day per assigned resident}`).
Anything else is carried but ignored.

The four pre-existing definitions keep their ids, costs and level-1 effects. `shelter` gained two
upgrade levels; `woodcutters_camp` gained 2 worker slots at +1 wood each (its base 2 wood/day is
unchanged, so unstaffed it behaves as before).

### 3.3 Village layout (`data/village/village_layouts.json`)

Keyed by settlement id. Units are cells (`cell_size` px each); `entries` and prop `at` may be
fractional.

```jsonc
"stl_emberfall": {
  "map_id": "village_emberfall", "name": "Emberfall",
  "cell_size": 32, "width": 44, "height": 30, "border_cells": 1,
  "ground": {"base": "terrain.village.grass",
             "patches": [{"visual": "terrain.village.path", "rect": [21, 16, 2, 13]}]},
  "entries": {"spawn": [22.0, 18.5], "hearth": [22.0, 16.0], "gate": [22.0, 25.5]},
  "default_entry": "spawn",
  "exits": [{"id": "gate", "rect": [21, 27, 2, 2], "to": "world_map", "return_entry": "gate",
             "prompt": "…", "visual": "marker.village_gate"}],
  "sites": [
    {"id": "site_hearth", "kind": "core", "reserved_for": "village_hearth",
     "cell": [21, 13], "footprint": [2, 2], "role": "hearth"},
    {"id": "plot_1", "kind": "plot", "cell": [14, 4], "footprint": [3, 2]}
  ],
  "border": {"visual": "prop.tree.pine", "spacing": 1.5},
  "props": [{"visual": "prop.tree.dead", "at": [5.5, 7.0], "solid": [0.6, 0.4]}]
}
```

- `kind: "core"` — reserved for one definition, shown as its ruin until built. `kind: "plot"` —
  takes any definition without `placement: "reserved"`.
- A site's **footprint is its collision box and the base of its interaction area**. Artwork size
  is irrelevant.
- An exit's `to` is `"world_map"`, `"return"` (pop the return destination) or a map id.
- `role: "hearth"` makes interacting with the site open Village Management instead of the
  inspection card.
- `ContentDb` validates all of it at startup (bounds, overlaps, entries inside solids, unknown
  buildings, every reserved building having exactly one site).

### 3.4 Map registry (`data/maps/maps.json`)

```jsonc
"village_emberfall": {"kind": "village", "name": "Emberfall", "status": "implemented",
                      "scene": "settlement", "settlement_id": "stl_emberfall", "default_entry": "spawn",
                      "arrival_entries": {"expedition_return": "gate", "resurrection": "hearth"}},
"lumber_camp":       {"kind": "poi", "name": "Lumber Camp", "status": "reserved", "scene": "",
                      "default_entry": "arrival", "description": "…"}
```

`status: "reserved"` maps exist as ids only; `MapTravelService.enter` refuses them. Generated
expedition areas are not listed: their map id is `wilderness:<landmark_id>`.

### 3.5 Visual registry

See `docs/ART_SWAP_GUIDE.md` for the entry format, the id list and the fallback rules.

## 4. Interfaces

### 4.1 `SettlementService` (`Session.settlement_service`)

Stateless front for the home settlement; constructing another one on the same save gives the same
answers (`SettlementService.new(save, Content)` — that is how the tests use it without `Session`).

**Read — every result is a fresh deep copy**

| Method | Returns |
| --- | --- |
| `snapshot()` | `{settlement_id, name, map_id, time, resources, storage_capacity, population{count, capacity, pending_recruits, idle, residents[]}, stats{…}, production, threat{awareness, label, text, grace_remaining}, sites[], unplaced_buildings[], jobs[], events[]}` |
| `inspect_site(site_id)` | one site (shape below); `{}` if unknown |
| `inspect_building(instance_id)` | same shape, by instance (works for a building without a site) |
| `available_improvements(site_id)` | the `improvements` list of the site |
| `time_view()` | `{day, minute_of_day, clock}` |
| `site_ids()` | layout order |

A site inspection:

```
{site_id, kind, role, state, definition_id, name, category, description,
 instance_id, level, max_level, condition, condition_label, functional, built_day,
 effects, worker_slots, workers:[{resident_id, name}],
 job: {} | {job_id, kind, target_level, work_done, work_required, work_per_day, builders:[…], …},
 improvements: [{action, definition_id, name, description, target_level,
                 cost, days, effects, blocked_by:[String], available}]}
```

`state` is one of `ruin` (reserved site, nothing built), `empty` (free plot), `construction`
(build job running), `standing`, `destroyed` (condition 0). `action` is `build`, `upgrade` or
`repair`. `blocked_by` is the same list the matching `validate_*` returns.

**Validate — reasons a request would be refused; empty = allowed**

`validate_construction(site_id, definition_id)`, `validate_upgrade(instance_id)`,
`validate_repair(instance_id)`, `validate_worker_assignment(resident_id, target_id)`.

**Change — each returns `OpResult`; a refused request changes nothing**

| Method | Notes |
| --- | --- |
| `request_construction(site_id, definition_id)` | value `{completed, instance, job}` |
| `request_construction_anywhere(definition_id)` | reserved site if free, else first free plot |
| `request_upgrade(instance_id)`, `request_repair(instance_id)` | same value shape |
| `request_improvement(site_id, action, definition_id = "")` | runs one entry of `improvements` |
| `cancel_job(job_id)` | value `{job, refund}` |
| `assign_worker(resident_id, target_id)` | target = building instance id or job id; moves the resident |
| `unassign_worker(resident_id)`, `assign_idle_worker(target_id)`, `unassign_one_worker(target_id)` | |
| `advance_time(minutes)` → Dictionary | `{minutes, days_passed, sim, recruits}`; each midnight runs `WorldSimulation.advance_days(1)` |
| `advance_to_minute(m)`, `rest_until_dawn()` | |
| `damage_building(instance_id, amount, cause = "")` | amount < 0 mends; value = new condition |
| `add_resources(amounts)` → Dictionary | `{added, lost}`, respects the storage cap |
| `normalize()` → Dictionary | names unnamed residents, places unplaced buildings, drops impossible assignments; idempotent; `Session` runs it after binding a save |

**Signals — emitted after the change is applied**

| Signal | When |
| --- | --- |
| `settlement_changed(reason)` | any change. Reasons: `construction`, `upgrade`, `repair`, `job_cancelled`, `workers`, `time`, `damage`, `resources`, `normalized`. A view that shows a whole snapshot needs only this. |
| `resources_changed(resources)` | |
| `building_changed(site_id, instance_id)` | `instance_id` is `""` while a first build is in progress |
| `job_changed(job_id, status)` | `started`, `progressed`, `completed`, `cancelled` |
| `population_changed(population)` | |
| `worker_assignment_changed(resident_id, target_id)` | |
| `time_advanced(day, minute_of_day)` | |
| `event_recorded(event)` | once per entry appended to the event log |

`Session` relays `settlement_changed` as its own `state_changed`.

Days that pass during an **expedition** go through `ExpeditionService.resolve` →
`WorldSimulation`, not through the service, so no service signals fire for them. Nothing is
listening at that moment (the village scene is not open) and the scene rebuilds from state when
it opens; the expedition summary lists work finished while away.

### 4.2 `MapTravelService` (`Session.travel`) and friends

| Call | Effect |
| --- | --- |
| `current_map_id()`, `current_entry_id()`, `home_map_id()`, `describe(map_id)` | read |
| `can_enter(map_id)` | `OpResult`; fails for unknown or `reserved` maps |
| `enter(map_id, entry_id = "", remember_return = true, return_entry_id = "")` | pushes the current map as a return destination; value `{map_id, entry_id, scene}` |
| `leave()` | pops it (home village if the stack is empty); same value |
| `arrive_home(purpose = "default")` | outright arrival, clears the stack |
| `set_entry(entry_id)`, `remember_position(Vector2)` | |
| `arrival_position(map_id, entries, default_entry, is_free = Callable())` | where a scene should put the player |
| signal `location_changed(map_id, entry_id)` | |

The service only writes `UniverseState.location`; changing scene stays `Router.go(value["scene"])`.
`ExpeditionService.start` / `resolve` update the same record directly (rules layer), so an
expedition leaves through the gate and returns to it, and a defeat arrives at the hearth.

`MapStateStore` — `get_flag / set_flag / clear_flag / is_done / mark_done(u, map_id, key)` —
stores in `UniverseState.world_modifications[map_id]`, the record expedition areas already use
for harvested nodes (their key is the landmark id). It is saved with the universe.

`Session.saving` fires just before a save is written; `MapSceneBase` uses it to record the
player's position.

### 4.3 Building a POI on the framework

1. Give the map a layout in the same format as §3.3 (sites optional) and load it into a
   `MapDefinition`.
2. In `data/maps/maps.json` set the POI's `status` to `implemented` and `scene` to a router key;
   add that key to `Router.SCENES`.
3. Write a scene script that `extends MapSceneBase` and overrides `_load_map_definition()`;
   add content in `_build_content()` (children of `entities`, positioned at their feet), a HUD in
   `_build_hud()`, `_combat_enabled()` if there is fighting.
4. Interactables: `InteractableArea.new()`, set `prompt`, `set_rect`/`set_circle`, connect
   `interacted`.
5. Getting there: `Session.travel.enter("lumber_camp", "", true, "<entry to come back to>")` then
   `Router.go(result.value["scene"])`. An exit in the layout with `"to": "return"` brings the
   player back.
6. Persistent changes: `MapStateStore`.

`village_controller.gd` is the worked example (≈200 lines over the base).

### 4.4 Controls

WASD / arrows move, **E** interact, **V** Village Management (new action `village_management`),
**M** world map, **Esc** closes a panel or opens the pause menu, F3 debug overlay. Attack input is
ignored in the village.

## 5. Implementation choices worth knowing

1. **Ruins are sites without an instance, not level-0 instances.** It keeps `buildings` meaning
   "what has been built", so every existing rule, test and the threat formula
   (`awareness_per_building × buildings.size()`) behave exactly as before.
2. **`population` derived from `residents`.** One source of truth; old callers still work.
3. **Names and sites are assigned by `normalize()`, not by the migration.** Both depend on content
   files; a migration that read them would change meaning whenever they changed.
4. **Resident names use `StableHash`, not an RNG stream.** No runtime stream is drawn, so world
   determinism and the relaunch check are unaffected.
5. **The four old buildings stay instant; the new ones take time.** `Session.construct_building`
   and everything that called it keep working. Jobs are real for the new buildings and all
   upgrades.
6. **Legacy screen kept under `settlement_legacy`**, unreachable in play. It still works (same
   state, same services). Delete it once nothing it shows is missing from the village interface.
7. **Opening any panel pauses the tree**, as the expedition HUD does.
8. **"Rest until dawn" exists** so construction can be seen finishing without an expedition. It
   costs only the day's food. Treat it as scaffolding to be gated or replaced.
9. **`generation_version` not bumped** — no generator was touched.
10. **Engine.** `project.godot` still declares 4.5 and CI pins 4.5.1; the suite also passes
    unmodified on the official 4.7.2-stable build. Moving the pin is a decision for the owner
    and whoever owns CI.

## 6. Verified

All commands run from `game/`, official headless builds, isolated application data, on Linux.

| # | Check | How | Result |
| --- | --- | --- | --- |
| — | Baseline before any change (`main` `eaadfdf`) | `run_tests.sh`, `verify.sh smoke`, `check_relaunch.sh` | 84 tests, 0 failed; smoke and relaunch passed |
| 1 | The project opens | `verify.sh import` and `verify.sh smoke` on a fresh clone of the branch (no `.godot/`) | passed, no error lines |
| 2 | The player can move around the village | `test_village_scene.gd::test_eight_direction_movement`, `::test_collision_with_buildings_and_borders` | 8 directions, equal speed, correct facing; blocked by buildings and the border; an empty plot is walkable until built on |
| 3 | All four buildings are interactable | `::test_all_four_buildings_are_interactable_and_show_the_settlement_state`, `::test_four_building_sites_are_interactable_and_can_be_built_on` | player walks up to Shelter, Workshop, Stockpile, Watchpost; each becomes the interaction target and opens its card — as ruins and again once built. The four free plots likewise, and each can be built on from its card |
| 4 | Building information matches the settlement state | same test + `test_settlement_service.gd::test_inspection_matches_state_for_every_building` | name, level, max level, condition, effects, improvements equal the state and definitions; enabled buttons equal the available improvements |
| 5 | Leaving and returning preserves the village | `::test_leaving_and_returning_preserves_the_village` | gate → world map → back: snapshot identical; full expedition: same buildings on the same sites, the upgrade in progress finished, player back at the gate |
| 6 | Saving and loading restores village progress | `::test_saving_and_loading_restores_village_progress`, `test_settlement_persistence.gd` (5), `check_relaunch.sh` | upgrades, stock, layout, population, workers, unfinished job, clock and player position restored; whole document identical across a real process restart |
| 7 | Changing a registry entry changes appearance without gameplay changes | `::test_registry_swap_changes_appearance_and_nothing_else`, `test_visual_registry.gd::test_changing_an_entry_changes_a_live_sprite` | new texture (different size) shown; state, inspection, collision box, interaction area unchanged |
| + | Schema-1 saves | `test_settlement_persistence.gd::test_schema_1_save_migrates`, `::test_migrated_save_loads_from_disk_and_is_rewritten_as_schema_2` | real `main` save migrates, nothing lost, deterministic |
| + | Full suite | `run_tests.sh` | **138 tests, 0 failed** on 4.5.1-stable; **138, 0 failed** on 4.7.2-stable |
| + | Rendered | `xvfb-run … res://tools/screenshot_tour.tscn` (software GL) | 16 screens, no script errors; village, inspection card, management panel and built-up village looked at by Claude |
| + | Exported build | Linux x86_64 export with the official 4.5.1 templates (the CI procedure), then run: `--headless --quit-after 60`, `relaunch_check` write + verify, and the screenshot tour under Xvfb | export clean; smoke exit 0; relaunch check passed; tour completed through the village with registry art, theme and data loaded from the `.pck` |

The 84 pre-existing tests pass with **one line changed** in one of them (`test_scenes.gd`: the old
management screen is instantiated through `settlement_legacy` instead of `settlement`).

The new tests were checked against deliberate breakage (level not loaded, cost not deducted, views
not refreshed, sites never solid, sprites not following the registry): each made tests fail.

Hosted CI on pull request #10, commit `301ae19` (the last commit before this note was added):

| Workflow | Result |
| --- | --- |
| Godot reliability — `windows-2022` ([run 42064300085](https://github.com/IntermediatShaine/Ashes_of_Dominion/actions/runs/42064300085)) | success: 138 tests, 0 failed; relaunch check passed; harness self-test 20 cases (PowerShell) |
| Godot reliability — `ubuntu-24.04` (same run) | success: 138 tests, 0 failed; smoke; relaunch check passed; harness self-test 20 cases each for Bash and PowerShell |
| Build downloadable game ([run 42064300302](https://github.com/IntermediatShaine/Ashes_of_Dominion/actions/runs/42064300302)) | success: Windows and Linux exports built; the exported Windows game launched |

The PowerShell harness self-test was not run locally (no `pwsh` here); the hosted runs cover it.

## 7. Unresolved

**Not verified**

- **No human has played this.** Movement feel, the size and readability of the village, whether
  interaction ranges feel right, the interface at other window sizes — all unseen by a person.
  The rendered screenshots were taken at 1280×720 with a software renderer.
- **Windows** is covered only by hosted CI (tests, relaunch check, launch of the exported game
  as far as the main menu).
- **The exported Windows build** was not run here; the Linux export was (table above). CI launches
  the Windows build as far as the main menu.

**Known gaps and rough edges**

- **The Workshop does nothing yet** beyond having work places. Its purpose is Stage 2's.
- **Workers only matter in two places**: the Woodcutter's Camp (+1 wood each) and construction
  jobs (+1 work a day each, at most 2). Watchpost and Workshop slots have no effect.
- **Condition never changes on its own** (`condition_decay_per_day` is 0) and nothing damages
  buildings; `damage_building` exists for raids/events to call.
- **No clock in real time.** Time moves only through `advance_time` (resting) and expeditions.
- **Four plots** cannot hold every plot building the definitions allow (3 more shelters, 2 camps,
  2 storehouses, 1 palisade). The fifth request fails with "No free building site".
- **Buildings without a site** can exist only if a migrated save has more buildings than sites, or
  code calls `ConstructionRules.build` directly. They work and are listed in the Buildings tab but
  are not in the village; nothing lets the player place them.
- **Camera limits** assume the window is not wider than the map (1408 px at 1:1): a very wide
  window shows beyond the border. Same pre-existing limitation as expedition areas.
- **Cancelling a job refunds everything** (`job_cancel_refund_ratio` 1.0).
- **Residents are names and a work place** — no needs, traits or individual simulation.
- **Expedition terrain and the expedition/menu interface are not on the registry/theme**; see the
  art guide's *Limits*.
- **Loading a save made mid-expedition** behaves as before (lands at home with the expedition
  still active). Not addressed; Phase 2C territory.
- **Telemetry** has no events for village actions except `building_built` (the allow-list was
  left alone).
- `docs/TESTING_AND_CI.md`, `docs/CODEX_HANDOFF.md` and `game/docs/implementation_status.md`
  still describe earlier test counts.

## 8. Continuing

Before anything else, from `game/`:

```bash
godot --headless --path . --import
./run_tests.sh <godot>          # expect 138 tests, 0 failed, no SCRIPT ERROR
godot --headless --path . --quit-after 60
./check_relaunch.sh <godot>
```

Ground rules that keep the foundation intact:

- **Change settlement values only through `SettlementService`** (or the rule classes it calls).
  If a mechanic needs something the service lacks, add a method there, with a signal and a test.
- **Views never store settlement values.** Refresh from `snapshot()` / `inspect_site()` on
  `settlement_changed`.
- **No image paths outside the registry** (`test_no_script_or_scene_names_an_image_file` enforces
  it). New objects get a visual id and a registry entry.
- **Collision and interaction geometry from data**, never from a texture.
- **No global RNG.** If a mechanic needs chance, draw from a named `RngStream` (`events` is
  reserved for settlement/world events) so it is saved and deterministic.
- **Any change to what is saved**: bump `SaveGame.SCHEMA_VERSION`, add `_migrate_2_to_3`, add a
  fixture and a test. Keep `tests/fixtures/save_schema1_main_eaadfdf.json`.
- New definitions/levels need matching `building.<id>.level_<n>` registry entries.

Natural starting points for Stage 2, smallest first:

1. Give the Workshop and the Watchpost a purpose (their worker slots are already there).
2. Decide what rest costs, or replace it with a running clock that calls `advance_time`.
3. Turn on wear and repair (`condition_decay_per_day`) or drive damage from threat.
4. Implement the first POI on `MapSceneBase` (§4.3) — `lumber_camp` is the obvious one.
5. Let the player choose what to do with buildings that have no site.

**Do not start Stage 3 work here**: the management interface is deliberately minimal and the
theme/registry are the hooks Gemini will use.
