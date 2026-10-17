#!/usr/bin/env python3
"""Placeholder tile kit for the modular (Wakfu-like) Crosshaven: flat colours.

Writes art/world/crosshaven_tiles/placeholder/: one 16-tile corner atlas per
ground terrain (128x64 tiles at hero 156 px), one iso box sprite per piece,
and kit.json. The real kit drops in with the same kit.json shape.

Ground autotiling (corner Wang, dual grid): a ground tile sits on every cell
corner (vertex); its 4 quarters are the 4 cells round that vertex, bit N=1
(cell x-1,y-1), E=2 (x,y-1), S=4 (x,y), W=8 (x-1,y). Terrains are drawn in
priority order; each terrain draws the tile whose bits are set where the
quarter's cell has that terrain or a higher one. Atlas column = mask (0..15).

Pieces: RGBA sprite plus "foot" (sprite px of the footprint's south corner)
and "footprint" [fw, fh] cells running north (-x, -y) from the anchor cell.

Usage: python3 tilekit_placeholder.py <repo root>
"""
import json
import os
import sys

from PIL import Image, ImageDraw

TW, TH = 128, 64
HERO = 156

TERRAINS = [
    ("grass", (96, 150, 70)),
    ("dirt", (160, 122, 80)),
    ("cobble", (150, 146, 136)),
    ("plaza", (196, 180, 150)),
    ("water", (60, 130, 190)),
]

# kind: footprint (cells), height (px at hero 156), colour, blocks
PIECES = {
    "wall": ((1, 1), 550, (170, 160, 140), True),
    "tower": ((3, 3), 990, (150, 140, 125), True),
    "gate": ((2, 2), 600, (120, 90, 60), False),
    "castle": ((10, 8), 1150, (200, 120, 110), True),
    "cathedral": ((8, 8), 1000, (120, 130, 200), True),
    "townhall": ((6, 5), 720, (200, 170, 110), True),
    "bank": ((5, 5), 650, (210, 190, 90), True),
    "house": ((3, 3), 460, (190, 110, 80), True),
    "workshop": ((3, 3), 480, (150, 100, 160), True),
    "mill": ((4, 3), 620, (120, 160, 160), True),
    "stall": ((1, 1), 260, (220, 90, 90), True),
    "fountain": ((2, 2), 280, (100, 170, 220), True),
    "well": ((1, 1), 250, (110, 110, 110), True),
    "lamp": ((1, 1), 270, (240, 220, 120), False),
    "bush": ((1, 1), 120, (60, 120, 50), False),
    "plot_normal": ((4, 4), 460, (230, 150, 120), True),
    "plot_rare": ((4, 4), 545, (130, 200, 230), True),
    "plot_legendary": ((4, 4), 620, (230, 200, 90), True),
    "bridge": ((1, 1), 40, (140, 110, 80), False),
}


def corner_tile(mask, col):
    im = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy, hw, hh = TW / 2, TH / 2, TW / 4, TH / 4
    quarters = {1: (cx, cy - hh), 2: (cx + hw, cy), 4: (cx, cy + hh), 8: (cx - hw, cy)}
    for bit, (qx, qy) in quarters.items():
        if mask & bit:
            d.polygon([(qx, qy - hh), (qx + hw, qy), (qx, qy + hh), (qx - hw, qy)], fill=col + (255,))
    return im


def box(fw, fh, h, col):
    w = (fw + fh) * TW // 2
    base_h = (fw + fh) * TH // 2
    im = Image.new("RGBA", (w + 2, base_h + h + 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # footprint diamond: west corner, north, east, south (anchor)
    south = (fh * TW / 2, base_h + h)
    east = (south[0] + fw * TW / 2, south[1] - fw * TH / 2)
    west = (south[0] - fh * TW / 2, south[1] - fh * TH / 2)
    north = (east[0] - fh * TW / 2, east[1] - fh * TH / 2)
    up = lambda p: (p[0], p[1] - h)
    dark = tuple(int(c * 0.62) for c in col)
    mid = tuple(int(c * 0.8) for c in col)
    d.polygon([west, south, up(south), up(west)], fill=dark + (255,))
    d.polygon([south, east, up(east), up(south)], fill=mid + (255,))
    d.polygon([up(west), up(south), up(east), up(north)], fill=col + (255,), outline=(30, 30, 30, 255))
    return im, (round(south[0]), round(south[1]))


def main():
    root = sys.argv[1]
    out = os.path.join(root, "art", "world", "crosshaven_tiles", "placeholder")
    os.makedirs(out, exist_ok=True)
    kit = {"format": "stasium.tile_kit", "format_version": 1, "name": "placeholder (flat colours)",
           "tile_px": [TW, TH], "hero_px": HERO, "autotile": "corner_wang_16",
           "corner_bits": {"N": 1, "E": 2, "S": 4, "W": 8},
           "terrains": [], "pieces": {}}
    for prio, (tid, col) in enumerate(TERRAINS):
        atlas = Image.new("RGBA", (TW * 16, TH), (0, 0, 0, 0))
        for m in range(16):
            atlas.paste(corner_tile(m, col), (m * TW, 0))
        name = "ground_%s.png" % tid
        atlas.save(os.path.join(out, name), optimize=True)
        kit["terrains"].append({"id": tid, "priority": prio, "atlas": name, "colour": list(col)})
    for kind, ((fw, fh), h, col, blocks) in PIECES.items():
        im, foot = box(fw, fh, h, col)
        name = "piece_%s.png" % kind
        im.save(os.path.join(out, name), optimize=True)
        kit["pieces"][kind] = {"file": name, "foot": list(foot), "footprint": [fw, fh], "blocks": blocks, "height_px": h}
    json.dump(kit, open(os.path.join(out, "kit.json"), "w"), indent=1)
    print("kit", out, len(kit["terrains"]), "terrains", len(kit["pieces"]), "pieces")


if __name__ == "__main__":
    main()
