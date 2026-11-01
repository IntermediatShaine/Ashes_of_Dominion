# Ashes of Dominion

> A planned single-player medieval-fantasy action RPG blending direct combat, procedural exploration, settlement management, faction politics, and consequential morality.

**Status:** Design documented; a **first playable vertical slice** lives in [`game/`](game/) (Godot 4.5.1,
GDScript, placeholder visuals). The full expedition loop — village → map → route → seeded wilderness →
8-direction movement → combat → resources → return → construction → save → relaunch → continue — is
covered by 62 automated tests and a two-process relaunch check. It has **not yet been played by a human**.
See [implementation status](docs/IMPLEMENTATION_STATUS.md) for the evidence.

## Vision

Begin as a survivor of a devastated frontier village. Explore uncertain wilderness, develop a character, build and govern a settlement, and eventually influence the conflicts of entire civilizations. Choices should have lasting consequences, and no prescribed hero/villain path should be required.

**Target:** Windows PC • Keyboard and mouse • 2.5D pixel art • Godot 4 with GDScript (verified on 4.5.1-stable).

## Running the game

1. Install [Godot 4.5.1](https://godotengine.org/download) (standard build, no .NET needed).
2. Godot → **Import** → `game/project.godot` → **Import & Edit**, then **F5**.
3. Tests, from `game/`: `.\run_tests.ps1 -Godot <godot_console.exe>` (or `./run_tests.sh <godot>`),
   and `.\check_relaunch.ps1 -Godot <godot_console.exe>` for the save → quit → relaunch → continue check.

Controls and the full layout are in [`game/README.md`](game/README.md).

## Where to start

- [Full game design](docs/GAME_DESIGN.md) — original comprehensive design; conceptual unless identified otherwise.
- [Architecture](docs/TECHNICAL_ARCHITECTURE.md) — proposed boundaries and save-state constraints.
- [Roadmap](docs/DEVELOPMENT_ROADMAP.md) — phased implementation and acceptance criteria.
- [Implementation status](docs/IMPLEMENTATION_STATUS.md) — evidence-based progress tracking.
- [Decisions](docs/DECISIONS.md) — confirmed directions and proposals not yet finalized.
- [AI handoff](docs/AI_HANDOFF.md) — coordination notes for coding assistants.
- [Codex onboarding](docs/CODEX_HANDOFF.md) — Codex Cloud setup and its first audit/fix assignment.
- [AGENTS.md](AGENTS.md) — shared instructions for AI assistants.
- [CLAUDE.md](CLAUDE.md) — Claude-specific entry point.

## Implementation location

The Godot project root is `game/`. Its own documentation (`game/docs/`) is the detailed technical
reference: architecture, state scopes, technical decisions, known issues, roadmap. Keep rules out
of scene scripts and keep the tests green; see [AI handoff](docs/AI_HANDOFF.md) for the working rules.

## Contributing

Work through short, testable changes. For every feature, document what was implemented, which tests were run, what is untested, and any effect on saves, procedural determinism, or prior design decisions.

## License

No license has been selected. The source is not licensed for reuse unless the repository owner explicitly adds a license.
