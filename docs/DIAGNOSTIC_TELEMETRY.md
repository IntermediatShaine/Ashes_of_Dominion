# Local diagnostic telemetry (optional)

## Intended behavior

Ashes of Dominion has **opt-in, local-only** diagnostics. **The default is OFF**, including for players whose existing user://settings.json does not contain the new key. Players can change it at any time in **Settings** (main menu or Emberfall) or from the **exploration pause menu**. The setting is saved across launches. No account, network connection, upload, crash reporter, or remote analytics endpoint exists in this feature.

The logger is separate from game-save data and does not modify the expedition checkpoint or schema. If it cannot write a log, the player can continue playing normally and the UI reports that logging could not be enabled.

- Storage: user://telemetry (the Settings menu displays its resolved OS path).
- Up to **five** per-application-session JSON Lines (.jsonl) logs, oldest rotated first, across restarts. Switching OFF and ON during the same running application appends to its existing session log; events while OFF are not written. Session file creation is delayed until enabled.
- Each file is limited to **1 MiB** to bound disk use. Once full, that session stops recording additional events. The next application launch starts another bounded file.
- Settings contains **Delete stored diagnostic logs**, which first switches logging off, then removes the logs. Existing logs otherwise remain on disk after opting out (but no new data is appended).
- Each entry has a UTC timestamp, an allowlisted event name and optionally numerical/boolean metrics. Free-form gameplay text, user-entered character names, world seeds, locations, file paths, narrative choices, account/character/universe IDs and raw error messages are not written. Numeric save-slot indices are recorded to help locate save failures. This is diagnostic metadata, not a full replay or combat-state dump.

## What is observed while enabled

Entry points: scene navigation, new/load/save outcomes (including write duration), save-state validation error counts, building construction, expedition start/finish, area generation (counts of enemies/resources), resource collection, enemy defeat, damage, narrative decision resolution and protagonist defeat. "state_checked" contains the number of errors reported by SaveGame.validate(), without the contents of the save.

A valid log does **not** prove that a playthrough was bug-free. Automated Godot unit/integration tests, the relaunch check, and manual gameplay remain the verification system. Native Godot engine/editor messages, crash files and operating-system diagnostics are **outside** this toggle; only this optional telemetry stream is controlled.

## Developer tests

Run the existing project checks from game/ (see docs/TESTING_AND_CI.md). The new unit test file covers default-off behavior, no writes while disabled, resume within a session, strict field/event allowlisting, rotation across eight mock app sessions, size limits and deletion. The integration test covers actual Session save/load event hooks, router scene events, switching the saved setting off, and normal save behavior after opting out.

Manual acceptance: on a clean profile, start a new game with diagnostics OFF, exit, and verify that no telemetry directory was created. Enable in Settings, play an expedition and return home; inspect the latest JSONL file. Toggle OFF from the pause menu while exploring, continue playing, and verify the file does not grow; toggle ON and verify append into the same file. Restart six or more times with logging ON and verify that no more than five files remain. Test Delete stored diagnostic logs. Test a log folder that is unwritable and confirm gameplay still works and enable reports an error.

This is independent of Phase 2C's still-proposed resumable-expedition persistence architecture.
