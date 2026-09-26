#!/usr/bin/env python3
"""Slice the original isometric contact sheet onto the Koliseo 64×32 grid.

Reads art/tilesets/original/original-tileset-b.jpg and writes the board PNGs
in art/maps/arena_colosseum_v2/tiled/tiles/. Flat tiles fill the diamond.
Cliff tiles keep a 64×32 top face and hang the face below it. Props are
uniformly scaled to that same ground scale.

Ice and electric packs are not created. pending/ice and pending/electric
are hooks for the scenario sheets.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent
SHEET = HERE / "original-tileset-b.jpg"
TILES = HERE.parents[1] / "maps" / "arena_colosseum_v2" / "tiled" / "tiles"
TSX = TILES.parent / "tileset_koliseo_base.tsx"
ATLAS = HERE / "atlas_map.json"

BG = np.array([247.0, 247.0, 247.0], np.float32)
# Ground diamonds on the sheet are about 90px wide. Props use the same scale
# so a fence matches a cell.
PROP_SCALE = 64.0 / 90.0

FLAT = "flat"
CLIFF = "cliff"
PROP = "prop"
FLAT_PROP = "flat_prop"

# Top-left of each connected sprite on original-tileset-b.jpg.
GRASS = [(16, 48), (16, 112), (220, 112), (15, 189), (218, 188)]
SAND = [(318, 48), (117, 188)]
COBBLE = [(317, 112)]
STONE = [(315, 187)]
CRACKED = [(416, 48)]
DARK = [(1359, 192)]
WATER = [(1257, 48), (1361, 48), (1152, 48)]
LAVA = [(1045, 192), (1153, 193)]
GRASS_LOW = [(16, 350)]
GRASS_TALL = [(395, 319)]
STONE_BLOCK = [(310, 345)]

# prefix -> terrain key -> (fit, anchors). First anchor is the primary PNG.
PACKS = {
    "": {
        "ground": (FLAT, GRASS),
        "mud": (FLAT, SAND),
        "water": (FLAT, WATER),
        "lava": (FLAT, LAVA),
        "ground_e1": (CLIFF, GRASS_LOW),
        "ground_e2": (CLIFF, GRASS_TALL),
        "mud_e1": (CLIFF, GRASS_LOW),
    },
    "brine_": {
        "ground": (FLAT, COBBLE + STONE),
        "mud": (FLAT, SAND),
        "water": (FLAT, [(1361, 48), (1257, 48)]),
        "ground_e1": (CLIFF, STONE_BLOCK),
        "ground_e2": (CLIFF, STONE_BLOCK),
        "mud_e1": (CLIFF, STONE_BLOCK),
    },
    "slag_": {
        "ground": (FLAT, CRACKED + DARK),
        "mud": (FLAT, CRACKED),
        "water": (FLAT, [(1361, 48)]),
        "lava": (FLAT, LAVA),
        "ground_e1": (CLIFF, STONE_BLOCK),
        "ground_e2": (CLIFF, STONE_BLOCK),
        "mud_e1": (CLIFF, STONE_BLOCK),
    },
    # Pale stone from the sheet. Not an ice pack.
    "wind_": {
        "ground": (FLAT, STONE + COBBLE),
        "mud": (FLAT, SAND[:1]),
        "water": (FLAT, [(1152, 48), (1257, 48)]),
        "ground_e1": (CLIFF, STONE_BLOCK),
        "ground_e2": (CLIFF, STONE_BLOCK),
        "mud_e1": (CLIFF, STONE_BLOCK),
    },
    # Dark rock from the sheet. Not an electric pack.
    "storm_": {
        "ground": (FLAT, DARK + CRACKED),
        "mud": (FLAT, CRACKED),
        "water": (FLAT, [(1361, 48), (1257, 48)]),
        "ground_e1": (CLIFF, STONE_BLOCK),
        "ground_e2": (CLIFF, STONE_BLOCK),
        "mud_e1": (CLIFF, STONE_BLOCK),
    },
}

PROPS = {
    "prop_ruins.png": (PROP, (531, 438)),
    "prop_well.png": (PROP, (1161, 750)),
    "prop_hay.png": (PROP, (411, 796)),
    "prop_fence.png": (PROP, (1194, 641)),
    "prop_rubble.png": (PROP, (712, 638)),
    "prop_rock_pillar.png": (PROP, (1336, 732)),
    "prop_floor_seal.png": (FLAT_PROP, (315, 187)),
    "prop_driftwood.png": (PROP, (291, 896)),
    "prop_waterfall.png": (PROP, (514, 752)),
    "prop_rock_cluster.png": (PROP, (605, 650)),
    "prop_basalt_pillar.png": (PROP, (637, 773)),
    "prop_steam_vent.png": (PROP, (979, 739)),
    "prop_ash_rock.png": (PROP, (521, 657)),
    "prop_crystal.png": (PROP, (865, 772)),
    "prop_ice_shard.png": (PROP, (1462, 147)),
    "prop_ice_sheet.png": (FLAT_PROP, (315, 187)),
    "prop_spark.png": (PROP, (19, 905)),
    "prop_conduit.png": (PROP, (1336, 732)),
    "prop_crystal_bolt.png": (PROP, (1029, 828)),
    "prop_arc.png": (PROP, (937, 316)),
}


def _components(arr: np.ndarray):
    mx = arr.max(axis=2)
    mn = arr.min(axis=2)
    content = ndimage.binary_opening(~((mn > 228) & ((mx - mn) < 22)), iterations=1)
    lab, _ = ndimage.label(content)
    objs = ndimage.find_objects(lab)
    comps = []
    for i, sl in enumerate(objs, start=1):
        if sl is None:
            continue
        ys, xs = sl
        h = ys.stop - ys.start
        w = xs.stop - xs.start
        area = int((lab[sl] == i).sum())
        if area < 80 or h < 8 or w < 8:
            continue
        comps.append((ys.start, xs.start, ys, xs, i, lab))
    return comps


def _nearest(comps, x: int, y: int, tol: int = 14):
    best = None
    bestd = 1e9
    for comp in comps:
        d = (comp[1] - x) ** 2 + (comp[0] - y) ** 2
        if d < bestd:
            bestd = d
            best = comp
    if best is None or bestd > tol * tol:
        raise SystemExit(f"no sprite near ({x}, {y}); closest dist^2={bestd}")
    return best


def _cut(arr: np.ndarray, comps, x: int, y: int) -> np.ndarray:
    yy, xx, ys, xs, i, lab = _nearest(comps, x, y)
    crop = arr[ys, xs].astype(np.float32)
    mask = ndimage.binary_dilation(lab[ys, xs] == i, iterations=1)
    dist = np.linalg.norm(crop - BG, axis=2)
    alpha = np.clip((dist - 16.0) / 22.0, 0.0, 1.0)
    alpha = np.where(mask, alpha, 0.0)
    safe = np.maximum(alpha, 0.18)[:, :, None]
    color = np.clip(BG + (crop - BG) / safe, 0, 255)
    out = np.zeros((crop.shape[0], crop.shape[1], 4), np.uint8)
    out[:, :, :3] = color.astype(np.uint8)
    out[:, :, 3] = (alpha * 255.0).astype(np.uint8)
    out[out[:, :, 3] < 8] = 0
    return out


def _opaque_bounds(rgba: np.ndarray, thresh: int = 24):
    ys, xs = np.where(rgba[:, :, 3] > thresh)
    if len(xs) == 0:
        raise SystemExit("sprite has no opaque pixels")
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def _fit_flat(rgba: np.ndarray) -> Image.Image:
    x0, y0, x1, y1 = _opaque_bounds(rgba)
    crop = rgba[y0 : y1 + 1, x0 : x1 + 1]
    spr = Image.fromarray(crop).resize((64, 32), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    arr[arr[:, :, 3] < 8] = 0
    return Image.fromarray(arr)


def _fit_cliff(rgba: np.ndarray) -> Image.Image:
    x0, y0, x1, y1 = _opaque_bounds(rgba, 30)
    body = rgba[y0 : y1 + 1, x0 : x1 + 1]
    solid = body[:, :, 3] > 40
    widths = solid.sum(axis=1)
    maxw = int(widths.max()) if len(widths) else 1
    eq = int(np.argmax(widths >= max(1, int(maxw * 0.92))))
    face_h = max(eq * 2, 8)
    face_h = min(face_h, body.shape[0])
    if face_h > body.shape[0] * 0.82:
        return _fit_flat(rgba)
    cols = np.where(solid[min(eq, body.shape[0] - 1)])[0]
    face_w = int(cols.max() - cols.min() + 1) if len(cols) else body.shape[1]
    face_w = max(face_w, 8)
    scale_x = 64.0 / face_w
    scale_y = 32.0 / face_h
    out_w = max(64, int(round(body.shape[1] * scale_x)))
    out_h = max(32, int(round(body.shape[0] * scale_y)))
    spr = Image.fromarray(body).resize((out_w, out_h), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    arr[arr[:, :, 3] < 8] = 0
    # Put the top-face center on x=32 so the diamond sits on the cell
    # even if the cliff body is wider than the cap.
    solid_o = arr[:, :, 3] > 40
    cap = solid_o[: min(32, arr.shape[0])]
    if cap.any():
        xs = np.where(cap.any(axis=0))[0]
        shift = int(round(32 - (xs.min() + xs.max()) / 2.0))
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
            # Keep a 64-wide window centered on the cap we just placed.
            left = max(0, min(arr.shape[1] - 64, 0))
            arr = arr[:, left : left + 64]
    return Image.fromarray(arr)


def _fit_prop(rgba: np.ndarray) -> Image.Image:
    x0, y0, x1, y1 = _opaque_bounds(rgba, 20)
    crop = rgba[y0 : y1 + 1, x0 : x1 + 1]
    w = max(8, int(round(crop.shape[1] * PROP_SCALE)))
    h = max(8, int(round(crop.shape[0] * PROP_SCALE)))
    longest = max(w, h)
    if longest > 128:
        s = 128.0 / longest
        w = max(8, int(round(w * s)))
        h = max(8, int(round(h * s)))
    spr = Image.fromarray(crop).resize((w, h), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    arr[arr[:, :, 3] < 8] = 0
    return Image.fromarray(arr)


def _fit(kind: str, rgba: np.ndarray) -> Image.Image:
    if kind == FLAT or kind == FLAT_PROP:
        return _fit_flat(rgba)
    if kind == CLIFF:
        return _fit_cliff(rgba)
    if kind == PROP:
        return _fit_prop(rgba)
    raise SystemExit(kind)


def _names(prefix: str, key: str, count: int) -> list[str]:
    primary = f"{prefix}{key}.png"
    names = [primary]
    for i in range(1, count):
        names.append(f"{prefix}{key}_v{i}.png")
    return names


def _sync_tsx() -> None:
    if not TSX.is_file():
        return
    text = TSX.read_text()
    import re

    def repl(match: re.Match) -> str:
        src = match.group(1)
        path = TILES / Path(src).name
        if not path.is_file():
            return match.group(0)
        with Image.open(path) as im:
            return f'<image source="{src}" width="{im.size[0]}" height="{im.size[1]}"/>'

    updated = re.sub(
        r'<image source="([^"]+)" width="\d+" height="\d+"/>',
        repl,
        text,
    )
    if updated != text:
        TSX.write_text(updated)


def main() -> None:
    if not SHEET.is_file():
        raise SystemExit(f"missing sheet {SHEET}")
    arr = np.asarray(Image.open(SHEET).convert("RGB"))
    comps = _components(arr)
    TILES.mkdir(parents=True, exist_ok=True)
    written = []

    for prefix, terrains in PACKS.items():
        for key, (kind, anchors) in terrains.items():
            names = _names(prefix, key, len(anchors))
            for name, anchor in zip(names, anchors):
                img = _fit(kind, _cut(arr, comps, anchor[0], anchor[1]))
                path = TILES / name
                img.save(path)
                written.append(
                    {
                        "file": name,
                        "anchor": [anchor[0], anchor[1]],
                        "fit": kind,
                        "size": [img.size[0], img.size[1]],
                    }
                )
                print(f"{name:24} {img.size[0]:3}x{img.size[1]:<3} from {anchor}")

    void = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    void.save(TILES / "void.png")
    written.append({"file": "void.png", "anchor": None, "fit": "empty", "size": [64, 32]})

    for name, (kind, anchor) in PROPS.items():
        img = _fit(kind, _cut(arr, comps, anchor[0], anchor[1]))
        img.save(TILES / name)
        written.append(
            {
                "file": name,
                "anchor": [anchor[0], anchor[1]],
                "fit": kind,
                "size": [img.size[0], img.size[1]],
            }
        )
        print(f"{name:24} {img.size[0]:3}x{img.size[1]:<3} from {anchor}")

    _sync_tsx()
    atlas = {
        "source_sheets": ["original-tileset-a.jpg", "original-tileset-b.jpg"],
        "sliced_from": "original-tileset-b.jpg",
        "grid": [64, 32],
        "families": {
            "crosshaven": {
                "pack": "grassland",
                "prefix": "",
                "pending_theme": None,
            },
            "brinewake": {
                "pack": "coast",
                "prefix": "brine_",
                "pending_theme": None,
            },
            "slagcrown": {
                "pack": "lava",
                "prefix": "slag_",
                "pending_theme": None,
            },
            "windmere": {
                "pack": "pale_stone",
                "prefix": "wind_",
                "pending_theme": "ice",
            },
            "stormspire": {
                "pack": "dark_stone",
                "prefix": "storm_",
                "pending_theme": "electric",
            },
        },
        "pending": {
            "ice": "pending/ice/",
            "electric": "pending/electric/",
        },
        "files": written,
    }
    ATLAS.write_text(json.dumps(atlas, indent=2) + "\n")
    print(f"wrote {len(written)} tiles")


if __name__ == "__main__":
    main()
