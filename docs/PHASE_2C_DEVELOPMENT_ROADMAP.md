# Phase 2C — Three-milestone development roadmap (PROPOSED)

> **Current-main update (2026-11-06):** This is a historical Phase 2C proposal based on the 2026-11-01 schema-1 baseline. Merged Stage 1/2 PRs subsequently introduced schema 3 and partial POI Save/Continue. Refer to the [2026-11-06 reassessment](PHASE_2C_ROADMAP_2026-11-06.md) for actionable architecture and tests. This historical proposal never constituted owner approval to implement a save policy.


**Base:** main aec6ce9, 2026-11-01. **Approval gate:** owner accepts or changes ADR-2C-A before gameplay work begins. The authoritative Godot project remains game/. No old external package is to be merged as the project root.

## Repository review and coordination

- PR #1 (Claude, merged): imported Godot project, physics enemy/combat tests, cross-process relaunch check. PR #2 (merged): Codex onboarding. PR #4 (Codex, merged): fixed Mist route-preview geometry and added 4 renderer integration tests; Codex reports 66 tests, 0 failures on Windows Godot 4.5.1. Issue #3 was closed by #4. At this review, no open PRs or issues were returned.
- Existing code: schema-1 three-scope saves, generated area rebuilt on scene entry, idempotent expedition/transition logic and persisted runtime RNG streams. No resume checkpoint or historical generation dispatch. Manual gameplay acceptance is still unverified.
- Codex's separately recovered v0.3.1-m1 archive was compared statically in docs/CODEX_ISSUE_3_AUDIT.md. Its format-2 nested-session saves and character-owned health conflict with current schema-1 three-scope saves; archive tests were not rerun. Do not replace game/ or copy its save format. Claude M2/M2b/M2.1 external packages remain unverified/unreconciled.

## Milestone 2C.1 — Decision, baseline and historical fixtures

**Priority P0. Owner:** choose atomic vs resumable; pause-only vs other save triggers; active-combat save rule; legacy active-save recovery behavior; reference performance budgets. **Claude:** supply owner-side Windows manual run for the current vertical slice and log concrete UX findings; do not start unapproved checkpoint work. **Codex:** build a deterministic v1 *fixture exporter* and tests against the existing graph/area code; audit crash-stage failure-injection capability and current wrapper import exit handling. **ChatGPT/owner:** review ADR, reconcile documentation status and create implementation issues only after approval.

**Deliverables:** signed-off decision record; historical v1 goldens with baseline SHA/engine/content inputs; engine test evidence and manual-report checklist; isolated tooling/regression PR(s). **Exit:** v1 fixtures reproduce from main, main remains green, target behavior approved or explicitly deferred. **Non-goals:** generator changes, gameplay snapshot and unreviewed v0.3.1 import.

## Milestone 2C.2 — Preserve v1 generation while introducing extensibility

**Dependency:** 2C.1 goldens and approval of content-version strategy. **Claude (primary):** implement dispatch for both generators and pin the v1 generation input bundle; keep old schema-1 saves reconstructing identically. Clarify generation_version validation (do not default missing to newest). If a genuine v2 is introduced, bump CURRENT_GENERATION_VERSION only after v1 assertions pass. **Codex (independent):** cross-version fixture tests, story-anchor assertions, old-save/route/harvest regression cases and review of every generation-contract diff. **Owner:** review map/landmark examples.

**Expected touched code:** game/scripts/generation/world_graph_generator.gd, wilderness_generator.gd, game/scripts/services/game_session.gd, game/scripts/gameplay/world/expedition_service.gd, game/scripts/models/universe_state.gd, optional versioned generation data and tests. **File coordination:** only one assistant edits shared production generator files per branch; Codex works from a distinct test/tool branch, rebases after Claude merges. **Exit:** v1 is identical to golden fixtures after v2-capable dispatch; new generation is deterministic; unsupported versions fail safely; no save-schema upgrade unless justified.

## Milestone 2C.3 — Bounded mid-expedition persistence (conditional)

**Dependency:** owner selects resumable and 2C.2 has passed. **Claude (primary):** introduce a versioned checkpoint DTO in the active ExpeditionRecord, schema migration, scene capture/restore, Session Continue routing, stable actor keys and user-visible Save & Exit. Snapshot positions, health, combat phase/timers, enemy FSM/HP/positions/local patrol RNG, resource depletion, NPC decision state and existing universe/character/multiverse state atomically. Coordinate transition recovery first. **Codex (independent):** fault injection at write stages, migration fixtures, deterministic no-reload vs resumed comparison, two-process active-expedition relaunch test and PR review. **Owner:** play on Windows; validate control feel, restored map/actors, interruption recovery and save-time UX.

**Expected touched code:** game/scripts/models/expedition_record.gd, universe_state.gd, save_game.gd; persistence/save_migrator.gd, save_validator.gd, save_repository.gd; gameplay/exploration/*.gd, services/game_session.gd, interface/main_menu.gd, load_game_menu.gd, exploration_hud.gd; tests/persistence, tests/integration and relaunch tools. **File coordination:** Claude owns integrated feature branch; Codex does not simultaneously edit Session/ExpeditionRecord/SaveRepository. Deliver independent test changes first or after the feature branch is ready; avoid parallel conflicting PRs.

**Exit:** all S01–S12 scenarios with documented results, no unearned re-rolls/duplication, backup recovery demonstrably safe, clean Godot import and full suite, active-expedition Continue in a fresh engine process, owner manual pass. **Fallback if owner chooses atomic:** no checkpoint/schema migration; instead clearly enforce save-at-settlement and loss of unsaved trip, add explicit abandon confirmation and crash/relaunch tests, document this as a chosen rule.

## Coordination rules and documentation debt

- One PR per bounded workstream; each PR lists baseline commit, code files, invariants, migrations, executed commands/results and untested claims. Neither assistant force-pushes or replaces game/.
- **Outdated:** root README and docs/CODEX_HANDOFF.md still advertise 62 tests / first Codex task; game/docs/development_roadmap.md still lists Mist fix as upcoming; game/docs/implementation_status.md is an older 62-test baseline (its historical evidence may be retained but labelled). docs/AI_HANDOFF.md and docs/DECISIONS.md contain earlier historical statements that the external archive was inaccessible, qualified by later Codex audit; add a clear superseding note.
- Current 66-test result is a **reported Codex run from PR #4**, not retested during this documentation review. No human play on Windows has been recorded.
- File-level v0.3.1-m1 reuse candidates are limited to test runner APPDATA/import propagation, raw physical input tests, and a separate study of detached save transactions. Treat all as proposals and independently verify before porting.
- A follow-on workstream for second decision / faction-relation consequences remains lower priority than persistence correctness; it should not share generator or save-model edits in parallel.
