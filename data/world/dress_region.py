#!/usr/bin/env python3
"""WP10a step 0. Dress built region chunks from dressing.json.

Crosshaven prop ids stand in until a region's painted art lands. The zone
format does not change: blocking props stay in props, walk-through dressing
stays in decor. The same seed always writes the same chunks.

Run: python3 data/world/dress_region.py
build_region_standins.write_region calls this after the stand-in skeleton.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ZONE_GD = ROOT.parents[1] / "backend" / "world_zone.gd"

WIDTH = 32
HEIGHT = 24
HERO_ORIGIN = (8, 4)
BLOCK_LIMIT = 0.08
DECOR_LIMIT = 0.25
DECOR_TARGET = 0.12
CLEARANCE = 2
SPACING = 2
GLADE = 4
CLUSTER_MIN = 3
CLUSTER_MAX = 5

# Stand-in ids are Crosshaven props already in world_zone.gd. stands_for is the
# painted name from WP10a; the art pair swaps the id when it lands.
CATALOG = {
    "rowanvale": {
        "seed": 11015,
        "ground": [("farm_soil", 4), ("golden_plains", 3), ("farm_cabbage", 2), ("farm_carrot", 1)],
        "props": [
            ("tree_apple", 4, "apple tree"),
            ("tree", 2, "pear tree"),
            ("hay_bale", 2, "hay bale"),
            ("scarecrow", 1, "scarecrow"),
            ("farm_fence_nwse", 2, "wooden fence"),
            ("crate_apples", 1, "beehive box"),
        ],
        "border": ("hedgerow_nwse", "orchard hedge"),
        "decor": [("flowers_a", 3), ("grass_tuft_a", 3), ("bush_small_a", 2), ("tuft_a", 2)],
        "hero_chunk": "rowanvale_hub",
        "hero_type": "windmill_2x2_body",
        "hero_name": "Old Windmill",
    },
    "windmere": {
        "seed": 1520,
        "ground": [("golden_plains", 5), ("farm_fallow", 2), ("farm_lavender", 1)],
        "props": [
            ("tree", 4, "snowy pine"),
            ("quarry_rocks_a", 2, "ice boulder"),
            ("lamp_post", 1, "warm lantern post"),
            ("well", 1, "ice crystal cluster"),
            ("hay_bale", 1, "snow drift"),
            ("fence", 2, "frozen shrub"),
        ],
        "border": ("tree", "snowy pine wall"),
        "decor": [("tuft_b", 3), ("rock_small_c", 2), ("decal_pebbles", 2), ("grass_tuft_b", 2)],
        "hero_chunk": "windmere_hub",
        "hero_type": "northgate_spire",
        "hero_name": "Frost Spire",
    },
    "brinewake": {
        "seed": 2025,
        "ground": [("golden_plains", 4), ("farm_fallow", 2), ("farm_soil", 1)],
        "props": [
            ("tree", 3, "palm"),
            ("rowboat", 2, "beached boat"),
            ("net_rack", 2, "net-drying rack"),
            ("barrel", 2, "crab pots and barrels"),
            ("quarry_rocks_a", 1, "shell rock"),
            ("lamp_post", 1, "dock post"),
        ],
        "border": ("quarry_rocks_a", "dune grass and rocks"),
        "decor": [("grass_tuft_tall_a", 3), ("reeds_a", 2), ("decal_pebbles", 2), ("bush_small_b", 1)],
        "hero_chunk": "brinewake_hub",
        "hero_type": "watchtower_2x2",
        "hero_name": "Lighthouse",
    },
    "slagcrown": {
        "seed": 2530,
        "ground": [("farm_fallow", 4), ("farm_plowed", 2), ("farm_soil", 1)],
        "props": [
            ("quarry_rocks_a", 4, "basalt columns"),
            ("tree", 2, "charred tree"),
            ("brazier", 2, "lava vent"),
            ("barrel", 1, "slag heap"),
            ("well", 1, "obsidian shard"),
            ("waystone", 1, "cooled lava boulder"),
        ],
        "border": ("stone_wall_high_nwse", "basalt cliff"),
        "decor": [("rock_small_d", 3), ("decal_pebbles", 2), ("mushrooms_a", 1), ("tuft_a", 2)],
        "hero_chunk": "slagcrown_hub",
        "hero_type": "smithy_2x2",
        "hero_name": "Magma Gate",
    },
    "eastmarch_fen_edge": {
        "seed": 2531,
        "ground": [("farm_soil", 4), ("golden_plains", 2), ("farm_plowed", 2)],
        "props": [
            ("tree", 4, "willow"),
            ("fence", 2, "broken fence"),
            ("cart", 1, "rotting cart"),
            ("hay_bale", 1, "mossy log"),
            ("well", 1, "cattails"),
            ("quarry_rocks_a", 1, "mud stone"),
        ],
        "border": ("tree", "willows and reeds"),
        "decor": [("reeds_a", 4), ("reeds_b", 3), ("decal_puddle_a", 2), ("grass_tuft_a", 2)],
        "hero_chunk": "eastmarch_fen_edge_entry",
        "hero_type": "watchtower_2x2",
        "hero_name": "Leaning Watchtower",
    },
    "gloomfen_mire": {
        "seed": 3038,
        "ground": [("farm_soil", 4), ("farm_plowed", 3), ("farm_fallow", 1)],
        "props": [
            ("tree", 4, "drowned stump"),
            ("fence", 2, "dead tree"),
            ("lamp_post", 1, "lantern buoy"),
            ("cart", 1, "fallen log"),
            ("well", 1, "bog pool"),
            ("barrel", 1, "peat stack"),
        ],
        "border": ("tree", "dead-tree thicket"),
        "decor": [("reeds_b", 3), ("lilypads_a", 3), ("mushrooms_b", 2), ("decal_moss", 2)],
        "hero_chunk": "gloomfen_mire_entry",
        "hero_type": "southbridge_spire",
        "hero_name": "Sunken Bell Tower",
    },
    "stormspire": {
        "seed": 3540,
        "ground": [("golden_plains", 4), ("farm_fallow", 2), ("farm_soil", 1)],
        "props": [
            ("tree", 3, "wind-bent tree"),
            ("quarry_rocks_a", 3, "jagged slate rock"),
            ("waystone", 2, "glowing rune stone"),
            ("lamp_post", 1, "broken pylon"),
            ("fence", 1, "copper conduit"),
            ("brazier", 1, "storm brazier"),
        ],
        "border": ("quarry_rocks_a", "jagged rock ridge"),
        "decor": [("grass_tuft_b", 3), ("rock_small_c", 3), ("tuft_b", 2), ("decal_pebbles", 1)],
        "hero_chunk": "stormspire_entry",
        "hero_type": "westwatch_spire",
        "hero_name": "Lightning Pylon",
    },
    "ashen_shardfields": {
        "seed": 3845,
        "ground": [("farm_fallow", 4), ("golden_plains", 2), ("farm_lavender", 2)],
        "props": [
            ("quarry_rocks_a", 4, "crystal shard cluster"),
            ("tree", 2, "petrified tree"),
            ("waystone", 2, "cracked obelisk"),
            ("well", 1, "ash rock"),
            ("barrel", 1, "glass chunk"),
            ("fence", 1, "dune stake"),
        ],
        "border": ("quarry_rocks_a", "crystal ridge"),
        "decor": [("rock_small_d", 3), ("decal_pebbles", 3), ("tuft_a", 2), ("mushrooms_a", 1)],
        "hero_chunk": "ashen_shardfields_entry",
        "hero_type": "tree_cluster_2x2_a",
        "hero_name": "Great Crystal Shard",
    },
    "blightwood_hollow": {
        "seed": 4548,
        "ground": [("farm_plowed", 4), ("farm_soil", 3), ("farm_fallow", 1)],
        "props": [
            ("tree", 4, "twisted dead tree"),
            ("fence", 2, "thorn bramble"),
            ("well", 1, "gravestone"),
            ("lamp_post", 1, "broken lantern post"),
            ("barrel", 1, "bone pile"),
            ("quarry_rocks_a", 2, "black rock"),
        ],
        "border": ("tree", "twisted-tree wall"),
        "decor": [("mushrooms_a", 4), ("mushrooms_b", 2), ("bush_small_a", 2), ("decal_moss", 2)],
        "hero_chunk": "blightwood_hollow_entry",
        "hero_type": "tree_cluster_2x2_a",
        "hero_name": "The Hollow Heart Tree",
    },
}


class Rng:
    def __init__(self, seed: int) -> None:
        self.state = seed & 0xFFFFFFFF

    def next(self) -> int:
        self.state = (1664525 * self.state + 1013904223) & 0xFFFFFFFF
        return self.state

    def rand(self, bound: int) -> int:
        if bound <= 1:
            return 0
        return self.next() % bound

    def pick(self, weighted: list[tuple]) -> str:
        total = sum(item[1] for item in weighted)
        roll = self.rand(total)
        acc = 0
        for item in weighted:
            acc += item[1]
            if roll < acc:
                return item[0]
        return weighted[-1][0]


def load_footprints() -> dict[str, list[tuple[int, int]]]:
    text = ZONE_GD.read_text()
    block = text.split("const PROP_FOOTPRINTS := {", 1)[1].split("\n}", 1)[0]
    footprints = {}
    for prop_id, body in re.findall(r'"([a-z0-9_]+)":\s*(\[\[.*?\]\])', block):
        pairs = re.findall(r"\[(-?\d+),\s*(-?\d+)\]", body)
        footprints[prop_id] = [(int(x), int(y)) for x, y in pairs]
    if footprints.get("tree") != [(0, 0)] or "tavern_3x2" not in footprints:
        raise SystemExit("could not read prop footprints from world_zone.gd")
    return footprints


def chebyshev(a: tuple[int, int], b: tuple[int, int]) -> int:
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]))


def bresenham(a: tuple[int, int], b: tuple[int, int]) -> list[tuple[int, int]]:
    x0, y0 = a
    x1, y1 = b
    dx = abs(x1 - x0)
    dy = abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy
    cells = []
    while True:
        cells.append((x0, y0))
        if (x0, y0) == (x1, y1):
            return cells
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x0 += sx
        if e2 < dx:
            err += dx
            y0 += sy


def in_bounds(cell: tuple[int, int]) -> bool:
    return 0 <= cell[0] < WIDTH and 0 <= cell[1] < HEIGHT


def footprint_cells(origin: tuple[int, int], shape: list[tuple[int, int]]) -> list[tuple[int, int]]:
    return [(origin[0] + dx, origin[1] + dy) for dx, dy in shape]


def make_prop(prop_id: str, prop_type: str, origin: tuple[int, int], shape: list[tuple[int, int]]) -> dict:
    return {
        "id": prop_id,
        "type": prop_type,
        "blocks": True,
        "origin": {"x": origin[0], "y": origin[1]},
        "footprint": [{"x": x, "y": y} for x, y in footprint_cells(origin, shape)],
    }


def dressing_doc(region: str, spec: dict) -> dict:
    return {
        "format": "stasium.region_dressing",
        "format_version": 1,
        "region": region,
        "seed": spec["seed"],
        "notes": "Crosshaven prop ids stand in until this region's art lands. stands_for is the WP10a painted name.",
        "ground_mix": [{"terrain": name, "weight": weight} for name, weight in spec["ground"]],
        "props": [
            {"type": name, "weight": weight, "stands_for": label}
            for name, weight, label in spec["props"]
            if weight > 0
        ],
        "border": {"type": spec["border"][0], "stands_for": spec["border"][1], "depth": 2},
        "decor": [{"type": name, "weight": weight} for name, weight in spec["decor"]],
        "cluster": {"min_size": CLUSTER_MIN, "max_size": CLUSTER_MAX, "spacing": SPACING, "glade": GLADE},
        "limits": {"blocking": BLOCK_LIMIT, "decor": DECOR_LIMIT},
        "clearance": CLEARANCE,
        "lane_margin": 1,
        "hero": {
            "chunk_id": spec["hero_chunk"],
            "type": spec["hero_type"],
            "stands_for": spec["hero_name"],
            "origin": {"x": HERO_ORIGIN[0], "y": HERO_ORIGIN[1]},
        },
    }


def write_dressing_files() -> None:
    for region, spec in CATALOG.items():
        path = ROOT / region / "dressing.json"
        path.write_text(json.dumps(dressing_doc(region, spec), indent=2) + "\n")


def load_npcs() -> dict[str, list[tuple[int, int]]]:
    doc = json.loads((ROOT / "npcs.json").read_text())
    by_zone: dict[str, list[tuple[int, int]]] = {}
    for row in doc["npcs"]:
        by_zone.setdefault(row["zone_id"], []).append((int(row["cell"]["x"]), int(row["cell"]["y"])))
    return by_zone


def load_gates() -> dict[str, list[tuple[int, int]]]:
    doc = json.loads((ROOT / "gates.json").read_text())
    by_zone: dict[str, list[tuple[int, int]]] = {}
    for gate in doc["gates"]:
        for side in ("from", "to"):
            zone_id = gate[side]["zone_id"]
            by_zone.setdefault(zone_id, []).append((int(gate[side]["x"]), int(gate[side]["y"])))
    return by_zone


def stable_seed(seed: int, text: str) -> int:
    mixed = seed & 0xFFFFFFFF
    for ch in text:
        mixed = ((mixed * 16777619) ^ ord(ch)) & 0xFFFFFFFF
    return mixed or 1


class ChunkDress:
    def __init__(self, doc: dict, chunk: dict, dressing: dict, npc_cells: list, gate_cells: list, footprints: dict) -> None:
        self.doc = doc
        self.chunk = chunk
        self.dressing = dressing
        self.footprints = footprints
        self.zone_id = chunk["id"]
        self.rng = Rng(stable_seed(int(dressing["seed"]), self.zone_id))
        self.path = {(int(tile["x"]), int(tile["y"])) for tile in doc["tiles"] if tile["terrain"] == "dirt_road"}
        self.lane = set(self.path)
        for cell in self.path:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nxt = (cell[0] + dx, cell[1] + dy)
                if in_bounds(nxt):
                    self.lane.add(nxt)
        self.exit_edges = {exit_rec["edge"] for exit_rec in doc["exits"]}
        self.exit_cells = []
        for exit_rec in doc["exits"]:
            for link in exit_rec["links"]:
                frm = link["from"]
                self.exit_cells.append((int(frm["x"]), int(frm["y"])))
        self.door_cells = []
        for poi in doc["points_of_interest"]:
            if str(poi["id"]).endswith("_door"):
                self.door_cells.append((int(poi["x"]), int(poi["y"])))
        spawn = doc["spawn"]
        seeds = [(int(spawn["x"]), int(spawn["y"]))]
        seeds.extend(npc_cells)
        seeds.extend(gate_cells)
        seeds.extend(self.exit_cells)
        seeds.extend(self.door_cells)
        self.protected = set()
        radius = int(dressing["clearance"])
        for cell in seeds:
            for dy in range(-radius, radius + 1):
                for dx in range(-radius, radius + 1):
                    if max(abs(dx), abs(dy)) <= radius:
                        nxt = (cell[0] + dx, cell[1] + dy)
                        if in_bounds(nxt):
                            self.protected.add(nxt)
        self.non_path = WIDTH * HEIGHT - len(self.path)
        self.occupied: set[tuple[int, int]] = set()
        self.sight: set[tuple[int, int]] = set()
        self.clusters: list[list[tuple[int, int]]] = []
        self.props: list[dict] = []
        self.decor: list[dict] = []

    def ratio(self, extra: int = 0) -> float:
        return (len(self.occupied) + extra) / float(self.non_path)

    def can_block(self, cell: tuple[int, int], group: list[tuple[int, int]]) -> bool:
        if not in_bounds(cell) or cell in self.lane or cell in self.protected or cell in self.sight or cell in self.occupied:
            return False
        for other in self.occupied:
            if chebyshev(cell, other) < SPACING:
                return False
        for cluster in self.clusters:
            for other in cluster:
                if chebyshev(cell, other) < GLADE:
                    return False
        for other in group:
            if chebyshev(cell, other) < SPACING:
                return False
        return True

    def commit(self, group: list[tuple[int, int]], kind: str, index: int, prop_type: str) -> None:
        if self.ratio(len(group)) > BLOCK_LIMIT + 1e-9:
            raise SystemExit(f"{self.zone_id} {kind} {index} would pass the blocking cap")
        shape = self.footprints[prop_type]
        if shape != [(0, 0)]:
            raise SystemExit(f"{prop_type} is not a 1x1 stand-in")
        for i, origin in enumerate(sorted(group)):
            self.props.append(make_prop(f"{self.zone_id}_{kind}_{index}_{i}", prop_type, origin, shape))
            self.occupied.add(origin)
        self.clusters.append(list(group))

    def grow(self, cands: list[tuple[int, int]]) -> list[tuple[int, int]]:
        if len(cands) < CLUSTER_MIN:
            return []
        order = list(cands)
        start = self.rng.rand(len(order))
        order = order[start:] + order[:start]
        span = 5
        for seed in order:
            group = [seed]
            for other in order:
                if other in group:
                    continue
                if not self.can_block(other, group):
                    continue
                if any(chebyshev(other, member) > span for member in group):
                    continue
                group.append(other)
                if len(group) >= CLUSTER_MAX:
                    break
            if len(group) >= CLUSTER_MIN:
                return group[:CLUSTER_MAX]
        return []

    def owner_edge(self, cell: tuple[int, int]) -> str:
        x, y = cell
        depths = {
            "north": y,
            "east": WIDTH - 1 - x,
            "south": HEIGHT - 1 - y,
            "west": x,
        }
        best = min(depths.values())
        if best > 1:
            return ""
        for edge in ("north", "east", "south", "west"):
            if depths[edge] == best and edge not in self.exit_edges:
                return edge
        return ""

    def place_landmark(self) -> None:
        hero = self.dressing["hero"]
        if self.zone_id == hero["chunk_id"]:
            origin = (int(hero["origin"]["x"]), int(hero["origin"]["y"]))
            prop_type = hero["type"]
            shape = self.footprints[prop_type]
            cells = footprint_cells(origin, shape)
            for cell in cells:
                if not in_bounds(cell) or cell in self.lane or cell in self.protected:
                    raise SystemExit(f"{self.zone_id} hero {prop_type} at {origin} hits a clear cell {cell}")
            spawn = (int(self.doc["spawn"]["x"]), int(self.doc["spawn"]["y"]))
            self.sight.update(bresenham(spawn, origin))
            for exit_rec in self.doc["exits"]:
                target = str(exit_rec["target_zone"])
                if target.endswith("_entry"):
                    for link in exit_rec["links"]:
                        frm = link["from"]
                        self.sight.update(bresenham((int(frm["x"]), int(frm["y"])), origin))
            for cell in cells:
                self.sight.discard(cell)
            prop = make_prop(f"{self.zone_id}_landmark", prop_type, origin, shape)
        else:
            origin = (2, 2)
            prop_type = "tavern_3x2"
            shape = self.footprints[prop_type]
            prop = make_prop(f"{self.zone_id}_landmark", prop_type, origin, shape)
            cells = footprint_cells(origin, shape)
        self.props.append(prop)
        self.occupied.update(cells)

    def place_border(self) -> None:
        prop_type = self.dressing["border"]["type"]
        index = 0
        for edge in ("north", "east", "south", "west"):
            if edge in self.exit_edges:
                continue
            cands = []
            for y in range(HEIGHT):
                for x in range(WIDTH):
                    cell = (x, y)
                    if self.owner_edge(cell) != edge:
                        continue
                    if self.can_block(cell, []):
                        cands.append(cell)
            cands.sort()
            group = self.grow(cands)
            if len(group) < CLUSTER_MIN:
                raise SystemExit(f"{self.zone_id} has no border cluster on {edge} ({len(cands)} free)")
            self.commit(group, "border", index, prop_type)
            index += 1

    def place_interior(self) -> None:
        weighted = [(row["type"], int(row["weight"])) for row in self.dressing["props"]]
        placed = 0
        seeds = [(x, y) for y in range(HEIGHT) for x in range(WIDTH) if self.edge_depth((x, y)) >= 4]
        start = self.rng.rand(len(seeds))
        seeds = seeds[start:] + seeds[:start]
        for seed in seeds:
            if placed >= 4:
                return
            if not self.can_block(seed, []):
                continue
            neighborhood = []
            for dy in range(-4, 5):
                for dx in range(-4, 5):
                    cell = (seed[0] + dx, seed[1] + dy)
                    if self.edge_depth(cell) >= 3 and self.can_block(cell, []):
                        neighborhood.append(cell)
            group = self.grow(neighborhood)
            if len(group) < CLUSTER_MIN:
                continue
            if self.ratio(len(group)) > BLOCK_LIMIT:
                continue
            prop_type = self.rng.pick(weighted)
            self.commit(group, "cluster", placed, prop_type)
            placed += 1
        if placed < 1:
            raise SystemExit(f"{self.zone_id} placed no interior cluster")

    def edge_depth(self, cell: tuple[int, int]) -> int:
        if not in_bounds(cell):
            return -1
        x, y = cell
        return min(x, y, WIDTH - 1 - x, HEIGHT - 1 - y)

    def place_decor(self) -> None:
        weighted = [(row["type"], int(row["weight"])) for row in self.dressing["decor"]]
        cands = []
        for y in range(HEIGHT):
            for x in range(WIDTH):
                cell = (x, y)
                if cell in self.lane or cell in self.protected or cell in self.occupied:
                    continue
                cands.append(cell)
        start = self.rng.rand(max(len(cands), 1))
        cands = cands[start:] + cands[:start]
        target = min(int(self.non_path * DECOR_TARGET), int(self.non_path * DECOR_LIMIT))
        for i, cell in enumerate(cands[:target]):
            self.decor.append({
                "id": f"{self.zone_id}_decor_{i}",
                "type": self.rng.pick(weighted),
                "x": cell[0],
                "y": cell[1],
            })

    def paint_ground(self) -> None:
        weighted = [(row["terrain"], int(row["weight"])) for row in self.dressing["ground_mix"]]
        for tile in self.doc["tiles"]:
            if tile["terrain"] == "dirt_road":
                continue
            tile["terrain"] = self.rng.pick(weighted)
            tile["walkable"] = True

    def apply(self) -> dict:
        self.place_landmark()
        self.place_border()
        self.place_interior()
        self.place_decor()
        self.paint_ground()
        self.doc["props"] = self.props
        self.doc["decor"] = self.decor
        return self.doc


def dress_document(doc: dict, chunk: dict, dressing: dict, npc_cells: list, gate_cells: list, footprints: dict) -> dict:
    return ChunkDress(doc, chunk, dressing, npc_cells, gate_cells, footprints).apply()


def apply_region(region: str, built: list[dict], built_ids: set[str], footprints: dict, npcs: dict, gates: dict) -> None:
    import build_region_standins as stand

    dressing = json.loads((ROOT / region / "dressing.json").read_text())
    if dressing["region"] != region:
        raise SystemExit(f"{region} dressing.json names {dressing['region']}")
    zone_dir = ROOT / region / "zones"
    for chunk in built:
        doc = stand.zone_doc(region, chunk, built_ids)
        dressed = dress_document(
            doc,
            chunk,
            dressing,
            npcs.get(chunk["id"], []),
            gates.get(chunk["id"], []),
            footprints,
        )
        path = zone_dir / f"{chunk['id']}.json"
        path.write_text(json.dumps(dressed, indent=2) + "\n")


def main() -> None:
    import build_region_standins as stand

    footprints = load_footprints()
    for spec in CATALOG.values():
        if spec["hero_type"] not in footprints:
            raise SystemExit(f"unknown hero {spec['hero_type']}")
        if spec["border"][0] not in footprints:
            raise SystemExit(f"unknown border {spec['border'][0]}")
    write_dressing_files()
    for region in CATALOG:
        stand.write_region(region, dress=True)


if __name__ == "__main__":
    main()
