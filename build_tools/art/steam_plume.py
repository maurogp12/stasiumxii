#!/usr/bin/env python3
"""Tall looping steam plume for Slagcrown's boiling pools (Mauro 5 Oct 2026,
his steam picture: thin columns rising high off the pools).
The Blend Steam loop carries a pale floor puff that hid the pool, so the map
plume is its own strip: no floor patch, a narrow column that widens and fades
as it rises. Seamless loop: every puff's phase wraps.
Writes art/vfx/blends/map_steam_plume.png (FRAMES cells of W x H, anchor at the
bottom centre, see VfxRouter.MAP_STEAM).
Run: python3 build_tools/art/steam_plume.py
"""
import math

from PIL import Image, ImageDraw, ImageFilter

W, H = 96, 224
FRAMES = 12
PUFFS = 22
OUT = "art/vfx/blends/map_steam_plume.png"
S = 3  # paint at 3x, then reduce


def frame(f):
    img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    for k in range(PUFFS):
        phase = (k / PUFFS + f / FRAMES) % 1.0
        y = (H - 10) - phase * (H - 30)
        sway = math.sin(phase * 5.0 + k * 1.7) * (3 + 10 * phase)
        x = W / 2 + sway
        r = 7 + phase * 22
        a = min(1.0, phase * 8.0) * (1.0 - phase) ** 0.7 * 0.7
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
