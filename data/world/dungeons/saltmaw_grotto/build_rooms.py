"""Build the Saltmaw Grotto room tags (room_a_tags.json, room_b_tags.json).

Same format as the Old Granary Cellar's and the Frostspire Archive's (and the
Koliseo tags files): `size`, `cells` with x, y, terrain, elevation,
paint_only, plus the dungeon keys `blocks` (a prop stands here: not walkable,
blocks a body) and `special` (a glowing pad). The script checks the layout
rules before it writes:
- every walkable cell is reachable from the hero start;
- the spawns of every star sit on open floor, off the pads, and room A's on
  the far rows (y 0-4, 6+ cells from the hero);
- bodies on every spawn still leave every route open;
- props cut some Drowned Harpooner lines onto the hero's side of room A, and
  the rock spires round the whirlpool cut some of Old Saltmaw's lure lines in
  room B, without sealing any route.
Run: python3 data/world/dungeons/saltmaw_grotto/build_rooms.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).parent
SIZE = 12

# Prop names are the art kit's board props (art manifest board.props,
# art/pc/dungeons/saltmaw_grotto/manifest.json), all 1x1 and blocking, from
# each room's list in the manifest (board.rooms.<a|b>.props).
KIT_PROPS = {
    "room_a": {"sunken_crate", "barrel", "coral_cluster", "anchor", "barnacle_rock"},
    "room_b": {"rock_spire", "giant_clam", "treasure_chest", "sunken_statue", "barrel", "sunken_crate", "barnacle_rock"},
}

# Room A, the sunken grotto. Rocks, crates and coral stand in short runs on
# the middle rows, so a Drowned Harpooner on the back rows must move to find
# a line on the hero; teal coral pads glow on the floor.
ROOM_A = {
    "hero": (8, 10),
    "props": {
        (5, 2): "barnacle_rock",
        (0, 2): "barrel",
        (11, 5): "coral_cluster",
        (2, 6): "sunken_crate", (3, 6): "barrel",
        (8, 6): "barnacle_rock", (9, 6): "coral_cluster",
        (5, 8): "anchor", (6, 8): "sunken_crate",
        (10, 9): "barnacle_rock",
        (1, 10): "coral_cluster",
    },
    "pads": {(6, 5): "coral_pad", (1, 8): "coral_pad", (10, 7): "coral_pad", (4, 10): "coral_pad", (7, 9): "coral_pad", (4, 4): "coral_pad"},
}

# Room B, Old Saltmaw's lair. The whirlpool is a 5x5 walkable floor decal
# on (4-8, 4-8) (origin (4, 4), bottom-centre on the south tip of (8, 8)): a
# stone kerb on its 16 border cells round the water on the inner 3x3, whose
# nine cells are the room's pads. Seven rock spires stand on kerb cells with
# gaps (the art mock's ring): a hero behind a spire is out of the lantern's
# line. The room shell (backdrop) paints the whale bones, the figureheads and
# the treasure heaps behind the walls.
WHIRLPOOL_ORIGIN = (4, 4)
WHIRLPOOL_SIZE = 5
SPIRES_FROM_ORIGIN = [(0, 1), (1, 0), (3, 0), (4, 2), (3, 4), (1, 4), (0, 3)]
ROOM_B = {
    "hero": (6, 10),
    "props": {
        **{(WHIRLPOOL_ORIGIN[0] + dx, WHIRLPOOL_ORIGIN[1] + dy): "rock_spire" for dx, dy in SPIRES_FROM_ORIGIN},
        (2, 1): "sunken_statue", (10, 1): "sunken_statue",
        (1, 4): "giant_clam", (10, 4): "treasure_chest",
        (2, 9): "barnacle_rock", (10, 9): "barrel",
        (1, 11): "sunken_crate", (11, 11): "barrel",
    },
    "pads": {(x, y): "whirlpool" for x in range(5, 8) for y in range(5, 8)},
    # Floor decal cells that are not pads (the kerb): they carry the decal's
    # name too, so each cell draws its piece of the 5x5 decal (under a spire too).
    "decal": {(WHIRLPOOL_ORIGIN[0] + dx, WHIRLPOOL_ORIGIN[1] + dy): "whirlpool" for dx in range(WHIRLPOOL_SIZE) for dy in range(WHIRLPOOL_SIZE)},
}

# Spawns per room (the run.json packs use these cells): every star's cells.
SPAWNS = {
    "room_a": [(3, 2), (8, 2), (5, 4), (11, 3), (1, 0), (6, 0), (10, 1), (4, 0)],
    "room_b": [(6, 2), (4, 2), (8, 2), (6, 4)],
}
# Where the room's ranged shooters (Harpooners; the boss's lure) stand.
SHOOTERS = {
    "room_a": [(1, 0), (6, 0), (10, 1)],
    "room_b": [(6, 2)],
}


def build(room: dict) -> dict:
    cells = []
    for y in range(SIZE):
        for x in range(SIZE):
            rec = {"x": x, "y": y, "terrain": "ground", "elevation": 0, "paint_only": []}
            prop = room["props"].get((x, y))
            decal = room.get("decal", {}).get((x, y))
            if prop:
                rec["paint_only"] = [prop]
                rec["blocks"] = True
                if decal:
                    rec["paint_only"].append(decal)
            elif decal:
                rec["paint_only"] = [decal]
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


def has_los(props: dict, a: tuple, b: tuple) -> bool:
    """CombatSim.has_los: the cells a straight line passes (ends excluded) are not props."""
    n = max(abs(b[0] - a[0]), abs(b[1] - a[1]))
    if n <= 1:
        return True
    steps = n * 4
    for i in range(1, steps):
        t = i / steps
        px = a[0] + (b[0] - a[0]) * t
        py = a[1] + (b[1] - a[1]) * t
        c = (_round(px), _round(py))
        if c in (a, b):
            continue
        if c in props:
            return False
    return True


def _round(v: float) -> int:
    # Godot roundi: half away from zero.
    return int(v + 0.5) if v >= 0 else -int(-v + 0.5)


def check(name: str, room: dict) -> None:
    props = room["props"]
    for c, kind in props.items():
        assert kind in KIT_PROPS[name], f"{name}: {kind} at {c} is not a {name} kit prop"
        assert 0 <= c[0] < SIZE and 0 <= c[1] < SIZE, f"{name}: prop {c} off the board"
    assert not set(props) & set(room["pads"]), f"{name}: a pad under a prop"
    for c in room["pads"]:
        if room.get("decal"):
            assert c in room["decal"], f"{name}: pad {c} off the decal"
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
    # Some lines from the shooters onto the hero's half are cut, none of the
    # shooters is sealed off from every cell of it.
    near = [c for c in walk if c[1] >= 7]
    cut = 0
    for s in SHOOTERS[name]:
        seen = [c for c in near if has_los(props, s, c)]
        assert seen, f"{name}: shooter {s} has no line onto the hero's half"
        cut += len(near) - len(seen)
    assert cut > 0, f"{name}: no line is cut"


def main() -> None:
    for name, room in (("room_a", ROOM_A), ("room_b", ROOM_B)):
        check(name, room)
        (ROOT / f"{name}_tags.json").write_text(json.dumps(build(room), indent=1) + "\n")


if __name__ == "__main__":
    main()
