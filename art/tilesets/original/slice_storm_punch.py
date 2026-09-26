#!/usr/bin/env python3
"""Slice the Stormspire algo-así punch sheets onto the Koliseo 64×32 grid.

Reads the three punch contact sheets in pending/electric/ and overwrites only
Stormspire presentation files (`storm_*` terrain and `storm_prop_*`).

Locked map geometry, tags, and cell layout are not touched. Crosshaven,
Brinewake, Slagcrown, and Windmere files are not written.

Flat tiles fill a 64×32 diamond. Cliff tiles keep that top face and hang the
wall below it. Props use the ground-diamond scale (64px per punch diamond).
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from slice_original_tileset import ATLAS, TILES, _names, _sync_tsx

HERE = Path(__file__).resolve().parent
PUNCH = HERE / "pending" / "electric"
GROUND_SHEET = PUNCH / "storm_ground_punch.png"
ELEV_SHEET = PUNCH / "storm_elevation_punch.png"
PROPS_SHEET = PUNCH / "storm_props_punch.png"

# Punch diamonds are about 149px wide. Board diamonds are 64px.
PROP_SCALE = 64.0 / 149.0

# Component index after sorting sprites top-to-bottom, left-to-right.
# Ground indices are dark stone. Mud is cyan-veined stone. Water is violet.
GROUND_INDEX = {
    "ground": [0, 11, 17, 26],
    "mud": [8, 2, 25],
    "water": [16, 5],
}
FLOOR_SEAL_INDEX = 12
# Elevation indices. e2 is a taller cliff than e1.
ELEV_INDEX = {
    "ground_e1": 4,
    "ground_e1_v1": 0,
    "mud_e1": 7,
    "ground_e2": 3,
}
# Prop sprites, nearest top-left on storm_props_punch.png.
PROP_ANCHORS = {
    "storm_prop_rock_pillar.png": (43, 7),
    "storm_prop_crystal_bolt.png": (713, 14),
    "storm_prop_arc.png": (977, 35),
    "storm_prop_conduit.png": (215, 224),
    "storm_prop_rubble.png": (555, 254),
    "storm_prop_spark.png": (404, 472),
}
SPARK_MAX = 72
PROP_MAX = 128


def _key_black(im: Image.Image) -> np.ndarray:
    """Punch grounds and cliffs are painted on opaque black. Key that plate out."""
    arr = np.asarray(im.convert("RGBA")).copy()
    rgb = arr[:, :, :3].astype(np.float32)
    lum = rgb.mean(2)
    chroma = rgb.max(2) - rgb.min(2)
    alpha = np.clip(np.maximum(lum - 3.0, chroma - 4.0) / 12.0, 0.0, 1.0)
    arr[:, :, 3] = (alpha * 255.0).astype(np.uint8)
    arr[arr[:, :, 3] < 8] = 0
    return arr


def _sprites(arr: np.ndarray, min_area: int) -> list[tuple[int, int, int, int]]:
    mask = arr[:, :, 3] > 24
    lab, count = ndimage.label(mask)
    boxes: list[tuple[int, int, int, int]] = []
    for i in range(1, count + 1):
        ys, xs = np.where(lab == i)
        if len(xs) < min_area:
            continue
        boxes.append((int(ys.min()), int(xs.min()), int(ys.max()) + 1, int(xs.max()) + 1))
    boxes.sort(key=lambda box: (box[0], box[1]))
    return boxes


def _fit_flat(crop: np.ndarray) -> Image.Image:
    solid = crop[:, :, 3] > 12
    ys, xs = np.where(solid)
    if len(xs) == 0:
        raise SystemExit("flat crop has no pixels")
    body = crop[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    spr = Image.fromarray(body).resize((64, 32), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    arr[arr[:, :, 3] < 8] = 0
    return Image.fromarray(arr)


def _fit_cliff(crop: np.ndarray, cap_frac: float = 0.42) -> Image.Image:
    """Top face becomes 64×32. The wall below that face hangs off the cell."""
    opaque = crop[:, :, 3] > 24
    ys, xs = np.where(opaque)
    if len(xs) == 0:
        raise SystemExit("cliff crop has no pixels")
    body = crop[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    solid = body[:, :, 3] > 40
    height, width = solid.shape
    widths = solid.sum(1)
    top_n = max(8, int(height * 0.55))
    top_w = widths[:top_n]
    maxw = max(int(top_w.max()), 1)
    equator = int(np.argmax(top_w >= max(1, int(maxw * 0.90))))
    face_h = max(equator * 2, 8)
    if face_h > height * 0.62:
        face_h = max(8, int(height * cap_frac))
    cols = np.where(solid[min(max(equator, 1), height - 1)])[0]
    face_w = int(cols.max() - cols.min() + 1) if len(cols) else width
    face_w = max(face_w, 8)
    scale_x = 64.0 / face_w
    scale_y = 32.0 / face_h
    out_w = max(64, int(round(body.shape[1] * scale_x)))
    out_h = max(33, int(round(body.shape[0] * scale_y)))
    spr = Image.fromarray(body).resize((out_w, out_h), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    arr[arr[:, :, 3] < 8] = 0
    cap = arr[: min(32, arr.shape[0]), :, 3] > 40
    if cap.any():
        span = np.where(cap.any(0))[0]
        shift = int(round(32 - (int(span.min()) + int(span.max())) / 2.0))
        moved = np.zeros_like(arr)
        if shift >= 0:
            moved[:, shift:] = arr[:, : arr.shape[1] - shift]
        else:
            moved[:, : arr.shape[1] + shift] = arr[:, -shift:]
        arr = moved
    if arr.shape[1] < 64:
        pad = np.zeros((arr.shape[0], 64, 4), np.uint8)
        pad[:, : arr.shape[1]] = arr
        arr = pad
    elif arr.shape[1] > 64:
        arr = arr[:, :64]
    return Image.fromarray(arr)


def _fit_prop(crop: np.ndarray, max_side: int) -> Image.Image:
    solid = crop[:, :, 3] > 16
    ys, xs = np.where(solid)
    if len(xs) == 0:
        raise SystemExit("prop crop has no pixels")
    body = crop[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    w = max(8, int(round(body.shape[1] * PROP_SCALE)))
    h = max(8, int(round(body.shape[0] * PROP_SCALE)))
    longest = max(w, h)
    if longest > max_side:
        scale = max_side / float(longest)
        w = max(8, int(round(w * scale)))
        h = max(8, int(round(h * scale)))
    spr = Image.fromarray(body).resize((w, h), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    arr[arr[:, :, 3] < 8] = 0
    return Image.fromarray(arr)


def _nearest_box(boxes: list[tuple[int, int, int, int]], anchor: tuple[int, int]) -> tuple[int, int, int, int]:
    ax, ay = anchor
    best = None
    bestd = 1e18
    for box in boxes:
        y0, x0, _, _ = box
        dist = (x0 - ax) ** 2 + (y0 - ay) ** 2
        if dist < bestd:
            bestd = dist
            best = box
    if best is None or bestd > 40 * 40:
        raise SystemExit(f"no prop near {anchor}; closest dist^2={bestd}")
    return best


def _save(name: str, img: Image.Image, records: list, fit: str) -> None:
    path = TILES / name
    img.save(path)
    records.append({"file": name, "fit": fit, "size": [img.size[0], img.size[1]]})
    print(f"{name:28} {img.size[0]:3}x{img.size[1]:<3}")


def _patch_atlas(records: list) -> None:
    atlas = json.loads(ATLAS.read_text())
    by_file = {item["file"]: item for item in records}
    for entry in atlas.get("files", []):
        fresh = by_file.get(entry.get("file"))
        if fresh is None:
            continue
        entry["size"] = fresh["size"]
        entry["fit"] = fresh["fit"]
    known = {entry.get("file") for entry in atlas.get("files", [])}
    for fresh in records:
        if fresh["file"] not in known:
            atlas["files"].append({"file": fresh["file"], "fit": fresh["fit"], "size": fresh["size"]})
    sheets = list(atlas.get("source_sheets", []))
    for rel in (
        "pending/electric/storm_ground_punch.png",
        "pending/electric/storm_elevation_punch.png",
        "pending/electric/storm_props_punch.png",
    ):
        if rel not in sheets:
            sheets.append(rel)
    atlas["source_sheets"] = sheets
    atlas["stormspire_punch"] = {
        "ground": "pending/electric/storm_ground_punch.png",
        "elevation": "pending/electric/storm_elevation_punch.png",
        "props": "pending/electric/storm_props_punch.png",
        "note": "Live Stormspire paint. Geometry and tags stay on the Locked maps.",
    }
    family = atlas["families"]["stormspire"]
    family["pack"] = "electric"
    family["prefix"] = "storm_"
    family["pending_theme"] = None
    ATLAS.write_text(json.dumps(atlas, indent=2) + "\n")


def _check(records: list) -> None:
    by_file = {item["file"]: item for item in records}
    ground = np.asarray(Image.open(TILES / "storm_ground.png"))
    water = np.asarray(Image.open(TILES / "storm_water.png"))
    e1 = Image.open(TILES / "storm_ground_e1.png")
    e2 = Image.open(TILES / "storm_ground_e2.png")
    gr, gg, gb = [int(v) for v in ground[16, 32, :3]]
    wr, wg, wb = [int(v) for v in water[16, 32, :3]]
    if not (gr < 102 and gb < 115):
        raise SystemExit(f"storm ground center is not dark stone: {(gr, gg, gb)}")
    if gg > gb and gg > 64:
        raise SystemExit(f"storm ground center reads green: {(gr, gg, gb)}")
    if not (wb > wr and wb > wg):
        raise SystemExit(f"storm water center is not violet/cyan energy: {(wr, wg, wb)}")
    if e1.size[1] <= 32:
        raise SystemExit(f"storm e1 does not hang: {e1.size}")
    if e2.size[1] <= e1.size[1]:
        raise SystemExit(f"storm e2 is not taller than e1: {e2.size} vs {e1.size}")
    if ground.shape[1] != 64 or ground[0, 0, 3] != 0 or ground[16, 48, 3] < 200:
        raise SystemExit("storm ground is not a full 64-wide diamond")
    spark = Image.open(TILES / "storm_prop_spark.png")
    if spark.mode != "RGBA" or max(spark.size) > SPARK_MAX:
        raise SystemExit(f"spark prop is not a small RGBA accent: {spark.size} {spark.mode}")
    written = {item["file"] for item in records}
    if any(not name.startswith("storm_") for name in written):
        raise SystemExit(f"slicer wrote a non-storm file: {sorted(written)}")
    expect = 4 + 3 + 2 + 4 + 6 + 1
    if len(records) != expect:
        raise SystemExit(f"expected {expect} storm files, wrote {len(records)}")
    print(
        f"check ground RGB {gr, gg, gb} water RGB {wr, wg, wb} "
        f"e1 {e1.size[1]} e2 {e2.size[1]} files {len(by_file)}"
    )


def main() -> None:
    for path in (GROUND_SHEET, ELEV_SHEET, PROPS_SHEET):
        if not path.is_file():
            raise SystemExit(f"missing punch sheet {path}")
    ground = _key_black(Image.open(GROUND_SHEET))
    elev = _key_black(Image.open(ELEV_SHEET))
    props = np.asarray(Image.open(PROPS_SHEET).convert("RGBA"))
    ground_boxes = _sprites(ground, 800)
    elev_boxes = _sprites(elev, 400)
    prop_boxes = _sprites(props, 800)
    if len(ground_boxes) != 31:
        raise SystemExit(f"expected 31 ground diamonds, found {len(ground_boxes)}")
    if len(elev_boxes) != 17:
        raise SystemExit(f"expected 17 elevation sprites, found {len(elev_boxes)}")
    if len(prop_boxes) != 11:
        raise SystemExit(f"expected 11 prop sprites, found {len(prop_boxes)}")

    records: list = []
    for key, indexes in GROUND_INDEX.items():
        for name, index in zip(_names("storm_", key, len(indexes)), indexes):
            y0, x0, y1, x1 = ground_boxes[index]
            _save(name, _fit_flat(ground[y0:y1, x0:x1]), records, "flat")
    y0, x0, y1, x1 = ground_boxes[FLOOR_SEAL_INDEX]
    _save("storm_prop_floor_seal.png", _fit_flat(ground[y0:y1, x0:x1]), records, "flat")

    for key, index in ELEV_INDEX.items():
        y0, x0, y1, x1 = elev_boxes[index]
        _save(f"storm_{key}.png", _fit_cliff(elev[y0:y1, x0:x1]), records, "cliff")

    for name, anchor in PROP_ANCHORS.items():
        y0, x0, y1, x1 = _nearest_box(prop_boxes, anchor)
        cap = SPARK_MAX if name.endswith("spark.png") else PROP_MAX
        _save(name, _fit_prop(props[y0:y1, x0:x1], cap), records, "prop")

    _sync_tsx()
    _patch_atlas(records)
    _check(records)
    print(f"sliced {len(records)} stormspire punch tiles")


if __name__ == "__main__":
    main()
