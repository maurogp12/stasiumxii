#!/usr/bin/env python3
"""Slice the Windmere punch sheets onto the ice dress.

Soft Lock: hielo + agua + sparse crystals. Presentation only.
Reads the punch contact sheets and overwrites wind_* terrain and wind_prop_*
files. Locked map geometry and tags are not opened for writing.

Ground diamonds are 8×4 on wind_ground_punch.png (pitch 159×167). Each
cell is masked to a hard 64×32 isometric diamond so freeze/water seams stay
readable. Cliffs keep that cap and hang the wall. Crystal props stay narrow
accents.
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
PUNCH = HERE / "pending" / "ice" / "punch"
GROUND_SHEET = PUNCH / "wind_ground_punch.png"
ELEV_SHEET = PUNCH / "wind_elevation_punch.png"
PROPS_SHEET = PUNCH / "wind_props_punch.png"
MIRROR = HERE.parents[2] / "stasium-ref" / "maps" / "windmere"
ROOT = TILES.parent
TAGS = ROOT / "windmere_15x15_tags.json"
TMX = ROOT / "windmere_15x15.tmx"

# Measured on wind_ground_punch.png. Autocorrelation period 159×167, 8×4.
CELL_ORIGIN = (4, 18)
CELL_PITCH = (159, 167)
CELL_COLS = 8
CELL_ROWS = 4
# Diamond inside one cell, before the 64×32 fit.
CELL_CX = 80.0
CELL_CY = 78.0
CELL_RX = 76.0
CELL_RY = 74.0

FLAT_NAMES = {
    "ground": ["wind_ground.png", "wind_ground_v1.png", "wind_ground_v2.png", "wind_ground_v3.png"],
    "water": ["wind_water.png", "wind_water_v1.png", "wind_water_v2.png"],
    "mud": ["wind_mud.png", "wind_mud_v1.png", "wind_mud_v2.png"],
}
# Accent caps. Wide crystal thickets are not used for these names.
PROP_BOX = {
    "wind_prop_spark.png": (52, 64),
    "wind_prop_ice_shard.png": (64, 96),
    "wind_prop_crystal.png": (56, 104),
    "wind_prop_rock_pillar.png": (64, 124),
    "wind_prop_rubble.png": (80, 64),
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


def _cell_diamond(height: int, width: int) -> np.ndarray:
    yy, xx = np.mgrid[0:height, 0:width]
    nx = np.abs(xx - CELL_CX) / CELL_RX
    ny = np.abs(yy - CELL_CY) / CELL_RY
    return (nx + ny) <= 1.0


def _rim(arr: np.ndarray, mask: np.ndarray) -> None:
    """One-pixel darker rim so neighboring diamonds keep a readable seam."""
    edge = mask & ~ndimage.binary_erosion(mask, iterations=1)
    if not edge.any():
        return
    rgb = arr[:, :, :3].astype(np.float32)
    rgb[edge] *= 0.58
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


def _fit_flat_cell(cell: np.ndarray) -> Image.Image:
    """Cell RGB → 64×32 diamond. Gutters outside the source diamond are dropped."""
    rgb = cell[:, :, :3]
    mask = _cell_diamond(cell.shape[0], cell.shape[1])
    rgba = np.zeros((cell.shape[0], cell.shape[1], 4), np.uint8)
    rgba[:, :, :3] = rgb
    rgba[:, :, 3] = np.where(mask, 255, 0).astype(np.uint8)
    ys, xs = np.where(mask)
    crop = rgba[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    spr = Image.fromarray(crop).resize((64, 32), Image.Resampling.LANCZOS)
    arr = _solid_diamond(np.asarray(spr).copy())
    return Image.fromarray(arr)


def _center(img: Image.Image) -> np.ndarray:
    px = np.asarray(img)[16, 32, :3].astype(np.float32) / 255.0
    return px


def _kind(px: np.ndarray) -> str:
    r, g, b = (float(v) for v in px)
    if r > 0.70 and b + 0.02 >= r and g > 0.70:
        return "ground"
    if b > g > r and b > 0.45 and r < 0.55:
        return "water"
    return "mud"


def _slice_ground() -> list[dict]:
    sheet = np.asarray(Image.open(GROUND_SHEET).convert("RGB"))
    ox, oy = CELL_ORIGIN
    pw, ph = CELL_PITCH
    fitted = []
    for row in range(CELL_ROWS):
        for col in range(CELL_COLS):
            x0 = ox + col * pw
            y0 = oy + row * ph
            cell = sheet[y0 : y0 + ph, x0 : x0 + pw]
            img = _fit_flat_cell(cell)
            px = _center(img)
            fitted.append({"img": img, "kind": _kind(px), "px": px, "at": (col, row)})
    buckets = {"ground": [], "water": [], "mud": []}
    for item in fitted:
        buckets[item["kind"]].append(item)
    buckets["ground"].sort(key=lambda item: -float(item["px"].sum()))
    buckets["water"].sort(key=lambda item: -(float(item["px"][2]) - float(item["px"][0])))
    # Darkest cells read as holes. Mud stays frozen ground, lighter ice first.
    buckets["mud"].sort(key=lambda item: -float(item["px"].sum()))
    for key, names in FLAT_NAMES.items():
        if len(buckets[key]) < len(names):
            raise SystemExit(f"need {len(names)} {key} diamonds, found {len(buckets[key])}")
    records = []
    chosen = {"ground": [], "water": [], "mud": []}
    for key, names in FLAT_NAMES.items():
        for name, item in zip(names, buckets[key]):
            path = TILES / name
            item["img"].save(path)
            chosen[key].append(item)
            records.append({"file": name, "size": [64, 32]})
            print(f"{name:24} 64x32  {key:6} rgb {np.round(item['px'], 3).tolist()} cell {item['at']}")
    # Flat props are diamonds, not standing crystals.
    ice = buckets["mud"][len(FLAT_NAMES["mud"])] if len(buckets["mud"]) > len(FLAT_NAMES["mud"]) else buckets["ground"][-1]
    seal = buckets["ground"][len(FLAT_NAMES["ground"])] if len(buckets["ground"]) > len(FLAT_NAMES["ground"]) else buckets["ground"][0]
    for name, item in (("wind_prop_ice_sheet.png", ice), ("wind_prop_floor_seal.png", seal)):
        item["img"].save(TILES / name)
        records.append({"file": name, "size": [64, 32]})
        print(f"{name:24} 64x32  flat prop")
    _assert_seams(chosen)
    return records


def _assert_seams(chosen: dict) -> None:
    mask = _iso_mask()
    for key in ("ground", "water"):
        img = np.asarray(chosen[key][0]["img"])
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
            # Rim darken does not change coverage. Coverage must be the mask.
            raise SystemExit(f"{key} diamond coverage is not the hard mask")
    snow = chosen["ground"][0]["px"]
    water = chosen["water"][0]["px"]
    if not (snow[0] > 0.70 and snow[2] >= snow[0]):
        raise SystemExit(f"wind ground center is not snow {snow}")
    if not (water[2] > water[1] > water[0]):
        raise SystemExit(f"wind water center is not blue {water}")


def _key_elevation(rgb: np.ndarray) -> np.ndarray:
    lum = rgb.astype(np.float32).mean(2)
    alpha = np.clip((lum - 10.0) / 14.0, 0.0, 1.0)
    alpha = np.where(lum < 12.0, 0.0, alpha)
    out = np.zeros((rgb.shape[0], rgb.shape[1], 4), np.uint8)
    out[:, :, :3] = rgb
    out[:, :, 3] = (alpha * 255.0).astype(np.uint8)
    out[out[:, :, 3] < 12] = 0
    return out


def _stamp_cliff(img: Image.Image) -> Image.Image:
    arr = np.asarray(img).copy()
    if arr.shape[1] != 64 or arr.shape[0] < 33:
        raise SystemExit(f"cliff fit is {arr.shape[1]}x{arr.shape[0]}")
    arr = _solid_diamond(arr)
    # The wall hangs under the south edge. Keep it inside the cell width.
    wall = arr[32:, :, 3] > 16
    if wall.any():
        inset = ndimage.binary_erosion(wall, iterations=1, border_value=0)
        edge = wall & ~inset
        rgb = arr[32:, :, :3].astype(np.float32)
        rgb[edge] *= 0.62
        arr[32:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return Image.fromarray(arr)


def _slice_elevation() -> list[dict]:
    rgb = np.asarray(Image.open(ELEV_SHEET).convert("RGB"))
    keyed = _key_elevation(rgb)
    mask = ndimage.binary_opening(keyed[:, :, 3] > 24, iterations=1)
    mask = ndimage.binary_closing(mask, iterations=2)
    lab, count = ndimage.label(mask)
    boxes = []
    for i in range(1, count + 1):
        ys, xs = np.where(lab == i)
        if len(xs) < 6000:
            continue
        boxes.append([int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())])
    # Each connected sprite is one wall. Stacked rows on the sheet stay separate.
    fitted = []
    for x0, y0, x1, y1 in boxes:
        crop = keyed[y0 : y1 + 1, x0 : x1 + 1]
        src_w = x1 - x0 + 1
        src_h = y1 - y0 + 1
        # Narrow slivers stretch into unreadable walls. Skip them.
        if src_h < 120 or src_w < 140:
            continue
        img = _stamp_cliff(_fit_cliff_sheet(crop, 0.42))
        if img.size[1] > 110:
            continue
        fitted.append(img)
        print(f"cliff candidate {img.size[0]}x{img.size[1]} from {x0},{y0} {src_w}x{src_h}")
    fitted.sort(key=lambda img: img.size[1])
    if len(fitted) < 4:
        raise SystemExit(f"need 4 cliffs, found {len(fitted)}")
    preferred = [img for img in fitted if 70 <= img.size[1] <= 82]
    shorts = preferred if len(preferred) >= 3 else [img for img in fitted if img.size[1] <= 82]
    if len(shorts) < 3:
        shorts = fitted[:-1]
    tall_pool = [img for img in fitted if img.size[1] > shorts[0].size[1]]
    if not tall_pool:
        raise SystemExit("no cliff taller than the low walls")
    tall = tall_pool[-1]
    # Three low walls, one high wall. mud_e1 stays on the ice dress.
    picks = [
        ("wind_ground_e1.png", shorts[0]),
        ("wind_ground_e1_v1.png", shorts[min(1, len(shorts) - 1)]),
        ("wind_mud_e1.png", shorts[min(2, len(shorts) - 1)]),
        ("wind_ground_e2.png", tall),
    ]
    if picks[3][1].size[1] <= picks[0][1].size[1]:
        raise SystemExit("ground_e2 is not taller than ground_e1")
    records = []
    for name, img in picks:
        img.save(TILES / name)
        records.append({"file": name, "size": [img.size[0], img.size[1]]})
        print(f"{name:24} {img.size[0]}x{img.size[1]}")
    return records


def _prop_sprites() -> list[dict]:
    sheet = np.asarray(Image.open(PROPS_SHEET).convert("RGBA"))
    mask = sheet[:, :, 3] > 30
    lab, count = ndimage.label(mask)
    sprites = []
    for i in range(1, count + 1):
        ys, xs = np.where(lab == i)
        if len(xs) < 800:
            continue
        x0, x1 = int(xs.min()), int(xs.max())
        y0, y1 = int(ys.min()), int(ys.max())
        crop = sheet[y0 : y1 + 1, x0 : x1 + 1].copy()
        crop[crop[:, :, 3] < 20] = 0
        sprites.append(
            {
                "img": crop,
                "w": crop.shape[1],
                "h": crop.shape[0],
                "area": int((crop[:, :, 3] > 20).sum()),
            }
        )
    return sprites


def _scale_prop(sprite: np.ndarray, max_w: int, max_h: int) -> Image.Image:
    height, width = sprite.shape[:2]
    scale = min(max_w / width, max_h / height, 1.0)
    out_w = max(8, int(round(width * scale)))
    out_h = max(8, int(round(height * scale)))
    img = Image.fromarray(sprite).resize((out_w, out_h), Image.Resampling.LANCZOS)
    arr = np.asarray(img).copy()
    arr[arr[:, :, 3] < 12] = 0
    return Image.fromarray(arr)


def _slice_props() -> list[dict]:
    sprites = _prop_sprites()
    if len(sprites) < 5:
        raise SystemExit(f"need accent props, found {len(sprites)}")
    # Narrow standing sprites read as accents. Wide clusters stay unused.
    accents = [s for s in sprites if s["h"] >= s["w"] * 0.85 and s["w"] <= 170]
    accents.sort(key=lambda s: (s["w"], s["area"]))
    if len(accents) < 4:
        raise SystemExit(f"need 4 narrow crystal accents, found {len(accents)}")
    used = {id(accents[0]), id(accents[1]), id(accents[2])}
    pillar_pool = [s for s in sprites if id(s) not in used]
    pillar = max(pillar_pool, key=lambda s: s["h"] / max(s["w"], 1))
    used.add(id(pillar))
    rubble_pool = [s for s in sprites if id(s) not in used]
    rubble = min(rubble_pool, key=lambda s: s["h"] / max(s["w"], 1))
    assigned = {
        "wind_prop_spark.png": accents[0],
        "wind_prop_ice_shard.png": accents[1],
        "wind_prop_crystal.png": accents[2],
        "wind_prop_rock_pillar.png": pillar,
        "wind_prop_rubble.png": rubble,
    }
    records = []
    for name, sprite in assigned.items():
        img = _scale_prop(sprite["img"], *PROP_BOX[name])
        if name == "wind_prop_crystal.png" and img.size[0] > 72:
            raise SystemExit(f"crystal is too wide to stay sparse ({img.size})")
        img.save(TILES / name)
        records.append({"file": name, "size": [img.size[0], img.size[1]]})
        print(f"{name:24} {img.size[0]:3}x{img.size[1]:<3} from {sprite['w']}x{sprite['h']}")
    return records


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
    ):
        if sheet not in sheets:
            sheets.append(sheet)
    atlas["source_sheets"] = sheets
    atlas["families"]["windmere"] = {"pack": "ice", "prefix": "wind_", "pending_theme": None}
    promoted = atlas.get("promoted") or {}
    promoted["ice"] = "pending/ice/punch/wind_ground_punch.png"
    atlas["promoted"] = promoted
    atlas["windmere_punch"] = {
        "ground": "pending/ice/punch/wind_ground_punch.png",
        "elevation": "pending/ice/punch/wind_elevation_punch.png",
        "props": "pending/ice/punch/wind_props_punch.png",
        "note": "Live Windmere paint. Geometry and tags stay on the Locked maps.",
    }
    written = {item["file"]: item for item in records}
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


def _tile_name(cell: dict) -> str:
    if cell["elevation"] >= 2:
        return "wind_ground_e2"
    if cell["elevation"] == 1:
        return "wind_mud_e1" if cell["terrain"] == "mud" else "wind_ground_e1"
    if cell["terrain"] == "water":
        return "wind_water"
    if cell["terrain"] == "mud":
        return "wind_mud"
    return "wind_ground"


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
    cache = {}

    def get(name: str) -> Image.Image:
        if name not in cache:
            cache[name] = Image.open(TILES / f"{name}.png").convert("RGBA")
        return cache[name]

    order = sorted(((x, y) for y in range(15) for x in range(15)), key=lambda p: (p[0] + p[1], p[0]))
    for x, y in order:
        cell = cells[y][x]
        tile = get(_tile_name(cell))
        lx, ly = local(x, y)
        px = int(lx - min_x + 80 - 32)
        py = int(ly - min_y + 80)
        if tile.height > 32:
            py -= tile.height - 32
        canvas.alpha_composite(tile, (px, py))
        for prop in cell["paint_only"]:
            prop_img = get(f"wind_prop_{prop}")
            ppx = px + 32 - prop_img.width // 2
            ppy = py + (tile.height - 32) - (prop_img.height - 32)
            if tile.height > 32:
                ppy = py + 32 - prop_img.height
            canvas.alpha_composite(prop_img, (ppx, ppy))
    return canvas


def _write_previews(cells: list) -> None:
    board = _render_board(cells)
    plain = Image.new("RGB", board.size, (168, 196, 214))
    plain.paste(board, mask=board.split()[-1])
    # Same origin as _render_board. The line sits on the diamond edge.
    min_x = min((x - y) * 32 for y in range(15) for x in range(15)) - 48
    min_y = min((x + y) * 16 for y in range(15) for x in range(15)) - 48
    ink = ImageDraw.Draw(plain)
    for y in range(15):
        for x in range(15):
            lx, ly = (x - y) * 32, (x + y) * 16
            ox = lx - min_x + 80
            oy = ly - min_y + 80
            diamond = [(ox, oy), (ox + 32, oy + 16), (ox, oy + 32), (ox - 32, oy + 16)]
            ink.line(diamond + [diamond[0]], fill=(18, 32, 48), width=1)
    plain_path = ROOT / "windmere_15x15_preview.png"
    plain.save(plain_path, optimize=True)

    plate = Image.new("RGB", (1280, 720), (186, 214, 228))
    grad = ImageDraw.Draw(plate)
    for i in range(720):
        t = i / 720
        grad.line([(0, i), (1279, i)], fill=(int(198 - 40 * t), int(220 - 36 * t), int(232 - 24 * t)))
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
    banner.rounded_rectangle([390, 16, 890, 58], radius=8, fill=(30, 48, 68))
    banner.text((408, 26), "15×15 Windmere · ice and meltwater", font=font, fill=(230, 242, 250))
    painted = ROOT / "windmere_15x15_painted_preview.png"
    plate.save(painted, optimize=True, quality=92)
    MIRROR.mkdir(parents=True, exist_ok=True)
    plate.save(MIRROR / "luca_preview_windmere.png", optimize=True, quality=92)
    print(f"preview {plain_path.name} {plain.size[0]}x{plain.size[1]}")
    print(f"painted {painted.name} and luca_preview_windmere.png")


def slice_windmere() -> list[dict]:
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
        raise SystemExit("Windmere tags or tmx changed")
    return records


def main() -> None:
    records = slice_windmere()
    _patch_atlas(records)
    _sync_tsx()
    _write_previews(_load_cells())
    print(f"windmere punch slices {len(records)}")


if __name__ == "__main__":
    main()
