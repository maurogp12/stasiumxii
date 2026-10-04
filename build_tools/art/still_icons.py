# XII Stills icons (Mauro 4 Oct 2026: "we need a better look for stills and
# still fragments", then "Still icons more painted"). Paints, for each of the
# 12 Stills, in its Vault of Aeons colour (StillVault.COLORS):
#   art/ui/stills/still_<id>.png           forged Still: gold-framed hourglass
#   art/ui/stills/still_<id>_fragment.png  fragment: a broken glass shard
# Painted look: beveled, lit gold; glowing glass with reflections; grainy sand
# with light; soft shadow, aura and sparkles; the Still's emblem on a gold
# medallion. 128x128, painted at 4x and downsampled.
# Run: python3 build_tools/art/still_icons.py
import math
import os
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "ui", "stills")
SIZE = 128
SS = 4
W = SIZE * SS

COLORS = {
    "opening": (1.0, 0.72, 0.22), "stride": (0.78, 0.86, 1.0), "cut": (0.86, 0.16, 0.18),
    "mercy": (1.0, 0.52, 0.78), "guard": (0.28, 0.52, 1.0), "quiet": (0.62, 0.36, 0.95),
    "root": (0.36, 0.78, 0.30), "ember": (1.0, 0.56, 0.12), "tide": (0.16, 0.78, 0.74),
    "silence": (0.95, 0.96, 1.0), "crown": (1.0, 0.86, 0.40), "end": (0.42, 0.36, 0.52),
}
GOLD_STOPS = [(0.0, (255, 240, 180)), (0.25, (238, 192, 96)), (0.55, (176, 120, 46)), (0.8, (226, 172, 82)), (1.0, (110, 70, 26))]


def s(v):
    return int(round(v * SS))


def rgb(c, k=1.0):
    return tuple(max(0, min(255, int(v * 255 * k))) for v in c)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


# ---------------------------------------------------------------- helpers

class _Filled:
    """ImageDraw that fills every shape (masks are solid, not outlines)."""

    def __init__(self, draw):
        self._d = draw

    def __getattr__(self, name):
        fn = getattr(self._d, name)

        def call(*args, **kwargs):
            if name in ("polygon", "ellipse", "rectangle", "rounded_rectangle", "pieslice"):
                kwargs.setdefault("fill", 255)
            return fn(*args, **kwargs)

        return call


def mask_of(draw_fn):
    m = Image.new("L", (W, W), 0)
    draw_fn(_Filled(ImageDraw.Draw(m)))
    return m


def ramp(stops, t):
    t = np.clip(t, 0.0, 1.0)
    out = np.zeros(t.shape + (3,), dtype=np.float32)
    for i in range(3):
        xs = [p for p, _ in stops]
        ys = [c[i] for _, c in stops]
        out[..., i] = np.interp(t, xs, ys)
    return out


