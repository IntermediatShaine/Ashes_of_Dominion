# Ashes of Dominion

> A planned single-player medieval-fantasy action RPG blending direct combat, procedural exploration, settlement management, faction politics, and consequential morality.

**Status:** Design documented. Source code and playable features have **not yet been verified in this repository**. This repository currently contains documentation, not a functioning Godot build.

## Vision

Begin as a survivor of a devastated frontier village. Explore uncertain wilderness, develop a character, build and govern a settlement, and eventually influence the conflicts of entire civilizations. Choices should have lasting consequences, and no prescribed hero/villain path should be required.

**Target:** Windows PC • Keyboard and mouse • 2.5D pixel art • Godot 4 with GDScript (installed engine version to be confirmed).

## Where to start

- [Full game design](docs/GAME_DESIGN.md) — original comprehensive design; conceptual unless identified otherwise.
- [Architecture](docs/TECHNICAL_ARCHITECTURE.md) — proposed boundaries and save-state constraints.
- [Roadmap](docs/DEVELOPMENT_ROADMAP.md) — phased implementation and acceptance criteria.
- [Implementation status](docs/IMPLEMENTATION_STATUS.md) — evidence-based progress tracking.
- [Decisions](docs/DECISIONS.md) — confirmed directions and proposals not yet finalized.
- [AI handoff](docs/AI_HANDOFF.md) — coordination notes for coding assistants.
- [AGENTS.md](AGENTS.md) — shared instructions for AI assistants.
- [CLAUDE.md](CLAUDE.md) — Claude-specific entry point.

## Implementation location

When actual Godot source is added, keep the Godot project root in `game/` unless there is an established existing structure. **Do not add an empty or fake `project.godot`.** Import and audit any code already produced by Claude before changing the architecture.

## Contributing

Work through short, testable changes. For every feature, document what was implemented, which tests were run, what is untested, and any effect on saves, procedural determinism, or prior design decisions.

## License

No license has been selected. The source is not licensed for reuse unless the repository owner explicitly adds a license.
