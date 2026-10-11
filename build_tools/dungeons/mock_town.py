"""Town door review mock: the dungeon building on town ground at 1x with a 2x2 town cottage
for scale, the existing door_keeper NPC beside the door cell (origin+(1,3)), and the door cell outlined.

  python3 mock_town.py frostspire_archive
Writes <OUT>/_mock/town_door_mock.png, town_door_hover_mock.png (additive glow on) and
town_door_footprint.png (the measured 3x3 footprint and door cell drawn over the building).
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402

KIT = os.path.join(gkit.REPO, "art", "world", "crosshaven")
KEEPER = os.path.join(gkit.REPO, "art", "characters", "world", "npc", "door_keeper")
CONF = {
    "frostspire_archive": {"ground": ["snow_crust_a", "snow_crust_b", "snow_crust_c"], "neighbour": ("cottage_slate_snow", 2),
                           "trees": ["tree_pine_snow_a", "tree_pine_snow_b"], "bg": (40, 46, 58)},
    "old_granary_cellar": {"ground": ["golden_plains_a"], "neighbour": ("cottage_thatch", 2), "trees": [], "bg": (40, 40, 30)},
    "saltmaw_grotto": {"ground": ["golden_plains_sand_a", "golden_plains_sand_b", "golden_plains_sand_c"], "neighbour": ("fishing_hut_2x2", 2),
                       "trees": ["tree_autumn_a", "tree_autumn_b"], "bg": (36, 52, 60), "keeper": (0, 3)},
    "drowned_abbey": {"ground": ["golden_plains_shade_a", "golden_plains_shade_b"], "neighbour": ("fishing_hut_2x2", 2),
                      "trees": ["tree_willow", "tree_willow_stump"], "bg": (34, 44, 38), "keeper": (0, 3)},
    # Westwatch: drawn in crosshaven_westwatch coordinates (building origin (2,9), door (5,13), keeper (6,13)), centred on (5,11)
    "heart_of_the_blight": {"ground": ["farm_fallow_a", "farm_fallow_b"], "span": ((-3, 14), (2, 21)), "neighbour": ("watchtower_2x2", 2),
                            "trees": ["tree_birch_stump", "tree_golden_oak_stump"], "bg": (40, 34, 44), "keeper": (4, 4),
                            "origin": (2, 9), "N": 18, "centre": (5, 11), "size": (900, 760), "neighbour_at": (6, -3), "tree_at": [(-2, 2), (7, 2)]},
}


def c2l(x, y):
    return (x - y) * 32, (x + y) * 16


def h(x, y, k):
    return (((x * 73856093) ^ (y * 19349663) ^ (x * y * 83492791)) & 0x7fffffff) % k


def add(can, img, pos):
    arr = np.array(can).astype(np.int32)
    g = np.array(img.convert("RGB")).astype(np.int32)
    x, y = pos
    hh, ww = g.shape[:2]
    arr[y:y + hh, x:x + ww, :3] = np.clip(arr[y:y + hh, x:x + ww, :3] + g, 0, 255)
    return Image.fromarray(arr.astype(np.uint8))


def main(did):
    gkit.use(did)
    cf = CONF[did]
    man = json.load(open(os.path.join(gkit.OUT, "manifest.json")))
    td = man["town_door"]
    b = Image.open(os.path.join(gkit.OUT, td["file"])).convert("RGBA")
    glow = Image.open(os.path.join(gkit.OUT, td["hatch_glow"])).convert("RGBA")
    N = cf.get("N", 10)
    W, H = cf.get("size", (780, 700))
    ox, oy = 380, 230
    if cf.get("centre"):
        ccx, ccy = c2l(*cf["centre"])
        ox, oy = W // 2 - ccx, H // 2 - ccy
    out = {}
    for hover in (False, True):
        can = Image.new("RGBA", (W, H), cf["bg"] + (255,))
        (gx0, gx1), (gy0, gy1) = cf.get("span", ((0, N), (0, N)))
        for s in range(gx0 + gy0, gx1 + gy1 - 1):
            for x in range(gx0, gx1):
                y = s - x
                if gy0 <= y < gy1:
                    cx, cy = c2l(x, y)
                    t = Image.open(os.path.join(KIT, "tiles", cf["ground"][h(x, y, len(cf["ground"]))] + ".png")).convert("RGBA")
                    can.alpha_composite(t, (ox + cx - 32, oy + cy - 16))
        O = cf.get("origin", (3, 2))
        fp = td["footprint_size"][0]
        dc = td["door_cell_from_nw"]
        d = ImageDraw.Draw(can)
        cx, cy = c2l(O[0] + dc[0], O[1] + dc[1])
        cx, cy = ox + cx, oy + cy
        d.polygon([(cx, cy - 16), (cx + 32, cy), (cx, cy + 16), (cx - 32, cy)], outline=(255, 230, 120))
        items = []
        sx, sy = O[0] + fp - 1, O[1] + fp - 1
        items.append((sx + sy, "b", (sx, sy)))
        nid, nfp = cf["neighbour"]
        na = cf.get("neighbour_at", (4, 0))
        nb = (O[0] + na[0], O[1] + na[1])
        items.append((nb[0] + nfp - 1 + nb[1] + nfp - 1, "n", (nb[0] + nfp - 1, nb[1] + nfp - 1)))
        kk = cf.get("keeper", (1, 3))
        kc = (O[0] + kk[0], O[1] + kk[1])
        items.append((kc[0] + kc[1], "k", kc))
        for i, tid in enumerate(cf["trees"]):
            ta = cf.get("tree_at", [(-2, 1), (6, 4)])
            tc = (O[0] + ta[i % 2][0], O[1] + ta[i % 2][1])
            items.append((tc[0] + tc[1], "t" + tid, tc))
        for _, kind, (x, y) in sorted(items):
            cx, cy = c2l(x, y)
            px, py = ox + cx, oy + cy + 16
            if kind == "b":
                can.alpha_composite(b, (px - b.width // 2, py - b.height))
                if hover:
                    can = add(can, glow, (px - b.width // 2, py - b.height))
            elif kind == "n":
                im = Image.open(os.path.join(KIT, "props", nid + ".png")).convert("RGBA")
                can.alpha_composite(im, (px - im.width // 2, py - im.height))
            elif kind == "k":
                strip = Image.open(os.path.join(KEEPER, "idle_s.png")).convert("RGBA")
                fr = strip.crop((0, 0, strip.height, strip.height))
                can.alpha_composite(fr, (px - 64, py - 16 - 120))
            else:
                im = Image.open(os.path.join(KIT, "props", kind[1:] + ".png")).convert("RGBA")
                can.alpha_composite(im, (px - im.width // 2, py - im.height))
        d = ImageDraw.Draw(can)
        d.text((10, 8), "%s door at 1x: %dx%d footprint, door cell outlined (origin+%s), door_keeper at origin+(%d,%d)%s"
               % (man["name"], fp, fp, dc, kk[0], kk[1], ", hover glow on" if hover else ""), fill=(235, 235, 240))
        out[hover] = can
    mock = os.path.join(gkit.OUT, "_mock")
    os.makedirs(mock, exist_ok=True)
    open(os.path.join(mock, ".gdignore"), "w").close()
    out[False].convert("RGB").save(os.path.join(mock, "town_door_mock.png"))
    out[True].convert("RGB").save(os.path.join(mock, "town_door_hover_mock.png"))
    print(os.path.join(mock, "town_door_mock.png"))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "frostspire_archive")
