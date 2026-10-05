#!/usr/bin/env python3
"""Slagcrown (lava map) round pits filled with boiling water (Mauro 5 Oct 2026:
"do the steaming water in the circles water").

The ash_rock pits (round red-rimmed bowls, already obstacles: they block walk
and sight) get dark teal water with bubble glints inside the bowl; the rim
stays. Their steam plume comes from CellTagMap.STEAM_PROPS.
Run after arena_props.py (it rewrites prop_ash_rock.png):
  python3 build_tools/art/slagcrown_steam_pits.py
"""
import random

from PIL import Image

PATH = "art/maps/arena_look/slagcrown/prop_ash_rock.png"
# Water surface inside the bowl, in sprite px (52 x 32 sprite).
CX, CY, RX, RY = 26.0, 14.5, 17.5, 6.8
DEEP = (8, 40, 50)
LIGHT = (95, 190, 200)


def main():
    img = Image.open(PATH).convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            e = ((x + 0.5 - CX) / RX) ** 2 + ((y + 0.5 - CY) / RY) ** 2
            if e >= 1.0:
                continue
            lum = (r * 0.5 + g * 0.3 + b * 0.2) / 255.0
            # Edge of the water darker (shadow under the lip), centre lighter.
            k = min(1.0, lum * 1.6) * (1.0 - 0.45 * e)
            px[x, y] = tuple(int(DEEP[c] + (LIGHT[c] - DEEP[c]) * k) for c in range(3)) + (a,)
    rnd = random.Random(5)
    for _ in range(9):
        bx = CX + rnd.uniform(-0.7, 0.7) * RX
        by = CY + rnd.uniform(-0.6, 0.6) * RY
        if ((bx - CX) / RX) ** 2 + ((by - CY) / RY) ** 2 < 0.7:
            px[int(bx), int(by)] = (210, 245, 250, 255)
    img.save(PATH, optimize=True)
    print("ash_rock pit filled with boiling water")


if __name__ == "__main__":
    main()
