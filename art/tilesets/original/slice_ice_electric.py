#!/usr/bin/env python3
"""Slice the scenario ice sheet onto the Koliseo 64×32 grid.

Reads pending/ice and overwrites only Windmere (`wind_*`) terrain and
dress-prefixed props. Stormspire (`storm_*`) is sliced by
slice_storm_punch.py from the algo-así punch sheets in pending/electric/.
Slagcrown (`slag_*`) is sliced by slice_lava_punch.py. Crosshaven is
sliced by slice_crosshaven_punch.py. Brinewake stays on the coast punch.

Flat tiles fill a 64×32 diamond. Cliff tiles keep that top face and hang the
wall below it. Props use the same ground scale as the original slicer.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from slice_original_tileset import (
    ATLAS,
    FLAT,
    PROP,
    TILES,
    _components,
    _cut,
    _fit_flat,
    _fit_prop,
    _names,
    _sync_tsx,
)

HERE = Path(__file__).resolve().parent
ICE_SHEET = HERE / "pending" / "ice" / "stasium_tileset_ice.png"
ELEC_SHEET = HERE / "pending" / "electric" / "stasium_tileset_electric.png"
ICE_BG = np.array([254.0, 255.0, 255.0], np.float32)


def _defringe(crop: np.ndarray, bg: np.ndarray, lum_cut: float = 246.0) -> np.ndarray:
    src = crop.astype(np.float32)
    dist = np.linalg.norm(src - bg, axis=2)
    lum = src.mean(2)
    alpha = np.clip((dist - 10.0) / 16.0, 0.0, 1.0)
    alpha = np.where(lum > lum_cut, 0.0, alpha)
    safe = np.maximum(alpha, 0.2)[:, :, None]
    color = np.clip(bg + (src - bg) / safe, 0, 255)
    out = np.zeros((src.shape[0], src.shape[1], 4), np.uint8)
    out[:, :, :3] = color.astype(np.uint8)
    out[:, :, 3] = (alpha * 255.0).astype(np.uint8)
    out[out[:, :, 3] < 12] = 0
    return out


def _fit_cliff_sheet(rgba: np.ndarray, cap_frac: float = 0.48) -> Image.Image:
    """Top face becomes 64×32. The wall below that face hangs off the cell."""
    opaque = rgba[:, :, 3] > 24
    ys, xs = np.where(opaque)
    if len(xs) == 0:
        raise SystemExit("cliff crop has no pixels")
    body = rgba[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
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


def _ice_wall(arr: np.ndarray, box: tuple[int, int, int, int]) -> np.ndarray:
    """Snow-capped ice wall inside a rect, cut off the connected snow floor."""
    x, y, w, h = box
    sub = arr[y : y + h, x : x + w].astype(np.float32)
    lum = sub.mean(2)
    wall = (lum < 205) & (sub[:, :, 2] > sub[:, :, 0] + 8) & (lum > 40)
    wall = ndimage.binary_opening(wall, iterations=1)
    lab, _ = ndimage.label(wall)
    if lab.max() == 0:
        raise SystemExit(f"no ice wall in {box}")
    sizes = [(int((lab == i).sum()), i) for i in range(1, int(lab.max()) + 1)]
    sizes.sort(reverse=True)
    mask = lab == sizes[0][1]
    cap = np.zeros_like(mask)
    ys_w, xs_w = np.where(mask)
    top: dict[int, int] = {}
    for yy, xx in zip(ys_w, xs_w):
        if xx not in top or yy < top[xx]:
            top[xx] = int(yy)
    for xx, yy in top.items():
        for y2 in range(yy, max(0, yy - 70), -1):
            if lum[y2, xx] > 248:
                break
            cap[y2, xx] = True
    mask = ndimage.binary_dilation(ndimage.binary_closing(mask | cap, iterations=1), iterations=1)
    rgba = np.zeros((sub.shape[0], sub.shape[1], 4), np.uint8)
    rgba[:, :, :3] = np.clip(sub, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = (mask * 255).astype(np.uint8)
    yy, xx = np.where(mask)
    return rgba[yy.min() : yy.max() + 1, xx.min() : xx.max() + 1]


def _flat_keep(arr: np.ndarray, anchor: tuple[int, int], lum_cut: float = 249.0) -> Image.Image:
    """Crop one diamond and keep near-white snow. Only the sheet white is keyed."""
    x, y = anchor
    crop = arr[y : y + 120, x : x + 158]
    lum = crop.mean(2)
    alpha = np.where(lum > lum_cut, 0, 255).astype(np.uint8)
    return _fit_flat(np.dstack([crop, alpha]))


def _fill_interior(rgba: np.ndarray) -> np.ndarray:
    """Snow interiors are nearly the sheet white. Put that paint back inside the diamond."""
    solid = rgba[:, :, 3] > 40
    if not solid.any():
        return rgba
    holes = ndimage.binary_fill_holes(solid) & ~solid
    if not holes.any():
        return rgba
    _, nearest = ndimage.distance_transform_edt(~solid, return_indices=True)
    out = rgba.copy()
    out[holes] = rgba[nearest[0][holes], nearest[1][holes]]
    out[holes, 3] = 255
    return out


def _save(name: str, img: Image.Image, records: list) -> None:
    path = TILES / name
    img.save(path)
    records.append({"file": name, "size": [img.size[0], img.size[1]]})
    print(f"{name:28} {img.size[0]:3}x{img.size[1]:<3}")


def _patch_atlas(records: list) -> None:
    atlas = json.loads(ATLAS.read_text())
    atlas["source_sheets"] = [
        "original-tileset-a.jpg",
        "original-tileset-b.jpg",
        "pending/ice/stasium_tileset_ice.png",
        "pending/ice/punch/wind_ground_punch.png",
        "pending/ice/punch/wind_elevation_punch.png",
        "pending/ice/punch/wind_props_punch.png",
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
    families = atlas["families"]
    families["windmere"] = {"pack": "ice", "prefix": "wind_", "pending_theme": None}
    families["stormspire"] = {"pack": "electric", "prefix": "storm_", "pending_theme": None}
    atlas["pending"] = {}
    promoted = atlas.get("promoted") or {}
    punch = HERE / "pending" / "ice" / "punch" / "wind_ground_punch.png"
    promoted["ice"] = (
        "pending/ice/punch/wind_ground_punch.png"
        if punch.is_file()
        else "pending/ice/stasium_tileset_ice.png"
    )
    promoted["electric"] = "pending/electric/stasium_tileset_electric.png"
    atlas["promoted"] = promoted
    written = {item["file"] for item in records}
    kept = [item for item in atlas.get("files", []) if item.get("file") not in written]
    atlas["files"] = kept + records
    ATLAS.write_text(json.dumps(atlas, indent=2) + "\n")


def _slice_legacy_ice(ice: np.ndarray, ice_comps, records: list) -> None:
    ice_flats = {
        "ground": [(16, 129), (512, 251), (346, 250), (184, 130)],
        "mud": [(868, 132), (1192, 133), (1031, 390)],
        "water": [(866, 390), (700, 392), (1029, 132)],
    }
    for key, anchors in ice_flats.items():
        for name, anchor in zip(_names("wind_", key, len(anchors)), anchors):
            if key == "ground":
                img = _flat_keep(ice, anchor)
            else:
                img = _fit_flat(_fill_interior(_cut(ice, ice_comps, anchor[0], anchor[1])))
            _save(name, img, records)

    ice_cliffs = {
        "ground_e1": ((0, 610, 190, 220), 0.48),
        "ground_e1_v1": ((200, 600, 200, 240), 0.48),
        "mud_e1": ((200, 600, 200, 240), 0.48),
        "ground_e2": ((1588, 1000, 220, 340), 0.34),
    }
    for key, (box, cap) in ice_cliffs.items():
        if key == "ground_e2":
            sprite = _ice_wall(ice, box)
        else:
            x, y, w, h = box
            sprite = _defringe(ice[y : y + h, x : x + w], ICE_BG)
        _save(f"wind_{key}.png", _fit_cliff_sheet(sprite, cap), records)

    ice_props = {
        "wind_prop_crystal.png": (PROP, (1657, 1753)),
        "wind_prop_ice_shard.png": (PROP, (1765, 1795)),
        "wind_prop_spark.png": (PROP, (1902, 1811)),
        "wind_prop_rock_pillar.png": (PROP, (1521, 1765)),
        "wind_prop_rubble.png": (PROP, (1370, 1495)),
        "wind_prop_ice_sheet.png": (FLAT, (16, 129)),
        "wind_prop_floor_seal.png": (FLAT, (1883, 127)),
    }
    for name, (kind, anchor) in ice_props.items():
        cut = _cut(ice, ice_comps, anchor[0], anchor[1])
        if kind == FLAT:
            img = _flat_keep(ice, anchor)
        else:
            img = _fit_prop(cut)
        _save(name, img, records)


def main() -> None:
    # Stormspire paint is the algo-así punch sheets. slice_storm_punch.py
    # owns storm_*.png. This slicer must not restore those older slices.
    records: list = []
    punch_ground = HERE / "pending" / "ice" / "punch" / "wind_ground_punch.png"
    if punch_ground.is_file():
        from slice_windmere_punch import slice_windmere

        records.extend(slice_windmere())
    else:
        if not ICE_SHEET.is_file():
            raise SystemExit("missing ice sheet under pending/")
        ice = np.asarray(Image.open(ICE_SHEET).convert("RGB"))
        _slice_legacy_ice(ice, _components(ice), records)

    _sync_tsx()
    _patch_atlas(records)
    print(f"promoted {len(records)} ice slices")


if __name__ == "__main__":
    main()
