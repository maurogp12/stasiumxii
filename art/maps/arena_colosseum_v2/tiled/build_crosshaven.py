#!/usr/bin/env python3
"""Build Crosshaven 12x12 Koliseo Tiled map package (STASIUM XII)."""
from __future__ import annotations

import json
import math
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.dom import minidom

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
TILES = ROOT / "tiles"
TILE_W, TILE_H = 64, 32

# --- Palette (from Crosshaven look-dev: warm golds, teal water, dark mud) ---
C = {
    "ground_fill": (198, 168, 88),
    "ground_hi": (228, 198, 118),
    "ground_lo": (158, 128, 58),
    "ground_edge": (120, 95, 42),
    "mud_fill": (92, 58, 32),
    "mud_hi": (118, 78, 44),
    "mud_lo": (62, 38, 20),
    "mud_edge": (48, 28, 14),
    "water_fill": (64, 148, 148),
    "water_hi": (110, 190, 186),
    "water_lo": (36, 100, 110),
    "water_edge": (28, 78, 88),
    "lava_fill": (210, 78, 28),
    "lava_hi": (255, 160, 48),
    "lava_lo": (140, 36, 12),
    "lava_edge": (90, 24, 8),
    "void_fill": (28, 28, 36),
    "void_edge": (18, 18, 24),
    "elev_rim": (170, 150, 110),
    "elev_side": (110, 90, 55),
    "prop_stone": (150, 145, 135),
    "prop_wood": (110, 75, 40),
    "prop_hay": (220, 180, 70),
    "prop_roof": (130, 90, 55),
    "seal_gold": (190, 160, 80),
    "seal_ink": (90, 70, 40),
}


def diamond_mask(w=TILE_W, h=TILE_H):
    """Boolean mask for isometric diamond."""
    cx, cy = w / 2 - 0.5, h / 2 - 0.5
    mask = Image.new("L", (w, h), 0)
    px = mask.load()
    for y in range(h):
        for x in range(w):
            # diamond: |dx|/(w/2) + |dy|/(h/2) <= 1
            nx = abs(x - cx) / (w / 2)
            ny = abs(y - cy) / (h / 2)
            if nx + ny <= 1.02:
                px[x, y] = 255
    return mask


def point_in_diamond(x, y, w=TILE_W, h=TILE_H):
    cx, cy = w / 2 - 0.5, h / 2 - 0.5
    nx = abs(x - cx) / (w / 2)
    ny = abs(y - cy) / (h / 2)
    return nx + ny <= 1.0


def edge_dist(x, y, w=TILE_W, h=TILE_H):
    cx, cy = w / 2 - 0.5, h / 2 - 0.5
    return 1.0 - (abs(x - cx) / (w / 2) + abs(y - cy) / (h / 2))


