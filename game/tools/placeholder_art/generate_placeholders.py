#!/usr/bin/env python3
"""Regenerates the placeholder artwork in game/assets/placeholders/.

    python3 tools/placeholder_art/generate_placeholders.py      (run from game/)

Needs Pillow. The PNGs it writes are committed, so nobody has to run this to
play or test the game; it exists so a placeholder can be tweaked or a new one
added in the same style. Every drawing is deterministic (fixed seeds), so
re-running without changes rewrites identical files.

These are stand-ins. Real art replaces them through
data/visuals/visual_registry.json (see docs/ART_SWAP_GUIDE.md) — nothing in
the game refers to these file names except that registry.
"""
import os
import random
import sys

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "placeholders")

# palette --------------------------------------------------------------------
OUTLINE = (38, 30, 34, 255)
WOOD = (133, 94, 58, 255)
WOOD_DARK = (96, 66, 42, 255)
WOOD_LIGHT = (168, 124, 80, 255)
THATCH = (186, 156, 84, 255)
THATCH_DARK = (148, 120, 60, 255)
STONE = (140, 140, 148, 255)
STONE_DARK = (98, 98, 108, 255)
STONE_LIGHT = (176, 176, 184, 255)
HIDE = (150, 118, 88, 255)
HIDE_DARK = (116, 88, 64, 255)
TILE = (150, 78, 60, 255)
TILE_DARK = (116, 56, 44, 255)
ASH = (88, 84, 88, 255)
ASH_LIGHT = (120, 116, 118, 255)
FIRE = (236, 142, 44, 255)
FIRE_HOT = (252, 214, 96, 255)
EMBER = (196, 72, 36, 255)
GRASS = (92, 112, 62, 255)
GRASS_DARK = (78, 98, 54, 255)
GRASS_LIGHT = (108, 128, 72, 255)
PATH = (150, 130, 96, 255)
PATH_DARK = (128, 110, 82, 255)
DIRT = (104, 92, 80, 255)
DIRT_DARK = (88, 78, 70, 255)
LEAF = (58, 92, 62, 255)
LEAF_DARK = (44, 72, 50, 255)
LEAF_LIGHT = (76, 112, 74, 255)
IRON = (93, 107, 122, 255)
CLOTH = (88, 124, 176, 255)
CLOTH_DARK = (64, 94, 138, 255)
SKIN = (230, 198, 166, 255)
HAIR = (112, 76, 50, 255)
RED = (176, 60, 52, 255)
SHADOW = (0, 0, 0, 70)
ROPE = (196, 176, 130, 255)


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def save(img, *parts):
    path = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=False)
    return path


def shadow(d, cx, base_y, rx, ry=5):
    d.ellipse([cx - rx, base_y - ry, cx + rx, base_y + ry - 1], fill=SHADOW)


def box(d, x0, y0, x1, y1, fill, outline=OUTLINE):
    d.rectangle([x0, y0, x1, y1], fill=fill, outline=outline)


def poly(d, pts, fill, outline=OUTLINE):
    d.polygon(pts, fill=fill, outline=outline)


def planks(d, x0, y0, x1, y1, base=WOOD, dark=WOOD_DARK, step=8):
    box(d, x0, y0, x1, y1, base)
    for x in range(x0 + step, x1, step):
        d.line([x, y0 + 1, x, y1 - 1], fill=dark)


def stones(d, x0, y0, x1, y1, rng, base=STONE, dark=STONE_DARK, light=STONE_LIGHT):
    box(d, x0, y0, x1, y1, base)
    y = y0 + 1
    row = 0
    while y < y1:
        x = x0 + 1 + (4 if row % 2 else 0)
        while x < x1:
            w = rng.randint(6, 10)
            d.line([min(x + w, x1 - 1), y, min(x + w, x1 - 1), min(y + 5, y1 - 1)], fill=dark)
            if rng.random() < 0.35:
                d.point([x + 2, y + 1], fill=light)
            x += w
        d.line([x0 + 1, min(y + 6, y1 - 1), x1 - 1, min(y + 6, y1 - 1)], fill=dark)
        y += 7
        row += 1


