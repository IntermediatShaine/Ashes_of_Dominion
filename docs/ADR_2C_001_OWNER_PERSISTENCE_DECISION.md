# ADR-2C-001 — Expedition persistence, historical generation, and transitional POI saving

- **Status:** Owner policy preferences recorded; ADR text finalized for architecture review. **Implementation NOT authorized.**
- **Date:** 2026-11-06
- **Decision owner:** Project owner, Ashes of Dominion
- **Scope:** Phase 2C — generated expeditions, save/resume compatibility, historical procedural generation, and existing hand-authored POI checkpoint behavior.
- **Source baseline:** `main` at `402bdc87423fd8184ea6cee6422a8ecfa2cc3648` (merged PR #13). Godot project remains `game/`.
- **Existing technical baseline:** `SaveGame.SCHEMA_VERSION = 3`; `UniverseState.CURRENT_GENERATION_VERSION = 1`.
- **Related documents:** [Current Phase 2C architecture proposal](PHASE_2C_ARCHITECTURE_2026-11-06.md), [compatibility and test specification](PHASE_2C_COMPATIBILITY_2026-11-06.md), [three-milestone roadmap](PHASE_2C_ROADMAP_2026-11-06.md).

## Decision summary — all seven owner preferences recorded

| Ref | Owner-selected direction | Status |
| --- | --- | --- |
| **A1** | **Resumable generated expeditions** are the target, rather than permanently atomic excursions. | Policy preference selected; implementation gated |
| **A2** | Initial user-facing trigger is **pause-menu Save & Exit**. | Selected; exact UI and transaction design pending review |
| **A3** | **Block saving during unresolved attacks** (including windup, hit resolution and other unsafe combat phases) for the first release. | Selected initial safety policy; exact eligibility criteria pending |
| **A4** | **Explicit recovery choices** for historical active-wilderness saves without complete checkpoints. No silent scene replay or forced resolution. | Selected; choice text, eligibility and fallbacks pending |
| **A5** | **Measure performance first; approve latency/size limits afterwards.** | Measurement strategy selected; numeric limits remain unapproved |
| **A6** | **Freeze an immutable version-1 generation bundle**, including algorithm behavior and effective generation inputs. | Selected; bundle inventory and baseline hashes pending |
| **A7** | **Retain existing partial POI Save/Continue temporarily, then unify** it with the exact-state checkpoint architecture. | Transitional policy selected; migration and notice design pending |

These are **owner-selected preferences**, not assumptions made by an AI assistant. They settle the *policy direction for architecture planning* but do not authorize code implementation. This ADR must not be represented as a merged gameplay change, completed capability, test result, or blanket instruction to start work.

## Context and rationale

Ashes of Dominion is intended to support long-running exploration, real-time combat, persistent world consequences, companion mortality and a changing universe. Atomic excursions are simpler and can reinforce risk; however, making progress disappear merely because a session is interrupted is a poor fit for the long-form experience. Resumable expeditions offer session flexibility while maintaining game-design consequences for defeat, resource scarcity and choices.

As reviewed in source, the current `game/` implementation already has three save scopes, seeded generation, independent gameplay RNG streams, expedition resolution guards and idempotent resurrection transitions. Stage 2 added Save/Continue for authored POIs, restoring player position, health, haul and one-time interactions; living enemies' partial HP and AI runtime do **not** fully persist. Generated wilderness does **not** currently resume exact live state. `generation_version=1` is recorded, but the two generators still lack dispatch to frozen version-specific algorithms or content, so future generation changes could alter established maps.

The owner prefers extending these existing contracts rather than replacing `game/` or copying the separate Codex v0.3.1-m1 project.

## Binding design intent for subsequent review (not an implementation order)

### A1 — Generated expeditions must eventually resume precisely

When delivered, an accepted checkpoint must resume the same active expedition, map and location with the same player health/facing, live/dead enemy identities and states, harvested resources, pack, NPC outcomes and gameplay RNG continuation. **Resumable** does not mean save-scumming protections are automatically designed or that death penalties are reduced; those mechanics remain separate.

### A2 — First interface: pause-menu Save & Exit

The initial approved *direction* is one explicit Save & Exit action accessible from the exploration pause menu at an eligible safe boundary. A successful action saves the consistent state and exits to the main menu. Failure must retain the current running session and show a truthful retryable error; no false success acknowledgment or hidden abandonment. Unrestricted manual saves, periodic autosaves and saving during any attack are **not approved** by A2. Existing POI interaction/event autosaves are grandfathered temporarily under A7 and must be reviewed for consistency.

### A3 — Unsafe combat phases are not save boundaries

For first-release checkpoint scope, requests occurring during an unresolved attack/windup, pending hit or other unsafe mutation window are rejected or delayed according to a separately reviewed UI rule. The player must receive a clear reason and a retry path. Capturing a snapshot may proceed only when all relevant combat/event state is internally consistent at a controlled simulation boundary. Exactly when an attack becomes settled, whether to queue a request automatically and whether cooldown/i-frame remainder persists still require detailed design. **Never reset an enemy's health, patrol RNG or strike timer merely to make a checkpoint easy to restore.**

### A4 — Historical active-wilderness saves need explicit recovery

When loading schemas 1/2/3 with an active wilderness expedition but no valid live-state checkpoint, the game must **not** silently restart a fresh encounter, teleport the player home while retaining a stranded expedition, double-award haul or replay a death/decision. Offer a clearly described selection among **available and verified** recovery paths, such as a prior valid backup or an expressly designed recover-to-home operation. The exact menu, consequences for unbanked haul/XP and what happens when no valid backup exists require owner acceptance. No recovered source or backup is overwritten before its integrity is established.

### A5 — Performance targets are to be measured, not guessed

Before approving numeric budgets, record the reference Windows hardware, loaded-area size and actor counts, and save latency p50/p95, load/resume latency and on-disk size for realistic and stress cases. The previously proposed `250 ms p95 / 1 MiB` are **illustrative candidates only** and are **not accepted limits**. The owner approves limits after seeing benchmark data and player-visible pause behavior.

### A6 — Existing procedural worlds must be historically reproducible

Freeze the `generation_version=1` graph and wilderness algorithms and their **effective immutable input bundle** before introducing generation changes. Include landmarks/anchor IDs and coordinates, biome and world-map/wilderness parameters, enemy/resource pools, NPC/decision selection inputs that affect geometry/repair, and historical hashing/RNG behavior. Produce immutable v1 goldens from a known verified baseline with seed/input/engine/source provenance. Explicit dispatch for **both** generators must continue to select the v1 algorithm/bundle for saved v1 universes. New universes may use v2 only after a separately reviewed intentional version bump.

Save schema version and generation version are independent. Never default a missing older `generation_version` to a future current version; use an explicit, fixture-proven legacy mapping or controlled error. Established landmark/story anchors, routes, harvested keys, NPC decision outcomes and Mist discovery references remain valid, or require a separately approved migration.

### A7 — POI Save/Continue stays as a temporary compatibility exception

Existing authored POI save/resume features remain available during the transition. They **must not** be represented as exact-state combat snapshots: partly injured surviving guards can reset after reload today. Future work should converge POI and generated-wilderness persistence onto one authoritative checkpoint contract, using current `MapLocation`, `MapStateStore`, `ExpeditionRecord` and three-scope save ownership rather than a second save authority. The migration and messaging for historical POI saves require review; no existing saved POI should be silently invalidated.

## Technical constraints inherited from the reviewed architecture

1. Keep the authoritative `game/` project and the three scopes (`CharacterState`, `UniverseState`, `MultiverseState`). Checkpoint state, if approved for implementation, belongs to the **universe-owned active expedition** in one durable SaveGame transaction, not a separate independently committed scene file.
2. Regenerate terrain from seed, historical generation version and immutable bundle; persist bounded changes/current-area actor state rather than the complete Godot scene tree or every terrain tile.
3. Capture at a consistent physics/event boundary, preserving all six named persisted gameplay RNG streams **and** each active enemy's private RNG/timer, along with stable actor keys, lives/deaths and combat phases. Never serialize transient Node instance IDs as cross-session identities.
4. On load, validate/migrate and recover any pending multiverse transition **before** selecting the resume scene or advancing combat; apply restored runtime state before RNG-consuming AI callbacks.
5. Keep once-only rewards, harvesting, NPC decisions, expedition resolution and resurrection/transition records idempotent. A failed write must not be presented as a completed checkpoint; test actual primary/backup/temp filesystem stages.
6. Do not bump `SaveGame.SCHEMA_VERSION` merely for historical generation dispatch. A new on-disk checkpoint field or format requires an explicitly reviewed migration (nominally schema 3→4) and tests for schemas 1/2/3.
7. Preserve authored POI stable object and enemy IDs across compatible content changes; an immutable world-generator bundle alone does not preserve renamed authored POI content.

## Options considered and consequences

**Rejected as long-term direction:** permanently atomic generated wilderness. This reduces scene-serialization work, but increases interruption costs and diverges from the long-session RPG direction. It remains the **current implemented limitation** until resumability is actually delivered.

**Deferred:** save-anytime during active attacks, periodic autosave policies, arbitrary projectile or companion snapshots, multi-area simultaneous active scenes, compression, event sourcing, and automatic save conversion from the separate v0.3.1-m1 foundation. They are not implicit requirements of A1–A7.

**Accepted tradeoffs in principle:** larger and more complex saves, snapshot versioning, stricter compatibility tests and additional development work in exchange for reproducible long-session continuity. Exact performance cost is unknown pending A5 measurements.

## Remaining approvals and release gates

The owner's choices above are **recorded** and must not be re-presented as undecided. The following detailed approvals are still **pending**:

| Gate | Required review/approval | Who signs off |
| --- | --- | --- |
| **R1 — implementation start** | Explicit authorization for each code milestone / bounded PR. This ADR itself authorizes **documentation only**. | Owner |
| **R2 — generation baseline** | Manifest of frozen v1 effective inputs, reference source/engine and locked fixture hashes, including story anchors and decision-driven repair. | Owner after Claude/Codex evidence |
| **R3 — checkpoint contract** | Snapshot fields/format, actor keys, collision/restore sequence, safe-tick definition, compatibility validation and migration policy; confirm schema increment only if needed. | Owner |
| **R4 — combat UX** | Precisely identify unsafe windup/strike/damage windows and whether Save & Exit is rejected, waits, or offers retry; screen wording and failure/quit behavior. | Owner |
| **R5 — legacy recovery UX** | Enumerate valid backup and recover-home choices; define unbanked loot/XP treatment, invalid-checkpoint handling and treatment of historical POI checkpoints. | Owner |
| **R6 — performance budgets** | Hardware/scene benchmark protocol, observed p50/p95 and save sizes, then concrete accepted maximums. | Owner |
| **R7 — validation and release** | Evidence from generation fixture regressions, G/P/S tests, actual staged filesystem failures, Windows/Linux Godot 4.5.1 CI, two-process active-wilderness relaunch and Windows manual play. | Owner after QA/agent report |

A failure of any gate blocks claims of completion; it does not automatically revoke the owner-selected direction. Future changes to A1–A7 require a dated superseding decision.

## Execution sequence after separate authorization

- **2C.1 — Baseline and feasibility:** Codex leads frozen v1 fixtures, schema-3 historical save cases and real save-repository fault tests; Claude audits live actor snapshot surfaces; owner reviews R2 and current UX. No gameplay feature implementation simply follows from this ADR.
- **2C.2 — Generation preservation:** Claude owns frozen v1 bundle and explicit two-generator dispatch; Codex independently proves old-world equality and migration/reference safety. R2 and a separate code go-ahead precede source changes.
- **2C.3 — Unified resume checkpoint:** After R3–R6 and explicit go-ahead, Claude owns checkpoint model, scene integration and Save & Exit; Codex owns independent deterministic/fault/relaunch verification; Gemini may contribute presentation on separately assigned scope. Full test and human acceptance R7 close the milestone.

**Decision authority:** This record documents the seven preferences provided directly by the project owner on 2026-11-06. It contains no gameplay implementation, no new test run and no authorization to merge code changes.
