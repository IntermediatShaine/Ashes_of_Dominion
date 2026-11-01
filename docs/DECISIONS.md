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
