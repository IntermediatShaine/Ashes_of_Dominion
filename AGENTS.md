# Repository-wide AI development instructions

This repository is the **source of truth** for the Ashes of Dominion project. Read `README.md`, `docs/GAME_DESIGN.md`, `docs/DECISIONS.md`, `docs/TECHNICAL_ARCHITECTURE.md`, `docs/IMPLEMENTATION_STATUS.md`, and `docs/AI_HANDOFF.md` before major changes.

## Evidence and communication

- Separate **design intent**, **implemented code**, and **tested behavior**. Never claim functionality exists merely because it appears in the GDD or a chat summary.
- Before changing existing code, inspect its current structure and avoid breaking stable behavior.
- Do not invent project state or imply a test passed without executing it.
- If requirements are unclear, propose bounded options and record accepted decisions.
- Keep implementation status and handoff notes updated as code is added.

## Technical principles

- Target Godot 4 / GDScript on Windows. Verify the actual installed Godot version and project configuration rather than assuming a version.
- Favor modular, data-driven content definitions and small interfaces.
- Persist state deterministically; never use nondeterministic global RNG in seeded gameplay systems.
- Separate long-lived character identity/progression from per-universe state and multiverse transition metadata once those mechanics are implemented.
- Protect saves with versioning, validation, and crash-safe write/backup paths; test reload invariants and deterministic world generation.
- Keep critical story anchors persistent while allowing seeded wilderness, routes, resources, and encounter details to vary.
- Morality and faction reputation must remain distinct concepts.
- No large untested rewrites. Prefer incremental changes and explicit migration steps.

## Workflow for changes

1. State the intended change and the files touched.
2. Inspect relevant code and docs.
3. Implement the smallest complete slice.
4. Run available checks; report their exact commands and outcomes.
5. Update `docs/IMPLEMENTATION_STATUS.md` and `docs/AI_HANDOFF.md` if the state changed.
6. Explain next steps and unresolved risks.

## Demo focus

Complete a playable expedition loop: settlement → world map/route → exploration → encounter/combat → resources → return → upgrade → save/reload. Resist expanding into full game systems before the core loop works.
