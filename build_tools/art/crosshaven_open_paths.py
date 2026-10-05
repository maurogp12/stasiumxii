#!/usr/bin/env python3
"""Crosshaven: no pocket you cannot walk out of (Mauro 5 Oct 2026, screenshot of
a fighter stuck by the fence and hay: "Heres another trap you cannot get out
make sure every map has a way to walk").

  (14,5)-(14,6) were sealed by a rock, a well and mud: (13,5) (13,6) -> ground.
  (10,13) (10,14) (11,14) (12,14) were sealed by water, mud, a rock and a fence:
      (12,13) mud -> ground and the rock at (10,12) goes (two ways out).
  (0,7) had one way out (fence, hay): the hay at (1,7) goes.
Writes the tags and the Tiled file. Run: python3 build_tools/art/crosshaven_open_paths.py
"""
import json
import re

PATH = "art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json"
TMX = "art/maps/arena_colosseum_v2/tiled/crosshaven_15x15.tmx"
TO_GROUND = [(13, 5), (13, 6), (12, 13)]
CLEAR_PROPS = [(10, 12), (1, 7)]


def _layer(text, name):
    m = re.search(r'(<layer id="\d+" name="%s"[^>]*>\s*<data encoding="csv">\s*)(.*?)(\s*</data>)' % name, text, re.S)
    return m, [r.rstrip(",").split(",") for r in m.group(2).strip().split("\n")]


def _put(text, m, rows):
    return text[:m.start(2)] + ",\n".join(",".join(r) for r in rows) + text[m.end(2):]


def main():
    data = json.load(open(PATH))
    by_cell = {(c["x"], c["y"]): c for c in data["cells"]}
    for cell in TO_GROUND:
        by_cell[cell]["terrain"] = "ground"
    for cell in CLEAR_PROPS:
        by_cell[cell]["paint_only"] = []
    with open(PATH, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    text = open(TMX).read()
    m, rows = _layer(text, "terrain")
    for x, y in TO_GROUND:
        rows[y][x] = "0"
    text = _put(text, m, rows)
    m, rows = _layer(text, "props_paint")
    for x, y in CLEAR_PROPS:
        rows[y][x] = "0"
    text = _put(text, m, rows)
    open(TMX, "w").write(text)
    print("crosshaven paths opened")


if __name__ == "__main__":
    main()
