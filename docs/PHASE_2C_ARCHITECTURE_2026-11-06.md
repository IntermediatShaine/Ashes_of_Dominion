# Phase 2C — Architecture decision proposal (current-main reassessment)

**Status: PROPOSED — owner approval required; no gameplay implementation authorized by this file.**  
**Reviewed baseline:** `main` `ea57814c181ce44d97cb77080c1c34e61cce4052` (2026-11-06).  
**Godot project:** `game/`. **Schema:** `SaveGame.SCHEMA_VERSION = 3`. **Generation:** `UniverseState.CURRENT_GENERATION_VERSION = 1`.

> **Owner preference update (2026-11-06):** A1–A7 now have owner-selected directions, recorded in [ADR-2C-001](ADR_2C_001_OWNER_PERSISTENCE_DECISION.md). The comparison and proposals below are historical design analysis, not a new request to select A1–A7. Detailed approvals R1–R7 and explicit permission to implement gameplay remain pending.

This reassesses [the original Phase 2C proposal](PHASE_2C_ARCHITECTURE_PROPOSAL.md), merged in PR #6 against schema 1. The original was never an adopted save-policy decision. PRs #10 (Claude, Stage 1), #11 (Codex, Stage 2), and #12 (CI reverification) have since merged; the following observations reflect those changes.

## Evidence: implemented, tested, absent

| Source | Current implementation evidence | Boundary / absent guarantee |
| --- | --- | --- |
| `models/save_game.gd`, `persistence/save_migrator.gd` | Three-scope single-document JSON; schemas 1→2→3; schema 3 adds neutral tools/equipment and salvage | No general live-actor snapshot or checkpoint format/version |
| `models/universe_state.gd`, `models/expedition_record.gd` | Stable seed/version, location, world modifications, six RNG stream states, active record, haul, experience, event log | ExpeditionRecord has no scene snapshot; world graph/wilderness generated on demand |
| `services/game_session.gd` | `saving` signal, durable save repository, POI-aware `resume_scene_key()` | Continue enters a POI if active, otherwise settlement; no generated-wilderness resume |
| `map_scene_base.gd`, `map_location.gd`, `poi_controller.gd` | Position/health/pack/once-flags for three POIs survive Save/Continue; guard deaths persist; POI Save and event autosaves exist | Player facing/cooldowns/i-frames and living guards' HP/AI state/timers/private RNG do not survive |
| `exploration_controller.gd` | Generated area recreated at spawn; harvested resources/decision log and selected world state persisted on supported save boundaries | No Save & Exit and no exact active-wilderness restoration |
| `expedition_service.gd`, `transition_service.gd` | Expedition resolve-once, stored resurrection outcome and pending transition recovery | Atomicity across scene capture and durable save not implemented |
| `save_repository.gd` | Verified temp, backup rotation and primary promotion; load primary→backup→temp | When primary is corrupt and backup valid, write removes backup before rotating primary; fault-injection coverage is needed |
| `tests/integration/test_stage2_gameplay.gd`, `tools/relaunch_check.gd` | POI position/pack/health/objects test, failed-save retry tests, two-process whole-save comparison | Not a live-AI/no-reload vs reload equivalence test or a generated-wilderness checkpoint test |

Most recent *reported* local Windows Godot 4.5.1 run: 157 tests, 0 failures, after PR #11 and reconfirmed in PR #12 on 2026-11-06. Neither this review nor PR #6 reran Godot. Do not equate passing headless tests with human-play acceptance.

## ADR-2C-A — Atomic versus resumable exploration

