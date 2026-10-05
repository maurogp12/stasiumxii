#!/usr/bin/env python3
"""Slagcrown (lava map) water stamps (Mauro 5 Oct 2026).

The water cut from the volcano picture came out near black, so the seven
water tiles read as black holes ("Is that circled area obstacles?" ... "yes do
it"). Repaint them as dark teal hot-spring water from the dock map's water
stamps, with a faint warm lava reflection so they belong on the volcano board.
Then (Mauro's steam picture) each water tile is a round boiling pool sunk in
the basalt floor: a dark rock rim, dark teal water inside (the pool circle is
UV radius POOL_R = 0.21, the same circle board/arena_surface.gdshader mode 6 boils).
Writes art/maps/arena_look/slagcrown/water_<n>.png (64x32, same diamond alpha).
Run: python3 build_tools/art/slagcrown_water.py
"""
from PIL import Image, ImageEnhance

SRC = "art/maps/arena_look/brinewake/water_%d.png"
FLOOR = "art/maps/arena_look/slagcrown/ground_%d.png"
POOL_R = 0.21
RIM_R = 0.28
OUT = "art/maps/arena_look/slagcrown/water_%d.png"
DEEP = (6, 30, 40)       # dark teal
WARM = (255, 120, 40)    # lava glow from below


def repaint(img):
    alpha = img.getchannel("A")
    grey = ImageEnhance.Contrast(img.convert("L")).enhance(1.3)
    out = Image.new("RGBA", img.size)
    px = out.load()
    g = grey.load()
    for y in range(img.height):
        for x in range(img.width):
            v = g[x, y] / 255.0
            # Teal body, light ripples toward pale cyan; warmer near the bottom edge.
            warm = max(0.0, (y / img.height) - 0.55) * 0.35
            r = DEEP[0] + (120 - DEEP[0]) * v ** 1.6 + WARM[0] * warm * 0.4
            gg = DEEP[1] + (200 - DEEP[1]) * v ** 1.6 + WARM[1] * warm * 0.25
            b = DEEP[2] + (205 - DEEP[2]) * v ** 1.6
            px[x, y] = (min(255, int(r)), min(255, int(gg)), min(255, int(b)), 255)
    out.putalpha(alpha)
    return out


def pool(n):
    floor = Image.open(FLOOR % n).convert("RGBA")
    water = repaint(Image.open(SRC % n).convert("RGBA"))
    w, h = floor.size
    out = floor.copy()
    px = out.load()
    wp = water.load()
    for y in range(h):
        for x in range(w):
            # UV circle (the 2:1 diamond stamp is a square in UV).
            u, v = (x + 0.5) / w - 0.5, (y + 0.5) / h - 0.5
            d = (u * u + v * v) ** 0.5
            r, g, b, a = px[x, y]
            if d < POOL_R:
                wr, wg, wb, _ = wp[x, y]
                # Darker toward the far (upper) lip, as if sunk.
                k = 0.75 + 0.5 * (v + POOL_R) / (2 * POOL_R)
                px[x, y] = (int(wr * k), int(wg * k), int(wb * k), a)
            elif d < RIM_R:
                t = (d - POOL_R) / (RIM_R - POOL_R)
                # Dark basalt lip, lit on the near (lower) edge.
                lit = 0.35 + 0.35 * max(0.0, v) / RIM_R
                f = lit + (1.0 - lit) * t * t
                px[x, y] = (int(r * f), int(g * f), int(b * f), a)
    return out


def main():
    for n in range(4):
        pool(n % 10).save(OUT % n, optimize=True)
        print("pool", n)


if __name__ == "__main__":
    main()
