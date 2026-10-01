#!/usr/bin/env python3
"""Generate Crosshaven open-world zone chunks.

Writes index.json and zones/*.json. The Godot scene and the server read those
files; this script is the authoring tool. Geography follows the world map:
Northgate north, Stoneford west, Eastmarch east, Westwatch southwest,
Southbridge south, roads joining them through a central crossroads.

Run from the repo root:

    python3 data/world/crosshaven/build_crosshaven_zones.py
"""

from __future__ import annotations

import json
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ZONE_DIR = ROOT / "zones"
SCHEMA_PATH = ROOT / "schema" / "zone.schema.json"
INDEX_SCHEMA_PATH = ROOT / "schema" / "index.schema.json"

TILE_WALKABLE = {
    "golden_plains": True,
    "dirt_road": True,
    "water": False,
    "cliff": False,
}

# Offsets from the northwest origin. +x east, +y south.
PROP_SHAPES = {
    "tree": [(0, 0)],
    "fence": [(0, 0)],
    "red_roof_cottage": [(0, 0), (1, 0), (0, 1), (1, 1)],
    "northgate_spire": [(0, 0), (1, 0), (0, 1), (1, 1)],
    "stoneford_spire": [(0, 0), (1, 0), (0, 1), (1, 1)],
    "eastmarch_spire": [(0, 0), (1, 0), (0, 1), (1, 1)],
    "westwatch_spire": [(0, 0), (1, 0), (0, 1), (1, 1)],
    "southbridge_spire": [(0, 0), (1, 0), (0, 1), (1, 1)],
    "crossroads_centerpiece": [(0, 0), (1, 0), (0, 1), (1, 1)],
}

EDGE_DIR = {
    "north": (0, -1),
    "south": (0, 1),
    "west": (-1, 0),
    "east": (1, 0),
}
OPPOSITE = {"north": "south", "south": "north", "east": "west", "west": "east"}
ORTHO = ((1, 0), (-1, 0), (0, 1), (0, -1))
ROAD_HALF = 2


def mouth_h(center_x: int, y: int) -> list[tuple[int, int]]:
    return [(center_x + d, y) for d in range(-ROAD_HALF, ROAD_HALF + 1)]


def mouth_v(x: int, center_y: int) -> list[tuple[int, int]]:
    return [(x, center_y + d) for d in range(-ROAD_HALF, ROAD_HALF + 1)]


