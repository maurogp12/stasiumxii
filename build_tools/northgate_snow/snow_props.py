"""Northgate snow props: repaints of kit sprites plus painted pines.

Every output is a 2x master in props/_2x/ and a 1x copy in props/.
Buildings get `<id>_snow` (roof under snow, warm walls, amber windows) and
`<id>_snow_glow` (additive window light). Small props get a snow cap on
every top face. Pines, small firs and snow mounds are painted from scratch.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

from common import load, luma, periodic_noise, rgb_to_hsv, save_pair, smoothstep

SNOW_HI = np.array([0.975, 0.985, 1.0])
SNOW_LO = np.array([0.72, 0.76, 0.90])
SNOW_LINE = np.array([0.33, 0.37, 0.52])
ICE = np.array([0.80, 0.91, 1.0])
AMBER_HI = np.array([1.0, 0.88, 0.52])
AMBER_LO = np.array([0.93, 0.52, 0.16])

# Building recipes. roof_hue: (lo, hi, min_sat). roof_poly overrides the hue
# mask for sprites whose roof and walls share a colour.
BUILDINGS = {
    "cottage_slate": {"roof_hue": (195, 240, 0.30), "warm_walls": True},
    "cottage_slate_b": {"roof_hue": (195, 240, 0.30), "warm_walls": True},
    "bakery_2x2": {"roof_hue": (160, 200, 0.25), "warm_walls": True},
    "farmhouse_2x2": {"roof_hue": (25, 62, 0.35), "warm_walls": True, "roof_max_y": 0.62},
    "wall_tower": {"roof_hue": (195, 240, 0.12), "roof_max_y": 0.55},
    "market_stall": {"roof_hue": (345, 15, 0.40), "roof_max_y": 0.5, "close": 7, "light_too": True},
    "market_stall_b": {"roof_hue": (345, 15, 0.40), "roof_max_y": 0.5, "close": 7, "light_too": True},
    "northgate_spire": {
        "roof_poly": [(140, 4), (262, 220), (244, 246), (184, 263), (138, 338), (80, 300), (79, 282), (24, 246), (22, 230)],
        "chapel": True,
    },
}
# Small props: a snow cap on every top face. (cap px at 2x, puff px)
CAPPED = {
    "barrel": (7, 3),
    "barrels_group": (7, 3),
    "crate": (7, 3),
    "crate_apples": (8, 3),
    "crate_stack": (7, 3),
    "cart": (6, 3),
    "fence": (5, 2),
    "fence_wood_nesw": (5, 2),
    "fence_wood_nwse": (5, 2),
    "fence_post": (5, 2),
    "farm_fence_nesw": (5, 2),
    "farm_fence_nwse": (5, 2),
    "lamp_post": (6, 2),
    "well": (8, 3),
    "signpost_crossroads": (5, 2),
    "signpost_small": (5, 2),
    "hay_bale": (9, 3),
    "stone_wall_high_nesw": (8, 3),
    "stone_wall_high_nwse": (8, 3),
    "stone_wall_low_nesw": (7, 3),
    "stone_wall_low_nwse": (7, 3),
    "rock_small_c": (6, 2),
    "rock_small_d": (6, 2),
    "firewood_stack": (7, 3),
    "sacks_a": (6, 2),
    "bench_nesw": (5, 2),
    "bench_nwse": (5, 2),
    "quarry_rocks_a": (8, 3),
    "quarry_blocks": (8, 3),
    "watchtower_2x2": (8, 3),
    "net_rack": (5, 2),
    "fishing_hut_2x2": (9, 3),
}

_PLUS = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], dtype=bool)


def _gauss(x: np.ndarray, s: float) -> np.ndarray:
    return ndimage.gaussian_filter(x, s)


def _shift_down(m: np.ndarray) -> np.ndarray:
    """out[y] = m[y - 1]: true where the pixel above is set."""
    out = np.zeros_like(m)
    out[1:] = m[:-1]
    return out


def _shift_up(m: np.ndarray) -> np.ndarray:
    """out[y] = m[y + 1]: true where the pixel below is set."""
    out = np.zeros_like(m)
    out[:-1] = m[1:]
    return out


def _up_run(alpha: np.ndarray) -> np.ndarray:
    """Opaque pixels above each pixel in its column, counted until the first gap."""
    h, w = alpha.shape
    out = np.zeros((h, w), dtype=np.int32)
    run = np.zeros(w, dtype=np.int32)
    for y in range(h):
        run = np.where(alpha[y], run + 1, 0)
        out[y] = run
    return out


def _snow_colour(shade: np.ndarray) -> np.ndarray:
    t = smoothstep(0.0, 1.0, np.clip(shade, 0, 1))[..., None]
    return SNOW_LO * (1 - t) + SNOW_HI * t


def _wobble(w: int, freq: float, seed: int) -> np.ndarray:
    if w < 8:
        return np.full(w, 0.5)
    return periodic_noise(w, 8, freq, np.random.default_rng(seed))[0, :w]


def _outline(a: np.ndarray, snow: np.ndarray) -> np.ndarray:
    """Cool dark line where snow meets transparency, like the kit's ink."""
    op = a[..., 3] > 0.5
    edge = snow & ndimage.binary_dilation(~op, structure=_PLUS)
    out = a.copy()
    out[..., :3] = np.where(edge[..., None], out[..., :3] * 0.25 + SNOW_LINE * 0.75, out[..., :3])
    return out


