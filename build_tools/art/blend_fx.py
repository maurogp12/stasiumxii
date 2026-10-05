# XII Elements Step 3: painted effect strips for the six Blends (Mauro
# 5 Oct 2026: "Can you add some visual effect to every element blend?").
# One horizontal strip of equal 192x192 cells per effect, played once over the
# target by vfx/vfx_strip.gd (anchor = the target's feet at (96, 150)), plus two
# looping ground strips for the tiles that stay on the board (Magma, Steam).
# Drawn at 2x and reduced, soft glows by blur, colours from the element tints
# (Pawn.RESIDUE_TINT). Deterministic (fixed seeds): re-runs are byte-identical.
# Writes art/vfx/blends/blend_<id>.png.
# Run: python3 build_tools/art/blend_fx.py
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "vfx", "blends")
CELL = 192
K = 2  # supersample
W = CELL * K
FEET = (96 * K, 150 * K)
FRAMES = 12
LOOP_FRAMES = 8

AIR = (140, 235, 220)
EARTH = (200, 143, 77)
FIRE = (255, 115, 38)
WATER = (82, 158, 255)
WHITE = (255, 255, 255)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(int(lerp(c1[i], c2[i], t)) for i in range(3))


def ease_out(t):
    return 1 - (1 - t) ** 2


def bell(t, start, peak, end):
    """0 before start, rises to 1 at peak, falls to 0 at end."""
    if t <= start or t >= end:
        return 0.0
    if t <= peak:
        return (t - start) / max(peak - start, 1e-6)
    return 1 - (t - peak) / max(end - peak, 1e-6)


class Frame:
    def __init__(self):
        self.base = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        self.glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))

    def layer(self):
        return Image.new("RGBA", (W, W), (0, 0, 0, 0))

    def paste(self, layer, glow_radius=0, glow_amount=0.0):
        if glow_radius > 0 and glow_amount > 0:
            g = layer.filter(ImageFilter.GaussianBlur(glow_radius * K))
            if glow_amount != 1.0:
                a = g.getchannel("A").point(lambda v: min(255, int(v * glow_amount)))
                g.putalpha(a)
            self.glow = Image.alpha_composite(self.glow, g)
        self.base = Image.alpha_composite(self.base, layer)

    def done(self):
        out = Image.alpha_composite(self.glow, self.base)
        return out.resize((CELL, CELL), Image.LANCZOS)


def ground_ellipse(d, rx, color, alpha, width=0, cy_off=0):
    cx, cy = FEET
    cy += cy_off * K
    box = (cx - rx * K, cy - rx * K * 0.5, cx + rx * K, cy + rx * K * 0.5)
    if width:
        d.ellipse(box, outline=color + (int(alpha),), width=int(width * K))
    else:
        d.ellipse(box, fill=color + (int(alpha),))


def at(x, y):
    """Cell px around the feet → canvas px."""
    return (FEET[0] + x * K, FEET[1] + y * K)


def blob(d, x, y, r, color, alpha):
    cx, cy = at(x, y)
    d.ellipse((cx - r * K, cy - r * K, cx + r * K, cy + r * K), fill=color + (int(max(0, min(255, alpha))),))


def bolt(d, rng, x0, y0, x1, y1, color, alpha, width, jag=7):
    pts = [at(x0, y0)]
    steps = 6
    for i in range(1, steps):
        t = i / steps
        px = lerp(x0, x1, t) + rng.uniform(-jag, jag)
        py = lerp(y0, y1, t) + rng.uniform(-jag, jag)
        pts.append(at(px, py))
    pts.append(at(x1, y1))
    d.line(pts, fill=color + (int(alpha),), width=int(width * K), joint="curve")


