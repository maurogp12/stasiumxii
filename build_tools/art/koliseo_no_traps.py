#!/usr/bin/env python3
"""Koliseo maps: no spot one fighter can seal you into (Mauro 5 Oct 2026,
Windmere screenshot of Kestrel shut in behind Ironjaw: "He is trapped again",
after "make sure every map has a way to walk").

A search over the walk graph (real rules: ground only, blocking / tall props,
centrepiece, climb at most 1) found every tile that, with one body standing on
it, cuts other tiles off from the rest of the board. These changes remove all
of them with as few edits as possible (mud first, then a prop, then water /
lava). Mauro's approved pieces stay: the dock wreck / crates / coral rocks,
the Slagcrown boiling pools and pits, the Windmere centre crystal; the dock
chest only moves one tile.
Writes the tags and the Tiled file of each map.
Run: python3 build_tools/art/koliseo_no_traps.py
"""
import json
import re

ROOT = "art/maps/arena_colosseum_v2/tiled/%s_15x15"
G = "ground"
# map -> list of (cell, new terrain or None, new elevation or None, props or None)
CHANGES = {
    "crosshaven": [
        ((1, 13), G, None, None), ((2, 1), G, None, None), ((11, 1), G, None, None),
        ((1, 2), G, None, None), ((2, 2), G, None, None),
        ((14, 7), None, None, []),   # well
        ((5, 13), None, None, []),   # fence
        ((1, 1), G, None, None),     # corner (0,1) gets a second way out
        ((6, 4), None, 1, None),     # a step up to the high platform (7,4)
    ],
    "brinewake": [
        ((1, 3), G, None, None), ((14, 10), G, None, None), ((2, 7), G, None, None),
        ((12, 7), G, None, None), ((6, 13), G, None, None), ((6, 6), G, None, None),
        ((1, 4), None, None, []), ((2, 3), None, None, ["chest"]),  # chest moves one tile
    ],
    "slagcrown": [
        ((5, 12), G, None, None), ((3, 14), G, None, None),
        ((6, 3), None, None, []), ((8, 3), None, None, []),       # rock pillars
        ((7, 6), G, None, None), ((7, 10), G, None, None), ((4, 7), G, None, None), ((8, 7), G, None, None),
    ],
    "windmere": [
        ((7, 14), None, None, []), ((6, 6), None, None, []),       # ice shards
        ((8, 8), None, None, []), ((2, 6), None, None, []),        # crystal, spark
        ((13, 8), G, None, None), ((1, 8), G, None, None), ((10, 8), G, None, None),   # water
        ((6, 5), G, None, None), ((4, 3), G, None, None), ((10, 3), G, None, None),
        ((0, 5), G, None, None), ((5, 13), G, None, None), ((9, 13), G, None, None),   # mud
    ],
    "stormspire": [
        ((3, 5), None, None, []), ((11, 5), None, None, []),       # rock pillars
    ],
}


def _layer(text, name):
    m = re.search(r'(<layer id="\d+" name="%s"[^>]*>\s*<data encoding="csv">\s*)(.*?)(\s*</data>)' % name, text, re.S)
    return m, [r.rstrip(",").split(",") for r in m.group(2).strip().split("\n")]


def _put(text, m, rows):
    return text[:m.start(2)] + ",\n".join(",".join(r) for r in rows) + text[m.end(2):]


def _gid_for(rows, by_cell, key, value):
    """The gid this Tiled layer already uses for a tag value."""
    for (x, y), rec in by_cell.items():
        if rec[key] == value:
            return rows[y][x]
    raise SystemExit("no gid for %s=%s" % (key, value))


def _prop_gid(rows, by_cell, prop):
    for (x, y), rec in by_cell.items():
        if rec["paint_only"] and rec["paint_only"][0] == prop:
            return rows[y][x]
    raise SystemExit("no gid for prop " + prop)


def main():
    for map_id, changes in CHANGES.items():
        path = ROOT % map_id + "_tags.json"
        tmx = ROOT % map_id + ".tmx"
        data = json.load(open(path))
        by_cell = {(c["x"], c["y"]): c for c in data["cells"]}
        text = open(tmx).read()
        mt, trows = _layer(text, "terrain")
        me, erows = _layer(text, "elevation")
        mp, prows = _layer(text, "props_paint")
        for cell, terrain, elev, props in changes:
            x, y = cell
            rec = by_cell[cell]
            if terrain is not None:
                trows[y][x] = _gid_for(trows, by_cell, "terrain", terrain)
                rec["terrain"] = terrain
            if elev is not None:
                erows[y][x] = _gid_for(erows, by_cell, "elevation", elev)
                rec["elevation"] = elev
            if props is not None:
                prows[y][x] = _prop_gid(prows, by_cell, props[0]) if props else "0"
                rec["paint_only"] = list(props)
        text = _put(text, mt, trows)
        _, erows2 = _layer(text, "elevation")
        me, _ = _layer(text, "elevation")
        text = _put(text, me, erows)
        mp, _ = _layer(text, "props_paint")
        text = _put(text, mp, prows)
        open(tmx, "w").write(text)
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        print(map_id, len(changes), "edits")


if __name__ == "__main__":
    main()
