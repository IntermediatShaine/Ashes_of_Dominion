# Technical architecture

**Status: proposed target; no imported Godot implementation has been audited.**

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

The universe may be replaced by transfer while persistent character progression survives. This is a **design discussion**, not verified implemented code. Confirm and transcribe the original v0.3 addendum before treating exact data fields as definitive.

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

When prior code is added, prefer `game/` as project root **only if it does not disrupt the existing architecture**. Do not fabricate an empty `project.godot` or claim a playable game based on documentation alone.
