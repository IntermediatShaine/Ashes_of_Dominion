# Art swap guide

How to replace placeholder graphics with final art (PixelLab or anything else) **without touching
a script**. Read this before adding or changing any image.

## The idea in one paragraph

No gameplay object names an image file. Objects ask for a **visual id** such as
`building.workshop.level_1`; the **visual registry** (`data/visuals/visual_registry.json`) says
which texture — and which part of it, where it sits, how big, what tint — that id means. It works
like a style sheet: the id is the class name, the registry entry is the rule. Swapping art means
editing the registry. Collisions, interaction areas, building costs and every other gameplay
number come from layout and content data, never from the picture, so a new image can be any size.

| What | Where |
| --- | --- |
| Registry (the only file that names images) | `data/visuals/visual_registry.json` |
| Resolver — autoload `Visuals` | `scripts/visuals/VisualResolver.gd` |
| Sprite that follows the registry | `scripts/visuals/visual_sprite.gd` (`VisualSprite`) |
| State → visual id for village objects | `scripts/gameplay/village/village_visuals.gd` |
| Placeholder images | `assets/placeholders/` |
| Final images (empty, waiting) | `assets/pixellab/` |
| Interface look | `ui/themes/village_theme.tres` |

## Swapping one image

1. Put the PNG under `assets/pixellab/` (sub-folders are up to you).
2. Open the project in Godot once (or run `godot --headless --path . --import`) so the image is
   imported. Commit the `.png.import` file Godot writes next to it.
3. In `data/visuals/visual_registry.json`, change the entry's `texture`:

   ```json
   "building.workshop.level_1": {"texture": "res://assets/pixellab/buildings/workshop_1.png", "anchor": "bottom_center", "offset": [0, 6]}
   ```
4. Run the game. If the picture sits too high, low or sideways, adjust `offset` (see below).

That is the whole procedure. Nothing else needs to change, including for a building whose new
image is twice the size of the placeholder: its collision box and interaction area are the site's
footprint in `data/village/village_layouts.json`.

The texture filter is "nearest" project-wide, so pixel art stays crisp.

## Entry fields

Every field except `texture` (or `extends`) is optional.

| Field | Meaning | Default |
| --- | --- | --- |
| `texture` | `res://` path of the image | — |
| `extends` | another visual id whose fields this entry inherits and may override | — |
| `anchor` | which point of the image sits on the object's position: `center`, `bottom_center`, `top_left` | `center` |
| `offset` | `[x, y]` extra pixels added after the anchor | `[0, 0]` |
| `scale` | number or `[x, y]` | `1` |
| `modulate` | tint, `"#rrggbb"` or `"#rrggbbaa"` | white |
| `z_index` | draw order against neighbours; `-1` draws under characters (flat ground decals) | `0` |
| `region` | `[x, y, w, h]` — use only this rectangle of the texture (atlases) | whole texture |
| `hframes`, `vframes` | columns and rows of a spritesheet | `1`, `1` |
| `frame` | which frame to show | `0` |
| `facing_frames` | `true`: frames 0–7 are the eight facings **E, SE, S, SW, W, NW, N, NE** | `false` |
| `animations` | `{name: {frames: [...], fps: n, loop: bool}}` — stored and handed to whoever animates the sprite; **nothing plays animations yet** | `{}` |
| `tile` | `true`: the texture repeats to fill an area (ground) | `false` |