class Zone:
    def __init__(self, zone_id: str, width: int, height: int, weather: list[str]) -> None:
        self.zone_id = zone_id
        self.w = width
        self.h = height
        self.weather = weather
        self.terrain = [["golden_plains" for _ in range(width)] for _ in range(height)]
        self.height = [[0 for _ in range(width)] for _ in range(height)]
        self.props: list[dict] = []
        self.exits: list[dict] = []
        self.pois: list[dict] = []
        self.spawn = (1, 1)
        self.blocked: set[tuple[int, int]] = set()
        self._counts: dict[str, int] = {}

    def in_bounds(self, x: int, y: int) -> bool:
        return 0 <= x < self.w and 0 <= y < self.h

    def fill_rect(self, x0: int, y0: int, x1: int, y1: int, terrain: str, height: int | None = None) -> None:
        if terrain not in TILE_WALKABLE:
            raise SystemExit(f"unknown terrain {terrain}")
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if not self.in_bounds(x, y):
                    raise SystemExit(f"{self.zone_id} fill OOB {(x, y)}")
                self.terrain[y][x] = terrain
                if height is not None:
                    self.height[y][x] = height

    def paint_road(self, x: int, y: int) -> None:
        if not self.in_bounds(x, y):
            return
        if self.terrain[y][x] == "cliff":
            return
        self.terrain[y][x] = "dirt_road"
        self.height[y][x] = 0

    def road_h(self, x0: int, x1: int, y: int, half: int = ROAD_HALF) -> None:
        if x0 > x1:
            x0, x1 = x1, x0
        for x in range(x0, x1 + 1):
            for dy in range(-half, half + 1):
                self.paint_road(x, y + dy)

    def road_v(self, x: int, y0: int, y1: int, half: int = ROAD_HALF) -> None:
        if y0 > y1:
            y0, y1 = y1, y0
        for y in range(y0, y1 + 1):
            for dx in range(-half, half + 1):
                self.paint_road(x + dx, y)

    def raise_plains(self, x0: int, y0: int, x1: int, y1: int, steps: int = 1) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if self.terrain[y][x] != "golden_plains":
                    raise SystemExit(
                        f"{self.zone_id} hill landed on {self.terrain[y][x]} at {(x, y)}"
                    )
                self.height[y][x] = steps

    def place(self, prop_type: str, ox: int, oy: int, allow_road: bool = False) -> None:
        shape = PROP_SHAPES[prop_type]
        cells: list[tuple[int, int]] = []
        for dx, dy in shape:
            x, y = ox + dx, oy + dy
            if not self.in_bounds(x, y):
                raise SystemExit(f"{self.zone_id} {prop_type} OOB {(x, y)}")
            if (x, y) in self.blocked:
                raise SystemExit(f"{self.zone_id} {prop_type} overlaps {(x, y)}")
            terrain = self.terrain[y][x]
            if terrain in ("water", "cliff"):
                raise SystemExit(f"{self.zone_id} {prop_type} on {terrain} {(x, y)}")
            if terrain == "dirt_road" and not allow_road:
                raise SystemExit(f"{self.zone_id} {prop_type} on road {(x, y)}")
            cells.append((x, y))
        count = self._counts.get(prop_type, 0) + 1
        self._counts[prop_type] = count
        self.props.append(
            {
                "id": f"{self.zone_id}_{prop_type}_{count:02d}",
                "type": prop_type,
                "blocks": True,
                "origin": {"x": ox, "y": oy},
                "footprint": [{"x": x, "y": y} for x, y in cells],
            }
        )
        self.blocked.update(cells)

    def add_exit(
        self,
        exit_id: str,
        edge: str,
        target: str,
        sources: list[tuple[int, int]],
        arrivals: list[tuple[int, int]],
    ) -> None:
        if len(sources) != len(arrivals):
            raise SystemExit(f"{self.zone_id} exit {exit_id} link length mismatch")
        self.exits.append(
            {
                "id": exit_id,
                "edge": edge,
                "target_zone": target,
                "links": [
                    {"from": {"x": a[0], "y": a[1]}, "to": {"x": b[0], "y": b[1]}}
                    for a, b in zip(sources, arrivals)
                ],
            }
        )

    def add_poi(self, poi_id: str, name: str, kind: str, x: int, y: int) -> None:
        self.pois.append({"id": poi_id, "name": name, "kind": kind, "x": x, "y": y})
        self.spawn = (x, y)

    def passable(self, x: int, y: int) -> bool:
        return TILE_WALKABLE[self.terrain[y][x]] and (x, y) not in self.blocked

    def to_json(self) -> dict:
        tiles = []
        for y in range(self.h):
            for x in range(self.w):
                terrain = self.terrain[y][x]
                tiles.append(
                    {
                        "x": x,
                        "y": y,
                        "terrain": terrain,
                        "walkable": TILE_WALKABLE[terrain],
                        "height": self.height[y][x],
                    }
                )
        return {
            "format": "stasium.zone",
            "format_version": 1,
            "zone_id": self.zone_id,
            "region": "crosshaven",
            "width": self.w,
            "height": self.h,
            "spawn": {"x": self.spawn[0], "y": self.spawn[1]},
            "points_of_interest": self.pois,
            "exits": self.exits,
            "props": self.props,
            "tiles": tiles,
            "presentation": {
                "status": "proposed",
                "authority": "client_visual",
                "default_weather": self.weather,
                "day_night": True,
            },
        }


def link(
    zones: dict[str, Zone],
    a_id: str,
    a_edge: str,
    a_cells: list[tuple[int, int]],
    b_id: str,
    b_edge: str,
    b_cells: list[tuple[int, int]],
) -> None:
    if OPPOSITE[a_edge] != b_edge:
        raise SystemExit(f"{a_id} {a_edge} is not opposite {b_id} {b_edge}")
    zones[a_id].add_exit(f"to_{b_id}", a_edge, b_id, a_cells, b_cells)
    zones[b_id].add_exit(f"to_{a_id}", b_edge, a_id, b_cells, a_cells)


