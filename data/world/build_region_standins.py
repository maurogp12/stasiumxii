"""Write WP5a stand-in chunks from each region's text map.

The text map lives at the top of data/world/<region>/build_<region>_zones.py.
Running this file, or any of those builders, rewrites that region's index,
stand-in sidecar, and the chunk JSON for every line marked built.
Chunks that are not marked built stay in the text map for WP5b.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
WIDTH = 32
HEIGHT = 24
SOUTH_XS = (12, 13, 14, 15)
EAST_YS = (8, 9, 10, 11)
SPAWN = (16, 12)
LANDMARK_ORIGIN = (2, 2)

DUNGEON_NAMES = {
    "rowanvale": "Rotting Orchard Barrow",
    "windmere": "Frostspire Archive",
    "brinewake": "Saltmaw Grotto",
    "slagcrown": "Cinderforge Depths",
    "eastmarch_fen_edge": "Sunken Mill",
    "gloomfen_mire": "Drowned Abbey",
    "stormspire": "Thunderwell Core",
    "ashen_shardfields": "Shard Hollow",
    "blightwood_hollow": "Heart of the Blight",
}

# Grade parameters for crosshaven_grade.gdshader. Weather stays in this sidecar.
# Grade numbers are the shipped sidecar values (WP6 rework). Regenerating a
# region must not put the earlier placeholder grades back.
LOOKS = {
    "rowanvale": {
        "ground": "farm_soil",
        "weather": ["clear"],
        "grade": {"warm_mul": [1.06, 1.02, 0.9], "haze_col": [0.62, 0.58, 0.32], "haze_max": 0.08, "saturation": 1.08},
    },
    "windmere": {
        "ground": "golden_plains",
        "weather": ["light_cloud"],
        "grade": {
            "warm_mul": [0.78, 0.88, 1.22], "haze_col": [0.82, 0.9, 1.0],
            "haze_max": 0.3, "saturation": 0.58, "tint_col": [0.0, 0.42, 1.0], "tint_amount": 0.55,
        },
    },
    "brinewake": {
        "ground": "golden_plains",
        "weather": ["clear"],
        "grade": {
            "warm_mul": [0.62, 1.02, 1.08], "haze_col": [0.55, 0.78, 0.92],
            "haze_max": 0.22, "saturation": 0.72, "tint_col": [0.0, 0.5, 1.0], "tint_amount": 0.55,
        },
    },
    "slagcrown": {
        "ground": "farm_fallow",
        "weather": ["clear"],
        "grade": {
            "warm_mul": [1.16, 0.86, 0.68], "haze_col": [0.75, 0.36, 0.16],
            "haze_max": 0.12, "saturation": 1.1, "tint_col": [1.0, 0.48, 0.08], "tint_amount": 0.4,
        },
    },
    "eastmarch_fen_edge": {
        "ground": "farm_soil",
        "weather": ["light_cloud"],
        "grade": {"warm_mul": [0.86, 0.96, 0.84], "haze_col": [0.435, 0.535, 0.53], "haze_max": 0.315, "saturation": 0.84},
    },
    "gloomfen_mire": {
        "ground": "farm_soil",
        "weather": ["light_rain"],
        "grade": {"warm_mul": [0.7, 0.92, 0.72], "haze_col": [0.42, 0.55, 0.44], "haze_max": 0.48, "saturation": 0.62},
    },
    "stormspire": {
        "ground": "golden_plains",
        "weather": ["wind"],
        "grade": {
            "warm_mul": [0.52, 0.54, 0.7], "haze_col": [0.28, 0.28, 0.4],
            "haze_max": 0.28, "saturation": 0.42, "tint_col": [0.7, 0.62, 0.98], "tint_amount": 0.5,
        },
    },
    "ashen_shardfields": {
        "ground": "farm_fallow",
        "weather": ["clear"],
        "grade": {"warm_mul": [1.02, 0.96, 1.0], "haze_col": [0.64, 0.58, 0.56], "haze_max": 0.1, "saturation": 0.9},
    },
    "blightwood_hollow": {
        "ground": "farm_plowed",
        "weather": ["light_cloud"],
        "grade": {
            "warm_mul": [0.74, 0.66, 1.1], "haze_col": [0.26, 0.14, 0.4],
            "haze_max": 0.18, "saturation": 0.7, "tint_col": [0.7, 0.08, 1.0], "tint_amount": 0.5,
        },
    },
}

OPPOSITE = {"north": "south", "south": "north", "east": "west", "west": "east"}


def builder_path(region: str) -> Path:
    return ROOT / region / f"build_{region}_zones.py"


def parse_text_map(text: str) -> tuple[str, list[dict]]:
    region = ""
    chunks: list[dict] = []
    for raw in text.splitlines():
        line = raw.strip()
        if line == "" or line.startswith("#"):
            continue
        if line.startswith("region "):
            region = line.split()[1]
            continue
        parts = line.split()
        edges = {}
        flags = []
        for token in parts[2:]:
            if "=" in token:
                edge, target = token.split("=", 1)
                edges[edge] = target
            else:
                flags.append(token)
        chunks.append({
            "id": parts[0],
            "role": parts[1],
            "built": "built" in flags,
            "edges": edges,
        })
    if region == "":
        raise SystemExit("text map has no region line")
    return region, chunks


def load_region(region: str) -> list[dict]:
    source = builder_path(region).read_text()
    marker = "TEXT_MAP = "
    start = source.index(marker)
    quote = source.index('"""', start)
    end = source.index('"""', quote + 3)
    text = source[quote + 3:end]
    found, chunks = parse_text_map(text)
    if found != region:
        raise SystemExit(f"{region} text map says {found}")
    return chunks


