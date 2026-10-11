"""Drowned Abbey combat-board kit: floor tiles, candle-rune pad, props, rune circle, lily pads, backdrops.

The cutting code is shared (board_kit.py); this file is the Abbey piece list.
Every keyed piece here is painted on flat MAGENTA (#FF00FF): the green moss, the green
rune light and the green water would be eaten by a green key.
Room A = the flooded nave (pack fight), room B = the Mire Abbess's sanctum (boss).
"""
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import board_kit  # noqa: E402

RUNE_GREEN = (0.62, 1.0, 0.32)
CANDLE = (1.0, 0.72, 0.3)
# The sanctum slabs came out with bright caustics; darken them a little so the rune circle and the units read on top.
SANCTUM_GRADE = {"mul": (0.82, 0.86, 0.84), "sat": 0.9, "gamma": 1.05}
NAVE_GRADE = {"mul": (0.9, 0.92, 0.9), "sat": 0.92}
RUNE_N = 5  # the design's ring is ~4.2 tile widths across (a top-down circle ~6 cells); 5x5 as the systems layout asks
META = {"tiles": [], "props": [], "decals": [], "glows": [], "backdrops": []}


def rune_bright(rgb):
    """Glowing yellow-green rune paint of a top-down painting (rgb 0..1)."""
    lum = rgb.mean(-1)
    t = rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2]) * 0.8
    return (np.clip((lum - 0.45) / 0.3, 0, 1) * np.clip((t - 0.05) / 0.25, 0, 1)).astype(np.float32)


def rune_lines(rgb, alpha):
    return rune_bright(rgb) * alpha


def flames(st, al):
    """Candle flames on a prop (straight rgb 0..1): the near-white flame cores and the bright yellow-orange flame light."""
    r, g, b = st[..., 0] * 255, st[..., 1] * 255, st[..., 2] * 255
    core = np.clip((g - 235) / 15, 0, 1) * np.clip((b - 185) / 30, 0, 1) * np.clip((r - 235) / 15, 0, 1)
    halo = np.clip((r - 232) / 15, 0, 1) * np.clip((g - 165) / 40, 0, 1) * np.clip((150 - b) / 60, 0, 1)
    return (np.clip(core + 0.8 * halo, 0, 1) * (al > 0.5)).astype(np.float32)


def mask_outside_diamond(out_id, n):
    """Clear the decal (and its glow, beyond a few px) outside its footprint diamond (as the Saltmaw whirlpool)."""
    from PIL import Image
    for sub, k in (("", 1), ("_2x", 2)):
        for name, grow in ((out_id, 0.5), (out_id + "_glow", 3.0)):
            p = os.path.join(gkit.OUT, "board", "props", sub, name + ".png")
            im = np.asarray(Image.open(p).convert("RGBA")).copy()
            m = gkit.diamond_mask(64 * n * k, 32 * n * k, grow * k)
            im[~m] = 0
            gkit.save_png(p, im)