| Dimension | Atomic generated expeditions (save at home only) | Resumable generated expeditions (exact in-area checkpoint) |
| --- | --- | --- |
| Player experience | Clear risk/commitment and short-term strategy; quitting mid-trip loses progress | Supports long journeys, interruptions, accessibility and future companions; save policy can still preserve risk |
| Build complexity | Preserve current wilderness flow; add accurate warnings and explicit policy | Versioned snapshot DTO, capture/restore order, stable actor identities, validation, routing, recovery and migrations |
| Runtime cost | Current seed-derived world and deltas; minimal save time | Freeze simulation to capture; bounded cost scales with current actors and deltas; actual performance must be measured |
| Save size | Existing small universe and expedition record | Current-area actor state, player combat state, and references; do not save entire terrain arrays or node trees |
| Determinism | Re-entering recreates enemies, including new local patrol streams | Preserve six universe streams and *every* private actor stream/timer; restore before new draws |
| Enemies | Revisit can reset live health/AI; defeated guards persist in POIs | Stable key + position, health, alive/dead, FSM, timer, target, pending strike and combat state |
| Resources | Harvested keys and pack must be committed together at supported boundaries | Save depleted keys, claimed rewards and unbanked haul in same transaction; no replay or duplication |
| NPC decisions | Once-only decision log already persists | Also preserve chosen option, NPC presentation/availability and any in-flight interaction stage |
| Compatibility | Schema 3 can remain unchanged | Schema 4 (if on-disk layout changes) plus 1→2→3→4 fixtures and explicit legacy active-record handling |
| Interruption recovery | Restore last durable settlement/POI save; show lost-trip policy | Restore most recent fully validated snapshot, never partially promoted state |
| Game vision | Makes sense for deliberately short, risk-heavy excursions | Better matches long-form RPG exploration, companion mortality and living-world consequences |

**Recommended direction, NOT approved:** implement a *unified exact-state resume contract* for generated wilderness and existing POIs, incrementally. Treat the current POI Save/Continue as a useful partial foundation rather than as proof full mid-expedition saving is complete. Until the contract is accepted and implemented, leave generated-wilderness saves explicitly restricted and make the policy transparent to players.

### Proposed first shipping scope (subject to approval)

1. **Save & Exit from the pause menu at a safe simulation boundary**, initially outside an active attack/windup/hit-resolution phase. A blocked save shows a clear reason; it must not silently drop or reset combat. An explicit manual save or autosave policy is a separate choice.
2. Capture one **current-area checkpoint** only; generated terrain remains derived from `world_seed + generation_version + pinned generation inputs`, plus persisted modifications. Future multi-area caravans/companions and persistent projectiles must be added under new checkpoint versions when implemented.
3. Store the checkpoint **inside the existing universe-owned active expedition**, not in a separately written file. `Session.save_game()` atomically persists the full character/universe/multiverse scopes, active expedition, area changes and RNG state.
4. Keep new generation dispatch/fixtures ahead of checkpoint rollout. A checkpoint cannot restore onto a silently changed map.

### Proposed checkpoint shape (contract, not GDScript implementation)

```text
ExpeditionRecord.checkpoint?:
  format_version, expedition_id, universe_id, map_id, area_id
  generation_version, generation_bundle_id, generated_area_fingerprint
  captured_physics_tick, save_boundary_kind
  player: position [x,y], facing, velocity, current_health,
          cooldown_remaining, swing_phase, hit_spawn_keys,
          invulnerability_remaining, optional input/interaction phase
  enemies: dictionary keyed by stable authored/generated spawn key:
          definition_id, alive, position [x,y], velocity, health,
          fsm_state, timer_remaining, home_position, patrol_target,
          target_spawn_key, private_rng_state, any queued attack
  npc_runtime: stable id -> unresolved/interaction/presentation state
  resources_runtime: stable id -> live state not represented by world_modifications
  explicit future schema extensions for companions/projectiles
```

The checkpoint is not the owner of loot, morale, discovered edges, death records, settlement state or general RNG streams; those already have authoritative owners in the existing save. The snapshot **must reference**, not duplicate or override, these records. Stable keys must be logical spawn IDs, not transient Godot instance IDs/NodePaths. Use typed/validated JSON-friendly coordinates; preserve exact determinism without depending on scene tree ordering.