**Positioning.** World objects stand on a point on the ground: a building on the middle of its
footprint's bottom edge, a character on its feet, a prop on its base. With `anchor:
"bottom_center"` the image's bottom centre is put on that point; `offset` then nudges it (positive
y = down). The placeholders use `[0, 6]` for buildings because their drawings have 6 px of shadow
below the wall line.

**Spritesheets.** Give `hframes`/`vframes`; the sprite shows `frame`. For the protagonist
(`actor.player`) the sheet is eight frames in one row, one per facing, with `facing_frames: true`.
A sheet with more rows (walk cycles) can be registered now, but playing it needs the small piece
of animation code that does not exist yet — see *Limits*.

**Atlases.** Several ids can share one texture with different `region`s.

**Inheritance.** `"extends": "building.shelter.level_1"` copies that entry; list only what differs.

## Fallback rules

Looking up an id tries, in order:

1. the id itself;
2. its parent path, repeatedly — `building.shelter.level_4` → `building.shelter` → `building`;
3. the registry's `fallback_visual` (`placeholder.missing`, a magenta checkerboard).

So a missing image is obvious on screen and never a crash, and a family entry such as
`building.shelter` can serve all levels until each has its own art.

## Visual ids in use

All of these have a placeholder today.

| Id | Shown for | Decided by |
| --- | --- | --- |
| `building.<definition>.level_<n>` (n ≥ 1) | a standing building at that level | `SettlementState` building `level` |
| `building.<definition>.level_0` | the building's ruin: not rebuilt yet, or destroyed (condition 0) | site state |
| `site.plot.empty` | a free building plot | site state |
| `site.construction` | scaffolding over a site being built on | a build job on the site |
| `marker.work_in_progress` | badge over a building being upgraded or repaired | an upgrade/repair job |
| `marker.village_gate` | the village exit | `village_layouts.json` exit `visual` |
| `terrain.village.grass` / `.path` / `.dirt` | village ground (tiled) | `village_layouts.json` `ground` |
| `prop.tree.pine`, `prop.tree.dead`, `prop.rubble`, `prop.stump`, `prop.signpost` | scenery | `village_layouts.json` `props` / `border` |
| `actor.player` | the protagonist, in the village **and** on expeditions | — |
| `icon.resource.<resource>` , `icon.population` | interface icons | — |
| `placeholder.missing` | anything unresolved | — |

`<definition>` is a key of `data/buildings.json`: `village_hearth` (levels 0–3), `shelter` (0–3),
`workshop` (0–2), `stockpile` (0–3), `watchpost` (0–2), `woodcutters_camp`, `storehouse`,
`palisade` (level 1 only; they never appear as ruins).

Adding a building level in `data/buildings.json` means adding `building.<id>.level_<n>` here;
`tests/unit/test_visual_registry.gd` fails until every level has an entry.

### Reserved ids — objects that are still drawn in code

Expedition objects predate the registry and are drawn with simple shapes in code. They already
look for an entry and switch to it the moment one exists (exact id, no fallback), so giving them
art is also a registry edit:

| Id | Object | Ids available |
| --- | --- | --- |
| `actor.enemy.<enemy id>` | an enemy | `marauder`, `ashen_hound`, `mire_lurker`, `rust_sentinel` |
| `resource.node.<resource id>` | a harvestable node | `wood`, `stone`, `food`, `iron` |
| `actor.npc.<decision id>` | a decision NPC | `stranded_survivor`, `crown_patrol` |

Health bars, attack warnings, amounts and the "!" marker stay code-drawn on top; states (hit,
wind-up, depleted, resolved) show as a tint on the sprite.

## Restyling the interface

`ui/themes/village_theme.tres` is a normal Godot Theme. Open it in the theme editor, or edit the
text. The village interface (`scripts/interface/village_hud.gd`) sets **no** colour, font size or
stylebox on any control; it only picks one of these type variations, so everything about its look
is in the theme:

| Variation | Base | Used for |
| --- | --- | --- |
| `TitleLabel`, `HeaderLabel` | Label | panel titles, section headings |
| `ValueLabel`, `SmallLabel`, `MutedLabel` | Label | large values, body text, secondary text |
| `GoodLabel`, `BadLabel` | Label | positive notes, blocking reasons |
| `PromptLabel`, `ToastLabel` | Label | `[E]` prompt, transient messages |
| `SmallButton`, `TabButton` | Button | row buttons, the Overview / Buildings tabs |
| `HudBar`, `ModalPanel`, `CardPanel` | PanelContainer | status bar, dialogs, cards inside dialogs |
| `ModalShade` | Panel | dimming behind a dialog |
| `WorkBar` | ProgressBar | construction progress (plain `ProgressBar` = condition) |
| `TightVBox`, `LooseVBox`, `TightHBox`, `LooseHBox` | Box containers | spacing |

`tools/build_village_theme.gd` regenerates the file from defaults. It **overwrites** edits; run it
only to start over or after adding a variation to it.

The menus, world map and expedition HUD still use the older code-built theme in
`scripts/interface/ui_kit.gd`. Moving them onto a `.tres` is not done.

## Checking your work

- A magenta checkerboard in the game = the id resolved to nothing. `Visuals.load_errors` lists
  why (missing file, bad field); the errors are also printed at startup.
- `godot --headless --path . res://tests/test_runner.tscn -- --filter=visual` runs the registry
  tests: every entry loads, every id the village can ask for exists, no script or scene contains
  an image path.
- While the game runs, `Visuals.reload()` re-reads the registry and every sprite updates in place.

## Regenerating the placeholders

`python3 tools/placeholder_art/generate_placeholders.py` (needs Pillow) rewrites
`assets/placeholders/`. The PNGs are committed; this is only for tweaking a stand-in.

## Limits (what is not done)

- **No animation playback.** `animations` is carried through the resolver but nothing reads it;
  characters show one frame per facing.
- **Expedition terrain is not on the registry.** `terrain_renderer.gd` still draws biome colours
  from `data/biomes.json` palettes. The village ground is.
- **Expedition enemies, resource nodes and NPCs have no placeholder images** — they use their
  code-drawn look until an entry is added (reserved ids above).
- **Condition has no picture of its own** between 1 and 99: a damaged building looks like a sound
  one (the inspection card shows the condition). Only condition 0 switches to the ruin.
- **One scaffolding image** for every site size.
- New images need Godot's import step before an exported build can load them.
