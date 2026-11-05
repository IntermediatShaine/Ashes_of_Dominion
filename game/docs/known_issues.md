# Known issues and limitations

Reproducible defects and deliberate limitations. Nothing here is hidden behind a working-looking UI.

## Defects / gaps

### Village (Stage 1, 2026-11-05)

- **No human has played the village.** Everything about it is verified by automated tests and by
  rendered screenshots at 1280×720 only.
- **The Workshop has no effect** beyond offering work places; Watchpost and Workshop work places
  do nothing when filled. Workers matter only at the Woodcutter's Camp and on construction jobs.
- **Condition never changes by itself** and nothing damages buildings (`condition_decay_per_day`
  is 0; `SettlementService.damage_building` is there for raids/events to call). Between 1 and 99
  a damaged building looks like a sound one.
- **Time only moves by resting at the hearth or going on an expedition.** Resting costs just the
  day's food.
- **Four building plots** are fewer than the plot buildings the definitions allow; a fifth
  request fails with "No free building site".
- **A building can end up without a site** (a migrated save with more buildings than sites, or
  code calling `ConstructionRules.build` directly). It works and is listed in the Buildings tab,
  but is not in the village and cannot be placed by the player.
- **Cancelling a construction job refunds its full cost.**
- **The village interface is the minimum** (Overview / Buildings); it rebuilds whole panels on
  every change.
- **The earlier management screen is still in the project** (`settlement_legacy`), unreachable.
- **Only the village interface is styled by `village_theme.tres`**; menus, world map and the
  expedition HUD use the code-built theme in `ui_kit.gd`.
- **Expedition terrain is not on the visual registry**, and expedition enemies / resource nodes /
  NPCs have no placeholder images (code-drawn until a registry entry is added).
- **No animation playback**: characters show one frame per facing.

### Earlier

- **No manual verification on Windows yet.** All runtime checks ran on Linux (headless tests, Xvfb +
  llvmpipe screenshot tour). Input feel, window handling and the save path on Windows are
  unverified.
- **Combat tuning values are guesses.** The enemy FSM and the hitbox sweep are now automated-tested
  (`tests/integration/test_enemy_fsm.gd`, `test_combat_physics.gd`), but detect radii, windups,
  reach and cooldowns in `data/enemies.json` / `data/balance.json` have never been felt by a player.
- **A dead protagonist can still start a swing programmatically.** `_try_attack()` does not check
  `combatant.is_alive`; in play this cannot happen because `_physics_process` stops polling input
  once dead and the exploration scene disables input on death. Harmless today; worth a guard when
  attacks get more entry points (abilities, companions).
- **Mist preview corrected (issue #3).** Uncharted and partly charted selections draw a straight
  dashed origin-to-destination indication; only charted edges retain their actual geometry.
  Four renderer integration tests cover hidden-waypoint movement, partial discovery, charted /
  Mist-off behavior and unchanged route/state data. Automated on Windows; human visual review remains open.
- **Old generation versions are not kept.** `generation_version` is validated (≤ current) but
  there is only one generator; bumping the version will make older universes regenerate
  differently unless the old algorithm is preserved behind a version switch.
- **No save during exploration.** Retreat/return/defeat are the only exits; "Abandon to main
  menu" from the pause menu discards the trip (clearly labelled).
- **Food can run out.** Starvation only lowers morale (no deaths); no warning before departure.
- **Resources are finite until regrowth** (10 days, `balance.json`). Enemies respawn every visit.
- **Waypoints share the nearest landmark's biome/danger**; edges average their endpoints. Route
  variety is modest with 6 waypoints.
- **`world_geometry`, `route`, `encounter` runtime streams are currently unused** (generation
  uses its own derived streams). They are persisted so future systems can draw from them.
- **Difficulty parameters marked "not yet functional"** (faction aggression, expansion, raids,
  discovery speed, companion mortality, cheats) are stored but read by nothing.
- **Class unlock has no effect** beyond `unlocked_classes`; switching class has no UI and no
  gameplay consequence.
- **Each decision resolves once per universe**, then its NPC never appears again there. Two are
  defined: the stranded survivor (marches/eldergrove) and the Crown patrol (crossroads/border fort,
  after the survivor). The Crown patrol's `fight` option wounds the protagonist through dialogue
  (never below 1 health) but spawns no actual riders — hostile patrols as combat encounters are a
  later feature.
- **Reputation gate reasons use prettified ids** ("Crown Of Aurel"): rules have no access to the
  content tables, so faction display names are not available to `DecisionRules.blocking_reason`.
- **Adding a decision to a biome can change an existing universe's area repair.** The NPC cell is
  part of the reachability repair input, so an area that previously had no NPC (all decisions
  resolved) may get one extra carved corridor once a new decision is defined for it. Terrain seeds,
  resources and enemies are unchanged; no `generation_version` bump was made for Phase 2A.
- **The crypt "dungeon" is a biome variant** (dense walls, sentinels), not an enclosed dungeon layout.
- **Camera limits assume the map is at least the viewport size**; smaller maps would show
  outside-of-map space (expedition areas and the village are 1408×960 px > 1280×720). A window
  much wider than 16:9 exceeds that with the `expand` stretch aspect.
- `Content` pushes errors for bad data but the bootstrap only *shows* them; the game still lets
  you reach the main menu, where they are listed again.

## Engine / tooling notes

- Godot 4.5 treats `inference_on_variant` as an error by default: never `:=` from a Variant
  (e.g. `Dictionary` lookups, duck-typed objects). Add an explicit type instead.
- New `class_name` scripts require `--import` (or opening the editor) before headless runs see them.
- The suite also passes unmodified on Godot 4.7.2-stable (2026-11-05). Engines from 4.6 on add
  `TextureRect`s of their own inside `ScrollContainer`; do not assume every `TextureRect` in a
  UI tree is yours.
- A local variable named like a global function (`log`, `range`, `load`) shadows it; pick
  another name.
- Inside a class, an unqualified call to a name that is also a global function (`randf`,
  `randi_range`, `load`…) resolves to the **global** — qualify with `self.` or rename.
