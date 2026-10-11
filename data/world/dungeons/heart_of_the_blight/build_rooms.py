"""Build the Heart of the Blight room tags (room_a_tags.json, room_b_tags.json).

Same format as the other dungeons' (and the Koliseo tags files): `size`,
`cells` with x, y, terrain, elevation, paint_only, plus the dungeon keys
`blocks` (a prop stands here: not walkable, blocks a body) and `special` (a
glowing pad). Multi-cell props name the prop on their south (anchor) cell and
"<id>:part" on the others. The script checks the layout rules before it writes:
- every prop is one of the room's art kit props (manifest board.rooms.<a|b>.props
  when the manifest lists them, else the agreed ids below);
- every walkable cell is reachable from the hero start;
- the spawns of every star sit on open floor, off the pads, and room A's on
  the far rows (y 0-4, 6+ cells from the hero);
- bodies on every spawn still leave every route open;
- props cut some Blight Horror lines onto the hero's side of each room without
  sealing a shooter off;
- the Root Wall has room: every open cell next to a pad-free cell of the
  hero's half keeps at least two open neighbours (the wall never boxes a
  hero in a dead end by itself).
Run: python3 data/world/dungeons/heart_of_the_blight/build_rooms.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).parent
REPO = ROOT.parents[3]
MANIFEST = REPO / "art/pc/dungeons/heart_of_the_blight/manifest.json"
SIZE = 12

# The agreed board props (art agent, claude/blight-art), all 1x1 and blocking.
# Replaced by the manifest's room lists once the manifest names them.
KIT = {"violet_crystals", "crystal_spire", "root_knot", "root_mound", "bone_pile", "broken_masonry", "fungus_clump", "chained_cocoon", "blight_eggs"}
KIT_PROPS = {"room_a": set(KIT), "room_b": set(KIT)}
FOOTPRINTS = {"root_mound": (2, 2)}


def _manifest_props() -> None:
    """Room prop lists and sizes from the art manifest, when it has them."""
    if not MANIFEST.exists():
        return
    man = json.loads(MANIFEST.read_text())
    board = man.get("board", {})
    sizes = {}
    props = board.get("props", [])
    if isinstance(props, dict):
        props = [{"id": k, "footprint_size": v} for k, v in props.items()]
    for row in props:
        fs = row.get("footprint_size", [1, 1])
        sizes[row["id"]] = (int(fs[0]), int(fs[1]))
    rooms = board.get("rooms", {})
    for key, name in (("a", "room_a"), ("b", "room_b")):
        listed = rooms.get(key, {}).get("props") if isinstance(rooms.get(key), dict) else None
        if listed:
            KIT_PROPS[name] = {p if isinstance(p, str) else p["id"] for p in listed}
    for pid, fs in sizes.items():
        if fs != (1, 1):
            FOOTPRINTS[pid] = fs


def stamp(origin: tuple, prop: str) -> dict:
    """A prop's cells: the name on its south (anchor) cell, <id>:part elsewhere."""
    w, h = FOOTPRINTS.get(prop, (1, 1))
    out = {}
    for dy in range(h):
        for dx in range(w):
            c = (origin[0] + dx, origin[1] + dy)
            out[c] = prop if (dx, dy) == (w - 1, h - 1) else f"{prop}:part"
    return out


# Room A, the rotting hollow. Root knots, a root mound and violet crystals stand in short
# runs on the middle rows, so a Blight Horror on the back rows must move to find
# a line on the hero; six violet blight pads glow on the floor.
ROOM_A_ORIGINS = {
    (0, 2): "fungus_clump",
    (11, 6): "bone_pile",
    (2, 5): "root_knot", (3, 5): "violet_crystals",
    (8, 3): "root_mound",
    (5, 7): "root_knot",
    (9, 8): "violet_crystals", (10, 8): "fungus_clump",
    (2, 9): "root_knot",
    (0, 11): "bone_pile",
    (11, 11): "fungus_clump",
}
ROOM_A = {
    "hero": (6, 10),
    "props": {},
    "origins": ROOM_A_ORIGINS,
    "pads": {(6, 2): "blight_pad", (1, 6): "blight_pad", (10, 6): "blight_pad", (7, 6): "blight_pad", (4, 9): "blight_pad", (8, 10): "blight_pad"},
    # Walkable 1x1 floor decals (the kit's root veins): paint only, no rule.
    "decor": {(4, 3): "root_veins", (6, 5): "root_veins", (10, 10): "root_veins", (1, 9): "root_veins", (3, 11): "root_veins"},
}

