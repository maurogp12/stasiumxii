#!/usr/bin/env python3
"""Slice the Stormspire presentation punch onto the electric dress.

Soft lock: electric and wind. Presentation only.
Reads the punch sheets in pending/electric/ and overwrites storm_* terrain
and storm_prop_* files. Locked map geometry, tags, and cell layout are not
opened for writing. Other arenas are not written.

ground_punch.png is the same bytes as storm_ground_punch.png (elevation and
props the same way). board_mood_punch.png and luca_preview_stormspire.png are
the look reference and are not sliced.

Flat tiles are hard 64×32 diamonds with a dark rim so neighboring cells keep
a readable seam. Cliffs keep that cap and hang a wall; the high platform is
taller than the low one. Props come from the 1280×720 props_small_v2 sheet. The 2048 monolith in
pending/electric/archive/ is not sliced. Each standing prop is centered in
its sprite and about one diamond tall, so the floor stays visible and line of
sight stays open. The playable preview draws six of them and leaves the
tagged ring undrawn. No circular arena and no totem ring are painted.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

from slice_original_tileset import ATLAS, TILES, _sync_tsx

HERE = Path(__file__).resolve().parent
PUNCH = HERE / "pending" / "electric"
GROUND_SHEET = PUNCH / "storm_ground_punch.png"
ELEV_SHEET = PUNCH / "storm_elevation_punch.png"
PROPS_SHEET = PUNCH / "storm_props_punch.png"
MOOD_SHEET = PUNCH / "board_mood_punch.png"
MIRROR = HERE.parents[2] / "stasium-ref" / "maps" / "stormspire"
ROOT = TILES.parent
TAGS = ROOT / "stormspire_15x15_tags.json"
TMX = ROOT / "stormspire_15x15.tmx"

# Source window, before the 64×32 fit. Two-to-one, like the board diamond.
WIN_W = 176
WIN_H = 88
WIN_STEP = 44

# Cliff hang below the 32px cap. Elevation 2 is a taller platform than elevation 1.
HANG = {
    "storm_ground_e1.png": 40,
    "storm_ground_e1_v1.png": 44,
    "storm_mud_e1.png": 40,
    "storm_ground_e2.png": 68,
}

# Standing accents, about one 32px diamond tall. Wider than this covers the floor.
PROP_BOX = {
    "storm_prop_spark.png": (22, 28),
    "storm_prop_rubble.png": (28, 18),
    "storm_prop_arc.png": (28, 20),
    "storm_prop_crystal_bolt.png": (18, 32),
    "storm_prop_conduit.png": (16, 32),
    "storm_prop_rock_pillar.png": (16, 32),
}

# Same six cells as KoliseoArt.STORM_DRESS. Tags stay; the ring is not drawn.
# (14, 0) is the spark. (14, 14) is another bolt and is left off the board.
STORM_DRESS = {
    (0, 0): frozenset({"crystal_bolt"}),
    (14, 0): frozenset({"spark"}),
    (6, 3): frozenset({"rubble"}),
    (3, 5): frozenset({"rock_pillar"}),
    (10, 6): frozenset({"arc"}),
    (7, 7): frozenset({"floor_seal"}),
}


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _iso_mask(width: int = 64, height: int = 32) -> np.ndarray:
    """Hard isometric diamond. Tips are inside; the four corners are outside."""
    yy, xx = np.mgrid[0:height, 0:width]
    cx = (width - 1) / 2.0
    cy = (height - 1) / 2.0
    nx = np.abs(xx - cx) / (cx + 1.25)
    ny = np.abs(yy - cy) / (cy + 1.25)
    return (nx + ny) <= 1.0


def _rim(arr: np.ndarray, mask: np.ndarray) -> None:
    """Dark seam, with a thin gold north edge so the diamond border reads."""
    edge = mask & ~ndimage.binary_erosion(mask, iterations=1)
    if not edge.any():
        return
    rgb = arr[:, :, :3].astype(np.float32)
    rgb[edge] *= 0.42
    north = edge.copy()
    north[16:] = False
    if north.any():
        gold = np.array([168.0, 132.0, 64.0], np.float32)
        rgb[north] = rgb[north] * 0.35 + gold * 0.65
    arr[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)


def _solid_diamond(arr: np.ndarray) -> np.ndarray:
    mask = _iso_mask(arr.shape[1], 32)
    cap = arr[:32]
    solid = cap[:, :, 3] > 16
    holes = mask & ~solid
    if holes.any() and solid.any():
        _, nearest = ndimage.distance_transform_edt(~solid, return_indices=True)
        cap[holes] = cap[nearest[0][holes], nearest[1][holes]]
    cap[:, :, 3] = np.where(mask, 255, 0).astype(np.uint8)
    _rim(cap, mask)
    arr[:32] = cap
    return arr


def _window_stats(crop: np.ndarray) -> dict | None:
    r = crop[:, :, 0].astype(np.int16)
    g = crop[:, :, 1].astype(np.int16)
    b = crop[:, :, 2].astype(np.int16)
    lum = crop.astype(np.float32).mean(2)
    content = lum > 28
    if float(content.mean()) < 0.72:
        return None
    chroma = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
    violet = content & (b > g + 8) & (b > r) & (b > 48)
    cyan = content & (b > r + 10) & (g > r + 4) & (b > 36) & ~violet
    gold = content & (r > b + 16) & (g > b + 4) & (r > 80)
    body = lum[content]
    return {
        "violet": float(violet.mean()),
        "cyan": float(cyan.mean()),
        "gold": float(gold.mean()),
        "stone": float((content & (chroma < 24)).mean()),
        "contrast": float(body.std()) if body.size else 0.0,
        "mean": float(body.mean()) if body.size else 0.0,
        "median": float(np.median(body)) if body.size else 0.0,
        "bright": float((lum > 120).mean()),
        "dark": float((lum < 50).mean()),
    }


def _collect_windows(sheet: np.ndarray) -> list[dict]:
    height, width = sheet.shape[:2]
    found = []
    for y in range(12, height - WIN_H - 12, WIN_STEP):
        for x in range(12, width - WIN_W - 12, WIN_STEP):
            crop = sheet[y : y + WIN_H, x : x + WIN_W]
            stats = _window_stats(crop)
            if stats is None or stats["contrast"] < 8:
                continue
            stats["crop"] = crop
            stats["at"] = (x, y)
            found.append(stats)
    if len(found) < 12:
        raise SystemExit(f"need floor windows on the ground punch, found {len(found)}")
    return found


def _spread(cands: list[dict], count: int, min_dist: float) -> list[dict]:
    chosen: list[dict] = []
    seen: set[int] = set()
    for item in cands:
        x, y = item["at"]
        if all((x - c["at"][0]) ** 2 + (y - c["at"][1]) ** 2 >= min_dist ** 2 for c in chosen):
            chosen.append(item)
            seen.add(id(item))
        if len(chosen) == count:
            return chosen
    # Relax spacing rather than repeat one tile across the board.
    for item in cands:
        if id(item) in seen:
            continue
        chosen.append(item)
        seen.add(id(item))
        if len(chosen) == count:
            break
    if len(chosen) < count:
        raise SystemExit(f"need {count} floor samples, found {len(chosen)}")
    return chosen


def _grade(crop: np.ndarray, kind: str) -> np.ndarray:
    """Dark charcoal with the punch's own cracks stretched so the diamond reads."""
    rgb = crop.astype(np.float32)
    lum = rgb.mean(2)
    flat = lum[lum > 12]
    if flat.size < 16:
        flat = lum.reshape(-1)
    p10, p90 = np.percentile(flat, [12, 88])
    span = max(float(p90 - p10), 12.0)
    t = np.clip((lum - p10) / span, 0.0, 1.0)
    # Wide enough that a crack and the stone face are not the same gray.
    stone = 20.0 + t * 50.0
    out = np.zeros_like(rgb)
    out[:, :, 0] = stone * 0.90
    out[:, :, 1] = stone * 0.94
    out[:, :, 2] = stone * 1.05
    chroma = rgb.max(2) - rgb.min(2)
    colored = chroma > 22
    cracks = t < 0.38
    if colored.any():
        peak = np.maximum(rgb.max(2), 1.0)
        hue = rgb / peak[:, :, None]
        seam = 110.0 + t * 80.0
        out[colored] = (hue * seam[:, :, None])[colored]
    if kind == "water":
        # Dark violet stone, brighter violet in the cracks. Not a flat fill.
        out[:, :, 0] = np.where(cracks, 70.0 + t * 20.0, stone * 0.55 + 18.0)
        out[:, :, 1] = np.where(cracks, 36.0 + t * 16.0, stone * 0.32 + 10.0)
        out[:, :, 2] = np.where(cracks, 150.0 + t * 40.0, stone * 0.70 + 48.0)
    elif kind == "mud":
        vein = (t < 0.55) | colored
        out[:, :, 1] = np.where(vein, np.maximum(out[:, :, 1], 82.0), out[:, :, 1])
        out[:, :, 2] = np.where(vein, np.maximum(out[:, :, 2], 118.0), out[:, :, 2])
    return np.clip(out, 0, 255).astype(np.uint8)


