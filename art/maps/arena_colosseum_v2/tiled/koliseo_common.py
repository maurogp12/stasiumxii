#!/usr/bin/env python3
"""Shared Koliseo Tiled helpers: tiles, TMX, tags, preview, validation."""
from __future__ import annotations

import json
import xml.etree.ElementTree as ET
from collections import Counter, deque
from pathlib import Path
from xml.dom import minidom

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
TILES = ROOT / "tiles"
TILE_W, TILE_H = 64, 32
# Original isometric sheet. The dress painter must not overwrite those slices.
_ORIGINAL_ATLAS = ROOT.parents[2] / "tilesets" / "original" / "atlas_map.json"


def _save_tile(img: Image.Image, path: Path) -> Image.Image:
    if _ORIGINAL_ATLAS.is_file() and path.exists():
        return Image.open(path).convert("RGBA")
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    return img

# Crosshaven / base warm palette (GIDs 0.. must stay stable)
BASE_C = {
    # Painted dress v1 — sampled/tuned from crosshaven.png plate
    "ground_fill": (198, 160, 96),
    "ground_hi": (224, 192, 128),
    "ground_lo": (160, 128, 64),
    "ground_edge": (120, 92, 40),
    "mud_fill": (107, 72, 32),
    "mud_hi": (138, 98, 48),
    "mud_lo": (68, 44, 20),
    "mud_edge": (48, 30, 14),
    "water_fill": (72, 152, 152),
    "water_hi": (140, 200, 196),
    "water_lo": (36, 100, 110),
    "water_edge": (28, 78, 88),
    "lava_fill": (210, 78, 28),
    "lava_hi": (255, 160, 48),
    "lava_lo": (140, 36, 12),
    "lava_edge": (90, 24, 8),
    "void_fill": (28, 28, 36),
    "void_edge": (18, 18, 24),
    "elev_rim": (186, 168, 128),
    "elev_side": (118, 96, 62),
    "prop_stone": (158, 150, 138),
    "prop_wood": (110, 75, 40),
    "prop_hay": (228, 188, 78),
    "prop_roof": (138, 96, 58),
    "seal_gold": (198, 168, 88),
    "seal_ink": (90, 70, 40),
}

# Brinewake — teal stone / ocean
BRINE_C = {
    **BASE_C,
    "ground_fill": (150, 168, 158),
    "ground_hi": (188, 205, 198),
    "ground_lo": (110, 128, 120),
    "ground_edge": (78, 95, 90),
    "mud_fill": (72, 68, 48),
    "mud_hi": (98, 90, 58),
    "mud_lo": (48, 44, 28),
    "mud_edge": (36, 32, 20),
    "water_fill": (42, 168, 178),
    "water_hi": (110, 220, 220),
    "water_lo": (22, 110, 128),
    "water_edge": (16, 78, 95),
    "elev_rim": (170, 190, 185),
    "elev_side": (80, 100, 95),
}

# Slagcrown — ash basalt / lava orange
SLAG_C = {
    **BASE_C,
    "ground_fill": (72, 68, 66),
    "ground_hi": (105, 98, 92),
    "ground_lo": (48, 44, 42),
    "ground_edge": (32, 28, 26),
    "mud_fill": (58, 48, 38),
    "mud_hi": (78, 62, 48),
    "mud_lo": (38, 30, 22),
    "mud_edge": (28, 22, 16),
    "water_fill": (70, 150, 170),
    "water_hi": (140, 210, 220),
    "water_lo": (40, 100, 120),
    "water_edge": (28, 70, 88),
    "lava_fill": (230, 90, 22),
    "lava_hi": (255, 190, 50),
    "lava_lo": (160, 40, 10),
    "lava_edge": (90, 20, 6),
    "elev_rim": (140, 120, 100),
    "elev_side": (50, 42, 38),
}

# Windmere — ice blue stone
WIND_C = {
    **BASE_C,
    "ground_fill": (180, 195, 210),
    "ground_hi": (220, 232, 242),
    "ground_lo": (140, 155, 175),
    "ground_edge": (100, 115, 140),
    "mud_fill": (90, 85, 78),
    "mud_hi": (120, 112, 100),
    "mud_lo": (60, 55, 48),
    "mud_edge": (44, 40, 34),
    "water_fill": (90, 170, 210),
    "water_hi": (160, 220, 245),
    "water_lo": (50, 120, 160),
    "water_edge": (36, 90, 125),
    "elev_rim": (200, 220, 235),
    "elev_side": (100, 120, 145),
}


# Stormspire — dark slate / charcoal + cyan-violet wet
STORM_C = {
    **BASE_C,
    "ground_fill": (58, 62, 72),
    "ground_hi": (88, 94, 108),
    "ground_lo": (38, 42, 50),
    "ground_edge": (24, 26, 34),
    "mud_fill": (52, 42, 34),
    "mud_hi": (78, 58, 40),
    "mud_lo": (34, 26, 20),
    "mud_edge": (22, 16, 12),
    "water_fill": (48, 170, 200),
    "water_hi": (140, 230, 255),
    "water_lo": (40, 80, 160),
    "water_edge": (60, 40, 120),
    "elev_rim": (120, 200, 230),
    "elev_side": (42, 46, 58),
}

REGION_PALETTES = {
    "base": BASE_C,
    "brine": BRINE_C,
    "slag": SLAG_C,
    "wind": WIND_C,
    "storm": STORM_C,
}


def _ground_accent(C):
    """Region fleck color for ground tiles (moss / ember / frost / spark)."""
    gf = C.get("ground_fill", (0, 0, 0))
    if gf == BRINE_C["ground_fill"]:
        return (48, 140, 110)  # wet seaweed / teal moss
    if gf == SLAG_C["ground_fill"]:
        return (210, 90, 30)  # ember in basalt cracks
    if gf == WIND_C["ground_fill"]:
        return (230, 245, 255)  # frost sparkle
    if gf == STORM_C["ground_fill"]:
        return (90, 200, 240)  # cyan conduit fleck
    return (92, 128, 48)  # Crosshaven moss


