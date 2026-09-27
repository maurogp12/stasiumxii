#!/usr/bin/env python3
"""Slice the Brinewake coast punch onto the Koliseo 64×32 grid.

Reads pending/brinewake contact sheets and overwrites only Brinewake
(`brine_*` terrain and `brine_prop_*`). Crosshaven, Slagcrown, Windmere,
and Stormspire stay on their own sheets.

Soft Lock is agua + costa: wet sand, pier wood, and tide scorch. Foam
stays on the diamond seam. Tide crust is a few dark marks on the face.
The green carpet on the punch sheet is not painted onto the diamonds.

Elevation is the regenerated sheet with the upper-corner wooden deck
removed. A cliff keeps the 64×32 deck cap and hangs the wooden stair
under it. The stair ends on the lower deck in that same sprite. A tread
that continues past the deck is cut. Props are the sparse dock pieces
on the props sheet, scaled to about one tile. Tags and geometry are
not this script's job.
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
# Rows 2–3 of the punch are the green carpet. They stay off these slots.
_FLATS = {
    "ground": [(0, 0), (1, 5), (0, 2)],  # wet sand with crust, not the green rows
    "mud": [(0, 4), (0, 5)],  # tide scorch
    "water": [(4, 1), (4, 2)],  # agua, the less-green water
}

# (x0, y0, x1, y1, total height, darken). Measured on elevation v2
# (1280×720, upper-corner deck removed): wooden treads and a wide
# landing. The tall crop starts higher so the high step hangs farther
# and still lands. The old sheet that still had that deck is not used.
_STAIR_DECKS = {
    "ground_e1": (520, 300, 700, 540, 58, 1.0),
    "ground_e2": (500, 240, 720, 560, 86, 1.0),
    "mud_e1": (520, 300, 700, 540, 56, 0.74),
}

# (x, y, w, h, max_w, max_h). Solid pier-wood patches on the props sheet.
# Scaled to about one tile so the arena stays sparse.
_PROPS = {
    "rock_pillar": (472, 1272, 22, 72, 16, 40),
    "ruins": (408, 1320, 40, 40, 28, 28),
    "driftwood": (600, 584, 70, 22, 44, 16),
    "fence": (888, 728, 70, 22, 44, 14),
    "rubble": (360, 1336, 48, 30, 34, 20),
    "rock_cluster": (1416, 1560, 48, 30, 36, 22),
    "waterfall": (1464, 616, 22, 72, 14, 40),
}
# A mark on the deck. A full diamond would replace the floor.
_SEAL_SIZE = (26, 14)


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
    foam = (lum > 165.0) & (sat < 42.0)
    # Only a bright wash comes off the inner face. Dark tide crust stays.
    veil = (lum > 176.0) & (sat < 48.0) & ~warm
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


def _is_grass(rgb: np.ndarray) -> np.ndarray:
    return (rgb[:, :, 1] > rgb[:, :, 0] + 10.0) & (rgb[:, :, 1] > rgb[:, :, 2] + 6.0)


def _crust_mask(rgba: np.ndarray) -> np.ndarray:
    """Small dark marks on the face. Not the green carpet and not one big shadow."""
    rgb = rgba[:, :, :3].astype(np.float32)
    alpha = rgba[:, :, 3] > 40
    lum = rgb.mean(axis=2)
    blur = ndimage.gaussian_filter(lum, 3.0)
    raw = alpha & (lum + 36.0 < blur) & ~_is_grass(rgb) & (lum > 18.0) & (lum < 145.0)
    labeled, count = ndimage.label(raw)
    keep = np.zeros(raw.shape, dtype=bool)
    for i in range(1, count + 1):
        comp = labeled == i
        area = int(comp.sum())
        if 6 <= area <= 110:
            keep |= comp
    return keep


def _stamp_crust(body: np.ndarray, out: np.ndarray) -> np.ndarray:
    """Keep tide crust as a few marks. A downscale must not turn it into a carpet."""
    mask = _crust_mask(body)
    if not mask.any():
        return out
    src_h, src_w = mask.shape
    out_h, out_w = out.shape[:2]
    y_edges = np.linspace(0, src_h, out_h + 1).astype(int)
    x_edges = np.linspace(0, src_w, out_w + 1).astype(int)
    strength = np.zeros((out_h, out_w), np.float32)
    pooled = np.zeros((out_h, out_w), dtype=bool)
    for y in range(out_h):
        for x in range(out_w):
            block = mask[y_edges[y] : y_edges[y + 1], x_edges[x] : x_edges[x + 1]]
            if block.any():
                pooled[y, x] = True
                strength[y, x] = float(block.mean())
    metric = _metric(out_h, out_w)
    candidates = np.argwhere(pooled & (metric <= 0.96) & (out[:, :, 3] > 40))
    if len(candidates) > 28:
        scores = strength[candidates[:, 0], candidates[:, 1]]
        candidates = candidates[np.argsort(scores)[::-1][:28]]
    if len(candidates) == 0:
        return out
    color = np.median(body[:, :, :3][mask].astype(np.float32), axis=0)
    color = np.clip(color * 0.7, 32, 96)
    if color[1] > color[0]:
        color[1] = color[0] * 0.8
    result = out.copy()
    for y, x in candidates:
        base = result[y, x, :3].astype(np.float32)
        result[y, x, :3] = np.clip(base * 0.28 + color * 0.72, 0, 255).astype(np.uint8)
        result[y, x, 3] = 255
    return result


def _reads_as_water(arr: np.ndarray) -> bool:
    rgb = arr[:, :, :3].astype(np.float32)
    opaque = arr[:, :, 3] > 40
    if not opaque.any():
        return False
    med = np.median(rgb[opaque], axis=0)
    return bool(med[1] > med[0] + 4.0 or med[2] > med[0] + 4.0)


def _kill_grass(arr: np.ndarray) -> np.ndarray:
    """Green carpet pixels become the neighboring sand or water."""
    rgb = arr[:, :, :3].astype(np.float32)
    alpha = arr[:, :, 3]
    grass = (alpha > 40) & _is_grass(rgb)
    if not grass.any():
        return arr
    keep = (alpha > 40) & ~grass
    if not keep.any():
        return arr
    _, nearest = ndimage.distance_transform_edt(~keep, return_indices=True)
    out = arr.copy()
    out[grass, :3] = arr[nearest[0][grass], nearest[1][grass], :3]
    return out


def _as_diamond(rgba: np.ndarray) -> Image.Image:
    body = _trim(rgba)
    metric = _metric(*body.shape[:2])
    body = body.copy()
    body[metric > 1.02, 3] = 0
    body = _strip_interior_haze(body, metric)
    body = _kill_grass(body)
    spr = Image.fromarray(body).resize((64, 32), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    metric = _metric(32, 64)
    arr[metric > 1.02, 3] = 0
    arr = _strip_interior_haze(arr, metric)
    # Agua stays water. Crust accents belong on the sand and the scorch.
    if not _reads_as_water(body):
        arr = _stamp_crust(body, arr)
    arr = _kill_grass(arr)
    if _reads_as_water(arr):
        arr = _strip_water_wash(arr, _metric(32, 64))
    arr[arr[:, :, 3] < 8] = 0
    return Image.fromarray(arr)


def _strip_water_wash(arr: np.ndarray, metric: np.ndarray) -> np.ndarray:
    """Gray wash on the water face becomes the neighboring teal. Seams stay."""
    out = arr.copy()
    for _ in range(4):
        rgb = out[:, :, :3].astype(np.float32)
        lum = rgb.mean(axis=2) / 255.0
        sat = (rgb.max(axis=2) - rgb.min(axis=2)) / 255.0
        warm = (rgb[:, :, 0] > rgb[:, :, 1] + 15.3) & (rgb[:, :, 0] > rgb[:, :, 2] + 28.0)
        teal = (rgb[:, :, 1] > rgb[:, :, 0] + 12.8) | (rgb[:, :, 2] > rgb[:, :, 0] + 12.8)
        foam = (lum > 0.65) & (sat < 0.16)
        gray = (sat < 0.14) & (lum > 0.25) & ~warm & ~teal
        clear = (out[:, :, 3] > 38) & (metric < 0.78) & (foam | gray)
        if not clear.any():
            break
        keep = (out[:, :, 3] > 38) & ~clear
        if not keep.any():
            break
        _, nearest = ndimage.distance_transform_edt(~keep, return_indices=True)
        out[clear, :3] = out[nearest[0][clear], nearest[1][clear], :3]
    return out


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
    body = _kill_grass(_trim(rgba))
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


def _iso_mask(width: int = 64, height: int = 32) -> np.ndarray:
    yy, xx = np.mgrid[0:height, 0:width]
    cx = (width - 1) / 2.0
    cy = (height - 1) / 2.0
    return (np.abs(xx - cx) / (cx + 1.25) + np.abs(yy - cy) / (cy + 1.25)) <= 1.0


def _wood_rgba(rgb: np.ndarray) -> np.ndarray:
    """Pier wood stays. Ocean, sky, and the green carpet go transparent."""
    src = rgb[:, :, :3].astype(np.float32) if rgb.shape[2] == 4 else rgb.astype(np.float32)
    red, green, blue = src[:, :, 0], src[:, :, 1], src[:, :, 2]
    lum = src.mean(2)
    wood = (red > green + 2.0) & (red > blue + 6.0) & (lum > 52.0) & (lum < 230.0)
    wood = ndimage.binary_opening(wood, iterations=1)
    wood = ndimage.binary_closing(wood, structure=np.ones((2, 3), bool), iterations=1)
    out = np.zeros((src.shape[0], src.shape[1], 4), np.uint8)
    out[:, :, :3] = np.clip(src, 0, 255).astype(np.uint8)
    out[:, :, 3] = np.where(wood, 255, 0).astype(np.uint8)
    return out


def _fit_stair_deck(rgb: np.ndarray, box: tuple[int, int, int, int], target_h: int, darken: float) -> Image.Image:
    """Upper deck becomes the 64×32 cap. Treads hang and stop on the lower deck."""
    x0, y0, x1, y1 = box
    crop = _wood_rgba(rgb[y0:y1, x0:x1])
    solid = crop[:, :, 3] > 20
    ys, xs = np.where(solid)
    if len(xs) == 0:
        raise SystemExit(f"stair crop {box} has no wood")
    crop = crop[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    widths = (crop[:, :, 3] > 20).sum(1)
    wide = np.where(widths >= max(24, int(crop.shape[1] * 0.45)))[0]
    if len(wide) == 0:
        raise SystemExit(f"stair crop {box} has no deck to land on")
    bands: list[tuple[int, int]] = []
    start = int(wide[0])
    prev = int(wide[0])
    for y in wide[1:]:
        if int(y) <= prev + 4:
            prev = int(y)
        else:
            bands.append((start, prev))
            start = int(y)
            prev = int(y)
    bands.append((start, prev))
    land0, land1 = bands[-1]
    top_rows = np.where(widths >= max(18, int(crop.shape[1] * 0.22)))[0]
    top_rows = top_rows[top_rows < land0 - 8]
    if len(top_rows) == 0:
        raise SystemExit(f"stair crop {box} has no upper deck")
    cap_end = int(top_rows[0])
    limit = int(top_rows[0] + crop.shape[0] * 0.24)
    for y in top_rows:
        if int(y) > limit:
            break
        cap_end = int(y)
    cap = crop[: cap_end + 1]
    stair = crop[max(0, cap_end - 4) : land1 + 1]
    cap_img = Image.fromarray(cap).resize((64, 32), Image.Resampling.LANCZOS)
    cap_arr = np.asarray(cap_img).copy()
    mask = _iso_mask()
    filled = cap_arr[:, :, 3] > 30
    holes = mask & ~filled
    if filled.any() and holes.any():
        _, nearest = ndimage.distance_transform_edt(~filled, return_indices=True)
        cap_arr[holes] = cap_arr[nearest[0][holes], nearest[1][holes]]
    cap_arr[:, :, 3] = np.where(mask, 255, 0).astype(np.uint8)
    edge = mask & ~ndimage.binary_erosion(mask, iterations=1)
    rgb_cap = cap_arr[:, :, :3].astype(np.float32)
    rgb_cap[edge] *= 0.5
    cap_arr[:, :, :3] = np.clip(rgb_cap * darken, 0, 255).astype(np.uint8)
    hang = target_h - 32
    stair_img = Image.fromarray(stair).resize((64, hang), Image.Resampling.LANCZOS)
    stair_arr = np.asarray(stair_img).copy()
    stair_arr[:, :, :3] = np.clip(stair_arr[:, :, :3].astype(np.float32) * darken, 0, 255).astype(np.uint8)
    stair_arr[stair_arr[:, :, 3] < 16] = 0
    out = np.zeros((32 + stair_arr.shape[0], 64, 4), np.uint8)
    out[:32] = cap_arr
    out[32:] = stair_arr
    meet = (out[31, :, 3] > 40) & (out[32, :, 3] > 40)
    if int(meet.sum()) < 4:
        tip = out[31, :, 3] > 40
        out[32, tip, :3] = out[31, tip, :3]
        out[32, tip, 3] = 255
    out = _trim_below_deck(out)
    out[out[:, :, 3] < 12] = 0
    _assert_lands(out, box)
    return Image.fromarray(out)


def _trim_below_deck(arr: np.ndarray) -> np.ndarray:
    """The foot of the sprite is the landing deck. Treads past that deck go."""
    widths = (arr[:, :, 3] > 40).sum(1)
    wide = np.where(widths >= 28)[0]
    wide = wide[wide >= 32]
    if len(wide) == 0:
        return arr
    foot = int(wide.max())
    trimmed = arr[: foot + 1].copy()
    trimmed[foot + 1 :] = 0
    return trimmed


def _assert_lands(arr: np.ndarray, box: tuple) -> None:
    if arr.shape[1] != 64 or arr.shape[0] <= 36:
        raise SystemExit(f"stair {box} fit is {arr.shape[1]}x{arr.shape[0]}")
    meet = int(((arr[31, :, 3] > 40) & (arr[32, :, 3] > 40)).sum())
    if meet < 3:
        raise SystemExit(f"stair {box} leaves the cap")
    rows = np.where((arr[:, :, 3] > 40).any(1))[0]
    foot_w = int((arr[int(rows.max()), :, 3] > 40).sum())
    if foot_w < 18:
        raise SystemExit(f"stair {box} does not land on a deck ({foot_w}px)")
    center = arr[16, 32]
    if int(center[3]) < 200 or int(center[0]) + 8 < int(center[2]):
        raise SystemExit(f"stair cap is not pier wood {center.tolist()}")


def _prop_object(sheet: np.ndarray, box: tuple[int, int, int, int, int, int]) -> Image.Image:
    """One pier-wood patch, rimmed, then scaled to about one tile."""
    x, y, w, h, max_w, max_h = box
    src = sheet[:, :, :3] if sheet.shape[2] == 4 else sheet
    crop = src[y : y + h, x : x + w].astype(np.float32)
    red, green, blue = crop[:, :, 0], crop[:, :, 1], crop[:, :, 2]
    lum = crop.mean(2)
    wood = (red > blue + 8.0) & (lum > 70.0) & (red > 80.0)
    if float(wood.mean()) < 0.7:
        raise SystemExit(f"prop crop {box[:4]} is not pier wood")
    wood = ndimage.binary_closing(wood, iterations=2)
    wood = ndimage.binary_fill_holes(wood)
    rgba = np.zeros((crop.shape[0], crop.shape[1], 4), np.uint8)
    rgba[:, :, :3] = np.clip(crop, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.where(wood, 255, 0).astype(np.uint8)
    edge = wood & ~ndimage.binary_erosion(wood, iterations=1, border_value=0)
    rgb = rgba[:, :, :3].astype(np.float32)
    rgb[edge] *= 0.42
    rgba[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    img = _scale_prop(rgba, max_w, max_h)
    if img.size[0] > 48 or img.size[1] > 48:
        raise SystemExit(f"prop {box[:4]} is {img.size}, not one tile")
    return img


def _floor_seal(sheet: np.ndarray) -> Image.Image:
    """Small deck mark. It sits on the diamond; it does not replace it."""
    src = sheet[:, :, :3] if sheet.shape[2] == 4 else sheet
    patch = src[400:470, 470:560].astype(np.float32)
    red, green, blue = patch[:, :, 0], patch[:, :, 1], patch[:, :, 2]
    warm = (red > 140.0) & (red > blue + 20.0) & (red > green - 10.0)
    if int(warm.sum()) < 40:
        raise SystemExit("floor seal patch is not deck wood")
    color = np.median(patch[warm], axis=0)
    spr = Image.fromarray(np.clip(patch, 0, 255).astype(np.uint8)).resize(_SEAL_SIZE, Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    rgba = np.zeros((arr.shape[0], arr.shape[1], 4), np.uint8)
    rgba[:, :, :3] = arr
    mask = _iso_mask(arr.shape[1], arr.shape[0])
    rgba[:, :, 3] = np.where(mask, 255, 0).astype(np.uint8)
    # Pull a pale crop back toward the deck so the mark stays wood.
    if float(np.median(rgba[:, :, 0][mask])) < 90:
        rgba[:, :, :3][mask] = np.clip(color, 0, 255).astype(np.uint8)
    if rgba.shape[0] >= 32 or rgba.shape[1] >= 48:
        raise SystemExit("floor seal covers the diamond")
    return Image.fromarray(rgba)


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

    stairs = {}
    for key, (x0, y0, x1, y1, target_h, darken) in _STAIR_DECKS.items():
        img = _fit_stair_deck(elev, (x0, y0, x1, y1), target_h, darken)
        stairs[key] = img
        _save(f"brine_{key}.png", img, records)
        print(f"  brine_{key}.png: {_qa(img)} h={img.size[1]}")
    if stairs["ground_e2"].size[1] <= stairs["ground_e1"].size[1]:
        raise SystemExit("ground_e2 is not taller than ground_e1")

    for prop, box in _PROPS.items():
        img = _prop_object(props, box)
        _save(f"brine_prop_{prop}.png", img, records)

    _save("brine_prop_floor_seal.png", _floor_seal(props), records)

    _sync_tsx()
    _patch_atlas(records)
    _write_board_preview()
    print(f"sliced {len(records)} brinewake punch tiles")


def _write_board_preview() -> None:
    """The painted preview is the same diamonds the board draws."""
    import json as _json

    tags_path = TILES.parent / "brinewake_15x15_tags.json"
    preview_path = TILES.parent / "brinewake_15x15_painted_preview.png"
    if not tags_path.is_file():
        return
    tags = _json.loads(tags_path.read_text())
    board = Image.new("RGB", (1280, 720), (14, 28, 32))
    ox, oy = 620, 78

    def variant(stem: str) -> list[Path]:
        names = []
        primary = TILES / f"{stem}.png"
        if primary.is_file():
            names.append(primary)
        i = 1
        while (TILES / f"{stem}_v{i}.png").is_file():
            names.append(TILES / f"{stem}_v{i}.png")
            i += 1
        return names

    cache: dict[Path, Image.Image] = {}

    def load(path: Path) -> Image.Image:
        if path not in cache:
            cache[path] = Image.open(path).convert("RGBA")
        return cache[path]

    def terrain_file(terrain: str, elev: int, cell: tuple[int, int]) -> Image.Image | None:
        z = elev
        while z >= 0:
            stem = f"brine_{terrain}" if z == 0 else f"brine_{terrain}_e{z}"
            files = variant(stem)
            if files:
                pick = (cell[0] * 13 + cell[1] * 29 + elev * 7) % len(files)
                return load(files[pick])
            z -= 1
        return None

    cells = sorted(tags["cells"], key=lambda c: (c["x"] + c["y"]) * 10 + int(c["elevation"]) * 8)
    for cell in cells:
        tex = terrain_file(cell["terrain"], int(cell["elevation"]), (cell["x"], cell["y"]))
        if tex is None:
            continue
        px = ox + (cell["x"] - cell["y"]) * 32
        py = oy + (cell["x"] + cell["y"]) * 16 - int(cell["elevation"]) * 10
        board.paste(tex, (px - 32, py - 16), tex)
        for prop in cell.get("paint_only") or []:
            prop_path = TILES / f"brine_prop_{prop}.png"
            if not prop_path.is_file():
                prop_path = TILES / f"prop_{prop}.png"
            if not prop_path.is_file():
                continue
            sprite = load(prop_path)
            board.paste(sprite, (px - sprite.size[0] // 2, py + 16 - sprite.size[1]), sprite)
    board.save(preview_path)
    print(f"preview {preview_path.name} {board.size[0]}x{board.size[1]}")


if __name__ == "__main__":
    main()
