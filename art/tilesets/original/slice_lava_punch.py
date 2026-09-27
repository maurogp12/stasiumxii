#!/usr/bin/env python3
"""Slice the Slagcrown lava punch onto the Koliseo dress.

Soft Lock: fuego + lava. Presentation only. Locked tags, geometry,
walkability, and kit numbers are not opened for writing.

Scenario punch v4 (Luca sí). Reads pending/lava:
  ground_punch.png     rock diamonds, lava seams and pits, not lava soup
  elevation_punch.png  platforms. White background is keyed out.
  props_punch.png      full scene. Only standing pillars and banners are cut.

board_mood_punch.png is a reference plate and is not sliced. The prop
sheet's floor is not sliced: a strip across the diamond eats the rock.
Tall pillars and banners are scaled to one tile. The board draws six of
them (four corner pillars, two edge banners). Every other paint_only
cell keeps a small mark so a blocker still reads. props_rejected sheets
are not read.

Flat tiles are a hard 64×32 diamond with a dark rim so neighboring
cells keep a seam. Cliffs keep that cap and hang the wall. Stairs stay
on the same sprite as the platform they climb. A clipped block at the
sheet edge is dropped so a stair does not lead into empty space.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

from slice_ice_electric import _fit_cliff_sheet
from slice_original_tileset import ATLAS, TILES, _sync_tsx

HERE = Path(__file__).resolve().parent
LAVA = HERE / "pending" / "lava"
GROUND_SHEET = LAVA / "ground_punch.png"
ELEV_SHEET = LAVA / "elevation_punch.png"
PROPS_SHEET = LAVA / "props_punch.png"
MIRROR = HERE.parents[2] / "stasium-ref" / "maps" / "lava"
ROOT = TILES.parent
TAGS = ROOT / "slagcrown_15x15_tags.json"
TMX = ROOT / "slagcrown_15x15.tmx"

# Source diamond on ground_punch.png, before the 64×32 fit.
SAMPLE_RW = 78
SAMPLE_RH = 38

PROP_BOX = {
    "slag_prop_basalt_pillar.png": (36, 88),
    "slag_prop_rock_pillar.png": (28, 76),
    "slag_prop_banner.png": (30, 84),
    "slag_prop_ash_rock.png": (22, 16),
    "slag_prop_rubble.png": (20, 14),
    "slag_prop_steam_vent.png": (18, 16),
}
# Same cells as KoliseoArt.SLAG_TALL_DRESS. Tags stay put; only the draw changes.
TALL_DRESS = {
    (0, 0): "basalt_pillar",
    (14, 0): "basalt_pillar",
    (0, 14): "basalt_pillar",
    (14, 14): "basalt_pillar",
    (7, 0): "banner",
    (7, 14): "banner",
}
# A brand on the south of the diamond. A full 64×32 seal would replace the floor.
SEAL_SIZE = (28, 14)


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


def _rim(arr: np.ndarray, mask: np.ndarray, rows: slice | None = None) -> None:
    """One-pixel darker rim so neighboring diamonds keep a readable seam."""
    edge = mask & ~ndimage.binary_erosion(mask, iterations=1)
    if rows is not None:
        full = np.zeros(mask.shape, bool)
        full[rows] = edge[rows]
        edge = full
    if not edge.any():
        return
    rgb = arr[:, :, :3].astype(np.float32)
    rgb[edge] *= 0.52
    arr[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)


def _real_rock(cap: np.ndarray) -> np.ndarray:
    """Opaque cap pixels that are not the white-sheet fringe."""
    rgb = cap[:, :, :3].astype(np.float32)
    lum = rgb.mean(2)
    chroma = rgb.max(2) - rgb.min(2)
    pale = (lum > 168.0) & (chroma < 14.0)
    return (cap[:, :, 3] > 40) & (lum < 200.0) & ~pale


def _solid_diamond(arr: np.ndarray) -> np.ndarray:
    mask = _iso_mask(arr.shape[1], 32)
    cap = arr[:32]
    solid = _real_rock(cap)
    holes = mask & ~solid
    if holes.any() and solid.any():
        _, nearest = ndimage.distance_transform_edt(~solid, return_indices=True)
        cap[holes] = cap[nearest[0][holes], nearest[1][holes]]
    cap[:, :, 3] = np.where(mask, 255, 0).astype(np.uint8)
    _rim(cap, mask)
    arr[:32] = cap
    return arr


def _green_fraction(arr: np.ndarray) -> float:
    """Same test as tests/run_koliseo_maps_tests.gd."""
    px = arr.astype(np.float32)
    alpha = px[:, :, 3] / 255.0
    red = px[:, :, 0] / 255.0
    green = px[:, :, 1] / 255.0
    blue = px[:, :, 2] / 255.0
    solid = alpha >= 0.15
    veg = solid & (green > red + 0.07) & (green > blue + 0.05) & (green > 0.23)
    return float(veg.sum()) / float(max(int(solid.sum()), 1))


def _require_clean(name: str, arr: np.ndarray) -> None:
    frac = _green_fraction(arr)
    if frac > 0.005:
        raise SystemExit(f"{name} still has lawn/moss ({frac:.3f})")


def _fit_flat_rgb(rgb: np.ndarray) -> np.ndarray:
    """RGB crop → hard 64×32 diamond. Gutters outside the source diamond drop."""
    height, width = rgb.shape[:2]
    yy, xx = np.mgrid[0:height, 0:width]
    cx = (width - 1) / 2.0
    cy = (height - 1) / 2.0
    mask = (np.abs(xx - cx) / (cx + 0.5) + np.abs(yy - cy) / (cy + 0.5)) <= 1.0
    rgba = np.zeros((height, width, 4), np.uint8)
    rgba[:, :, :3] = rgb
    rgba[:, :, 3] = np.where(mask, 255, 0).astype(np.uint8)
    ys, xs = np.where(mask)
    crop = rgba[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    spr = Image.fromarray(crop).resize((64, 32), Image.Resampling.LANCZOS)
    return _solid_diamond(np.asarray(spr).copy())


def _center(arr: np.ndarray) -> np.ndarray:
    return arr[16, 32, :3].astype(np.float32)


def _lava_mask(rgb: np.ndarray) -> np.ndarray:
    r = rgb[:, :, 0].astype(np.float32)
    g = rgb[:, :, 1].astype(np.float32)
    b = rgb[:, :, 2].astype(np.float32)
    return (r > 150.0) & (r > g + 28.0) & (r > b + 40.0)


def _sample_ground(sheet: np.ndarray) -> dict[str, list[dict]]:
    height, width = sheet.shape[:2]
    rw, rh = SAMPLE_RW, SAMPLE_RH
    found = {"ground": [], "lava": [], "mud": [], "water": []}
    for cy in range(rh + 8, height - rh - 8, 36):
        for cx in range(rw + 8, width - rw - 8, 48):
            crop = sheet[cy - rh : cy + rh, cx - rw : cx + rw]
            if crop.shape[0] != rh * 2 or crop.shape[1] != rw * 2:
                continue
            if float(crop.mean()) < 16.0:
                continue
            fitted = _fit_flat_rgb(crop)
            if int((fitted[:, :, 3] > 200).sum()) < 900:
                continue
            if cy < 200:
                continue
            opaque = fitted[:, :, 3] > 200
            lum_map = fitted[:, :, :3].astype(np.float32).mean(2)
            mean_lum = float(lum_map[opaque].mean())
            if float((lum_map[opaque] < 12.0).mean()) > 0.08:
                continue
            px = _center(fitted)
            r, g, b = (float(v) for v in px)
            # v4 rock is darker than the rejected orange soup. Green stays low.
            if not (r > g + 2.0 and r > b + 2.0 and g > 8.0):
                continue
            lum = float(px.mean())
            lava_frac = float(_lava_mask(fitted[:, :, :3]).mean())
            std = float(lum_map[opaque].std())
            item = {
                "img": fitted,
                "px": px,
                "at": (cx, cy),
                "lum": lum,
                "mean": mean_lum,
                "lava": lava_frac,
                "std": std,
            }
            center_hot = r > 150.0 and r > g + 40.0
            # Lava cells are the bright seams and pits. Ground stays dark rock
            # with a few cracks, so the field is not an orange soup.
            if lava_frac > 0.30 and r > 160.0 and b < 140.0 and lum > 55.0:
                found["lava"].append(item)
            elif (not center_hot) and lava_frac < 0.06 and 18.0 <= mean_lum <= 36.0 and std > 5.0 and lum < 42.0:
                found["water"].append(item)
            elif (not center_hot) and lava_frac < 0.12 and 26.0 <= mean_lum <= 48.0 and (r - g) < 45.0 and std > 6.0:
                found["mud"].append(item)
            elif (not center_hot) and 0.02 <= lava_frac <= 0.20 and 26.0 <= mean_lum <= 68.0 and std > 8.0 and r < 150.0:
                found["ground"].append(item)
    return found


def _spread(items: list[dict], count: int, prefer) -> list[dict]:
    ordered = sorted(items, key=prefer)
    chosen: list[dict] = []
    seen: set[int] = set()
    min_dist = 220
    while len(chosen) < count and min_dist >= 0:
        for item in ordered:
            mark = id(item)
            if mark in seen:
                continue
            cx, cy = item["at"]
            if any(abs(cx - o["at"][0]) + abs(cy - o["at"][1]) < min_dist for o in chosen):
                continue
            chosen.append(item)
            seen.add(mark)
            if len(chosen) == count:
                break
        min_dist -= 70
    if len(chosen) < count:
        raise SystemExit(f"need {count} diamonds, found {len(chosen)} from {len(items)}")
    return chosen


def _slice_ground() -> list[dict]:
    sheet = np.asarray(Image.open(GROUND_SHEET).convert("RGB"))
    found = _sample_ground(sheet)
    for key, need in (("ground", 5), ("lava", 8), ("mud", 1), ("water", 1)):
        if len(found[key]) < need:
            raise SystemExit(f"need {need} {key} diamonds, found {len(found[key])}")
    picks = {
        "ground": _spread(found["ground"], 5, lambda item: (abs(item["lum"] - 62.0), -item["std"])),
        "lava": _spread(found["lava"], 8, lambda item: (-item["lava"], -item["lum"])),
        "mud": _spread(found["mud"], 1, lambda item: item["lum"]),
        "water": _spread(found["water"], 1, lambda item: item["lum"]),
    }
    # Primary lava is a seam or pit, not a white core. Primary ground is dark rock.
    picks["lava"].sort(key=lambda item: (abs(item["lava"] - 0.55), abs(item["lum"] - 100.0)))
    rock = np.array([52.0, 30.0, 24.0], np.float32)
    ash = np.array([34.0, 24.0, 22.0], np.float32)
    picks["ground"].sort(key=lambda item: (abs(item["lava"] - 0.08), float(np.abs(item["px"] - rock).sum())))
    picks["water"].sort(key=lambda item: float(np.abs(item["px"] - ash).sum()))
    records = []
    names = {
        "ground": ["slag_ground.png", "slag_ground_v1.png", "slag_ground_v2.png", "slag_ground_v3.png", "slag_ground_v4.png"],
        "lava": [f"slag_lava.png"] + [f"slag_lava_v{i}.png" for i in range(1, 8)],
        "mud": ["slag_mud.png"],
        "water": ["slag_water.png"],
    }
    for key, files in names.items():
        for name, item in zip(files, picks[key]):
            _save_arr(name, item["img"], records, item["at"], "flat")
            px = np.round(item["px"], 1).tolist()
            print(f"{name:28} 64x32  {key:6} rgb {px} lava {item['lava']:.2f} at {item['at']}")
    _assert_flats(picks)
    seal = _fit_seal(picks["water"][0])
    _save_arr("slag_prop_floor_seal.png", seal, records, picks["water"][0]["at"], "seal")
    print(f"{'slag_prop_floor_seal.png':28} {seal.shape[1]}x{seal.shape[0]}  small ash mark")
    return records


def _fit_seal(water: dict) -> np.ndarray:
    """Small ash diamond. It sits on the tile; it does not replace it."""
    src = water["img"]
    spr = Image.fromarray(src).resize(SEAL_SIZE, Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    mask = _iso_mask(arr.shape[1], arr.shape[0])
    arr[:, :, 3] = np.where(mask, 255, 0).astype(np.uint8)
    _rim(arr, mask)
    if arr.shape[0] >= 32 or arr.shape[1] >= 48:
        raise SystemExit("floor seal covers the diamond")
    return arr


def _assert_flats(picks: dict) -> None:
    mask = _iso_mask()
    for key in ("ground", "lava", "water"):
        img = picks[key][0]["img"]
        if img.shape[1] != 64 or img.shape[0] != 32:
            raise SystemExit(f"{key} diamond is not 64×32")
        tips = [(32, 0), (63, 16), (32, 31), (0, 16)]
        for x, y in tips:
            if img[y, x, 3] < 200:
                raise SystemExit(f"{key} diamond tip {(x, y)} is open")
        for x, y in ((0, 0), (63, 0), (0, 31), (63, 31)):
            if img[y, x, 3] > 8:
                raise SystemExit(f"{key} diamond corner {(x, y)} is filled")
        if not np.array_equal(img[:, :, 3] > 200, mask):
            raise SystemExit(f"{key} diamond coverage is not the hard mask")
    ground = picks["ground"][0]["px"]
    lava = picks["lava"][0]["px"]
    water = picks["water"][0]["px"]
    if not (ground[0] > ground[1] and ground[0] > ground[2]):
        raise SystemExit(f"slag ground center is not scorched rock {ground}")
    if not (lava[0] > lava[2]):
        raise SystemExit(f"slag lava center is not lava {lava}")
    if not (water[0] > water[1] and water[0] > water[2]):
        raise SystemExit(f"slag pool center is not dark ash {water}")
    if float(ground.mean()) > 80.0:
        raise SystemExit(f"slag ground center is lava soup {ground}")
    if float(lava.mean()) < float(ground.mean()) + 25.0:
        raise SystemExit(f"slag lava is not brighter than the rock {lava} vs {ground}")


def _key_white(rgb: np.ndarray) -> np.ndarray:
    """Drop the white sheet. Keep the rock color; do not unmix toward white."""
    src = rgb.astype(np.float32)
    lum = src.mean(2)
    chroma = src.max(2) - src.min(2)
    bg = (lum > 205.0) & (chroma < 26.0)
    alpha = np.ones(lum.shape, np.float32)
    alpha[bg] = 0.0
    band = (lum > 175.0) & (chroma < 22.0) & ~bg
    alpha[band] = np.clip((205.0 - lum[band]) / 30.0, 0.0, 1.0)
    out = np.zeros((src.shape[0], src.shape[1], 4), np.uint8)
    out[:, :, :3] = np.clip(src, 0, 255).astype(np.uint8)
    out[:, :, 3] = (alpha * 255.0).astype(np.uint8)
    out[out[:, :, 3] < 20] = 0
    return out


def _stairs_meet_platform(arr: np.ndarray) -> bool:
    """The hanging wall, including stairs, stays attached to the cap."""
    if arr.shape[0] < 40 or arr.shape[1] != 64:
        return False
    solid = arr[:, :, 3] > 40
    # Equator of the cap is the wide part. The south tip itself is only a few pixels.
    if int(solid[16].sum()) < 40 or int(solid[31].sum()) < 2:
        return False
    # Cap row 31 must touch the first wall row. A gap is a stair into void.
    # The south tip of a 64×32 diamond is only a few pixels wide.
    meet = solid[31] & solid[32]
    if int(meet.sum()) < 3:
        return False
    reach = np.zeros_like(solid)
    reach[:32] = solid[:32]
    for _ in range(arr.shape[0]):
        grown = ndimage.binary_dilation(reach) & (solid | reach)
        if np.array_equal(grown, reach):
            break
        reach = grown
    wall = solid.copy()
    wall[:32] = False
    if int(wall.sum()) < 40:
        return False
    detached = int((wall & ~reach).sum())
    if detached > 0.12 * float(max(int(wall.sum()), 1)):
        return False
    rows = np.where(reach.any(1))[0]
    if len(rows) == 0 or int(rows.max()) < 36:
        return False
    return True


def _stamp_cliff(img: Image.Image) -> np.ndarray:
    arr = np.asarray(img).copy()
    if arr.shape[1] != 64 or arr.shape[0] < 36:
        raise SystemExit(f"cliff fit is {arr.shape[1]}x{arr.shape[0]}")
    arr = _solid_diamond(arr)
    wall = arr[32:, :, 3] > 16
    if wall.any():
        inset = ndimage.binary_erosion(wall, iterations=1, border_value=0)
        edge = wall & ~inset
        rgb = arr[32:, :, :3].astype(np.float32)
        rgb[edge] *= 0.62
        arr[32:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return arr


def _platform_crop(keyed: np.ndarray, lab: np.ndarray, index: int) -> tuple[np.ndarray, tuple[int, int]] | None:
    ys, xs = np.where(lab == index)
    if len(xs) < 40000:
        return None
    x0, x1 = int(xs.min()), int(xs.max())
    y0, y1 = int(ys.min()), int(ys.max())
    height, width = lab.shape
    # A block cut by the sheet edge is a platform or stair with nowhere to land.
    if x0 < 8 or y0 < 8 or x1 > width - 9 or y1 > height - 9:
        return None
    crop = keyed[y0 : y1 + 1, x0 : x1 + 1].copy()
    crop[lab[y0 : y1 + 1, x0 : x1 + 1] != index] = 0
    return crop, (x0, y0)


def _fit_platform(crop: np.ndarray, at: tuple[int, int], cap_frac: float, lo: int, hi: int) -> dict | None:
    arr = _stamp_cliff(_fit_cliff_sheet(crop, cap_frac))
    if arr.shape[0] < lo or arr.shape[0] > hi:
        return None
    cap = arr[4, 32].astype(np.int16)
    if int(cap[3]) < 200 or int(cap[0]) <= int(cap[1]) or int(cap[0]) <= int(cap[2]):
        return None
    if not _stairs_meet_platform(arr):
        return None
    return {"img": arr, "at": at, "h": int(arr.shape[0])}


def _slice_elevation() -> list[dict]:
    rgb = np.asarray(Image.open(ELEV_SHEET).convert("RGB"))
    keyed = _key_white(rgb)
    mask = ndimage.binary_opening(keyed[:, :, 3] > 36, iterations=1)
    mask = ndimage.binary_closing(mask, iterations=2)
    lab, count = ndimage.label(mask)
    lows = []
    highs = []
    for i in range(1, count + 1):
        packed = _platform_crop(keyed, lab, i)
        if packed is None:
            continue
        crop, at = packed
        # Low step: more of the block is the cap, so the wall stays short.
        # High step: the same kind of block hangs a taller wall. One source
        # can fill both, but the three low files use different blocks.
        low = _fit_platform(crop, at, 0.58, 46, 66)
        high = _fit_platform(crop, at, 0.38, 78, 96)
        if low is not None:
            lows.append(low)
            print(f"low platform {low['img'].shape[1]}x{low['h']} from {at}")
        if high is not None:
            highs.append(high)
            print(f"high platform {high['img'].shape[1]}x{high['h']} from {at}")
    if len(lows) < 3 or not highs:
        raise SystemExit(f"need 3 low platforms and 1 high, found {len(lows)} and {len(highs)}")
    lows.sort(key=lambda item: (item["h"], item["at"]))
    highs.sort(key=lambda item: item["h"])
    tall = highs[-1]
    # Keep the low walls clearly shorter than the high platform.
    shorts = [item for item in lows if item["h"] + 16 <= tall["h"]]
    if len(shorts) < 3:
        raise SystemExit("low platforms are not shorter than the high wall")
    picks = [
        ("slag_ground_e1.png", shorts[0]),
        ("slag_ground_e1_v1.png", shorts[1]),
        ("slag_mud_e1.png", shorts[2]),
        ("slag_ground_e2.png", tall),
    ]
    records = []
    for name, item in picks:
        _save_arr(name, item["img"], records, item["at"], "cliff")
        print(f"{name:28} {item['img'].shape[1]}x{item['img'].shape[0]}")
    if picks[3][1]["h"] <= picks[0][1]["h"]:
        raise SystemExit("ground_e2 is not taller than ground_e1")
    return records


def _scale_prop(sprite: np.ndarray, max_w: int, max_h: int) -> np.ndarray:
    opaque = sprite[:, :, 3] > 20
    ys, xs = np.where(opaque)
    if len(xs) == 0:
        raise SystemExit("prop crop has no pixels")
    crop = sprite[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    scale = min(max_w / crop.shape[1], max_h / crop.shape[0], 1.0)
    out_w = max(8, int(round(crop.shape[1] * scale)))
    out_h = max(8, int(round(crop.shape[0] * scale)))
    img = Image.fromarray(crop).resize((out_w, out_h), Image.Resampling.LANCZOS)
    arr = np.asarray(img).copy()
    arr[arr[:, :, 3] < 16] = 0
    return arr


def _key_scene(rgb: np.ndarray) -> np.ndarray:
    """Drop the white page. Keep the painted prop."""
    src = rgb.astype(np.float32)
    lum = src.mean(2)
    alpha = np.where(lum > 205.0, 0.0, 1.0)
    band = (lum > 180.0) & (lum <= 205.0)
    alpha[band] = np.clip((205.0 - lum[band]) / 25.0, 0.0, 1.0)
    out = np.zeros((src.shape[0], src.shape[1], 4), np.uint8)
    out[:, :, :3] = np.clip(src, 0, 255).astype(np.uint8)
    out[:, :, 3] = (alpha * 255.0).astype(np.uint8)
    out[out[:, :, 3] < 16] = 0
    return out


def _trim_floor(arr: np.ndarray) -> np.ndarray:
    """Cut a wide dark floor that came along with the prop base."""
    opaque = arr[:, :, 3] > 20
    widths = opaque.sum(1)
    body = widths[widths > 0]
    if body.size == 0:
        return arr
    med = float(np.median(body))
    cut = arr.shape[0]
    for y in range(arr.shape[0] - 1, arr.shape[0] // 2, -1):
        if widths[y] > med * 1.8:
            cut = y
        else:
            break
    if cut < arr.shape[0]:
        arr = arr[:cut]
    ys, xs = np.where(arr[:, :, 3] > 20)
    if len(xs) == 0:
        return arr
    return arr[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]


def _standing_props(sheet: np.ndarray) -> list[dict]:
    """Pillars and banners stick above the board edge. The floor stays put."""
    lum = sheet.astype(np.float32).mean(2)
    content = lum < 200.0
    height, width = content.shape
    top = np.full(width, height - 1, np.int32)
    for x in range(width):
        ys = np.where(content[:, x])[0]
        if len(ys):
            top[x] = int(ys[0])
    valid = top < int(height * 0.92)
    fallback = int(np.median(top[valid])) if valid.any() else height // 2
    edge = ndimage.maximum_filter1d(np.where(valid, top, fallback), size=90, mode="nearest")
    protrude = edge.astype(np.int32) - top
    mask = valid & (protrude > 70)
    runs: list[tuple[int, int]] = []
    start = 0
    inside = False
    for x in range(width):
        if mask[x] and not inside:
            start = x
            inside = True
        elif not mask[x] and inside:
            runs.append((start, x - 1))
            inside = False
    if inside:
        runs.append((start, width - 1))
    sprites = []
    for a, b in runs:
        span = b - a + 1
        if span < 18 or span > 160:
            continue
        pad = 6
        x0 = max(0, a - pad)
        x1 = min(width - 1, b + pad)
        y0 = max(0, int(top[a : b + 1].min()) - 2)
        y1 = min(height - 1, int(np.median(edge[a : b + 1])) + 10)
        if y1 - y0 < 80:
            continue
        crop = _trim_floor(_key_scene(sheet[y0 : y1 + 1, x0 : x1 + 1]))
        opaque = crop[:, :, 3] > 20
        if int(opaque.sum()) < 400:
            continue
        red = crop[:, :, 0].astype(np.float32)
        green = crop[:, :, 1].astype(np.float32)
        cloth = opaque & (red > green + 30.0) & (red > 80.0)
        sprites.append(
            {
                "img": crop,
                "w": int(crop.shape[1]),
                "h": int(crop.shape[0]),
                "at": (x0, y0),
                "area": int(opaque.sum()),
                "red": float(cloth.sum()) / float(max(int(opaque.sum()), 1)),
            }
        )
    return sprites


def _chip_from(path: Path, size: tuple[int, int]) -> np.ndarray:
    """A small south-tip mark. It does not replace the diamond."""
    src = Image.open(path).convert("RGBA").resize(size, Image.Resampling.LANCZOS)
    arr = np.asarray(src).copy()
    mask = _iso_mask(arr.shape[1], arr.shape[0])
    arr[:, :, 3] = np.where(mask, 255, 0).astype(np.uint8)
    _rim(arr, mask)
    return arr


def _slice_props() -> list[dict]:
    sheet = np.asarray(Image.open(PROPS_SHEET).convert("RGB"))
    standing = _standing_props(sheet)
    banners = [s for s in standing if s["red"] >= 0.08 and s["h"] >= s["w"]]
    pillars = [s for s in standing if s["red"] < 0.08 and s["h"] >= s["w"] * 1.15]
    if not banners or len(pillars) < 2:
        raise SystemExit(f"need 2 pillars and 1 banner, found {len(pillars)} and {len(banners)}")
    basalt = max(pillars, key=lambda s: s["area"])
    rock_pillar = min((s for s in pillars if s is not basalt), key=lambda s: s["w"] / max(s["h"], 1))
    banner = max(banners, key=lambda s: s["h"] / max(s["w"], 1))
    assigned = {
        "slag_prop_basalt_pillar.png": basalt,
        "slag_prop_rock_pillar.png": rock_pillar,
        "slag_prop_banner.png": banner,
    }
    records = []
    for name, sprite in assigned.items():
        arr = _scale_prop(sprite["img"], *PROP_BOX[name])
        limit = 40 if "rock_pillar" in name or "banner" in name else 48
        if arr.shape[1] > limit:
            raise SystemExit(f"{name} is too wide for one tile ({arr.shape[1]})")
        if arr.shape[0] <= arr.shape[1]:
            raise SystemExit(f"{name} does not stand ({arr.shape[1]}x{arr.shape[0]})")
        _save_arr(name, arr, records, sprite["at"], "prop")
        print(
            f"{name:28} {arr.shape[1]:3}x{arr.shape[0]:<3} "
            f"from {sprite['w']}x{sprite['h']} red {sprite['red']:.2f} at {sprite['at']}"
        )
    chips = {
        "slag_prop_ash_rock.png": TILES / "slag_ground.png",
        "slag_prop_rubble.png": TILES / "slag_ground_v1.png",
        "slag_prop_steam_vent.png": TILES / "slag_lava.png",
    }
    for name, src in chips.items():
        arr = _chip_from(src, PROP_BOX[name])
        if arr.shape[0] >= 32 or arr.shape[1] >= 40:
            raise SystemExit(f"{name} covers the diamond")
        _save_arr(name, arr, records, (0, 0), "prop")
        print(f"{name:28} {arr.shape[1]:3}x{arr.shape[0]:<3} small mark")
    return records


def _save_arr(name: str, arr: np.ndarray, records: list, anchor, kind: str) -> None:
    _require_clean(name, arr)
    img = Image.fromarray(arr)
    img.save(TILES / name)
    records.append(
        {
            "file": name,
            "anchor": [int(anchor[0]), int(anchor[1])],
            "fit": kind,
            "size": [img.size[0], img.size[1]],
            "source": "pending/lava",
        }
    )


def _patch_atlas(records: list[dict]) -> None:
    atlas = json.loads(ATLAS.read_text())
    sheets = list(atlas.get("source_sheets") or [])
    for sheet in (
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
        "pending/brinewake/brine_ground_punch.png",
        "pending/brinewake/brine_elevation_punch.png",
        "pending/brinewake/brine_props_punch.png",
    ):
        if sheet not in sheets:
            sheets.append(sheet)
    atlas["source_sheets"] = sheets
    promoted = atlas.get("promoted") or {}
    promoted["lava"] = "pending/lava/ground_punch.png"
    atlas["promoted"] = promoted
    atlas["slagcrown_punch"] = {
        "ground": "pending/lava/ground_punch.png",
        "elevation": "pending/lava/elevation_punch.png",
        "props": "pending/lava/props_punch.png",
        "mood": "pending/lava/board_mood_punch.png",
        "note": "Live Slagcrown paint is scenario punch v4. Mood plate is reference only. Geometry and tags stay on the Locked map. Six tall props: corner pillars and two banners.",
    }
    written = {item["file"] for item in records}
    kept = [item for item in atlas.get("files", []) if item.get("file") not in written]
    atlas["files"] = kept + records
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


def _dress_names(x: int, y: int, props: list) -> list[str]:
    """Six tall props. Other cells keep a small mark. Tags are not edited."""
    if not props:
        return []
    if (x, y) in TALL_DRESS:
        return [TALL_DRESS[(x, y)]]
    names = []
    for prop in props:
        if prop in ("floor_seal", "steam_vent", "rubble"):
            names.append(prop)
        else:
            names.append("ash_rock")
    return names


def _tile_stem(cell: dict) -> str:
    if cell["elevation"] >= 2:
        return "slag_ground_e2"
    if cell["elevation"] == 1:
        return "slag_mud_e1" if cell["terrain"] == "mud" else "slag_ground_e1"
    if cell["terrain"] == "water":
        return "slag_water"
    if cell["terrain"] == "lava":
        return "slag_lava"
    if cell["terrain"] == "mud":
        return "slag_mud"
    return "slag_ground"


def _variants(stem: str) -> list[str]:
    names = [stem]
    i = 1
    while (TILES / f"{stem}_v{i}.png").is_file():
        names.append(f"{stem}_v{i}")
        i += 1
    return names


def _render_board(cells: list) -> Image.Image:
    def local(x: int, y: int) -> tuple[int, int]:
        return ((x - y) * 32, (x + y) * 16)

    pts = [local(x, y) for y in range(15) for x in range(15)]
    min_x = min(p[0] for p in pts) - 48
    max_x = max(p[0] for p in pts) + 48
    min_y = min(p[1] for p in pts) - 48
    max_y = max(p[1] for p in pts) + 120
    width = int(max_x - min_x + 160)
    height = int(max_y - min_y + 180)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    cache: dict[str, Image.Image] = {}

    def get(name: str) -> Image.Image:
        if name not in cache:
            cache[name] = Image.open(TILES / f"{name}.png").convert("RGBA")
        return cache[name]

    order = sorted(((x, y) for y in range(15) for x in range(15)), key=lambda p: (p[0] + p[1], p[0]))
    for x, y in order:
        cell = cells[y][x]
        stem = _tile_stem(cell)
        names = _variants(stem)
        pick = (x * 13 + y * 29 + int(cell["elevation"]) * 7) % len(names)
        tile = get(names[pick])
        lx, ly = local(x, y)
        px = int(lx - min_x + 80 - 32)
        py = int(ly - min_y + 80)
        if tile.height > 32:
            py -= tile.height - 32
        canvas.alpha_composite(tile, (px, py))
        for prop in _dress_names(x, y, cell["paint_only"]):
            prop_img = get(f"slag_prop_{prop}")
            ppx = px + 32 - prop_img.width // 2
            ppy = py + 32 - prop_img.height
            canvas.alpha_composite(prop_img, (ppx, ppy))
    return canvas


def _write_previews(cells: list) -> None:
    board = _render_board(cells)
    plain = Image.new("RGB", board.size, (12, 10, 10))
    plain.paste(board, mask=board.split()[-1])
    min_x = min((x - y) * 32 for y in range(15) for x in range(15)) - 48
    min_y = min((x + y) * 16 for y in range(15) for x in range(15)) - 48
    ink = ImageDraw.Draw(plain)
    for y in range(15):
        for x in range(15):
            lx, ly = (x - y) * 32, (x + y) * 16
            ox = lx - min_x + 80
            oy = ly - min_y + 80
            diamond = [(ox, oy), (ox + 32, oy + 16), (ox, oy + 32), (ox - 32, oy + 16)]
            ink.line(diamond + [diamond[0]], fill=(176, 92, 42), width=1)
    plain_path = ROOT / "slagcrown_15x15_preview.png"
    plain.save(plain_path, optimize=True)

    plate = Image.new("RGB", (1280, 720), (14, 10, 10))
    grad = ImageDraw.Draw(plate)
    for i in range(720):
        t = i / 720
        grad.line([(0, i), (1279, i)], fill=(int(22 - 10 * t), int(14 - 6 * t), int(12 - 6 * t)))
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
    banner.rounded_rectangle([360, 16, 920, 58], radius=8, fill=(28, 16, 12))
    banner.text((378, 26), "15×15 Slagcrown · fire and lava", font=font, fill=(255, 214, 170))
    painted = ROOT / "slagcrown_15x15_painted_preview.png"
    plate.save(painted, optimize=True, quality=92)
    print(f"preview {plain_path.name} {plain.size[0]}x{plain.size[1]}")
    print(f"painted {painted.name}")


def slice_slagcrown() -> list[dict]:
    for path in (GROUND_SHEET, ELEV_SHEET, PROPS_SHEET, TAGS, TMX):
        if not path.is_file():
            raise SystemExit(f"missing {path}")
    before = (_sha(TAGS), _sha(TMX))
    records = []
    records.extend(_slice_ground())
    records.extend(_slice_elevation())
    records.extend(_slice_props())
    after = (_sha(TAGS), _sha(TMX))
    if before != after:
        raise SystemExit("Slagcrown tags or tmx changed")
    return records


def main() -> None:
    records = slice_slagcrown()
    _patch_atlas(records)
    _sync_tsx()
    _write_previews(_load_cells())
    print(f"sliced {len(records)} slagcrown lava/rock files")


if __name__ == "__main__":
    main()
