"""Build the Old Granary Cellar room tags (room_a_tags.json, room_b_tags.json).

Same format as the Koliseo tags files (`size`, `cells` with x, y, terrain,
elevation, paint_only) plus two optional keys the dungeon loader reads:
`blocks` (a prop stands here: not walkable, blocks a body) and `special`
(a glowing pad). Run: python3 data/world/dungeons/old_granary_cellar/build_rooms.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).parent
SIZE = 12

# Prop names are the art kit's board props (art manifest board.props):
# crate_stack, grain_sacks, barrel_cluster, broken_crate (1x1) and the
# Ratking's bone_throne (2x2). A multi-cell prop names itself on its south
# (anchor) cell and "<id>:part" on its other cells.

# Room A, the cellar stores. Sacks, barrels and crates block tiles; amber
# wheat pads glow on the floor.
ROOM_A = {
    "props": {
        (1, 6): "grain_sacks", (1, 7): "grain_sacks",
        (9, 1): "barrel_cluster", (10, 1): "barrel_cluster",
        (5, 5): "crate_stack", (6, 5): "broken_crate",
        (10, 7): "crate_stack",
        (3, 9): "barrel_cluster",
        (7, 9): "grain_sacks",
        (0, 2): "broken_crate",
    },
    "pads": {(4, 3): "wheat_pad", (8, 4): "wheat_pad", (3, 6): "wheat_pad", (7, 7): "wheat_pad"},
}

# Room B, the Ratking's lair. The bone throne against the back wall, crates
# and sacks at the sides, the glowing drain grate (3x3 decal) in the middle:
# its nine cells are the room's pads.
ROOM_B = {
    "props": {
        (5, 0): "bone_throne:part", (6, 0): "bone_throne:part", (5, 1): "bone_throne:part", (6, 1): "bone_throne",
        (2, 2): "crate_stack", (9, 2): "barrel_cluster",
        (1, 7): "grain_sacks", (10, 6): "broken_crate",
        (4, 9): "grain_sacks", (8, 9): "barrel_cluster",
    },
    "pads": {(x, y): "drain_grate" for x in range(5, 8) for y in range(5, 8)},
}


def build(room: dict) -> dict:
    cells = []
    for y in range(SIZE):
        for x in range(SIZE):
            rec = {"x": x, "y": y, "terrain": "ground", "elevation": 0, "paint_only": []}
            prop = room["props"].get((x, y))
            if prop:
                rec["paint_only"] = [prop]
                rec["blocks"] = True
            pad = room["pads"].get((x, y))
            if pad:
                rec["paint_only"] = [pad]
                rec["special"] = "pad"
            cells.append(rec)
    return {"size": [SIZE, SIZE], "cells": cells}


def main() -> None:
    for name, room in (("room_a", ROOM_A), ("room_b", ROOM_B)):
        (ROOT / f"{name}_tags.json").write_text(json.dumps(build(room), indent=1) + "\n")


if __name__ == "__main__":
    main()
