# Handoff 02 — Codex → Gemini

Stage 2 of 3: village gameplay and three POIs. 2026-11-05.
Branch: `codex/stage2-village-gameplay`, based on Claude's
`feature/stage1-village-foundation` at `0e86cfce231ffc746bd1db3995c5f5276db694a5`.
The authoritative project is `current-repo/game/` on this workstation, not the
older sibling copies at `D:\Ashes of Dominion\game` or the drive-root project.

Stage 3 has **not** been implemented. The interface remains temporary. Start
from this branch, preserve the services below and replace presentation only.

## Implemented mechanics

- New games start with the Survivor class and **zero residents/companions**.
  The protagonist is not a worker in the resident roster. Personal gathering,
  baseline construction work and crafting require no hired worker. Existing
  saves retain their residents, resources and jobs.
- Shelter, Workshop, Stockpile and Watchpost reuse Claude's level, condition,
  job, cost, repair and upgrade rules. All reach at least level 2. Initial
  ruins are sites without instances; rebuilding uses `build`, while damaged
  existing instances use `repair`. No level-0 instances were introduced.
- Workshop: L1 produces 1 wood/day, plus 1 salvage/day per assigned worker;
  L2 produces 2 wood/day, plus 2 salvage/day per worker. Personal basic tools
  add 1 wood/day while a Workshop functions. Daily output respects productivity
  and per-resource storage capacity; residents consume food through the old tick.
- Crafting recipes live in `data/recipes.json`. Basic tools need Workshop L1,
  3 wood, 2 salvage and 120 minutes. A reinforced blade needs L2, 2 wood,
  4 salvage and 180 minutes; it grants +3 melee attack. No resident is required.
  Inputs, output and elapsed time commit synchronously; repeat requests for
  an owned tool/equipped blade fail without spending or advancing time.
- Watchpost L1: 2 defense plus 2 per worker (one slot). L2: 5 defense plus 3
  per worker (two slots). Defense reduces awareness gained after grace, with
  a floor of one awareness per later trip. This is preparedness, **not raids**.
- The demo POIs gather wood, stone, food and salvage. **Iron remains supported
  for legacy wilderness content, decisions and saves**; it is not silently
  converted. New village upper-level costs use salvage. Outstanding old job
  costs/refunds remain exactly as saved.

## POIs and their persistent rewards

All three use `MapSceneBase`, `MapDefinition`, `ExplorationKit`,
`InteractableArea`, the existing player/enemy controllers and registry sprites.
Layouts, gathering objects, encounters and rewards are in `data/pois.json`.
All are reachable through named buttons on the existing world map. These are
local known destinations, separate from the generated landmark route graph;
the Mist route renderer and generators are unchanged.

| Map id | Contents |
| --- | --- |
| `lumber_camp` | Two 18-wood stacks, 10 food, one rescued resident and survivor testimony |
| `ruined_watchtower` | Two marauders, 18 stone, 10 salvage, a guarded cache with 8 stone/4 salvage, +2 attack tower blade and orders implicating the village's destruction |
| `forgotten_shrine` | Ancient inscription, 2 salvage, and a mutually exclusive choice: honor (+10 morality, 4 food, +2 village defense ward) or plunder (-10 morality, 8 salvage, desecration) |

Gathering nodes regrow after ten **in-game** days. Residents, defeated guards,
cache rewards and decisions never regrow. A shrine outcome changes morality
and the saved world consequence, independently of faction reputation. Rewards
enter the expedition pack; returning delivers it through the existing capacity
rules. Defeat loses the pack under the pre-existing balance setting. Rescue,
lore, morality and equipped gear persist; this stage adds no companion resurrection.

Real-time combat reuses eight-direction movement, melee sweeps, enemy attacks,
health, hit tint and death signals. POI level-ups refresh the live body's stats.
The cache never replaces a stronger crafted blade. Death calls the existing
`TransitionService`; its death ids/outcomes/completed transitions remain authoritative.
Returned, retreated and defeated trips all count, as before. Difficulty's grace
setting remains unchanged (about five trips); testing pins five explicitly.

