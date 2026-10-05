#!/usr/bin/env python3
"""Brinewake dock layout (Mauro 5 Oct 2026).

"Lets change all obstacles in the dock map ... obstacles have to be something
above the ground", then "dont put too many obstacles / dont do the flag / I
really like the rocks that looks like coral and the plants ... the ship in the
middle just without the flags and a little bit less obstacles".

Rewrites only the paint_only props of the Koliseo dock map tags (terrain,
elevation and size are kept). 9 obstacles instead of 13:
  shipwreck across (6,7) (7,7) (8,7)  - drawn once as the centrepiece on (7,7)
  coral rocks  (3,3) (11,3) (3,11) (11,11)
  crates       (7,2) (7,12)
  chests       (1,4) (13,10)
Coral plants grow on six water tiles (decoration; water is not walkable anyway).
The eight raised blocks around the wreck are flattened (the picture is flat there).
Run: python3 build_tools/art/brinewake_dock_layout.py
"""
import json

PATH = "art/maps/arena_colosseum_v2/tiled/brinewake_15x15_tags.json"
TMX = "art/maps/arena_colosseum_v2/tiled/brinewake_15x15.tmx"

PROPS = {
    (6, 7): "wreck_side", (7, 7): "wreck_side", (8, 7): "wreck_side",
    (3, 3): "coral_rock", (11, 3): "coral_rock", (3, 11): "coral_rock", (11, 11): "coral_rock",
    (7, 2): "crate", (7, 12): "crate",
    (1, 4): "chest", (13, 10): "chest",
}
CORAL_ON_WATER = [(1, 1), (12, 2), (0, 6), (14, 5), (4, 12), (10, 13)]
# The raised blocks hugging the middle hid the wreck; the picture's dock is
# flat there. The outer raised blocks stay.
FLATTEN = [(7, 5), (7, 6), (7, 8), (7, 9), (5, 5), (9, 5), (5, 9), (9, 9)]


def main():
    data = json.load(open(PATH))
    by_cell = {(c["x"], c["y"]): c for c in data["cells"]}
    for c in data["cells"]:
        c["paint_only"] = []
    for cell, prop in PROPS.items():
        rec = by_cell[cell]
        assert rec["terrain"] == "ground", (cell, rec)
        rec["paint_only"] = [prop]
    for cell in FLATTEN:
        by_cell[cell]["elevation"] = 0
    for cell in CORAL_ON_WATER:
        rec = by_cell[cell]
        assert rec["terrain"] == "water", (cell, rec)
        rec["paint_only"] = ["coral"]
    with open(PATH, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    flatten_tmx()
    print("brinewake dock: %d obstacles, %d coral plants" % (len(PROPS), len(CORAL_ON_WATER)))


def flatten_tmx():
    """The sibling Tiled file must keep the same elevation (CellTagMap.cross_check_tmx)."""
    import re
    text = open(TMX).read()
    m = re.search(r'(<layer id="\d+" name="elevation"[^>]*>\s*<data encoding="csv">\s*)(.*?)(\s*</data>)', text, re.S)
    rows = [r.rstrip(",").split(",") for r in m.group(2).strip().split("\n")]
    for x, y in FLATTEN:
        rows[y][x] = "0"
    csv = ",\n".join(",".join(r) for r in rows)
    text = text[:m.start(2)] + csv + text[m.end(2):]
    open(TMX, "w").write(text)


if __name__ == "__main__":
    main()
