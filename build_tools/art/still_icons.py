# XII Stills icons (Mauro 4 Oct 2026: "we need a better look for stills and
# still fragments"). Paints, for each of the 12 Stills, in its Vault of Aeons
# colour (StillVault.COLORS):
#   art/ui/stills/still_<id>.png           forged Still: gold-framed hourglass
#   art/ui/stills/still_<id>_fragment.png  fragment: a broken glass shard
# Each carries the Still's emblem on a small medallion. 128x128, drawn at 4x
# and downsampled. Run: python3 build_tools/art/still_icons.py
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "ui", "stills")
SIZE = 128
SS = 4
W = SIZE * SS

COLORS = {
    "opening": (1.0, 0.72, 0.22), "stride": (0.78, 0.86, 1.0), "cut": (0.86, 0.16, 0.18),
    "mercy": (1.0, 0.52, 0.78), "guard": (0.28, 0.52, 1.0), "quiet": (0.62, 0.36, 0.95),
    "root": (0.36, 0.78, 0.30), "ember": (1.0, 0.56, 0.12), "tide": (0.16, 0.78, 0.74),
    "silence": (0.95, 0.96, 1.0), "crown": (1.0, 0.86, 0.40), "end": (0.30, 0.28, 0.34),
}
GOLD = (222, 176, 92)
GOLD_LIGHT = (255, 228, 150)
GOLD_DARK = (120, 84, 36)


def rgb(c, k=1.0):
    return tuple(max(0, min(255, int(v * 255 * k))) for v in c)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def s(v):
    return int(round(v * SS))


def glow(img, color, center, radius, alpha):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = center
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=color + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(radius * 0.45))
    img.alpha_composite(layer)


