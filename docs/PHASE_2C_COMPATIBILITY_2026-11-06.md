# Phase 2C — Compatibility and test specification (current main)

**Status: SPECIFICATION, NOT EXECUTED TEST RESULTS.** Base: `main` `ea57814c181ce44d97cb77080c1c34e61cce4052`, 2026-11-06. Supersedes the *baseline assumptions* (not the historical record) in [the 2026-11-01 specification](PHASE_2C_COMPATIBILITY_TEST_SPEC.md). Schema is **3**, generation version **1**, and POIs have partial mid-map Save/Continue.

## Verified source contract and uncovered risks

- `UniverseState.to_dict()`: `world_seed` is decimal **string**; `generation_version` is **integer**. `from_dict()` defaults a **missing** generation version to `CURRENT_GENERATION_VERSION`; `validate()` accepts 1..current. If the current constant becomes 2, missing-version saves would incorrectly assume 2. This must be fixed before changing generation.
- `UniverseFactory.create()` stamps `CURRENT_GENERATION_VERSION`. `GameSession._bind()` and `ExpeditionService.build_area()` pass the saved version through.
- `WorldGraphGenerator.generate()` and `WildernessGenerator.generate()` only include the version number in derived seed labels; they **do not dispatch to frozen version-specific algorithms**. Old worlds will change if the algorithm or effective input content changes.
- The current `WorldGraph.fingerprint()` excludes some node/edge metadata; `WildernessMap.fingerprint()` does not fully encode spawn coordinates, NPC runtime decisions, all world modifications or character/enemy runtime. Neither is sufficient alone as a historical compatibility contract.
- Inputs that affect graph/area identity include `data/regions/landmarks.json`, `data/biomes.json`, `data/balance.json` `world_map`, `wilderness`, `expedition`, `data/decisions.json` selection/priority, and resolved decision logs, difficulty `resource_abundance_multiplier`, current day/regrowth values and the historical RNG/hash routines. A new decision can add an NPC to a previously empty area and change reachability repair corridors. Enemy/resource pools and pool ordering also affect actor identities.
- `SaveMigrator` supports **1→2→3**, with real schema-1 and frozen schema-2 fixtures under `game/tests/fixtures/`. No schema-3 complete representative historical fixture or version-1 canonical generation golden data is committed. `test_generation.gd` currently compares repeat invocations with *current* code, not outputs frozen from historical code.
- POI layouts/object IDs in `data/pois.json` are authored, not procedurally derived. Their `MapStateStore.once` and `flags` keys persist across revisions; treat removal/renaming of those IDs, entry locations, or guard definitions as a **separate authored-content compatibility problem**. A generator version bump alone does not protect them.

## Required changes before modifying generation algorithms or generation-affecting data

1. **Freeze a baseline** from the identified main SHA *before* touching generators or generation inputs. Commit a deterministic fixture exporter and goldens with engine build, SHA, source content digests, seed/area/biome/difficulty/decision input values, schema provenance and canonicalization rules. Generate in a fresh process; do not update goldens from changed code simply to make tests pass.
2. **Preserve v1 code and effective content** as an immutable bundle or equivalent versioned tables. The stable hash/PRNG and draw order are part of the contract. Dynamic balance values influencing generation must be pinned; values affecting unrelated combat can be independently tuned.
3. **Add explicit version dispatch to BOTH generators**. Version 1 must run frozen v1 algorithm + data. `CURRENT_GENERATION_VERSION` remains 1 until an intentional v2 algorithm is introduced. If v2 is introduced, new universes use it while older saved universes keep v1 without rerolling.
4. **Decouple schema and generation migrations**. Schemas 1→2→3 must retain `generation_version = 1`; a future schema 4 does not force generation v2. Reject unsupported future/nonpositive generation versions and missing fields in current formats. Only map an omitted version in a positively identified historical schema if a real historical fixture proves that omission existed; never default to latest.
5. **Preserve narrative anchors**: immutable IDs, coordinates, descriptions/required NPC associations, known-at-start states and connectivity assumptions for established worlds. If a story revision intentionally moves an anchor, it needs a separate owner-approved migration with before/after behavior—not merely `generation_version++`.
6. **Validate old references after reconstructing the historical graph**: revealed edges, expedition route edges/nodes, destination IDs, harvested resource keys, defeated actor keys, story/NPC decisions, POI `once` markers and saved map locations. Failed references are controlled, non-destructive errors.
7. **Cross-platform and cross-process regression gate**: v1 fixture output must match pre-change canonical expected output on Windows/Linux Godot 4.5.1, even when v2 code and content have been added; compare 64-bit seed and RNG state **text**, not lossy JSON numeric casts.

