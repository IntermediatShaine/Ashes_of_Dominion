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

## Earlier technical discussion — now implemented in `game/`

The separation of character, universe and multiverse state, seeded independent RNG streams,
resolved resurrection rolls stored before use and explicit pending multiverse transitions are
implemented and automated-tested in `game/` (see `game/docs/game_state.md`). No "v0.3 addendum"
document exists; the ideas were carried into the rebuild. Universe **transfer** rules themselves
are still undefined (only the `return_home` resurrection outcome exists).

**Phase 2C proposal status (2026-11-01):** [The expedition-save ADR](PHASE_2C_ARCHITECTURE_PROPOSAL.md) is **not an adopted decision**. The [Codex issue #3 audit](CODEX_ISSUE_3_AUDIT.md) subsequently recovered and statically inspected the separate v0.3.1-m1 archive; older statements about inaccessibility below are historical and do not authorize a replacement of game/.

## Decision records

### 2026-11-05 — Stage 2 bounded gameplay decisions

The Stage 2 assignment authorizes solo new-game starts (zero residents),
salvage in the three new demo POIs, personal crafting without hired workers,
and saved consequences. Existing saves keep their populations and iron; old
wilderness content remains compatible. POIs use Claude's map framework and
standard expedition records, with local map buttons rather than changing the
seeded route graph. A shrine ward grants data-defined defense; Watchpost
staffing also grants defense, reducing later awareness growth to a minimum
of one per trip after the unchanged difficulty grace period. No raids or faction
simulation are implied. Rebuilding a ruin still uses Claude's `build` action;
`repair` restores condition on an existing building. Time remains turn-based
through rest/expeditions, with recipe-defined crafting minutes added.

Schema 3 adds neutral equipment/tool defaults and salvage to migrated stock.
Universe-bound gear does not become character progression. POI Continue is
supported; the wider Phase 2C generated-wilderness checkpoint proposal remains
outside scope. See `game/docs/handoffs/02_CODEX_TO_GEMINI.md` for contracts,
tested evidence and provisional balance values.

For every material new decision, add a dated entry below noting rationale, alternatives considered, affected systems and save-migration implications.

### 2026-11-01 — Repository as the shared AI project reference

A GitHub repository is the common reference for documentation and eventually Godot source. Changes should be synchronized through commits, not assumed from prior AI conversations.

### 2026-11-01 — `game/` is the Godot project root; engine is Godot 4.5.1-stable

**Decision.** The project from `D:\Ashes of Dominion` was imported unchanged into `game/`; the
repository root keeps the cross-assistant documentation. `project.godot` declares feature `4.5`;
all recorded test evidence is from the official 4.5.1-stable build. **Rationale.** The directive
asked for `game/` unless an existing structure argued otherwise; the existing project had no
nested layout to preserve. The "Godot 4.7.2" named in the design document does not exist.
**Alternatives.** Project at repository root (rejected: mixes engine files with collaboration
docs). **Affected systems.** Tooling paths only. **Save implications.** None.

### 2026-11-01 — The imported `game/` project is the repository's only implementation (provisional)

**Decision.** `game/` (the 2026-10-28 rebuild) is committed and treated as the working baseline.
A separate line of work — Codex's "AshesOfDominion-unified-foundation" v0.3.1-m1 and Claude's
M2/M2b/M2.1 packages (walkable village, headless world engine checkpoint, backend-first
corrections) — exists outside the repository and was not inspected on 2026-11-01. **Rationale.**
Only `game/` was accessible and could be executed and tested. **Open for the owner.** Decide
whether that other line of work should be imported and audited (and if so, which project is
authoritative), merged feature-by-feature into `game/`, or retired. Until decided, new features
go into `game/`. **Affected systems.** Potentially everything if a merge is chosen. **Save
implications.** The two lines may have different save schemas; a merge needs a migration plan.

### 2026-11-01 — Reputation gates read faction standing only; thresholds reuse the standing bands

**Decision.** Narrative options and prompt variants are gated with `requires_reputation` /
`prompts_by_reputation` on faction `player_reputation`; morality is never an input. Threshold
values in content use the existing `ReputationRules.label` bands (Friendly ≥ 20, Neutral,
Distrusted ≤ −20) so the settlement screen's standing label predicts how a faction will treat you.
**Rationale.** Keeps the morality/reputation separation mechanical, not just conceptual, and
gives the player one readable scale per faction. **Alternatives.** Hidden per-encounter
thresholds (rejected: unreadable); morality-based reactions (rejected: breaks the separation).
**Affected systems.** DecisionRules, exploration HUD, content validation. **Save implications.**
None (no new persisted fields; `decision_log` unchanged).

### 2026-11-01 — Decision selection is data-driven (biome, landmarks, priority), one NPC per area

**Decision.** `DecisionRules.select_for_area` picks the lowest-`priority` unresolved decision for
the area's biome and (optionally) landmark; a resolved decision gives way to the next one.
**Rationale.** The generator supports one event NPC per area; sequencing by priority keeps the
survivor first and makes the patrol reachable on the next marches trip without new generator
work. **Consequence.** The NPC cell is a repair input, so defining a new decision for a biome can
add a carved corridor to an existing universe's area where all decisions were already resolved
(documented in `game/docs/known_issues.md`); no `generation_version` bump was made because the
project has no shipped saves. **Provisional.** A dialogue wound (`health` effect) never kills;
hostile patrols that spawn riders are deferred.

### 2026-11-01 — Death penalty remains provisional

`game/data/balance.json → expedition.defeat_loses_haul = true` (carried loot is lost, earned XP is
kept) is the only implemented consequence. The design leaves the penalty open; see
`game/docs/technical_decisions.md` §9. Not a final rule.

### 2026-11-05 — Engine version: 4.7.2-stable exists; the project stays pinned to 4.5.1 for now

**Correction.** Earlier entries say "Godot 4.7.2" does not exist. As of 2026-11-05 it does
(official build `4.7.2.stable.official.ed1daf0bf`). **Finding.** The full suite (138 tests), the
smoke test and the relaunch check pass unmodified on it. **Decision (provisional).**
`project.godot` keeps declaring 4.5 and CI keeps its checksum-pinned 4.5.1, because the pin and
the export templates belong to the CI/release setup and were not part of Stage 1. **Open for the
owner.** Whether to move the pin to 4.7.2 (editor, CI installer, export templates and
`config/features` together). **Save implications.** None.

### 2026-11-05 — The village starts as ruins; buildings exist only once built

**Decision.** Emberfall opens with the Village Hearth, Shelter, Workshop, Stockpile and Watchpost
as ruins on reserved sites and four free plots. A building instance is created when it is
(re)built; a ruin is a site without one. **Rationale.** It matches the story (a destroyed
village), leaves the starting numbers and every existing rule untouched, and makes "rebuild" the
first thing a player does. **Alternatives.** Start with working level-1 buildings (rejected: it
changes housing, storage and threat from day one and needs rebalancing); level-0 instances
(rejected: every rule that counts buildings would have to learn to skip them). **Affected
systems.** Settlement rules, construction, save format. **Save implications.** Schema 2;
`game/docs/game_state.md`.

### 2026-11-05 — Save schema 2

**Decision.** `SaveGame.SCHEMA_VERSION` 1 → 2: time of day, location, building level / condition
/ site, residents instead of a head count, construction jobs, settlement event log. Migration
`_migrate_1_to_2` plus `SettlementService.normalize()` for the parts that depend on content
(names, sites). **Verification.** A save written by `main` before the change is kept as a
fixture and migrated in tests. **Not affected.** `generation_version`, world generation, the
runtime RNG streams, character and multiverse scopes. This is independent of the unapproved
Phase 2C expedition-checkpoint proposal and does not implement any of it.

### 2026-11-05 — Images are named only in the visual registry

**Decision.** Objects reference stable visual ids; `game/data/visuals/visual_registry.json` maps
them to images; collisions and interaction areas come from layout data. A test fails if a script
or scene contains an image path. **Scope reached.** Village, protagonist, interface icons.
Expedition enemies, resource nodes and NPCs switch to registry art as soon as an entry with
their id exists; expedition terrain is still drawn from biome palettes. **Save implications.**
None.

### 2026-11-05 — Provisional: resting at the hearth passes the night for the price of a day's food

**Decision.** Village Management offers "Rest until dawn", which advances the clock to the next
dawn and runs the normal daily tick. **Rationale.** Construction now takes days; without a way
to let time pass in the village, finished work could only be seen after an expedition.
**Provisional.** It has no cost beyond food and no risk. Whether resting should be limited,
cost something, or be replaced by a running clock is a design question for the owner and
Stage 2. **Save implications.** None beyond the clock field.

### 2026-11-05 — The earlier management screen is kept, unreachable, for one more stage

**Decision.** `settlement` now opens the village; the previous screen stays in the project under
the router key `settlement_legacy` with its test. **Rationale.** It is working, tested code that
shows a few things in a denser form; removing it is cheap later and not reversible in spirit
once the dashboard work starts from the village interface. **Open for the owner.** Delete it
when the Stage 3 dashboard exists.