def ground_cell_decal(src, out_id, room, note, inset=0.96, grade=None, key=None):
    """A 1-cell walkable ground decal (no glow): a keyed top-down painting mapped into the 64x32 diamond.
    key: the keyer (default gkit.key_magenta, the Abbey's)."""
    rgb = gkit.load_rgb(src)
    prem = gkit.clean_alpha((key or gkit.key_magenta)(rgb), min_island=40)
    if grade:
        prem = gkit.grade(prem, **grade)
    # Crop to a square around the painted content (the cluster sits in the middle with wide margins).
    ys, xs = np.nonzero(prem[..., 3] > 0.5)
    cx, cy = (xs.min() + xs.max()) / 2.0, (ys.min() + ys.max()) / 2.0
    half = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2.0 + 8
    x0, y0 = int(max(0, cx - half)), int(max(0, cy - half))
    prem = prem[y0:int(cy + half), x0:int(cx + half)]
    prem = cv2.resize(prem, (768, 768), interpolation=cv2.INTER_AREA)
    for sub, k in (("", 1), ("_2x", 2)):
        W, H = 64 * k, 32 * k
        ss = 4
        ys, xs = np.mgrid[0:H * ss, 0:W * ss].astype(np.float32) + 0.5
        px = (xs - W * ss / 2) / (W * ss / 2)
        py = ys / (H * ss / 2)
        s = ((px + py) / 2.0 - 0.5) * inset + 0.5
        t = ((py - px) / 2.0 - 0.5) * inset + 0.5
        mx = (np.clip(s, 0, 1) * 767).astype(np.float32)
        my = (np.clip(t, 0, 1) * 767).astype(np.float32)
        big = cv2.remap(prem, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        big[(s < 0) | (s > 1) | (t < 0) | (t > 1)] = 0
        im = gkit.binarize(cv2.resize(big, (W, H), interpolation=cv2.INTER_AREA))
        gkit.save_png(os.path.join(gkit.OUT, "board", "props", sub, out_id + ".png"), im)
    return {
        "id": out_id, "room": room, "kind": "floor_decal", "blocks": False, "walkable": True,
        "file": "board/props/%s.png" % out_id, "file_2x": "board/props/_2x/%s.png" % out_id,
        "size": [64, 32], "size_2x": [128, 64], "footprint_size": [1, 1], "footprint_from_nw": [[0, 0]], "anchor_cell_from_nw": [0, 0],
        "anchor": "image centre = cell centre (cell_to_local), same as a floor tile",
        "bottom_centre_from_nw_centre_1x": [0, 16],
        "layer": "ground: after floor tiles, before props and units (no y-sort)", "source": src, "note": note,
    }


def build():
    gkit.use("drowned_abbey")
    b = board_kit.Board(key="magenta", floor_fill=(14, 22, 16))
    for i in (1, 2, 3):
        b.tile("floor_a_%d.jpg" % i, "nave_floor_%s" % "abc"[i - 1], "a", grade=NAVE_GRADE)
        b.tile("floor_b_%d.jpg" % i, "sanctum_floor_%s" % "abc"[i - 1], "b", grade=SANCTUM_GRADE)
    pr = b.tile("candle_pad.jpg", "candle_pad", "a", kind="glow_pad")
    b.pad_glow(pr, "candle_pad_glow", "candle_pad", col=RUNE_GREEN, bright=rune_bright(pr), gain=(2.6, 0.8))
    g = {"mul": (0.9, 0.92, 0.9), "sat": 0.92}
    cg = (flames, CANDLE, 2.5, 7.0)
    b.prop("pew.jpg", "pew", "a", 62, grade=g, notes="broken dark-wood abbey pew with a carved back, one end snapped; line-of-fire cover in room A")
    b.prop("broken_pillar.jpg", "broken_pillar", "a+b", 56, grade=g, notes="broken fluted column stump with its fallen drum, rubble, ivy and three candles")
    b.prop("fallen_statue.jpg", "fallen_statue", "a", 62, grade=g, notes="toppled winged saint statue on rubble with a broken column and candles")
    b.prop("candle_cluster.jpg", "candle_cluster", "a+b", 50, grade={"mul": (0.95, 0.95, 0.93), "sat": 0.95},
           notes="mossy stone block heaped with lit melted candles; has an additive _glow", glow=cg)
    b.prop("coffin.jpg", "coffin", "a+b", 60, grade=g, notes="rotting wooden coffin, lid split and half open, lily leaves and moss")
    b.prop("gravestone.jpg", "gravestone", "a", 44, grade=g, notes="leaning mossy headstone with a carved cross and a candle stub")
    b.prop("gnarled_roots.jpg", "gnarled_roots", "a+b", 58, grade=g, notes="knee-high knot of gnarled roots bursting through broken flagstones")
    b.prop("altar.jpg", "altar", "b", 62, grade={"mul": (0.95, 0.95, 0.93), "sat": 0.95},
           notes="stone altar with a tattered green-sun cloth and lit candles; has an additive _glow", glow=cg)
    b.prop("candle_stand.jpg", "candle_stand", "b", 40, grade={"mul": (0.95, 0.95, 0.93), "sat": 0.95},
           notes="tall stone pedestal heaped with lit candles (tall); has an additive _glow", glow=cg)
    b.prop("floating_coffin.jpg", "floating_coffin", "b", 60, grade=g, notes="closed coffin floating low in the flood water with lily pads and ripples")
    b.prop("saint_statue.jpg", "saint_statue", "b", 36, grade=g, notes="tall hooded praying nun statue on a mossy plinth, two candles (tall)")
    b.prop("fallen_bell.jpg", "fallen_bell", "b", 124, footprint=(2, 2), grade=g,
           notes="the abbey's huge fallen bronze bell on its side on rubble, wrapped in roots; 2x2 blocker")
    b.decal("rune_circle.jpg", "rune_circle", n=RUNE_N, room="b", glow_mask=rune_lines, glow_col=RUNE_GREEN, glow_gain=(3, 1.0, 0.35))
    mask_outside_diamond("rune_circle", RUNE_N)
    b.META["decals"].append(ground_cell_decal("lily_pads.jpg", "lily_pads", "a+b",
                                              "a few floating lily pads and a water lily; walkable ground dressing, scatter on wet cells"))
    for n in (15, 12):
        b.backdrop("shell_room_a.jpg", "room_a_nave", "a", n, "nave_floor")
        b.backdrop("shell_room_b.jpg", "room_b_sanctum", "b", n, "sanctum_floor")
    for k in META:
        META[k][:] = b.META[k]
    return META


if __name__ == "__main__":
    import json
    m = build()
    print(json.dumps({k: [(e["id"], e.get("size")) for e in v] for k, v in m.items()}))
    for bd in m["backdrops"]:
        print(bd["id"], bd["size"], bd["cell00_centre_px"], bd["fit_residual_px"])