def _cap(a: np.ndarray, thick: float, puff: float, seed: int, keep: np.ndarray | None = None) -> np.ndarray:
    """Snow cap on every top face, with a rounded puff above the silhouette."""
    h, w = a.shape[:2]
    op = a[..., 3] > 0.5
    up = _up_run(op)
    wob = _wobble(w, 3.0, seed)
    t_col = thick * (0.7 + 0.6 * wob)
    cap = op & (up <= t_col[None, :])
    # Do not cap slivers: a cap needs a little width.
    cap = ndimage.binary_opening(cap, structure=np.ones((1, 3), dtype=bool)) & op
    if keep is not None:
        cap &= ~keep
    p_col = np.round(puff * (0.3 + 0.9 * wob)).astype(int)
    top_edge = cap & (up == 1)
    add = np.zeros((h, w), dtype=bool)
    ys, xs = np.nonzero(top_edge)
    for y, x in zip(ys, xs):
        for k in range(1, p_col[x] + 1):
            if y - k >= 0 and not op[y - k, x]:
                add[y - k, x] = True
    add = (ndimage.binary_closing(add | cap, structure=np.ones((3, 3), dtype=bool)) & ~op) | add
    snow = cap | add
    shade = np.clip(1.0 - 0.07 * up.clip(0, 10), 0.35, 1.0)
    out = a.copy()
    out[..., :3] = np.where(snow[..., None], _snow_colour(shade), out[..., :3])
    out[..., 3] = np.where(add, 1.0, out[..., 3])
    return _outline(out, snow)


def _roof_mask(a: np.ndarray, recipe: dict) -> np.ndarray:
    h, w = a.shape[:2]
    op = a[..., 3] > 0.5
    if "roof_poly" in recipe:
        img = Image.new("L", (w, h), 0)
        ImageDraw.Draw(img).polygon(recipe["roof_poly"], fill=255)
        return (np.asarray(img) > 0) & op
    lo, hi, sat = recipe["roof_hue"]
    hsv = rgb_to_hsv(a[..., :3])
    hue = hsv[..., 0]
    in_hue = (hue >= lo) & (hue <= hi) if lo <= hi else (hue >= lo) | (hue <= hi)
    m = op & in_hue & (hsv[..., 1] >= sat)
    if recipe.get("light_too"):
        # Striped canopies: the pale stripes are roof as well.
        m |= op & (hsv[..., 1] < 0.35) & (hsv[..., 2] > 0.75)
    if "roof_max_y" in recipe:
        m[int(h * recipe["roof_max_y"]):] = False
    close = int(recipe.get("close", 5))
    m = ndimage.binary_closing(m, structure=np.ones((close, close), dtype=bool))
    m = ndimage.binary_fill_holes(m)
    lab, n = ndimage.label(m)
    if n == 0:
        return m
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    keep = [i + 1 for i, s in enumerate(sizes) if s >= max(sizes) * 0.15]
    roof = np.isin(lab, keep)
    # Shingle ink between roof pixels belongs to the roof too.
    return ndimage.binary_closing(roof, structure=np.ones((3, 3), dtype=bool)) & op


