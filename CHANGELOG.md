# Changelog

Significant development changes to **Ashes of Dominion** are recorded here. Do not claim planned mechanics as released features.

## Unreleased

### Engineering — Phase 2B (2026-11-01)
- Hardened PowerShell/Bash test and relaunch wrappers with import checking, strict completion
  evidence, isolated application data and optional retained logs.
- Added Godot 4.5.1 Linux/Windows GitHub Actions and deliberate harness failure-injection checks.
- Local Windows verification: 66 game tests pass; 20 controlled harness cases behave correctly.
  Exact commands and hosted verification status are in `docs/TESTING_AND_CI.md`.
### Added — 2026-11-01 (`feature/second-decision-reputation`, Phase 2A)
- Second narrative encounter, **the Crown patrol**, at the Ashen Crossroads and the Aurel Border
  Fort (after the survivor): escort (Friendly only; +morality, +Crown, −Legion, iron), trade
  (rations, +Crown), bribe (spends iron), defy (−Crown, +Legion, a deserter recruit), fight
  (Distrusted only; wound, −Crown, −morality, a looted blade).
- Faction reactivity in the decision system: `requires_reputation` option gates (shown disabled
  with the reason, or hidden with `hide_when_blocked`), `prompts_by_reputation` prompt variants,
  `health` effects, `npc_color` / `npc_prompt` per decision. Thresholds follow the existing
  Friendly / Neutral / Distrusted bands.
- Data-driven per-area decision selection (`DecisionRules.select_for_area`: biome, optional
  `appears_at_landmarks`, `priority`), replacing first-by-id; content validation for decision
  references.
- `tests/unit/test_decisions.gd` (9) and `tests/integration/test_crown_patrol.gd` (3); suite now
  78 tests.

### Fixed — 2026-11-01 (`codex/issue-3-mist-preview`)
- Prevented selected uncharted routes from revealing hidden intermediate waypoint geometry.
- Added four renderer regression tests; 66 tests pass on Windows Godot 4.5.1 headless, with
  successful import, boot and save/relaunch checks. No schema or generator changes.
- Inventoried the recovered v0.3.1-m1 archive without merging it; see `docs/CODEX_ISSUE_3_AUDIT.md`.

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
