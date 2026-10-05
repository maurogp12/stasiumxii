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

# Room A, the cellar stores. Props from the approved painting: grain sacks,
# barrels and crates block tiles; amber wheat pads glow on the floor.
ROOM_A = {
    "props": {
        (1, 6): "sack_pile", (1, 7): "sack_pile",
        (9, 1): "barrel", (10, 1): "barrel",
        (5, 5): "crate_stack", (6, 5): "crate",
        (10, 7): "crate",
        (3, 9): "barrel",
        (7, 9): "sack",
        (0, 2): "lantern_post",
    },
    "pads": [(4, 3), (8, 4), (3, 6), (7, 7)],
}

# Room B, the Ratking's lair. Sack-and-bone throne at the back, farm tools on
# the side walls, the glowing drain grate in the middle.
ROOM_B = {
    "props": {
        (5, 0): "throne", (6, 0): "throne",
        (2, 2): "tool_rack", (9, 2): "tool_rack",
        (1, 7): "bone_pile", (10, 6): "bone_pile",
        (4, 9): "sack", (8, 9): "barrel",
    },
    "pads": [(5, 5), (6, 5), (5, 6), (6, 6)],
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
            if (x, y) in room["pads"]:
                rec["paint_only"] = ["wheat_pad"] if "throne" not in room["props"].values() else ["drain_grate"]
                rec["special"] = "pad"
            cells.append(rec)
    return {"size": [SIZE, SIZE], "cells": cells}


def main() -> None:
    for name, room in (("room_a", ROOM_A), ("room_b", ROOM_B)):
        (ROOT / f"{name}_tags.json").write_text(json.dumps(build(room), indent=1) + "\n")


if __name__ == "__main__":
    main()