def _windows(a: np.ndarray, roof: np.ndarray, chapel: bool) -> np.ndarray:
    """Glass panes: small blue or cream patches in the walls."""
    op = a[..., 3] > 0.5
    hsv = rgb_to_hsv(a[..., :3])
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    wall = op & ~ndimage.binary_dilation(roof, iterations=2)
    blue = wall & (h > 195) & (h < 245) & (s > 0.35) & (v < 0.85)
    cream = wall & (h > 28) & (h < 62) & (s > 0.18) & (v > 0.78)
    if chapel:
        # The chapel's slit windows are dark blue-black glass.
        blue = wall & (h > 195) & (h < 250) & (s > 0.25) & (v < 0.45)
    lab, n = ndimage.label(blue | cream)
    out = np.zeros_like(op)
    limit = 900 if chapel else 360
    for i in range(1, n + 1):
        comp = lab == i
        size = int(comp.sum())
        if 6 <= size <= limit:
            ys, xs = np.nonzero(comp)
            # Chimneys share the cream paint. Panes sit in the lower walls.
            low_enough = chapel or ys.mean() > op.shape[0] * 0.45
            if ys.max() - ys.min() >= 2 and xs.max() - xs.min() >= 1 and low_enough:
                out |= comp
    return out


def _amber(a: np.ndarray, panes: np.ndarray) -> np.ndarray:
    out = a.copy()
    if not panes.any():
        return out
    op = a[..., 3] > 0.5
    glass = ndimage.binary_dilation(panes, iterations=1) & op
    lab, n = ndimage.label(glass)
    hh, ww = panes.shape
    yy, xx = np.mgrid[0:hh, 0:ww]
    t = np.zeros((hh, ww))
    for i in range(1, n + 1):
        comp = lab == i
        ys, xs = np.nonzero(comp)
        ry = max((ys.max() - ys.min()) * 0.6, 1)
        rx = max((xs.max() - xs.min()) * 0.6, 1)
        d = np.sqrt(((yy - ys.mean()) / ry) ** 2 + ((xx - xs.mean()) / rx) ** 2)
        t = np.where(comp, np.clip(1.15 - d, 0, 1), t)
    lum = luma(a[..., :3])
    mullion = glass & (lum < 0.2) & ~panes
    col = AMBER_LO[None, None, :] * (1 - t[..., None]) + AMBER_HI[None, None, :] * t[..., None]
    paint = glass & ~mullion
    out[..., :3] = np.where(paint[..., None], col, out[..., :3])
    return out


# Glow maps reach past the sprite: the same image grown by GLOW_PAD (2x px)
# on every side. The scene offsets them by half that at 1x.
GLOW_PAD = 24


def _glow_map(shape, panes: np.ndarray, extra: np.ndarray | None = None, strength: float = 1.0) -> np.ndarray:
    m = panes.astype(float)
    if extra is not None:
        m = np.maximum(m, extra.astype(float))
    m = np.pad(m, GLOW_PAD)
    g = np.clip((_gauss(m, 6.0) * 2.0 + _gauss(m, 2.0) * 0.8) * strength, 0, 1)
    out = np.zeros((m.shape[0], m.shape[1], 4))
    out[..., 0] = 1.0
    out[..., 1] = 0.70
    out[..., 2] = 0.32
    out[..., 3] = g * 0.9
    return out


