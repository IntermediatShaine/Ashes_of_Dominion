# Ashes of Dominion

> A planned single-player medieval-fantasy action RPG blending direct combat, procedural exploration, settlement management, faction politics, and consequential morality.

**Status:** Design documented; a **first playable vertical slice** lives in [`game/`](game/) (Godot 4.5.1,
GDScript, placeholder visuals). The full expedition loop — walkable village → map → route → seeded wilderness →
8-direction movement → combat → resources → return → construction → save → relaunch → continue — is
covered by automated tests and a two-process relaunch check. Full manual gameplay
acceptance has not yet been completed.
See [implementation status](docs/IMPLEMENTATION_STATUS.md) for the evidence.
Godot 4.5.1 Linux/Windows CI and harness failure-injection results are documented in
[testing and CI](docs/TESTING_AND_CI.md).

## Vision

Begin as a survivor of a devastated frontier village. Explore uncertain wilderness, develop a character, build and govern a settlement, and eventually influence the conflicts of entire civilizations. Choices should have lasting consequences, and no prescribed hero/villain path should be required.

**Target:** Windows PC • Keyboard and mouse • 2.5D pixel art • Godot 4 with GDScript (verified on 4.5.1-stable).

## Download and play — no Godot installation required

**[Download Ashes of Dominion (Windows 64-bit)](https://github.com/IntermediatShaine/Ashes_of_Dominion/releases/download/preview/Ashes-of-Dominion-Windows-x64.zip)**

[Download for Linux x86_64](https://github.com/IntermediatShaine/Ashes_of_Dominion/releases/download/preview/Ashes-of-Dominion-Linux-x64.zip) · [All game releases](https://github.com/IntermediatShaine/Ashes_of_Dominion/releases)

These links point to the latest successfully built **preview** (prototype). **The first downloads appear once the distribution workflow has passed and published its initial release.** Download the ZIP, extract **all** files, and run `AshesOfDominion.exe` on Windows or `AshesOfDominion.x86_64` on Linux. Keep the adjacent `.pck` file in the same directory. No separate installer or Godot editor is needed. Windows may warn about an unsigned executable; Linux may need `chmod +x AshesOfDominion.x86_64`.

The preview is unfinished and not yet validated by a full human playthrough. See [distribution and releases](docs/DOWNLOADS_AND_RELEASES.md) for build checks and versioned releases.

## Running from source (developers)

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
- [Codex onboarding](docs/CODEX_HANDOFF.md) — setup and completed first assignment.
- [Downloadable builds and releases](docs/DOWNLOADS_AND_RELEASES.md) — player downloads, automated export, release verification.
- [Phase 2C proposals](docs/PHASE_2C_ARCHITECTURE_PROPOSAL.md) — owner-pending persistence decision, compatibility tests and roadmap.
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
