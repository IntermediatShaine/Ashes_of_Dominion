# Technical decisions

### 1. Fresh project instead of extending the earlier "Milestone 1" code
**Problem.** The earlier code was never run in Godot and no copy existed on disk. **Decision.**
Rebuild from the design document + directive, keeping the earlier *ideas* (custom hash/PRNG,
versioned crash-safe saves, data-driven settings, layered architecture). **Trade-off.** Lost
nothing verifiable; gained a codebase where every file has been executed.

### 2. JSON for content and saves; RefCounted models, not Resources
**Problem.** Resources give editor integration but `ResourceLoader` on user data can execute
scripts, and `.tres` diffs are noisy. **Decision.** JSON everywhere, typed accessors in `DictUtil`,
`to_dict/from_dict/validate` on each model. **Trade-off.** No inspector editing of content;
numbers come back as floats and must be cast (handled centrally). **Future.** Typed Resources can
be layered on top for editor tooling without changing the save format.

### 3. 64-bit integers are serialized as strings
**Problem.** `JSON.parse_string` returns doubles; seeds and PCG states above 2^53 silently lost
bits (caught by `test_random_state_preserved`). **Decision.** `str()` on write, `DictUtil.get_int`
(accepts numeric strings) on read. Part of the save-compatibility contract.

### 4. PCG32 (`RandomNumberGenerator`) wrapped in named streams, seeds from FNV-1a + splitmix
**Problem.** The directive asks to reuse a custom hash/PRNG if correct; none existed. Writing a
PRNG in GDScript is possible but slower and gains nothing over the engine's platform-independent
integer PCG. **Decision.** Custom, documented *hashing* (`StableHash`: FNV-1a 64 over UTF-8,
splitmix64 finalizer, logical shifts implemented on signed ints) for all seed derivation; engine
PCG for the streams; `state` persisted. **Trade-off.** Depends on Godot keeping PCG32 stable (it
has since 3.x). **Note.** Inside `RngStream`, unqualified `randf()` resolves to the *global*
function, not the method — every internal call uses `self.` (this bug produced nondeterministic
generation until the determinism tests caught it).

### 5. Derived world, persisted modifications
**Problem.** Storing generated maps bloats saves and lets stale layouts diverge from the seed.
**Decision.** `WorldGraph` and `WildernessMap` are regenerated from (seed, version, area id);
only discovery, harvest history and decisions are saved. **Trade-off.** Any generator change
must bump `CURRENT_GENERATION_VERSION`; old saves keep their version and would need the old
generator kept alive (not done yet — see known_issues).

### 6. Generation-time streams are separate from runtime streams
Generators create their own `RngStream` from `derive_seed(seed, "gen:…")`; the six persisted
runtime streams (`world_geometry`, `route`, `encounter`, `combat`, `rewards`, `events`) are only
drawn by gameplay. Replaying generation on load therefore never consumes runtime state.

### 7. Save write protocol: temp → read-back validate → rotate backup → promote (rename, copy fallback)
Windows can refuse a rename while another process holds the file; success is checked after each
step and the previous `save.json` is only touched after the temp copy proved valid. Load order:
primary → `.bak` → orphaned `.tmp`, with the recovery reported as a warning.

### 8. Transitions as explicit records; resurrection outcome stored before use
See game_state.md. Only `return_home` exists; probabilities and transfer rules are *not*
invented. Counters for natural/forced transfers exist but are never incremented.

### 9. Defeat loses the pack (provisional)
The design says death "should not be free" but leaves the penalty open. The only consequence
implemented is fictional and configurable: `balance.json → expedition.defeat_loses_haul`. XP
already earned is kept (it belongs to the character). Revisit when the death rules are designed.

### 10. Settlement is a management screen, not a walkable scene
Cheaper and sufficient for the checkpoint; the exploration scene already proves the 2.5D walkable
presentation, and the settlement's state is where the gameplay is. A walkable Emberfall is on
the roadmap.

### 11. UI built in code via `UiKit`
Hand-written `.tscn` for complex Control trees is error-prone without the editor; building in
code keeps screens testable headless. Scenes still exist as roots so designers can later move
pieces into the editor.

### 12. Expedition counting counts every excursion (returned, retreated, defeated)
Leaving the village is what draws attention; the grace period is about expeditions, not
successes. Configurable later if the design disagrees.

### 13. Mist semantics
Persistent landmarks are known from the start only if `known_at_start`; completing an expedition
reveals its route edges and the destination's neighbouring landmarks. Waypoints show once an
adjacent edge was travelled. Route *preview* draws the planned line (dashed where uncharted) but
labels days/danger as estimates (see known_issues for the shape leak).

### 14. One test runner, no framework
A 150-line runner (`tests/test_runner.gd`) run as a scene so autoloads exist; tests are plain
`TestCase` subclasses. Runtime script errors abort the test that hit them and are not visible to
the runner, so the wrapper scripts fail the run on any `SCRIPT ERROR` output.
