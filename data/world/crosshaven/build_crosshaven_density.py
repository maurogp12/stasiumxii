#!/usr/bin/env python3
"""Cluster each Crosshaven town around a flagstone square.

Run after build_crosshaven_dressing.py. Re-running the zone builder wipes
both passes. This script only edits the five towns and the crossroads, and
only with prop and tile ids already in the catalog.

Interior dirt_road within chebyshev 7 of a point of interest is drawn as
flagstone by crosshaven_art.gd pick_tile. A plaza is that dirt_road rect.
The crossroads spawn stays (22, 18). Other town spawns move onto the square.
New blockers stay off the original through-road, off exit mouths, and off
the 3x3 around the spawn. Every passable cell must stay reachable.
"""

from __future__ import annotations

import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ZONE_DIR = ROOT / "data" / "world" / "crosshaven" / "zones"

SQ = [(0, 0), (1, 0), (0, 1), (1, 1)]
STALL = [(0, 0), (1, 0)]
ONE = [(0, 0)]
DIRS = ((1, 0), (-1, 0), (0, 1), (0, -1))
CLUTTER = {
    "tree", "hedgerow_nesw", "hedgerow_nwse", "fence",
    "farm_fence_nesw", "farm_fence_nwse",
}
# Same set the world scene uses when it decides a sprite hangs over a cell.
SHADE = {
    "red_roof_cottage",
    "northgate_spire", "stoneford_spire", "eastmarch_spire",
    "westwatch_spire", "southbridge_spire", "crossroads_centerpiece",
    "barn_2x2", "farmhouse_2x2", "windmill_2x2_body", "bakery_2x2", "smithy_2x2",
    "tavern_3x2", "fountain_2x2", "watermill_2x2_body", "watchtower_2x2",
    "fishing_hut_2x2", "wall_tower", "market_stall",
}
BUILDINGS = SHADE - {"market_stall", "wall_tower", "fountain_2x2"}
DOOR_TYPES = {
    "red_roof_cottage", "barn_2x2", "farmhouse_2x2", "bakery_2x2", "smithy_2x2",
    "fishing_hut_2x2", "watermill_2x2_body", "watchtower_2x2",
    "northgate_spire", "stoneford_spire", "eastmarch_spire", "westwatch_spire", "southbridge_spire",
}
SHEDS = {"barn_2x2", "farmhouse_2x2"}
FLOWERS = ["flowers_a", "flowers_b", "flowers_c", "flowers_d", "decal_flowers_pink", "decal_flowers_yellow"]
TOWNS = [
    "crosshaven_crossroads",
    "crosshaven_northgate",
    "crosshaven_stoneford",
    "crosshaven_eastmarch",
    "crosshaven_westwatch",
    "crosshaven_southbridge",
]