def build() -> dict[str, Zone]:
    zones = {
        "crosshaven_crossroads": Zone(
            "crosshaven_crossroads", 40, 36, ["clear", "light_cloud", "light_rain"]
        ),
        "crosshaven_road_north": Zone(
            "crosshaven_road_north", 24, 32, ["clear", "light_cloud"]
        ),
        "crosshaven_northgate": Zone(
            "crosshaven_northgate", 40, 32, ["clear", "light_cloud", "wind"]
        ),
        "crosshaven_road_west": Zone(
            "crosshaven_road_west", 36, 24, ["clear", "light_cloud"]
        ),
        "crosshaven_stoneford": Zone(
            "crosshaven_stoneford", 36, 32, ["clear", "light_rain"]
        ),
        "crosshaven_road_east": Zone(
            "crosshaven_road_east", 36, 24, ["clear", "light_cloud"]
        ),
        "crosshaven_eastmarch": Zone(
            "crosshaven_eastmarch", 36, 32, ["clear", "light_cloud", "light_rain"]
        ),
        "crosshaven_road_southwest": Zone(
            "crosshaven_road_southwest", 32, 32, ["clear", "light_cloud"]
        ),
        "crosshaven_westwatch": Zone(
            "crosshaven_westwatch", 36, 32, ["clear", "light_rain"]
        ),
        "crosshaven_road_south": Zone(
            "crosshaven_road_south", 24, 36, ["clear", "light_rain"]
        ),
        "crosshaven_southbridge": Zone(
            "crosshaven_southbridge", 40, 32, ["clear", "light_rain", "light_cloud"]
        ),
    }

    # Borders. Other regions are out of scope, so these edges have no exits.
    north = zones["crosshaven_northgate"]
    north.fill_rect(0, 0, 39, 0, "cliff", 4)
    north.fill_rect(0, 1, 39, 1, "cliff", 3)
    north.fill_rect(0, 2, 39, 2, "cliff", 2)
    north.raise_plains(0, 3, 39, 3, 1)

    stone = zones["crosshaven_stoneford"]
    stone.fill_rect(0, 0, 2, 31, "water", 0)
    stone.fill_rect(8, 0, 8, 31, "water", 0)

    east = zones["crosshaven_eastmarch"]
    east.fill_rect(33, 0, 35, 31, "water", 0)

    westwatch = zones["crosshaven_westwatch"]
    westwatch.fill_rect(0, 0, 2, 31, "water", 0)
    westwatch.fill_rect(0, 29, 35, 29, "cliff", 2)
    westwatch.fill_rect(0, 30, 35, 30, "cliff", 3)
    westwatch.fill_rect(0, 31, 35, 31, "cliff", 4)
    westwatch.raise_plains(3, 28, 35, 28, 1)

    south_road = zones["crosshaven_road_south"]
    south_road.fill_rect(0, 22, 23, 22, "water", 0)

    west_road = zones["crosshaven_road_west"]
    west_road.fill_rect(18, 0, 18, 23, "water", 0)

    southbridge = zones["crosshaven_southbridge"]
    southbridge.fill_rect(8, 23, 12, 25, "water", 0)
    southbridge.fill_rect(0, 29, 39, 29, "cliff", 2)
    southbridge.fill_rect(0, 30, 39, 30, "cliff", 3)
    southbridge.fill_rect(0, 31, 39, 31, "cliff", 4)
    southbridge.raise_plains(0, 28, 39, 28, 1)

    # Dirt roads. Painted after water so fords and the Southbridge bridge stay walkable.
    cross = zones["crosshaven_crossroads"]
    cross.road_v(20, 0, 35)
    cross.road_h(0, 39, 18)
    cross.road_h(0, 20, 28)

    zones["crosshaven_road_north"].road_v(12, 0, 31)
    north.road_v(20, 6, 31)
    west_road.road_h(0, 35, 12)
    stone.road_h(4, 35, 16)
    zones["crosshaven_road_east"].road_h(0, 35, 12)
    east.road_h(0, 31, 16)
    zones["crosshaven_road_southwest"].road_h(14, 31, 28)
    zones["crosshaven_road_southwest"].road_v(14, 28, 31)
    westwatch.road_v(16, 0, 22)
    south_road.road_v(12, 0, 35)
    southbridge.road_v(20, 0, 20)

    # Gentle rises on plains. Walkable neighbors differ by at most one step.
    cross.raise_plains(6, 12, 7, 13, 1)
    north.raise_plains(10, 24, 11, 25, 1)
    stone.raise_plains(30, 24, 31, 25, 1)
    east.raise_plains(10, 26, 11, 27, 1)
    westwatch.raise_plains(28, 22, 29, 23, 1)
    southbridge.raise_plains(30, 22, 31, 23, 1)
    zones["crosshaven_road_north"].raise_plains(6, 20, 6, 20, 1)
    zones["crosshaven_road_south"].raise_plains(6, 6, 6, 6, 1)
    west_road.raise_plains(24, 18, 24, 18, 1)
    zones["crosshaven_road_east"].raise_plains(20, 4, 20, 4, 1)
    zones["crosshaven_road_southwest"].raise_plains(20, 8, 20, 8, 1)

    # Props. Cottages and spires sit off the roads. The centerpiece sits on the crossing.
    cross.place("crossroads_centerpiece", 19, 17, allow_road=True)
    for xy in (
        (4, 4),
        (8, 6),
        (34, 5),
        (36, 10),
        (5, 32),
        (34, 30),
        (8, 22),
        (30, 24),
        (3, 14),
        (26, 8),
    ):
        cross.place("tree", *xy)
    cross.place("fence", 6, 8)
    cross.place("fence", 7, 8)
    cross.place("fence", 32, 8)
    cross.place("fence", 33, 8)
    cross.add_poi("crossroads", "Crosshaven Crossroads", "crossroads", 22, 18)

    def dress_town(zone: Zone, spire: str, poi_id: str, poi_name: str, spire_at, poi_at, cottages, fences, trees) -> None:
        zone.place(spire, *spire_at)
        for origin in cottages:
            zone.place("red_roof_cottage", *origin)
        for origin in fences:
            zone.place("fence", *origin)
        for origin in trees:
            zone.place("tree", *origin)
        zone.add_poi(poi_id, poi_name, "town", *poi_at)

    dress_town(
        north,
        "northgate_spire",
        "northgate_center",
        "Northgate",
        (14, 10),
        (16, 11),
        [(6, 8), (26, 8), (6, 18), (26, 18)],
        [(6, 7), (7, 7), (28, 8), (28, 9)],
        [(4, 24), (10, 26), (33, 24), (36, 6), (12, 5)],
    )
    dress_town(
        stone,
        "stoneford_spire",
        "stoneford_center",
        "Stoneford",
        (22, 12),
        (25, 12),
        [(12, 8), (28, 8), (12, 20), (28, 20)],
        [(12, 7), (13, 7), (28, 7), (29, 7)],
        [(4, 10), (5, 22), (20, 6), (32, 22), (30, 26)],
    )
    dress_town(
        east,
        "eastmarch_spire",
        "eastmarch_center",
        "Eastmarch",
        (18, 8),
        (21, 8),
        [(6, 6), (24, 6), (6, 22), (24, 22)],
        [(6, 5), (7, 5), (26, 6), (26, 7)],
        [(10, 26), (28, 26), (14, 10), (30, 10)],
    )
    dress_town(
        westwatch,
        "westwatch_spire",
        "westwatch_center",
        "Westwatch",
        (22, 12),
        (25, 13),
        [(6, 8), (24, 8), (6, 18), (24, 20)],
        [(6, 7), (7, 7), (26, 8), (26, 9)],
        [(4, 14), (10, 24), (30, 16), (32, 24), (20, 26)],
    )
    dress_town(
        southbridge,
        "southbridge_spire",
        "southbridge_center",
        "Southbridge",
        (12, 12),
        (15, 13),
        [(6, 8), (26, 8), (6, 18), (26, 18)],
        [(6, 7), (7, 7), (28, 8), (28, 9)],
        [(4, 6), (34, 12), (30, 24), (14, 26)],
    )

    def dress_road(zone: Zone, poi_id: str, poi_name: str, poi_at, trees, fences) -> None:
        for origin in trees:
            zone.place("tree", *origin)
        for origin in fences:
            zone.place("fence", *origin)
        zone.add_poi(poi_id, poi_name, "landmark", *poi_at)

    dress_road(
        zones["crosshaven_road_north"],
        "north_road",
        "North Road",
        (12, 16),
        [(3, 6), (4, 16), (5, 26), (18, 8), (19, 18), (20, 27)],
        [(2, 12), (2, 13)],
    )
    dress_road(
        west_road,
        "stone_ford",
        "Stone Ford",
        (18, 12),
        [(6, 4), (8, 18), (28, 4), (30, 18), (22, 6)],
        [(6, 2), (7, 2)],
    )
    dress_road(
        zones["crosshaven_road_east"],
        "east_road",
        "East Road",
        (18, 12),
        [(6, 4), (10, 18), (24, 5), (28, 18), (16, 20)],
        [(8, 20), (9, 20)],
    )
    dress_road(
        zones["crosshaven_road_southwest"],
        "westwatch_road",
        "Westwatch Road",
        (22, 28),
        [(4, 4), (8, 10), (16, 8), (24, 14), (6, 18)],
        [(4, 14), (4, 15)],
    )
    dress_road(
        south_road,
        "southbridge_crossing",
        "Southbridge Crossing",
        (12, 22),
        [(3, 8), (4, 16), (18, 8), (19, 30), (5, 28)],
        [(18, 12), (19, 12)],
    )

    link(
        zones,
        "crosshaven_crossroads",
        "north",
        mouth_h(20, 0),
        "crosshaven_road_north",
        "south",
        mouth_h(12, 31),
    )
    link(
        zones,
        "crosshaven_road_north",
        "north",
        mouth_h(12, 0),
        "crosshaven_northgate",
        "south",
        mouth_h(20, 31),
    )
    link(
        zones,
        "crosshaven_crossroads",
        "west",
        mouth_v(0, 18),
        "crosshaven_road_west",
        "east",
        mouth_v(35, 12),
    )
    link(
        zones,
        "crosshaven_road_west",
        "west",
        mouth_v(0, 12),
        "crosshaven_stoneford",
        "east",
        mouth_v(35, 16),
    )
    link(
        zones,
        "crosshaven_crossroads",
        "east",
        mouth_v(39, 18),
        "crosshaven_road_east",
        "west",
        mouth_v(0, 12),
    )
    link(
        zones,
        "crosshaven_road_east",
        "east",
        mouth_v(35, 12),
        "crosshaven_eastmarch",
        "west",
        mouth_v(0, 16),
    )
    link(
        zones,
        "crosshaven_crossroads",
        "west",
        mouth_v(0, 28),
        "crosshaven_road_southwest",
        "east",
        mouth_v(31, 28),
    )
    link(
        zones,
        "crosshaven_road_southwest",
        "south",
        mouth_h(14, 31),
        "crosshaven_westwatch",
        "north",
        mouth_h(16, 0),
    )
    link(
        zones,
        "crosshaven_crossroads",
        "south",
        mouth_h(20, 35),
        "crosshaven_road_south",
        "north",
        mouth_h(12, 0),
    )
    link(
        zones,
        "crosshaven_road_south",
        "south",
        mouth_h(12, 35),
        "crosshaven_southbridge",
        "north",
        mouth_h(20, 0),
    )
    return zones


