# Changelog

Significant development changes to **Ashes of Dominion** are recorded here. Do not claim planned mechanics as released features.

## Unreleased

### Added — 2026-11-05 (`feature/stage1-village-foundation`, Stage 1: village architecture and foundation)
- **Walkable village.** Home is now a three-quarter top-down map you walk around: Village
  Hearth, Shelter, Workshop, Stockpile and Watchpost (ruins until rebuilt), four free building
  plots, a gate to the world map. Walk up to anything and press E to see what it is, its level
  and condition, and what can be improved. Uses the expedition scene's player controller.
- **Settlement state and `SettlementService`.** Building levels, condition and sites; a resident
  roster with worker assignments; construction jobs that advance per in-game day; a persistent
  event log; time of day. One service for snapshots, validation, requests and change signals;
  the interface and village objects hold no settlement values.
- **Building levels.** Shelter, hearth, stockpile, workshop and watchpost can be upgraded;
  upgrades and the new buildings take in-game days. Residents can be put to work at the
  Woodcutter's Camp (+1 wood each) and on construction jobs.
- **Village Management** (Overview / Buildings) at the hearth or with **V** — deliberately minimal.
- **Visual registry.** `game/data/visuals/visual_registry.json` maps stable visual ids to
  images; the `Visuals` autoload resolves them; 40 placeholder images; `assets/pixellab/` for
  final art; `ui/themes/village_theme.tres` for the village interface. Art is swapped by editing
  the registry (`game/docs/ART_SWAP_GUIDE.md`). The protagonist is drawn from it everywhere.
- **Shared exploration framework** for hand-authored maps, travel with return destinations and
  persistent per-map state; `lumber_camp`, `ruined_watchtower` and `forgotten_shrine` registered
  as reserved ids (not built).
- **Save schema 2** with a migration from schema 1, tested against a real save from `main`.
- Tests: 84 → **138**, 0 failed on Godot 4.5.1 and on 4.7.2; the relaunch check now also covers
  village state; an exported Linux build was run through the village.

### Changed — 2026-11-05
- The router key `settlement` opens the village; the earlier management screen is kept under
  `settlement_legacy` and is not reachable in play.
- Returning from an expedition puts you at the village gate; after a defeat, by the hearth.
  Continue puts you back where you stood when the game was saved.
- Saving happens from the pause menu in the village, and automatically when work is ordered or
  the night is rested through.

### Not yet included — 2026-11-05
- Nobody has played the village; nothing was run on Windows outside CI.
- The Workshop has no effect yet; no real-time clock; no building damage or wear; the three POIs
  are identifiers only.

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
