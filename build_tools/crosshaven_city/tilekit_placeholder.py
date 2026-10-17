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
    "bridge": ((2, 5), 40, (140, 110, 80), False),
}

# Round 26: ring pieces are runs along the wall line (screen slope 0 or
# +/-0.5), drawn as slabs: [width px, slope, height, colour, extra]
SLABS = {
    "wall_h": (409, 0.0, 550, (170, 160, 140), None),
    "wall_diag_se": (409, 0.5, 550, (170, 160, 140), None),
    "wall_diag_ne": (409, -0.5, 550, (170, 160, 140), None),
    "gate_h": (1323, 0.0, 550, (165, 155, 135), "arch"),
    "gate_diag_se": (1323, 0.5, 550, (165, 155, 135), "arch"),
    "gate_diag_ne": (1323, -0.5, 550, (165, 155, 135), "arch"),
    "tunnel_h": (1027, 0.0, 550, (150, 150, 160), "grate"),
    "tunnel_diag_se": (1027, 0.5, 550, (150, 150, 160), "grate"),
    "tunnel_diag_ne": (1027, -0.5, 550, (150, 150, 160), "grate"),
}


def slab(width, slope, h, col, extra):
    dy = abs(slope) * width
    W, H = width, int(h + dy + 8)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # foot line from left to right; the foot (bottom centre) at (W/2, foot_y)
    y_left = H - 4 - (dy if slope < 0 else 0)
    y_right = y_left + slope * width
    d.polygon([(0, y_left), (W, y_right), (W, y_right - h), (0, y_left - h)], fill=col + (255,), outline=(60, 55, 50, 255))
    foot = (W // 2, int(round((y_left + y_right) / 2)))
    door = None
    if extra:
        aw, ah = 244, 352
        ax0 = W // 2 - aw // 2
        ay1 = foot[1]
        if extra == "arch":
            d.polygon([(ax0, ay1 - slope * aw / 2), (ax0 + aw, ay1 + slope * aw / 2),
                       (ax0 + aw, ay1 + slope * aw / 2 - ah), (ax0, ay1 - slope * aw / 2 - ah)], fill=(0, 0, 0, 0))
            door = {"frames": 8, "fps": 12, "frame_w": aw, "frame_h": ah + int(abs(slope) * aw),
                    "offset": [ax0, int(ay1 - ah - abs(slope) * aw / 2)], "open_inward": True}
        else:
            for k in range(8):
                x = ax0 + k * aw // 7
                d.line([(x, ay1 - ah), (x, ay1)], fill=(40, 40, 50, 255), width=6)
    return im, foot, door


def door_strip(fw, fh):
    im = Image.new("RGBA", (fw * 8, fh), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for f in range(8):
        leaf = int((fw // 2) * (1.0 - f / 7.0))
        x0 = f * fw
        if leaf > 0:
            d.rectangle([x0, 0, x0 + leaf, fh - 1], fill=(120, 80, 45, 255), outline=(60, 40, 20, 255))
            d.rectangle([x0 + fw - leaf, 0, x0 + fw - 1, fh - 1], fill=(120, 80, 45, 255), outline=(60, 40, 20, 255))
    return im


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
    for kind, (width, slope, h, col, extra) in SLABS.items():
        im, foot, door = slab(width, slope, h, col, extra)
        name = "piece_%s.png" % kind
        im.save(os.path.join(out, name), optimize=True)
        rec = {"file": name, "foot": list(foot), "footprint": [3, 1], "blocks": True, "height_px": h,
               "size": [im.width, im.height], "slope": slope}
        if door:
            dn = "piece_%s_door.png" % kind
            door_strip(door["frame_w"], door["frame_h"]).save(os.path.join(out, dn), optimize=True)
            door["file"] = dn
            rec["door"] = door
        kit["pieces"][kind] = rec
    for t in kit["terrains"]:
        t["atlas_cols"] = 16
    json.dump(kit, open(os.path.join(out, "kit.json"), "w"), indent=1)
    print("kit", out, len(kit["terrains"]), "terrains", len(kit["pieces"]), "pieces")


if __name__ == "__main__":
    main()