def link_pairs(edge: str) -> list[tuple[tuple[int, int], tuple[int, int]]]:
    if edge == "south":
        return [((x, HEIGHT - 1), (x, 0)) for x in SOUTH_XS]
    if edge == "north":
        return [((x, 0), (x, HEIGHT - 1)) for x in SOUTH_XS]
    if edge == "east":
        return [((WIDTH - 1, y), (0, y)) for y in EAST_YS]
    if edge == "west":
        return [((0, y), (WIDTH - 1, y)) for y in EAST_YS]
    raise SystemExit(f"unknown edge {edge}")


def exits_for(chunk: dict, built_ids: set[str]) -> list[dict]:
    grouped: dict[tuple[str, str], list] = {}
    for edge, target in chunk["edges"].items():
        if target not in built_ids:
            continue
        links = []
        for frm, dest in link_pairs(edge):
            links.append({
                "from": {"x": frm[0], "y": frm[1]},
                "to": {"x": dest[0], "y": dest[1]},
            })
        grouped[(edge, target)] = links
    rows = []
    for (edge, target), links in grouped.items():
        rows.append({
            "id": f"to_{target}",
            "edge": edge,
            "target_zone": target,
            "links": links,
        })
    return rows


def poi_for(region: str, chunk: dict) -> dict:
    if chunk["role"] == "door":
        return {
            "id": f"{chunk['id']}_door",
            "name": DUNGEON_NAMES[region],
            "kind": "landmark",
            "x": 20,
            "y": 12,
        }
    if chunk["role"] == "hub":
        return {
            "id": f"{chunk['id']}_hamlet",
            "name": region.replace("_", " ").title() + " Hamlet",
            "kind": "town",
            "x": 20,
            "y": 12,
        }
    return {
        "id": f"{chunk['id']}_mark",
        "name": chunk["id"].replace("_", " ").title(),
        "kind": "landmark",
        "x": 20,
        "y": 12,
    }


def zone_doc(region: str, chunk: dict, built_ids: set[str]) -> dict:
    ground = LOOKS[region]["ground"]
    tiles = []
    for y in range(HEIGHT):
        for x in range(WIDTH):
            terrain = "dirt_road" if x == 16 or y == 12 else ground
            tiles.append({
                "x": x,
                "y": y,
                "terrain": terrain,
                "walkable": True,
                "height": 0,
            })
    ox, oy = LANDMARK_ORIGIN
    footprint = []
    for dy in (0, 1):
        for dx in (0, 1, 2):
            footprint.append({"x": ox + dx, "y": oy + dy})
    return {
        "format": "stasium.zone",
        "format_version": 1,
        "zone_id": chunk["id"],
        "region": region,
        "width": WIDTH,
        "height": HEIGHT,
        "spawn": {"x": SPAWN[0], "y": SPAWN[1]},
        "points_of_interest": [poi_for(region, chunk)],
        "exits": exits_for(chunk, built_ids),
        "props": [{
            "id": f"{chunk['id']}_landmark",
            "type": "tavern_3x2",
            "blocks": True,
            "origin": {"x": ox, "y": oy},
            "footprint": footprint,
        }],
        "tiles": tiles,
    }


def index_doc(region: str, built: list[dict]) -> dict:
    entry = next(chunk for chunk in built if chunk["role"] == "entry")
    return {
        "format": "stasium.zone_index",
        "format_version": 1,
        "region": region,
        "start_zone": entry["id"],
        "start": {"zone_id": entry["id"], "x": SPAWN[0], "y": SPAWN[1]},
        "max_climb_steps": -1,
        "movement": {"adjacency": "ortho"},
        "zones": [
            {
                "zone_id": chunk["id"],
                "file": f"zones/{chunk['id']}.json",
                "width": WIDTH,
                "height": HEIGHT,
            }
            for chunk in built
        ],
    }


def stand_in_doc(region: str) -> dict:
    look = LOOKS[region]
    return {
        "format": "stasium.region_stand_in",
        "format_version": 1,
        "region": region,
        "weather": look["weather"],
        "grade": look["grade"],
    }


def write_region(region: str, dress: bool = True) -> None:
    chunks = load_region(region)
    built = [chunk for chunk in chunks if chunk["built"]]
    built_ids = {chunk["id"] for chunk in built}
    folder = ROOT / region
    zone_dir = folder / "zones"
    zone_dir.mkdir(parents=True, exist_ok=True)
    for stale in zone_dir.glob("*.json"):
        if stale.stem not in built_ids:
            stale.unlink()
    for chunk in built:
        path = zone_dir / f"{chunk['id']}.json"
        path.write_text(json.dumps(zone_doc(region, chunk, built_ids), indent=2) + "\n")
    (folder / "index.json").write_text(json.dumps(index_doc(region, built), indent=2) + "\n")
    side_path = folder / "stand_in.json"
    side_doc = stand_in_doc(region)
    # Keep the shipped sidecar bytes when the grade values already match.
    # json.dumps wraps tint_col differently from the checked-in files.
    if not side_path.exists() or json.loads(side_path.read_text()) != side_doc:
        side_path.write_text(json.dumps(side_doc, indent=2) + "\n")
    print(f"{region}: {len(built)} built / {len(chunks)} mapped")
    if dress and (folder / "dressing.json").exists():
        world_dir = str(Path(__file__).resolve().parent)
        if world_dir not in sys.path:
            sys.path.insert(0, world_dir)
        import dress_region
        dress_region.apply_region(
            region,
            built,
            built_ids,
            dress_region.load_footprints(),
            dress_region.load_npcs(),
            dress_region.load_gates(),
        )


def write_all() -> None:
    for region in LOOKS:
        write_region(region)


if __name__ == "__main__":
    write_all()