def exit_lookup(zone: Zone) -> dict[tuple[int, int], tuple[str, int, int, str]]:
    found: dict[tuple[int, int], tuple[str, int, int, str]] = {}
    for exit_rec in zone.exits:
        edge = exit_rec["edge"]
        for link_rec in exit_rec["links"]:
            src = (link_rec["from"]["x"], link_rec["from"]["y"])
            if src in found:
                raise SystemExit(f"{zone.zone_id} exit tile {src} used twice")
            found[src] = (
                exit_rec["target_zone"],
                link_rec["to"]["x"],
                link_rec["to"]["y"],
                edge,
            )
    return found


def assert_layout(zones: dict[str, Zone]) -> None:
    for zone in zones.values():
        if not zone.passable(*zone.spawn):
            raise SystemExit(f"{zone.zone_id} spawn {zone.spawn} is not passable")
        for poi in zone.pois:
            if not zone.passable(poi["x"], poi["y"]):
                raise SystemExit(f"{zone.zone_id} poi {poi['id']} is not passable")
        lookup = exit_lookup(zone)
        dx, dy = 0, 0
        for (x, y), (target, ax, ay, edge) in lookup.items():
            dx, dy = EDGE_DIR[edge]
            if zone.in_bounds(x + dx, y + dy):
                raise SystemExit(f"{zone.zone_id} exit {(x, y)} does not leave via {edge}")
            if not zone.passable(x, y):
                raise SystemExit(f"{zone.zone_id} exit {(x, y)} is not passable")
            if zone.terrain[y][x] != "dirt_road":
                raise SystemExit(f"{zone.zone_id} exit {(x, y)} is {zone.terrain[y][x]}")
            other = zones[target]
            if not other.in_bounds(ax, ay) or not other.passable(ax, ay):
                raise SystemExit(f"{zone.zone_id} arrival {(ax, ay)} in {target} is not passable")
            back = exit_lookup(other).get((ax, ay))
            if back != (zone.zone_id, x, y, OPPOSITE[edge]):
                raise SystemExit(f"exit {(zone.zone_id, x, y)} is not reciprocal, got {back}")

    north = zones["crosshaven_northgate"]
    if any(north.terrain[0][x] != "cliff" for x in range(north.w)):
        raise SystemExit("northgate north edge is not cliff")
    stone = zones["crosshaven_stoneford"]
    if any(stone.terrain[y][0] != "water" for y in range(stone.h)):
        raise SystemExit("stoneford west edge is not water")
    east = zones["crosshaven_eastmarch"]
    if any(east.terrain[y][east.w - 1] != "water" for y in range(east.h)):
        raise SystemExit("eastmarch east edge is not water")
    bridge = zones["crosshaven_southbridge"]
    if any(bridge.terrain[bridge.h - 1][x] != "cliff" for x in range(bridge.w)):
        raise SystemExit("southbridge south edge is not cliff")
    if zones["crosshaven_road_south"].terrain[22][12] != "dirt_road":
        raise SystemExit("south bridge is not dirt_road")
    if zones["crosshaven_road_west"].terrain[12][18] != "dirt_road":
        raise SystemExit("stone ford is not dirt_road")

    spire_home = {
        "northgate_spire": "crosshaven_northgate",
        "stoneford_spire": "crosshaven_stoneford",
        "eastmarch_spire": "crosshaven_eastmarch",
        "westwatch_spire": "crosshaven_westwatch",
        "southbridge_spire": "crosshaven_southbridge",
    }
    seen = {key: 0 for key in spire_home}
    centerpieces = 0
    for zone in zones.values():
        for prop in zone.props:
            if prop["type"] in spire_home:
                if zone.zone_id != spire_home[prop["type"]]:
                    raise SystemExit(f"{prop['type']} placed in {zone.zone_id}")
                seen[prop["type"]] += 1
            if prop["type"] == "crossroads_centerpiece":
                if zone.zone_id != "crosshaven_crossroads":
                    raise SystemExit("centerpiece is outside the crossroads")
                centerpieces += 1
    for prop_type, count in seen.items():
        if count != 1:
            raise SystemExit(f"{prop_type} count is {count}")
    if centerpieces != 1:
        raise SystemExit(f"centerpiece count is {centerpieces}")

    start = zones["crosshaven_crossroads"]
    seen_cells: set[tuple[str, int, int]] = set()
    queue: deque[tuple[str, int, int]] = deque()
    queue.append((start.zone_id, start.spawn[0], start.spawn[1]))
    seen_cells.add((start.zone_id, start.spawn[0], start.spawn[1]))
    while queue:
        zone_id, x, y = queue.popleft()
        zone = zones[zone_id]
        links = exit_lookup(zone)
        for dx, dy in ORTHO:
            nx, ny = x + dx, y + dy
            if zone.in_bounds(nx, ny):
                if not zone.passable(nx, ny):
                    continue
                if abs(zone.height[ny][nx] - zone.height[y][x]) > 1:
                    raise SystemExit(f"slope {zone_id} {(x, y)} -> {(nx, ny)}")
                key = (zone_id, nx, ny)
            else:
                hopped = links.get((x, y))
                if hopped is None or EDGE_DIR[hopped[3]] != (dx, dy):
                    continue
                target, ax, ay, _edge = hopped
                other = zones[target]
                if abs(other.height[ay][ax] - zone.height[y][x]) > 1:
                    raise SystemExit(f"exit slope {zone_id} {(x, y)} -> {target} {(ax, ay)}")
                key = (target, ax, ay)
            if key not in seen_cells:
                seen_cells.add(key)
                queue.append(key)

    missing = []
    for zone in zones.values():
        for y in range(zone.h):
            for x in range(zone.w):
                if zone.passable(x, y) and (zone.zone_id, x, y) not in seen_cells:
                    missing.append((zone.zone_id, x, y))
    if missing:
        raise SystemExit(f"{len(missing)} passable tiles unreachable, e.g. {missing[:6]}")


