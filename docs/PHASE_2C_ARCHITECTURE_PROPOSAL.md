# Phase 2C — Architecture decision proposal (UNAPPROVED)

**Status:** Proposal for owner review. **Baseline:** main at aec6ce9 (2026-11-01). **Scope:** design only; no gameplay implementation or save migration is approved by this document.

## Evidence from the tracked source

- Godot 4.5.1 project root is game/. SaveGame schema 1 has CharacterState, UniverseState and MultiverseState. UniverseState generation_version = 1, with immutable seed and frozen difficulty/settings. State and six named gameplay RNG streams serialize through SaveRepository.
- ExpeditionRecord retains active status, route, haul, XP, event history and resolution flag; it has **no runtime scene snapshot**. GameSession.load_slot reconstructs the generated world graph but has no checkpoint-to-scene routing; both Continue and Load route to the settlement. ExplorationController._ready regenerates the wilderness and places the player at the spawn; enemies start at full health with new runtime FSM state. HUD pause offers retreat or abandon, not save.
- World modifications already retain harvested-resource keys. DecisionRules records a once-per-universe decision, and ExpeditionService/TransitionService use recorded IDs and resolved flags for idempotency. Those contracts are valuable but do not constitute in-expedition resume.
- The design specifies persistent consequences, risky exploration, long-term companions with permanent death, and a living world. It requires reliable saving/loading but **does not settle** whether trips must be atomic.

## ADR-2C-A: when can an expedition be saved?

| Dimension | Atomic excursion (save at settlement) | Resume an active excursion |
| --- | --- | --- |
| Player experience | Clear risk boundary, simple commitment; interruption loses unsaved trip | Supports long journeys and player interruptions; avoids time-based punishment |
| Complexity | Existing approach; enforce the boundary | Versioned checkpoint DTO, scene capture/restore, routing, collision reconciliation |
| Save size / performance | Existing small seed + world deltas | Additional player/enemy/NPC runtime deltas; bounded by one loaded area, not a complete generated map |
| Compatibility | No schema change required | Add checkpoint record and schema 1→2 migration, or an equivalent explicit versioned contract |
| RNG | Unsaved outcomes roll again after restart | Save all six gameplay stream states **and** per-enemy private patrol streams and FSM timing |
| Enemies / NPCs | Reset on a new expedition | Keep health, death, positions, AI states, timers, target intent and one-time interactions |
| Harvest | Changes are committed on return | Persist area harvested keys together with the unbanked haul, without double awards |
| Interruption | Recover at previous durable settlement save | Load last fully validated checkpoint; never promote an incomplete one |

**Recommendation (not approval):** target *resumable expeditions* because the intended RPG supports longer travel, consequential companion states and interruption-friendly progression. Implement as a **bounded, opt-in feature slice** after generation v1 compatibility is locked. The proposed first shipping contract is explicit pause-menu Save & Exit at a stable physics-tick boundary and exact-position Continue. A later expansion to arbitrary autosaves/mid-animation saves needs its own acceptance criteria. If saves during an active attack are offered, cooldown, active-hit targets, i-frames and attack phase must be serialized; do not reset combat to gain an advantage. Alternatively refuse save while the attack phase is in flight, with a visible reason and no loss of game control. The owner must choose that player-facing rule.

### Proposed ownership and serialization contract

- Keep procedural terrain derived from **world_seed + generation_version + immutable generation-content version**. Save **deltas only**, not TerrainRenderer nodes or full tile arrays.
- Attach an optional **checkpoint** to the active ExpeditionRecord (single authoritative owner), with checkpoint_format_version, expedition_id, universe_id, area_id, generated-area fingerprint/content version, captured_tick or equivalent sequence number, player transform/facing/health, cooldown/attack/i-frame state, enemy instances keyed by stable spawn key (alive/dead, HP, transform, state, state timer, patrol target and local PRNG state), NPC/decision state and optional future companion/projectile state.
- Persist existing expedition haul, enemy rewards/XP, world_modifications, decision_log and multiverse transition records in the **same SaveGame transaction**. Store structured numeric coordinates rather than NodePaths or instance IDs. Validate every reference against the regenerated area before applying changes.
- Snapshot at a consistent simulation boundary. Pause event processing during capture; avoid duplicate scene callbacks on restore. Bind saved RNG states before any gameplay draw. Never replay already-applied reward, death, decision or harvest events.
- On load, Session first validates/migrates and binds state, then resolves pending transitions **before** choosing a scene. If a transition ends the expedition, route to settlement; otherwise a valid active checkpoint routes to exploration and restores the matching area. Loading an old active expedition without a checkpoint must use a visibly explained, non-destructive fallback—not silently restart the encounter or award loot.
- A checksum/fingerprint mismatch, missing generator version or invalid actor key is a controlled load failure with preservation of source saves and recovery options. Successful save feedback is shown only after SaveRepository confirms durability.
- Save-system failure injection must test temp-write, backup rotation and final promotion, particularly backup preservation when the current primary is corrupt. The current write path deletes the previous backup before rotating primary; this is a **risk to test**, not a claim of a proven data-loss bug.

### Owner approval needed

1. **A1:** Atomic excursions, or resumable expeditions as the target behavior? Proposed: resumable.
2. **A2:** Initial save UI: pause-only Save & Exit; also manual save while exploring; or checkpoint autosaves? Proposed: pause-only first.
3. **A3:** Can a player save during an active attack / enemy windup? Proposed: accept only fully captured combat states, otherwise temporarily disallow at that phase with explicit notice.
4. **A4:** On an invalid legacy active expedition with no checkpoint, should the player restore the last settlement checkpoint, receive an explicit recover-to-home option, or choose from backups? No silent resolution.
5. **A5:** Performance target proposal: 250 ms p95 save latency and 1 MiB p95 size for a typical current-area checkpoint on a specified reference Windows machine; measure before committing to budgets.

### Implemented vs proposed

**Implemented/previously tested:** three scopes, schema-1 round-trip, runtime RNG stream persistence, generated maps and harvested deltas, finish/idempotency, pending resurrection recovery. **Proposed, not implemented/tested:** checkpoint format, exact-coordinate restore, enemy/NPC runtime snapshots, in-combat save policy, schema 2, checkpoint-specific backup/fault tests, load-to-exploration routing. Historical published 66-test result belongs to Codex PR #4; it is not a test run for Phase 2C.