def point_in_diamond(x, y, w=TILE_W, h=TILE_H):
    cx, cy = w / 2 - 0.5, h / 2 - 0.5
    nx = abs(x - cx) / (w / 2)
    ny = abs(y - cy) / (h / 2)
    return nx + ny <= 1.0


def edge_dist(x, y, w=TILE_W, h=TILE_H):
    cx, cy = w / 2 - 0.5, h / 2 - 0.5
    return 1.0 - (abs(x - cx) / (w / 2) + abs(y - cy) / (h / 2))


def _hash2(x: int, y: int, seed: int = 0) -> float:
    n = (x * 374761393 + y * 668265263 + seed * 982451653) & 0x7FFFFFFF
    n = (n ^ (n >> 13)) * 1274126177
    return ((n ^ (n >> 16)) & 0x7FFFFFFF) / 0x7FFFFFFF


def _smooth_noise(x: float, y: float, seed: int = 0) -> float:
    x0, y0 = int(x), int(y)
    fx, fy = x - x0, y - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    v00 = _hash2(x0, y0, seed)
    v10 = _hash2(x0 + 1, y0, seed)
    v01 = _hash2(x0, y0 + 1, seed)
    v11 = _hash2(x0 + 1, y0 + 1, seed)
    a = v00 * (1 - fx) + v10 * fx
    b = v01 * (1 - fx) + v11 * fx
    return a * (1 - fy) + b * fy


def _fbm(x: float, y: float, seed: int = 0, octaves: int = 3) -> float:
    amp, freq, total, norm = 1.0, 1.0, 0.0, 0.0
    for i in range(octaves):
        total += amp * _smooth_noise(x * freq, y * freq, seed + i * 17)
        norm += amp
        amp *= 0.5
        freq *= 2.0
    return total / norm