# Plaza rects sit inside chebyshev 7 of the spawn so the open square is flagstone.
# Cottages are 2x2. Life props sit off the original road and off the spawn's 3x3.
LAYOUTS = {
    "crosshaven_crossroads": {
        "spawn": (22, 18),
        "lock_spawn": True,
        "plaza": (15, 12, 29, 24),
        "move": {"fountain_2x2": (24, 22)},
        "cottages": [(8, 13), (12, 13), (15, 13), (27, 13), (31, 13), (12, 21), (15, 21), (27, 21)],
        "extra": [
            ("barn_2x2", (6, 32)),
            ("market_stall", (24, 14)),
            ("lamp_post", (14, 15)),
            ("lamp_post", (30, 15)),
            ("lamp_post", (14, 22)),
            ("lamp_post", (29, 22)),
            ("barrel", (11, 15)),
            ("barrel", (30, 14)),
            ("crate_apples", (11, 23)),
            ("crate_apples", (29, 23)),
            ("cart", (6, 24)),
            ("hay_bale", (7, 34)),
        ],
        "farms": [("farm_cabbage", 4, 8, 4, 3), ("farm_carrot", 32, 8, 3, 3)],
        "hedges": [(2, 12), (3, 12), (5, 12), (36, 12), (37, 12), (2, 28), (4, 28), (36, 28), (38, 28)],
    },
    "crosshaven_northgate": {
        "spawn": (20, 12),
        "lock_spawn": False,
        "plaza": (14, 8, 26, 17),
        "move": {
            "northgate_spire": (12, 8),
            "bakery_2x2": (24, 8),
            "wall_tower": (16, 4),
            "stone_wall_high_nwse": (15, 4),
            "stone_wall_high_nesw": (17, 4),
            "brazier": (16, 5),
        },
        "cottages": [(8, 8), (8, 14), (12, 14), (24, 14), (28, 8), (28, 14), (8, 20), (28, 20)],
        "extra": [
            ("farmhouse_2x2", (32, 22)),
            ("market_stall", (14, 11)),
            ("well", (26, 12)),
            ("lamp_post", (14, 16)),
            ("lamp_post", (26, 16)),
            ("lamp_post", (10, 11)),
            ("lamp_post", (27, 11)),
            ("barrel", (11, 10)),
            ("barrel", (29, 10)),
            ("crate_apples", (11, 16)),
            ("crate_apples", (29, 16)),
            ("cart", (14, 20)),
            ("signpost_crossroads", (26, 11)),
            ("hay_bale", (33, 24)),
        ],
        "farms": [("farm_pumpkin", 4, 24, 4, 3)],
        "hedges": [(2, 16), (3, 16), (5, 16), (36, 16), (37, 16), (2, 26), (4, 26), (36, 26), (38, 26)],
    },
    "crosshaven_stoneford": {
        "spawn": (16, 16),
        "lock_spawn": False,
        "plaza": (10, 12, 22, 20),
        "move": {},
        "cottages": [(10, 10), (13, 10), (29, 10), (32, 10), (10, 20), (13, 20), (28, 20), (32, 20)],
        "extra": [
            ("barn_2x2", (22, 24)),
            ("market_stall", (11, 19)),
            ("well", (20, 12)),
            ("lamp_post", (10, 19)),
            ("lamp_post", (21, 19)),
            ("lamp_post", (30, 13)),
            ("lamp_post", (33, 13)),
            ("barrel", (12, 12)),
            ("barrel", (31, 12)),
            ("crate_apples", (12, 22)),
            ("crate_apples", (30, 22)),
            ("cart", (20, 22)),
            ("signpost_crossroads", (20, 20)),
            ("hay_bale", (23, 26)),
        ],
        "farms": [("farm_lavender", 14, 24, 4, 3)],
        "hedges": [(10, 28), (12, 28), (14, 28), (24, 28), (26, 28), (10, 6), (12, 6), (30, 6), (32, 6)],
    },
    "crosshaven_eastmarch": {
        "spawn": (16, 16),
        "lock_spawn": False,
        "plaza": (10, 12, 24, 20),
        "move": {},
        "cottages": [(8, 10), (12, 10), (26, 10), (30, 10), (8, 20), (12, 20), (26, 20), (30, 20)],
        "extra": [
            ("barn_2x2", (4, 24)),
            ("market_stall", (10, 19)),
            ("well", (22, 12)),
            ("lamp_post", (10, 13)),
            ("lamp_post", (23, 13)),
            ("lamp_post", (9, 21)),
            ("lamp_post", (24, 21)),
            ("barrel", (11, 12)),
            ("barrel", (29, 12)),
            ("crate_apples", (11, 22)),
            ("crate_apples", (29, 22)),
            ("cart", (18, 22)),
            ("signpost_crossroads", (14, 12)),
            ("hay_bale", (5, 26)),
        ],
        "farms": [("farm_sunflower", 14, 24, 4, 3)],
        "hedges": [(4, 28), (6, 28), (8, 28), (22, 28), (24, 28), (4, 4), (6, 4), (28, 4), (30, 4)],
    },
    "crosshaven_westwatch": {
        "spawn": (16, 10),
        "lock_spawn": False,
        "plaza": (10, 6, 22, 16),
        "move": {"watchtower_2x2": (30, 11)},
        "cottages": [(4, 6), (8, 6), (4, 16), (8, 16), (20, 6), (28, 8), (20, 18), (28, 16)],
        "extra": [
            ("market_stall", (10, 14)),
            ("well", (12, 8)),
            ("lamp_post", (11, 8)),
            ("lamp_post", (21, 8)),
            ("lamp_post", (11, 15)),
            ("lamp_post", (30, 12)),
            ("barrel", (6, 8)),
            ("barrel", (22, 8)),
            ("crate_apples", (6, 18)),
            ("crate_apples", (22, 20)),
            ("cart", (30, 20)),
            ("signpost_crossroads", (12, 14)),
            ("hay_bale", (6, 22)),
        ],
        "farms": [("farm_plowed", 4, 22, 4, 3)],
        "hedges": [(6, 26), (8, 26), (10, 26), (20, 26), (22, 26), (30, 4), (32, 4), (30, 24), (32, 24)],
    },
    "crosshaven_southbridge": {
        "spawn": (20, 10),
        "lock_spawn": False,
        "plaza": (14, 6, 26, 16),
        "move": {
            "watermill_2x2_body": (13, 21),
            "hay_bale": (15, 23),
        },
        "cottages": [(6, 6), (10, 6), (6, 14), (10, 14), (24, 6), (28, 6), (24, 14), (28, 14)],
        "extra": [
            ("farmhouse_2x2", (30, 20)),
            ("market_stall", (14, 14)),
            ("well", (26, 10)),
            ("lamp_post", (15, 8)),
            ("lamp_post", (25, 8)),
            ("lamp_post", (15, 15)),
            ("lamp_post", (25, 15)),
            ("barrel", (8, 8)),
            ("barrel", (29, 8)),
            ("crate_apples", (8, 16)),
            ("crate_apples", (29, 16)),
            ("cart", (16, 18)),
            ("signpost_crossroads", (26, 12)),
        ],
        "farms": [("farm_fallow", 32, 22, 4, 3)],
        "hedges": [(2, 18), (4, 18), (34, 18), (36, 18), (2, 26), (4, 26), (34, 26), (36, 26)],
    },
}


def footprint(prop_type: str, origin: tuple[int, int]) -> list[tuple[int, int]]:
    shape = SQ if prop_type in {
        "red_roof_cottage", "barn_2x2", "farmhouse_2x2", "bakery_2x2", "smithy_2x2",
        "fishing_hut_2x2", "watchtower_2x2", "watermill_2x2_body", "fountain_2x2",
        "northgate_spire", "stoneford_spire", "eastmarch_spire", "westwatch_spire",
        "southbridge_spire", "crossroads_centerpiece",
    } else STALL if prop_type == "market_stall" else ONE
    return [(origin[0] + dx, origin[1] + dy) for dx, dy in shape]


def load_zones() -> dict[str, dict]:
    out = {}
    for path in sorted(ZONE_DIR.glob("*.json")):
        out[path.stem] = json.loads(path.read_text())
    return out


def index_terrain(doc: dict) -> dict[tuple[int, int], dict]:
    return {(tile["x"], tile["y"]): tile for tile in doc["tiles"]}


def artery_of(doc: dict) -> set[tuple[int, int]]:
    """The through-road bands: each exit's width, extended across the chunk.

    A plaza painted on a previous run is also dirt_road, so the artery cannot
    be "every dirt cell". Houses may sit on the square. They may not sit on
    these bands, and neither may carts or stalls.
    """
    bands: set[tuple[int, int]] = set()
    width, height = doc["width"], doc["height"]
    for exit_rec in doc["exits"]:
        xs = [link["from"]["x"] for link in exit_rec["links"]]
        ys = [link["from"]["y"] for link in exit_rec["links"]]
        if exit_rec["edge"] in ("north", "south"):
            for y in range(height):
                for x in range(min(xs), max(xs) + 1):
                    bands.add((x, y))
        else:
            for x in range(width):
                for y in range(min(ys), max(ys) + 1):
                    bands.add((x, y))
    return bands


def reserved_of(doc: dict, spawn: tuple[int, int]) -> set[tuple[int, int]]:
    reserved = {spawn}
    for poi in doc["points_of_interest"]:
        reserved.add((poi["x"], poi["y"]))
    inward = {"north": (0, 1), "south": (0, -1), "east": (-1, 0), "west": (1, 0)}
    for exit_rec in doc["exits"]:
        step = inward[exit_rec["edge"]]
        for link in exit_rec["links"]:
            frm = (link["from"]["x"], link["from"]["y"])
            reserved.add(frm)
            reserved.add((frm[0] + step[0], frm[1] + step[1]))
    return reserved


def prop_cells(prop: dict) -> list[tuple[int, int]]:
    return [(cell["x"], cell["y"]) for cell in prop["footprint"]]


def blocked_map(doc: dict) -> dict[tuple[int, int], dict]:
    out = {}
    for prop in doc["props"]:
        if prop.get("blocks", True):
            for cell in prop_cells(prop):
                out[cell] = prop
    return out


def reachable(start: tuple[int, int], walk: set[tuple[int, int]], blocked: set[tuple[int, int]]) -> set[tuple[int, int]]:
    if start in blocked or start not in walk:
        return set()
    seen = {start}
    queue = deque([start])
    while queue:
        x, y = queue.popleft()
        for dx, dy in DIRS:
            nxt = (x + dx, y + dy)
            if nxt in seen or nxt not in walk or nxt in blocked:
                continue
            seen.add(nxt)
            queue.append(nxt)
    return seen


def walkable_cells(doc: dict) -> set[tuple[int, int]]:
    return {(tile["x"], tile["y"]) for tile in doc["tiles"] if tile["walkable"]}


def paint(tile: dict, terrain: str) -> None:
    tile["terrain"] = terrain
    tile["walkable"] = True


def door_cells(origin: tuple[int, int], cells: list[tuple[int, int]]) -> list[tuple[int, int]]:
    max_y = max(c[1] for c in cells)
    xs = sorted({c[0] for c in cells if c[1] == max_y})
    return [(x, max_y + 1) for x in xs]


def under_roof(props: list[dict], spot: tuple[int, int]) -> bool:
    for prop in props:
        kind = prop["type"]
        if kind not in SHADE:
            continue
        cells = prop_cells(prop)
        if not cells:
            continue
        min_x = min(c[0] for c in cells)
        max_x = max(c[0] for c in cells)
        min_y = min(c[1] for c in cells)
        max_y = max(c[1] for c in cells)
        if spot[0] < min_x - 1 or spot[0] > max_x + 1:
            continue
        if spot[1] > max_y + 1:
            continue
        reach = 6 if kind.endswith("spire") or kind == "crossroads_centerpiece" else 3
        if spot[1] < min_y - reach:
            continue
        return True
    return False


def gap_to(spot: tuple[int, int], blocked: set[tuple[int, int]]) -> int:
    best = 99
    for other in blocked:
        best = min(best, max(abs(other[0] - spot[0]), abs(other[1] - spot[1])))
    return best


def add_prop(doc: dict, prop_type: str, origin: tuple[int, int], serial: int) -> dict:
    cells = footprint(prop_type, origin)
    prop = {
        "id": f"{doc['zone_id']}_density_{prop_type}_{serial:02d}",
        "type": prop_type,
        "blocks": True,
        "origin": {"x": origin[0], "y": origin[1]},
        "footprint": [{"x": c[0], "y": c[1]} for c in cells],
    }
    doc["props"].append(prop)
    return prop


def move_prop(doc: dict, prop_type: str, origin: tuple[int, int]) -> dict:
    matches = [
        prop for prop in doc["props"]
        if prop["type"] == prop_type and "_scatter_" not in prop["id"] and "_density_" not in prop["id"]
    ]
    if len(matches) != 1:
        raise SystemExit(f"{doc['zone_id']} expected one {prop_type} to move, found {len(matches)}")
    prop = matches[0]
    cells = footprint(prop_type, origin)
    prop["origin"] = {"x": origin[0], "y": origin[1]}
    prop["footprint"] = [{"x": c[0], "y": c[1]} for c in cells]
    return prop


def strip_density(doc: dict) -> None:
    doc["props"] = [prop for prop in doc["props"] if "_density_" not in str(prop.get("id", ""))]
    doc["decor"] = [rec for rec in doc.get("decor", []) if "_density_" not in str(rec.get("id", ""))]


def clear_clutter(doc: dict, doomed: set[tuple[int, int]]) -> int:
    kept = []
    removed = 0
    for prop in doc["props"]:
        cells = prop_cells(prop)
        if prop["type"] in CLUTTER and any(cell in doomed for cell in cells):
            removed += 1
            continue
        kept.append(prop)
    doc["props"] = kept
    return removed


def placeable(doc: dict, tiles, blocked, artery, reserved, cells, allow_artery: bool = False) -> str:
    w, h = doc["width"], doc["height"]
    for cell in cells:
        if cell[0] < 0 or cell[1] < 0 or cell[0] >= w or cell[1] >= h:
            return "out of bounds"
        tile = tiles.get(cell)
        if tile is None:
            return "missing tile"
        if tile["terrain"] in ("water", "cliff") or not tile["walkable"]:
            return f"unwalkable {tile['terrain']}"
        if cell in blocked:
            return "occupied"
        if cell in reserved:
            return "reserved"
        if cell in artery and not allow_artery:
            return "on the through-road"
    return ""


def keeps_reach(walk: set[tuple[int, int]], blocked: set[tuple[int, int]], spawn: tuple[int, int], cells: list[tuple[int, int]]) -> bool:
    before = {cell for cell in walk if cell not in blocked}
    trial = set(blocked)
    trial.update(cells)
    need = before - set(cells)
    return need <= reachable(spawn, walk, trial)


def nearby(origin: tuple[int, int]):
    yield origin
    for radius in range(1, 4):
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                if max(abs(dx), abs(dy)) != radius:
                    continue
                yield (origin[0] + dx, origin[1] + dy)


def paint_lane(tiles, blocked, artery, origin_cells: list[tuple[int, int]]) -> str:
    doors = door_cells((0, 0), origin_cells)
    for door in doors:
        tile = tiles.get(door)
        if tile is None or tile["terrain"] in ("water", "cliff") or not tile["walkable"]:
            return f"door {door} has no ground"
        if door in blocked:
            return f"door {door} is blocked"
    if any(tiles[door]["terrain"] == "dirt_road" for door in doors):
        for door in doors:
            if tiles[door]["terrain"] != "dirt_road" and tiles[door]["terrain"] not in ("water", "cliff"):
                paint(tiles[door], "dirt_road")
        return ""
    start = doors[0]
    came: dict[tuple[int, int], tuple[int, int] | None] = {start: None}
    queue = deque([start])
    found = None
    while queue:
        cur = queue.popleft()
        if tiles[cur]["terrain"] == "dirt_road" and cur not in doors:
            found = cur
            break
        if len(came) > 1600:
            break
        for dx, dy in DIRS:
            nxt = (cur[0] + dx, cur[1] + dy)
            if nxt in came or nxt in blocked or nxt not in tiles:
                continue
            kind = tiles[nxt]["terrain"]
            if kind in ("water", "cliff") or not tiles[nxt]["walkable"]:
                continue
            if kind not in ("golden_plains", "dirt_road") and not kind.startswith("farm_"):
                continue
            came[nxt] = cur
            queue.append(nxt)
    if found is None:
        return f"no lane from {doors}"
    cur = found
    while cur is not None:
        if tiles[cur]["terrain"] != "dirt_road":
            paint(tiles[cur], "dirt_road")
        cur = came[cur]
    for door in doors:
        paint(tiles[door], "dirt_road")
    return ""


def connect_dirt(tiles, blocked, start: tuple[int, int], artery: set[tuple[int, int]]) -> bool:
    if start in blocked or start not in tiles:
        return False
    seen = {start}
    queue = deque([start])
    while queue:
        cur = queue.popleft()
        if cur in artery and tiles[cur]["terrain"] == "dirt_road":
            return True
        for dx, dy in DIRS:
            nxt = (cur[0] + dx, cur[1] + dy)
            if nxt in seen or nxt in blocked or nxt not in tiles:
                continue
            if tiles[nxt]["terrain"] != "dirt_road":
                continue
            seen.add(nxt)
            queue.append(nxt)
    return False


def paint_farm(tiles, blocked, reserved, artery, terrain: str, x: int, y: int, w: int, h: int) -> int:
    painted = 0
    for dy in range(h):
        for dx in range(w):
            cell = (x + dx, y + dy)
            tile = tiles.get(cell)
            if tile is None:
                continue
            if tile["terrain"] not in ("golden_plains", terrain):
                continue
            if cell in blocked or cell in reserved or cell in artery:
                continue
            paint(tile, terrain)
            painted += 1
    return painted


def apply_town(doc: dict, layout: dict) -> list[str]:
    errors = []
    strip_density(doc)
    tiles = index_terrain(doc)
    artery = artery_of(doc)
    spawn = layout["spawn"]
    if layout["lock_spawn"] and (doc["spawn"]["x"], doc["spawn"]["y"]) != spawn:
        errors.append(f"refusing to move locked spawn {doc['spawn']}")
        return errors
    reserved = reserved_of(doc, spawn)
    # Exit mouths stay reserved even if the old spawn moves off them.
    reserved |= reserved_of(doc, (doc["spawn"]["x"], doc["spawn"]["y"]))
    reserved.add(spawn)

    for prop_type, origin in layout["move"].items():
        move_prop(doc, prop_type, origin)

    doc["props"] = [prop for prop in doc["props"] if prop["type"] != "red_roof_cottage"]

    doomed = set()
    x0, y0, x1, y1 = layout["plaza"]
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            doomed.add((x, y))
    planned: list[tuple[str, tuple[int, int]]] = [("red_roof_cottage", origin) for origin in layout["cottages"]]
    planned += list(layout["extra"])
    for prop_type, origin in planned:
        cells = footprint(prop_type, origin)
        doomed.update(cells)
        if prop_type in BUILDINGS or prop_type == "market_stall":
            doomed.update(door_cells((0, 0), cells))
    for prop_type, origin in layout["move"].items():
        cells = footprint(prop_type, origin)
        doomed.update(cells)
        if prop_type in BUILDINGS:
            doomed.update(door_cells((0, 0), cells))
    for terrain, x, y, w, h in layout["farms"]:
        for dy in range(h):
            for dx in range(w):
                doomed.add((x + dx, y + dy))
    clear_clutter(doc, doomed)

    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            tile = tiles.get((x, y))
            if tile is None:
                continue
            if tile["terrain"] in ("water", "cliff"):
                continue
            if tile["terrain"] == "golden_plains" or tile["terrain"].startswith("farm_") or tile["terrain"] == "dirt_road":
                paint(tile, "dirt_road")

    blocked = blocked_map(doc)
    walk = {cell for cell, tile in tiles.items() if tile["walkable"]}
    serial = 1
    buildings = [(prop_type, origin) for prop_type, origin in planned if prop_type == "red_roof_cottage" or prop_type in SHEDS]
    life = [(prop_type, origin) for prop_type, origin in planned if prop_type != "red_roof_cottage" and prop_type not in SHEDS]
    for prop_type, origin in buildings:
        cells = footprint(prop_type, origin)
        reason = placeable(doc, tiles, blocked, artery, reserved, cells)
        if reason:
            errors.append(f"{prop_type} at {origin} {reason}")
            continue
        if not keeps_reach(walk, set(blocked), spawn, cells):
            errors.append(f"{prop_type} at {origin} would split the walk")
            continue
        prop = add_prop(doc, prop_type, origin, serial)
        serial += 1
        for cell in cells:
            blocked[cell] = prop

    for prop in doc["props"]:
        if prop["type"] not in DOOR_TYPES:
            continue
        reason = paint_lane(tiles, set(blocked), artery, prop_cells(prop))
        if reason:
            errors.append(f"{prop['type']} {prop['origin']} {reason}")

    # A tree left on a new lane still blocks the doorstep. Clear clutter off fresh dirt.
    lane_block = []
    for cell, prop in list(blocked.items()):
        tile = tiles.get(cell)
        if tile and tile["terrain"] == "dirt_road" and prop["type"] in CLUTTER and cell not in artery:
            lane_block.append(prop["id"])
    if lane_block:
        gone = set(lane_block)
        doc["props"] = [prop for prop in doc["props"] if prop["id"] not in gone]
        blocked = blocked_map(doc)

    door_spots: set[tuple[int, int]] = set()
    for prop in doc["props"]:
        if prop["type"] in DOOR_TYPES:
            door_spots.update(door_cells((0, 0), prop_cells(prop)))
    must_life = {"market_stall", "well", "signpost_crossroads"}
    for prop_type, origin in life:
        placed_at = None
        for spot in nearby(origin):
            cells = footprint(prop_type, spot)
            if any(max(abs(cell[0] - spawn[0]), abs(cell[1] - spawn[1])) < 2 for cell in cells):
                continue
            if any(cell in door_spots for cell in cells):
                continue
            reason = placeable(doc, tiles, blocked, artery, reserved, cells)
            if reason:
                continue
            if not keeps_reach(walk, set(blocked), spawn, cells):
                continue
            trial = [prop for prop in doc["props"]]
            ghost = {"type": prop_type, "footprint": [{"x": c[0], "y": c[1]} for c in cells]}
            if under_roof(trial + [ghost], spawn):
                continue
            if gap_to(spawn, set(blocked) | set(cells)) < 2:
                continue
            prop = add_prop(doc, prop_type, spot, serial)
            serial += 1
            for cell in cells:
                blocked[cell] = prop
            placed_at = spot
            break
        if placed_at is None and prop_type in must_life:
            errors.append(f"could not place {prop_type} near {origin}")

    def try_blocker(prop_type: str, cell: tuple[int, int]) -> None:
        nonlocal serial
        reason = placeable(doc, tiles, blocked, artery, reserved, [cell])
        if reason or cell in door_spots:
            return
        if max(abs(cell[0] - spawn[0]), abs(cell[1] - spawn[1])) < 2:
            return
        if not keeps_reach(walk, set(blocked), spawn, [cell]):
            return
        prop = add_prop(doc, prop_type, cell, serial)
        serial += 1
        blocked[cell] = prop

    for terrain, x, y, w, h in layout["farms"]:
        painted = paint_farm(tiles, set(blocked), reserved, artery, terrain, x, y, w, h)
        if painted < 8:
            errors.append(f"{terrain} painted only {painted} cells")
        # A broken fence line on the north and west, with gaps so the plot stays open.
        for i, dx in enumerate(range(w)):
            if i % 3 == 2:
                continue
            try_blocker("farm_fence_nwse", (x + dx, y - 1))
        for i, dy in enumerate(range(h)):
            if i % 3 == 2:
                continue
            try_blocker("farm_fence_nesw", (x - 1, y + dy))
    # The dressing pass left crop plots in the middle of town. Keep only the edge rects.
    keep_farm: set[tuple[int, int]] = set()
    for terrain, x, y, w, h in layout["farms"]:
        for dy in range(h):
            for dx in range(w):
                keep_farm.add((x + dx, y + dy))
    for cell, tile in tiles.items():
        if str(tile["terrain"]).startswith("farm_") and cell not in keep_farm:
            paint(tile, "golden_plains")

    for hx, hy in layout["hedges"]:
        kind = "hedgerow_nwse" if hy % 2 == 0 else "hedgerow_nesw"
        try_blocker(kind, (hx, hy))

    # Flower beds on a free cell beside each cottage door.
    decor = list(doc.get("decor", []))
    decor_serial = 1
    seen_decor = {rec["id"] for rec in decor}
    cottages = [prop for prop in doc["props"] if prop["type"] == "red_roof_cottage"]
    for index, prop in enumerate(cottages):
        cells = prop_cells(prop)
        ox = min(c[0] for c in cells)
        oy = min(c[1] for c in cells)
        candidates = [(ox - 1, oy + 1), (ox + 2, oy + 1), (ox, oy + 2), (ox + 1, oy - 1)]
        planted = 0
        for cell in candidates:
            tile = tiles.get(cell)
            if tile is None or cell in blocked or not tile["walkable"]:
                continue
            if tile["terrain"] in ("water", "cliff"):
                continue
            decor_id = f"{doc['zone_id']}_density_flowers_{decor_serial:02d}"
            decor_serial += 1
            if decor_id in seen_decor:
                continue
            decor.append({
                "id": decor_id,
                "type": FLOWERS[index % len(FLOWERS)],
                "x": cell[0],
                "y": cell[1],
            })
            planted += 1
            if planted >= 2:
                break
    # Drop decor that now sits inside a blocker so flowers do not grow indoors.
    decor = [rec for rec in decor if (rec["x"], rec["y"]) not in blocked]
    doc["decor"] = decor

    doc["spawn"] = {"x": spawn[0], "y": spawn[1]}
    for poi in doc["points_of_interest"]:
        if poi["kind"] in ("town", "crossroads"):
            poi["x"], poi["y"] = spawn

    return errors