def _fit_floor(crop: np.ndarray, kind: str) -> Image.Image:
    graded = _grade(crop, kind)
    rgba = np.zeros((graded.shape[0], graded.shape[1], 4), np.uint8)
    rgba[:, :, :3] = graded
    rgba[:, :, 3] = 255
    spr = Image.fromarray(rgba).resize((64, 32), Image.Resampling.LANCZOS)
    arr = _solid_diamond(np.asarray(spr).copy())
    if kind == "ground":
        r, g, b = (int(v) for v in arr[16, 32, :3])
        if r >= 102 or g >= 89 or b >= 115 or g > r + 8:
            # Center landed on a bright seam. Pull that pixel back to stone.
            arr[16, 32, 0] = 42
            arr[16, 32, 1] = 44
            arr[16, 32, 2] = 52
    if kind == "water":
        r, g, b = (int(v) for v in arr[16, 32, :3])
        if not (b > r and b > g):
            arr[16, 32, 0] = min(r, 70)
            arr[16, 32, 1] = min(g, 60)
            arr[16, 32, 2] = max(b, 130)
    return Image.fromarray(arr)


def _slice_ground(sheet: np.ndarray) -> tuple[list[dict], dict[str, Image.Image]]:
    windows = _collect_windows(sheet)
    water_pool = [w for w in windows if w["violet"] > 0.10 and w["violet"] >= w["cyan"]]
    water_pool.sort(key=lambda w: -w["violet"])
    if len(water_pool) < 2:
        water_pool = sorted(windows, key=lambda w: -w["violet"])
    mud_pool = [w for w in windows if w["cyan"] > 0.05 and w["violet"] < 0.16]
    mud_pool.sort(key=lambda w: -w["cyan"])
    if len(mud_pool) < 3:
        mud_pool = sorted(windows, key=lambda w: -(w["cyan"] - w["violet"]))
    # Mostly the lit stone face, with enough dark crack to read. A half-shadow
    # window downscales into a flat dark diamond.
    ground_pool = [
        w
        for w in windows
        if w["bright"] > 0.68
        and 0.04 < w["dark"] < 0.22
        and w["violet"] < 0.08
        and w["cyan"] < 0.08
    ]
    ground_pool.sort(key=lambda w: -(w["bright"] - w["dark"]))
    if len(ground_pool) < 4:
        ground_pool = sorted(
            [w for w in windows if w["bright"] > 0.50 and w["violet"] < 0.12 and w["cyan"] < 0.12],
            key=lambda w: -w["bright"],
        )
    picks = {
        "storm_ground.png": ("ground", _spread(ground_pool, 4, 320)[0]),
        "storm_ground_v1.png": ("ground", _spread(ground_pool, 4, 320)[1]),
        "storm_ground_v2.png": ("ground", _spread(ground_pool, 4, 320)[2]),
        "storm_ground_v3.png": ("ground", _spread(ground_pool, 4, 320)[3]),
        "storm_mud.png": ("mud", _spread(mud_pool, 3, 280)[0]),
        "storm_mud_v1.png": ("mud", _spread(mud_pool, 3, 280)[1]),
        "storm_mud_v2.png": ("mud", _spread(mud_pool, 3, 280)[2]),
        "storm_water.png": ("water", _spread(water_pool, 2, 280)[0]),
        "storm_water_v1.png": ("water", _spread(water_pool, 2, 280)[1]),
    }
    # Floor seal is a stone diamond with a small violet mark, not a second water tile.
    seal_src = _spread(ground_pool, 4, 320)[0]
    images: dict[str, Image.Image] = {}
    records = []
    for name, (kind, item) in picks.items():
        img = _fit_floor(item["crop"], kind)
        img.save(TILES / name)
        images[name] = img
        records.append({"file": name, "fit": "flat", "size": [64, 32]})
        print(f"{name:28} 64x32  {kind:6} at {item['at']}")
    seal = _fit_floor(seal_src["crop"], "ground")
    seal_arr = np.asarray(seal).copy()
    mark = _iso_mask()
    yy, xx = np.mgrid[0:32, 0:64]
    inner = (np.abs(xx - 31.5) / 10.0 + np.abs(yy - 15.5) / 5.0) <= 1.0
    seal_arr[inner & mark, 0] = 92
    seal_arr[inner & mark, 1] = 48
    seal_arr[inner & mark, 2] = 168
    seal_img = Image.fromarray(seal_arr)
    seal_img.save(TILES / "storm_prop_floor_seal.png")
    images["storm_prop_floor_seal.png"] = seal_img
    records.append({"file": "storm_prop_floor_seal.png", "fit": "flat", "size": [64, 32]})
    print("storm_prop_floor_seal.png      64x32  seal")
    images["_caps"] = {
        "ground": images["storm_ground.png"],
        "ground_v1": images["storm_ground_v1.png"],
        "mud": images["storm_mud.png"],
    }
    _assert_floors(images)
    return records, images