def _mix(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


def _clamp_rgb(c):
    return tuple(max(0, min(255, int(v))) for v in c)


def _shade(c, mul):
    return _clamp_rgb((c[0] * mul, c[1] * mul, c[2] * mul))


def make_terrain_tile(name: str, fill, hi, lo, edge, elev: int = 0, C=None) -> Image.Image:
    """Painted dress v1 — Dofus/Wakfu isometric diamond (Crosshaven koliseo vibe)."""
    C = C or BASE_C
    extrude = elev * 8
    h = TILE_H + extrude
    img = Image.new("RGBA", (TILE_W, h), (0, 0, 0, 0))
    px = img.load()
    seed = {"ground": 11, "mud": 29, "water": 47, "lava": 61, "void": 73}.get(
        name.split("_")[0], 3
    )
    seed += elev * 101 + (sum(fill) % 97)

    if elev > 0:
        side_lo = C["elev_side"]
        side_hi = _mix(side_lo, C["elev_rim"], 0.45)
        for x in range(TILE_W):
            top_ys = [y for y in range(TILE_H) if point_in_diamond(x, y)]
            if not top_ys:
                continue
            y_max = max(top_ys)
            leftish = x < TILE_W // 2
            base_side = _shade(side_lo, 0.85) if leftish else _mix(side_lo, side_hi, 0.55)
            for ey in range(extrude):
                yy = y_max + ey + 1
                if not (0 <= yy < h):
                    continue
                course = ey // 4
                mortar = (ey % 4 == 3)
                n = _hash2(x, ey, seed + 9)
                if mortar:
                    col = _shade(base_side, 0.55 + 0.1 * n)
                else:
                    shift = int(_hash2(course, 0, seed) * 3)
                    seam = ((x + shift) % 10) == 0
                    mul = 0.92 + 0.16 * n - (0.12 if seam else 0)
                    mul *= 1.0 - ey / max(1, extrude) * 0.22
                    col = _shade(base_side, mul)
                    if not leftish:
                        col = _mix(col, C["elev_rim"], 0.12)
                px[x, yy] = (*col, 255)

    for y in range(TILE_H):
        for x in range(TILE_W):
            if not point_in_diamond(x, y):
                continue
            d = edge_dist(x, y)
            u = (x / TILE_W) * 2.0
            v = (y / TILE_H) * 2.0
            n1 = _fbm(u * 3.2, v * 3.2, seed, 4)
            n2 = _fbm(u * 7.0 + 3.1, v * 7.0, seed + 5, 3)
            n3 = _smooth_noise(u * 14, v * 14, seed + 8)
            base = name.split("_")[0]

            if base == "ground":
                col = _mix(fill, hi, 0.35 + 0.35 * n1)
                col = _mix(col, lo, 0.25 * (1 - n2))
                lit = 1.0 + 0.12 * (1 - x / TILE_W) - 0.08 * (y / TILE_H)
                col = _shade(col, lit)
                crack = abs(n2 - 0.5) * abs(n1 - 0.42)
                if crack < 0.018 and d > 0.15:
                    col = _mix(col, edge, 0.55)
                if n3 > 0.82 and d > 0.2:
                    accent = _ground_accent(C)
                    # slag: prefer crack/ember over moss blob
                    amt = 0.22 + 0.25 * n1 if accent == (210, 90, 30) else 0.28 + 0.2 * n1
                    col = _mix(col, accent, amt)
                if n3 < 0.12:
                    col = _mix(col, hi, 0.2)
            elif base == "mud":
                col = _mix(fill, lo, 0.4 * n1)
                col = _mix(col, hi, 0.25 * n2)
                swirl = abs(_smooth_noise(u * 2.5 + n1, v * 2.5, seed + 2) - 0.5)
                if swirl < 0.08:
                    col = _mix(col, hi, 0.35)
                if 0.3 < d < 0.85 and n2 > 0.7 and y < TILE_H * 0.45:
                    gloss = _mix(hi, (210, 190, 140), 0.4)
                    col = _mix(col, gloss, 0.35)
                col = _shade(col, 0.95 + 0.1 * (1 - y / TILE_H))
            elif base == "water":
                depth = 0.35 + 0.5 * n1
                col = _mix(lo, fill, depth)
                col = _mix(col, hi, 0.2 * n2)
                cx, cy = TILE_W / 2, TILE_H / 2
                rr = (
                    (x - cx) ** 2 / (TILE_W * 0.5) ** 2
                    + (y - cy) ** 2 / (TILE_H * 0.5) ** 2
                ) ** 0.5
                ripple = abs((rr * 6 + n1 * 2) % 1.0 - 0.5)
                if ripple < 0.08:
                    col = _mix(col, hi, 0.45)
                if n3 > 0.88 and d > 0.25:
                    col = _mix(col, (220, 245, 240), 0.55)
                if d < 0.2:
                    col = _mix(col, edge, 0.5 * (1 - d / 0.2))
            elif base == "lava":
                col = _mix(lo, fill, 0.4 + 0.4 * n1)
                vein = abs(n2 - 0.5)
                if vein < 0.07:
                    col = _mix(col, hi, 0.85)
                if n3 > 0.85:
                    col = _mix(col, (255, 220, 80), 0.5)
                col = _shade(col, 0.95 + 0.15 * n1)
            else:
                col = _mix(fill, lo, n1 * 0.5)
                if n2 > 0.75:
                    col = _mix(col, hi, 0.3)

            if d < 0.10:
                col = _mix(col, edge, 0.75)
            elif d < 0.18:
                col = _mix(col, edge, 0.35)
            if elev > 0 and d < 0.28:
                col = _mix(col, C["elev_rim"], 0.18)
                if d < 0.14:
                    col = _mix(col, C["elev_rim"], 0.35)

            dither = (_hash2(x, y, seed + 99) - 0.5) * 10
            col = _clamp_rgb((col[0] + dither, col[1] + dither * 0.8, col[2] + dither * 0.5))
            px[x, y] = (*col, 255)

    return img


def make_prop_tile(kind: str, C=None) -> Image.Image:
    """Paint-only props — bottom-pivoted, human-perception scale vs heroes.

    Design space is 64×H_design. Houses/ruins ~1.5–2.5× export_2x hero height
    on the board; pillars taller; conduits/sparks stay accent-sized.
    """
    C = C or BASE_C
    # Design height (in 64-wide units). Foot sits near bottom of canvas.
    H_DESIGN = {
        "ruins": 112,
        "well": 80,
        "hay": 72,
        "fence": 64,
        "rubble": 52,
        "rock_pillar": 100,
        "floor_seal": 48,
        "driftwood": 56,
        "waterfall": 104,
        "rock_cluster": 72,
        "basalt_pillar": 108,
        "steam_vent": 80,
        "ash_rock": 56,
        "crystal": 100,
        "ice_shard": 88,
        "ice_sheet": 48,
        "spark": 48,
        "conduit": 52,
        "crystal_bolt": 104,
        "arc": 56,
    }
    hd = H_DESIGN.get(kind, 64)
    s = TILE_W / 64.0
    W = TILE_W
    H = int(hd * s)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Foot diamond near bottom of canvas (iso contact)
    foot_y = hd - 18
    foot = [(32, foot_y), (50, foot_y + 8), (32, foot_y + 16), (14, foot_y + 8)]
    draw.polygon([(int(x * s), int(y * s)) for x, y in foot], fill=(40, 30, 18, 55))

    stone = C["prop_stone"]
    stone_dk = (110, 100, 90)
    stone_hi = (175, 168, 155)
    wood = C["prop_wood"]
    wood_dk = (75, 48, 24)
    roof = C["prop_roof"]
    hay = C["prop_hay"]
    gold = C["seal_gold"]

    def R(box, **kw):
        x0, y0, x1, y1 = box
        draw.rectangle([int(x0 * s), int(y0 * s), int(x1 * s), int(y1 * s)], **kw)

    def E(box, **kw):
        x0, y0, x1, y1 = box
        draw.ellipse([int(x0 * s), int(y0 * s), int(x1 * s), int(y1 * s)], **kw)

    def L(a, b, **kw):
        draw.line([int(a[0] * s), int(a[1] * s), int(b[0] * s), int(b[1] * s)], **kw)

    def P(pts, **kw):
        draw.polygon([(int(x * s), int(y * s)) for x, y in pts], **kw)

    def A(box, start, end, **kw):
        x0, y0, x1, y1 = box
        draw.arc([int(x0 * s), int(y0 * s), int(x1 * s), int(y1 * s)], start, end, **kw)

    # Alias: y offsets measured from foot (positive = up). Converts to canvas y.
    def up(dy):
        return foot_y - dy

    if kind == "ruins":
        # Cottage / ruined house — clearly taller than heroes (~2×)
        base_y = up(8)
        wall_top = up(70)
        roof_peak = up(98)
        P([(10, wall_top), (32, roof_peak), (54, wall_top), (54, wall_top + 4), (10, wall_top + 4)], fill=roof + (245,))
        P([(12, wall_top), (32, roof_peak + 4), (52, wall_top)], fill=_mix(roof, (180, 130, 70), 0.35) + (235,))
        R([12, wall_top, 52, base_y], fill=stone + (245,))
        P([(12, wall_top), (12, base_y), (22, base_y - 6), (22, wall_top + 4)], fill=stone_dk + (210,))
        # door + windows
        R([28, up(38), 36, base_y], fill=(55, 42, 32, 235))
        R([16, up(58), 24, up(46)], fill=(70, 90, 110, 190))
        R([40, up(58), 48, up(46)], fill=(70, 90, 110, 190))
        L((44, roof_peak + 10), (44, base_y - 4), fill=wood_dk + (220,), width=max(2, int(3 * s)))
        L((14, wall_top), (50, wall_top), fill=wood + (200,), width=max(1, int(2 * s)))
        # rubble at feet
        E([8, base_y - 4, 22, base_y + 10], fill=stone_dk + (200,))
        E([44, base_y - 2, 58, base_y + 10], fill=stone + (200,))
    elif kind == "well":
        rim = up(14)
        E([16, rim + 6, 48, rim + 22], fill=stone_dk + (230,))
        E([18, rim, 46, rim + 16], fill=stone + (245,))
        E([24, rim + 4, 40, rim + 14], fill=C["water_lo"] + (235,))
        E([26, rim + 4, 34, rim + 9], fill=C["water_hi"] + (170,))
        L((22, up(52)), (22, rim + 4), fill=wood + (245,), width=max(2, int(3 * s)))
        L((42, up(52)), (42, rim + 4), fill=wood + (245,), width=max(2, int(3 * s)))
        P([(16, up(48)), (32, up(66)), (48, up(48))], fill=roof + (245,))
        P([(18, up(48)), (32, up(62)), (46, up(48))], fill=_mix(roof, (160, 110, 60), 0.3) + (225,))
        L((18, up(48)), (46, up(48)), fill=wood_dk + (235,), width=max(2, int(2 * s)))
        R([30, up(46), 34, up(36)], fill=wood + (225,))
    elif kind == "hay":
        E([12, up(18), 52, up(2)], fill=_shade(hay, 0.75) + (245,))
        E([14, up(36), 50, up(14)], fill=hay + (250,))
        E([18, up(48), 46, up(28)], fill=_mix(hay, (255, 220, 120), 0.4) + (245,))
        A([16, up(34), 48, up(12)], 30, 150, fill=C["ground_edge"] + (160,), width=max(1, int(s)))
        L((20, up(32)), (44, up(18)), fill=_shade(hay, 0.65) + (180,), width=max(1, int(s)))
        for cx, cy in ((22, up(36)), (34, up(28)), (28, up(20)), (40, up(32))):
            E([cx, cy, cx + 4, cy + 3], fill=_mix(hay, (255, 230, 140), 0.5) + (150,))
    elif kind == "fence":
        for x in (16, 32, 48):
            L((x, up(48)), (x, up(4)), fill=wood_dk + (245,), width=max(2, int(3 * s)))
            E([x - 3, up(52), x + 3, up(46)], fill=wood + (230,))
        L((12, up(36)), (52, up(36)), fill=wood + (240,), width=max(2, int(3 * s)))
        L((12, up(22)), (52, up(22)), fill=wood + (240,), width=max(2, int(3 * s)))
        L((13, up(38)), (51, up(38)), fill=_mix(wood, (180, 140, 80), 0.4) + (130,), width=max(1, int(s)))
    elif kind == "rubble":
        for x0, y0, x1, y1, col in [
            (14, up(16), 34, up(2), stone_dk),
            (26, up(22), 50, up(6), stone),
            (18, up(28), 36, up(14), stone_hi),
            (34, up(14), 54, up(2), _shade(stone, 0.85)),
        ]:
            E([x0, y0, x1, y1], fill=col + (235,))
        R([24, up(24), 38, up(12)], fill=stone_dk + (215,))
    elif kind in ("rock_pillar",):
        top = up(88)
        base = up(6)
        P([(22, base), (26, top), (38, top - 4), (42, base)], fill=stone + (250,))
        P([(22, base), (26, top), (30, top + 2), (28, base)], fill=stone_dk + (230,))
        P([(34, top), (38, top - 4), (42, base), (36, base)], fill=stone_hi + (190,))
        E([16, base - 4, 48, base + 12], fill=(90, 80, 65, 170))
        E([28, up(60), 36, up(50)], fill=(90, 120, 50, 150))
        L((32, top + 2), (31, up(20)), fill=stone_dk + (150,), width=max(1, int(s)))
    elif kind in ("floor_seal",):
        cy = up(16)
        E([10, cy - 4, 54, cy + 16], fill=(0, 0, 0, 45))
        E([12, cy - 6, 52, cy + 14], outline=gold + (235,), width=max(2, int(2 * s)))
        E([18, cy - 2, 46, cy + 12], outline=_mix(gold, (120, 90, 40), 0.3) + (210,), width=max(1, int(s)))
        E([24, cy + 2, 40, cy + 10], outline=C["seal_ink"] + (210,), width=max(1, int(s)))
        L((32, cy - 4), (32, cy + 12), fill=gold + (210,), width=max(1, int(s)))
        L((16, cy + 4), (48, cy + 4), fill=gold + (210,), width=max(1, int(s)))
        E([29, cy + 1, 35, cy + 7], fill=_mix(gold, (255, 230, 140), 0.5) + (230,))
    elif kind == "driftwood":
        L((10, up(14)), (54, up(20)), fill=(160, 130, 90, 245), width=max(3, int(5 * s)))
        L((16, up(28)), (28, up(8)), fill=(140, 110, 70, 235), width=max(2, int(3 * s)))
        L((40, up(30)), (50, up(10)), fill=(150, 120, 80, 235), width=max(2, int(3 * s)))
    elif kind == "waterfall":
        R([26, up(92), 38, up(20)], fill=(90, 190, 200, 210))
        E([18, up(24), 46, up(6)], fill=(70, 170, 185, 190))
        L((28, up(90)), (28, up(22)), fill=(200, 240, 245, 170), width=max(2, int(2 * s)))
        L((34, up(86)), (34, up(18)), fill=(180, 230, 240, 150), width=max(1, int(s)))
        E([22, up(14), 42, up(2)], fill=(220, 245, 250, 120))
    elif kind == "rock_cluster":
        E([12, up(28), 36, up(6)], fill=(110, 120, 115, 245))
        E([28, up(36), 54, up(10)], fill=(130, 140, 135, 245))
        E([20, up(44), 40, up(24)], fill=(145, 155, 150, 235))
        E([8, up(16), 24, up(2)], fill=(100, 110, 105, 220))
    elif kind == "basalt_pillar":
        top = up(96)
        base = up(8)
        P([(26, top), (40, top + 8), (38, base), (24, base - 4)], fill=(55, 50, 48, 250))
        P([(18, top + 12), (26, top), (24, base - 4), (16, base - 2)], fill=(70, 64, 60, 240))
        P([(36, top + 6), (42, top + 14), (40, base), (36, base)], fill=(90, 70, 50, 200))
        # lava kiss on edge
        L((38, up(70)), (37, up(20)), fill=(255, 140, 40, 160), width=max(1, int(s)))
        E([14, base - 6, 50, base + 10], fill=(40, 36, 34, 190))
    elif kind == "steam_vent":
        E([20, up(18), 44, up(4)], fill=(80, 90, 95, 240))
        E([26, up(36), 38, up(16)], fill=(200, 220, 230, 150))
        E([22, up(52), 42, up(30)], fill=(220, 235, 240, 110))
        E([24, up(64), 40, up(44)], fill=(235, 245, 250, 80))
    elif kind == "ash_rock":
        E([16, up(22), 44, up(4)], fill=(90, 85, 80, 245))
        R([24, up(34), 38, up(16)], fill=(70, 65, 60, 240))
        E([28, up(40), 36, up(30)], fill=(110, 70, 40, 120))
    elif kind == "crystal":
        top = up(88)
        P([(32, top), (46, up(28)), (32, up(8)), (18, up(28))], fill=(90, 170, 230, 240))
        P([(32, top), (40, up(30)), (32, up(12))], fill=(160, 215, 255, 230))
        L((32, top + 2), (32, up(10)), fill=(220, 245, 255, 200), width=max(2, int(2 * s)))
        E([24, up(10), 40, up(0)], fill=(60, 100, 140, 150))
    elif kind == "ice_shard":
        P([(28, up(76)), (44, up(28)), (30, up(8)), (16, up(30))], fill=(170, 210, 240, 230))
        L((28, up(74)), (34, up(14)), fill=(230, 245, 255, 200), width=max(2, int(2 * s)))
        E([22, up(10), 40, up(0)], fill=(140, 180, 210, 140))
    elif kind == "ice_sheet":
        P([(12, up(14)), (32, up(26)), (52, up(14)), (32, up(2))], fill=(180, 220, 245, 130), outline=(140, 190, 230, 190))
        L((20, up(14)), (44, up(14)), fill=(230, 245, 255, 120), width=max(1, int(s)))
    elif kind == "spark":
        E([26, up(28), 38, up(16)], fill=(180, 240, 255, 190))
        L((32, up(40)), (32, up(8)), fill=(200, 250, 255, 150), width=max(1, int(s)))
        L((18, up(22)), (46, up(22)), fill=(200, 250, 255, 150), width=max(1, int(s)))
    elif kind == "conduit":
        cy = up(16)
        P([(10, cy), (32, cy - 10), (54, cy), (32, cy + 10)], fill=(40, 30, 70, 100))
        L((12, cy), (52, cy), fill=(80, 40, 160, 210), width=max(3, int(4 * s)))
        L((14, cy), (50, cy), fill=(80, 220, 255, 230), width=max(2, int(2 * s)))
        L((20, cy), (44, cy), fill=(200, 250, 255, 190), width=max(1, int(s)))
        E([26, cy - 6, 38, cy + 6], fill=(160, 100, 255, 150))
        E([29, cy - 3, 35, cy + 3], fill=(220, 250, 255, 210))
    elif kind == "crystal_bolt":
        top = up(92)
        P([(32, top), (44, up(40)), (32, up(8)), (20, up(40))], fill=(90, 60, 180, 240))
        P([(32, top), (38, up(42)), (32, up(14))], fill=(140, 220, 255, 230))
        P([(32, up(60)), (50, up(32)), (32, up(24)), (26, up(40))], fill=(180, 120, 255, 190))
        L((32, top + 2), (32, up(10)), fill=(230, 250, 255, 210), width=max(2, int(2 * s)))
        L((22, up(48)), (42, up(32)), fill=(200, 180, 255, 170), width=max(1, int(s)))
        E([26, up(10), 38, up(0)], fill=(60, 40, 100, 150))
    elif kind == "arc":
        A([8, up(40), 56, up(8)], 200, 340, fill=(120, 60, 200, 170), width=max(3, int(4 * s)))
        A([10, up(38), 54, up(10)], 200, 340, fill=(80, 220, 255, 230), width=max(2, int(2 * s)))
        A([12, up(36), 52, up(12)], 205, 335, fill=(220, 250, 255, 190), width=max(1, int(s)))
        E([16, up(32), 24, up(24)], fill=(180, 120, 255, 170))
        E([40, up(34), 48, up(26)], fill=(140, 230, 255, 170))
    else:
        E([24, up(24), 40, up(8)], fill=(200, 100, 200, 200))
    return img


def _paint_and_downscale(img: Image.Image, target_w: int, target_h: int) -> Image.Image:
    if img.size == (target_w, target_h):
        return img
    return img.resize((target_w, target_h), Image.Resampling.LANCZOS)


BASE_TERRAIN_SPECS = [
    ("ground", 0),
    ("mud", 0),
    ("water", 0),
    ("lava", 0),
    ("void", 0),
    ("ground_e1", 1),
    ("ground_e2", 2),
    ("mud_e1", 1),
]

BASE_PROPS = ["ruins", "well", "hay", "fence", "rubble", "rock_pillar", "floor_seal"]

REGION_EXTRA_PROPS = {
    "brine": ["driftwood", "waterfall", "rock_cluster"],
    "slag": ["basalt_pillar", "steam_vent", "ash_rock"],
    "wind": ["crystal", "ice_shard", "ice_sheet", "spark"],
    # storm props appended after all existing tiles (GID stability for brine/slag/wind)
}

# Appended at end of catalog so brine_/slag_/wind_ terrain GIDs stay put
STORM_PROPS = ["conduit", "crystal_bolt", "arc"]


def _terrain_colors(C, base: str):
    if base == "void":
        return C["void_fill"], (40, 40, 50), (20, 20, 28), C["void_edge"]
    return (
        C[f"{base}_fill"],
        C[f"{base}_hi"],
        C[f"{base}_lo"],
        C[f"{base}_edge"],
    )


def _append_terrain(catalog, prefix: str, C, include_lava=True):
    global TILE_W, TILE_H
    specs = [
        ("ground", 0),
        ("mud", 0),
        ("water", 0),
        ("lava", 0),
        ("ground_e1", 1),
        ("ground_e2", 2),
        ("mud_e1", 1),
    ]
    ow, oh = TILE_W, TILE_H
    TILE_W, TILE_H = ow * 2, oh * 2
    for name, elev in specs:
        base = name.split("_")[0]
        if base == "lava" and not include_lava:
            continue
        fill, hi, lo, edge = _terrain_colors(C, base)
        tile_name = f"{prefix}_{name}" if prefix else name
        img = make_terrain_tile(base, fill, hi, lo, edge, elev=elev, C=C)
        img = _paint_and_downscale(img, ow, oh + elev * 8)
        path = TILES / f"{tile_name}.png"
        img = _save_tile(img, path)
        catalog.append(
            {
                "file": f"tiles/{tile_name}.png",
                "name": tile_name,
                "terrain": base,
                "elevation": elev,
                "paint_only": False,
                "w": img.width,
                "h": img.height,
            }
        )
    TILE_W, TILE_H = ow, oh


def generate_full_catalog():
    """Base Crosshaven tiles first (stable GIDs), then region tints + extra props."""
    TILES.mkdir(parents=True, exist_ok=True)
    catalog = []

    # --- Base (must match build_crosshaven order for GID stability) ---
    # Painted dress v1: render at 2× then downscale for smoother brush feel.
    global TILE_W, TILE_H
    ow, oh = TILE_W, TILE_H
    TILE_W, TILE_H = ow * 2, oh * 2
    for name, elev in BASE_TERRAIN_SPECS:
        base = name.split("_")[0]
        fill, hi, lo, edge = _terrain_colors(BASE_C, base)
        img = make_terrain_tile(base, fill, hi, lo, edge, elev=elev, C=BASE_C)
        img = _paint_and_downscale(img, ow, oh + elev * 8)
        path = TILES / f"{name}.png"
        img = _save_tile(img, path)
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
    for p in BASE_PROPS:
        img = make_prop_tile(p, BASE_C)
        img = _paint_and_downscale(img, ow, max(48, img.height // 2))
        path = TILES / f"prop_{p}.png"
        img = _save_tile(img, path)
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
    # region props also at 2x while scaled (tinted to region palette)
    for region, props in REGION_EXTRA_PROPS.items():
        RC = REGION_PALETTES.get(region, BASE_C)
        for p in props:
            img = make_prop_tile(p, RC)
            img = _paint_and_downscale(img, ow, max(48, img.height // 2))
            path = TILES / f"prop_{p}.png"
            img = _save_tile(img, path)
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
    TILE_W, TILE_H = ow, oh

    # --- Region terrain tints ---
    _append_terrain(catalog, "brine", BRINE_C, include_lava=False)
    _append_terrain(catalog, "slag", SLAG_C, include_lava=True)
    _append_terrain(catalog, "wind", WIND_C, include_lava=False)

    # Stormspire — append only (keeps prior region GIDs stable)
    ow, oh = TILE_W, TILE_H
    TILE_W, TILE_H = ow * 2, oh * 2
    for p in STORM_PROPS:
        img = make_prop_tile(p, STORM_C)
        img = _paint_and_downscale(img, ow, max(48, img.height // 2))
        path = TILES / f"prop_{p}.png"
        img = _save_tile(img, path)
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
    TILE_W, TILE_H = ow, oh
    _append_terrain(catalog, "storm", STORM_C, include_lava=False)

    return catalog


def empty_board(n=15):
    return [
        [{"terrain": "ground", "elevation": 0, "paint_only": []} for _ in range(n)]
        for _ in range(n)
    ]


def apply_terrain(cells, coords, terrain):
    for x, y in coords:
        cells[y][x]["terrain"] = terrain


def apply_elev(cells, coords, elev):
    for x, y in coords:
        cells[y][x]["elevation"] = elev


def apply_props(cells, props: dict):
    for (x, y), plist in props.items():
        cells[y][x]["paint_only"] = list(plist)


def write_tsx(catalog):
    ts = ET.Element(
        "tileset",
        {
            "version": "1.10",
            "tiledversion": "1.11.0",
            "name": "koliseo_base",
            "tilewidth": str(TILE_W),
            "tileheight": str(TILE_H),
            "tilecount": str(len(catalog)),
            "columns": "0",
        },
    )
    for i, t in enumerate(catalog):
        tile = ET.SubElement(ts, "tile", {"id": str(i)})
        props = ET.SubElement(tile, "properties")
        ET.SubElement(
            props, "property", {"name": "terrain", "type": "string", "value": t["terrain"]}
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
                props, "property", {"name": "prop", "type": "string", "value": t["prop"]}
            )
        ET.SubElement(
            tile,
            "image",
            {"source": t["file"], "width": str(t["w"]), "height": str(t["h"])},
        )
    path = ROOT / "tileset_koliseo_base.tsx"
    _write_xml(ts, path)
    return path, {t["name"]: i for i, t in enumerate(catalog)}


def _write_xml(elem, path: Path):
    rough = ET.tostring(elem, encoding="utf-8")
    pretty = minidom.parseString(rough).toprettyxml(indent=" ", encoding="utf-8")
    path.write_bytes(pretty)


def write_tmx(cells, id_of, arena: str, tile_prefix: str):
    """tile_prefix e.g. 'brine' → brine_ground, brine_mud, …"""
    N = 15

    def gid(name):
        return id_of[name] + 1

    def tname(base):
        return f"{tile_prefix}_{base}" if tile_prefix else base

    prop_tile = {
        "ruins": "prop_ruins",
        "well": "prop_well",
        "hay": "prop_hay",
        "fence": "prop_fence",
        "rubble": "prop_rubble",
        "rock_pillar": "prop_rock_pillar",
        "floor_seal": "prop_floor_seal",
        "driftwood": "prop_driftwood",
        "waterfall": "prop_waterfall",
        "rock_cluster": "prop_rock_cluster",
        "basalt_pillar": "prop_basalt_pillar",
        "steam_vent": "prop_steam_vent",
        "ash_rock": "prop_ash_rock",
        "crystal": "prop_crystal",
        "ice_shard": "prop_ice_shard",
        "ice_sheet": "prop_ice_sheet",
        "spark": "prop_spark",
        "conduit": "prop_conduit",
        "crystal_bolt": "prop_crystal_bolt",
        "arc": "prop_arc",
    }

    ground_data, terrain_data, elev_data, props_data = [], [], [], []
    for y in range(N):
        for x in range(N):
            c = cells[y][x]
            ground_data.append(str(gid(tname("ground"))))
            e = c["elevation"]
            if e == 0 and c["terrain"] != "ground":
                terrain_data.append(str(gid(tname(c["terrain"]))))
            else:
                terrain_data.append("0")
            if e == 0:
                elev_data.append("0")
            elif e == 1:
                if c["terrain"] == "mud":
                    elev_data.append(str(gid(tname("mud_e1"))))
                else:
                    elev_data.append(str(gid(tname("ground_e1"))))
            else:
                elev_data.append(str(gid(tname("ground_e2"))))
            plist = c["paint_only"]
            if plist:
                props_data.append(str(gid(prop_tile[plist[0]])))
            else:
                props_data.append("0")

    def layer(name, lid, data_csv):
        el = ET.Element(
            "layer",
            {"id": str(lid), "name": name, "width": str(N), "height": str(N)},
        )
        data = ET.SubElement(el, "data", {"encoding": "csv"})
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
    mprops = ET.SubElement(root, "properties")
    ET.SubElement(mprops, "property", {"name": "arena", "type": "string", "value": arena})
    ET.SubElement(
        mprops, "property", {"name": "playable_size", "type": "string", "value": "15x15"}
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
            "value": f"{arena}_15x15_tags.json",
        },
    )
    ET.SubElement(root, "tileset", {"firstgid": "1", "source": "tileset_koliseo_base.tsx"})
    root.append(layer("ground", 1, ground_data))
    root.append(layer("terrain", 2, terrain_data))
    root.append(layer("elevation", 3, elev_data))
    root.append(layer("props_paint", 4, props_data))
    root.append(layer("meta", 5, ["0"] * (N * N)))

    path = ROOT / f"{arena}_15x15.tmx"
    _write_xml(root, path)
    return path


def write_tags(cells, arena: str):
    N = 15
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
    path = ROOT / f"{arena}_15x15_tags.json"
    path.write_text(json.dumps(out, indent=2) + "\n")
    return path, out


def cell_to_local(x, y):
    return ((x - y) * 32, (x + y) * 16)


def write_preview(cells, arena: str, label: str, bg_rgb, tile_prefix: str):
    N = 15
    pts = [cell_to_local(x, y) for y in range(N) for x in range(N)]
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    pad = 80
    min_x, max_x = min(xs) - 40, max(xs) + 40
    min_y, max_y = min(ys) - 40, max(ys) + 80
    W = int(max_x - min_x + pad * 2)
    H = int(max_y - min_y + pad * 2 + 40)
    img = Image.new("RGB", (W, H), bg_rgb)
    draw = ImageDraw.Draw(img, "RGBA")
    r0, g0, b0 = bg_rgb
    for i in range(H):
        t = i / H
        col = (int(r0 - 20 * t), int(g0 - 25 * t), int(b0 - 15 * t))
        draw.line([(0, i), (W, i)], fill=col)

    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(img.convert("RGBA"))

    order = sorted(
        ((x, y) for y in range(N) for x in range(N)), key=lambda p: (p[0] + p[1], p[0])
    )
    cache = {}

    def get_tile(name):
        if name not in cache:
            cache[name] = Image.open(TILES / f"{name}.png").convert("RGBA")
        return cache[name]

    def tname(base):
        return f"{tile_prefix}_{base}" if tile_prefix else base

    for x, y in order:
        c = cells[y][x]
        if c["elevation"] == 1:
            base_name = tname("mud_e1") if c["terrain"] == "mud" else tname("ground_e1")
        elif c["elevation"] >= 2:
            base_name = tname("ground_e2")
        elif c["terrain"] != "ground":
            base_name = tname(c["terrain"])
        else:
            base_name = tname("ground")

        tile = get_tile(base_name)
        lx, ly = cell_to_local(x, y)
        px = int(lx - min_x + pad - TILE_W // 2)
        py = int(ly - min_y + pad)
        if tile.height > TILE_H:
            py -= tile.height - TILE_H
        canvas.alpha_composite(tile, (px, py))

        for pi, prop in enumerate(c["paint_only"]):
            pt = get_tile(f"prop_{prop}")
            ppx = px + pi * 4
            if tile.height > TILE_H:
                ppy = py
            else:
                ppy = py - (pt.height - TILE_H)
            canvas.alpha_composite(pt, (ppx, ppy))

    grid = ImageDraw.Draw(canvas)
    for y in range(N):
        for x in range(N):
            lx, ly = cell_to_local(x, y)
            ox = lx - min_x + pad
            oy = ly - min_y + pad
            diamond = [(ox, oy), (ox + 32, oy + 16), (ox, oy + 32), (ox - 32, oy + 16)]
            grid.polygon(diamond, outline=(255, 255, 255, 55))

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

    bw, bh = 400, 52
    bx, by = (W - bw) // 2, 12
    grid.rounded_rectangle(
        [bx, by, bx + bw, by + bh], radius=8, fill=(40, 30, 15, 200)
    )
    grid.text((bx + 28, by + 8), label, font=font, fill=(255, 235, 180, 255))
    grid.text(
        (bx + 28, by + 32),
        "STASIUM XV · Koliseo · isometric 64×32",
        font=font_sm,
        fill=(220, 200, 150, 230),
    )

    out = canvas.convert("RGB")
    path = ROOT / f"{arena}_15x15_preview.png"
    out.save(path, optimize=True)
    return path


def counts_of(tags_or_cells):
    if isinstance(tags_or_cells, dict) and "cells" in tags_or_cells:
        cells = tags_or_cells["cells"]
        terrains = [c["terrain"] for c in cells]
        elevs = [c["elevation"] for c in cells]
    else:
        flat = [c for row in tags_or_cells for c in row]
        terrains = [c["terrain"] for c in flat]
        elevs = [c["elevation"] for c in flat]
    ctr = Counter(terrains)
    return {
        "ground": ctr.get("ground", 0),
        "mud": ctr.get("mud", 0),
        "water": ctr.get("water", 0),
        "lava": ctr.get("lava", 0),
        "elev": sum(1 for e in elevs if e >= 1),
        "elev2": sum(1 for e in elevs if e >= 2),
        "total": len(terrains),
    }


def ortho_neighbors(x, y, n=15):
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = x + dx, y + dy
        if 0 <= nx < n and 0 <= ny < n:
            yield nx, ny


def validate_elev_ramps(cells, n=15):
    """Every elev≥2 cell must have an ortho neighbor with elev≥1."""
    bad = []
    for y in range(n):
        for x in range(n):
            if cells[y][x]["elevation"] < 2:
                continue
            if not any(cells[ny][nx]["elevation"] >= 1 for nx, ny in ortho_neighbors(x, y, n)):
                bad.append((x, y))
    return bad


def validate_climb_drop(cells, n=15):
    """Check pairwise ortho steps: climb≤1, drop≤2 (informational — all adjacent pairs)."""
    violations = []
    for y in range(n):
        for x in range(n):
            e0 = cells[y][x]["elevation"]
            for nx, ny in ortho_neighbors(x, y, n):
                if (nx, ny) < (x, y):
                    continue
                e1 = cells[ny][nx]["elevation"]
                diff = e1 - e0
                if diff > 1:  # climb from e0 to e1
                    violations.append(((x, y, e0), (nx, ny, e1), "climb", diff))
                if diff < -2:  # drop from e0 to e1
                    violations.append(((x, y, e0), (nx, ny, e1), "drop", diff))
    return violations


def lava_reachability(cells, n=15):
    """Non-lava cells must form one 4-connected component (lava = impassable)."""
    walkable = [
        (x, y)
        for y in range(n)
        for x in range(n)
        if cells[y][x]["terrain"] != "lava"
    ]
    if not walkable:
        return 0, 0, False
    start = walkable[0]
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for nx, ny in ortho_neighbors(x, y, n):
            if (nx, ny) in seen:
                continue
            if cells[ny][nx]["terrain"] == "lava":
                continue
            seen.add((nx, ny))
            q.append((nx, ny))
    return len(seen), len(walkable), len(seen) == len(walkable)


def validate_board(cells, *, expect_lava=False, mud_water_band=(0.15, 0.25), check_reach=False):
    n = 15
    assert len(cells) == n and all(len(r) == n for r in cells)
    counts = counts_of(cells)
    assert counts["total"] == 225
    if not expect_lava:
        assert counts["lava"] == 0, counts
    share = (counts["mud"] + counts["water"]) / 225
    if mud_water_band is not None:
        lo, hi = mud_water_band
        assert lo <= share <= hi, f"mud+water share {share:.3f} outside [{lo},{hi}]"
    bad_ramps = validate_elev_ramps(cells)
    assert not bad_ramps, f"elev≥2 missing ramp neighbor: {bad_ramps}"
    # e0↔e2 adjacency is OK: voluntary climb uses the elev≥1 ramp neighbor.
    # Direct e0→e2 steps are simply illegal moves; Rules require the ramp present.
    reach = None
    if check_reach:
        reached, walkable, ok = lava_reachability(cells)
        assert ok, f"lava splits board: reachable {reached}/{walkable}"
        reach = (reached, walkable)
    return counts, share, reach
