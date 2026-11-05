# PixelLab artwork goes here

This folder is empty on purpose. It is where final PixelLab images and
spritesheets are dropped; `assets/placeholders/` holds the stand-ins used
until then.

Nothing in the game refers to a file in this folder directly. To use an image:

1. Put the PNG here (any sub-folder layout you like, e.g. `buildings/`, `actors/`).
2. Open the project in Godot once so the image is imported.
3. In `data/visuals/visual_registry.json`, point the matching visual id's
   `texture` at the new file (and adjust `offset`, `hframes`, … if the image
   has a different size or is a spritesheet).

No script changes are needed. The full procedure, the list of visual ids and
the entry fields are in `docs/ART_SWAP_GUIDE.md`.
