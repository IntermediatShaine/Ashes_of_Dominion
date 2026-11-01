# Claude project entry point

Follow the cross-assistant rules in [`AGENTS.md`](AGENTS.md); they apply to Claude as well.

The original 31-section design is in `docs/GAME_DESIGN.md`. The Godot project is in `game/`
(verified on Godot 4.5.1); `game/docs/` holds the detailed technical docs. Only code that is
committed here counts as existing — do not assume anything from a chat summary.

## When continuing Claude's earlier work

1. Read `docs/AI_HANDOFF.md` and `docs/IMPLEMENTATION_STATUS.md`, then `game/docs/*.md`.
2. Run the checks from `game/` before and after changes: `--import`, `run_tests`, `--quit-after 60`, `check_relaunch`.
3. Preserve working code; bring any architectural changes through small, tested migrations
   (bump `SCHEMA_VERSION` / `CURRENT_GENERATION_VERSION` with a migration and a test).
4. Report concrete changes, actual test evidence, and outstanding gaps.

## Save architecture to preserve if present

Three scopes are implemented and tested in `game/scripts/models/`: persistent `CharacterState`,
resettable `UniverseState`, and `MultiverseState` with resolved resurrection outcomes (stored before
use, so a reload cannot reroll them) and an explicit pending-transition record that `Session.load_slot`
completes exactly once. Keep these invariants when extending; universe *transfer* rules are still undefined.

See `docs/AI_HANDOFF.md` for current handoff context.
