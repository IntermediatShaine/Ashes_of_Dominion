# Phase 2C — Three-milestone development roadmap (current-main reassessment)

**Status: PROPOSED / NOT AN IMPLEMENTATION AUTHORIZATION.**  
**Review baseline:** `main` `ea57814c181ce44d97cb77080c1c34e61cce4052` (2026-11-06); **authoritative project:** `game/`; **schema:** 3; **generation:** 1. Historical [Phase 2C roadmap](PHASE_2C_DEVELOPMENT_ROADMAP.md) describes the 2026-11-01 schema-1 baseline and should not be given verbatim to developers.

## Repository and cross-assistant coordination audit

| PR / issue | Actual status on 2026-11-06 | Dependencies and effects |
| --- | --- | --- |
| [#6 Phase 2C proposal](https://github.com/IntermediatShaine/Ashes_of_Dominion/pull/6) | **Merged, docs-only, not approved ADR** | Based on schema 1; its future schema 1→2 plan is obsolete after Stage 1/2 |
| [#10 Claude Stage 1](https://github.com/IntermediatShaine/Ashes_of_Dominion/pull/10) | **Merged** | Walkable village, map framework, `MapLocation`, `SettlementService`, visual registry, schema **2** |
| [#11 Codex Stage 2](https://github.com/IntermediatShaine/Ashes_of_Dominion/pull/11) | **Merged** | Schema **3**; 3 POIs; `PoiRules` and `MapStateStore.once`; POI Save/Continue; no live actor checkpoint |
| [#12 Phase 2B reverification](https://github.com/IntermediatShaine/Ashes_of_Dominion/pull/12) | **Merged**, current `main` head | Documentation-only; reported fresh local Windows Godot 4.5.1 157/157, Mist 4/4, two-process relaunch and 20/20 failure-harness cases |
| [#4 Mist fix](https://github.com/IntermediatShaine/Ashes_of_Dominion/pull/4) / [issue #3](https://github.com/IntermediatShaine/Ashes_of_Dominion/issues/3) | **Merged / closed** | Route preview no longer leaks hidden waypoint geometry; not an open task |
| Open PRs / issues | **None found at review time** | Create focused tasks only following owner approval or for independent test/fixture scaffolding |

All four reviewed recent PRs had no recorded inline review threads/review submissions returned by the connector; absence of review comments is not a claim of human acceptance. Current `main` code was read directly, not inferred solely from PR descriptions.

### Already implemented and tested (reported evidence)

- Save schema 1→2→3 migrations and three state scopes; current code records `generation_version = 1`.
- Stable expedition IDs, haul/once-marker accounting, resurrection outcome and pending transition resolution.
- Village and current POI location Save/Continue; 19 Stage 2 acceptance tests; 157/157 last reported Windows local run; a whole-document two-process POI relaunch test.
- Fixed Mist preview, independent six RNG streams, and strict Windows/Linux CI runners.
- Generation is deterministic for repeated same-code invocations, **not guaranteed against future generator/content changes**.

### Not implemented or verified

- Full generated-wilderness Save & Exit / actor runtime checkpoint; stable recovery after partially damaged enemies, facing, timers or attack phases.
- Version-dispatched frozen v1 graph/area algorithms and immutable historical generation inputs; historical canonical generation goldens.
- Real fail-at-each-filesystem-stage backup safety; owner-accepted checkpoint performance targets.
- Full faction AI, companion runtime, army systems, Stage 3 final dashboard, human play acceptance. Do not infer these from planned content.
- A new Linux/Windows CI run for the precise `ea57814` tree is not established by the PR #12 local rerun; historical cross-platform CI results remain valuable evidence but are not current-tree verification.

## Milestone 2C.1 — P0: Decision gate and freeze the working baseline

**Preconditions:** work from `main` `ea57814` or newer verified head; no unapproved gameplay policy change.

**Owner:** decide or explicitly defer A1–A7 in the [architecture proposal](PHASE_2C_ARCHITECTURE_2026-11-06.md): atomic vs resumable wilderness, save trigger, active-combat rule, legacy active record recovery, performance hardware/budget, generation bundle strategy and current POI partial-save messaging. Record decisions in `docs/DECISIONS.md` with date, rationale and affected systems. Play the current Windows village→POI→wilderness loop and report controls/interruptions.

**Codex, primary for isolated test tooling:** make an approved, test-only branch to export frozen `generation_version=1` world/area goldens with source and content hashes. Add schema-3 baseline fixtures, same-seed canonical comparisons, 64-bit and multi-process checks; investigate `SaveRepository` corrupt-primary/valid-backup rotation and add *real staged fault-injection tests* without changing save semantics until review. Preserve `game/tests/fixtures/save_schema1_main_eaadfdf.json` and `save_schema2_stage1_migrated.json`.

**Claude:** audit exact runtime capture needs in `PlayerController`, `EnemyController`, generated `ExplorationController` and `PoiController`. Propose stable actor keys and a save-boundary protocol; **do not begin checkpoint code** until A1–A4 are accepted. Coordinate with Codex to avoid both editing tests/persistence at the same time.

**Deliverable/exit:** owner choice is recorded or marked pending; frozen v1 fixtures reproduce against baseline; latest test suite passes and fixture provenance is auditable; crash-stage risk has a test report. **Files:** mostly `game/tests/deterministic/*`, `game/tests/fixtures/*`, `game/tests/persistence/*`, new test utilities, docs. No change to generator algorithms or save schema in this milestone.

## Milestone 2C.2 — P0: Historical generation compatibility

**Dependency:** 2C.1 v1 goldens; approved immutable input bundle/versioning approach. **Order matters:** freeze v1 *before* introducing v2 or altering world content.

**Claude, production owner:** introduce explicit version dispatch in `game/scripts/generation/world_graph_generator.gd` and `wilderness_generator.gd`, pin all effective v1 generation inputs (including decisions affecting NPC spawn/repair) and maintain story anchors. Update `UniverseState.from_dict`/validation to reject missing or unsupported generation versions instead of defaulting to latest. Keep `UniverseFactory`, `Session._bind`, `ExpeditionService.build_area` using the save's historical generator version. Do **not** set `CURRENT_GENERATION_VERSION = 2` unless a deliberate new algorithm or input contract actually exists.

**Codex, independent reviewer:** add G01–G14 coverage, Windows/Linux historical fixture comparisons and adversarial old-save tests for routes/harvest/decision placement and unsupported future version. Review any generator/content semantic diff and certify v1 unchanged against locked fixtures; avoid overlapping production generator files.

**Owner:** verify persistent landmark examples and sign off on any intentional v2 changes. **Deliverable/exit:** v1 exact-match digests and anchor/route integrity remain invariant with new dispatcher; current new-world generation is deterministic; old schema-1/2/3 saves retain v1; CI checks pass. **No automatic save-schema bump solely for generator dispatch.**

**Expected production overlaps:** `world_graph_generator.gd`, `wilderness_generator.gd`, `universe_state.gd`, `game_session.gd`, `expedition_service.gd`, `data/landmarks/biomes/balance/decisions` (only if required and with version bundles). One assistant owns these production changes in one active branch.

## Milestone 2C.3 — P1: Owner-selected save behavior

**Dependency:** approved A1–A7 and completed 2C.2. **Two mutually exclusive branches; do not silently choose.**

### If resumable wilderness is approved (recommended)

**Claude:** implement a versioned checkpoint DTO on the active expedition, schema **3→4** migration only if the stored layout changes, stable enemy/player runtime serialization, consistent physics-boundary capture, exact scene restore, pending-transition-first routing and one-transaction save. Reuse `MapLocation` and `MapStateStore` instead of another global world-state owner. Harmonize POI autosaves with the same contract. Ensure state is restored before AI/physics/RNG-driven initialization. Coordinate save-file failure handling with Codex's independent tests.

**Codex:** author S01–S14 and P01–P05 independent tests, real write-stage fault injection, no-reload vs restarted RNG equivalence and two-process *generated-wilderness* active checkpoint verification. Audit repeat reward prevention, historical migrations, invalid generated fingerprints and pending resurrection. Review Claude's PR rather than concurrently rewriting `Session`, `SaveRepository` or actors.

**Owner:** human Windows Save & Exit + Continue, active combat restriction, long expedition, crash recovery, actor HP and exact-map restoration; accept measured p95 latency/size on selected hardware.

**Exit:** approved policy is correctly visible, old saves remain loadable, all required S tests pass with results recorded, no duplicate rewards/transitions, engine import/boot/relaunch and CI are green, manual acceptance performed.

### If atomic wilderness is approved

**Claude:** do not add a checkpoint or bump schema for this policy. Enforce only the supported save boundaries, label generated-wilderness abandon and interruption consequences visibly, add confirmation/recovery UX and do not imply active wilderness can be continued.

**Codex:** regression-test POI exception, settlement save boundary, crash/backup behavior and generated trip abandonment. **Owner:** accept the intended short-expedition risk/commitment loop. Document that generated wilderness stays atomic by explicit decision.

**Exit:** comprehensible save boundaries, deterministic retry/recovery, no lost/duplicated committed state and owner manual acceptance. Full checkpoint S-series is not required on the atomic branch.

## Collision map and handoff rules

| Touching subsystem | Already changed in | Future single owner / conflict prevention |
| --- | --- | --- |
| `save_game.gd`, `universe_state.gd`, `save_migrator.gd`, `game_session.gd` | Both #10 and #11 | Claude owns any checkpoint migration; Codex fixture tests in separate PR after branch is ready |
| `expedition_service.gd`, `exploration_controller.gd`, `enemy_controller.gd` | Both #10 and #11 touched relevant gameplay | Claude owns runtime capture/restore; Codex test/review only until integration merges |
| `map_scene_base.gd`, `map_location.gd`, `map_state_store.gd`, `poi_controller.gd` | #10 framework and #11 POIs | Do not invent a separate POI save authority; owner assigns all map-capture integration together |
| `world_map_screen.gd`, `main_menu.gd`, `load_game_menu.gd`, `village_hud.gd` | Mist #4, village #10, POIs #11 | Gemini Stage 3 presentation must rebase before checkpoint UI; coordinate routed scene changes |
| `save_repository.gd`, tests, relaunch tools | #5 strict harness, #10/#11 fixture and relaunch updates | Codex owns isolated fault/fixture tools; production repository behavior changes reviewed jointly |
| `data/decisions.json`, `data/biomes.json`, `data/balance.json`, `data/regions/landmarks.json` | #7 narrative, #10/#11 economy | Freeze generation-affecting inputs for v1; no parallel content changes until manifest contract is verified |

All work uses separate branches and bounded PRs from current main. No force-push to main or wholesale replay of another assistant's branch. PR descriptions must separate code *implemented*, checks *actually executed*, and tests/UI *unverified*. Rebase dependent work after main changes; rerun migrations and fixed seeds after every shared-file edit. PRs #10/#11/#12 are already merged, so the table represents **future collision risks**, not unresolved merge conflicts in those historical PRs.

## Separate Codex v0.3.1-m1 comparison (do not replace `game/`)

The [issue #3 audit](CODEX_ISSUE_3_AUDIT.md) recovered the `AshesOfDominion-unified-foundation.zip` archive and **statically** compared its `AoD/` source. Archive tests were not rerun. Its **format-2 nested session** and **character-owned health** conflict with the current **schema-3 three-scope state** and **universe-owned health**. The archive is not a save migration input or replacement root.

Review specific ideas only if still valuable: raw physical-key tests; detached-candidate save transaction; fault-resistant runner techniques. Note that many runner protections have **already** been implemented in PR #5 and the walkable village is **already** in PR #10; an older roadmap that recommends importing those wholesale is outdated. External Claude M2/M2b/M2.1 packages remain a separate unverified historical line. Any proposed reuse requires a file-level mapping, a compatibility plan and its own approved, tested PR.

## Documentation debt (tracked for later, not permission to alter gameplay)

- Original `docs/PHASE_2C_*.md` assume schema 1, nonexistent POI save support and a 66-test baseline; label as historical and link this current reassessment.
- `game/docs/game_state.md` schema table documents only 1→2 and calls equipment unimplemented; add schema-3 and POI state detail in a later bounded documentation update.
- `docs/TECHNICAL_ARCHITECTURE.md` and `docs/DEVELOPMENT_ROADMAP.md` contain 2026-11-01 historical statuses; prominent current pointers are needed.
- `docs/CODEX_HANDOFF.md` says older Codex archive was not inspected; [the later audit](CODEX_ISSUE_3_AUDIT.md) supersedes that sentence. Its old Mist task is already completed.
- `game/docs/known_issues.md` retains old 'no save during exploration' language below a Stage 2 supersession notice; distinguish generated wilderness from POIs clearly.
- `docs/IMPLEMENTATION_STATUS.md` has a long historical system table still describing schema 1/2 and nonexistent equipment; its newer top and 2026-11-06 bottom evidence takes precedence. Keep historical evidence, add an unambiguous current summary.
- `docs/AI_HANDOFF.md` includes date-scoped historical statements; latest Stage 2 and 2026-11-06 updates take precedence.
- Preserve `docs/GAME_DESIGN.md` as design intent: it requires reliable persistence and familiar story anchors but **never approved an atomic or resumable save rule**.

See [current architecture proposal](PHASE_2C_ARCHITECTURE_2026-11-06.md) and [compatibility/test scenarios](PHASE_2C_COMPATIBILITY_2026-11-06.md). None of these documents authorizes a production code change without owner approval.
