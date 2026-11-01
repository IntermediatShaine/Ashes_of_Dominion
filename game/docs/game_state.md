# Game state: scopes, ownership, transitions

Save file = `SaveGame { schema_version, meta, character, universe, multiverse }` → one JSON
document per slot. Every 64-bit integer (seeds, rng states) is written as a **string** because
JSON numbers are doubles (see technical_decisions.md).

## Scope 1 — CharacterState (follows the protagonist between universes)

| Field | Owner notes |
| --- | --- |
| `character_id`, `character_name`, `archetype_id`, `background` | identity, immutable |
| `primary_ancestry`, `secondary_ancestry` ("" if not mixed) | two separate ancestry ids, never a concatenated "race" |
| `current_class`, `unlocked_classes` | ClassRules refreshes unlocks on level-up; switching class has no UI yet |
| `level`, `experience`, `base_attributes` | ProgressionRules; XP resets to the remainder on level-up |
| `learned_skills`, `permanent_unlocks`, `persistent_lore`, `persistent_character_flags` | reserved, serialized, empty in the slice |
| `morality` (-100..100), `morality_log` | MoralityRules; log entries keyed by event id → each event applies once |

**Not here on purpose:** current health (universe), faction reputation (universe), equipment (not implemented).

## Scope 2 — UniverseState (one generated world; replaced on transfer)

Immutable generation parameters: `universe_id`, `world_seed`, `generation_version`, `difficulty`
(frozen copy of the chosen configuration), `world_settings.mist_enabled`.

Mutable: `current_day`, `discovered_landmark_ids`, `revealed_edge_ids`, `world_modifications`
(`area_id → {harvested: {node_key: day}}`), `settlements` (home only for now), `factions`
(`FactionState`: reputation, relations, territory, aggression, log), `territory_state`,
`threat_state {completed_expeditions, awareness, grace_period}`, `world_events`, `expeditions`
(`ExpeditionRecord` by id), `expedition_history`, `active_expedition_id`, `story_flags`,
`decision_log` (decision id → chosen option), `protagonist_condition {health}`, `death_count`,
`id_counters` (sequential ids: `exp_`, `bld_`, `death_`), `rng_states` (6 named streams),
`npc_states`, `companion_states` (reserved, empty).

**Why health lives here:** it is reset by returning home and would carry stale numbers across a
universe transfer. If a future rule says health persists, move the field and bump the schema.

## Scope 3 — MultiverseState (survives universe replacement)

`natural_transfer_count`, `forced_transfer_count` (never incremented — rules undefined),
`resolved_resurrection_outcomes` (death event id → outcome; written **before** the outcome is
applied, so a reload cannot reroll it), `pending_transition` (one explicit record or null),
`completed_transition_ids`, `persistent_multiverse_flags`, `universe_counter`, `id_counters` (`tr_`).

## Stable identifiers

| Thing | Id |
| --- | --- |
| character | `chr_<12 hex>` (time + random, created once) |
| universe | `u<counter>_<8 hex of seed hash>` |
| faction / landmark / biome / enemy / building definition | data key |
| settlement | `stl_emberfall` |
| expedition / building instance / death event | `exp_000001`, `bld_000001`, `death_000001` (universe counters) |
| transition | `tr_000001` (multiverse counter) |
| edge | `e_<a>__<b>` (sorted endpoint ids) ; waypoint `wp_NN` |

Node instance ids are never persisted.

## Validation

`SaveValidator.build_and_validate(raw)`: structural (sections + schema_version present) →
`SaveMigrator.migrate` (rejects version ≤ 0 and > current) → `SaveGame.from_dict` →
`validate()` on every model (ids present, ranges, references: home settlement exists, active
expedition exists and is active, home landmark discovered, every rng stream present, no negative
resources, pending transition not already completed…). `SaveRepository.write` refuses to write an
invalid state and refuses to promote a temp file that does not read back valid.

## Death → resurrection → transition (TransitionService)

```
record_death()            universe.death_count++, world_events += {id: death_000N}
resolve_resurrection(id)  multiverse.resolved_resurrection_outcomes[id] ?= {kind: return_home, transition_id: tr_000N}
begin_transition(outcome) multiverse.pending_transition = {transition_id, kind: resurrection_return, status: pending}
execute_transition(t)     if completed → no-op; else ExpeditionService.finish("defeated") (itself idempotent
                          via ExpeditionRecord.resolved), heal, completed_transition_ids += id, pending = null
recover_pending()         called by Session.load_slot: executes a pending record left by a crash, once
```

Only `return_home` exists. Universe transfer is deliberately **not** implemented: the record
carries `kind` so a transfer kind can be added without changing the save schema, and
`TransitionService.execute_transition` is the single place to add it.

## Idempotency guarantees (tested)

- `ExpeditionRecord.resolved` → haul, discovery, calendar, threat, history apply once.
- `MoralityRules.apply_event` / `ReputationRules.apply_event` keyed by event id.
- `decision_log` → a narrative decision resolves once per universe; a refused option (pack or
  reputation gate) leaves the decision open.
- Resurrection outcome keyed by death id; transition keyed by transition id.
- `world_modifications.harvested` → a resource node cannot be gathered twice (until regrowth).
