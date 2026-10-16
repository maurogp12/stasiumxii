"""Writes art/pc/world/stoneford/manifest.json (package Z1): the Stoneford
world monster kit in the dungeon art format (`stasium.dungeon_art`), so the
board view, the monster pawns and the map layer load it the same way.
Rows are the monsters' meta.json files.

  python3 build_stoneford_manifest.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402

gkit.use_world("stoneford")
ORDER = ["bristleback_boar", "mandrake_rootling", "thistle_puffball", "flour_moth", "grimhoot_orchard_owl", "old_gulp_millpond_toad", "thresher_stag"]


def main():
    rows = []
    for mid in ORDER:
        p = os.path.join(gkit.OUT, "monsters", mid, "meta.json")
        if not os.path.exists(p):
            print("missing", mid)
            continue
        meta = json.load(open(p))
        row = {k: meta[k] for k in ("id", "name", "dir", "cell", "pivot", "fps", "facings", "mirror", "actions") if k in meta}
        for k in ("release", "role", "flies"):
            if k in meta:
                row[k] = meta[k]
        rows.append(row)
    doc = {
        "format": "stasium.dungeon_art",
        "format_version": 1,
        "zone": "stoneford",
        "name": "Stoneford world monsters",
        "root": "res://art/pc/world/stoneford/",
        "conventions": "Painted-part rigs, 512x360 cells pivot (256,329), bosses 768x540 pivot (384,494), 17.144 fps, S and E painted, W and N mirrored, binary alpha. Open-world monsters only: never a dungeon monster (Mauro).",
        "monsters": rows,
    }
    out = os.path.join(gkit.OUT, "manifest.json")
    with open(out, "w") as fh:
        json.dump(doc, fh, indent=1)
    print("wrote", out, len(rows), "monsters")


if __name__ == "__main__":
    main()
