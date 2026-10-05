#!/usr/bin/env python3
"""Slagcrown (lava map) west crossing (Mauro 5 Oct 2026, screenshot with the
two lava tiles circled: "Remove the 2 tiles circled because there is not a
path to keep walking"). The lava row y=7 cut the board in two; (1,7) and (2,7)
become plain ground so fighters can cross on the west side. Then ("yes open
the east side too") the mirror pair (12,7) and (13,7) opens as well.
Writes the tags and the Tiled file. Run after slagcrown_steam_corner.py:
  python3 build_tools/art/slagcrown_west_crossing.py
"""
import json
import re

PATH = "art/maps/arena_colosseum_v2/tiled/slagcrown_15x15_tags.json"
TMX = "art/maps/arena_colosseum_v2/tiled/slagcrown_15x15.tmx"
CELLS = [(1, 7), (2, 7), (12, 7), (13, 7)]


def main():
    data = json.load(open(PATH))
    for c in data["cells"]:
        if (c["x"], c["y"]) in CELLS:
            c["terrain"] = "ground"
            c["elevation"] = 0
            c["paint_only"] = []
    with open(PATH, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    text = open(TMX).read()
    m = re.search(r'(<layer id="\d+" name="terrain"[^>]*>\s*<data encoding="csv">\s*)(.*?)(\s*</data>)', text, re.S)
    rows = [r.rstrip(",").split(",") for r in m.group(2).strip().split("\n")]
    for x, y in CELLS:
        rows[y][x] = "0"
    text = text[:m.start(2)] + ",\n".join(",".join(r) for r in rows) + text[m.end(2):]
    open(TMX, "w").write(text)
    print("west crossing open at", CELLS)


if __name__ == "__main__":
    main()
