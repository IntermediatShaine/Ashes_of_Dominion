# Changelog

Significant development changes to **Ashes of Dominion** are recorded here. Do not claim planned mechanics as released features.

## Unreleased

### Added — 2026-11-01 (`feature/import-godot-project`)
- Imported the Godot 4.5 project into `game/` from the owner's `D:\Ashes of Dominion` folder:
  three-scope state, versioned crash-safe saves, deterministic world/wilderness generation, route
  planning with Mist, 8-direction exploration, melee combat with four enemy archetypes, resources,
  one narrative decision, settlement construction, difficulty presets, menus/HUD, 51 tests.
- Verified on the official Godot 4.5.1-stable build: import clean, `62 tests, 0 failed`, boot
  smoke test exit 0.
- `tests/integration/test_enemy_fsm.gd` (7 tests): every enemy state-machine transition driven by
  real physics frames, including dodge, aggro-on-hit, death-once and the rule that patrol
  wandering never touches the persisted combat stream.
- `tests/integration/test_combat_physics.gd` (4 tests): the player's hitbox sweep through the
  real physics path (front hit once, behind untouched, cooldown, invulnerability window, dead
  protagonist cannot move).
- `tools/relaunch_check` + `check_relaunch.sh/.ps1`: save → engine exits → new process → Continue,
  comparing the entire state document field by field.
- Repository docs reconciled with the actual code and test evidence.

### Not yet included
- Manual verification on Windows (nothing has been played by a human).
- The Codex "unified-foundation" project and Claude's M2/M2b/M2.1 packages (outside this repo,
  not inspected).

### Earlier
- Established the central GitHub repository documentation and shared AI development instructions.
- Imported the original comprehensive game design document.
- Added proposed technical architecture, phased roadmap, implementation status and AI handoff records.
