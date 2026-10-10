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
    N = 10
    ox, oy = 380, 230
    W, H = 780, 700
    out = {}
    for hover in (False, True):
        can = Image.new("RGBA", (W, H), cf["bg"] + (255,))
        for s in range(2 * N - 1):
            for x in range(N):
                y = s - x
                if 0 <= y < N:
                    cx, cy = c2l(x, y)
                    t = Image.open(os.path.join(KIT, "tiles", cf["ground"][h(x, y, len(cf["ground"]))] + ".png")).convert("RGBA")
                    can.alpha_composite(t, (ox + cx - 32, oy + cy - 16))
        O = (3, 2)
        dc = td["door_cell_from_nw"]
        d = ImageDraw.Draw(can)
        cx, cy = c2l(O[0] + dc[0], O[1] + dc[1])
        cx, cy = ox + cx, oy + cy
        d.polygon([(cx, cy - 16), (cx + 32, cy), (cx, cy + 16), (cx - 32, cy)], outline=(255, 230, 120))
        items = []
        sx, sy = O[0] + 2, O[1] + 2
        items.append((sx + sy, "b", (sx, sy)))
        nid, nfp = cf["neighbour"]
        nb = (O[0] + 4, O[1])
        items.append((nb[0] + nfp - 1 + nb[1] + nfp - 1, "n", (nb[0] + nfp - 1, nb[1] + nfp - 1)))
        kk = cf.get("keeper", (1, 3))
        kc = (O[0] + kk[0], O[1] + kk[1])
        items.append((kc[0] + kc[1], "k", kc))
        for i, tid in enumerate(cf["trees"]):
            tc = [(O[0] - 2, O[1] + 1), (O[0] + 6, O[1] + 4)][i % 2]
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
        d.text((10, 8), "%s door at 1x: 3x3 footprint, door cell outlined (origin+%s), door_keeper at origin+(%d,%d)%s"
               % (man["name"], dc, kk[0], kk[1], ", hover glow on" if hover else ""), fill=(235, 235, 240))
        out[hover] = can
    mock = os.path.join(gkit.OUT, "_mock")
    os.makedirs(mock, exist_ok=True)
    open(os.path.join(mock, ".gdignore"), "w").close()
    out[False].convert("RGB").save(os.path.join(mock, "town_door_mock.png"))
    out[True].convert("RGB").save(os.path.join(mock, "town_door_hover_mock.png"))
    print(os.path.join(mock, "town_door_mock.png"))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "frostspire_archive")