## Interface contract for Gemini

Read `01_CLAUDE_TO_CODEX.md` for all preserved settlement, map and visual APIs.
No existing method was removed. Views must read fresh snapshots on
`settlement_changed` and send requests to the service, not edit state dictionaries.

| API | Stage 2 use |
| --- | --- |
| `Session.settlement_service.snapshot()` | Existing fields plus `crafting` recipe definitions, `equipment` id and `tools` ids; `production` includes personal tools; defense includes staffing and shrine ward |
| `inspect_site(site_id)` / `available_improvements(site_id)` | Building condition, level, effects, workers, jobs, costs, durations, requirements and blocking reasons |
| `request_improvement(site, action, definition_id = "")` | Rebuild/repair/upgrade; existing authoritative job and cost path |
| `assign_worker`, `unassign_worker`, `assign_idle_worker` | Existing limits, job builders and building worker slots |
| `craft(recipe_id) -> OpResult` | Validates ownership, workshop and resources, then applies output and time. Emits `settlement_changed("crafting")` and resource/time signals |
| `defense_strength() -> int` | Actual defense including the saved shrine ward |
| `add_resources(amounts) -> Dictionary` | Same `{added,lost}` success shape; invalid unknown/negative/fractional amounts return `{added:{},lost:{},error}` without mutation |
| `ResourceTransaction.spend(state,cost,resource_defs)` | Validated all-or-nothing primitive for rule code; UI should use service actions |
| `PoiRules.start(Session.expeditions,map_id)` | Creates a standard expedition and sets map location; call only from home, save, then `Router.go("poi")` |
| `PoiRules.available(expeditions,key)` | Whether an object is unresolved or regrown |
| `PoiRules.claim(expeditions,key,choice = "")` | Validate guards/choice/once marker, then apply pack reward, recruitment, lore, choice or equipment atomically |
| `PoiRules.enemy_defeated(expeditions,key)` | Once-only guard XP/drops through the existing expedition reward service |
| `Session.resume_scene_key()` | Main-menu Continue/Load resumes an active POI instead of returning home with a stranded trip |

Controllers autosave POI departure, successful interactions, defeated guards and
return/death. The POI HUD also offers Save. Village improvement/crafting/rest
actions autosave through the existing controller. If writing fails the interface
reports `SAVE FAILED`; in-memory action state remains available for retry.

`SettlementRules.daily_production` accepts an optional third bonus dictionary;
`tick_day` an optional fifth production-bonus dictionary. Existing callers retain
their behavior. `ThreatRules.on_expedition_resolved` accepts optional `defense=0`.

## Saved data and migration

Save schema **3**. `_migrate_2_to_3` adds neutral defaults; 1→2 remains unchanged.
The frozen schema-2 fixture is the original Stage 1 1→2 migration's output on
the real schema-1 fixture, generated once in Godot, not regenerated by tests.

- `universe.protagonist_condition`: existing `health`, plus `tools: [String]`,
  `equipment: String`, `equipment_attack: int`. These remain universe-bound.
  The loader now preserves the typed dictionary rather than converting every
  value to an integer. New fields have structural validation.
- `universe.world_modifications[map_id].once[object_or_enemy_id] = day`:
  reward and defeat markers. A renewable node compares its last harvest day.
- `world_modifications.forgotten_shrine.flags`: `decision`, `consequence`,
  `defense_bonus`. These and the morality event share one saved document.
- `character.persistent_lore`: testimony, tower orders and shrine inscription.
  Morality uses the existing idempotent event log keyed by universe/map/object.
- `universe.expeditions`: ordinary records, with a POI map id as destination.
  POI completion skips generated-graph discovery and uses existing delivery,
  calendar, threat, history, home-arrival and resurrection resolution.
- Existing `location` stores the POI id, return stack and exact saved position.
  RNG states continue through the same `Session.save_game()` path.

No generator, generation version, RNG algorithm or filesystem save protocol changed.
No new parallel settlement, combat, population or persistence service was created.

## Visual identifiers and presentation work