def make_terrain_tile(name: str, fill, hi, lo, edge, elev: int = 0) -> Image.Image:
    """Readable isometric diamond terrain tile."""
    # Extra vertical space for elevation extrusion
    extrude = elev * 8
    h = TILE_H + extrude
    img = Image.new("RGBA", (TILE_W, h), (0, 0, 0, 0))
    px = img.load()

    # Side faces for elevation (simple vertical extrusion of diamond silhouette)
    if elev > 0:
        top_y0 = 0
        # Draw sides: for each column, extend down from top diamond edge
        for x in range(TILE_W):
            top_ys = []
            for y in range(TILE_H):
                if point_in_diamond(x, y):
                    top_ys.append(y)
            if not top_ys:
                continue
            y_min, y_max = min(top_ys), max(top_ys)
            # left-ish darker, right-ish mid
            side_col = C["elev_side"] if x < TILE_W // 2 else tuple(
                min(255, c + 25) for c in C["elev_side"]
            )
            for ey in range(extrude):
                yy = y_max + ey + 1
                if 0 <= yy < h:
                    # fade slightly
                    shade = 1.0 - ey / max(1, extrude) * 0.25
                    px[x, yy] = (
                        int(side_col[0] * shade),
                        int(side_col[1] * shade),
                        int(side_col[2] * shade),
                        255,
                    )

    # Top diamond (shifted up by 0 — sits at top of image)
    for y in range(TILE_H):
        for x in range(TILE_W):
            if not point_in_diamond(x, y):
                continue
            d = edge_dist(x, y)
            # subtle noise stripes for readability
            stripe = ((x + y * 2) % 7) / 7.0
            if d < 0.12:
                col = edge
            elif y < TILE_H * 0.35:
                t = 0.55 + 0.45 * stripe
                col = tuple(int(hi[i] * t + fill[i] * (1 - t)) for i in range(3))
            elif y > TILE_H * 0.65:
                t = 0.4 + 0.3 * stripe
                col = tuple(int(lo[i] * t + fill[i] * (1 - t)) for i in range(3))
            else:
                t = 0.15 * stripe
                col = tuple(int(fill[i] * (1 - t) + hi[i] * t) for i in range(3))
            # elev rim highlight
            if elev > 0 and d < 0.22:
                col = tuple(min(255, int(c * 0.85 + C["elev_rim"][i] * 0.15)) for i, c in enumerate(col))
            px[x, y] = (*col, 255)

    # Tiny label letter for debug readability (optional faint)
    draw = ImageDraw.Draw(img)
    label = {"ground": "G", "mud": "M", "water": "W", "lava": "L", "void": "X"}.get(
        name.split("_")[0], ""
    )
    if label and elev == 0:
        # faint center mark
        cx, cy = TILE_W // 2, TILE_H // 2
        draw.ellipse([cx - 2, cy - 1, cx + 2, cy + 1], fill=(*edge, 180))

    return img


