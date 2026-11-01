# Development roadmap

## Current checkpoint — DONE (foundation + first playable loop + combat/relaunch verification)

Phases A–F of the directive are implemented and automated-test verified; the loop in §5.2 runs
end-to-end in the engine (see implementation_status.md). Visuals are placeholders. On 2026-11-01
the project was imported into the GitHub repository as `game/`, re-verified on Godot 4.5.1, and
the two weakest-verified steps (enemy encounter / combat, quit → relaunch → continue) received
automated coverage (62 tests + `check_relaunch`).

## Continuation record — exact next task

**Task:** Manual verification pass on the target machine, then fix what it finds.

1. Open the project in Godot 4.5.1 on Windows, press F5, play the loop once: new game → build →
   map → expedition → fight → gather → survivor decision → return → build → save → quit → relaunch
   → Continue. Confirm the loaded state matches.
2. Run `.\run_tests.ps1 -Godot <path to console exe>` — expect `62 tests, 0 failed` and no
   `SCRIPT ERROR`; then `.\check_relaunch.ps1 -Godot <path>` — expect `RELAUNCH CHECK PASSED`.
3. Record findings in `docs/known_issues.md`.

**Files involved:** everything under `scenes/`, `scripts/interface/`, `scripts/gameplay/exploration/`
(the only layers without automated coverage of feel/visuals).
**Acceptance:** the §5.2 loop completes without script errors; save survives exit + relaunch;
controls feel acceptable (movement speed, attack reach, enemy aggression) or the numbers in
`data/balance.json` / `data/enemies.json` are adjusted.
**Outstanding failures:** none known.

## Next milestones (necessary)

1. **Combat feel** — FSM and hitbox tests exist now; what remains is tuning `balance.json` /
   `enemies.json` from a human play session.
2. **Save during exploration** — persist the active area state (player cell, enemy states,
   gathered nodes) or decide explicitly that expeditions are atomic.
3. **Generation versioning** — keep old generator paths behind `generation_version` so a bump
   never changes an existing universe.
4. **Mist preview leak** — hide uncharted route geometry (straight dashed line).
5. ~~Second decision + faction reactivity~~ — done (Phase 2A, 2026-11-01): the Crown patrol at the
   crossroads / border fort reads Crown standing. Next step for the system: a decision whose
   outcome changes faction–faction relations or territory, and hostile patrols that spawn riders.

## Later (optional / Phase G expansion)

- Walkable Emberfall scene with NPCs; settlement policies (governance trade-offs).
- Real dungeon layout generator for the Sunken Chapel.
- Equipment/inventory, skills, class switching and class abilities.
- Companion model (recruit, permanent death, capture) — data model only exists as empty dicts.
- Faction simulation tick (expansion, war/peace) on the `events` stream; raids after the grace period.
- Universe transfer rules once designed → `TransitionService.execute_transition` new `kind`.
- Pixel-art tiles/sprites replacing `_draw()` placeholders; audio manager when there is audio.