def lamp_glow(a: np.ndarray) -> np.ndarray:
    hsv = rgb_to_hsv(a[..., :3])
    lit = (a[..., 3] > 0.5) & (hsv[..., 0] > 28) & (hsv[..., 0] < 70) & (hsv[..., 1] > 0.25) & (hsv[..., 2] > 0.7)
    lit = ndimage.binary_dilation(lit, iterations=2)
    return _glow_map(a.shape, lit, strength=1.4)


def _warm_walls(a: np.ndarray, roof: np.ndarray, panes: np.ndarray) -> np.ndarray:
    """Whitewash to warm stone-and-timber: low-saturation light wall paint."""
    out = a.copy()
    op = a[..., 3] > 0.5
    hsv = rgb_to_hsv(a[..., :3])
    plaster = op & ~roof & ~ndimage.binary_dilation(panes, iterations=1) & (hsv[..., 1] < 0.16) & (hsv[..., 2] > 0.62)
    lum = luma(a[..., :3])
    stone = np.array([0.64, 0.55, 0.46])
    n = periodic_noise(a.shape[1], a.shape[0], 14.0, np.random.default_rng(3))
    col = stone[None, None, :] * (0.74 + 0.34 * lum[..., None]) * (0.92 + 0.12 * n[..., None])
    out[..., :3] = np.where(plaster[..., None], np.clip(col, 0, 1), out[..., :3])
    return out


def _roof_snow(a: np.ndarray, roof: np.ndarray, seed: int) -> tuple[np.ndarray, np.ndarray]:
    h, w = roof.shape
    rng = np.random.default_rng(seed)
    out = a.copy()
    lum = luma(a[..., :3])
    soft = _gauss(lum, 2.2)
    vals = soft[roof]
    lo, hi = (np.percentile(vals, 5), np.percentile(vals, 95)) if vals.size else (0.0, 1.0)
    f = np.clip((soft - lo) / max(hi - lo, 1e-3), 0, 1)
    # Compressed, so the shingles read as soft lumps of snow.
    col = _snow_colour(0.42 + 0.58 * f)
    out[..., :3] = np.where(roof[..., None], col, out[..., :3])
    # A thick rounded lip under every eave.
    eave = roof & ~_shift_up(roof)
    wob = _wobble(w, 6.0, seed)
    lip_len = np.round(3 + 4 * wob).astype(int)
    lip = np.zeros_like(roof)
    ys, xs = np.nonzero(eave)
    for y, x in zip(ys, xs):
        for k in range(1, lip_len[x] + 1):
            if y + k < h:
                lip[y + k, x] = True
    lip = ndimage.binary_closing(lip, structure=np.ones((3, 3), dtype=bool)) & ~roof
    lip_shade = 0.9 - 0.4 * _gauss(lip.astype(float), 1.0)
    out[..., :3] = np.where(lip[..., None], _snow_colour(lip_shade), out[..., :3])
    out[..., 3] = np.where(lip, 1.0, out[..., 3])
    # Icicles hang from some of the lip.
    ice = np.zeros_like(roof)
    lip_bottom = lip & ~_shift_up(lip)
    by, bx = np.nonzero(lip_bottom)
    last = -99
    for i in np.argsort(bx):
        x, y = int(bx[i]), int(by[i])
        if x - last < 9 or rng.random() > 0.35:
            continue
        last = x
        length = int(4 + rng.random() * 9)
        for k in range(length):
            half = 1 if k < length * 0.5 else 0
            for dx in range(-half, half + 1):
                yy, xx = y + 1 + k, x + dx
                if 0 <= yy < h and 0 <= xx < w:
                    ice[yy, xx] = True
    out[..., :3] = np.where(ice[..., None], ICE, out[..., :3])
    out[..., 3] = np.where(ice, np.maximum(out[..., 3], 0.92), out[..., 3])
    snow = roof | lip
    out = _outline(out, snow | ice)
    # Ink under the lip so it reads as a thick overhang, not a stripe.
    under = _shift_down(lip) & ~lip & ~roof & ~ice & (out[..., 3] > 0.5)
    out[..., :3] = np.where(under[..., None], out[..., :3] * 0.4 + SNOW_LINE * 0.4, out[..., :3])
    return out, snow | ice


