#!/usr/bin/env python3
"""Rejected Crosshaven earth punch. Not the live dress.

The board paints original-tileset-b.jpg grassland slices. Running this
script overwrites that restore. Soft lock: tierra + naturaleza. Dirt and
roots stay accents, so a green lawn is not the ground. Reads the punch
sheets in this folder and overwrites only the Crosshaven paths:

  ground.png and ground_vN.png
  ground_e1.png, ground_e2.png, and their _vN siblings
  mud_e1.png
  prop_ruins, prop_well, prop_hay, prop_fence, prop_rubble, prop_rock_pillar

Water and the lighter mud stay on original-tileset-b.jpg so those tags
still read apart from the dirt. Floor seal stays the original stone mark.
Tags, geometry, and combat numbers are not touched.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from slice_original_tileset import ATLAS, TILES, _sync_tsx

HERE = Path(__file__).resolve().parent
GROUND_SHEET = HERE / "crosshaven_ground_punch.png"
ELEV_SHEET = HERE / "crosshaven_elevation_punch.png"
PROPS_SHEET = HERE / "crosshaven_props_punch.png"

# Index on the props punch, then how the sprite is scaled onto a cell.
# height / width / long (the longer side).
PROPS = {
    "prop_rock_pillar.png": (0, "height", 88),
    "prop_rubble.png": (2, "width", 86),
    "prop_well.png": (4, "long", 64),
    "prop_ruins.png": (6, "height", 84),
    "prop_hay.png": (5, "width", 60),
    "prop_fence.png": (7, "width", 72),
}


def _components(arr: np.ndarray, min_area: int) -> list:
    rgb = arr[:, :, :3].astype(np.float32)
    alpha = arr[:, :, 3]
    lum = rgb.mean(2)
    if int(alpha.min()) < 250:
        content = alpha > 16
    else:
        content = lum > 12
    content = ndimage.binary_opening(content, iterations=1)
    lab, _ = ndimage.label(content)
    comps = []
    for i, sl in enumerate(ndimage.find_objects(lab), start=1):
        if sl is None:
            continue
        ys, xs = sl
        height = ys.stop - ys.start
        width = xs.stop - xs.start
        area = int((lab[sl] == i).sum())
        if area < min_area or height < 20 or width < 20:
            continue
        comps.append((ys.start, xs.start, ys.stop, xs.stop, i, lab))
    comps.sort(key=lambda comp: (comp[0] // 30, comp[1]))
    return comps


def _cut(arr: np.ndarray, comp) -> np.ndarray:
    y0, x0, y1, x1, index, lab = comp
    crop = arr[y0:y1, x0:x1, :3]
    mask = lab[y0:y1, x0:x1] == index
    mask = ndimage.binary_fill_holes(mask)
    rgba = np.zeros((crop.shape[0], crop.shape[1], 4), np.uint8)
    rgba[:, :, :3] = np.clip(crop, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.where(mask, 255, 0).astype(np.uint8)
    ys, xs = np.where(mask)
    return rgba[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]


def _fit_flat(rgba: np.ndarray) -> Image.Image:
    ys, xs = np.where(rgba[:, :, 3] > 24)
    crop = rgba[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    spr = Image.fromarray(crop).resize((64, 32), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    arr[arr[:, :, 3] < 8] = 0
    return Image.fromarray(arr)


def _fit_cliff(rgba: np.ndarray) -> Image.Image:
    """Equator of the cap becomes 64px. The wall under that cap hangs below."""
    solid = rgba[:, :, 3] > 40
    widths = solid.sum(1)
    face_w = max(int(widths.max()) if len(widths) else 1, 8)
    scale = 64.0 / float(face_w)
    out_w = max(64, int(round(rgba.shape[1] * scale)))
    out_h = max(33, int(round(rgba.shape[0] * scale)))
    spr = Image.fromarray(rgba).resize((out_w, out_h), Image.Resampling.LANCZOS)
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


def _fit_prop(rgba: np.ndarray, mode: str, target: int) -> Image.Image:
    ys, xs = np.where(rgba[:, :, 3] > 20)
    crop = rgba[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    height, width = crop.shape[:2]
    if mode == "height":
        scale = float(target) / float(height)
    elif mode == "width":
        scale = float(target) / float(width)
    else:
        scale = float(target) / float(max(width, height))
    out_w = max(8, int(round(width * scale)))
    out_h = max(8, int(round(height * scale)))
    spr = Image.fromarray(crop).resize((out_w, out_h), Image.Resampling.LANCZOS)
    arr = np.asarray(spr).copy()
    arr[arr[:, :, 3] < 8] = 0
    return Image.fromarray(arr)


def _names(key: str, count: int) -> list[str]:
    names = [f"{key}.png"]
    for i in range(1, count):
        names.append(f"{key}_v{i}.png")
    return names


def _mean_rgb(img: Image.Image) -> tuple[float, float, float]:
    arr = np.asarray(img).astype(np.float32)
    mask = arr[:, :, 3] > 40
    px = arr[mask][:, :3]
    return tuple(float(v) for v in px.mean(0))


def _green_fraction(img: Image.Image) -> float:
    arr = np.asarray(img).astype(np.float32) / 255.0
    green = 0
    count = 0
    for y in range(arr.shape[0]):
        for x in range(arr.shape[1]):
            px = arr[y, x]
            if px[3] < 0.15:
                continue
            count += 1
            if px[1] > px[0] + 0.07 and px[1] > px[2] + 0.05 and px[1] > 0.23:
                green += 1
    return float(green) / float(max(count, 1))


def _save(name: str, img: Image.Image, records: list, anchor: list) -> None:
    img.save(TILES / name)
    records.append(
        {
            "file": name,
            "anchor": anchor,
            "fit": "punch",
            "size": [img.size[0], img.size[1]],
        }
    )
    print(f"{name:28} {img.size[0]:3}x{img.size[1]:<3}")


def _patch_atlas(records: list) -> None:
    atlas = json.loads(ATLAS.read_text())
    sheets = list(atlas.get("source_sheets", []))
    for name in (
        "crosshaven_ground_punch.png",
        "crosshaven_elevation_punch.png",
        "crosshaven_props_punch.png",
    ):
        if name not in sheets:
            sheets.append(name)
    atlas["source_sheets"] = sheets
    atlas["families"]["crosshaven"] = {
        "pack": "earth",
        "prefix": "",
        "pending_theme": None,
    }
    written = {item["file"] for item in records}
    kept = [item for item in atlas.get("files", []) if item.get("file") not in written]
    atlas["files"] = kept + records
    ATLAS.write_text(json.dumps(atlas, indent=2) + "\n")


def main() -> None:
    raise SystemExit(
        "Crosshaven earth punch is not the live dress. "
        "The board paints original-tileset-b.jpg grassland slices."
    )
    for path in (GROUND_SHEET, ELEV_SHEET, PROPS_SHEET):
        if not path.is_file():
            raise SystemExit(f"missing punch sheet {path}")
    ground = np.asarray(Image.open(GROUND_SHEET).convert("RGBA"))
    elev = np.asarray(Image.open(ELEV_SHEET).convert("RGBA"))
    props = np.asarray(Image.open(PROPS_SHEET).convert("RGBA"))
    ground_comps = _components(ground, 4000)
    elev_comps = _components(elev, 4000)
    prop_comps = _components(props, 800)
    if len(ground_comps) < 5:
        raise SystemExit(f"ground punch has {len(ground_comps)} sprites, need at least 5")
    if len(elev_comps) < 2:
        raise SystemExit(f"elevation punch has {len(elev_comps)} sprites")
    records: list = []

    step = max(1, len(ground_comps) // 8)
    picks = list(range(0, len(ground_comps), step))[:8]
    for name, index in zip(_names("ground", len(picks)), picks):
        img = _fit_flat(_cut(ground, ground_comps[index]))
        _save(name, img, records, ["ground", index])
    primary = Image.open(TILES / "ground.png")
    red, green, blue = _mean_rgb(primary)
    lawn = _green_fraction(primary)
    if not (red > green > blue and lawn < 0.05):
        raise SystemExit(
            f"ground punch is not dirt/stone (mean {red:.0f},{green:.0f},{blue:.0f} lawn {lawn:.3f})"
        )
    print(f"ground mean {red:.0f},{green:.0f},{blue:.0f} lawn {lawn:.3f}")

    cliffs = []
    for index, comp in enumerate(elev_comps):
        img = _fit_cliff(_cut(elev, comp))
        if img.size[0] != 64 or img.size[1] <= 32:
            print(f"skip elev {index} {img.size} (no hanging wall)")
            continue
        cliffs.append((img.size[1], index, img))
    cliffs.sort()
    short = [item for item in cliffs if item[0] < 64]
    tall = [item for item in cliffs if item[0] >= 64]
    if not short or not tall:
        raise SystemExit(f"need a low cliff and a high cliff, got heights {[c[0] for c in cliffs]}")
    # Primary files are what KoliseoArt.terrain_texture returns. The high
    # primary has to be taller than the low primary.
    e1 = [short[len(short) // 2]] + short[: len(short) // 2] + short[len(short) // 2 + 1 :]
    e2 = [tall[-1]] + tall[:-1]
    e1 = e1[:8]
    e2 = e2[:8]
    if e2[0][0] <= e1[0][0]:
        raise SystemExit("elevation 2 is not taller than elevation 1")
    for name, (_height, index, img) in zip(_names("ground_e1", len(e1)), e1):
        _save(name, img, records, ["elev", index])
    for name, (_height, index, img) in zip(_names("ground_e2", len(e2)), e2):
        _save(name, img, records, ["elev", index])
    _save("mud_e1.png", e1[min(1, len(e1) - 1)][2], records, ["elev", e1[min(1, len(e1) - 1)][1]])

    if len(prop_comps) <= max(spec[0] for spec in PROPS.values()):
        raise SystemExit(f"props punch has {len(prop_comps)} sprites")
    for name, (index, mode, target) in PROPS.items():
        img = _fit_prop(_cut(props, prop_comps[index]), mode, target)
        _save(name, img, records, ["prop", index])
        if name == "prop_ruins.png" and img.size[1] <= 32:
            raise SystemExit("ruins must stand above the diamond")

    _sync_tsx()
    _patch_atlas(records)
    _accents()
    print(f"sliced {len(records)} Crosshaven earth files")


def _accents() -> None:
    """Moss sits in the ruin walls only. The field and the floor seal stay bare."""
    _moss_on_ruin_walls(TILES / "prop_ruins.png")
    _clear_seal_moss(TILES / "prop_floor_seal.png")


def _moss_on_ruin_walls(path: Path) -> None:
    arr = np.asarray(Image.open(path).convert("RGBA")).copy()
    height, width = arr.shape[:2]
    rgb = arr[:, :, :3].astype(np.float32)
    opaque = arr[:, :, 3] > 40
    ys = np.where(opaque)[0]
    if len(ys) == 0:
        raise SystemExit(f"{path.name} has no pixels")
    y0 = int(ys.min())
    span = max(1, int(ys.max()) - y0)
    rows = np.arange(height)[:, None]
    cap = opaque & ((rows - y0) < span * 0.22)
    wall = opaque & ~cap
    lum = rgb.mean(2)
    thr = float(np.percentile(lum[wall], 55))
    face = wall & (lum <= thr)
    yy, xx = np.indices((height, width))
    moss = face & (((xx * 17 + yy * 31) % 13) < 4)
    rgb[moss, 0] *= 0.72
    rgb[moss, 1] = np.clip(rgb[moss, 1] * 0.92 + 34.0, 0, 255)
    rgb[moss, 2] *= 0.64
    arr[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    Image.fromarray(arr).save(path)
    covered = float(moss.sum()) / float(max(int(opaque.sum()), 1))
    print(f"ruin wall moss {covered:.3f}")
    if not 0.08 <= covered <= 0.20:
        raise SystemExit(f"ruin moss coverage {covered:.3f} is outside the wall accent")


def _clear_seal_moss(path: Path) -> None:
    if not path.is_file():
        return
    arr = np.asarray(Image.open(path).convert("RGBA")).copy()
    rgb = arr[:, :, :3].astype(np.float32)
    green = (arr[:, :, 3] > 20) & (rgb[:, :, 1] > rgb[:, :, 0])
    rgb[:, :, 1] = np.where(green, rgb[:, :, 0] * 0.96, rgb[:, :, 1])
    arr[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    Image.fromarray(arr).save(path)
    print(f"floor seal moss pixels cleared {int(green.sum())}")


if __name__ == "__main__":
    main()