def make_prop_tile(kind: str) -> Image.Image:
    """Simple paint-only prop placeholder (64x48 tall diamond footprint + sprite)."""
    h = 48
    img = Image.new("RGBA", (TILE_W, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # faint diamond footprint
    foot = [(32, 28), (48, 36), (32, 44), (16, 36)]
    draw.polygon(foot, fill=(0, 0, 0, 40))

    if kind == "ruins":
        # crumbled cottage silhouette
        draw.rectangle([18, 8, 46, 30], fill=C["prop_stone"] + (230,))
        draw.polygon([(16, 12), (32, 2), (48, 12)], fill=C["prop_roof"] + (230,))
        draw.rectangle([26, 18, 34, 30], fill=(60, 50, 40, 220))
        draw.line([(40, 10), (40, 28)], fill=C["prop_wood"] + (200,), width=2)
    elif kind == "well":
        draw.ellipse([22, 22, 42, 34], fill=C["prop_stone"] + (230,))
        draw.ellipse([26, 24, 38, 30], fill=C["water_lo"] + (220,))
        draw.line([(24, 18), (24, 26)], fill=C["prop_wood"] + (230,), width=2)
        draw.line([(40, 18), (40, 26)], fill=C["prop_wood"] + (230,), width=2)
        draw.line([(22, 18), (42, 18)], fill=C["prop_wood"] + (230,), width=2)
        draw.rectangle([28, 10, 36, 18], fill=C["prop_roof"] + (220,))
    elif kind == "hay":
        draw.ellipse([18, 24, 46, 38], fill=C["prop_hay"] + (240,))
        draw.ellipse([22, 18, 42, 30], fill=tuple(min(255, c + 20) for c in C["prop_hay"]) + (240,))
        draw.arc([20, 20, 44, 36], 20, 160, fill=C["ground_edge"] + (180,), width=1)
    elif kind == "fence":
        for x in (20, 32, 44):
            draw.line([(x, 16), (x, 36)], fill=C["prop_wood"] + (230,), width=2)
        draw.line([(18, 20), (46, 20)], fill=C["prop_wood"] + (230,), width=2)
        draw.line([(18, 28), (46, 28)], fill=C["prop_wood"] + (230,), width=2)
    elif kind == "rubble":
        draw.ellipse([20, 28, 36, 38], fill=(130, 125, 115, 230))
        draw.ellipse([30, 24, 46, 36], fill=(145, 140, 130, 230))
        draw.rectangle([24, 22, 34, 30], fill=(120, 115, 105, 220))
    elif kind == "rock_pillar":
        draw.rectangle([26, 6, 38, 34], fill=(140, 135, 125, 240))
        draw.rectangle([24, 4, 40, 10], fill=(155, 150, 140, 240))
        draw.ellipse([22, 30, 42, 40], fill=(100, 95, 85, 180))
    elif kind == "floor_seal":
        draw.ellipse([14, 20, 50, 40], outline=C["seal_gold"] + (220,), width=2)
        draw.ellipse([22, 24, 42, 36], outline=C["seal_ink"] + (200,), width=1)
        draw.line([(32, 22), (32, 38)], fill=C["seal_gold"] + (180,), width=1)
        draw.line([(18, 30), (46, 30)], fill=C["seal_gold"] + (180,), width=1)
    else:
        draw.ellipse([24, 24, 40, 36], fill=(200, 100, 200, 200))

    return img


def generate_tiles():
    TILES.mkdir(parents=True, exist_ok=True)
    catalog = []

    specs = [
        ("ground", 0, C["ground_fill"], C["ground_hi"], C["ground_lo"], C["ground_edge"]),
        ("mud", 0, C["mud_fill"], C["mud_hi"], C["mud_lo"], C["mud_edge"]),
        ("water", 0, C["water_fill"], C["water_hi"], C["water_lo"], C["water_edge"]),
        ("lava", 0, C["lava_fill"], C["lava_hi"], C["lava_lo"], C["lava_edge"]),
        ("void", 0, C["void_fill"], (40, 40, 50), (20, 20, 28), C["void_edge"]),
        ("ground_e1", 1, C["ground_fill"], C["ground_hi"], C["ground_lo"], C["ground_edge"]),
        ("ground_e2", 2, C["ground_fill"], C["ground_hi"], C["ground_lo"], C["ground_edge"]),
        ("mud_e1", 1, C["mud_fill"], C["mud_hi"], C["mud_lo"], C["mud_edge"]),
    ]
    for name, elev, fill, hi, lo, edge in specs:
        base = name.split("_")[0]
        img = make_terrain_tile(base, fill, hi, lo, edge, elev=elev)
        path = TILES / f"{name}.png"
        img.save(path)
        catalog.append(
            {
                "file": f"tiles/{name}.png",
                "name": name,
                "terrain": base if base != "void" else "void",
                "elevation": elev,
                "paint_only": False,
                "w": img.width,
                "h": img.height,
            }
        )

    props = ["ruins", "well", "hay", "fence", "rubble", "rock_pillar", "floor_seal"]
    for p in props:
        img = make_prop_tile(p)
        path = TILES / f"prop_{p}.png"
        img.save(path)
        catalog.append(
            {
                "file": f"tiles/prop_{p}.png",
                "name": f"prop_{p}",
                "terrain": "paint_only",
                "elevation": 0,
                "paint_only": True,
                "prop": p,
                "w": img.width,
                "h": img.height,
            }
        )

    return catalog


# ---------------------------------------------------------------------------
# Crosshaven 12x12 design
# Terrain: ~20% mud+water, clear lanes, no lava, edge ruins, center seal
# Elevation: a few +1 platforms (paint matches elevated ground tiles)
# ---------------------------------------------------------------------------

def design_board():
    N = 12
    cells = [[{"terrain": "ground", "elevation": 0, "paint_only": []} for _ in range(N)] for _ in range(N)]

    # Mud puddles (Dofus-lite clusters, leave lanes)
    mud = [
        (1, 1), (1, 2), (2, 1),
        (2, 5), (3, 5), (3, 6),
        (5, 2), (6, 2), (6, 3),
        (8, 8), (8, 9), (9, 8),
        (10, 4), (10, 5), (11, 4),
        (4, 9), (5, 9), (5, 10),
        (0, 7), (1, 7),
        (7, 0), (7, 1),
    ]
    # Water puddles
    water = [
        (4, 3), (4, 4),
        (9, 2), (9, 3),
        (2, 9), (3, 9),
        (6, 7), (7, 7), (7, 8),
        (11, 10), (10, 11),
        (0, 3),
        (8, 5),
    ]
    for x, y in mud:
        cells[y][x]["terrain"] = "mud"
    for x, y in water:
        cells[y][x]["terrain"] = "water"

    # Elevation platforms (+1) — clear of heavy mud clusters where possible
    elev1 = [(3, 2), (8, 3), (2, 8), (9, 9), (5, 5), (6, 6)]
    for x, y in elev1:
        cells[y][x]["elevation"] = 1
        # keep terrain as-is; elevated mud rare
        if cells[y][x]["terrain"] == "water":
            cells[y][x]["terrain"] = "ground"

    # One +2 decorative plinth near center-north
    cells[4][5]["elevation"] = 2
    cells[4][5]["terrain"] = "ground"

    # Paint-only props (edge ruins / countryside dressing)
    props = {
        (0, 0): ["ruins"],
        (0, 11): ["ruins", "fence"],
        (11, 0): ["ruins"],
        (11, 11): ["rubble"],
        (0, 5): ["fence", "hay"],
        (11, 6): ["well"],
        (5, 0): ["hay"],
        (6, 11): ["hay", "fence"],
        (1, 10): ["rubble"],
        (10, 1): ["rubble"],
        (3, 11): ["ruins"],
        (11, 3): ["rock_pillar"],
        (0, 8): ["rock_pillar"],
        (5, 6): ["floor_seal"],  # near center seal on ground cell
        (6, 5): ["floor_seal"],
        (4, 7): ["rubble"],
        (7, 4): ["hay"],
        (2, 0): ["fence"],
        (9, 11): ["fence"],
    }
    for (x, y), plist in props.items():
        cells[y][x]["paint_only"] = list(plist)

    return cells


def write_tsx(catalog):
    """External tileset referencing individual images (Tiled collection)."""
    # Collection-of-images tileset
    ts = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.0",
            "name": "koliseo_base",
            "tilewidth": str(TILE_W),
            "tileheight": str(TILE_H),
            "tilecount": str(len(catalog)),
            "columns": "0",  # collection
        },
    )
    # Use max tile height for tileheight attribute — Tiled collections still need a default;
    # individual tiles override via tile image size. Keep base as 32; tall tiles ok.
    for i, t in enumerate(catalog):
        tile = ET.SubElement(ts, "tile", {"id": str(i)})
        # custom properties
        props = ET.SubElement(tile, "properties")
        ET.SubElement(
            props,
            "property",
            {"name": "terrain", "type": "string", "value": t["terrain"]},
        )
        ET.SubElement(
            props,
            "property",
            {"name": "elevation", "type": "int", "value": str(t["elevation"])},
        )
        ET.SubElement(
            props,
            "property",
            {
                "name": "paint_only",
                "type": "bool",
                "value": "true" if t["paint_only"] else "false",
            },
        )
        if t.get("prop"):
            ET.SubElement(
                props,
                "property",
                {"name": "prop", "type": "string", "value": t["prop"]},
            )
        ET.SubElement(
            tile,
            "image",
            {
                "source": t["file"],
                "width": str(t["w"]),
                "height": str(t["h"]),
            },
        )

    path = ROOT / "tileset_koliseo_base.tsx"
    _write_xml(ts, path)
    return path, {t["name"]: i for i, t in enumerate(catalog)}


def _write_xml(elem, path: Path):
    rough = ET.tostring(elem, encoding="utf-8")
    pretty = minidom.parseString(rough).toprettyxml(indent=" ", encoding="utf-8")
    # strip xml decl duplicate issues — minidom adds declaration
    path.write_bytes(pretty)


def write_tmx(cells, id_of):
    N = 12
    # Map uses classic Tiled isometric (diamond). Godot 4 imports this via
    # TileMap / Tiled importer; staggered-isometric is NOT used (that's for
    # offset-row diamond variants). Matches cell_to_local ≈ ((x-y)*32,(x+y)*16).

    def gid(name):
        return id_of[name] + 1  # firstgid=1

    ground_data = []
    terrain_data = []
    elev_data = []
    props_data = []

    prop_tile = {
        "ruins": "prop_ruins",
        "well": "prop_well",
        "hay": "prop_hay",
        "fence": "prop_fence",
        "rubble": "prop_rubble",
        "rock_pillar": "prop_rock_pillar",
        "floor_seal": "prop_floor_seal",
    }

    for y in range(N):
        for x in range(N):
            c = cells[y][x]
            # ground layer always base ground (visual underlay)
            ground_data.append(str(gid("ground")))

            # terrain overlays: mud/water/lava on flat cells only.
            # When elevation>0, the elevation layer tile encodes terrain+height
            # so leave terrain empty to avoid double-draw in Tiled.
            e = c["elevation"]
            if e == 0 and c["terrain"] != "ground":
                terrain_data.append(str(gid(c["terrain"])))
            else:
                terrain_data.append("0")

            # elevation layer: elevated variants when elev>0
            if e == 0:
                elev_data.append("0")
            elif e == 1:
                if c["terrain"] == "mud":
                    elev_data.append(str(gid("mud_e1")))
                else:
                    elev_data.append(str(gid("ground_e1")))
            else:  # 2+
                elev_data.append(str(gid("ground_e2")))

            # props: one primary prop tile per cell (first in list); extras noted in JSON
            plist = c["paint_only"]
            if plist:
                props_data.append(str(gid(prop_tile[plist[0]])))
            else:
                props_data.append("0")

    def layer(name, lid, data_csv):
        el = ET.Element(
            "layer",
            {
                "id": str(lid),
                "name": name,
                "width": str(N),
                "height": str(N),
            },
        )
        data = ET.SubElement(el, "data", {"encoding": "csv"})
        # pretty csv rows
        rows = [",".join(data_csv[y * N : (y + 1) * N]) for y in range(N)]
        data.text = "\n" + ",\n".join(rows) + "\n"
        return el

    root = ET.Element(
        "map",
        {
            "version": "1.10",
            "tiledversion": "1.11.0",
            "orientation": "isometric",
            "renderorder": "right-down",
            "width": str(N),
            "height": str(N),
            "tilewidth": str(TILE_W),
            "tileheight": str(TILE_H),
            "infinite": "0",
            "nextlayerid": "6",
            "nextobjectid": "1",
        },
    )
    # map properties documenting playable region
    mprops = ET.SubElement(root, "properties")
    ET.SubElement(
        mprops,
        "property",
        {"name": "arena", "type": "string", "value": "crosshaven"},
    )
    ET.SubElement(
        mprops,
        "property",
        {"name": "playable_size", "type": "string", "value": "12x12"},
    )
    ET.SubElement(
        mprops,
        "property",
        {
            "name": "orientation_note",
            "type": "string",
            "value": "Tiled isometric diamond; screen N=up-right E=down-right; cell_to_local=((x-y)*32,(x+y)*16)",
        },
    )
    ET.SubElement(
        mprops,
        "property",
        {
            "name": "tags_file",
            "type": "string",
            "value": "crosshaven_12x12_tags.json",
        },
    )

    ts_ref = ET.SubElement(
        root,
        "tileset",
        {"firstgid": "1", "source": "tileset_koliseo_base.tsx"},
    )

    root.append(layer("ground", 1, ground_data))
    root.append(layer("terrain", 2, terrain_data))
    root.append(layer("elevation", 3, elev_data))
    root.append(layer("props_paint", 4, props_data))

    # meta layer: void markers unused on playable; kept empty (all 0) as placeholder
    meta = ["0"] * (N * N)
    root.append(layer("meta", 5, meta))

    path = ROOT / "crosshaven_12x12.tmx"
    _write_xml(root, path)
    return path


def write_tags(cells):
    N = 12
    out = {"size": [N, N], "cells": []}
    for y in range(N):
        for x in range(N):
            c = cells[y][x]
            out["cells"].append(
                {
                    "x": x,
                    "y": y,
                    "terrain": c["terrain"],
                    "elevation": c["elevation"],
                    "paint_only": list(c["paint_only"]),
                }
            )
    path = ROOT / "crosshaven_12x12_tags.json"
    path.write_text(json.dumps(out, indent=2) + "\n")
    return path, out


def cell_to_local(x, y):
    return ((x - y) * 32, (x + y) * 16)


def write_preview(cells):
    """Composite isometric preview with faint grid + label."""
    N = 12
    # Compute bounds
    pts = [cell_to_local(x, y) for y in range(N) for x in range(N)]
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    pad = 80
    # tile extends ±32 x, +16 y from origin tip; also elev extrusion
    min_x, max_x = min(xs) - 40, max(xs) + 40
    min_y, max_y = min(ys) - 40, max(ys) + 80
    W = int(max_x - min_x + pad * 2)
    H = int(max_y - min_y + pad * 2 + 40)
    # warm plains background
    img = Image.new("RGB", (W, H), (210, 175, 95))
    draw = ImageDraw.Draw(img, "RGBA")
    # subtle gradient bands
    for i in range(H):
        t = i / H
        col = (
            int(216 - 20 * t),
            int(177 - 30 * t),
            int(93 - 10 * t),
        )
        draw.line([(0, i), (W, i)], fill=col)

    def blit_tile(name, gx, gy, elev_extra=0):
        path = TILES / f"{name}.png"
        tile = Image.open(path).convert("RGBA")
        lx, ly = cell_to_local(gx, gy)
        # place so diamond center/top aligns: tile drawn with tip at top
        # local (0,0) is top tip of cell diamond
        px = int(lx - min_x + pad - TILE_W // 2)
        py = int(ly - min_y + pad)
        # elev tiles are taller; bottom-align to ground plane
        if tile.height > TILE_H:
            py = py - (tile.height - TILE_H)
        img.alpha_composite(tile, (px, py)) if img.mode == "RGBA" else None
        # work on RGBA canvas
        return px, py, tile

    # Use RGBA working canvas
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bg = img.convert("RGBA")
    canvas.alpha_composite(bg)

    # Draw order: back-to-front = ascending (x+y), then x
    order = sorted(((x, y) for y in range(N) for x in range(N)), key=lambda p: (p[0] + p[1], p[0]))

    # Load tiles cache
    cache = {}

    def get_tile(name):
        if name not in cache:
            cache[name] = Image.open(TILES / f"{name}.png").convert("RGBA")
        return cache[name]

    for x, y in order:
        c = cells[y][x]
        # base ground
        base_name = "ground"
        if c["elevation"] == 1:
            base_name = "mud_e1" if c["terrain"] == "mud" else "ground_e1"
        elif c["elevation"] >= 2:
            base_name = "ground_e2"
        elif c["terrain"] != "ground":
            base_name = c["terrain"]

        tile = get_tile(base_name)
        lx, ly = cell_to_local(x, y)
        px = int(lx - min_x + pad - TILE_W // 2)
        py = int(ly - min_y + pad)
        if tile.height > TILE_H:
            py -= tile.height - TILE_H
        # If we used elev tile for mud/ground but terrain is water on elev0 already handled
        # For elev>0 with separate terrain overlay when terrain != ground and elev==0 done;
        # when elev>0 and terrain mud, mud_e1 used. When elev>0 and terrain water → forced ground earlier.
        canvas.alpha_composite(tile, (px, py))

        # If elev tile used but we also want mud/water on flat cells already in base_name.
        # Props
        for pi, prop in enumerate(c["paint_only"]):
            pt = get_tile(f"prop_{prop}")
            ppx = px
            ppy = py - (pt.height - TILE_H) + (0 if base_name.startswith("ground") or "e" in base_name else 0)
            # sit prop on top of tile top surface
            if tile.height > TILE_H:
                ppy = py  # already elevated
            else:
                ppy = py - (pt.height - TILE_H)
            # slight offset for second prop
            ppx += pi * 4
            canvas.alpha_composite(pt, (ppx, ppy))

    # Faint grid outlines
    grid = ImageDraw.Draw(canvas)
    for y in range(N):
        for x in range(N):
            lx, ly = cell_to_local(x, y)
            ox = lx - min_x + pad
            oy = ly - min_y + pad
            diamond = [
                (ox, oy),
                (ox + 32, oy + 16),
                (ox, oy + 32),
                (ox - 32, oy + 16),
            ]
            grid.polygon(diamond, outline=(255, 255, 255, 55))

    # Label banner
    label = "12×12 Crosshaven Tiled"
    try:
        font = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22
        )
        font_sm = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14
        )
    except Exception:
        font = ImageFont.load_default()
        font_sm = font

    # banner box
    bw, bh = 360, 52
    bx, by = (W - bw) // 2, 12
    grid.rounded_rectangle(
        [bx, by, bx + bw, by + bh], radius=8, fill=(40, 30, 15, 200)
    )
    # text
    grid.text((bx + 28, by + 8), label, font=font, fill=(255, 235, 180, 255))
    grid.text(
        (bx + 28, by + 32),
        "STASIUM XII · Koliseo · isometric 64×32",
        font=font_sm,
        fill=(220, 200, 150, 230),
    )

    out = canvas.convert("RGB")
    path = ROOT / "crosshaven_12x12_preview.png"
    out.save(path, optimize=True)
    return path


def write_readme(counts):
    text = f"""# Crosshaven 12×12 — Koliseo Tiled map (STASIUM XII)

Built for Mauro · Sep 24 2026 (ET). Playable grid locked at **12×12** (8×8 is proto only).

## Orientation (locked)

| Item | Value |
|------|--------|
| Tiled `orientation` | **`isometric`** (classic diamond — **not** `staggered`) |
| Tile size | **64×32** px (diamond bounding box) |
| Screen compass | N = up-right, E = down-right, S = down-left, W = up-left |
| Cell → local | `cell_to_local(x,y) ≈ ((x-y)*32, (x+y)*16)` |
| Godot 4 | Import `.tmx` / use isometric TileMap; same diamond math. Staggered-isometric is a different grid and is **not** used here. |

**Why isometric (not staggered):** Matches historical game tiles and the locked `cell_to_local` formula. Tiled + Godot 4 both handle diamond isometric maps cleanly; staggered is for offset-row layouts and would break the (x−y)/(x+y) projection.

## Playable region

- Map width × height = **12 × 12**. Every cell is playable.
- No decorative outer ring in this deliverable (outer moat / plains stay in look-dev plates only). If a future shell adds OOB cells, mark them `terrain: void` in tags and paint with the `void` tile on `meta`.

## Files

| Path | Role |
|------|------|
| `tileset_koliseo_base.tsx` | Collection tileset (terrain + elev variants + paint props) |
| `tiles/*.png` | Generated 64×32 (or taller) isometric PNGs |
| `crosshaven_12x12.tmx` | Tiled map |
| `crosshaven_12x12_tags.json` | Authoritative per-cell combat tags for Godot |
| `crosshaven_12x12_preview.png` | Render preview with faint grid |
| `build_crosshaven.py` | Reproducible builder |

## Layers

| Layer | Meaning |
|-------|---------|
| `ground` | Base warm ground under every playable cell |
| `terrain` | Mud / water overlays (empty = ground). **Source of combat terrain when JSON absent** |
| `elevation` | Height variants (`ground_e1`, `ground_e2`, `mud_e1`). Empty = elevation 0 |
| `props_paint` | Paint-only placeholders (ruins, well, hay, fence, rubble, rock_pillar, floor_seal). **No combat block / LoS / MP** |
| `meta` | Reserved (all empty on Crosshaven) |

## Terrain tags (Rules Keeper)

Combat-relevant (stamp these):

- `ground` — MP 1
- `mud` — MP 2
- `water` — MP 2
- `lava` — voluntary impassable; push → Burn (**0 cells on Crosshaven**)
- `elevation` — int; climb ≤1 / drop ≤2

Paint-only (NO block / LoS / cost): ruins, wells, hay, fences, rubble, rock pillars, floor seals, outer moat, ice, dressing props. **Do not invent LoS blockers from props.**

### Crosshaven cell counts

- ground: **{counts['ground']}**
- mud: **{counts['mud']}**
- water: **{counts['water']}**
- lava: **{counts['lava']}**
- mud+water share: **{(counts['mud']+counts['water'])/144*100:.1f}%** (target ~15–25%)
- elevation ≥1: **{counts['elev']}** cells

## How Godot should load tags

1. Prefer **`crosshaven_12x12_tags.json`** as the combat authority (backend must not invent blockers from art).
2. Schema:
   ```json
   {{ "size": [12,12], "cells": [ {{ "x":0, "y":0, "terrain":"ground", "elevation":0, "paint_only":[] }}, ... ] }}
   ```
3. `terrain` ∈ `ground|mud|water|lava`.
4. `paint_only` is a string array of prop names — visuals only.
5. Optionally cross-check against Tiled layers `terrain` + `elevation` tile custom properties (`terrain`, `elevation`, `paint_only` on each tileset tile).
6. Movement: read `terrain` + `elevation` only. Ignore `props_paint` for pathing / LoS.

## Tileset tile names

Terrain: `ground`, `mud`, `water`, `lava`, `void`, `ground_e1`, `ground_e2`, `mud_e1`  
Props: `prop_ruins`, `prop_well`, `prop_hay`, `prop_fence`, `prop_rubble`, `prop_rock_pillar`, `prop_floor_seal`

## Open in Tiled

```bash
tiled /workspace/art/maps/arena_colosseum_v2/tiled/crosshaven_12x12.tmx
```

Rebuild:

```bash
python3 /workspace/art/maps/arena_colosseum_v2/tiled/build_crosshaven.py
```
"""
    path = ROOT / "README.md"
    path.write_text(text)
    return path