### Fixture shape and canonicalization

Use at least these seeds: `0`, `-99`, `20261105`, `9007199254740993` (>2^53). Cover multiple regions/biomes, at least one event NPC and one resolved decision, danger 1 and 3, harvested and regrowth states, and both Mist modes. Include generated areas for `ashen_crossroads` and one other seeded destination, plus the whole world graph.

Canonical record (UTF-8 with sorted object keys and sorted ID-keyed collections) must contain: every persistent landmark id/position/name/biome/known flag/danger; every waypoint id/position; each edge id/endpoints/cost/distance/terrain cost/danger; terrain byte digest (and ideally compressed canonical bytes for diagnosis); spawn and exit; **each resource and enemy spawn's stable key, type, amount, cell**; decision id/cell; repair count; reachable target checks. Record `generation_version`, effective content-bundle digest and historical engine/commit provenance alongside the digest. Never hash unsorted dictionaries or transient node IDs.

Capture three independently readable **save fixtures**: historical schema 1, historical schema 2 (already tracked), and a new schema-3 save with an active POI, location, living and defeated guards, collected resources, in-progress jobs, equipment, six RNG streams, story consequence and pending transition variant. The schema-3 fixture must be created on baseline code and then frozen.

## Generation and migration tests — required

| ID | Setup/action | Pass criterion |
| --- | --- | --- |
| G01 | Generate pinned v1 seed/graph/area in two clean processes | Exact canonical fixture equality, not merely same-run equality |
| G02 | Run the **same v1 fixture after v2 dispatch/code is present** | Every historical v1 coordinate, ID, edge, cost, actor/resource spawn and digest unchanged |
| G03 | Create two v2 universes with identical seed and fixed v2 input (if v2 exists) | Byte/canonical equivalence, all route/area reachability constraints |
| G04 | Compare v1 and v2 worlds for same seed (if v2 exists) | Story anchors unchanged; any generated variation intentionally documented |
| G05 | Load v1 save with harvested key on day 3, load day 5 and day 20 | Same key/resource/amount; depleted then regrown at historical timing, no duplicate haul |
| G06 | Load v1 with revealed edges, selected active route and Mist on/off | Every reference exists in historical graph; estimates/visibility remain correct |
| G07 | Missing, 0, negative or >supported `generation_version` in schema-3, plus actual historical schemas | Controlled error; no fallback to CURRENT, except documented fixture-proven legacy mapping |
| G08 | Migrate real schema-1 and frozen schema-2 fixtures to schema 3 (or later) | Identical seed, v1 generation tag, ancestry, morale, loot, residents, iron, jobs, gear defaults and RNG text; no silent zeroing |
| G09 | Test `0`, `-99`, and >2^53 seed across Linux/Windows official 4.5.1 | Exact decimal seed/RNG-state strings, canonical graph and area outputs |
| G10 | Unresolved decision, then recorded choice; add a new higher-priority decision to latest content | Old v1 decision selection/repair/spawn unchanged; no re-award or geometry change |
| G11 | Load v1 save with existing map/POI `once` flags and authored resource IDs | Stable references, guard deaths/loot and story consequences remain; renames require explicit migration |
| G12 | Change generator or content manifest intentionally | Version 1 fixture remains frozen; v2 different only as approved; manifest drift fails CI |
| G13 | Unknown edge/waypoint/actor key, impossible position or map version in saved checkpoint | Validation/recovery response; source and backup bytes unchanged |
| G14 | Snapshot transfer/recovery with v1 generation | Exactly-once transition; no alteration of generation version or unresolved choice/loot |

## Existing POI acceptance / regression (implemented partially)

| ID | Test to retain or extend | Pass criterion |
| --- | --- | --- |
| P01 | Save/reload inside `lumber_camp` after moving and harvesting | Position, protagonist health, haul and `once` markers exactly restored |
| P02 | Save/reload after guard kill and tower reward | Guard does not respawn or duplicate XP/loot |
| P03 | Save/reload with an **injured living guard** | **Expected gap today:** guard resets; must become exact only after new full-checkpoint contract is approved |
| P04 | Interrupt save write while POI active; retry | One expedition id, no duplicated return/rewards, visible failure |
| P05 | Load old schema-3 POI save after new checkpoint implementation | Old Save/Continue still opens its map; legacy partial behavior handled explicitly, no crash or invented combat snapshot |

