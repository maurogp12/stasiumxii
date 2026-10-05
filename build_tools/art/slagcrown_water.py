#!/usr/bin/env python3
"""Slagcrown (lava map) water stamps (Mauro 5 Oct 2026).

The water cut from the volcano picture came out near black, so the seven
water tiles read as black holes ("Is that circled area obstacles?" ... "yes do
it"). Repaint them as dark teal hot-spring water from the dock map's water
stamps, with a faint warm lava reflection so they belong on the volcano board.
Writes art/maps/arena_look/slagcrown/water_<n>.png (64x32, same diamond alpha).
Run: python3 build_tools/art/slagcrown_water.py
"""
from PIL import Image, ImageEnhance

SRC = "art/maps/arena_look/brinewake/water_%d.png"
OUT = "art/maps/arena_look/slagcrown/water_%d.png"
DEEP = (10, 52, 62)      # dark teal
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


def main():
    for n in range(4):
        img = Image.open(SRC % n).convert("RGBA")
        repaint(img).save(OUT % n, optimize=True)
        print("water", n)


if __name__ == "__main__":
    main()
