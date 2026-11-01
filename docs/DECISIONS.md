# Design decisions and open questions

## Established design directions

- Begin as a weak **Survivor**, not a fully powered hero or villain.
- Track **personal morality** separately from **reputation with individual factions**.
- The protagonist's supernatural return after death is part of the narrative; important companions ordinarily face permanent death.
- Keep important story locations recognizable while procedurally changing wilderness, terrain, routes and encounters.
- Make the **Mist of Discovery** configurable; strategic route previews provide estimates, not perfect information.
- Start near a contested frontier village destroyed or devastated by factional conflict.
- Target a single-player Windows game using mouse/keyboard, 2.5D pixel art and Godot/GDScript.
- Build and validate a limited playable demo before expanding to every class, region and strategic system.
- The core loop spans preparation, route planning, exploration, interaction/combat, return, settlement improvement and world progression.

## Proposals and balancing targets, not final rules

- Seven initial regions, proposed racial roster and twenty candidate advanced class specializations.
- The first demo envelope: one village, three biomes, two factions, four enemy types, three archetypes, one dungeon and four functional buildings.
- Approximately five expeditions of grace before discovery becomes a serious threat; precise difficulty-dependent calculations remain undecided.
- Combat formulas, class transformations, spell/weapon costs, troop formations, faction decision logic, settlement production and unrest.
- Companion capture and ransom rules, exact resurrection costs and multiverse transfer conditions.
- The exact Godot 4 patch version, game save schema, random stream algorithms and generated map representation.

## Earlier technical discussion, not yet verified in source

A Claude exchange describing a v0.3 addendum proposed the separation of character, universe and multiverse state, seeded independent RNG streams, resolved resurrection rolls and pending multiverse transfers. The full addendum and the code are not included in this repository yet. Treat these as historical design context until reviewed against the original material and actual implementation.

## Decision records

For every material new decision, add a dated entry below noting rationale, alternatives considered, affected systems and save-migration implications.

### 2026-11-01 — Repository as the shared AI project reference

A GitHub repository is the common reference for documentation and eventually Godot source. Changes should be synchronized through commits, not assumed from prior AI conversations.
