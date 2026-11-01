# Claude project entry point

Follow the cross-assistant rules in [`AGENTS.md`](AGENTS.md); they apply to Claude as well.

The original 31-section design is in `docs/GAME_DESIGN.md`. The current repository starter is documentation only: **do not assume the code from previous Claude conversations has already been committed**.

## When continuing Claude's earlier work

1. Inspect the repository tree and identify existing Godot scenes, scripts, services, and tests.
2. Compare that implementation to `docs/TECHNICAL_ARCHITECTURE.md` and `docs/IMPLEMENTATION_STATUS.md`.
3. Preserve working code; bring any architectural changes through small, tested migrations.
4. Report concrete changes, actual test evidence, and outstanding gaps.

## Save architecture to preserve if present

Earlier collaboration discussed three distinct scopes: persistent character record, resettable universe state, and multiverse-level transfer metadata. A deterministic, resumable transfer needs its own pending-transition record and should not permit a resurrection outcome to be rerolled by reloading. Verify actual code before marking these implemented.

See `docs/AI_HANDOFF.md` for current handoff context.
