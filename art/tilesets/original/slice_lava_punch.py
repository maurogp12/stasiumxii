#!/usr/bin/env python3
"""Slice the Scenario lava punch sheets onto Slagcrown.

Reads pending/lava and overwrites only slag_* terrain and slag_prop_* props.
Locked tags, geometry, and the other four arenas stay put.

Flat tiles fill a 64×32 diamond. Cliffs keep that top face and hang the wall
below it, with the north tip on x=32. Props keep their punch alpha and are
scaled up enough to read on a phone. The mood sheet is reference only.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

from slice_original_tileset import ATLAS, TILES, _names, _sync_tsx

HERE = Path(__file__).resolve().parent
LAVA = HERE / "pending" / "lava"
GROUND = LAVA / "ground_punch.png"
ELEVATION = LAVA / "elevation_punch.png"
PROPS = LAVA / "props_punch.png"

# Punch sheets sit on this dark brown, not white.
BG = np.array([36.0, 28.0, 24.0], np.float32)

# ground_punch.png. Lava is three rows, then three dirt rows. Pitch (140, 80).
# Bottom bars under the dirt are palette strips and are not tiles.
_LAVA_Y = (36, 116, 196)
_DIRT_Y = (276, 356, 436)


def _cell(col: int, row: int, kind: str) -> tuple[int, int, int, int]:
    y = (_LAVA_Y if kind == "lava" else _DIRT_Y)[row]
    return (17 + col * 140, y, 132, 72)


def _key(crop: np.ndarray) -> np.ndarray:
    src = crop.astype(np.float32)
    dist = np.linalg.norm(src - BG, axis=2)
    alpha = np.clip((dist - 22.0) / 12.0, 0.0, 1.0)
    safe = np.maximum(alpha, 0.22)[:, :, None]
    color = np.clip(BG + (src - BG) / safe, 0, 255)
    out = np.zeros((src.shape[0], src.shape[1], 4), np.uint8)
    out[:, :, :3] = color.astype(np.uint8)
    out[:, :, 3] = (alpha * 255.0).astype(np.uint8)
    out[out[:, :, 3] < 10] = 0
    return out


def _fit_flat(rgba: np.ndarray) -> np.ndarray:
    opaque = rgba[:, :, 3] > 16
    ys, xs = np.where(opaque)
    if len(xs) == 0:
        raise SystemExit("flat crop has no pixels")
    crop = rgba[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    spr = Image.fromarray(crop).resize((64, 32), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    arr[arr[:, :, 3] < 8] = 0
    return arr


def _fit_cliff(rgba: np.ndarray) -> np.ndarray:
    opaque = rgba[:, :, 3] > 24
    ys, xs = np.where(opaque)
    if len(xs) == 0:
        raise SystemExit("cliff crop has no pixels")
    body = rgba[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    solid = body[:, :, 3] > 40
    height = solid.shape[0]
    widths = solid.sum(1)
    top_n = max(8, int(height * 0.75))
    top_w = widths[:top_n]
    maxw = max(int(top_w.max()), 1)
    equator = int(np.argmax(top_w >= max(1, int(maxw * 0.90))))
    face_h = max(equator * 2, 8)
    if face_h > height * 0.85:
        face_h = max(8, int(height * 0.55))
    cols = np.where(solid[min(equator, height - 1)])[0]
    face_w = int(cols.max() - cols.min() + 1) if len(cols) else body.shape[1]
    face_w = max(face_w, 8)
    scale_x = 64.0 / face_w
    scale_y = 32.0 / face_h
    out_w = max(64, int(round(body.shape[1] * scale_x)))
    out_h = max(33, int(round(body.shape[0] * scale_y)))
    spr = Image.fromarray(body).resize((out_w, out_h), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    arr[arr[:, :, 3] < 8] = 0
    solid_o = arr[:, :, 3] > 40
    top_rows = np.where(solid_o.any(1))[0]
    if len(top_rows) == 0:
        raise SystemExit("cliff fit lost its cap")
    tip_xs = np.where(solid_o[int(top_rows[0])])[0]
    tip = (int(tip_xs.min()) + int(tip_xs.max())) / 2.0
    shift = int(round(32 - tip))
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
    return arr


def _fit_prop(rgba: np.ndarray, target_h: int) -> np.ndarray:
    opaque = rgba[:, :, 3] > 16
    ys, xs = np.where(opaque)
    if len(xs) == 0:
        raise SystemExit("prop crop has no pixels")
    crop = rgba[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    scale = float(target_h) / float(crop.shape[0])
    out_w = max(8, int(round(crop.shape[1] * scale)))
    spr = Image.fromarray(crop).resize((out_w, target_h), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    arr[arr[:, :, 3] < 8] = 0
    return arr


def _green_fraction(arr: np.ndarray) -> float:
    """Same test as tests/run_koliseo_maps_tests.gd, in float so lava cannot wrap."""
    px = arr.astype(np.float32)
    alpha = px[:, :, 3] / 255.0
    red = px[:, :, 0] / 255.0
    green = px[:, :, 1] / 255.0
    blue = px[:, :, 2] / 255.0
    solid = alpha >= 0.15
    veg = solid & (green > red + 0.07) & (green > blue + 0.05) & (green > 0.23)
    return float(veg.sum()) / float(max(int(solid.sum()), 1))


def _require_clean(name: str, arr: np.ndarray, kind: str) -> None:
    frac = _green_fraction(arr)
    if frac > 0.005:
        raise SystemExit(f"{name} still has lawn/moss ({frac:.3f})")
    if kind == "flat":
        solid = int((arr[:, :, 3] > 200).sum())
        if solid < 700:
            raise SystemExit(f"{name} diamond is hollow ({solid} opaque)")
        px = arr[16, 32].astype(np.int16)
        if int(px[3]) < 200 or int(px[0]) <= int(px[2]):
            raise SystemExit(f"{name} center is not opaque rock/lava {px.tolist()}")
    if kind == "cliff":
        cap = arr[4, 32].astype(np.int16)
        if int(cap[3]) < 200 or int(cap[0]) <= int(cap[1]) or int(cap[0]) <= int(cap[2]):
            raise SystemExit(f"{name} cap is not scorched rock {cap.tolist()}")


def _save(name: str, arr: np.ndarray, records: list, anchor, kind: str) -> None:
    _require_clean(name, arr, kind)
    img = Image.fromarray(arr)
    img.save(TILES / name)
    records.append(
        {
            "file": name,
            "anchor": list(anchor) if anchor is not None else None,
            "fit": kind,
            "size": [img.size[0], img.size[1]],
            "source": "pending/lava",
        }
    )
    print(f"{name:32} {img.size[0]:3}x{img.size[1]:<3}")


def _patch_atlas(records: list) -> None:
    atlas = json.loads(ATLAS.read_text())
    atlas["source_sheets"] = [
        "original-tileset-a.jpg",
        "original-tileset-b.jpg",
        "pending/ice/stasium_tileset_ice.png",
        "pending/electric/stasium_tileset_electric.png",
        "pending/electric/storm_ground_punch.png",
        "pending/electric/storm_elevation_punch.png",
        "pending/electric/storm_props_punch.png",
        "crosshaven_ground_punch.png",
        "crosshaven_elevation_punch.png",
        "crosshaven_props_punch.png",
        "pending/lava/ground_punch.png",
        "pending/lava/elevation_punch.png",
        "pending/lava/props_punch.png",
    ]
    promoted = atlas.get("promoted") or {}
    promoted["lava"] = "pending/lava/"
    atlas["promoted"] = promoted
    written = {item["file"] for item in records}
    kept = [item for item in atlas.get("files", []) if item.get("file") not in written]
    atlas["files"] = kept + records
    ATLAS.write_text(json.dumps(atlas, indent=2) + "\n")


def main() -> None:
    for path in (GROUND, ELEVATION, PROPS):
        if not path.is_file():
            raise SystemExit(f"missing punch sheet {path}")
    ground = np.asarray(Image.open(GROUND).convert("RGB"))
    elev = np.asarray(Image.open(ELEVATION).convert("RGB"))
    props = np.asarray(Image.open(PROPS).convert("RGBA"))
    records: list = []

    def flat_from(sheet: np.ndarray, box: tuple[int, int, int, int]) -> np.ndarray:
        x, y, w, h = box
        return _fit_flat(_key(sheet[y : y + h, x : x + w]))

    # Solid dirt only. The soft diamond at column 3 is skipped.
    # Primary is the readable mid scorch. Darkest solid diamond is the pool.
    dirt = {
        "ground": [(1, 0), (6, 0), (4, 0), (5, 0), (2, 0)],
        "mud": [(2, 0)],
        "water": [(0, 0)],
    }
    for key, cells in dirt.items():
        boxes = [_cell(col, row, "dirt") for col, row in cells]
        for name, box in zip(_names("slag_", key, len(boxes)), boxes):
            _save(name, flat_from(ground, box), records, box[:2], "flat")

    # High-contrast full diamonds. Hollow and faint lava cells are left on the sheet.
    lava_cells = [
        (6, 0),
        (0, 1),
        (8, 0),
        (4, 2),
        (4, 1),
        (0, 2),
        (5, 0),
        (7, 2),
    ]
    lava_boxes = [_cell(col, row, "lava") for col, row in lava_cells]
    for name, box in zip(_names("slag_", "lava", len(lava_boxes)), lava_boxes):
        _save(name, flat_from(ground, box), records, box[:2], "flat")

    # Measured content runs on elevation_punch.png. Row 0 is the clean ledge row.
    # e1 is the short lava-veined cliff. e2 is the taller scorched wall.
    cliffs = {
        "ground_e1": (6, 40, 131),
        "ground_e1_v1": (4, 40, 139),
        "ground_e2": (0, 188, 315),
        "mud_e1": (5, 40, 151),
    }
    for key, (col, y0, y1) in cliffs.items():
        x = 30 + col * 152
        crop = elev[y0 : y1 + 1, x : x + 128]
        _save(f"slag_{key}.png", _fit_cliff(_key(crop)), records, [x, y0], "cliff")

    # Center-tile cluster only (y < 200). Bottom-edge scraps are trims, not props.
    # Heights stay in the same range as the other dress props so a phone overview
    # still reads the rock without covering the diamond under it.
    prop_specs = {
        "slag_prop_basalt_pillar.png": ((245, 44, 41, 78), 104),
        "slag_prop_ash_rock.png": ((345, 59, 47, 68), 76),
        "slag_prop_rubble.png": ((445, 67, 47, 55), 60),
        "slag_prop_rock_pillar.png": ((559, 39, 31, 78), 104),
        "slag_prop_steam_vent.png": ((1045, 63, 47, 59), 56),
    }
    for name, (box, target_h) in prop_specs.items():
        x, y, w, h = box
        _save(name, _fit_prop(props[y : y + h, x : x + w], target_h), records, [x, y], "prop")

    # Seals sit on dirt cells. A dark ash diamond reads as a brand, not a lava cell
    # and not the forest stone seal.
    seal_box = _cell(7, 0, "dirt")
    _save(
        "slag_prop_floor_seal.png",
        flat_from(ground, seal_box),
        records,
        seal_box[:2],
        "flat",
    )

    _sync_tsx()
    _patch_atlas(records)
    print(f"sliced {len(records)} slagcrown lava/rock/dirt files")


if __name__ == "__main__":
    main()