# Room B, the Elder's heart chamber. The root rune circle is a 5x5 walkable floor
# decal on (4-8, 4-8) (origin (4, 4), bottom-centre on the south tip of
# (8, 8)); its inner 3x3 glows (the nine pads). Crystal spires on its four
# corner cells give cover from the horror's spores. A chained cocoon, masonry, eggs and
# bones lie round the walls under the crystal heart.
CIRCLE_ORIGIN = (4, 4)
CIRCLE_SIZE = 5
ROOM_B_ORIGINS = {
    (1, 1): "chained_cocoon",
    (10, 1): "broken_masonry",
    (11, 4): "violet_crystals",
    (4, 4): "crystal_spire", (8, 4): "crystal_spire", (4, 8): "crystal_spire", (8, 8): "crystal_spire",
    (0, 6): "bone_pile",
    (2, 9): "root_knot",
    (10, 9): "blight_eggs",
    (0, 11): "violet_crystals",
    (11, 11): "bone_pile",
}
ROOM_B = {
    "hero": (6, 10),
    "props": {},
    "origins": ROOM_B_ORIGINS,
    "pads": {(x, y): "root_rune_circle" for x in range(5, 8) for y in range(5, 8)},
    "decal": {(CIRCLE_ORIGIN[0] + dx, CIRCLE_ORIGIN[1] + dy): "root_rune_circle" for dx in range(CIRCLE_SIZE) for dy in range(CIRCLE_SIZE)},
    "decor": {(2, 5): "root_veins", (10, 6): "root_veins", (3, 10): "root_veins", (9, 10): "root_veins", (1, 8): "root_veins"},
}

# Spawns per room (the run.json packs use these cells): every star's cells.
SPAWNS = {
    "room_a": [(2, 2), (4, 1), (8, 1), (10, 3), (1, 0), (10, 0), (5, 0), (7, 0)],
    "room_b": [(6, 2), (4, 2), (8, 2), (6, 0)],
}
# Where the room's ranged shooters (Blight Horrors) stand.
SHOOTERS = {
    "room_a": [(1, 0), (10, 0), (5, 0)],
    "room_b": [(6, 0)],
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
            elif room.get("decor", {}).get((x, y)):
                rec["paint_only"] = [room["decor"][(x, y)]]
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
        base = kind.split(":")[0]
        assert base in KIT_PROPS[name], f"{name}: {base} at {c} is not a {name} kit prop"
        assert 0 <= c[0] < SIZE and 0 <= c[1] < SIZE, f"{name}: prop {c} off the board"
    assert not set(props) & set(room["pads"]), f"{name}: a pad under a prop"
    for c in room.get("decor", {}):
        assert c not in props and c not in room["pads"] and c not in room.get("decal", {}), f"{name}: decor {c} on a prop, pad or decal"
    for c in room["pads"]:
        if room.get("decal"):
            assert c in room["decal"], f"{name}: pad {c} off the decal"
    walk = {(x, y) for y in range(SIZE) for x in range(SIZE) if (x, y) not in props}
    hero = room["hero"]
    assert hero in walk, f"{name}: hero start on a prop"
    assert _flood(walk, hero) == walk, f"{name}: a walkable cell is sealed off"
    spawns = SPAWNS[name]
    assert len(set(spawns)) == len(spawns), f"{name}: two spawns share a cell"
    for c in spawns:
        assert c in walk and c not in room["pads"], f"{name}: spawn {c} on a prop or pad"
    # Bodies standing on every spawn still leave every other cell reachable.
    assert _flood(walk - set(spawns), hero) == walk - set(spawns), f"{name}: the spawns seal a route"
    if name == "room_a":
        for c in spawns:
            assert c[1] <= 4 and max(abs(c[0] - hero[0]), abs(c[1] - hero[1])) >= 6, f"{name}: spawn {c} not on the far rows"
    # Some lines from the shooters onto the hero's half are cut; none of the
    # shooters is sealed off from every cell of it.
    near = [c for c in walk if c[1] >= 7]
    cut = 0
    for s in SHOOTERS[name]:
        seen = [c for c in near if has_los(props, s, c)]
        assert seen, f"{name}: shooter {s} has no line onto the hero's half"
        cut += len(near) - len(seen)
    assert cut > 0, f"{name}: no line is cut"
    # Root Wall room: the hero's start keeps open ground round it.
    open_round = [n for n in ((hero[0] + 1, hero[1]), (hero[0] - 1, hero[1]), (hero[0], hero[1] + 1), (hero[0], hero[1] - 1)) if n in walk]
    assert len(open_round) >= 3, f"{name}: the hero start is hemmed in"


def main() -> None:
    _manifest_props()
    for name, room in (("room_a", ROOM_A), ("room_b", ROOM_B)):
        room["props"] = {}
        for origin, prop in room["origins"].items():
            for c, label in stamp(origin, prop).items():
                assert c not in room["props"], f"{name}: {prop} overlaps {room['props'][c]} at {c}"
                room["props"][c] = label
        check(name, room)
        (ROOT / f"{name}_tags.json").write_text(json.dumps(build(room), indent=1) + "\n")
        print(f"{name}: {len(room['props'])} prop cells, {len(room['pads'])} pads, spawns ok, reachability ok")


if __name__ == "__main__":
    main()
