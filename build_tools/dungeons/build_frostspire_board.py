"""Frostspire Archive combat-board kit: floor tiles, rune pad, props, rune circle, backdrops.

The cutting code is shared (board_kit.py); this file is the Frostspire piece list.
Every keyed piece here is painted on flat MAGENTA (#FF00FF): the ice-blue paint
would be eaten by a green key.
Room A = the archive stacks (pack fight), room B = the Pale Archivist's reading hall (boss).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import board_kit  # noqa: E402

ICE = (0.42, 0.74, 1.0)
META = {"tiles": [], "props": [], "decals": [], "glows": [], "backdrops": []}


def cyan_lines(rgb, alpha):
    """The glowing ice-blue rune lines of a top-down painting (rgb 0..1)."""
    lum = rgb.mean(-1)
    blue = rgb[..., 2] - rgb[..., 0]
    return (np.clip((lum - 0.55) / 0.3, 0, 1) * np.clip((blue - 0.05) / 0.2, 0, 1) * alpha).astype(np.float32)


def flame(st, al):
    """Cold flame / glowing ice on a prop (straight rgb 0..1): bright and blue."""
    lum = st.mean(-1)
    return (np.clip((lum - 0.62) / 0.25, 0, 1) * np.clip((st[..., 2] - st[..., 0] - 0.1) / 0.25, 0, 1) * (al > 0.5)).astype(np.float32)


def flame_top(st, al):
    """The brazier's flame only (the upper half of the sprite), not its icy base."""
    m = flame(st, al)
    m[int(m.shape[0] * 0.42):] = 0
    return m


def build():
    gkit.use("frostspire_archive")
    b = board_kit.Board(key="magenta", floor_fill=(16, 20, 30))
    for i in (1, 2, 3):
        b.tile("floor_a_%d.jpg" % i, "archive_floor_%s" % "abc"[i - 1], "a")
        b.tile("floor_b_%d.jpg" % i, "hall_floor_%s" % "abc"[i - 1], "b")
    pr = b.tile("rune_pad.jpg", "rune_pad", "a", kind="glow_pad")
    lum = pr.mean(-1)
    bright = (np.clip((lum - 0.58) / 0.3, 0, 1) * np.clip((pr[..., 2] - pr[..., 0] - 0.05) / 0.2, 0, 1)).astype(np.float32)
    b.pad_glow(pr, "rune_pad_glow", "rune_pad", col=ICE, bright=bright, gain=(3.2, 0.9))
    g = {"mul": (0.9, 0.92, 0.96), "sat": 0.92}
    b.prop("frozen_bookshelf.jpg", "frozen_bookshelf", "a+b", 60, grade=g,
           notes="short frozen bookshelf with a candle; line-of-fire cover in room A")
    b.prop("book_pile.jpg", "book_pile", "a+b", 62, grade=g, notes="waist-high frozen heap of books and scrolls")
    b.prop("reading_desk.jpg", "reading_desk", "a", 60, grade=g, notes="frozen scholar's desk with an open book and a candle")
    b.prop("ice_crystals.jpg", "ice_crystals", "a+b", 50, grade={"mul": (0.92, 0.94, 0.98), "sat": 0.95},
           notes="cluster of glowing ice crystals; has an additive _glow", glow=(flame, ICE, 4, 1.6))
    b.prop("frozen_chest.jpg", "frozen_chest", "a+b", 56, grade=g, notes="iron-banded chest with a crate and books on top")
    b.prop("frost_brazier.jpg", "frost_brazier", "b", 44, grade={"mul": (0.95, 0.96, 1.0), "sat": 0.95},
           notes="iron brazier burning with cold blue flame; has an additive _glow (flicker it)", glow=(flame_top, ICE, 5, 2.0))
    b.prop("ice_throne.jpg", "ice_throne", "b", 140, footprint=(2, 2), grade={"mul": (0.92, 0.94, 0.98), "sat": 0.95},
           notes="the Pale Archivist's ice throne behind the chained-grimoire lectern on a stone plinth; 2x2 blocker, place against the back wall")
    b.decal("rune_circle.jpg", "rune_circle", n=3, room="b", glow_mask=cyan_lines, glow_col=ICE, glow_gain=(3, 1.2, 0.35))
    for n in (15, 12):
        b.backdrop("shell_room_a.jpg", "room_a_archive", "a", n, "archive_floor")
        b.backdrop("shell_room_b.jpg", "room_b_hall", "b", n, "hall_floor")
    for k in META:
        META[k][:] = b.META[k]
    return META


if __name__ == "__main__":
    import json
    m = build()
    gkit.write_json(os.path.join(os.path.dirname(os.path.abspath(__file__)), "_board_meta_frostspire.json"), m)
    print(json.dumps({k: [e["id"] for e in v] for k, v in m.items()}))
    for bd in m["backdrops"]:
        print(bd["id"], bd["size"], bd["cell00_centre_px"], bd["fit_residual_px"])