def paint(img, mask, colors, alpha=1.0):
    """Composite an (H, W, 3) float colour field through a mask."""
    layer = Image.fromarray(np.clip(colors, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    a = np.asarray(mask, dtype=np.float32) * alpha
    layer.putalpha(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "L"))
    img.alpha_composite(layer)


def vgrad(y0, y1, stops):
    y = np.arange(W, dtype=np.float32)[:, None].repeat(W, 1)
    return ramp(stops, (y - y0) / max(1.0, (y1 - y0)))


def hgrad(x0, x1, stops):
    x = np.arange(W, dtype=np.float32)[None, :].repeat(W, 0)
    return ramp(stops, (x - x0) / max(1.0, (x1 - x0)))


def radial(cx, cy, r, stops):
    y, x = np.mgrid[0:W, 0:W].astype(np.float32)
    return ramp(stops, np.hypot(x - cx, y - cy) / max(1.0, r))


def noise(seed, amount):
    rng = np.random.default_rng(seed)
    n = rng.normal(0.0, amount, (W // 4, W // 4)).astype(np.float32)
    im = Image.fromarray(np.clip(n + 128, 0, 255).astype(np.uint8), "L").resize((W, W), Image.BICUBIC)
    return np.asarray(im, dtype=np.float32)[..., None] - 128.0


def fine_noise(seed, amount):
    rng = np.random.default_rng(seed)
    return rng.normal(0.0, amount, (W, W, 1)).astype(np.float32)


def soft(img, color, mask, blur, alpha):
    layer = Image.new("RGBA", (W, W), color + (0,))
    m = mask.filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(m, dtype=np.float32) * alpha
    layer.putalpha(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "L"))
    img.alpha_composite(layer)


def stroke(img, points, color, width, alpha=255, blur=0):
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(layer).line(points, fill=color + (alpha,), width=width, joint="curve")
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(layer)


def sparkle(img, x, y, r, color=(255, 252, 230), alpha=235):
    layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    t = max(1, r // 6)
    d.polygon([(x, y - r), (x + t, y - t), (x + r, y), (x + t, y + t), (x, y + r), (x - t, y + t), (x - r, y), (x - t, y - t)], fill=color + (alpha,))
    glow = layer.filter(ImageFilter.GaussianBlur(r * 0.4))
    img.alpha_composite(glow)
    img.alpha_composite(layer)


def gold_shape(img, draw_fn, y0, y1, seed):
    """Lit gold: vertical gradient, grain, a dark rim and a bright top edge."""
    m = mask_of(draw_fn)
    paint(img, m.filter(ImageFilter.MaxFilter(5)), np.full((W, W, 3), (70, 42, 14), np.float32))
    col = vgrad(y0, y1, GOLD_STOPS) + noise(seed, 10) + fine_noise(seed + 1, 5)
    paint(img, m, col)
    # Bright top bevel: the mask shifted down and subtracted.
    shifted = ImageChops.offset(m, 0, s(1.2))
    edge = ImageChops.subtract(m, shifted)
    soft(img, (255, 246, 205), edge, 1, 0.9)
    return m


# ---------------------------------------------------------------- emblem

def emblem(d, id, cx, cy, r, ink):
    w = max(2, int(r * 0.17))
    if id == "opening":
        d.pieslice([cx - r * 0.55, cy - r * 0.35, cx + r * 0.55, cy + r * 0.75], 180, 360, fill=ink)
        for a in range(200, 341, 35):
            t = math.radians(a)
            d.line([cx + math.cos(t) * r * 0.65, cy + 0.2 * r + math.sin(t) * r * 0.65, cx + math.cos(t) * r * 0.92, cy + 0.2 * r + math.sin(t) * r * 0.92], fill=ink, width=w)
        d.line([cx - r * 0.8, cy + r * 0.22, cx + r * 0.8, cy + r * 0.22], fill=ink, width=w)
    elif id == "stride":
        for off in (-0.35, 0.2):
            d.line([cx + r * (off - 0.2), cy - r * 0.55, cx + r * (off + 0.25), cy, cx + r * (off - 0.2), cy + r * 0.55], fill=ink, width=w + 1, joint="curve")
    elif id == "cut":
        d.polygon([(cx - r * 0.72, cy + r * 0.62), (cx + r * 0.78, cy - r * 0.72), (cx + r * 0.36, cy - r * 0.18), (cx - r * 0.5, cy + r * 0.74)], fill=ink)
        d.polygon([(cx - r * 0.2, cy + r * 0.62), (cx + r * 0.78, cy - r * 0.2), (cx + r * 0.6, cy + r * 0.02), (cx - r * 0.1, cy + r * 0.7)], fill=ink)
    elif id == "mercy":
        d.ellipse([cx - r * 0.62, cy - r * 0.5, cx, cy + r * 0.1], fill=ink)
        d.ellipse([cx, cy - r * 0.5, cx + r * 0.62, cy + r * 0.1], fill=ink)
        d.polygon([(cx - r * 0.6, cy - r * 0.12), (cx + r * 0.6, cy - r * 0.12), (cx, cy + r * 0.68)], fill=ink)
    elif id == "guard":
        d.polygon([(cx - r * 0.55, cy - r * 0.6), (cx + r * 0.55, cy - r * 0.6), (cx + r * 0.5, cy + r * 0.1), (cx, cy + r * 0.72), (cx - r * 0.5, cy + r * 0.1)], fill=ink)
    elif id == "quiet":
        d.arc([cx - r * 0.7, cy - r * 0.55, cx + r * 0.7, cy + r * 0.35], 20, 160, fill=ink, width=w + 1)
        for x in (-0.4, 0.0, 0.4):
            d.line([cx + r * x, cy + r * 0.32, cx + r * x * 1.2, cy + r * 0.6], fill=ink, width=w)
    elif id == "root":
        d.line([cx, cy + r * 0.1, cx, cy - r * 0.55], fill=ink, width=w)
        d.ellipse([cx - r * 0.55, cy - r * 0.75, cx - r * 0.02, cy - r * 0.35], fill=ink)
        d.ellipse([cx + r * 0.02, cy - r * 0.62, cx + r * 0.5, cy - r * 0.25], fill=ink)
        for x in (-0.5, 0.0, 0.5):
            d.line([cx, cy + r * 0.1, cx + r * x, cy + r * 0.7], fill=ink, width=w)
    elif id == "ember":
        d.polygon([(cx, cy - r * 0.8), (cx + r * 0.2, cy - r * 0.35), (cx + r * 0.5, cy - r * 0.05), (cx + r * 0.42, cy + r * 0.45), (cx, cy + r * 0.72), (cx - r * 0.42, cy + r * 0.45), (cx - r * 0.5, cy), (cx - r * 0.25, cy - r * 0.15), (cx - r * 0.2, cy - r * 0.5)], fill=ink)
    elif id == "tide":
        for dy in (-0.25, 0.25):
            pts = [(cx + r * (x / 10.0 - 0.75), cy + r * dy + math.sin(x / 10.0 * math.pi * 2.0) * r * 0.18) for x in range(16)]
            d.line(pts, fill=ink, width=w + 1, joint="curve")
    elif id == "silence":
        d.pieslice([cx - r * 0.5, cy - r * 0.6, cx + r * 0.5, cy + r * 0.5], 180, 360, fill=ink)
        d.rectangle([cx - r * 0.5, cy - r * 0.06, cx + r * 0.5, cy + r * 0.3], fill=ink)
        d.ellipse([cx - r * 0.12, cy + r * 0.3, cx + r * 0.12, cy + r * 0.55], fill=ink)
        d.line([cx - r * 0.7, cy + r * 0.7, cx + r * 0.7, cy - r * 0.7], fill=(40, 30, 50), width=w + 3)
        d.line([cx - r * 0.7, cy + r * 0.7, cx + r * 0.7, cy - r * 0.7], fill=ink, width=w)
    elif id == "crown":
        d.polygon([(cx - r * 0.65, cy + r * 0.45), (cx - r * 0.65, cy - r * 0.35), (cx - r * 0.3, cy + r * 0.05), (cx, cy - r * 0.6), (cx + r * 0.3, cy + r * 0.05), (cx + r * 0.65, cy - r * 0.35), (cx + r * 0.65, cy + r * 0.45)], fill=ink)
    elif id == "end":
        d.ellipse([cx - r * 0.5, cy - r * 0.62, cx + r * 0.5, cy + r * 0.3], fill=ink)
        d.rectangle([cx - r * 0.3, cy + r * 0.1, cx + r * 0.3, cy + r * 0.55], fill=ink)
        dark = (30, 26, 36)
        d.ellipse([cx - r * 0.33, cy - r * 0.25, cx - r * 0.07, cy + r * 0.02], fill=dark)
        d.ellipse([cx + r * 0.07, cy - r * 0.25, cx + r * 0.33, cy + r * 0.02], fill=dark)
        for x in (-0.15, 0.0, 0.15):
            d.line([cx + r * x, cy + r * 0.32, cx + r * x, cy + r * 0.55], fill=dark, width=max(1, w // 2))


def medallion(img, id, cx, cy, r, seed):
    tint = rgb(COLORS[id])
    # Shadow under the coin.
    soft(img, (0, 0, 0), mask_of(lambda d: d.ellipse([cx - r, cy - r + s(2), cx + r, cy + r + s(3)])), s(2), 0.6)
    gold_shape(img, lambda d: d.ellipse([cx - r, cy - r, cx + r, cy + r]), cy - r, cy + r, seed)
    inner = int(r * 0.78)
    face = radial(cx - inner * 0.3, cy - inner * 0.35, inner * 1.5, [(0.0, mix(tint, (255, 255, 255), 0.25)), (0.5, mix(tint, (16, 12, 24), 0.35)), (1.0, mix(tint, (8, 6, 14), 0.75))])
    face = face + fine_noise(seed + 7, 6)
    paint(img, mask_of(lambda d: d.ellipse([cx - inner, cy - inner, cx + inner, cy + inner])), face)
    # Emblem: a dark drop shadow, then the light sign.
    ink = (255, 248, 228) if id != "silence" else (52, 56, 76)
    sh = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    emblem(ImageDraw.Draw(sh), id, cx + s(0.8), cy + s(1.0), inner * 0.9, (0, 0, 0))
    a = np.asarray(sh.split()[3], dtype=np.float32) * 0.55
    sh.putalpha(Image.fromarray(a.astype(np.uint8)))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(s(0.6))))
    lay = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    emblem(ImageDraw.Draw(lay), id, cx, cy, inner * 0.9, ink)
    img.alpha_composite(lay)
    # Glass gloss on the coin face.
    soft(img, (255, 255, 255), mask_of(lambda d: d.ellipse([cx - inner * 0.8, cy - inner * 0.85, cx + inner * 0.5, cy - inner * 0.1])), s(1), 0.28)


def aura(img, tint, cx, cy, r, seed):
    glow = radial(cx, cy, r, [(0.0, tint), (1.0, tint)])
    m = mask_of(lambda d: d.ellipse([cx - r, cy - r, cx + r, cy + r])).filter(ImageFilter.GaussianBlur(r * 0.45))
    paint(img, m, glow, 0.75)
    # Faint light rays.
    rays = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(rays)
    rnd = random.Random(seed)
    for i in range(10):
        a = i * math.tau / 10 + rnd.uniform(-0.15, 0.15)
        d.polygon([(cx, cy), (cx + math.cos(a - 0.06) * r * 1.25, cy + math.sin(a - 0.06) * r * 1.25), (cx + math.cos(a + 0.06) * r * 1.25, cy + math.sin(a + 0.06) * r * 1.25)], fill=110)
    rays = rays.filter(ImageFilter.GaussianBlur(s(3)))
    paint(img, rays, np.full((W, W, 3), mix(tint, (255, 255, 255), 0.4), np.float32), 0.35)


# ---------------------------------------------------------------- Still

def hourglass(id):
    rnd = random.Random(id)
    seed = sum(map(ord, id))
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    tint = rgb(COLORS[id])
    light = mix(tint, (255, 255, 255), 0.6)
    deep = mix(tint, (0, 0, 0), 0.45)
    cx = W // 2
    top, bot = s(20), s(106)
    mid = (top + bot) // 2
    bw = s(25)
    neck = s(3)
    aura(img, tint, cx, mid, s(46), seed)
    # Ground shadow.
    soft(img, (0, 0, 0), mask_of(lambda d: d.ellipse([cx - s(40), bot + s(2), cx + s(40), bot + s(12)])), s(3), 0.55)
    upper = [(cx - bw, top + s(6)), (cx + bw, top + s(6)), (cx + neck, mid), (cx - neck, mid)]
    lower = [(cx - neck, mid), (cx + neck, mid), (cx + bw, bot - s(6)), (cx - bw, bot - s(6))]
    # Glass body: dark-to-tint radial, so the bulbs read as lit from the left.
    # Dark glass so the bright sand pops against it.
    glass = radial(cx - s(10), mid - s(16), s(48), [(0.0, mix(tint, (255, 255, 255), 0.2)), (0.45, mix(tint, (12, 10, 20), 0.62)), (1.0, mix(tint, (5, 4, 10), 0.86))])
    paint(img, mask_of(lambda d: d.polygon(upper)), glass, 0.82)
    paint(img, mask_of(lambda d: d.polygon(lower)), glass, 0.82)
    # Sand: a cone left on top, a heap below, the falling stream, with grain.
    sand_col = vgrad(mid - s(18), bot - s(6), [(0.0, light), (0.5, mix(tint, (255, 255, 255), 0.2)), (1.0, tint)]) + fine_noise(seed + 3, 14)
    paint(img, mask_of(lambda d: d.polygon([(cx - s(16), mid - s(18)), (cx + s(16), mid - s(18)), (cx + neck, mid), (cx - neck, mid)])), sand_col)
    heap = [(cx - bw + s(1), bot - s(7)), (cx + bw - s(1), bot - s(7)), (cx + bw - s(4), bot - s(14)), (cx + s(12), bot - s(24)), (cx + s(4), bot - s(32)), (cx, bot - s(34)), (cx - s(4), bot - s(32)), (cx - s(12), bot - s(24)), (cx - bw + s(4), bot - s(14))]
    paint(img, mask_of(lambda d: d.polygon(heap)), sand_col)
    # Lit crest of the heap and of the top cone.
    stroke(img, heap[2:] + [heap[0]], mix(tint, (255, 255, 255), 0.75), s(1.2), 200)
    stroke(img, [(cx - s(16), mid - s(18)), (cx + s(16), mid - s(18))], mix(tint, (255, 255, 255), 0.75), s(1.2), 200)
    stroke(img, [(cx, mid), (cx, bot - s(33))], light, s(1.8))
    stroke(img, [(cx, mid), (cx, bot - s(33))], light, s(3.5), 130, s(1.5))
    # Glowing grains in the air.
    for _ in range(7):
        gx = cx + rnd.uniform(-bw * 0.6, bw * 0.6)
        gy = rnd.uniform(mid + s(6), bot - s(30))
        soft(img, light, mask_of(lambda d: d.ellipse([gx - s(1.2), gy - s(1.2), gx + s(1.2), gy + s(1.2)])), s(0.6), 1.0)
    # Inner glow at the heap.
    soft(img, light, mask_of(lambda d: d.ellipse([cx - s(14), bot - s(30), cx + s(14), bot - s(12)])), s(5), 0.35)
    # Glass rims and reflections.
    rim = mix(tint, (255, 255, 255), 0.8)
    stroke(img, [(cx - bw, top + s(6)), (cx - neck, mid), (cx - bw, bot - s(6))], rim, s(1.3), 220)
    stroke(img, [(cx + bw, top + s(6)), (cx + neck, mid), (cx + bw, bot - s(6))], rim, s(1.3), 170)
    stroke(img, [(cx - bw + s(6), top + s(10)), (cx - s(8), mid - s(9))], (255, 255, 255), s(2.4), 200, s(0.6))
    stroke(img, [(cx - bw + s(9), top + s(10)), (cx - s(13), top + s(18))], (255, 255, 255), s(1.2), 150)
    stroke(img, [(cx - bw + s(6), bot - s(10)), (cx - s(9), mid + s(10))], (255, 255, 255), s(1.6), 110, s(0.5))
    stroke(img, [(cx + bw - s(5), top + s(12)), (cx + s(10), mid - s(8))], mix(tint, (255, 255, 255), 0.5), s(1.2), 90)
    # Gold pillars with knobs.
    for x in (cx - bw - s(6), cx + bw + s(6)):
        gold_shape(img, lambda d, x=x: d.rounded_rectangle([x - s(2.4), top + s(4), x + s(2.4), bot - s(4)], radius=s(2)), top, bot, seed + x)
        stroke(img, [(x - s(0.8), top + s(6)), (x - s(0.8), bot - s(6))], (255, 240, 190), s(0.8), 160)
        gold_shape(img, lambda d, x=x: d.ellipse([x - s(4), mid - s(4), x + s(4), mid + s(4)]), mid - s(4), mid + s(4), seed + 2 * x)
        for yy in (top + s(16), bot - s(16)):
            gold_shape(img, lambda d, x=x, yy=yy: d.ellipse([x - s(3.2), yy - s(2.2), x + s(3.2), yy + s(2.2)]), yy - s(2), yy + s(2), seed + yy)
    # Gold caps with an engraved line and a small gem in the Still's colour.
    for y in (top, bot):
        gold_shape(img, lambda d, y=y: d.rounded_rectangle([cx - bw - s(12), y - s(6), cx + bw + s(12), y + s(6)], radius=s(4)), y - s(6), y + s(6), seed + y)
        stroke(img, [(cx - bw - s(8), y + s(2)), (cx + bw + s(8), y + s(2))], (110, 72, 28), s(0.9), 200)
        gem = [(cx, y - s(4)), (cx + s(4), y), (cx, y + s(4)), (cx - s(4), y)]
        paint(img, mask_of(lambda d, gem=gem: d.polygon(gem)), radial(cx - s(1.5), y - s(1.5), s(5), [(0.0, light), (1.0, deep)]))
        sparkle(img, cx - s(1.2), y - s(1.4), s(2))
    sparkle(img, cx - bw - s(3), top - s(3), s(5))
    sparkle(img, cx + bw + s(8), mid + s(14), s(3))
    medallion(img, id, W - s(25), W - s(25), s(19), seed + 99)
    return finish(img)


# ---------------------------------------------------------------- fragment

def fragment(id):
    rnd = random.Random(id + "frag")
    seed = sum(map(ord, id)) + 500
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    tint = rgb(COLORS[id])
    light = mix(tint, (255, 255, 255), 0.6)
    deep = mix(tint, (0, 0, 0), 0.5)
    aura(img, tint, s(58), s(60), s(38), seed)
    shard = [(s(30), s(28)), (s(62), s(14)), (s(86), s(38)), (s(92), s(70)), (s(72), s(98)), (s(44), s(102)), (s(34), s(78)), (s(24), s(56))]
    soft(img, (0, 0, 0), mask_of(lambda d: d.polygon([(x + s(3), y + s(5)) for x, y in shard])), s(3), 0.55)
    # Facets: each plane of the broken glass catches the light differently.
    centre = (s(58), s(50))
    shades = [0.78, 0.55, 0.36, 0.22, 0.3, 0.48, 0.66, 0.85]
    for i in range(len(shard)):
        a, b = shard[i], shard[(i + 1) % len(shard)]
        col = mix(mix(tint, (20, 16, 30), 0.35), (255, 255, 255), shades[i] * 0.6)
        paint(img, mask_of(lambda d, a=a, b=b: d.polygon([centre, a, b])), np.full((W, W, 3), col, np.float32) + fine_noise(seed + i, 4), 0.62)
    # Sand caught in the bottom, with grain and light.
    sand = [(s(34), s(78)), (s(44), s(102)), (s(72), s(98)), (s(88), s(78)), (s(72), s(68)), (s(54), s(71))]
    paint(img, mask_of(lambda d: d.polygon(sand)), vgrad(s(66), s(102), [(0.0, light), (0.5, tint), (1.0, deep)]) + fine_noise(seed + 9, 18))
    soft(img, light, mask_of(lambda d: d.ellipse([s(46), s(66), s(78), s(84)])), s(5), 0.45)
    for _ in range(9):
        gx = rnd.uniform(s(40), s(80))
        gy = rnd.uniform(s(46), s(70))
        soft(img, light, mask_of(lambda d, gx=gx, gy=gy: d.ellipse([gx - s(1.3), gy - s(1.3), gx + s(1.3), gy + s(1.3)])), s(0.5), 1.0)
    # Bright cut edges and crack lines.
    edge = mix(tint, (255, 255, 255), 0.85)
    stroke(img, shard + [shard[0]], edge, s(1.6), 230)
    stroke(img, shard + [shard[0]], edge, s(4), 70, s(1.5))
    for a in ((s(62), s(14)), (s(92), s(70)), (s(34), s(78))):
        stroke(img, [centre, a], (255, 255, 255), s(0.9), 120)
    stroke(img, [(s(34), s(31)), (s(57), s(21))], (255, 255, 255), s(2.6), 220, s(0.5))
    stroke(img, [(s(30), s(40)), (s(29), s(56))], (255, 255, 255), s(1.4), 150)
    # A chunk of the gold frame still stuck to it.
    gold_shape(img, lambda d: d.polygon([(s(27), s(24)), (s(62), s(9)), (s(66), s(16)), (s(31), s(31))]), s(9), s(31), seed + 3)
    gem = [(s(46), s(13)), (s(50), s(17)), (s(46), s(22)), (s(42), s(18))]
    paint(img, mask_of(lambda d: d.polygon(gem)), radial(s(45), s(15), s(6), [(0.0, light), (1.0, deep)]))
    sparkle(img, s(88), s(24), s(8))
    sparkle(img, s(28), s(90), s(4))
    medallion(img, id, W - s(23), W - s(23), s(17), seed + 99)
    return finish(img)


def finish(img):
    out = img.resize((SIZE, SIZE), Image.LANCZOS)
    return out.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))


def main():
    os.makedirs(OUT, exist_ok=True)
    for id in COLORS:
        hourglass(id).save(os.path.join(OUT, "still_%s.png" % id))
        fragment(id).save(os.path.join(OUT, "still_%s_fragment.png" % id))
    print("wrote %d icons to %s" % (len(COLORS) * 2, OUT))


if __name__ == "__main__":
    main()