def flame(d, cx, base_y, h):
    w = max(3, h // 2)
    poly(d, [(cx - w, base_y), (cx - w // 2, base_y - h // 2), (cx, base_y - h), (cx + w // 2, base_y - h // 2), (cx + w, base_y)], FIRE, EMBER)
    poly(d, [(cx - w // 2, base_y), (cx, base_y - (h * 3) // 5), (cx + w // 2, base_y)], FIRE_HOT, FIRE)


def stone_ring(d, cx, cy, rx, ry, rng):
    for i in range(10):
        import math
        a = i / 10.0 * math.tau
        x = cx + int(math.cos(a) * rx)
        y = cy + int(math.sin(a) * ry)
        c = STONE if rng.random() < 0.6 else STONE_LIGHT
        d.ellipse([x - 5, y - 4, x + 5, y + 3], fill=c, outline=OUTLINE)


def log_pile(d, x0, base_y, rows=3, per_row=4):
    y = base_y
    for r in range(rows):
        for i in range(per_row - r):
            x = x0 + r * 5 + i * 10
            d.ellipse([x, y - 9, x + 9, y], fill=WOOD_LIGHT, outline=OUTLINE)
            d.point([x + 4, y - 5], fill=WOOD_DARK)
        y -= 8


def crate(d, x0, base_y, size=14, fill=WOOD):
    box(d, x0, base_y - size, x0 + size, base_y, fill)
    d.line([x0, base_y - size, x0 + size, base_y], fill=WOOD_DARK)
    d.line([x0 + size, base_y - size, x0, base_y], fill=WOOD_DARK)


def barrel(d, x0, base_y):
    box(d, x0, base_y - 16, x0 + 11, base_y, WOOD)
    d.line([x0, base_y - 12, x0 + 11, base_y - 12], fill=IRON)
    d.line([x0, base_y - 4, x0 + 11, base_y - 4], fill=IRON)


# --- terrain ------------------------------------------------------------------
def terrain():
    rng = random.Random(11)
    img, d = canvas(32, 32)
    d.rectangle([0, 0, 31, 31], fill=GRASS)
    for _ in range(26):
        x, y = rng.randrange(32), rng.randrange(32)
        d.point([x, y], fill=GRASS_DARK if rng.random() < 0.6 else GRASS_LIGHT)
    for _ in range(5):
        x, y = rng.randrange(2, 30), rng.randrange(3, 30)
        d.line([x, y, x, y - 2], fill=GRASS_LIGHT)
    save(img, "terrain", "village_grass.png")

    rng = random.Random(12)
    img, d = canvas(32, 32)
    d.rectangle([0, 0, 31, 31], fill=PATH)
    for _ in range(22):
        x, y = rng.randrange(32), rng.randrange(32)
        d.point([x, y], fill=PATH_DARK)
    for _ in range(4):
        x, y = rng.randrange(2, 28), rng.randrange(2, 29)
        d.rectangle([x, y, x + 2, y + 1], fill=STONE_LIGHT)
    save(img, "terrain", "village_path.png")

    rng = random.Random(13)
    img, d = canvas(32, 32)
    d.rectangle([0, 0, 31, 31], fill=DIRT)
    for _ in range(30):
        x, y = rng.randrange(32), rng.randrange(32)
        d.point([x, y], fill=DIRT_DARK if rng.random() < 0.7 else ASH_LIGHT)
    save(img, "terrain", "village_dirt.png")


# --- props --------------------------------------------------------------------
def props():
    img, d = canvas(48, 80)
    shadow(d, 24, 76, 16)
    box(d, 21, 56, 27, 76, WOOD_DARK)
    poly(d, [(24, 4), (10, 30), (38, 30)], LEAF_LIGHT)
    poly(d, [(24, 18), (6, 48), (42, 48)], LEAF)
    poly(d, [(24, 34), (3, 64), (45, 64)], LEAF_DARK)
    save(img, "props", "tree_pine.png")

    img, d = canvas(48, 72)
    shadow(d, 24, 68, 12)
    box(d, 21, 26, 27, 68, WOOD_DARK)
    for pts in ([(24, 34), (10, 18)], [(24, 28), (38, 12)], [(24, 44), (36, 34)], [(24, 26), (22, 6)], [(10, 18), (6, 10)], [(38, 12), (44, 14)]):
        d.line(pts, fill=OUTLINE, width=3)
        d.line(pts, fill=WOOD_DARK, width=1)
    save(img, "props", "tree_dead.png")

    rng = random.Random(21)
    img, d = canvas(40, 24)
    shadow(d, 20, 21, 17, 4)
    for (x, y, w, h) in ((2, 10, 14, 10), (13, 6, 13, 14), (24, 11, 13, 9), (9, 15, 10, 6)):
        d.ellipse([x, y, x + w, y + h], fill=STONE if rng.random() < 0.5 else STONE_DARK, outline=OUTLINE)
    d.line([18, 4, 30, 12], fill=WOOD_DARK, width=2)
    save(img, "props", "rubble.png")

    img, d = canvas(24, 20)
    shadow(d, 12, 17, 10, 3)
    box(d, 5, 6, 18, 17, WOOD_DARK)
    d.ellipse([4, 2, 19, 10], fill=WOOD_LIGHT, outline=OUTLINE)
    d.ellipse([9, 4, 14, 8], outline=WOOD_DARK)
    save(img, "props", "stump.png")

    img, d = canvas(32, 44)
    shadow(d, 16, 41, 8, 3)
    box(d, 14, 10, 17, 41, WOOD_DARK)
    poly(d, [(4, 6), (26, 6), (30, 11), (26, 16), (4, 16)], WOOD_LIGHT)
    d.line([8, 11, 22, 11], fill=WOOD_DARK)
    save(img, "props", "signpost.png")


# --- markers -------------------------------------------------------------------
def markers():
    img, d = canvas(96, 96)
    shadow(d, 48, 92, 44, 4)
    box(d, 6, 18, 16, 92, WOOD_DARK)
    box(d, 80, 18, 90, 92, WOOD_DARK)
    box(d, 2, 10, 94, 20, WOOD)
    poly(d, [(6, 18), (2, 10), (10, 2), (16, 10)], WOOD_LIGHT)
    poly(d, [(80, 18), (80, 10), (86, 2), (94, 10), (90, 18)], WOOD_LIGHT)
    box(d, 34, 22, 62, 34, THATCH)
    d.line([38, 28, 58, 28], fill=OUTLINE)
    poly(d, [(54, 25), (59, 28), (54, 31)], OUTLINE)
    save(img, "markers", "village_gate.png")

    img, d = canvas(16, 16)
    box(d, 2, 2, 10, 6, IRON)
    box(d, 6, 6, 8, 14, WOOD_LIGHT)
    save(img, "markers", "work_in_progress.png")

    img, d = canvas(32, 32)
    for y in range(4):
        for x in range(4):
            d.rectangle([x * 8, y * 8, x * 8 + 7, y * 8 + 7], fill=(236, 38, 196, 255) if (x + y) % 2 else (24, 20, 28, 255))
    save(img, "common", "missing.png")


# --- sites ---------------------------------------------------------------------
def sites():
    img, d = canvas(96, 64)
    d.rectangle([4, 6, 91, 59], fill=(118, 104, 84, 110))
    for (x, y) in ((4, 6), (91, 6), (4, 59), (91, 59)):
        box(d, x - 2, y - 5, x + 2, y + 2, WOOD_LIGHT)
    for seg in ([4, 3, 91, 3], [4, 56, 91, 56], [4, 3, 4, 56], [91, 3, 91, 56]):
        d.line(seg, fill=ROPE)
    save(img, "sites", "plot_empty.png")

    img, d = canvas(96, 104)
    shadow(d, 48, 100, 44, 4)
    for x in (10, 36, 60, 86):
        box(d, x - 2, 10, x + 2, 100, WOOD_LIGHT)
    for y in (22, 52, 80):
        box(d, 6, y, 90, y + 4, WOOD)
    d.line([10, 52, 36, 22], fill=WOOD_DARK, width=2)
    d.line([60, 52, 86, 22], fill=WOOD_DARK, width=2)
    d.line([36, 80, 60, 52], fill=WOOD_DARK, width=2)
    box(d, 40, 86, 58, 100, WOOD_DARK)
    log_pile(d, 62, 100, rows=2, per_row=3)
    save(img, "sites", "construction.png")


# --- buildings ------------------------------------------------------------------
def hearth():
    rng = random.Random(31)
    for level in range(4):
        img, d = canvas(64, 80)
        shadow(d, 32, 74, 28, 6)
        d.ellipse([10, 54, 54, 76], fill=ASH, outline=OUTLINE)
        if level == 0:
            d.ellipse([18, 58, 46, 72], fill=ASH_LIGHT)
            for (x, y) in ((12, 62), (26, 54), (44, 58), (50, 68), (20, 72)):
                d.ellipse([x - 5, y - 4, x + 5, y + 3], fill=STONE_DARK, outline=OUTLINE)
            d.line([24, 64, 40, 68], fill=WOOD_DARK, width=2)
        else:
            stone_ring(d, 32, 65, 21, 9, rng)
            d.line([22, 68, 42, 62], fill=WOOD_DARK, width=3)
            d.line([24, 62, 40, 68], fill=WOOD, width=3)
            flame(d, 32, 66, 14 + level * 7)
        if level == 2:
            d.line([14, 74, 32, 24], fill=WOOD_DARK, width=2)
            d.line([50, 74, 32, 24], fill=WOOD_DARK, width=2)
            box(d, 27, 40, 37, 48, IRON)
        if level == 3:
            for x in (8, 54):
                box(d, x - 2, 22, x + 2, 76, WOOD_DARK)
            poly(d, [(2, 24), (32, 4), (62, 24)], TILE)
            d.line([8, 24, 56, 24], fill=TILE_DARK)
            box(d, 4, 70, 60, 77, STONE)
        save(img, "buildings", "village_hearth_level_%d.png" % level)


def shelter():
    # level 0: collapsed frame
    img, d = canvas(96, 112)
    shadow(d, 48, 106, 44, 6)
    poly(d, [(8, 106), (30, 84), (58, 92), (88, 106)], HIDE_DARK)
    d.line([14, 106, 44, 62], fill=OUTLINE, width=5)
    d.line([14, 106, 44, 62], fill=WOOD_DARK, width=3)
    d.line([40, 104, 82, 80], fill=OUTLINE, width=5)
    d.line([40, 104, 82, 80], fill=WOOD, width=3)
    box(d, 60, 96, 76, 106, STONE_DARK)
    save(img, "buildings", "shelter_level_0.png")
    # level 1: hide lean-to
    img, d = canvas(96, 112)
    shadow(d, 48, 106, 44, 6)
    poly(d, [(8, 106), (48, 44), (88, 106)], HIDE)
    poly(d, [(40, 106), (48, 70), (56, 106)], (52, 40, 36, 255))
    d.line([48, 44, 48, 34], fill=WOOD_DARK, width=3)
    d.line([48, 44, 28, 106], fill=HIDE_DARK)
    d.line([48, 44, 68, 106], fill=HIDE_DARK)
    save(img, "buildings", "shelter_level_1.png")
    # level 2: timber hut, thatch roof
    img, d = canvas(96, 112)
    shadow(d, 48, 106, 46, 6)
    planks(d, 10, 62, 86, 106)
    poly(d, [(4, 64), (48, 24), (92, 64)], THATCH)
    for y in (36, 46, 56):
        d.line([48 - (y - 24), y, 48 + (y - 24), y], fill=THATCH_DARK)
    box(d, 40, 78, 56, 106, WOOD_DARK)
    save(img, "buildings", "shelter_level_2.png")
    # level 3: stone-footed house, tiled roof, window
    rng = random.Random(33)
    img, d = canvas(96, 112)
    shadow(d, 48, 106, 46, 6)
    planks(d, 8, 52, 88, 92, WOOD_LIGHT, WOOD)
    stones(d, 8, 90, 88, 106, rng)
    poly(d, [(2, 54), (48, 10), (94, 54)], TILE)
    for y in (22, 32, 42):
        d.line([48 - (y - 10), y, 48 + (y - 10), y], fill=TILE_DARK)
    box(d, 40, 70, 56, 106, WOOD_DARK)
    box(d, 64, 64, 78, 78, (220, 196, 120, 255))
    d.line([71, 64, 71, 78], fill=OUTLINE)
    box(d, 66, 12, 74, 30, STONE_DARK)
    save(img, "buildings", "shelter_level_3.png")


def workshop():
    img, d = canvas(96, 112)
    shadow(d, 48, 106, 44, 6)
    box(d, 12, 70, 16, 106, WOOD_DARK)
    d.line([80, 106, 66, 78], fill=OUTLINE, width=5)
    d.line([80, 106, 66, 78], fill=WOOD_DARK, width=3)
    poly(d, [(24, 106), (30, 92), (62, 92), (70, 106)], WOOD)
    d.line([34, 92, 30, 106], fill=WOOD_DARK)
    box(d, 44, 98, 56, 106, STONE_DARK)
    save(img, "buildings", "workshop_level_0.png")

    img, d = canvas(96, 112)
    shadow(d, 48, 106, 46, 6)
    for x in (12, 84):
        box(d, x - 3, 50, x + 3, 106, WOOD_DARK)
    poly(d, [(4, 54), (92, 38), (92, 48), (4, 64)], THATCH)
    box(d, 22, 86, 58, 92, WOOD_LIGHT)
    box(d, 24, 92, 28, 106, WOOD_DARK)
    box(d, 52, 92, 56, 106, WOOD_DARK)
    poly(d, [(64, 92), (80, 92), (76, 98), (78, 106), (66, 106), (68, 98)], IRON)
    d.line([30, 84, 44, 76], fill=WOOD_DARK, width=2)
    box(d, 42, 72, 50, 78, IRON)
    save(img, "buildings", "workshop_level_1.png")

    rng = random.Random(34)
    img, d = canvas(96, 112)
    shadow(d, 48, 106, 46, 6)
    planks(d, 8, 58, 88, 106)
    poly(d, [(2, 60), (94, 44), (94, 54), (2, 70)], TILE)
    stones(d, 66, 18, 80, 50, rng)
    for (x, y, r) in ((73, 12, 5), (79, 5, 4)):
        d.ellipse([x - r, y - r, x + r, y + r], fill=(200, 200, 204, 150))
    box(d, 14, 74, 44, 106, (52, 40, 36, 255))
    poly(d, [(20, 96), (34, 96), (31, 100), (33, 106), (21, 106), (23, 100)], IRON)
    box(d, 54, 76, 76, 90, (220, 196, 120, 255))
    d.line([65, 76, 65, 90], fill=OUTLINE)
    save(img, "buildings", "workshop_level_2.png")


def stockpile():
    img, d = canvas(96, 112)
    shadow(d, 48, 106, 44, 6)
    poly(d, [(14, 106), (18, 92), (34, 96), (30, 106)], WOOD_DARK)
    d.line([40, 104, 70, 96], fill=OUTLINE, width=6)
    d.line([40, 104, 70, 96], fill=WOOD_LIGHT, width=4)
    d.ellipse([70, 96, 84, 106], fill=STONE_DARK, outline=OUTLINE)
    save(img, "buildings", "stockpile_level_0.png")

    img, d = canvas(96, 112)
    shadow(d, 48, 106, 46, 6)
    log_pile(d, 8, 106, rows=3, per_row=4)
    crate(d, 54, 106, 16)
    crate(d, 72, 106, 14, WOOD_LIGHT)
    crate(d, 60, 90, 13, WOOD_LIGHT)
    save(img, "buildings", "stockpile_level_1.png")

    img, d = canvas(96, 112)
    shadow(d, 48, 106, 46, 6)
    for x in (8, 88):
        box(d, x - 2, 52, x + 2, 106, WOOD_DARK)
    log_pile(d, 12, 106, rows=3, per_row=4)
    crate(d, 56, 106, 16)
    crate(d, 73, 106, 12, WOOD_LIGHT)
    crate(d, 60, 90, 13, WOOD_LIGHT)
    barrel(d, 44, 106)
    poly(d, [(2, 56), (48, 36), (94, 56)], THATCH)
    d.line([20, 50, 76, 50], fill=THATCH_DARK)
    save(img, "buildings", "stockpile_level_2.png")

    rng = random.Random(35)
    img, d = canvas(96, 112)
    shadow(d, 48, 106, 46, 6)
    planks(d, 8, 54, 88, 96)
    stones(d, 8, 94, 88, 106, rng)
    poly(d, [(2, 56), (48, 22), (94, 56)], TILE)
    d.line([18, 46, 78, 46], fill=TILE_DARK)
    d.line([30, 36, 66, 36], fill=TILE_DARK)
    box(d, 30, 68, 66, 106, WOOD_DARK)
    d.line([48, 68, 48, 106], fill=OUTLINE)
    barrel(d, 72, 106)
    crate(d, 12, 106, 14, WOOD_LIGHT)
    save(img, "buildings", "stockpile_level_3.png")


def watchpost():
    img, d = canvas(64, 128)
    shadow(d, 32, 122, 28, 6)
    box(d, 12, 96, 18, 122, WOOD_DARK)
    d.line([24, 120, 56, 104], fill=OUTLINE, width=6)
    d.line([24, 120, 56, 104], fill=WOOD, width=4)
    d.line([30, 112, 50, 122], fill=OUTLINE, width=5)
    d.line([30, 112, 50, 122], fill=WOOD_DARK, width=3)
    save(img, "buildings", "watchpost_level_0.png")

    img, d = canvas(64, 128)
    shadow(d, 32, 122, 28, 6)
    for x in (12, 52):
        box(d, x - 2, 56, x + 2, 122, WOOD_DARK)
    d.line([12, 122, 52, 80], fill=WOOD_DARK, width=2)
    d.line([52, 122, 12, 80], fill=WOOD_DARK, width=2)
    box(d, 6, 52, 58, 60, WOOD)
    box(d, 6, 36, 58, 40, WOOD_LIGHT)
    for x in (8, 56):
        d.line([x, 40, x, 52], fill=WOOD_DARK, width=2)
    for y in range(64, 120, 8):
        d.line([28, y, 36, y], fill=WOOD_LIGHT, width=2)
    d.line([28, 60, 28, 122], fill=WOOD_DARK)
    d.line([36, 60, 36, 122], fill=WOOD_DARK)
    save(img, "buildings", "watchpost_level_1.png")

    img, d = canvas(64, 128)
    shadow(d, 32, 122, 28, 6)
    for x in (12, 52):
        box(d, x - 3, 44, x + 3, 122, WOOD_DARK)
    d.line([12, 122, 52, 84], fill=WOOD_DARK, width=2)
    d.line([52, 122, 12, 84], fill=WOOD_DARK, width=2)
    d.line([12, 84, 52, 52], fill=WOOD_DARK, width=2)
    planks(d, 4, 40, 60, 56, WOOD, WOOD_DARK, 7)
    for x in (8, 56):
        box(d, x - 2, 22, x + 2, 40, WOOD_DARK)
    poly(d, [(0, 24), (32, 6), (64, 24)], TILE)
    d.line([32, 6, 32, 0], fill=OUTLINE, width=2)
    poly(d, [(33, 0), (46, 3), (33, 7)], RED)
    for y in range(60, 120, 8):
        d.line([28, y, 36, y], fill=WOOD_LIGHT, width=2)
    save(img, "buildings", "watchpost_level_2.png")


def plot_buildings():
    # woodcutter's camp
    img, d = canvas(96, 112)
    shadow(d, 48, 106, 46, 6)
    poly(d, [(6, 106), (28, 66), (50, 106)], HIDE)
    poly(d, [(22, 106), (28, 84), (34, 106)], (52, 40, 36, 255))
    log_pile(d, 52, 106, rows=3, per_row=4)
    box(d, 44, 96, 52, 106, WOOD_DARK)
    d.line([48, 96, 56, 80], fill=WOOD_LIGHT, width=2)
    poly(d, [(52, 78), (62, 80), (58, 88)], IRON)
    save(img, "buildings", "woodcutters_camp_level_1.png")

    # storehouse
    rng = random.Random(41)
    img, d = canvas(96, 112)
    shadow(d, 48, 106, 46, 6)
    planks(d, 6, 50, 90, 106, WOOD, WOOD_DARK, 7)
    poly(d, [(0, 52), (20, 22), (76, 22), (96, 52)], THATCH)
    d.line([12, 40, 84, 40], fill=THATCH_DARK)
    d.line([18, 30, 78, 30], fill=THATCH_DARK)
    box(d, 30, 66, 66, 106, WOOD_DARK)
    d.line([30, 66, 66, 106], fill=WOOD)
    d.line([66, 66, 30, 106], fill=WOOD)
    stones(d, 6, 100, 28, 106, rng)
    save(img, "buildings", "storehouse_level_1.png")

    # palisade
    img, d = canvas(96, 112)
    shadow(d, 48, 106, 46, 5)
    for i, x in enumerate(range(4, 92, 11)):
        top = 52 + (i % 2) * 6
        poly(d, [(x, 106), (x, top + 10), (x + 5, top), (x + 10, top + 10), (x + 10, 106)], WOOD if i % 2 else WOOD_LIGHT)
    box(d, 2, 78, 94, 83, WOOD_DARK)
    box(d, 2, 96, 94, 100, WOOD_DARK)
    save(img, "buildings", "palisade_level_1.png")


# --- actors ----------------------------------------------------------------------
def player():
    # 8 frames, one per facing, in PlayerController.DIRS_8 order:
    # E, SE, S, SW, W, NW, N, NE. Frame 32x48, feet at the bottom centre.
    import math
    fw, fh = 32, 48
    img, d = canvas(fw * 8, fh)
    for i in range(8):
        ox = i * fw
        a = i * math.pi / 4.0
        dx, dy = math.cos(a), math.sin(a)
        cx = ox + fw // 2
        shadow(d, cx, 44, 10, 4)
        # facing marker on the ground
        tip = (cx + int(dx * 13), 42 + int(dy * 5))
        d.line([cx, 42, tip[0], tip[1]], fill=(255, 240, 180, 220), width=2)
        box(d, cx - 6, 30, cx - 1, 43, CLOTH_DARK)
        box(d, cx + 1, 30, cx + 6, 43, CLOTH_DARK)
        box(d, cx - 8, 16, cx + 8, 33, CLOTH)
        d.ellipse([cx - 7, 3, cx + 7, 17], fill=SKIN, outline=OUTLINE)
        back = dy < -0.3
        if back:
            d.pieslice([cx - 7, 3, cx + 7, 17], 180, 360, fill=HAIR, outline=OUTLINE)
            d.rectangle([cx - 6, 9, cx + 6, 13], fill=HAIR)
        else:
            d.pieslice([cx - 7, 3, cx + 7, 17], 190, 350, fill=HAIR, outline=OUTLINE)
            ex = int(dx * 3)
            for side in (-3, 3):
                d.point([cx + side + ex, 11], fill=OUTLINE)
        # belt + a hand on the leading side
        d.line([cx - 8, 27, cx + 8, 27], fill=WOOD_DARK)
        hx = cx + int(dx * 9)
        box(d, hx - 2, 22, hx + 2, 27, SKIN)
    save(img, "actors", "player_facings.png")


# --- icons -----------------------------------------------------------------------
def icons():
    img, d = canvas(16, 16)
    d.ellipse([1, 5, 9, 13], fill=WOOD_LIGHT, outline=OUTLINE)
    box(d, 5, 5, 14, 13, WOOD)
    d.point([5, 9], fill=WOOD_DARK)
    save(img, "icons", "resource_wood.png")
    img, d = canvas(16, 16)
    poly(d, [(2, 13), (4, 6), (9, 3), (14, 8), (13, 13)], STONE)
    d.line([6, 7, 9, 10], fill=STONE_DARK)
    save(img, "icons", "resource_stone.png")
    img, d = canvas(16, 16)
    d.ellipse([3, 5, 13, 14], fill=(181, 194, 58, 255), outline=OUTLINE)
    d.line([8, 5, 10, 2], fill=LEAF_DARK, width=2)
    save(img, "icons", "resource_food.png")
    img, d = canvas(16, 16)
    poly(d, [(2, 11), (5, 5), (12, 5), (14, 11)], IRON)
    box(d, 2, 11, 14, 13, (70, 82, 96, 255))
    save(img, "icons", "resource_iron.png")
    img, d = canvas(16, 16)
    d.ellipse([5, 1, 11, 7], fill=SKIN, outline=OUTLINE)
    poly(d, [(3, 15), (4, 9), (12, 9), (13, 15)], CLOTH)
    save(img, "icons", "population.png")


def main():
    terrain()
    props()
    markers()
    sites()
    hearth()
    shelter()
    workshop()
    stockpile()
    watchpost()
    plot_buildings()
    player()
    icons()
    count = sum(len([f for f in files if f.endswith(".png")]) for _, _, files in os.walk(OUT))
    print("wrote %d placeholder images under %s" % (count, os.path.normpath(OUT)))


if __name__ == "__main__":
    sys.exit(main())