# ---------------------------------------------------------------- Drift-Pin
def drift_pin(f):
    t = f / (FRAMES - 1)
    fr = Frame()
    # Earth sigil ring on the floor.
    ring = fr.layer()
    d = ImageDraw.Draw(ring)
    a = 220 * bell(t, 0.25, 0.5, 1.0)
    ground_ellipse(d, 30 + 8 * ease_out(min(1, t * 1.6)), EARTH, a, width=3)
    ground_ellipse(d, 22, mix(EARTH, WHITE, 0.3), a * 0.6, width=1.5)
    fr.paste(ring, 3, 0.8)
    # Gust: three spiral arcs whirling around the body.
    gust = fr.layer()
    d = ImageDraw.Draw(gust)
    ga = 255 * bell(t, 0.0, 0.25, 0.65)
    for i in range(3):
        ang = t * 540 + i * 120
        h = -20 - i * 22
        rx, ry = 40 - i * 5, 14 - i
        cx, cy = at(0, h)
        box = (cx - rx * K, cy - ry * K, cx + rx * K, cy + ry * K)
        d.arc(box, ang, ang + 170, fill=AIR + (int(ga),), width=int(4.5 * K))
        d.arc(box, ang + 20, ang + 90, fill=WHITE + (int(ga * 0.8),), width=int(1.5 * K))
    fr.paste(gust, 4, 1.0)
    # Stone spikes rise and pin the feet.
    spikes = fr.layer()
    d = ImageDraw.Draw(spikes)
    grow = ease_out(min(1, max(0, (t - 0.3) / 0.25)))
    fade = 1 - max(0, (t - 0.85) / 0.15)
    for i, ang in enumerate([200, 250, 290, 340, 20]):
        r = 24
        bx = math.cos(math.radians(ang)) * r
        by = math.sin(math.radians(ang)) * r * 0.5
        h = (28 + (i % 2) * 10) * grow
        if h < 1:
            continue
        lean = -bx * 0.25
        base_l, base_r = at(bx - 7, by), at(bx + 7, by)
        tip = at(bx + lean, by - h)
        d.polygon([base_l, tip, base_r], fill=mix(EARTH, (60, 40, 20), 0.35) + (int(255 * fade),))
        d.polygon([base_l, tip, at(bx, by)], fill=mix(EARTH, WHITE, 0.25) + (int(255 * fade),))
    fr.paste(spikes, 2, 0.5)
    # Dust kicked up as the stones land.
    dust = fr.layer()
    d = ImageDraw.Draw(dust)
    rng = random.Random(11)
    da = 160 * bell(t, 0.45, 0.6, 1.0)
    for _ in range(10):
        ang = rng.uniform(0, math.tau)
        dist = 18 + 22 * ease_out(min(1, max(0, (t - 0.45) / 0.5)))
        blob(d, math.cos(ang) * dist, math.sin(ang) * dist * 0.5 - 4, rng.uniform(4, 8), mix(EARTH, WHITE, 0.4), da * rng.uniform(0.4, 1))
    fr.paste(dust.filter(ImageFilter.GaussianBlur(2 * K)))
    return fr.done()


