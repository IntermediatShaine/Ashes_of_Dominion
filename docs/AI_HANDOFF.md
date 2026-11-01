# AI collaboration handoff

## Project and source of truth

**Ashes of Dominion** is a planned Windows Godot/GDScript game with a comprehensive specification in `GAME_DESIGN.md`. Shared work between Claude, ChatGPT and other coding agents should be committed here rather than relying on separate conversation memories.

## Prior Claude work (user-provided account, not GitHub-verified)

A past Claude response reported it had completed initial data models and core services and was beginning menus. It considered seeded generation, versioned crash-safe saves with backup, data-driven settings and layered architecture compatible with a v0.3 addendum. It also said it was splitting a flat session model into three scopes:

- **Character:** identity, ancestry, XP/level, attributes, skills, lore, permanent unlocks, class unlocks, morality and character flags.
- **Universe:** world seed/layers, settlement (population, buildings, stockpile), faction/NPC relations, territory, NPC and world-event states, threat, expedition log, in-game day and companions, with distinct combat/rewards/events random streams.
- **Multiverse:** natural and forced transfer counts, already-resolved resurrection outcomes, plus pending transition metadata.

**Do not treat these statements as verified implementation.** The actual Claude source and full addendum were not present in this repository on 2026-11-01. The narrative may evolve when those materials are imported and audited.

## Next action for any AI assistant

1. Read `AGENTS.md`, the game design, decisions and implementation status.
2. Check the actual repository tree for Godot files before generating or refactoring anything.
3. If previously produced source exists outside GitHub, import it intact and perform a baseline audit.
4. Run only available tests and report actual outcomes.
5. Implement the smallest complete playable slice after confirming architecture and compatibility.
6. Update this file and `IMPLEMENTATION_STATUS.md` with concrete commit/test evidence.

## Handoff record template

- Date and commit/branch:
- Files changed:
- Working behavior:
- Test commands and observed results:
- Untested behavior or known limitations:
- Save/schema/determinism implications:
- Decisions requiring owner review:
- Next smallest actionable change:
