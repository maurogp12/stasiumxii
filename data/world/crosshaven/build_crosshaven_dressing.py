#!/usr/bin/env python3
"""Dress Crosshaven chunks with v6 crops, blocking props, and walk-through decor.

Run after build_crosshaven_zones.py. Re-running the zone builder wipes this pass.
Footprints match backend/world_zone.gd. A new blocker is kept only when every
previously passable cell that it does not cover stays reachable from spawn.
"""

from __future__ import annotations

import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ZONE_DIR = ROOT / "data" / "world" / "crosshaven" / "zones"

FARMS = [
    ("crosshaven_crossroads", "farm_cabbage", 4, 3),
    ("crosshaven_crossroads", "farm_carrot", 3, 3),
    ("crosshaven_northgate", "farm_pumpkin", 4, 3),
    ("crosshaven_stoneford", "farm_lavender", 4, 3),
    ("crosshaven_eastmarch", "farm_sunflower", 4, 3),
    ("crosshaven_westwatch", "farm_plowed", 4, 3),
    ("crosshaven_southbridge", "farm_fallow", 4, 3),
    ("crosshaven_road_north", "farm_soil", 3, 4),
]

# type, footprint offsets from the northwest origin, home zone, on_water
PROPS = [
    ("fountain_2x2", [(0, 0), (1, 0), (0, 1), (1, 1)], "crosshaven_crossroads", False),
    ("signpost_crossroads", [(0, 0)], "crosshaven_crossroads", False),
    ("well", [(0, 0)], "crosshaven_crossroads", False),
    ("market_stall", [(0, 0), (1, 0)], "crosshaven_crossroads", False),
    ("lamp_post", [(0, 0)], "crosshaven_crossroads", False),
    ("barrel", [(0, 0)], "crosshaven_crossroads", False),
    ("bakery_2x2", [(0, 0), (1, 0), (0, 1), (1, 1)], "crosshaven_northgate", False),
    ("wall_tower", [(0, 0)], "crosshaven_northgate", False),
    ("stone_wall_high_nwse", [(0, 0)], "crosshaven_northgate", False),
    ("stone_wall_high_nesw", [(0, 0)], "crosshaven_northgate", False),
    ("brazier", [(0, 0)], "crosshaven_northgate", False),
    ("smithy_2x2", [(0, 0), (1, 0), (0, 1), (1, 1)], "crosshaven_stoneford", False),
    ("quarry_rocks_a", [(0, 0)], "crosshaven_stoneford", False),
    ("cart", [(0, 0)], "crosshaven_stoneford", False),
    ("waystone", [(0, 0)], "crosshaven_stoneford", False),
    ("fishing_hut_2x2", [(0, 0), (1, 0), (0, 1), (1, 1)], "crosshaven_eastmarch", False),
    ("net_rack", [(0, 0)], "crosshaven_eastmarch", False),
    ("watermill_2x2_body", [(0, 0), (1, 0), (0, 1), (1, 1)], "crosshaven_southbridge", False),
    ("hay_bale", [(0, 0)], "crosshaven_southbridge", False),
    ("watchtower_2x2", [(0, 0), (1, 0), (0, 1), (1, 1)], "crosshaven_westwatch", False),
    ("barn_2x2", [(0, 0), (1, 0), (0, 1), (1, 1)], "crosshaven_westwatch", False),
    ("scarecrow", [(0, 0)], "crosshaven_westwatch", False),
    ("tree_apple", [(0, 0)], "crosshaven_westwatch", False),
    ("windmill_2x2_body", [(0, 0), (1, 0), (0, 1), (1, 1)], "crosshaven_road_north", False),
    ("farmhouse_2x2", [(0, 0), (1, 0), (0, 1), (1, 1)], "crosshaven_road_north", False),
    ("farm_fence_nwse", [(0, 0)], "crosshaven_road_north", False),
    ("tavern_3x2", [(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1)], "crosshaven_road_south", False),
    ("haystack", [(0, 0)], "crosshaven_road_south", False),
    ("rowboat", [(0, 0)], "crosshaven_road_west", True),
    ("hedgerow_nesw", [(0, 0)], "crosshaven_road_east", False),
    ("hedgerow_nwse", [(0, 0)], "crosshaven_road_east", False),
    ("farm_fence_nesw", [(0, 0)], "crosshaven_road_east", False),
    ("crate_apples", [(0, 0)], "crosshaven_road_southwest", False),
    ("tree_cluster_2x2_a", [(0, 0), (1, 0), (0, 1), (1, 1)], "crosshaven_road_southwest", False),
]

ROAD_OK = {"signpost_crossroads", "lamp_post", "barrel", "cart", "waystone", "hay_bale", "crate_apples"}
DIRS = ((1, 0), (-1, 0), (0, 1), (0, -1))

PLAINS_DECOR = [
    "flowers_a", "flowers_b", "flowers_c", "flowers_d",
    "grass_tuft_a", "grass_tuft_b", "grass_tuft_tall_a",
    "tuft_a", "tuft_b", "bush_small_a", "bush_small_b",
    "mushrooms_a", "mushrooms_b", "rock_small_c", "rock_small_d",
    "sunflowers_tall", "decal_flowers_yellow", "decal_leaves",
]
ROAD_DECOR = ["decal_road_stones", "decal_pebbles", "decal_road_grass", "decal_path_stones_a", "decal_path_stones_b"]
FARM_DECOR = ["flowers_c", "grass_tuft_a", "decal_dirt_blend", "tuft_b"]
WATER_DECOR = ["lilypads_a", "reeds_a", "reeds_b", "ford_stones"]


def load_zones() -> dict[str, dict]:
    out = {}
    for path in sorted(ZONE_DIR.glob("*.json")):
        out[path.stem] = json.loads(path.read_text())
    return out


def index_maps(doc: dict) -> dict:
    w, h = doc["width"], doc["height"]
    terrain = {}
    walk = {}
    for tile in doc["tiles"]:
        c = (tile["x"], tile["y"])
        terrain[c] = tile["terrain"]
        walk[c] = bool(tile["walkable"])
    blocked = set()
    for prop in doc["props"]:
        if prop.get("blocks", True):
            for cell in prop["footprint"]:
                blocked.add((cell["x"], cell["y"]))
    reserved = {(doc["spawn"]["x"], doc["spawn"]["y"])}
    for poi in doc["points_of_interest"]:
        reserved.add((poi["x"], poi["y"]))
    for exit_rec in doc["exits"]:
        for link in exit_rec["links"]:
            frm = (link["from"]["x"], link["from"]["y"])
            reserved.add(frm)
            edge = exit_rec["edge"]
            inward = {"north": (0, 1), "south": (0, -1), "east": (-1, 0), "west": (1, 0)}[edge]
            reserved.add((frm[0] + inward[0], frm[1] + inward[1]))
    return {"w": w, "h": h, "terrain": terrain, "walk": walk, "blocked": blocked, "reserved": reserved}


def reachable(spawn, walk, blocked) -> set:
    if spawn in blocked or not walk.get(spawn, False):
        return set()
    seen = {spawn}
    q = deque([spawn])
    while q:
        x, y = q.popleft()
        for dx, dy in DIRS:
            n = (x + dx, y + dy)
            if n in seen or not walk.get(n, False) or n in blocked:
                continue
            seen.add(n)
            q.append(n)
    return seen


def must_reach(walk, blocked) -> set:
    return {c for c, ok in walk.items() if ok and c not in blocked}


def place_ok(maps, cells, on_water: bool, allow_road: bool, allow_farm: bool) -> bool:
    for c in cells:
        if c in maps["blocked"] or c in maps["reserved"]:
            return False
        kind = maps["terrain"].get(c, "")
        if on_water:
            if kind != "water":
                return False
            continue
        if not maps["walk"].get(c, False):
            return False
        if kind == "dirt_road" and not allow_road:
            return False
        if kind.startswith("farm_") and not allow_farm:
            return False
        if kind not in ("golden_plains", "dirt_road") and not kind.startswith("farm_"):
            return False
    return True


def keeps_reach(doc, maps, cells) -> bool:
    spawn = (doc["spawn"]["x"], doc["spawn"]["y"])
    before = must_reach(maps["walk"], maps["blocked"])
    trial = set(maps["blocked"])
    trial.update(cells)
    after_need = before - set(cells)
    got = reachable(spawn, maps["walk"], trial)
    return after_need <= got


def candidates(maps, bias) -> list:
    cells = [(x, y) for y in range(maps["h"]) for x in range(maps["w"])]
    cells.sort(key=lambda c: (abs(c[0] - bias[0]) + abs(c[1] - bias[1]), c[1], c[0]))
    return cells


def add_prop(doc, maps, prop_type, shape, on_water: bool) -> bool:
    spawn = (doc["spawn"]["x"], doc["spawn"]["y"])
    bias = spawn
    if doc["points_of_interest"]:
        poi = doc["points_of_interest"][0]
        bias = (poi["x"], poi["y"])
    tries = [(False, False), (prop_type in ROAD_OK, False), (True, True)]
    if on_water:
        tries = [(False, False)]
    for allow_road, allow_farm in tries:
        for origin in candidates(maps, bias):
            cells = [(origin[0] + dx, origin[1] + dy) for dx, dy in shape]
            if any(c[0] < 0 or c[1] < 0 or c[0] >= maps["w"] or c[1] >= maps["h"] for c in cells):
                continue
            if not place_ok(maps, cells, on_water, allow_road, allow_farm):
                continue
            if not on_water and not keeps_reach(doc, maps, cells):
                continue
            footprint = [{"x": c[0], "y": c[1]} for c in cells]
            doc["props"].append({
                "id": f"{doc['zone_id']}_{prop_type}_01",
                "type": prop_type,
                "blocks": True,
                "origin": {"x": origin[0], "y": origin[1]},
                "footprint": footprint,
            })
            if not on_water:
                maps["blocked"].update(cells)
            else:
                maps["blocked"].update(cells)
            return True
    return False


