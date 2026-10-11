"""Heart of the Blight combat-board kit: floor tiles, violet sigil pad, props, root-rune circle, root veins, backdrops.

The cutting code is shared (board_kit.py); this file is the Blight piece list.
Every keyed piece here is painted on flat GREEN (#00FF00). The blight is violet and magenta, the
opposite hue to the green key, so a magenta key (as the Abbey used) would eat exactly the colour
that matters here. The olive moss and the brown bark key cleanly on green (checked on every cut).
Room A = the blighted crypt (pack fight), room B = the Rotting Elder's heart chamber (boss).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import board_kit  # noqa: E402

VIOLET = (0.8, 0.38, 1.0)
CRYPT_GRADE = {"mul": (0.92, 0.9, 0.94), "sat": 0.95}
# The heart-chamber slabs came out brighter and warmer than the crypt; darken them so the rune circle and the units read.
HEART_GRADE = {"mul": (0.78, 0.74, 0.8), "sat": 0.88, "gamma": 1.08}
RUNE_N = 5  # the design's ring is ~3.8 tile widths across = a top-down circle of ~5.4 cells: 5x5
META = {"tiles": [], "props": [], "decals": [], "glows": [], "backdrops": []}


def violet_bright(rgb):
    """Glowing violet/magenta paint (straight rgb 0..1): bright, red and blue well above green."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    vio = np.minimum(r, b) - g
    lum = np.maximum(r, b)
    return (np.clip((vio - 0.18) / 0.25, 0, 1) * np.clip((lum - 0.55) / 0.3, 0, 1)).astype(np.float32)


def violet_mask(st, al):
    """Prop glow mask (straight rgb 0..1, alpha): the glowing violet crystal faces, caps and veins."""
    return (violet_bright(st) * (al > 0.5)).astype(np.float32)


def rune_lines(rgb, alpha):
    return violet_bright(rgb) * alpha


def mask_outside_diamond(out_id, n):
    """Clear the decal (and its glow, beyond a few px) outside its footprint diamond (as the Abbey's rune circle)."""
    from PIL import Image
    for sub, k in (("", 1), ("_2x", 2)):
        for name, grow in ((out_id, 0.5), (out_id + "_glow", 3.0)):
            p = os.path.join(gkit.OUT, "board", "props", sub, name + ".png")
            im = np.asarray(Image.open(p).convert("RGBA")).copy()
            m = gkit.diamond_mask(64 * n * k, 32 * n * k, grow * k)
            im[~m] = 0
            gkit.save_png(p, im)


def build():
    gkit.use("heart_of_the_blight")
    import build_abbey_board as abbey  # the 1-cell ground decal helper (the Abbey's lily pads), with the green key
    b = board_kit.Board(key="green", floor_fill=(20, 14, 22))
    for i in (1, 2, 3):
        b.tile("floor_a_%d.jpg" % i, "crypt_floor_%s" % "abc"[i - 1], "a", grade=CRYPT_GRADE)
        b.tile("floor_b_%d.jpg" % i, "heart_floor_%s" % "abc"[i - 1], "b", grade=HEART_GRADE)
    pr = b.tile("blight_pad.jpg", "blight_pad", "a", kind="glow_pad")
    b.pad_glow(pr, "blight_pad_glow", "blight_pad", col=VIOLET, bright=violet_bright(pr), gain=(2.4, 0.7))
    g = {"mul": (0.92, 0.9, 0.92), "sat": 0.95}
    vg = (violet_mask, VIOLET, 3.0, 2.2)
    b.prop("violet_crystals.jpg", "violet_crystals", "a+b", 54, grade=g, glow=vg,
           notes="a cluster of sharp glowing violet crystals on dark rock and roots with a skull; has an additive _glow")
    b.prop("crystal_spire.jpg", "crystal_spire", "b", 40, grade=g, glow=vg,
           notes="one tall glowing violet crystal spire on broken stones and roots (tall); has an additive _glow")
    b.prop("root_knot.jpg", "root_knot", "a+b", 58, grade=g,
           notes="knee-high knot of thorny blighted roots bursting through broken flagstones, faint violet veins")
    b.prop("bone_pile.jpg", "bone_pile", "a+b", 60, grade=g, notes="heap of old bones, two skulls and a ribcage tangled in roots")
    b.prop("broken_masonry.jpg", "broken_masonry", "b", 56, grade=g,
           notes="waist-high corner of a collapsed sandstone wall with tumbled blocks, roots and two small crystals")
    b.prop("fungus_clump.jpg", "fungus_clump", "a", 52, grade=g, glow=vg,
           notes="cluster of glowing violet toadstools on a rotten root stump; has an additive _glow")
    b.prop("chained_cocoon.jpg", "chained_cocoon", "b", 42, grade=g, glow=vg,
           notes="man-sized root-and-husk cocoon chained to a post, violet light through the husk, a skeletal hand (tall); has an additive _glow")
    b.prop("blight_eggs.jpg", "blight_eggs", "b", 58, grade=g, glow=vg,
           notes="clutch of four leathery violet-veined eggs in a nest of roots, one cracked open; has an additive _glow")
    b.prop("root_mound.jpg", "root_mound", "a", 124, footprint=(2, 2), grade=g,
           notes="big low mound of thorny blighted roots with crystals and a skull caught in it; 2x2 blocker")
    b.decal("rune_circle.jpg", "root_rune_circle", n=RUNE_N, room="b", glow_mask=rune_lines, glow_col=VIOLET, glow_gain=(3, 1.0, 0.35))
    mask_outside_diamond("root_rune_circle", RUNE_N)
    b.META["decals"].append(abbey.ground_cell_decal("root_veins.jpg", "root_veins", "a+b",
                                                    "thin blighted root veins with violet cracks and crystal grit; walkable ground dressing, scatter on any cell",
                                                    grade={"mul": (0.9, 0.88, 0.92), "sat": 0.95}, key=gkit.key_green))
    for n in (15, 12):
        b.backdrop("shell_room_a.jpg", "room_a_crypt", "a", n, "crypt_floor")
        b.backdrop("shell_room_b.jpg", "room_b_heart", "b", n, "heart_floor")
    for k in META:
        META[k][:] = b.META[k]
    return META


if __name__ == "__main__":
    import json
    m = build()
    print(json.dumps({k: [(e["id"], e.get("size")) for e in v] for k, v in m.items()}))
    for bd in m["backdrops"]:
        print(bd["id"], bd["size"], bd["cell00_centre_px"], bd["fit_residual_px"])