### Capture, load and failure requirements

- At a defined physics-tick boundary, stop gameplay mutation and RNG draws; collect player/actor state; update the world-delta and existing expedition records; export all six streams; validate; then write one snapshot through `SaveRepository`. Resume gameplay only after the operation is resolved. Display success only after durable write confirmation.
- Loading: read/validate/migrate the save; restore the historical generator/content bundle; construct the world and active area; **recover pending multiverse transition before selecting a scene**; if the active expedition remains valid, create entities with stable keys and apply their saved states *before* physics, AI, attack or RNG callbacks.
- Cross-check checkpoint map id, expedition id, universe id, generator version, area fingerprint, stable actors, saved position/collision and already-applied once/reward markers. Reject inconsistent snapshots without altering original files. Do not respawn dead enemies, repeat a rescue or re-roll rewards.
- A save written during transition recovery must have explicit failure handling; failed writes must not be presented as completed recovery. Crash/fault tests must cover temp, rotation, promotion, corrupted primary + good backup and orphaned temp, not just a mock repository returning failure.
- Legacy schema-1/2/3 *without* checkpoint: ordinary settlement saves load unchanged; currently supported active POI loads keep their old partial semantics until a separately approved migration strategy; active generated-wilderness records **must not** be silently transformed into a fresh encounter, rewarded, or completed. Offer a documented, reversible recovery action or a selectable prior valid save.
- Existing POI automatic saves on claims/deaths may coexist with the new checkpoint only when they capture a consistent live state or are explicitly restricted to durable event boundaries. Avoid a player exploiting the existing partial-health reset through reload.

## Earlier proposal questions — owner directions now recorded in ADR-2C-001

| ID | Decision required | Proposed option, not binding |
| --- | --- | --- |
| A1 | Should *generated* expeditions be atomic or fully resumable? | Resumable; retain a clear transition period |
| A2 | Initial saving trigger: Save & Exit, manual Save, event autosave, periodic autosave? | Pause-menu Save & Exit first; event autosaves revisited for all combat maps |
| A3 | In-combat saving and pending-hit behavior | Initially block during active attacks/windups, clearly; preserve live actors even when allowed |
| A4 | Legacy active-wilderness save without snapshot | Offer an explicit recover-at-home / prior-save selection, never silent replay; preserve backup |
| A5 | Performance acceptance hardware and budget | Measure first; candidate p95 250 ms save, 1 MiB typical checkpoint only if owner agrees |
| A6 | Historical generated-content strategy: immutable bundle versus versioned data tables | Freeze v1 effective inputs and add explicit dispatch before evolving them |
| A7 | Are partial POI checkpoints accepted as a temporary distinct feature? | Label honestly, then unify; do not market as exact-state combat resume |

Owner-selected directions for A1–A7 are now recorded in ADR-2C-001. The remaining detailed R1–R7 gates and separate implementation authorization still apply. No gameplay/schema/generation edits are authorized by this documentation.

## Candidate implementation ownership after approval

- **Claude, production integration owner:** checkpoint record and migration, `Session`/router capture and load ordering, generated-wilderness and POI scene integration, actor serialization.
- **Codex, independent verifier:** fixture generation, golden cross-version tests, real filesystem fault injection, S-series restore tests, two-process active-wilderness relaunch and review of Claude's PR.
- **Owner:** select A1–A7, test Windows gameplay and accept visible save/Continue and recovery behavior.
- **Gemini, presentation-only if separately assigned:** Save & Exit messages, resume badges and failure dialogs after contract freeze; do not independently rewrite persistence.
- **ChatGPT, architecture coordination:** reconcile specifications/PR file ownership and audit evidence; no implied approval power.

See [compatibility/test specification](PHASE_2C_COMPATIBILITY_2026-11-06.md) and [development roadmap](PHASE_2C_ROADMAP_2026-11-06.md).
