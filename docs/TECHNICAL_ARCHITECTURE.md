# Technical architecture

**Status: implemented in `game/` and audited on 2026-11-01.** The authoritative, detailed
description is `game/docs/architecture.md` and `game/docs/game_state.md`; this file keeps the
intended boundaries and invariants at summary level. Where this file says "proposed", the
`game/docs/` files say what was actually built.

## Runtime target

- Godot 4 / GDScript (verify the exact installed patch version).
- Windows PC, mouse and keyboard.
- 2.5D pixel-art presentation; three-quarter direct exploration and separate strategic map.

## Proposed boundaries

| Domain | Responsibilities |
| --- | --- |
| Character | Identity, ancestry, levels/XP, skills/classes, persistent flags and personal morality |
| World generation | Seeded geographic layers, stable narrative locations, variable wilderness/routes |
| Exploration | Fog, navigation, routes, travel progress, encounters, expedition records |
| Combat | Player input, abilities, enemies, combat resolution and rewards |
| Settlement | Population, production, stockpiles, buildings, morale, loyalty and defenses |
| Factions | Reputation, territory, diplomacy, autonomous actions, threats and wars |
| NPCs/events | Character state, quest flags, narratives, consequences |
| Saves | Versioned records, validation, persistence, backup/recovery and migration |
| UI | Menus, HUD and map views calling service/domain interfaces |

These are logical boundaries, **not mandatory filenames or directories**. Reconcile with Claude's actual code before restructuring.

## Proposed save ownership model

Prior discussion described three state scopes:

1. **Character record:** permanent identity, ancestry, XP/level, attributes, skills, lore, unlocks, unlocked classes, morality and permanent character flags.
2. **Universe state:** seed and world layers, settlements, factions/NPC relations, territory, NPC state, events, threats, expeditions, in-game day, companions and separate combat/rewards/events random streams.
3. **Multiverse state:** natural/forced transfer counts, already-resolved resurrection rolls and a pending transition record to make resumption safe after interruption.

The universe may be replaced by transfer while persistent character progression survives. The
three scopes above are implemented (`game/scripts/models/`) and tested; exact fields are listed in
`game/docs/game_state.md`. Universe transfer *rules* are not implemented (only `return_home`).

## Persistence and RNG invariants to preserve

- A fixed seed and known random stream states reproduce the same generated results under the same generation version.
- Stable story landmarks do not shift when wilderness/route layers regenerate.
- Saving and loading never triggers a second draw for an already-resolved outcome.
- Writes are validated, versioned and recoverable from interruption/backup.
- Interruption during universe transfer cannot duplicate or skip state transitions.
- Morality does not automatically overwrite unrelated faction relations.

## Integration and migration rules

Use explicit interfaces/signals and stable identifiers. Prefer data-defined races, classes, items, buildings, events and difficulty settings. Introduce schema migrations for save changes, with tests around reload and recovery. Avoid large speculative rewrites ahead of a tested expedition loop.

## Proposed Godot location

The project root is `game/` (`game/project.godot`). Autoloads: `Content` (data), `Session` (state
owner + bound services), `Router` (scenes). Layout: `scripts/core`, `models`, `persistence`,
`generation`, `gameplay` (pure rules + scene-side exploration controllers), `services`,
`interface`; `scenes/`; `data/*.json`; `tests/`; `tools/`.