def main():
    print("Generating tiles…")
    catalog = generate_tiles()
    print(f"  {len(catalog)} tiles → {TILES}")

    print("Designing board…")
    cells = design_board()

    print("Writing tileset…")
    tsx, id_of = write_tsx(catalog)

    print("Writing TMX…")
    tmx = write_tmx(cells, id_of)

    print("Writing tags JSON…")
    tags_path, tags = write_tags(cells)

    # counts
    counts = {"ground": 0, "mud": 0, "water": 0, "lava": 0, "elev": 0}
    for c in tags["cells"]:
        counts[c["terrain"]] += 1
        if c["elevation"] >= 1:
            counts["elev"] += 1

    print("Writing preview…")
    preview = write_preview(cells)

    print("Writing README…")
    readme = write_readme(counts)

    # Validate XML
    for p in (tsx, tmx):
        ET.parse(p)
        print(f"  XML OK: {p.name}")

    # Validate JSON matches terrain intent
    assert tags["size"] == [12, 12]
    assert len(tags["cells"]) == 144
    assert counts["lava"] == 0
    share = (counts["mud"] + counts["water"]) / 144
    assert 0.15 <= share <= 0.25, share

    print("COUNTS", counts, f"share={share:.3f}")
    print("DONE")
    print("tsx", tsx)
    print("tmx", tmx)
    print("tags", tags_path)
    print("preview", preview)
    print("readme", readme)


if __name__ == "__main__":
    main()
