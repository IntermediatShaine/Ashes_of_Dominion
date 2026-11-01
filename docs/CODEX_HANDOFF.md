# Codex onboarding and first assignment

## Purpose

Codex joins Claude and ChatGPT as a coding/review assistant for **Ashes of Dominion**.
The [GitHub repository](https://github.com/IntermediatShaine/Ashes_of_Dominion) is the shared
source of truth. Codex reads root [`AGENTS.md`](../AGENTS.md) automatically. This file is
additional context and a suggested first task, **not** a substitute for connecting the repo
to Codex or creating a Codex Cloud environment.

## Authoritative implementation

- Godot project root: `game/` — open `game/project.godot`.
- The imported implementation was tested with **Godot 4.5.1-stable**, not Godot 4.7.2.
- The latest Phase 2B checkpoint (2026-11-01) reported **66 tests, 0 failures** on Linux/Windows CI,
  successful headless import/boot, and a two-process save/relaunch check.
  **Those are historical results, not a fresh Codex test run.**
- Phase 2B hardened the wrappers and added CI/failure-injection checks. Current commands,
  isolation behavior and verified workflow links: [`TESTING_AND_CI.md`](TESTING_AND_CI.md).
  The original Mist assignment below is completed in PR #4.
- A first expedition-loop prototype exists, with placeholder artwork. Manual Windows gameplay
  remains unverified. Read [`IMPLEMENTATION_STATUS.md`](IMPLEMENTATION_STATUS.md) for evidence.

Read before editing, in this order:

1. `AGENTS.md`, `README.md`, `docs/AI_HANDOFF.md`, `docs/IMPLEMENTATION_STATUS.md`.
2. `docs/GAME_DESIGN.md`, `docs/DECISIONS.md`, `docs/TECHNICAL_ARCHITECTURE.md`.
3. `game/README.md`, `game/docs/technical_decisions.md`,
   `game/docs/game_state.md`, `game/docs/known_issues.md`, and relevant code/tests.

## Responsibilities and coordination

- **Claude** focuses on game features, scenes and the Godot gameplay loop, unless the owner
  assigns otherwise.
- **Codex** initially focuses on independent audits, regression tests, small bounded fixes
  and pull-request reviews. It may implement game features when explicitly assigned.
- **ChatGPT** helps coordinate game design, review proposed technical decisions and keep
  project documentation consistent.

These are **suggested roles, not exclusive file ownership**. Coordinate overlapping changes
through pull requests and documented issue/branch scope. Always start from the latest
`main`; make a new feature branch; do not force-push or silently modify another agent's work.
Do not assume changes in separate chat sessions were synced unless the remote commit exists.

## Unreconciled earlier Codex project

Prior handoff material identifies an external project named
`AshesOfDominion-unified-foundation` (**v0.3.1-m1**) and separate Claude M2/M2b/M2.1
packages. Their contents have **not been inspected in this repository**.

If available in a Codex task or local workspace:

- Inventory the exact source/version and compare it against `game/` on `main`.
- Identify reusable fixes, conflicting architecture, save-schema incompatibilities and tests.
- Present a file-level comparison and a safe, feature-by-feature migration proposal.
- **Do not replace `game/`, overwrite saves or merge the older project wholesale.**
- Do not claim that earlier source was recovered if it was not accessible.

## Codex Cloud environment setup

The repository connection for ChatGPT is separate from Codex Cloud's environment permissions.
In Codex (web/desktop), create a cloud environment, select this GitHub repository and approve
access when prompted; prepare and publish the environment before running cloud tasks.

Ask Codex's environment setup to use the official **Godot 4.5.1-stable standard/headless**
binary. Do not commit downloaded Godot executables, caches, credentials or user save files.

From `game/`, baseline verification commands on Linux/macOS are:

```bash
godot --headless --path . --import
./run_tests.sh "$(command -v godot)"
godot --headless --path . --quit-after 60
./check_relaunch.sh "$(command -v godot)"
```

If `godot` is unavailable, first check whether the correct Godot binary is installed under a
different path. If not, report the missing dependency or prepare the approved environment.
Do not claim successful tests when commands could not run. On Windows use
`run_tests.ps1` and `check_relaunch.ps1` with the Godot executable path.

## Recommended first coding task

1. Check the latest remote `main` and read the documents above.
2. Run (or clearly report inability to run) the baseline Godot checks.
3. Independently reproduce the known **Mist of Discovery route preview leak** described
   in `game/docs/known_issues.md`. The uncharted preview currently reveals intermediate
   waypoint shape; danger and day estimates are already intentionally approximate.
4. If reproducible, write a regression test showing that undiscovered route geometry is not
   exposed by the preview. Implement the smallest correct fix while preserving route
   selection, estimates, seed determinism and save state.
5. Run all available tests, compare before/after results, and update
   `game/docs/known_issues.md`, `docs/IMPLEMENTATION_STATUS.md` and `docs/AI_HANDOFF.md`
   **only for verified changes**.
6. Open a pull request from a Codex-owned feature branch to `main`. Report exact changed files,
   commands/results, commit SHA, PR link and any remaining risks.

If the leak cannot be reproduced with available tooling, create a focused audit report and a
specific test/reproduction plan rather than claiming a speculative repair.

## Codex review priorities

Pay particular attention to deterministic random streams, save migrations, already-resolved
resurrection outcomes, exactly-once pending transitions, Mist information leaks, and Godot scene
references. Prioritize reproducible correctness bugs over cosmetic preferences. Automated
checks and human approvals remain necessary even with AI review.