def validate(zones: dict[str, dict]) -> list[str]:
    errors = []
    # Global walk from the crossroads stand, matching the zone test.
    walk = {}
    blocked = {}
    for zone_id, doc in zones.items():
        tiles = index_terrain(doc)
        walk[zone_id] = {cell for cell, tile in tiles.items() if tile["walkable"]}
        blocked[zone_id] = set(blocked_map(doc))
    start_zone = "crosshaven_crossroads"
    start = (zones[start_zone]["spawn"]["x"], zones[start_zone]["spawn"]["y"])
    if start != (22, 18):
        errors.append(f"crossroads spawn is {start}")
    seen = {(start_zone, start)}
    queue = deque([(start_zone, start)])
    while queue:
        zone_id, cell = queue.popleft()
        doc = zones[zone_id]
        for dx, dy in DIRS:
            nxt = (cell[0] + dx, cell[1] + dy)
            key = (zone_id, nxt)
            if key in seen or nxt not in walk[zone_id] or nxt in blocked[zone_id]:
                continue
            seen.add(key)
            queue.append((zone_id, nxt))
        for exit_rec in doc["exits"]:
            for link in exit_rec["links"]:
                frm = (link["from"]["x"], link["from"]["y"])
                if frm != cell:
                    continue
                dest_zone = exit_rec["target_zone"]
                dest = (link["to"]["x"], link["to"]["y"])
                key = (dest_zone, dest)
                if key in seen:
                    continue
                if dest not in walk.get(dest_zone, set()) or dest in blocked.get(dest_zone, set()):
                    errors.append(f"exit {zone_id} {frm} lands on blocked {dest_zone} {dest}")
                    continue
                seen.add(key)
                queue.append((dest_zone, dest))
    for zone_id, doc in zones.items():
        for cell in walk[zone_id]:
            if cell in blocked[zone_id]:
                continue
            if (zone_id, cell) not in seen:
                errors.append(f"unreachable {zone_id} {cell}")
                if len(errors) > 12:
                    return errors
    for zone_id in TOWNS:
        doc = zones[zone_id]
        tiles = index_terrain(doc)
        spawn = (doc["spawn"]["x"], doc["spawn"]["y"])
        blocked_cells = blocked[zone_id]
        if spawn in blocked_cells or not tiles[spawn]["walkable"]:
            errors.append(f"{zone_id} spawn {spawn} is not open")
        if tiles[spawn]["terrain"] != "dirt_road":
            errors.append(f"{zone_id} spawn {spawn} is not on the square")
        if gap_to(spawn, blocked_cells) < 2:
            errors.append(f"{zone_id} spawn {spawn} gap {gap_to(spawn, blocked_cells)}")
        if under_roof(doc["props"], spawn):
            errors.append(f"{zone_id} spawn {spawn} is under a roof")
        cottages = [prop for prop in doc["props"] if prop["type"] == "red_roof_cottage"]
        if not 6 <= len(cottages) <= 10:
            errors.append(f"{zone_id} has {len(cottages)} cottages")
        for prop in doc["props"]:
            if prop["type"] not in DOOR_TYPES:
                continue
            cells = prop_cells(prop)
            doors = door_cells((0, 0), cells)
            if not any(connect_dirt(tiles, blocked_cells, door, artery_of_current(tiles)) for door in doors):
                errors.append(f"{zone_id} {prop['type']} {prop['origin']} door is not on a lane")
        for exit_rec in doc["exits"]:
            for link in exit_rec["links"]:
                frm = (link["from"]["x"], link["from"]["y"])
                if tiles[frm]["terrain"] != "dirt_road" or frm in blocked_cells:
                    errors.append(f"{zone_id} exit {frm} is not an open road")
    return errors