def write(zones: dict[str, Zone]) -> None:
    ZONE_DIR.mkdir(parents=True, exist_ok=True)
    order = [
        "crosshaven_crossroads",
        "crosshaven_road_north",
        "crosshaven_northgate",
        "crosshaven_road_west",
        "crosshaven_stoneford",
        "crosshaven_road_east",
        "crosshaven_eastmarch",
        "crosshaven_road_southwest",
        "crosshaven_westwatch",
        "crosshaven_road_south",
        "crosshaven_southbridge",
    ]
    docs = {}
    for zone_id in order:
        doc = zones[zone_id].to_json()
        docs[zone_id] = doc
        path = ZONE_DIR / f"{zone_id}.json"
        path.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {path.relative_to(ROOT)} {doc['width']}x{doc['height']} props={len(doc['props'])}")

    start = zones["crosshaven_crossroads"]
    index = {
        "format": "stasium.zone_index",
        "format_version": 1,
        "region": "crosshaven",
        "start_zone": start.zone_id,
        "start": {"zone_id": start.zone_id, "x": start.spawn[0], "y": start.spawn[1]},
        "max_climb_steps": -1,
        "movement": {"adjacency": "ortho"},
        "zones": [
            {
                "zone_id": zone_id,
                "file": f"zones/{zone_id}.json",
                "width": zones[zone_id].w,
                "height": zones[zone_id].h,
            }
            for zone_id in order
        ],
    }
    (ROOT / "index.json").write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")
    _check_schema(index, docs)


def _check_schema(index: dict, docs: dict[str, dict]) -> None:
    try:
        import jsonschema
    except ImportError:
        print("jsonschema not installed; skipped draft-2020-12 check")
        return
    zone_schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    index_schema = json.loads(INDEX_SCHEMA_PATH.read_text(encoding="utf-8"))
    jsonschema.Draft202012Validator.check_schema(zone_schema)
    jsonschema.Draft202012Validator.check_schema(index_schema)
    jsonschema.validate(index, index_schema)
    for zone_id, doc in docs.items():
        jsonschema.validate(doc, zone_schema)
    print("json schema: index and zones valid")


def main() -> None:
    zones = build()
    assert_layout(zones)
    write(zones)


if __name__ == "__main__":
    try:
        main()
    except SystemExit as exc:
        if exc.code not in (None, 0):
            print(exc, file=sys.stderr)
        raise