All image paths remain exclusively in `data/visuals/visual_registry.json`.
Added exact ids: `resource.node.wood`, `.stone`, `.food`, `.salvage`,
`icon.resource.salvage`, `actor.npc.stranded_survivor`, `actor.enemy.marauder`,
`poi.tower.cache`, `poi.shrine.inscription`, `poi.shrine.altar`, and
`terrain.poi.lumber_camp`, `.ruined_watchtower`, `.forgotten_shrine`.
They inherit existing placeholders, with tints where useful. Building level,
construction badge and ruin appearances remain Claude's registry mapping.

Gemini should improve POI object readability, show the pack and rewards with
icons, surface lore/choice consequences in a journal, make recipe ownership and
blocking reasons visible, and use snapshot defense/production rather than
recalculating them. Keep interaction/collision geometry independent of textures.
The Workshop inspection has temporary Craft buttons; the world map has three
temporary departure buttons. This is **not** a final dashboard design.

## Verification

Engine observed: `4.5.1.stable.official.f62fdbde1`, Windows. Baseline on Claude's
unchanged branch: **138 tests, 0 failed**. Final suite: **157 tests, 0 failed**,
including **19** Stage 2 acceptance tests. Final commands/results are recorded in
the repository-level `docs/IMPLEMENTATION_STATUS.md`.

New `tests/integration/test_stage2_gameplay.gd` covers solo start, resource
validation/capacity, four buildings through destroy/repair/upgrade with mid-job
reload, crafting/production/worker limits, gathered rewards and rescue reload,
both shrine outcomes, guarded equipment, grace and staffed defense, the complete
camp→rebuild→tower→save loop, actual enemy damage handling, death return,
mid-POI position/health/pack reload, shrine interaction pause, schema migration,
visual/content references, real E-input gathering and live level-up/equipment.
Two injected-write-failure cases verify departure/return save retries without
creating another expedition or resolving/delivering rewards twice.
Existing Stage 1 suites remain present. Their staffing fixtures now explicitly
create the six residents those historical scenarios require; actual new-game
acceptance checks verify zero residents instead.

`check_relaunch.ps1` now tests a real two-process restart with four resolved
expeditions, rescue, tower equipment, crafted tools, shrine consequence, an
unfinished staffed upgrade and an active camp trip with an already-claimed reward.
It compares the whole saved document and rejects duplicate collection after restart.

`tools/stage2_tour.tscn` renders seven screens. Run with an OpenGL context:
`godot --path . --rendering-driver opengl3 res://tools/stage2_tour.tscn -- --out=<directory>`.
The tour uses private saves and stocks resources only for its final Workshop
presentation fixture. Screenshots were inspected at 1280×720; this is scripted
render review, **not human playtesting**.

## Remaining limitations and risks

- Human playtesting, combat feel/balance, accessibility, controller support and
  other window sizes remain unverified. No Stage 2 exported-build test yet.
- POI layouts and artwork are intentionally sparse placeholders. No audio or
  animation playback. Generated wilderness terrain still uses biome palettes.
- The old generated wilderness economy still uses iron; the new POI demo uses
  salvage. Keep this compatibility visible when designing the final resource UI.
- Only the camp's named resident is newly recruitable here; generic legacy
  wilderness survivor decisions also remain available. No companion combat system.
- Buildings can be damaged through `damage_building`; no raids or autonomous
  wear were enabled. Time advances through resting, crafting and expeditions.
- Basic tools improve automatic daily Workshop output, not individual node size.
- POI guards stay dead across visits; partly injured guards reset on reload.
  Defeated-guard rewards cannot be claimed twice. There is no full live actor checkpoint.
- Legacy generated-wilderness mid-expedition saves remain outside this stage;
  only POIs gain a supported save/Continue checkpoint. Do not promise full
  Phase 2C checkpoint/resume for arbitrary generated wilderness.
- Existing four-plot and migrated unplaced-building limitations remain.
- Defense changes awareness growth; it does not simulate armies or village attacks.

Next work belongs to Gemini: connect the final management presentation to these
tested services, retaining validation, save migration and registry contracts.