def emblem(d, id, cx, cy, r, ink):
    """The Still's sign, white on its medallion."""
    w = max(2, int(r * 0.16))
    if id == "opening":  # sunrise: half sun and rays
        d.pieslice([cx - r * 0.55, cy - r * 0.35, cx + r * 0.55, cy + r * 0.75], 180, 360, fill=ink)
        for a in range(200, 341, 35):
            t = math.radians(a)
            d.line([cx + math.cos(t) * r * 0.65, cy + 0.2 * r + math.sin(t) * r * 0.65, cx + math.cos(t) * r * 0.9, cy + 0.2 * r + math.sin(t) * r * 0.9], fill=ink, width=w)
        d.line([cx - r * 0.8, cy + r * 0.22, cx + r * 0.8, cy + r * 0.22], fill=ink, width=w)
    elif id == "stride":  # double chevron forward
        for off in (-0.35, 0.2):
            d.line([cx + r * (off - 0.2), cy - r * 0.55, cx + r * (off + 0.25), cy, cx + r * (off - 0.2), cy + r * 0.55], fill=ink, width=w + 1, joint="curve")
    elif id == "cut":  # slash
        d.polygon([(cx - r * 0.7, cy + r * 0.6), (cx + r * 0.75, cy - r * 0.7), (cx + r * 0.45, cy - r * 0.3), (cx - r * 0.5, cy + r * 0.72)], fill=ink)
    elif id == "mercy":  # heart
        d.ellipse([cx - r * 0.62, cy - r * 0.5, cx, cy + r * 0.1], fill=ink)
        d.ellipse([cx, cy - r * 0.5, cx + r * 0.62, cy + r * 0.1], fill=ink)
        d.polygon([(cx - r * 0.6, cy - r * 0.12), (cx + r * 0.6, cy - r * 0.12), (cx, cy + r * 0.68)], fill=ink)
    elif id == "guard":  # shield
        d.polygon([(cx - r * 0.55, cy - r * 0.6), (cx + r * 0.55, cy - r * 0.6), (cx + r * 0.5, cy + r * 0.1), (cx, cy + r * 0.72), (cx - r * 0.5, cy + r * 0.1)], fill=ink)
    elif id == "quiet":  # closed eye
        d.arc([cx - r * 0.7, cy - r * 0.55, cx + r * 0.7, cy + r * 0.35], 20, 160, fill=ink, width=w + 1)
        for x in (-0.4, 0.0, 0.4):
            d.line([cx + r * x, cy + r * 0.32, cx + r * x * 1.2, cy + r * 0.6], fill=ink, width=w)
    elif id == "root":  # sprout with roots
        d.line([cx, cy + r * 0.1, cx, cy - r * 0.55], fill=ink, width=w)
        d.ellipse([cx - r * 0.55, cy - r * 0.75, cx - r * 0.02, cy - r * 0.35], fill=ink)
        d.ellipse([cx + r * 0.02, cy - r * 0.62, cx + r * 0.5, cy - r * 0.25], fill=ink)
        for x in (-0.5, 0.0, 0.5):
            d.line([cx, cy + r * 0.1, cx + r * x, cy + r * 0.7], fill=ink, width=w)
    elif id == "ember":  # flame
        d.polygon([(cx, cy - r * 0.78), (cx + r * 0.45, cy - r * 0.05), (cx + r * 0.38, cy + r * 0.45), (cx, cy + r * 0.7), (cx - r * 0.38, cy + r * 0.45), (cx - r * 0.45, cy - r * 0.05), (cx - r * 0.12, cy - r * 0.3)], fill=ink)
    elif id == "tide":  # two waves
        for dy in (-0.25, 0.25):
            pts = [(cx + r * (x / 10.0 - 0.75), cy + r * dy + math.sin(x / 10.0 * math.pi * 2.0) * r * 0.18) for x in range(16)]
            d.line(pts, fill=ink, width=w + 1, joint="curve")
    elif id == "silence":  # bell with a slash
        d.pieslice([cx - r * 0.5, cy - r * 0.6, cx + r * 0.5, cy + r * 0.5], 180, 360, fill=ink)
        d.rectangle([cx - r * 0.5, cy - r * 0.06, cx + r * 0.5, cy + r * 0.3], fill=ink)
        d.ellipse([cx - r * 0.12, cy + r * 0.3, cx + r * 0.12, cy + r * 0.55], fill=ink)
        d.line([cx - r * 0.7, cy + r * 0.7, cx + r * 0.7, cy - r * 0.7], fill=(40, 30, 50), width=w + 3)
        d.line([cx - r * 0.7, cy + r * 0.7, cx + r * 0.7, cy - r * 0.7], fill=ink, width=w)
    elif id == "crown":  # crown
        d.polygon([(cx - r * 0.65, cy + r * 0.45), (cx - r * 0.65, cy - r * 0.35), (cx - r * 0.3, cy + r * 0.05), (cx, cy - r * 0.6), (cx + r * 0.3, cy + r * 0.05), (cx + r * 0.65, cy - r * 0.35), (cx + r * 0.65, cy + r * 0.45)], fill=ink)
    elif id == "end":  # skull
        d.ellipse([cx - r * 0.5, cy - r * 0.62, cx + r * 0.5, cy + r * 0.3], fill=ink)
        d.rectangle([cx - r * 0.3, cy + r * 0.1, cx + r * 0.3, cy + r * 0.55], fill=ink)
        dark = (30, 26, 36)
        d.ellipse([cx - r * 0.33, cy - r * 0.25, cx - r * 0.07, cy + r * 0.02], fill=dark)
        d.ellipse([cx + r * 0.07, cy - r * 0.25, cx + r * 0.33, cy + r * 0.02], fill=dark)
        for x in (-0.15, 0.0, 0.15):
            d.line([cx + r * x, cy + r * 0.32, cx + r * x, cy + r * 0.55], fill=dark, width=max(1, w // 2))


def medallion(img, id, cx, cy, r):
    tint = rgb(COLORS[id])
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r - s(2), cy - r - s(2), cx + r + s(2), cy + r + s(2)], fill=GOLD_DARK + (255,))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GOLD + (255,))
    inner = r * 0.82
    base = mix(tint, (20, 16, 28), 0.55)
    d.ellipse([cx - inner, cy - inner, cx + inner, cy + inner], fill=base + (255,))
    ink = (255, 250, 236) if id != "silence" else (60, 64, 80)
    if id == "silence":
        d.ellipse([cx - inner, cy - inner, cx + inner, cy + inner], fill=(210, 214, 228, 255))
    emblem(d, id, cx, cy, inner * 0.92, ink)