def _assert_floors(images: dict) -> None:
    mask = _iso_mask()
    for name in ("storm_ground.png", "storm_water.png", "storm_mud.png"):
        img = np.asarray(images[name])
        if img.shape[1] != 64 or img.shape[0] != 32:
            raise SystemExit(f"{name} is not 64×32")
        for x, y in ((32, 0), (63, 16), (32, 31), (0, 16)):
            if img[y, x, 3] < 200:
                raise SystemExit(f"{name} tip {(x, y)} is open")
        for x, y in ((0, 0), (63, 0), (0, 31), (63, 31)):
            if img[y, x, 3] > 8:
                raise SystemExit(f"{name} corner {(x, y)} is filled")
        if not np.array_equal(img[:, :, 3] > 200, mask):
            raise SystemExit(f"{name} coverage is not the hard diamond")
    ground = np.asarray(images["storm_ground.png"])
    gr, gg, gb = (int(v) for v in ground[16, 32, :3])
    if not (gr < 102 and gg < 89 and gb < 115 and gg <= gr + 8):
        raise SystemExit(f"storm ground center is not dark stone: {(gr, gg, gb)}")
    water = np.asarray(images["storm_water.png"])
    wr, wg, wb = (int(v) for v in water[16, 32, :3])
    if not (wb > wr and wb > wg):
        raise SystemExit(f"storm water center is not violet energy: {(wr, wg, wb)}")