P01/P02/P04 have related Stage 2 automated evidence and relaunch coverage. P03/P05 are **not completed feature guarantees**.

## Conditional full-checkpoint acceptance (only if owner approves resumability)

| ID | Setup/action | Pass criterion |
| --- | --- | --- |
| S01 | Move, turn, pause/save, terminate process; Continue | Same area, exact world-space position, facing, health, route, return stack and expedition id |
| S02 | Damage living enemy; leave another dead; pause during patrol | Same stable keys, dead/alive, HP, coordinates, FSM, timers, target/home, private PRNG; no extra spawns |
| S03 | Harvest twice, earn XP/drop, record pending haul | Exactly one claim of each event; same pack/XP, depleted nodes and next draw after reload |
| S04 | Resolve NPC choice, save, reload and revisit | Decision/morality/reputation/once marker applied once; no decision duplication |
| S05 | Script two identical combat sequences, one with save/relaunch | Same next damage, reward, patrol and event RNG draws, including local actor RNG |
| S06 | Save at allowed safe combat boundary; attempt while forbidden windup | Allowed state resumes without cooldown/i-frame reset; forbidden save visibly rejected and previous valid save preserved |
| S07 | Save with pending resurrection transition and active expedition | Recovery resolves once, routes home, does not re-enter defeated scene |
| S08 | Load schema 1/2/3 save with **no checkpoint**, including artificially active wilderness record | Ordinary saves load; legacy active record uses owner-approved non-destructive fallback, no silent replay |
| S09 | Tamper area fingerprint, unknown actor id, out-of-bounds point | Deterministic controlled rejection, no source overwrite, documented recovery options |
| S10 | Repeat save/reload N>=10 times in same active area | No cumulative drift in actors, inventory, counters, clocks, decisions, RNG |
| S11 | Two actual processes: write active generated wilderness, exit, Continue | Scene key is exploration; capture/restored full state identical, including actor runtime |
| S12 | Fault at temp write, readback, backup rotation, primary promotion and final verify | Recover last full valid checkpoint; no mixed scopes, no write-success claim |
| S13 | **Corrupt primary + valid backup**, then perform failing/succeeding new write | Valid backup cannot be silently destroyed before replacement is durable; recovery always available |
| S14 | Measure save time/size/pause latency on owner-approved Windows PC | Recorded p50/p95 and file size meet **approved** limits or fail release gate |

Additional variant rows must cover enemy movement on restore, event signals during scene initialization, colliding saved player position after a map change, quest flags, return/retreat/defeat, optional future companions, resource regrowth timing and the absent/invalid save-slot distinction.

## Test execution and proof

- **Pre-change main baseline:** import, full suite, deterministic fixture export, 60-frame headless boot, two-process relaunch, and reproducible baseline fixture hashes.
- **CI/after change:** use `game/run_tests.ps1` and `game/run_tests.sh`, the strict `tools/verify.*` runners, `check_relaunch.*`, Windows/Linux Godot 4.5.1 and a new active-wilderness two-process checkpoint harness. Protect against import failures, missing completion markers and stderr diagnostics; no false green on zero tests.
- **Real faults:** tests must inject failures at actual `SaveRepository` filesystem stages. Existing Stage 2 `FailedWrites` only returns a mocked error and does **not** prove backup safety.
- **Owner manual acceptance:** play a long route with combat and interruption, reload at exact spot, verify restored actors and no loot exploit, and exercise visible error/recovery UX. Headless tests cannot prove this.
- **Evidence format:** commit SHA, Godot exact version/platform, commands, observed counts, fixture digests, failure-injection stages, warnings, full-state comparisons and untested claims; link PR CI runs. No new tests have been run by this document.

## Required versus optional

**Required before generator changes:** historical v1 goldens, immutable effective v1 inputs, both-generator version dispatch, explicit missing/unsupported generation handling, reference integrity, cross-version tests and anchor verification. **Required only after approving full checkpoints:** snapshot DTO/schema migration, actor capture/restore, fault-safe save boundary, S01–S14 tests and manual acceptance. **Required now for honest documentation:** label current POI saves partial and generated wilderness atomic.

**Optional later:** compression, chunk-specific deltas, full event sourcing, deterministic visual replay, automated content-manifest tooling, safe historical generator retirement policy and new engine-pin migration. None replaces v1 preservation.
