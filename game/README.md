# Ashes of Dominion — first playable vertical slice

Medieval-fantasy action RPG / settlement prototype. Godot 4.x, GDScript, Windows PC, single-player.

This folder is the Godot project root (`game/` in the GitHub repository). It is the **foundation
checkpoint** from the master development directive: the smallest
coherent gameplay loop running on the real architecture (three-scope state, deterministic generation,
versioned crash-safe saves), with placeholder visuals.

## Engine version

Developed and verified on **Godot 4.5.1-stable (official)** (`config/features` says 4.5).
Other 4.x versions are untested: 4.4 will probably open it, anything older than 4.3 will not
(the GDScript relies on 4.3+ builtins such as `floorf`). The "4.7.2" mentioned in the design
document does not exist as of this writing; use the latest 4.5.x stable.

## Download a playable build (no Godot editor required)

Visit the [latest playable preview](https://github.com/IntermediatShaine/Ashes_of_Dominion/releases/tag/preview) and download the **Windows x64 ZIP** or **Linux x86_64 ZIP**. Extract the entire ZIP, launch `AshesOfDominion.exe` (Windows) or `AshesOfDominion.x86_64` (Linux), and keep its `.pck` beside it. These builds are portable, not signed installers. The preview becomes available after the first successful [distribution workflow](../docs/DOWNLOADS_AND_RELEASES.md) run on main.

## Opening and running from source

1. Install Godot 4.5.1 (standard build; .NET is not required).
2. Open Godot → **Import** → select `project.godot` in this folder → **Import & Edit**.
   The first open imports `icon.svg` and builds the script class cache; wait for it to finish.
3. Press **F5** (Run Project). Or from a terminal:

   ```powershell
   # Windows (use the *_console.exe build to see log output)
   "C:\path\to\Godot_v4.5.1-stable_win64_console.exe" --path "D:\Ashes of Dominion"
   ```

Saves live in `%APPDATA%\Godot\app_userdata\Ashes of Dominion\saves\slot_N\` (the Settings screen
prints the exact path). Settings live next to them in `settings.json`.

## Running the automated tests

```powershell
.\run_tests.ps1 -Godot "C:\path\to\Godot_v4.5.1-stable_win64_console.exe"
# or directly:
godot --headless --path . --import
godot --headless --path . res://tests/test_runner.tscn
```

The runner prints one line per test file and `=== N tests, M failed ===`, exit code 1 on failure.
**A run is only green if there are also no `SCRIPT ERROR` lines** — a runtime script error aborts
the test that hit it, so `run_tests.ps1` / `run_tests.sh` grep for them and fail the run.
Smoke test: `godot --headless --path . --quit-after 60` must exit 0 with no errors.

Persistence across a real restart (save → engine exits → new process → Continue):

```powershell
.\check_relaunch.ps1 -Godot "C:\path\to\Godot_v4.5.1-stable_win64_console.exe"   # or ./check_relaunch.sh <godot>
```

Optional rendered walkthrough (writes PNGs of every screen, needs a GPU/display):
`godot --path . res://tools/screenshot_tour.tscn -- --out=C:/temp/shots`

## How to play

| Action | Input |
| --- | --- |
| Move (8 directions) | WASD / arrow keys |
| Attack | Left mouse button or Space |
| Interact (gather, talk, return home) | E |
| Open world map (from Emberfall) | M, or the World Map button |
| Pause / back | Escape |
| Debug overlay | F3 |

1. **New Game** → name, background (3 archetypes), difficulty preset or custom sliders, Mist on/off, seed, slot → **Begin**.
2. **Emberfall** (settlement screen): status, factions, resources, buildings. Build when you can afford it.
3. **World Map**: click a known place, pick route A/B, **Begin Expedition**.
4. **Exploration**: fight (red things), gather (diamonds, E), talk to the figure marked (!) — the
   stranded survivor first, later a Crown patrol whose offer depends on how the Crown regards you —
   walk to the gold ring on the right edge and press E to return. Esc → Retreat keeps your pack.
   If you fall, the curse returns you to Emberfall; what you carried stays where you fell.
5. Returning autosaves; **Save Game** also works any time in Emberfall. **Continue** loads the newest slot.

Engineering checks, isolated data, CI and harness failure injection are documented in
[`../docs/TESTING_AND_CI.md`](../docs/TESTING_AND_CI.md). The test/relaunch wrappers now reject
failed imports and missing success markers; a filter matching zero tests fails.

## Project layout

```
project.godot          Godot config, autoloads, input map
data/                  JSON content: archetypes, ancestries, classes, factions, enemies, biomes,
                       buildings, resources, landmarks, difficulty, decisions, balance
scripts/core/          StableHash, RngStream/RngRegistry, IdFactory, OpResult, DictUtil
scripts/models/        CharacterState, UniverseState, MultiverseState, SettlementState,
                       FactionState, ExpeditionRecord, SaveGame
scripts/persistence/   SaveRepository (slots, temp/backup/recovery), SaveValidator, SaveMigrator
scripts/generation/    WorldGraph(+Generator), RoutePlanner, WildernessMap(+Generator)
scripts/gameplay/      pure rules: character, combat, settlement, world (expedition, transitions,
                       morality, reputation, threat, decisions, difficulty, simulation)
scripts/gameplay/exploration/  scene-side controllers (player, enemy, resource, npc, terrain)
scripts/services/      autoloads: Content (data), Session (state + services), Router (scenes)
scripts/interface/     menus, settlement screen, world map, HUD, UiKit
scenes/                one .tscn per screen; UI is built in code from those roots
tests/                 unit / deterministic / persistence / integration + test_runner.tscn
tools/                 screenshot_tour (rendered smoke test), relaunch_check (two-process save check)
docs/                  architecture, game_state, implementation_status, technical_decisions,
                       known_issues, development_roadmap
```

See `docs/implementation_status.md` for what is implemented vs. tested vs. planned, and
`docs/development_roadmap.md` for the exact next task.
