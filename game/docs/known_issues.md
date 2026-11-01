# Known issues and limitations

Reproducible defects and deliberate limitations. Nothing here is hidden behind a working-looking UI.

## Defects / gaps

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
- **Route preview can leak shape.** With the Mist on, the dashed preview of an uncharted route
  still reveals where the intermediate waypoints are. Days and danger stay estimates. Options:
  draw a straight dashed line to the destination for uncharted segments.
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
- **Decision NPC appears in marches/eldergrove areas only until resolved**, then never again in
  that universe (one decision defined).
- **The crypt "dungeon" is a biome variant** (dense walls, sentinels), not an enclosed dungeon layout.
- **Camera limits assume the map is at least the viewport size**; smaller maps would show
  outside-of-map space (current map 1408×960 px > 1280×720).
- `Content` pushes errors for bad data but the bootstrap only *shows* them; the game still lets
  you reach the main menu, where they are listed again.

## Engine / tooling notes

- Godot 4.5 treats `inference_on_variant` as an error by default: never `:=` from a Variant
  (e.g. `Dictionary` lookups, duck-typed objects). Add an explicit type instead.
- New `class_name` scripts require `--import` (or opening the editor) before headless runs see them.
- Inside a class, an unqualified call to a name that is also a global function (`randf`,
  `randi_range`, `load`…) resolves to the **global** — qualify with `self.` or rename.
