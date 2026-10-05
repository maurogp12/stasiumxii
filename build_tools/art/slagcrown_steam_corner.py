#!/usr/bin/env python3
"""Slagcrown (lava map) steam corner (Mauro 5 Oct 2026).

Mauro sent a picture of lava streams with round boiling pools and tall steam
between them: "Can you do something like this but leaving a path that
characters can walk". Rewrites the south-west corner (x 0..4, y 10..14) of the
tags and the Tiled file:
  lava streams   x1 (y 9..11, 13..14) and x3 (y 10..11, 13..14)
  boiling pools  (2,10) (2,11) (4,10) (4,11) (0,13)   water: steam blocks sight
  walk path      column x0 down to row y12, row y12 across both streams
                 (the bridge), then (2,13)-(2,14) and (4,12)-(4,14)
The two steam vents there go (the pools steam instead). Rest of the map kept.
Run: python3 build_tools/art/slagcrown_steam_corner.py
"""
import json
import re

PATH = "art/maps/arena_colosseum_v2/tiled/slagcrown_15x15_tags.json"
TMX = "art/maps/arena_colosseum_v2/tiled/slagcrown_15x15.tmx"
G, L, W = "ground", "lava", "water"
CORNER = [  # rows y = 10..14, columns x = 0..4
    [G, L, W, L, W],
    [G, L, W, L, W],
    [G, G, G, G, G],
    [W, L, G, L, G],
    [G, L, G, L, G],
]
TERRAIN_GID = {G: "0", "mud": "33", W: "34", L: "35"}
REMOVE_PROPS = [(0, 11), (2, 10)]  # steam vents


def main():
    data = json.load(open(PATH))
    by_cell = {(c["x"], c["y"]): c for c in data["cells"]}
    for dy, row in enumerate(CORNER):
        for x, terrain in enumerate(row):
            rec = by_cell[(x, 10 + dy)]
            rec["terrain"] = terrain
            rec["elevation"] = 0
            if terrain != G:
                rec["paint_only"] = []
    for cell in REMOVE_PROPS:
        by_cell[cell]["paint_only"] = []
    with open(PATH, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    patch_tmx()
    print("slagcrown steam corner written")


def _layer(text, name):
    m = re.search(r'(<layer id="\d+" name="%s"[^>]*>\s*<data encoding="csv">\s*)(.*?)(\s*</data>)' % name, text, re.S)
    rows = [r.rstrip(",").split(",") for r in m.group(2).strip().split("\n")]
    return m, rows


def _put(text, m, rows):
    csv = ",\n".join(",".join(r) for r in rows)
    return text[:m.start(2)] + csv + text[m.end(2):]


def patch_tmx():
    text = open(TMX).read()
    m, rows = _layer(text, "terrain")
    for dy, row in enumerate(CORNER):
        for x, terrain in enumerate(row):
            rows[10 + dy][x] = TERRAIN_GID[terrain]
    text = _put(text, m, rows)
    m, rows = _layer(text, "elevation")
    for dy in range(5):
        for x in range(5):
            rows[10 + dy][x] = "0"
    text = _put(text, m, rows)
    m, rows = _layer(text, "props_paint")
    for x, y in REMOVE_PROPS:
        rows[y][x] = "0"
    text = _put(text, m, rows)
    open(TMX, "w").write(text)


if __name__ == "__main__":
    main()