def hourglass(id):
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    tint = rgb(COLORS[id])
    light = mix(tint, (255, 255, 255), 0.55)
    deep = mix(tint, (0, 0, 0), 0.35) if id != "end" else (70, 64, 84)
    glow(img, tint if id != "end" else (150, 120, 190), (W // 2, W // 2), s(44), 150)
    d = ImageDraw.Draw(img)
    cx = W // 2
    top, bot = s(22), s(106)
    mid = (top + bot) // 2
    bw = s(26)  # bulb half width
    neck = s(3)
    # Glass bulbs.
    glass = mix(tint, (255, 255, 255), 0.7) + (90,)
    d.polygon([(cx - bw, top + s(6)), (cx + bw, top + s(6)), (cx + neck, mid), (cx - neck, mid)], fill=glass)
    d.polygon([(cx - neck, mid), (cx + neck, mid), (cx + bw, bot - s(6)), (cx - bw, bot - s(6))], fill=glass)
    # Sand: a little left on top, a pile below, a falling stream.
    d.polygon([(cx - s(13), mid - s(14)), (cx + s(13), mid - s(14)), (cx + neck, mid), (cx - neck, mid)], fill=tint + (255,))
    d.polygon([(cx - bw + s(2), bot - s(7)), (cx + bw - s(2), bot - s(7)), (cx + s(9), bot - s(22)), (cx, bot - s(27)), (cx - s(9), bot - s(22))], fill=tint + (255,))
    d.polygon([(cx - bw + s(2), bot - s(7)), (cx + bw - s(2), bot - s(7)), (cx + s(14), bot - s(13)), (cx - s(14), bot - s(13))], fill=deep + (255,))
    d.line([cx, mid, cx, bot - s(26)], fill=light + (255,), width=s(1.6))
    # Glass outline and highlights.
    outline = mix(tint, (255, 255, 255), 0.8) + (230,)
    d.line([(cx - bw, top + s(6)), (cx - neck, mid), (cx - bw, bot - s(6))], fill=outline, width=s(1.4))
    d.line([(cx + bw, top + s(6)), (cx + neck, mid), (cx + bw, bot - s(6))], fill=outline, width=s(1.4))
    d.line([(cx - bw + s(6), top + s(10)), (cx - s(7), mid - s(8))], fill=(255, 255, 255, 170), width=s(2))
    d.line([(cx - bw + s(6), bot - s(10)), (cx - s(8), mid + s(10))], fill=(255, 255, 255, 110), width=s(1.5))
    # Gold pillars.
    for x in (cx - bw - s(6), cx + bw + s(6)):
        d.rounded_rectangle([x - s(2.2), top + s(4), x + s(2.2), bot - s(4)], radius=s(2), fill=GOLD_DARK)
        d.rounded_rectangle([x - s(1.4), top + s(4), x + s(1.4), bot - s(4)], radius=s(1.5), fill=GOLD)
        d.ellipse([x - s(3.5), mid - s(3.5), x + s(3.5), mid + s(3.5)], fill=GOLD_LIGHT, outline=GOLD_DARK, width=s(1))
    # Gold caps.
    for y in (top, bot):
        d.rounded_rectangle([cx - bw - s(12), y - s(6), cx + bw + s(12), y + s(6)], radius=s(4), fill=GOLD_DARK)
        d.rounded_rectangle([cx - bw - s(11), y - s(5), cx + bw + s(11), y + s(4)], radius=s(4), fill=GOLD)
        d.line([cx - bw - s(8), y - s(3), cx + bw + s(8), y - s(3)], fill=GOLD_LIGHT, width=s(1.5))
    medallion(img, id, W - s(26), W - s(26), s(19))
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def fragment(id):
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    tint = rgb(COLORS[id])
    deep = mix(tint, (0, 0, 0), 0.4) if id != "end" else (70, 64, 84)
    glow(img, tint if id != "end" else (150, 120, 190), (s(58), s(60)), s(34), 140)
    d = ImageDraw.Draw(img)
    # A jagged shard of hourglass glass.
    shard = [(s(30), s(28)), (s(62), s(16)), (s(84), s(40)), (s(90), s(72)), (s(70), s(96)), (s(44), s(100)), (s(36), s(76)), (s(26), s(58))]
    d.polygon(shard, fill=mix(tint, (255, 255, 255), 0.55) + (150,))
    # Sand caught inside.
    sand = [(s(36), s(76)), (s(44), s(100)), (s(70), s(96)), (s(86), s(78)), (s(70), s(68)), (s(52), s(70))]
    d.polygon(sand, fill=tint + (255,))
    d.polygon([(s(44), s(100)), (s(70), s(96)), (s(80), s(86)), (s(48), s(90))], fill=deep + (255,))
    for gx, gy in ((56, 62), (64, 58), (48, 66), (72, 64)):
        d.ellipse([s(gx) - s(1.5), s(gy) - s(1.5), s(gx) + s(1.5), s(gy) + s(1.5)], fill=tint + (255,))
    # Crack facets and rim.
    edge = mix(tint, (255, 255, 255), 0.85) + (240,)
    d.line(shard + [shard[0]], fill=edge, width=s(1.6), joint="curve")
    d.line([(s(62), s(16)), (s(58), s(46)), (s(84), s(40))], fill=(255, 255, 255, 120), width=s(1))
    d.line([(s(58), s(46)), (s(36), s(76))], fill=(255, 255, 255, 90), width=s(1))
    d.line([(s(36), s(32)), (s(56), s(24))], fill=(255, 255, 255, 200), width=s(2.2))
    # A bit of the gold frame still stuck to it.
    d.line([(s(30), s(28)), (s(62), s(16))], fill=GOLD_DARK, width=s(6))
    d.line([(s(31), s(27)), (s(61), s(16))], fill=GOLD, width=s(3.5))
    # Sparkle.
    sx, sy = s(86), s(26)
    d.polygon([(sx, sy - s(9)), (sx + s(2), sy - s(2)), (sx + s(9), sy), (sx + s(2), sy + s(2)), (sx, sy + s(9)), (sx - s(2), sy + s(2)), (sx - s(9), sy), (sx - s(2), sy - s(2))], fill=(255, 255, 240, 230))
    medallion(img, id, W - s(24), W - s(24), s(17))
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    for id in COLORS:
        hourglass(id).save(os.path.join(OUT, "still_%s.png" % id))
        fragment(id).save(os.path.join(OUT, "still_%s_fragment.png" % id))
    print("wrote %d icons to %s" % (len(COLORS) * 2, OUT))


if __name__ == "__main__":
    main()
