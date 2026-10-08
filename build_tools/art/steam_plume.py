#!/usr/bin/env python3
"""Short soft steam for Slagcrown's boiling pools.
No floor puff. A narrow column that fades as it rises, short enough that it
does not cover the cells above the pool. Seamless loop.
Writes art/vfx/blends/map_steam_plume.png (FRAMES cells of W x H, anchor at the
bottom centre, see VfxRouter.MAP_STEAM).
Run: python3 build_tools/art/steam_plume.py
"""
import math

from PIL import Image, ImageDraw, ImageFilter

W, H = 96, 160
FRAMES = 12
PUFFS = 8
OUT = "art/vfx/blends/map_steam_plume.png"
S = 3  # paint at 3x, then reduce


def frame(f):
    img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    for k in range(PUFFS):
        phase = (k / PUFFS + f / FRAMES) % 1.0
        y = (H - 10) - phase * (H - 30)
        sway = math.sin(phase * 5.0 + k * 1.7) * (3 + 10 * phase)
        x = W / 2 + sway
        r = 5 + phase * 14
        a = min(1.0, phase * 8.0) * (1.0 - phase) ** 0.85 * 0.32
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        shade = int(235 - 25 * phase)
        d.ellipse(((x - r) * S, (y - r * 0.9) * S, (x + r) * S, (y + r * 0.9) * S),
                  fill=(shade, shade, shade + 6, int(255 * a)))
        layer = layer.filter(ImageFilter.GaussianBlur(r * S * 0.6))
        img.alpha_composite(layer)
    return img.resize((W, H), Image.LANCZOS)


def main():
    strip = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
    for f in range(FRAMES):
        strip.alpha_composite(frame(f), (f * W, 0))
    strip.save(OUT, optimize=True)
    print("plume", strip.size)


if __name__ == "__main__":
    main()