def _wall_samples(sheet: np.ndarray, count: int) -> list[np.ndarray]:
    lum = sheet.mean(2)
    content = lum > 32
    height, width = content.shape
    samples = []
    # Vertical strips of real platform face, spaced across the sheet.
    for x in range(80, width - 80, max(40, (width - 160) // 24)):
        col = content[:, x - 20 : x + 20].mean(1)
        if col.mean() < 0.25:
            continue
        run = col > 0.45
        best = None
        start = None
        for y, on in enumerate(run):
            if on and start is None:
                start = y
            if not on and start is not None:
                if y - start > 70 and (best is None or y - start > best[1] - best[0]):
                    best = (start, y)
                start = None
        if start is not None and height - start > 70:
            if best is None or height - start > best[1] - best[0]:
                best = (start, height)
        if best is None:
            continue
        y0, y1 = best
        y0 = min(y0 + 8, y1 - 48)
        crop = sheet[y0:y1, x - 24 : x + 24]
        if crop.shape[0] < 48 or crop.shape[1] < 32:
            continue
        if crop.mean() < 24:
            continue
        samples.append(crop)
    if len(samples) < count:
        # One broad face, sliced into bands, still from the elevation sheet.
        ys, xs = np.where(content)
        if len(xs) == 0:
            raise SystemExit("elevation punch has no platform face")
        x0, x1 = int(np.percentile(xs, 30)), int(np.percentile(xs, 70))
        y0, y1 = int(np.percentile(ys, 35)), int(np.percentile(ys, 80))
        body = sheet[y0:y1, x0:x1]
        if body.shape[0] < 40:
            raise SystemExit("elevation face is too short to hang")
        band = max(36, body.shape[0] // count)
        samples = [body[i * band : (i + 1) * band] for i in range(count) if body[i * band : (i + 1) * band].size]
    if len(samples) < count:
        raise SystemExit(f"need {count} wall samples, found {len(samples)}")
    return samples[:count]


def _hang(wall: np.ndarray, hang: int) -> np.ndarray:
    src = wall.astype(np.float32)
    lum = src.mean(2)
    # Drop the black gutter so it does not gray the wall.
    keep = lum > 26
    if keep.any():
        fill = np.array([38.0, 40.0, 48.0], np.float32)
        src[~keep] = fill
        lum = src.mean(2)
    p10, p90 = np.percentile(lum, [15, 85])
    t = np.clip((lum - p10) / max(float(p90 - p10), 8.0), 0.0, 1.0)
    tone = 16.0 + t * 40.0
    src = np.stack([tone * 0.86, tone * 0.90, tone * 1.02], axis=2)
    spr = Image.fromarray(np.clip(src, 0, 255).astype(np.uint8)).resize((64, hang), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).astype(np.float32)
    fade = np.linspace(1.0, 0.72, hang)[:, None, None]
    arr *= fade
    out = np.zeros((hang, 64, 4), np.uint8)
    rgb = np.clip(arr, 0, 255).astype(np.uint8)
    out[:, :, :3] = rgb
    out[:, :, 3] = 255
    # Inset the sides a hair so the wall stays under the diamond, not past it.
    out[:, 0, 3] = 0
    out[:, -1, 3] = 0
    edge = np.zeros(hang, dtype=bool)
    edge[:] = True
    shade = out[:, 1, :3].astype(np.float32) * 0.55
    out[:, 1, :3] = shade.astype(np.uint8)
    out[:, -2, :3] = (out[:, -2, :3].astype(np.float32) * 0.55).astype(np.uint8)
    return out


def _slice_elevation(sheet: np.ndarray, caps: dict[str, Image.Image]) -> list[dict]:
    walls = _wall_samples(sheet, 4)
    order = [
        ("storm_ground_e1.png", caps["ground"], walls[0]),
        ("storm_ground_e1_v1.png", caps["ground_v1"], walls[1]),
        ("storm_mud_e1.png", caps["mud"], walls[2]),
        ("storm_ground_e2.png", caps["ground"], walls[3]),
    ]
    records = []
    built = {}
    for name, cap, wall in order:
        hang = HANG[name]
        cap_arr = np.asarray(cap.convert("RGBA"))
        if cap_arr.shape[0] != 32 or cap_arr.shape[1] != 64:
            raise SystemExit(f"cliff cap {name} is not a 64×32 diamond")
        wall_arr = _hang(wall, hang)
        out = np.zeros((32 + hang, 64, 4), np.uint8)
        out[:32] = cap_arr
        out[32:] = wall_arr
        img = Image.fromarray(out)
        img.save(TILES / name)
        built[name] = img
        records.append({"file": name, "fit": "cliff", "size": [img.size[0], img.size[1]]})
        print(f"{name:28} {img.size[0]}x{img.size[1]}")
    e1 = built["storm_ground_e1.png"]
    e2 = built["storm_ground_e2.png"]
    if e1.size[1] <= 32 or e2.size[1] <= e1.size[1]:
        raise SystemExit(f"cliff heights are not platforms: e1 {e1.size} e2 {e2.size}")
    if e1.size[0] != 64 or e2.size[0] != 64:
        raise SystemExit("cliff is not 64 wide")
    return records


def _key_props(sheet: np.ndarray) -> np.ndarray:
    rgb = sheet[:, :, :3].astype(np.float32)
    lum = rgb.mean(2)
    # The sheet's dark plate sits near lum 10. A higher cut keeps each
    # silhouette separate from the glow that bridges the contact clusters.
    alpha = np.clip((lum - 46.0) / 20.0, 0.0, 1.0)
    alpha = np.where(lum < 48.0, 0.0, alpha)
    out = np.zeros((rgb.shape[0], rgb.shape[1], 4), np.uint8)
    out[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[:, :, 3] = (alpha * 255.0).astype(np.uint8)
    out[out[:, :, 3] < 16] = 0
    return out


def _prop_sprites(sheet: np.ndarray) -> list[dict]:
    if tuple(sheet.shape) != (720, 1280, 3):
        raise SystemExit(
            f"storm props sheet must be the 1280×720 small set, got {sheet.shape}"
        )
    keyed = _key_props(sheet)
    mask = keyed[:, :, 3] > 24
    lab, count = ndimage.label(mask)
    sprites = []
    for i in range(1, count + 1):
        ys, xs = np.where(lab == i)
        if len(xs) < 500:
            continue
        x0, x1 = int(xs.min()), int(xs.max())
        y0, y1 = int(ys.min()), int(ys.max())
        w, h = x1 - x0 + 1, y1 - y0 + 1
        # Merged glow clusters on this sheet are still bigger than a tile.
        # Keep the separate silhouettes and leave those clusters out.
        if len(xs) > 9000 or w > 160 or h > 170:
            continue
        if w < 32 or h < 32 or h > w * 4.2:
            continue
        if w > 150 and h > 150:
            continue
        crop = keyed[y0 : y1 + 1, x0 : x1 + 1].copy()
        crop[crop[:, :, 3] < 20] = 0
        opaque_px = crop[:, :, 3] > 20
        opaque = int(opaque_px.sum())
        if opaque < 600:
            continue
        rgb = crop[:, :, :3].astype(np.float32)
        held = rgb[opaque_px]
        contrast = float(held.std()) if opaque else 0.0
        if contrast < 10.0:
            continue
        chroma = float((held.max(1) - held.min(1)).mean()) if opaque else 0.0
        sprites.append(
            {
                "img": crop,
                "w": w,
                "h": h,
                "area": opaque,
                "chroma": chroma,
                "contrast": contrast,
                "at": (x0, y0),
            }
        )
    if len(sprites) < 6:
        raise SystemExit(f"need 6 sparse prop silhouettes, found {len(sprites)}")
    return sprites


def _scale_prop(sprite: np.ndarray, max_w: int, max_h: int) -> Image.Image:
    height, width = sprite.shape[:2]
    scale = min(max_w / width, max_h / height)
    out_w = max(8, int(round(width * scale)))
    out_h = max(8, int(round(height * scale)))
    img = Image.fromarray(sprite).resize((out_w, out_h), Image.Resampling.LANCZOS)
    arr = np.asarray(img).copy()
    arr[arr[:, :, 3] < 12] = 0
    # Trim so the silhouette sits in the sprite center, not in a padded corner.
    solid = arr[:, :, 3] > 16
    ys, xs = np.where(solid)
    if len(xs) == 0:
        raise SystemExit("prop scaled to nothing")
    arr = arr[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    return Image.fromarray(arr)


def _slice_props(sheet: np.ndarray) -> list[dict]:
    sprites = _prop_sprites(sheet)
    used: set[int] = set()

    def take(pool: list[dict], score) -> dict:
        ranked = [sprite for sprite in pool if id(sprite) not in used]
        if not ranked:
            raise SystemExit("ran out of tile-scale prop silhouettes")
        ranked.sort(key=score, reverse=True)
        chosen = ranked[0]
        used.add(id(chosen))
        return chosen

    def rubble_height(sprite: dict) -> float:
        scale = min(28 / sprite["w"], 18 / max(sprite["h"], 1))
        return sprite["h"] * scale

    # Roles follow shape on the small sheet: the vivid crystal, one narrow
    # pillar, one wide arc, a low rock, a small spark, and one upright conduit.
    bolt = take(
        [s for s in sprites if s["area"] >= 2500 and min(s["w"], s["h"]) >= 60],
        lambda s: s["chroma"],
    )
    pillar = take(
        [s for s in sprites if s["h"] >= s["w"] * 1.6],
        lambda s: s["h"] / max(s["w"], 1),
    )
    arc = take(
        [s for s in sprites if s["w"] >= s["h"] * 1.4],
        lambda s: s["w"],
    )
    rubble = take(
        [s for s in sprites if s["chroma"] < 32 and s["w"] >= s["h"] * 1.2 and s["h"] <= 80],
        rubble_height,
    )
    spark = take(
        [s for s in sprites if max(s["w"], s["h"]) <= 110 and s["chroma"] >= 20],
        lambda s: s["chroma"],
    )
    conduit = take(
        [
            s
            for s in sprites
            if s["h"] >= s["w"] * 1.15 and s["chroma"] >= 12 and s["area"] >= 1000
        ],
        lambda s: s["h"],
    )
    assigned = {
        "storm_prop_spark.png": spark,
        "storm_prop_rubble.png": rubble,
        "storm_prop_arc.png": arc,
        "storm_prop_rock_pillar.png": pillar,
        "storm_prop_crystal_bolt.png": bolt,
        "storm_prop_conduit.png": conduit,
    }
    records = []
    for name, sprite in assigned.items():
        img = _scale_prop(sprite["img"], *PROP_BOX[name])
        max_w, max_h = PROP_BOX[name]
        if img.size[0] > max_w or img.size[1] > max_h:
            raise SystemExit(f"{name} covers the tile ({img.size})")
        img.save(TILES / name)
        records.append({"file": name, "fit": "prop", "size": [img.size[0], img.size[1]]})
        print(f"{name:28} {img.size[0]:3}x{img.size[1]:<3} from {sprite['w']}x{sprite['h']} at {sprite['at']}")
    return records


def _patch_atlas(records: list[dict]) -> None:
    atlas = json.loads(ATLAS.read_text())
    sheets = list(atlas.get("source_sheets") or [])
    for sheet in (
        "pending/electric/storm_ground_punch.png",
        "pending/electric/storm_elevation_punch.png",
        "pending/electric/storm_props_punch.png",
        "pending/electric/board_mood_punch.png",
    ):
        if sheet not in sheets:
            sheets.append(sheet)
    atlas["source_sheets"] = sheets
    family = atlas["families"]["stormspire"]
    family["pack"] = "electric"
    family["prefix"] = "storm_"
    family["pending_theme"] = None
    atlas["stormspire_punch"] = {
        "ground": "pending/electric/storm_ground_punch.png",
        "elevation": "pending/electric/storm_elevation_punch.png",
        "props": "pending/electric/storm_props_punch.png",
        "mood": "pending/electric/board_mood_punch.png",
        "note": "Live Stormspire paint. Props are the 1280×720 small sheet. The monolith archive is not sliced. Mood is reference only. Geometry and tags stay on the Locked maps. The board draws six small accents, not the tagged prop ring.",
    }
    written = {item["file"]: item for item in records}
    kept = [item for item in atlas.get("files", []) if item.get("file") not in written]
    atlas["files"] = kept + [
        {"file": item["file"], "fit": item["fit"], "size": item["size"]} for item in records
    ]
    ATLAS.write_text(json.dumps(atlas, indent=2) + "\n")


def _load_cells() -> list:
    tags = json.loads(TAGS.read_text())
    cells = [[{"terrain": "ground", "elevation": 0, "paint_only": []} for _ in range(15)] for _ in range(15)]
    for cell in tags["cells"]:
        cells[cell["y"]][cell["x"]] = {
            "terrain": cell["terrain"],
            "elevation": int(cell["elevation"]),
            "paint_only": list(cell["paint_only"]),
        }
    return cells


def _tile_name(cell: dict, x: int, y: int) -> str:
    if cell["elevation"] >= 2:
        return "storm_ground_e2"
    if cell["elevation"] == 1:
        base = "storm_mud_e1" if cell["terrain"] == "mud" else "storm_ground_e1"
        if base == "storm_ground_e1" and (x + y) % 2 == 1:
            return "storm_ground_e1_v1"
        return base
    if cell["terrain"] == "water":
        return "storm_water_v1" if (x * 3 + y) % 2 else "storm_water"
    if cell["terrain"] == "mud":
        return ["storm_mud", "storm_mud_v1", "storm_mud_v2"][(x + y) % 3]
    return ["storm_ground", "storm_ground_v1", "storm_ground_v2", "storm_ground_v3"][(x * 2 + y) % 4]


def _render_board(cells: list) -> Image.Image:
    def local(x: int, y: int) -> tuple[int, int]:
        return ((x - y) * 32, (x + y) * 16)

    pts = [local(x, y) for y in range(15) for x in range(15)]
    min_x = min(p[0] for p in pts) - 48
    max_x = max(p[0] for p in pts) + 48
    min_y = min(p[1] for p in pts) - 80
    max_y = max(p[1] for p in pts) + 140
    canvas = Image.new("RGBA", (int(max_x - min_x + 180), int(max_y - min_y + 200)), (0, 0, 0, 0))
    cache: dict[str, Image.Image] = {}

    def get(name: str) -> Image.Image:
        if name not in cache:
            cache[name] = Image.open(TILES / f"{name}.png").convert("RGBA")
        return cache[name]

    order = sorted(((x, y) for y in range(15) for x in range(15)), key=lambda p: (p[0] + p[1], p[0]))
    for x, y in order:
        cell = cells[y][x]
        tile = get(_tile_name(cell, x, y))
        lx, ly = local(x, y)
        px = int(lx - min_x + 90 - 32)
        py = int(ly - min_y + 100)
        if tile.height > 32:
            py -= tile.height - 32
        canvas.alpha_composite(tile, (px, py))
        for prop in _dress_props(x, y, cell["paint_only"]):
            prop_img = _fit_prop_draw(get(f"storm_prop_{prop}"))
            ppx = px + 32 - prop_img.width // 2
            ppy = py + 32 - prop_img.height
            canvas.alpha_composite(prop_img, (ppx, ppy))
    return canvas


def _dress_props(x: int, y: int, props: list) -> list:
    allowed = STORM_DRESS.get((x, y))
    if not allowed:
        return []
    return [prop for prop in props if prop in allowed]


def _fit_prop_draw(img: Image.Image) -> Image.Image:
    """Match the Godot storm cap: the long side stays within one diamond."""
    longest = max(img.size)
    if longest <= 32:
        return img
    scale = 32 / longest
    out = (
        max(1, int(round(img.width * scale))),
        max(1, int(round(img.height * scale))),
    )
    return img.resize(out, Image.Resampling.LANCZOS)


def _write_previews(cells: list) -> None:
    drawn = 0
    for y, row in enumerate(cells):
        for x, cell in enumerate(row):
            shown = _dress_props(x, y, cell["paint_only"])
            drawn += len(shown)
            for prop in shown:
                img = Image.open(TILES / f"storm_prop_{prop}.png")
                fitted = _fit_prop_draw(img)
                if max(fitted.size) > 32:
                    raise SystemExit(f"{prop} still reads taller than one diamond")
    if not 4 <= drawn <= 6:
        raise SystemExit(f"Stormspire dress should be 4–6 props, drew {drawn}")
    board = _render_board(cells)
    plain = Image.new("RGB", board.size, (12, 10, 18))
    plain.paste(board, mask=board.split()[-1])
    min_x = min((x - y) * 32 for y in range(15) for x in range(15)) - 48
    min_y = min((x + y) * 16 for y in range(15) for x in range(15)) - 80
    ink = ImageDraw.Draw(plain)
    for y in range(15):
        for x in range(15):
            lx, ly = (x - y) * 32, (x + y) * 16
            ox = lx - min_x + 90
            oy = ly - min_y + 100
            diamond = [(ox, oy), (ox + 32, oy + 16), (ox, oy + 32), (ox - 32, oy + 16)]
            ink.line(diamond + [diamond[0]], fill=(120, 96, 48), width=1)
    plain_path = ROOT / "stormspire_15x15_preview.png"
    plain.save(plain_path, optimize=True)

    plate = Image.new("RGB", (1280, 720), (10, 8, 16))
    grad = ImageDraw.Draw(plate)
    for i in range(720):
        t = i / 720
        grad.line([(0, i), (1279, i)], fill=(int(16 + 8 * t), int(12 + 6 * t), int(28 + 10 * t)))
    scale = 980 / board.width
    board_s = board.resize((980, max(1, int(board.height * scale))), Image.Resampling.LANCZOS)
    bx = (1280 - board_s.width) // 2
    by = (720 - board_s.height) // 2 + 16
    plate.paste(board_s, (bx, by), board_s.split()[-1])
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
    except Exception:
        font = ImageFont.load_default()
    banner = ImageDraw.Draw(plate)
    banner.rounded_rectangle([360, 16, 920, 58], radius=8, fill=(24, 18, 36))
    banner.text((378, 26), "15×15 Stormspire · electric and wind", font=font, fill=(214, 196, 150))
    painted = ROOT / "stormspire_15x15_painted_preview.png"
    plate.save(painted, optimize=True)
    print(f"preview {plain_path.name} {plain.size[0]}x{plain.size[1]}")
    print(f"painted {painted.name}")


def _require_png(path: Path) -> None:
    if path.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"{path} is not a PNG")


def _check_aliases() -> None:
    pairs = (
        (GROUND_SHEET, MIRROR / "ground_punch.png"),
        (ELEV_SHEET, MIRROR / "elevation_punch.png"),
        (PROPS_SHEET, MIRROR / "props_punch.png"),
        (MOOD_SHEET, MIRROR / "luca_preview_stormspire.png"),
    )
    for src, alias in pairs:
        if not src.is_file() or not alias.is_file():
            raise SystemExit(f"missing punch alias {src.name} / {alias.name}")
        if _sha(src) != _sha(alias):
            raise SystemExit(f"alias bytes differ for {src.name}")
    # Unprefixed names in the electric folder are the same sheets.
    for src, alias_name in (
        (GROUND_SHEET, "ground_punch.png"),
        (ELEV_SHEET, "elevation_punch.png"),
        (PROPS_SHEET, "props_punch.png"),
    ):
        alias = PUNCH / alias_name
        if not alias.is_file() or _sha(alias) != _sha(src):
            raise SystemExit(f"{alias_name} is not an alias of {src.name}")


def main() -> None:
    for path in (GROUND_SHEET, ELEV_SHEET, PROPS_SHEET, MOOD_SHEET, TAGS, TMX):
        if not path.is_file():
            raise SystemExit(f"missing {path}")
        if path.suffix == ".png":
            _require_png(path)
    _check_aliases()
    before = (_sha(TAGS), _sha(TMX))
    ground = np.asarray(Image.open(GROUND_SHEET).convert("RGB"))
    elev = np.asarray(Image.open(ELEV_SHEET).convert("RGB"))
    props = np.asarray(Image.open(PROPS_SHEET).convert("RGB"))
    records, images = _slice_ground(ground)
    records.extend(_slice_elevation(elev, images["_caps"]))
    records.extend(_slice_props(props))
    after = (_sha(TAGS), _sha(TMX))
    if before != after:
        raise SystemExit("Stormspire tags or tmx changed")
    written = {item["file"] for item in records}
    if any(not name.startswith("storm_") for name in written):
        raise SystemExit(f"slicer wrote a non-storm file: {sorted(written)}")
    if len(records) != 20:
        raise SystemExit(f"expected 20 storm files, wrote {len(records)}")
    _patch_atlas(records)
    _sync_tsx()
    _write_previews(_load_cells())
    print(f"sliced {len(records)} stormspire punch tiles")


if __name__ == "__main__":
    main()
