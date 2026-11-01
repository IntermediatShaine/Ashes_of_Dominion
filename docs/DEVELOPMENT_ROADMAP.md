# Development roadmap

**This is a proposed implementation sequence, not a claim that these features already work.**

## Phase 0 — Existing-code audit and boot

- Import any prior Claude-produced Godot project and tests, preserving its working code and directory layout.
- Confirm Godot executable/version, project entry point, scenes, service scripts and error-free startup.
- Inspect save formats, random streams, world generation and game-state ownership.
- Record actual outcomes in [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md).

**Exit criteria:** A reproducible working baseline, or a specific documented blocker list.

## Phase 1 — Playable vertical slice

- Starting village with UI, direct player controls and three-quarter exploration.
- One deterministic wilderness area with stable story anchors.
- Strategic map, destination selection, route preview and basic fog discovery.
- An enemy encounter with responsive real-time combat.
- Resource pickup, return to settlement and a meaningful upgrade.
- Save/reload that preserves all committed gameplay state.

**Exit criteria:** Play the full expedition loop from start to finish and continue successfully after reloading.

## Phase 2 — Expand the demo

The first-demo design proposes **1 starting village, 3 biomes, 2 active factions, 4 enemy types, 3 archetypes, 1 small dungeon and 4 functional buildings**. Add an initial morality/reputation interaction, difficulty controls and faction awareness after an adjustable grace period.

**Exit criteria:** All included mechanics are demonstrable, with their verification recorded.

## Phase 3 — Deeper connected systems

Explore class evolution, rarer companions, mortality/capture, population and governance, autonomous diplomacy, larger-scale warfare and richer narrative consequences. Multiverse mechanics should follow tested save/resurrection invariants, not precede them.

**Exit criteria:** Mechanic interactions are consistent and save compatibility is demonstrated.

## Cross-cutting testing

- Script/scene import and application boot.
- Fixed-seed terrain and route determinism.
- World-anchor persistence versus generated wilderness variation.
- Combat, pickups, inventory and settlement updates.
- Difficulty and fog options.
- Save/load, backup recovery and reloading after any random outcome.
- Exactly-once multiverse transitions once implemented.

Only mark a test as passed after it is actually executed. Document command, build/commit, expected result and observed result.