def paint_farm(doc, maps, farm: str, rw: int, rh: int) -> bool:
    best = None
    best_score = 10**9
    cx, cy = maps["w"] // 2, maps["h"] // 2
    for y in range(maps["h"] - rh + 1):
        for x in range(maps["w"] - rw + 1):
            cells = []
            ok = True
            for dy in range(rh):
                for dx in range(rw):
                    c = (x + dx, y + dy)
                    if maps["terrain"].get(c) != "golden_plains":
                        ok = False
                        break
                    if c in maps["blocked"] or c in maps["reserved"] or not maps["walk"].get(c, False):
                        ok = False
                        break
                    cells.append(c)
                if not ok:
                    break
            if not ok:
                continue
            score = abs((x + rw // 2) - cx) + abs((y + rh // 2) - cy)
            if score < best_score:
                best_score = score
                best = cells
    if best is None:
        return False
    wanted = set(best)
    for tile in doc["tiles"]:
        if (tile["x"], tile["y"]) in wanted:
            tile["terrain"] = farm
            tile["walkable"] = True
            maps["terrain"][(tile["x"], tile["y"])] = farm
    return True


EDGE_DECOR = [
    "flowers_a", "flowers_b", "flowers_c", "flowers_d",
    "bush_small_a", "bush_small_b",
    "grass_tuft_a", "grass_tuft_b", "grass_tuft_tall_a",
    "sunflowers_tall", "sunflowers_tall_b", "tuft_a", "tuft_b",
]
# Extra blockers. They sit off the road so the path stays walkable.
SCATTER = [
    ("tree", 18, 4, (2, 3)),
    ("hedgerow_nesw", 8, 3, (1, 1)),
    ("hedgerow_nwse", 8, 3, (1, 1)),
    ("lamp_post", 10, 5, (1, 1)),
    ("farm_fence_nesw", 6, 3, (1, 2)),
    ("farm_fence_nwse", 6, 3, (1, 2)),
    ("cart", 3, 6, (1, 2)),
    ("crate_apples", 4, 4, (1, 2)),
    ("barrel", 4, 4, (1, 2)),
]
DECOR_CAP = 320


def _hash(x: int, y: int) -> int:
    return ((x * 73856093) ^ (y * 19349663) ^ (x * y * 83492791)) & 0x7FFFFFFF


def dist_to_road(maps) -> dict:
    dist = {}
    q = deque()
    for c, kind in maps["terrain"].items():
        if kind == "dirt_road":
            dist[c] = 0
            q.append(c)
    while q:
        x, y = q.popleft()
        for dx, dy in DIRS:
            n = (x + dx, y + dy)
            if n in dist or n not in maps["terrain"]:
                continue
            dist[n] = dist[(x, y)] + 1
            q.append(n)
    return dist


def scatter_blockers(doc, maps) -> int:
    """Trees, hedges, lamps, fences, carts and crates along roads and in fields."""
    dist = dist_to_road(maps)
    placed = []
    added = 0
    for prop_type, cap, gap, band in SCATTER:
        got = 0
        cells = [(x, y) for y in range(maps["h"]) for x in range(maps["w"])]
        cells.sort(key=lambda c: (_hash(c[0], c[1]), c[1], c[0]))
        for c in cells:
            if got >= cap:
                break
            d = dist.get(c, 99)
            if d < band[0] or d > band[1]:
                continue
            if any(abs(c[0] - p[0]) + abs(c[1] - p[1]) < gap for p in placed):
                continue
            if not place_ok(maps, [c], False, False, False):
                continue
            if not keeps_reach(doc, maps, [c]):
                continue
            added += 1
            got += 1
            placed.append(c)
            maps["blocked"].add(c)
            doc["props"].append({
                "id": f"{doc['zone_id']}_scatter_{prop_type}_{got:02d}",
                "type": prop_type,
                "blocks": True,
                "origin": {"x": c[0], "y": c[1]},
                "footprint": [{"x": c[0], "y": c[1]}],
            })
    return added


def add_decor(doc, maps) -> int:
    spawn = (doc["spawn"]["x"], doc["spawn"]["y"])
    dist = dist_to_road(maps)
    edge = []
    roads = []
    fields = []
    water = []
    for y in range(maps["h"]):
        for x in range(maps["w"]):
            c = (x, y)
            if c in maps["blocked"] or c in maps["reserved"]:
                continue
            if abs(c[0] - spawn[0]) + abs(c[1] - spawn[1]) <= 2:
                continue
            kind = maps["terrain"].get(c, "")
            n = _hash(x, y)
            d = dist.get(c, 99)
            if kind == "water":
                if n % 6 != 0:
                    continue
                water.append((c, WATER_DECOR[n % len(WATER_DECOR)]))
            elif kind == "dirt_road":
                if n % 11 != 0:
                    continue
                roads.append((c, ROAD_DECOR[n % len(ROAD_DECOR)]))
            elif kind.startswith("farm_"):
                if n % 5 != 0:
                    continue
                fields.append((c, FARM_DECOR[n % len(FARM_DECOR)]))
            elif kind == "golden_plains":
                if d <= 2:
                    if n % 2 != 0:
                        continue
                    edge.append((c, EDGE_DECOR[n % len(EDGE_DECOR)]))
                else:
                    if n % 5 != 0:
                        continue
                    fields.append((c, PLAINS_DECOR[n % len(PLAINS_DECOR)]))
    chosen = (edge + roads + water + fields)[:DECOR_CAP]
    doc["decor"] = [
        {"id": f"{doc['zone_id']}_decor_{i:03d}", "type": decor_type, "x": c[0], "y": c[1]}
        for i, (c, decor_type) in enumerate(chosen, start=1)
    ]
    return len(chosen)


def strip_scatter(doc) -> None:
    prefix = f"{doc['zone_id']}_scatter_"
    doc["props"] = [p for p in doc["props"] if not str(p.get("id", "")).startswith(prefix)]


def enrich() -> None:
    """Replace decor and scatter blockers. Leaves farms and the one-of-each props."""
    zones = load_zones()
    for zone_id, doc in zones.items():
        strip_scatter(doc)
        maps = index_maps(doc)
        n_props = scatter_blockers(doc, maps)
        maps = index_maps(doc)
        n = add_decor(doc, maps)
        spawn = (doc["spawn"]["x"], doc["spawn"]["y"])
        got = reachable(spawn, maps["walk"], maps["blocked"])
        need = must_reach(maps["walk"], maps["blocked"])
        if got != need:
            raise SystemExit(f"{zone_id} reachability broke: {len(need - got)} cells")
        path = ZONE_DIR / f"{zone_id}.json"
        path.write_text(json.dumps(doc, indent=2) + "\n")
        print(f"wrote {zone_id} decor={n} scatter={n_props} props={len(doc['props'])}")


def main() -> None:
    zones = load_zones()
    for zone_id, farm, rw, rh in FARMS:
        maps = index_maps(zones[zone_id])
        if not paint_farm(zones[zone_id], maps, farm, rw, rh):
            raise SystemExit(f"no {rw}x{rh} plot for {farm} in {zone_id}")
        print(f"farm {farm} in {zone_id}")
    for prop_type, shape, home, on_water in PROPS:
        maps = index_maps(zones[home])
        if not add_prop(zones[home], maps, prop_type, shape, on_water):
            # Fall back through the other chunks so a tight town still gets a home.
            placed = False
            for other_id, other in zones.items():
                if other_id == home:
                    continue
                other_maps = index_maps(other)
                if add_prop(other, other_maps, prop_type, shape, on_water):
                    print(f"prop {prop_type} moved to {other_id}")
                    placed = True
                    break
            if not placed:
                raise SystemExit(f"could not place {prop_type}")
        else:
            print(f"prop {prop_type} in {home}")
    for zone_id, doc in zones.items():
        maps = index_maps(doc)
        n = add_decor(doc, maps)
        spawn = (doc["spawn"]["x"], doc["spawn"]["y"])
        got = reachable(spawn, maps["walk"], maps["blocked"])
        need = must_reach(maps["walk"], maps["blocked"])
        if got != need:
            raise SystemExit(f"{zone_id} reachability broke: {len(need - got)} cells")
        path = ZONE_DIR / f"{zone_id}.json"
        path.write_text(json.dumps(doc, indent=2) + "\n")
        print(f"wrote {zone_id} decor={n} props={len(doc['props'])}")


if __name__ == "__main__":
    enrich()
