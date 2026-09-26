#!/usr/bin/env python3
"""Slice the Brinewake coast punch onto the Koliseo 64×32 grid.

Reads pending/brinewake contact sheets and overwrites only Brinewake
(`brine_*` terrain and `brine_prop_*`). Crosshaven, Slagcrown, Windmere,
and Stormspire stay on their own sheets.

Soft Lock is agua + costa: wet sand, pier wood, and tide scorch. Foam
stays on the diamond seam. Pale haze over the face is filled back with
the tile color. Tags and geometry are not this script's job.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from slice_original_tileset import ATLAS, TILES, _sync_tsx

HERE = Path(__file__).resolve().parent
PUNCH = HERE / "pending" / "brinewake"
GROUND_SHEET = PUNCH / "brine_ground_punch.png"
ELEV_SHEET = PUNCH / "brine_elevation_punch.png"
PROPS_SHEET = PUNCH / "brine_props_punch.png"

# Measured gutters on brine_ground_punch.png. Each cell is one diamond.
_BANDS = [(16, 138), (148, 271), (281, 405), (415, 541), (554, 678)]
_COLS = [
    (26, 200),
    (203, 376),
    (379, 551),
    (553, 726),
    (728, 901),
    (903, 1077),
    (1079, 1254),
]

# (row, col) on the ground sheet. Primary file is the first cell.
_FLATS = {
    "ground": [(0, 0), (1, 1), (0, 3)],  # wet sand, wet sand, pier wood
    "mud": [(0, 4), (0, 5)],  # tide scorch
    "water": [(4, 3), (4, 1)],  # agua
}

# (x, y, w, h, total height). The top face stays 64×32. e2 hangs lower.
_CLIFFS = {
    "ground_e1": (667, 94, 185, 130, 68),
    "ground_e2": (481, 23, 182, 206, 96),
    "mud_e1": (356, 280, 188, 140, 70),
}

# (x, y, w, h, max_w, max_h) on brine_props_punch.png.
_PROPS = {
    "driftwood": (57, 248, 171, 141, 86, 52),
    "rock_cluster": (704, 58, 162, 156, 74, 66),
    "rock_pillar": (1058, 438, 170, 257, 46, 88),
    "rubble": (481, 475, 170, 187, 80, 70),
    "ruins": (306, 71, 161, 144, 64, 80),
    "fence": (51, 416, 194, 79, 78, 48),
    "waterfall": (1063, 8, 164, 240, 72, 116),
}


def _key_black(rgb: np.ndarray) -> np.ndarray:
    """Black sheet background goes transparent. Dark paint inside the sprite stays."""
    src = rgb[:, :, :3].astype(np.float32) if rgb.shape[2] == 4 else rgb.astype(np.float32)
    lum = src.max(axis=2)
    raw = lum > 12
    filled = ndimage.binary_fill_holes(ndimage.binary_closing(raw, iterations=1))
    alpha = np.zeros(lum.shape, np.float32)
    alpha[filled] = 1.0
    fringe = (lum > 6) & ~filled
    alpha[fringe] = np.clip((lum[fringe] - 6.0) / 10.0, 0.0, 1.0)
    out = np.zeros((src.shape[0], src.shape[1], 4), np.uint8)
    out[:, :, :3] = np.clip(src, 0, 255).astype(np.uint8)
    out[:, :, 3] = (alpha * 255.0).astype(np.uint8)
    out[out[:, :, 3] < 8] = 0
    return out


def _trim(rgba: np.ndarray) -> np.ndarray:
    ys, xs = np.where(rgba[:, :, 3] > 16)
    if len(xs) == 0:
        raise SystemExit("sprite has no pixels")
    return rgba[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]


def _metric(h: int, w: int) -> np.ndarray:
    yy, xx = np.mgrid[0:h, 0:w]
    cx = (w - 1) / 2.0
    cy = (h - 1) / 2.0
    return np.abs(xx - cx) / (w / 2.0) + np.abs(yy - cy) / (h / 2.0)


def _strip_interior_haze(rgba: np.ndarray, metric: np.ndarray, edge: float = 0.78) -> np.ndarray:
    """Keep pale foam on the outer seam. Fill wash inside the face.

    White foam on the rim stays. A gray or cream veil over the middle of
    the diamond is filled from the nearest real tile color.
    """
    rgb = rgba[:, :, :3].astype(np.float32)
    alpha = rgba[:, :, 3]
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    warm = (rgb[:, :, 0] > rgb[:, :, 1] + 16.0) & (rgb[:, :, 0] > rgb[:, :, 2] + 28.0)
    teal = (rgb[:, :, 1] > rgb[:, :, 0] + 12.0) | (rgb[:, :, 2] > rgb[:, :, 0] + 12.0)
    foam = (lum > 165.0) & (sat < 42.0)
    # Gray wash is not sand and not water. It only comes off the inner face.
    veil = (sat < 36.0) & (lum > 64.0) & ~warm & ~teal
    interior = (alpha > 40) & (metric < edge) & (foam | veil)
    if not interior.any():
        return rgba
    keep = (alpha > 40) & ~interior
    if not keep.any():
        return rgba
    _, nearest = ndimage.distance_transform_edt(~keep, return_indices=True)
    out = rgba.copy()
    out[interior, :3] = rgba[nearest[0][interior], nearest[1][interior], :3]
    out[interior, 3] = 255
    return out


def _as_diamond(rgba: np.ndarray) -> Image.Image:
    body = _trim(rgba)
    metric = _metric(*body.shape[:2])
    body = body.copy()
    body[metric > 1.02, 3] = 0
    body = _strip_interior_haze(body, metric)
    spr = Image.fromarray(body).resize((64, 32), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    metric = _metric(32, 64)
    arr[metric > 1.02, 3] = 0
    arr = _strip_interior_haze(arr, metric)
    arr[arr[:, :, 3] < 8] = 0
    return Image.fromarray(arr)


def _flat_cell(sheet: np.ndarray, row: int, col: int) -> Image.Image:
    y0, y1 = _BANDS[row]
    x0, x1 = _COLS[col]
    return _as_diamond(_key_black(sheet[y0 : y1 + 1, x0 : x1 + 1]))


def _cap_span(alpha: np.ndarray) -> tuple[int, int]:
    """Top diamond: from the north tip to twice the first width plateau."""
    widths = alpha.sum(axis=1)
    rows = np.where(widths > 0)[0]
    if len(rows) == 0:
        raise SystemExit("cliff has no pixels")
    top = int(rows[0])
    search_end = min(len(widths), top + 52)
    equator = None
    for y in range(top, search_end):
        width = int(widths[y])
        if width < 24:
            continue
        ahead = widths[y : min(len(widths), y + 8)]
        if int(ahead.max()) <= width * 1.12:
            equator = y
            break
    if equator is None:
        window = widths[top:search_end]
        equator = top + int(np.argmax(window))
    face_h = max(12, (equator - top) * 2)
    face_end = min(top + face_h, alpha.shape[0])
    return top, face_end


def _cliff(sheet: np.ndarray, box: tuple[int, int, int, int], target_h: int) -> Image.Image:
    x, y, w, h = box
    sprite = _trim(_key_black(sheet[y : y + h, x : x + w]))
    alpha = sprite[:, :, 3] > 20
    top, face_end = _cap_span(alpha)
    face_band = alpha[top:face_end]
    xs = np.where(face_band.any(axis=0))[0]
    face = _as_diamond(sprite[top:face_end, xs.min() : xs.max() + 1])
    hang = target_h - 32
    wall_src = sprite[face_end:]
    wall_alpha = wall_src[:, :, 3] > 16 if wall_src.size else np.zeros((0, 0), bool)
    if wall_src.shape[0] < 2 or not wall_alpha.any():
        wall = Image.new("RGBA", (64, hang), (0, 0, 0, 0))
    else:
        ys, xs = np.where(wall_alpha)
        wall_crop = wall_src[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
        wall = Image.fromarray(wall_crop).resize((64, hang), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (64, target_h), (0, 0, 0, 0))
    out.paste(face, (0, 0), face)
    out.paste(wall, (0, 32), wall)
    arr = np.asarray(out).copy()
    arr[arr[:, :, 3] < 8] = 0
    return Image.fromarray(arr)


def _scale_prop(rgba: np.ndarray, max_w: int, max_h: int) -> Image.Image:
    body = _trim(rgba)
    h, w = body.shape[:2]
    scale = min(max_w / max(w, 1), max_h / max(h, 1))
    out_w = max(8, int(round(w * scale)))
    out_h = max(8, int(round(h * scale)))
    spr = Image.fromarray(body).resize((out_w, out_h), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    arr[arr[:, :, 3] < 8] = 0
    return Image.fromarray(arr)


def _names(key: str, count: int) -> list[str]:
    names = [f"brine_{key}.png"]
    for i in range(1, count):
        names.append(f"brine_{key}_v{i}.png")
    return names


def _save(name: str, img: Image.Image, records: list) -> None:
    path = TILES / name
    img.save(path)
    records.append(
        {
            "file": name,
            "fit": "punch",
            "size": [img.size[0], img.size[1]],
            "source": "pending/brinewake/",
        }
    )
    print(f"{name:28} {img.size[0]:3}x{img.size[1]:<3}")


def _patch_atlas(records: list) -> None:
    atlas = json.loads(ATLAS.read_text())
    sheets = list(atlas.get("source_sheets", []))
    for sheet in (
        "pending/brinewake/brine_ground_punch.png",
        "pending/brinewake/brine_elevation_punch.png",
        "pending/brinewake/brine_props_punch.png",
    ):
        if sheet not in sheets:
            sheets.append(sheet)
    atlas["source_sheets"] = sheets
    families = atlas.setdefault("families", {})
    families["brinewake"] = {"pack": "coast", "prefix": "brine_", "pending_theme": None}
    promoted = atlas.setdefault("promoted", {})
    promoted["brinewake"] = "pending/brinewake/brine_ground_punch.png"
    written = {item["file"] for item in records}
    kept = [item for item in atlas.get("files", []) if item.get("file") not in written]
    atlas["files"] = kept + records
    ATLAS.write_text(json.dumps(atlas, indent=2) + "\n")


def _qa(img: Image.Image) -> str:
    arr = np.asarray(img)
    face_h = min(32, arr.shape[0])
    face = arr[:face_h]
    metric = _metric(face_h, face.shape[1])
    alpha = face[:, :, 3] > 40
    rgb = face[:, :, :3].astype(np.float32)
    lum = rgb.mean(2)
    sat = rgb.max(2) - rgb.min(2)
    pale = alpha & (lum > 168.0) & (sat < 40.0)
    interior = pale & (metric < 0.78)
    opaque = max(int(alpha.sum()), 1)
    return f"pale {int(pale.sum()):3d} interior {int(interior.sum()):3d} ({100.0 * interior.sum() / opaque:.2f}%)"


def main() -> None:
    for path in (GROUND_SHEET, ELEV_SHEET, PROPS_SHEET):
        if not path.is_file():
            raise SystemExit(f"missing punch sheet {path}")
    ground = np.asarray(Image.open(GROUND_SHEET).convert("RGB"))
    elev = np.asarray(Image.open(ELEV_SHEET).convert("RGB"))
    props = np.asarray(Image.open(PROPS_SHEET).convert("RGBA"))
    records: list = []

    for key, cells in _FLATS.items():
        for name, (row, col) in zip(_names(key, len(cells)), cells):
            img = _flat_cell(ground, row, col)
            _save(name, img, records)
            print(f"  {name}: {_qa(img)}")

    for key, (x, y, w, h, target_h) in _CLIFFS.items():
        img = _cliff(elev, (x, y, w, h), target_h)
        _save(f"brine_{key}.png", img, records)
        print(f"  brine_{key}.png: {_qa(img)} h={img.size[1]}")

    for prop, (x, y, w, h, max_w, max_h) in _PROPS.items():
        crop = props[y : y + h, x : x + w]
        img = _scale_prop(crop, max_w, max_h)
        _save(f"brine_prop_{prop}.png", img, records)

    seal = _flat_cell(ground, 0, 3)
    _save("brine_prop_floor_seal.png", seal, records)

    _sync_tsx()
    _patch_atlas(records)
    print(f"sliced {len(records)} brinewake punch tiles")


if __name__ == "__main__":
    main()
