#!/usr/bin/env python3
"""Run each region builder on a temp copy of the world data.

The builders live in data/world/<region>/ and import dress_region. That import
used to fail once the undressed chunks were already written. This check copies
the tree, runs every builder, and checks the copy came back dressed.
"""

from __future__ import annotations

import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGIONS = [
    "rowanvale",
    "windmere",
    "brinewake",
    "slagcrown",
    "eastmarch_fen_edge",
    "gloomfen_mire",
    "stormspire",
    "ashen_shardfields",
    "blightwood_hollow",
]
CROPS = {"farm_cabbage", "farm_carrot", "farm_lavender", "farm_pumpkin", "farm_sunflower"}


def copy_tree(dest: Path) -> None:
    world = dest / "data" / "world"
    shutil.copytree(
        ROOT / "data" / "world",
        world,
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
    )
    backend = dest / "backend"
    backend.mkdir(parents=True)
    shutil.copy(ROOT / "backend" / "world_zone.gd", backend / "world_zone.gd")


def run_builder(dest: Path, region: str) -> subprocess.CompletedProcess:
    script = dest / "data" / "world" / region / f"build_{region}_zones.py"
    return subprocess.run(
        [sys.executable, str(script)],
        cwd=dest,
        text=True,
        capture_output=True,
    )


def load_dress(dest: Path):
    path = dest / "data" / "world" / "dress_region.py"
    spec = importlib.util.spec_from_file_location("dress_region_temp", path)
    if spec is None or spec.loader is None:
        raise SystemExit("could not load the temp dress_region")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def border_count(zone_path: Path) -> int:
    text = zone_path.read_text()
    return text.count("_border_")


def check_seed(dest: Path) -> None:
    module = load_dress(dest)
    path = dest / "data" / "world" / "rowanvale" / "dressing.json"
    original = path.read_text()
    marked = original.replace("Crosshaven", "Crosshaven SENTINEL", 1)
    if marked == original:
        raise SystemExit("sentinel was not written into the temp dressing file")
    path.write_text(marked)
    module.seed_dressing_files()
    if "SENTINEL" not in path.read_text():
        raise SystemExit("seed overwrote an existing dressing.json")
    path.write_text(original)
    saved = path.read_text()
    path.unlink()
    module.seed_dressing_files()
    if not path.exists():
        raise SystemExit("seed did not create a missing dressing.json")
    fresh = json.loads(path.read_text())
    if fresh.get("region") != "rowanvale" or fresh.get("format") != "stasium.region_dressing":
        raise SystemExit("seeded dressing.json is not a rowanvale dressing file")
    path.write_text(saved)


def check_dressed(dest: Path) -> None:
    for region in REGIONS:
        mix = json.loads((dest / "data" / "world" / region / "dressing.json").read_text())["ground_mix"]
        terrains = {row["terrain"] for row in mix}
        crops = terrains & CROPS
        if crops:
            raise SystemExit(f"{region} ground mix still uses crop tiles {sorted(crops)}")
        zone_dir = dest / "data" / "world" / region / "zones"
        zones = list(zone_dir.glob("*.json"))
        if not zones:
            raise SystemExit(f"{region} builder wrote no chunks")
        for zone_path in zones:
            count = border_count(zone_path)
            if count < 20:
                raise SystemExit(f"{zone_path.name} has {count} border props; the band was not placed")


def non_path(doc: dict) -> int:
    roads = sum(1 for tile in doc["tiles"] if tile["terrain"] == "dirt_road")
    return int(doc["width"]) * int(doc["height"]) - roads


def check_knobs(dest: Path) -> None:
    region = "rowanvale"
    path = dest / "data" / "world" / region / "dressing.json"
    doc = json.loads(path.read_text())
    doc["limits"]["decor"] = 0.02
    doc["border"]["depth"] = 1
    doc["cluster"]["spacing"] = 3
    doc["cluster"]["min_size"] = 3
    doc["cluster"]["max_size"] = 3
    path.write_text(json.dumps(doc, indent=2) + "\n")
    result = run_builder(dest, region)
    if result.returncode != 0:
        raise SystemExit(f"knob rebuild failed\n{result.stdout}\n{result.stderr}")
    for zone_path in (dest / "data" / "world" / region / "zones").glob("*.json"):
        zone = json.loads(zone_path.read_text())
        decor_n = len(zone.get("decor", []))
        cap = non_path(zone) * 0.02 + 1e-6
        if decor_n > cap:
            raise SystemExit(f"{zone['zone_id']} placed {decor_n} decor past the file cap {cap:.1f}")
        for prop in zone["props"]:
            if "_border_" not in str(prop["id"]):
                continue
            origin = prop["origin"]
            x, y = int(origin["x"]), int(origin["y"])
            edge = min(x, y, int(zone["width"]) - 1 - x, int(zone["height"]) - 1 - y)
            if edge != 0:
                raise SystemExit(f"{zone['zone_id']} border at {(x, y)} ignores depth 1")
        groups: dict[str, list[tuple[int, int]]] = {}
        for prop in zone["props"]:
            prop_id = str(prop["id"])
            if "_cluster_" not in prop_id:
                continue
            parts = prop_id.split("_")
            key = parts[-2]
            origin = prop["origin"]
            groups.setdefault(key, []).append((int(origin["x"]), int(origin["y"])))
        for key, cells in groups.items():
            if len(cells) != 3:
                raise SystemExit(f"{zone['zone_id']} cluster {key} has {len(cells)} cells, file max is 3")
            for i, left in enumerate(cells):
                for right in cells[i + 1:]:
                    gap = max(abs(left[0] - right[0]), abs(left[1] - right[1]))
                    if gap < 3:
                        raise SystemExit(f"{zone['zone_id']} cluster spacing {gap} ignores the file")
    doc["cluster"]["spacing"] = 6
    path.write_text(json.dumps(doc, indent=2) + "\n")
    tight = run_builder(dest, region)
    if tight.returncode == 0:
        raise SystemExit("spacing 6 still placed an interior cluster; the file was not read")
    if "placed no interior cluster" not in (tight.stderr + tight.stdout):
        raise SystemExit(f"spacing probe failed for another reason\n{tight.stdout}\n{tight.stderr}")


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="region-builders-") as tmp:
        dest = Path(tmp)
        copy_tree(dest)
        check_seed(dest)
        for region in REGIONS:
            result = run_builder(dest, region)
            if result.returncode != 0:
                sys.stderr.write(result.stdout)
                sys.stderr.write(result.stderr)
                raise SystemExit(f"{region} builder exited {result.returncode}")
        check_dressed(dest)
        check_knobs(dest)
    print("region builders: ok")


if __name__ == "__main__":
    main()
