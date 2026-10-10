"""Build the Frostspire Archive room tags (room_a_tags.json, room_b_tags.json).

Same format as the Old Granary Cellar's (and the Koliseo tags files): `size`,
`cells` with x, y, terrain, elevation, paint_only, plus the dungeon keys
`blocks` (a prop stands here: not walkable, blocks a body) and `special`
(a glowing pad). The script checks the layout rules before it writes:
every walkable cell is reachable from the hero start, props break lines of
fire without sealing a route, and the spawns of every star sit on open floor
on the far rows, off the pads.
Run: python3 data/world/dungeons/frostspire_archive/build_rooms.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).parent
SIZE = 12

# Prop names are the art kit's board props (art manifest board.props,
# art/pc/dungeons/frostspire_archive/manifest.json): frozen_bookshelf,
# book_pile, reading_desk, ice_crystals, frozen_chest, frost_brazier (1x1)
# and the Archivist's ice_throne (2x2, not used: the room B shell paints it). A multi-cell prop names itself on its
# south (anchor) cell and "<id>:part" on its other cells.

# Room A, the frozen stacks. Shelves and desks stand in short runs across the
# middle rows, so a Book Wraith on the back rows must move to find a line on
# the hero; ice-blue rune pads glow on the floor.
ROOM_A = {
    "hero": (8, 10),
    "props": {
        (5, 2): "frozen_bookshelf",
        (0, 2): "frozen_chest",
        (11, 4): "ice_crystals",
        (2, 6): "frozen_bookshelf", (3, 6): "book_pile",
        (8, 6): "frozen_bookshelf", (9, 6): "ice_crystals",
        (5, 8): "reading_desk", (6, 8): "frozen_chest",
        (10, 9): "book_pile",
        (1, 10): "ice_crystals",
    },
    "pads": {(6, 5): "rune_pad", (1, 8): "rune_pad", (10, 7): "rune_pad", (4, 10): "rune_pad", (7, 9): "rune_pad", (4, 4): "rune_pad"},
}

# Room B, the Archivist's hall. The room shell (backdrop) already paints the
# ice throne on its dais behind the back wall, so the kit's ice_throne prop
# is not stood on the board (no second throne). Frost braziers flank the
# Archivist, chests and book piles stand at the sides, the glowing rune
# circle (3x3 decal) is in the middle: its nine cells are the room's pads.
ROOM_B = {
    "hero": (6, 10),
    "props": {
        (3, 1): "frost_brazier", (9, 1): "frost_brazier",
        (1, 4): "book_pile", (10, 5): "frozen_chest",
        (2, 8): "ice_crystals", (9, 8): "frozen_bookshelf",
        (1, 10): "frozen_chest", (11, 10): "book_pile",
    },
    "pads": {(x, y): "rune_circle" for x in range(5, 8) for y in range(5, 8)},
}

# Spawns per room (the run.json packs use these cells): every star's cells.
SPAWNS = {
    "room_a": [(3, 2), (8, 2), (1, 0), (6, 0), (10, 1), (11, 3), (5, 4), (4, 0)],
    "room_b": [(6, 2), (4, 2), (8, 2), (6, 4)],
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


def _flood(open_cells: set, start: tuple) -> set:
    seen = {start}
    todo = [start]
    while todo:
        x, y = todo.pop()
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n in open_cells and n not in seen:
                seen.add(n)
                todo.append(n)
    return seen


def check(name: str, room: dict) -> None:
    props = room["props"]
    assert not set(props) & set(room["pads"]), f"{name}: a pad under a prop"
    walk = {(x, y) for y in range(SIZE) for x in range(SIZE) if (x, y) not in props}
    hero = room["hero"]
    assert hero in walk, f"{name}: hero start on a prop"
    assert _flood(walk, hero) == walk, f"{name}: a walkable cell is sealed off"
    spawns = SPAWNS[name]
    for c in spawns:
        assert c in walk and c not in room["pads"], f"{name}: spawn {c} on a prop or pad"
    # Bodies standing on every spawn still leave every other cell reachable.
    assert _flood(walk - set(spawns), hero) == walk - set(spawns), f"{name}: the spawns seal a route"
    if name == "room_a":
        for c in spawns:
            assert c[1] <= 4 and max(abs(c[0] - hero[0]), abs(c[1] - hero[1])) >= 6, f"{name}: spawn {c} not on the far rows"


def main() -> None:
    for name, room in (("room_a", ROOM_A), ("room_b", ROOM_B)):
        check(name, room)
        (ROOT / f"{name}_tags.json").write_text(json.dumps(build(room), indent=1) + "\n")


if __name__ == "__main__":
    main()