def _frost_moss(a: np.ndarray) -> np.ndarray:
    """Green moss on stone turns to frost."""
    out = a.copy()
    hsv = rgb_to_hsv(a[..., :3])
    moss = (a[..., 3] > 0.5) & (hsv[..., 0] > 60) & (hsv[..., 0] < 150) & (hsv[..., 1] > 0.15)
    lum = luma(a[..., :3])
    col = (SNOW_LO * 0.6 + SNOW_HI * 0.4)[None, None, :] * (0.85 + 0.25 * lum[..., None])
    out[..., :3] = np.where(moss[..., None], np.clip(col, 0, 1), out[..., :3])
    return out


def _chapel_door(a: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Warm arched doorway at the foot of the chapel's lit (left) face.

    The left face drops 0.54 px per px toward the front corner. The blue
    banner above it turns a deep red cloth.
    """
    out = a.copy()
    h, w = a.shape[:2]
    hsv = rgb_to_hsv(a[..., :3])
    banner = (a[..., 3] > 0.5) & (hsv[..., 0] > 200) & (hsv[..., 0] < 235) & (hsv[..., 1] > 0.6) & (hsv[..., 2] > 0.45)
    banner[:270] = False
    lum = luma(a[..., :3])
    red = np.array([0.62, 0.16, 0.14])
    out[..., :3] = np.where(banner[..., None], np.clip(red * (0.6 + 0.7 * lum[..., None]), 0, 1), out[..., :3])
    door = np.zeros((h, w), dtype=bool)
    frame = np.zeros((h, w), dtype=bool)
    t_map = np.zeros((h, w))
    x0, x1 = 90, 112

    def base(x: float) -> float:
        return 345.0 + 0.54 * (x - 45.0)

    tall = 26.0
    for x in range(x0 - 3, x1 + 4):
        bottom = base(x) - 1
        u = (x - (x0 + x1) / 2.0) / ((x1 - x0) / 2.0)
        arch = np.sqrt(max(0.0, 1 - min(abs(u), 1.0) ** 2)) * 8.0
        top = bottom - tall - arch
        for y in range(int(top) - 3, int(bottom) + 1):
            if not (0 <= y < h):
                continue
            if x0 <= x <= x1 and y >= top:
                door[y, x] = True
                t_map[y, x] = np.clip(1 - ((y - top) / (bottom - top)) * 0.5 - abs(u) * 0.35, 0, 1)
            elif y >= top - 3:
                frame[y, x] = True
    frame &= ~door
    out[..., :3] = np.where(frame[..., None], np.array([0.34, 0.31, 0.30]), out[..., :3])
    col = AMBER_LO[None, None, :] * (1 - t_map[..., None]) + AMBER_HI[None, None, :] * t_map[..., None]
    out[..., :3] = np.where(door[..., None], col, out[..., :3])
    # Two door leaves standing open: a dark wood edge each side.
    for x in (x0, x0 + 1, x0 + 2, x1 - 2, x1 - 1, x1):
        for y in range(h):
            if door[y, x]:
                out[y, x, :3] = np.array([0.40, 0.24, 0.12])
    # A snowy step in front.
    step = np.zeros((h, w), dtype=bool)
    for x in range(x0 - 4, x1 + 5):
        b = int(base(x))
        for y in range(b, b + 4):
            if 0 <= y < h and a[y, x, 3] > 0.5:
                step[y, x] = True
    out[..., :3] = np.where(step[..., None], _snow_colour(np.full((h, w), 0.85)), out[..., :3])
    return out, door


def snow_building(src: Path, recipe: dict, seed: int) -> tuple[np.ndarray, np.ndarray]:
    a = load(src)
    roof = _roof_mask(a, recipe)
    chapel = bool(recipe.get("chapel", False))
    panes = _windows(a, roof, chapel)
    out = a.copy()
    if recipe.get("warm_walls"):
        out = _warm_walls(out, roof, panes)
    if chapel:
        out = _frost_moss(out)
    out = _amber(out, panes)
    extra = None
    if chapel:
        out, extra = _chapel_door(out)
    out, snow = _roof_snow(out, roof, seed)
    # Chimney tops, finials, sills: a cap on every remaining top face.
    out = _cap(out, 6, 3, seed + 1, keep=snow)
    return out, _glow_map(out.shape, panes, extra)


# --- Painted pines -------------------------------------------------------

def _finish(img: Image.Image, k: int) -> np.ndarray:
    small = img.resize((img.width // k, img.height // k), Image.LANCZOS)
    return np.clip(np.asarray(small).astype(np.float64) / 255.0, 0, 1)


def _tier_points(cx, top, bottom, half_w, rng, teeth):
    """A drooping bough tier: peak at top, jagged lower hem."""
    pts = [(cx, top), (cx + half_w * 0.55, top + (bottom - top) * 0.55)]
    for i in range(teeth + 1):
        t = i / teeth
        x = cx + half_w - 2 * half_w * t
        y = bottom + (1 - (2 * t - 1) ** 2) * (bottom - top) * 0.10
        pts.append((x, y))
        if i < teeth:
            pts.append((x - half_w / teeth, y - (bottom - top) * (0.16 + 0.10 * rng.random())))
    pts.append((cx - half_w * 0.55, top + (bottom - top) * 0.55))
    return pts


def _hem(cx, y_top, y_bot, half, rng, teeth):
    """Drooping bough outline: peak, bowed flanks, a jagged lower hem."""
    pts = [(cx, y_top)]
    pts.append((cx + half * 0.62, y_top + (y_bot - y_top) * 0.62))
    for i in range(teeth + 1):
        t = i / teeth
        x = cx + half - 2 * half * t
        y = y_bot + (1 - (2 * t - 1) ** 2) * (y_bot - y_top) * 0.06 + (rng.random() - 0.5) * (y_bot - y_top) * 0.05
        pts.append((x, y))
        if i < teeth:
            pts.append((x - half / teeth, y - (y_bot - y_top) * (0.10 + 0.08 * rng.random())))
    pts.append((cx - half * 0.62, y_top + (y_bot - y_top) * 0.62))
    return pts


def paint_pine(w: int, h: int, tiers: int, seed: int, small: bool = False) -> np.ndarray:
    """Dense dark pine, boughs loaded with snow on their lit upper faces."""
    k = 4
    rng = np.random.default_rng(seed)
    W, H = w * k, h * k
    cx = W / 2
    ink = (30, 28, 38, 255)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base_y = H - (13 if small else 20) * k
    top = 6 * k
    span = base_y - top
    max_half = W * 0.47
    d.ellipse([cx - W * 0.40, H - 14 * k, cx + W * 0.40, H - 2 * k], fill=(60, 70, 120, 60))
    d.rectangle([cx - 4 * k, base_y - 14 * k, cx + 4 * k, H - 8 * k], fill=(74, 50, 34, 255), outline=ink, width=2 * k)
    greens = [(22, 58, 48), (27, 70, 54), (32, 82, 60)]
    # Bottom tier first, so each upper tier's hem hangs over the one below.
    bounds = []
    for i in range(tiers):
        y_top = top + span * (i / tiers) ** 1.15 * 0.96
        y_bot = top + span * min(((i + 1.0) / tiers) ** 0.95, 1.0)
        if i == tiers - 1:
            y_bot = base_y
        bounds.append((y_top, y_bot))
    for i in reversed(range(tiers)):
        y_top, y_bot = bounds[i]
        frac = (y_bot - top) / span
        half = max_half * (0.18 + 0.82 * frac) * (0.94 + 0.12 * rng.random())
        teeth = 3 + int(frac * 4)
        pts = _hem(cx, y_top, y_bot, half, rng, teeth)
        tier = Image.new("L", (W, H), 0)
        ImageDraw.Draw(tier).polygon(pts, fill=255)
        tier_in = Image.new("L", (W, H), 0)
        ImageDraw.Draw(tier_in).polygon([(cx + (x - cx) * 0.95, y_top + (y - y_top) * 0.96 + 0.8 * k) for x, y in pts], fill=255)
        g = greens[i % 3]
        layer = Image.new("RGBA", (W, H), ink)
        img.paste(layer, (0, 0), tier)
        body = Image.new("RGBA", (W, H), g + (255,))
        img.paste(body, (0, 0), tier_in)
        # Lit left half of the bough.
        lit = Image.new("L", (W, H), 0)
        ImageDraw.Draw(lit).polygon([(cx - k, y_top), (cx - half, y_bot), (0, y_bot), (0, y_top)], fill=255)
        lit_m = Image.fromarray(np.minimum(np.asarray(lit), np.asarray(tier_in)))
        img.paste(Image.new("RGBA", (W, H), (g[0] + 14, g[1] + 24, g[2] + 14, 255)), (0, 0), lit_m)
        dd = ImageDraw.Draw(img)
        for _ in range(teeth * 3):
            x = cx - half * 0.85 + 2 * half * 0.85 * rng.random()
            y = y_top + (y_bot - y_top) * (0.55 + 0.35 * rng.random())
            dd.line([(x, y), (x + (rng.random() - 0.5) * 5 * k, y + 4 * k)], fill=(14, 38, 32, 255), width=k)
        # Keep the needle strokes inside the bough.
        arr = np.asarray(img).copy()
        outside = (np.asarray(tier) < 128) & (arr[..., 1] == 38) & (arr[..., 0] == 14)
        arr[outside] = 0
        img = Image.fromarray(arr, "RGBA")
        # Snow on the visible upper face: from the tier above's hem, a lumpy band.
        above = bounds[i - 1][1] if i > 0 else y_top
        y_snow = above + (y_bot - above) * (0.42 if not small else 0.36)
        snow = Image.new("L", (W, H), 0)
        sd = ImageDraw.Draw(snow)
        line = [(0, 0), (W, 0)]
        n = 9
        for j in range(n + 1):
            x = W - W * j / n
            line.append((x, y_snow + (rng.random() - 0.5) * 4 * k))
        sd.polygon(line, fill=255)
        for j in range(n):
            x = cx + half * 0.9 * (1 - 2 * (j + 0.5) / n)
            r = (2.0 + rng.random() * 2.4) * k
            sd.ellipse([x - r, y_snow - r * 0.8, x + r, y_snow + r * 0.7], fill=255)
        snow_m = np.minimum(np.asarray(snow), np.asarray(tier_in))
        # Shade: bright on the lit left, cool lilac on the right.
        xs = np.arange(W)[None, :]
        t = np.clip((xs - (cx - half)) / max(2 * half, 1), 0, 1)
        col = np.zeros((H, W, 4), dtype=np.uint8)
        c_hi = np.array([248, 250, 255])
        c_lo = np.array([196, 204, 236])
        mix = smoothstep(0.35, 0.95, t)[..., None]
        col[..., :3] = (c_hi * (1 - mix) + c_lo * mix).astype(np.uint8).repeat(H, 0)
        col[..., 3] = 255
        img.paste(Image.fromarray(col, "RGBA"), (0, 0), Image.fromarray(snow_m))
        # A thin ink line under the snow edge so it sits on the boughs.
        edge = np.asarray(snow_m) > 128
        under = np.zeros_like(edge)
        under[k:] = edge[:-k]
        under &= ~edge & (np.asarray(tier_in) > 128)
        arr = np.asarray(img).copy()
        arr[under] = (arr[under] * 0.5 + np.array([20, 40, 44, 255]) * 0.5).astype(np.uint8)
        img = Image.fromarray(arr, "RGBA")
        d = ImageDraw.Draw(img)
    r = 2.6 * k
    d.ellipse([cx - r, top - r * 0.4, cx + r * 0.9, top + r * 1.3], fill=(246, 249, 255, 255))
    # One ink silhouette around the whole crown, like the kit's outlines.
    alpha = img.getchannel("A").point(lambda v: 255 if v > 100 else 0)
    from PIL import ImageFilter
    ring = alpha.filter(ImageFilter.MaxFilter(2 * k + 1))
    back = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    back.paste(Image.new("RGBA", (W, H), ink), (0, 0), ring)
    back.alpha_composite(img)
    img = back
    d = ImageDraw.Draw(img)
    # Drift at the trunk base.
    d.ellipse([cx - W * 0.34, H - 15 * k, cx + W * 0.30, H - 4 * k], fill=(224, 230, 250, 255))
    d.ellipse([cx - W * 0.22, H - 17 * k, cx + W * 0.10, H - 8 * k], fill=(248, 250, 255, 255))
    return _finish(img, k)


def paint_mound(w: int, h: int, seed: int) -> np.ndarray:
    k = 4
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W, H = w * k, h * k
    d.ellipse([W * 0.06, H * 0.45, W * 0.94, H * 0.98], fill=(90, 100, 150, 60))
    for i in range(3):
        cx = W * (0.3 + 0.2 * i + (rng.random() - 0.5) * 0.08)
        ry = H * (0.22 + 0.12 * rng.random())
        rx = W * (0.20 + 0.06 * rng.random())
        cy = H * 0.72 - ry * 0.4
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(214, 220, 244, 255))
        d.ellipse([cx - rx * 0.9, cy - ry * 1.05, cx + rx * 0.6, cy + ry * 0.4], fill=(246, 249, 255, 255))
    return _finish(img, k)


def build(out_root: Path) -> list[str]:
    props = Path(out_root) / "props"
    written: list[str] = []
    for i, (name, recipe) in enumerate(BUILDINGS.items()):
        src = props / "_2x" / f"{name}.png"
        if not src.exists():
            continue
        art, glow = snow_building(src, recipe, 100 + i)
        written += save_pair(props, f"{name}_snow", art)
        if glow[..., 3].max() > 0.05:
            written += save_pair(props, f"{name}_snow_glow", glow)
    for i, (name, (thick, puff)) in enumerate(CAPPED.items()):
        src = props / "_2x" / f"{name}.png"
        if not src.exists():
            continue
        a = load(src)
        written += save_pair(props, f"{name}_snow", _cap(a, thick, puff, 300 + i))
        if name == "lamp_post":
            written += save_pair(props, "lamp_post_snow_glow", lamp_glow(a))
    written += save_pair(props, "tree_pine_snow_a", paint_pine(124, 200, 7, 11))
    written += save_pair(props, "tree_pine_snow_b", paint_pine(112, 178, 6, 23))
    written += save_pair(props, "tree_pine_snow_c", paint_pine(136, 226, 8, 37))
    # Firs and mounds stand in for shrubs and flowers, which draw at about
    # half scale (hedges at 0.62), so they are painted twice as large.
    written += save_pair(props, "fir_snow_small", paint_pine(128, 192, 5, 51, small=True))
    written += save_pair(props, "fir_snow_small_b", paint_pine(112, 168, 4, 63, small=True))
    written += save_pair(props, "snow_mound_a", paint_mound(112, 52, 71))
    written += save_pair(props, "snow_mound_b", paint_mound(88, 44, 83))
    return written