# --------------------------------------------------------------------- Spark
def spark(f):
    t = f / (FRAMES - 1)
    fr = Frame()
    rng = random.Random(100 + f // 2)
    core_y = -48
    flash = fr.layer()
    d = ImageDraw.Draw(flash)
    fa = 255 * bell(t, 0.0, 0.08, 0.45)
    blob(d, 0, core_y, 30 * (0.6 + t), mix(FIRE, (255, 230, 120), 0.5), fa * 0.7)
    blob(d, 0, core_y, 12, WHITE, fa)
    fr.paste(flash, 10, 1.2)
    bolts = fr.layer()
    d = ImageDraw.Draw(bolts)
    ba = 255 * bell(t, 0.0, 0.15, 0.7)
    reach = 30 + 40 * ease_out(min(1, t * 2.2))
    for i in range(7):
        ang = math.radians(i * (360 / 7) + rng.uniform(-14, 14) + f * 9)
        x1, y1 = math.cos(ang) * reach, core_y + math.sin(ang) * reach * 0.8
        bolt(d, rng, 0, core_y, x1, y1, (255, 214, 90), ba, 3.2, jag=6)
        bolt(d, rng, 0, core_y, x1 * 0.7, y1 * 0.85, WHITE, ba * 0.9, 1.4, jag=4)
    fr.paste(bolts, 4, 1.4)
    sparks = fr.layer()
    d = ImageDraw.Draw(sparks)
    srng = random.Random(7)
    for _ in range(24):
        ang = srng.uniform(0, math.tau)
        speed = srng.uniform(40, 80)
        x = math.cos(ang) * speed * t
        y = core_y + math.sin(ang) * speed * t * 0.8 + 70 * t * t
        a = 255 * (1 - t) * (0.5 + 0.5 * srng.random())
        blob(d, x, y, srng.uniform(1.5, 2.8), mix(FIRE, (255, 240, 160), srng.random()), a)
    fr.paste(sparks, 2, 1.0)
    return fr.done()


# --------------------------------------------------------------------- Sleet
def sleet(f):
    t = f / (FRAMES - 1)
    fr = Frame()
    frost = fr.layer()
    d = ImageDraw.Draw(frost)
    spread = ease_out(min(1, max(0, (t - 0.25) / 0.45)))
    a = 200 * bell(t, 0.25, 0.6, 1.0)
    ground_ellipse(d, 12 + 30 * spread, mix(WATER, WHITE, 0.55), a * 0.55)
    ground_ellipse(d, 12 + 30 * spread, mix(WATER, WHITE, 0.8), a, width=2)
    # Frost crystals around the ring.
    for i in range(8):
        ang = math.radians(i * 45 + 10)
        r = (12 + 30 * spread) * 0.95
        x, y = math.cos(ang) * r, math.sin(ang) * r * 0.5
        h = 9 * spread
        d.polygon([at(x - 2.5, y), at(x, y - h), at(x + 2.5, y)], fill=mix(WATER, WHITE, 0.75) + (int(a),))
    fr.paste(frost, 3, 0.7)
    shards = fr.layer()
    d = ImageDraw.Draw(shards)
    rng = random.Random(31)
    for i in range(9):
        start = rng.uniform(0.0, 0.35)
        u = (t - start) / 0.4
        if u < 0 or u > 1.25:
            continue
        lx = rng.uniform(-30, 30)
        ly = rng.uniform(-12, 6)
        x = lx + 34 * (1 - min(u, 1))
        y = ly - 120 * (1 - min(u, 1))
        a = 255 * (1 if u <= 1 else max(0, 1 - (u - 1) * 4))
        L = 12
        dx, dy = -0.27, 0.96  # falling down-left
        tip = at(x + dx * L, y + dy * L)
        tail = at(x - dx * L, y - dy * L)
        mid_l = at(x - 2.5, y)
        mid_r = at(x + 2.5, y)
        d.polygon([tail, mid_l, tip, mid_r], fill=mix(WATER, WHITE, 0.6) + (int(a),))
        d.line([tail, tip], fill=WHITE + (int(a),), width=int(1 * K))
    fr.paste(shards, 3, 0.9)
    snow = fr.layer()
    d = ImageDraw.Draw(snow)
    srng = random.Random(5)
    for _ in range(18):
        x0 = srng.uniform(-44, 44)
        y0 = srng.uniform(-130, -20)
        y = y0 + 70 * t
        x = x0 + math.sin(t * 6 + srng.random() * 6) * 4
        a = 230 * bell(t, 0.0, 0.3, 1.0)
        blob(d, x, y, srng.uniform(1.2, 2.2), WHITE, a)
    fr.paste(snow, 2, 0.8)
    return fr.done()


# --------------------------------------------------------------------- Magma
def _lava_pool(d, rng, rx, glow, crack_a, f, loop=False):
    cx, cy = FEET
    ground_ellipse(d, rx, (70, 24, 10), 230 * crack_a)
    ground_ellipse(d, rx * 0.86, mix(FIRE, (255, 200, 80), 0.3 * glow), 210 * crack_a * glow)
    # Dark crust plates.
    prng = random.Random(77)
    for _ in range(7):
        ang = prng.uniform(0, math.tau)
        r = prng.uniform(0.2, 0.7) * rx
        x, y = math.cos(ang) * r, math.sin(ang) * r * 0.5
        s = prng.uniform(4, 8)
        d.ellipse((at(x - s, y - s * 0.5)[0], at(x - s, y - s * 0.5)[1], at(x + s, y + s * 0.5)[0], at(x + s, y + s * 0.5)[1]),
                  fill=(55, 22, 12, int(220 * crack_a)))


def magma(f):
    t = f / (FRAMES - 1)
    fr = Frame()
    rng = random.Random(3)
    pool = fr.layer()
    d = ImageDraw.Draw(pool)
    grow = ease_out(min(1, t * 2.2))
    fade = 1 - max(0, (t - 0.8) / 0.2) * 0.6
    _lava_pool(d, rng, 10 + 26 * grow, 0.6 + 0.4 * math.sin(t * 9) ** 2, fade, f)
    # Cracks spreading out of the pool.
    crng = random.Random(9)
    for i in range(7):
        ang = math.radians(i * (360 / 7) + crng.uniform(-15, 15))
        L = (24 + 22 * crng.random()) * grow
        pts = []
        for s in range(5):
            r = L * s / 4
            pts.append(at(math.cos(ang) * r + crng.uniform(-2, 2), math.sin(ang) * r * 0.5 + crng.uniform(-1, 1)))
        d.line(pts, fill=(255, 150, 50, int(240 * fade)), width=int(2 * K))
    fr.paste(pool, 5, 1.1)
    flames = fr.layer()
    d = ImageDraw.Draw(flames)
    fa = bell(t, 0.15, 0.4, 0.9)
    for i in range(6):
        ang = math.radians(i * 60 + 15)
        x, y = math.cos(ang) * 18, math.sin(ang) * 9
        h = (18 + 10 * math.sin(f * 1.7 + i)) * fa
        if h < 2:
            continue
        d.polygon([at(x - 5, y), at(x + 2 * math.sin(f + i), y - h), at(x + 5, y)], fill=FIRE + (int(230 * fa),))
        d.polygon([at(x - 2.5, y), at(x + math.sin(f + i), y - h * 0.6), at(x + 2.5, y)], fill=(255, 220, 110, int(240 * fa)))
    fr.paste(flames, 4, 1.2)
    embers = fr.layer()
    d = ImageDraw.Draw(embers)
    erng = random.Random(21)
    for _ in range(16):
        x0 = erng.uniform(-28, 28)
        start = erng.uniform(0, 0.5)
        u = max(0, t - start)
        y = -u * erng.uniform(60, 110)
        a = 255 * bell(t, start, start + 0.15, 1.0)
        blob(d, x0 + math.sin(u * 8) * 3, y, erng.uniform(1.2, 2.2), (255, 190, 80), a)
    fr.paste(embers, 2, 1.0)
    return fr.done()


def magma_loop(f):
    t = f / LOOP_FRAMES
    fr = Frame()
    pool = fr.layer()
    d = ImageDraw.Draw(pool)
    _lava_pool(d, random.Random(3), 34, 0.55 + 0.45 * math.sin(t * math.tau) ** 2, 0.9, f, loop=True)
    fr.paste(pool, 5, 0.9)
    bub = fr.layer()
    d = ImageDraw.Draw(bub)
    brng = random.Random(40)
    for i in range(5):
        phase = (t + i / 5) % 1
        ang = brng.uniform(0, math.tau)
        r = brng.uniform(4, 22)
        x, y = math.cos(ang) * r, math.sin(ang) * r * 0.5
        s = 1.5 + 3.5 * phase
        a = 255 * (1 - phase)
        blob(d, x, y - 1, s, (255, 205, 100), a)
    for i in range(4):
        phase = (t + i / 4) % 1
        x = -18 + i * 12
        blob(d, x + math.sin(phase * 6) * 2, -phase * 34, 1.6, (255, 180, 70), 255 * (1 - phase))
    fr.paste(bub, 2, 1.0)
    return fr.done()


# ---------------------------------------------------------------------- Mire
MUD = (120, 96, 52)
MUD_WET = (96, 120, 72)
MUD_LIGHT = (176, 150, 96)


def mire(f):
    t = f / (FRAMES - 1)
    fr = Frame()
    pool = fr.layer()
    d = ImageDraw.Draw(pool)
    grow = ease_out(min(1, t * 2.4))
    fade = 1 - max(0, (t - 0.8) / 0.2) * 0.7
    ground_ellipse(d, 12 + 30 * grow, (52, 40, 22), 240 * fade)
    ground_ellipse(d, (12 + 30 * grow) * 0.9, MUD, 240 * fade)
    ground_ellipse(d, (12 + 30 * grow) * 0.62, mix(MUD, MUD_WET, 0.6), 230 * fade)
    for k in range(2):
        rr = (12 + 30 * grow) * (0.4 + 0.45 * ((t * 2 + k * 0.5) % 1))
        ground_ellipse(d, rr, MUD_LIGHT, 200 * fade, width=2)
    fr.paste(pool, 2, 0.5)
    splash = fr.layer()
    d = ImageDraw.Draw(splash)
    rng = random.Random(55)
    sa = bell(t, 0.05, 0.25, 0.75)
    for _ in range(14):
        ang = rng.uniform(math.pi * 1.05, math.pi * 1.95)
        speed = rng.uniform(50, 90)
        u = min(1, t / 0.6)
        x = math.cos(ang) * speed * 0.7 * u
        y = math.sin(ang) * speed * u + 110 * u * u
        r = rng.uniform(3.5, 6)
        blob(d, x, min(y, 4), r, (52, 40, 22), 255 * sa)
        blob(d, x - r * 0.25, min(y, 4) - r * 0.25, r * 0.7, mix(MUD, MUD_LIGHT, rng.random()), 255 * sa)
    fr.paste(splash, 1, 0.4)
    # Tendrils curling up around the ankles.
    tend = fr.layer()
    d = ImageDraw.Draw(tend)
    ta = 255 * bell(t, 0.3, 0.55, 1.0)
    h = 34 * ease_out(min(1, max(0, (t - 0.3) / 0.3)))
    for i, ang in enumerate([160, 220, 320, 20]):
        x = math.cos(math.radians(ang)) * 14
        y = math.sin(math.radians(ang)) * 7
        pts = [at(x + math.sin(s * 1.4 + i) * 4 * (s / 5), y - h * s / 5) for s in range(6)]
        d.line(pts, fill=(52, 40, 22, int(ta)), width=int(6 * K), joint="curve")
        d.line(pts, fill=MUD_WET + (int(ta),), width=int(3.5 * K), joint="curve")
    fr.paste(tend, 1, 0.3)
    bub = fr.layer()
    d = ImageDraw.Draw(bub)
    brng = random.Random(8)
    for i in range(6):
        phase = (t * 1.5 + i / 6) % 1
        ang = brng.uniform(0, math.tau)
        r = brng.uniform(4, 20) * grow
        blob(d, math.cos(ang) * r, math.sin(ang) * r * 0.5 - 1, 1.5 + 3.5 * phase, MUD_LIGHT, 230 * (1 - phase) * fade)
    fr.paste(bub)
    return fr.done()


# --------------------------------------------------------------------- Steam
def _puffs(d, rng_seed, t, count, rise, spread, alpha, loop=False):
    rng = random.Random(rng_seed)
    for i in range(count):
        start = (i / count) if loop else rng.uniform(0, 0.4)
        u = ((t + start) % 1) if loop else max(0.0, (t - start) / 0.7)
        if not loop and (t < start or u > 1.2):
            continue
        x = rng.uniform(-spread, spread) + math.sin(u * 4 + i) * 6
        y = -u * rise - rng.uniform(0, 10)
        r = 9 + 16 * u
        a = alpha * (1 - min(u, 1)) * (0.6 + 0.4 * rng.random())
        if loop:
            a *= min(1, u * 5)
        tone = mix((214, 222, 232), WHITE, rng.random())
        blob(d, x, y, r, tone, a)


def steam(f):
    t = f / (FRAMES - 1)
    fr = Frame()
    base = fr.layer()
    d = ImageDraw.Draw(base)
    ga = 170 * bell(t, 0.0, 0.25, 1.0)
    ground_ellipse(d, 34, (220, 228, 236), ga * 0.7)
    fr.paste(base.filter(ImageFilter.GaussianBlur(3 * K)))
    cloud = fr.layer()
    d = ImageDraw.Draw(cloud)
    _puffs(d, 61, t, 16, 110, 26, 235)
    fr.paste(cloud.filter(ImageFilter.GaussianBlur(3 * K)), 6, 0.5)
    sparkle = fr.layer()
    d = ImageDraw.Draw(sparkle)
    srng = random.Random(14)
    for _ in range(10):
        x = srng.uniform(-30, 30)
        y = srng.uniform(-90, -10) - 20 * t
        a = 255 * bell(t, srng.uniform(0, 0.4), 0.5, 1.0)
        blob(d, x, y, 1.3, mix(WATER, WHITE, 0.6), a)
    fr.paste(sparkle, 2, 1.0)
    return fr.done()


def steam_loop(f):
    t = f / LOOP_FRAMES
    fr = Frame()
    base = fr.layer()
    d = ImageDraw.Draw(base)
    ground_ellipse(d, 30, (220, 228, 236), 120)
    fr.paste(base.filter(ImageFilter.GaussianBlur(3 * K)))
    cloud = fr.layer()
    d = ImageDraw.Draw(cloud)
    _puffs(d, 62, t, 8, 90, 20, 200, loop=True)
    fr.paste(cloud.filter(ImageFilter.GaussianBlur(3 * K)), 5, 0.4)
    return fr.done()


EFFECTS = {
    "drift_pin": (drift_pin, FRAMES),
    "spark": (spark, FRAMES),
    "sleet": (sleet, FRAMES),
    "magma": (magma, FRAMES),
    "mire": (mire, FRAMES),
    "steam": (steam, FRAMES),
    "magma_loop": (magma_loop, LOOP_FRAMES),
    "steam_loop": (steam_loop, LOOP_FRAMES),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (fn, n) in EFFECTS.items():
        strip = Image.new("RGBA", (CELL * n, CELL), (0, 0, 0, 0))
        for f in range(n):
            strip.paste(fn(f), (CELL * f, 0))
        strip.save(os.path.join(OUT, "blend_%s.png" % name), optimize=True)
    print("wrote %d Blend strips to %s" % (len(EFFECTS), OUT))


if __name__ == "__main__":
    main()