def artery_of_current(tiles: dict) -> set[tuple[int, int]]:
    return {cell for cell, tile in tiles.items() if tile["terrain"] == "dirt_road"}


def dump_town(doc: dict) -> None:
    tiles = index_terrain(doc)
    w, h = doc["width"], doc["height"]
    grid = [["."] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            kind = tiles[(x, y)]["terrain"]
            if kind == "dirt_road":
                grid[y][x] = "#"
            elif kind == "water":
                grid[y][x] = "~"
            elif kind == "cliff":
                grid[y][x] = "^"
            elif kind.startswith("farm_"):
                grid[y][x] = "F"
    for prop in doc["props"]:
        mark = "H" if prop["type"] == "red_roof_cottage" else "B" if prop["type"] in SHADE else "p"
        for cell in prop_cells(prop):
            grid[cell[1]][cell[0]] = mark
    sx, sy = doc["spawn"]["x"], doc["spawn"]["y"]
    grid[sy][sx] = "@"
    print(f"\n== {doc['zone_id']} spawn {sx},{sy} cottages {sum(1 for p in doc['props'] if p['type']=='red_roof_cottage')} props {len(doc['props'])}")
    for y in range(h):
        print(f"{y:02d} " + "".join(grid[y]))


def main() -> None:
    zones = load_zones()
    problems = []
    for zone_id, layout in LAYOUTS.items():
        notes = apply_town(zones[zone_id], layout)
        for note in notes:
            problems.append(f"{zone_id}: {note}")
    problems.extend(validate(zones))
    if problems:
        for note in problems[:40]:
            print("ERROR", note)
        raise SystemExit(f"{len(problems)} density errors")
    for zone_id in TOWNS:
        doc = zones[zone_id]
        path = ZONE_DIR / f"{zone_id}.json"
        path.write_text(json.dumps(doc, indent=2) + "\n")
        dump_town(doc)
    print("density pass wrote", ", ".join(TOWNS))


if __name__ == "__main__":
    main()
