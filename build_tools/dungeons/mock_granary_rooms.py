"""Review mock: room A and room B assembled from the kit at game camera scale (1 board px = 1 screen px).

Writes art/pc/dungeons/old_granary_cellar/_mock/rooms_mock.png (and per-room images).
Optional monster stand-ins: if monster idle frames exist they are placed on the board
at pawn scale 0.5 with the cell pivot (256,329) on the cell centre (pawn.gd SPRITE_SCALE).
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402

K = gkit.OUT
N = 15
MOCK = os.path.join(K, "_mock")

ROOM_A = {
    "floor": "cellar_floor", "backdrop": "room_a_cellar_15x15",
    "pads": [(3, 4), (8, 2), (12, 6), (4, 11), (10, 10), (7, 13)],
    "props": [("crate_stack", (5, 4)), ("grain_sacks", (6, 4)), ("barrel_cluster", (10, 5)), ("crate_stack", (11, 5)),
              ("grain_sacks", (11, 6)), ("broken_crate", (6, 9)), ("crate_stack", (2, 8)), ("barrel_cluster", (13, 11)),
              ("broken_crate", (9, 13)), ("grain_sacks", (1, 13))],
    "units": [("granary_rat", "S", (7, 6)), ("granary_rat", "E", (9, 8)), ("scarecrow_drudge", "S", (4, 7)),
              ("hero:kestrel", "E", (8, 11)), ("hero:bastion", "E", (5, 12))],
}
ROOM_B = {
    "floor": "lair_floor", "backdrop": "room_b_lair_15x15",
    "pads": [(2, 7), (12, 7), (7, 12)],
    "decals": [("drain_grate", (6, 6))],
    "props": [("bone_throne", (6, 0)), ("barrel_cluster", (1, 2)), ("crate_stack", (12, 1)), ("grain_sacks", (13, 2)),
              ("broken_crate", (3, 10)), ("grain_sacks", (11, 11))],
    "units": [("the_ratking", "S", (7, 3)), ("granary_rat", "S", (5, 4)), ("granary_rat", "S", (10, 4)),
              ("hero:kestrel", "E", (6, 11)), ("hero:bastion", "E", (9, 12))],
}


def c2l(x, y):
    return (x - y) * 32, (x + y) * 16


def load(p):
    return Image.open(os.path.join(K, p)).convert("RGBA")


def add(can, img, pos):
    arr = np.array(can).astype(np.int32)
    g = np.array(img.convert("RGB")).astype(np.int32)
    x, y = pos
    h, w = g.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(arr.shape[1], x + w), min(arr.shape[0], y + h)
    arr[y0:y1, x0:x1, :3] = np.clip(arr[y0:y1, x0:x1, :3] + g[y0 - y:y1 - y, x0 - x:x1 - x], 0, 255)
    return Image.fromarray(arr.astype(np.uint8))


def unit_img(kind, facing):
    """Return (image, pivot) for a unit at board scale 0.5."""
    if kind.startswith("hero:"):
        cls = kind[5:]
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_hero_ref", "%s_idle_%s_f00.png" % (cls, facing))
        if not os.path.exists(path):
            return None
        im = Image.open(path).convert("RGBA")
        piv = (256, 329)
    else:
        mdir = os.path.join(K, "monsters", kind)
        mm = os.path.join(mdir, "meta.json")
        if not os.path.exists(mm):
            return None
        meta = json.load(open(mm))
        im = Image.open(os.path.join(mdir, "idle", "idle_%s_f00.png" % facing)).convert("RGBA")
        piv = tuple(meta["pivot"])
    s = 0.5
    im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    return im, (piv[0] * s, piv[1] * s)


def render(room):
    bd = [b for b in json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "_board_meta.json")))["backdrops"] if b["id"] == room["backdrop"]][0]
    bimg = load(bd["file"])
    ox, oy = bd["cell00_centre_px"]
    pad = 20
    W, H = bimg.width + 2 * pad, bimg.height + 2 * pad + 40
    can = Image.new("RGBA", (W, H), (7, 6, 5, 255))
    O = (ox + pad, oy + pad)
    can.alpha_composite(bimg, (pad, pad))
    pads = set(room.get("pads", []))
    for s in range(2 * N - 1):
        for x in range(N):
            y = s - x
            if not 0 <= y < N:
                continue
            cx, cy = c2l(x, y)
            if (x, y) in pads:
                t = load("board/tiles/wheat_pad.png")
            else:
                t = load("board/tiles/%s_%s.png" % (room["floor"], "abc"[gkit_hash(x, y, 3)]))
            can.alpha_composite(t, (O[0] + cx - 32, O[1] + cy - 16))
    for did, (x, y) in room.get("decals", []):
        d = load("board/props/%s.png" % did)
        cx, cy = c2l(x + 2, y + 2)
        can.alpha_composite(d, (O[0] + cx - d.width // 2, O[1] + cy + 16 - d.height))
        can = add(can, load("board/props/%s_glow.png" % did), (O[0] + cx - d.width // 2, O[1] + cy + 16 - d.height))
    for (x, y) in pads:
        cx, cy = c2l(x, y)
        can = add(can, load("board/tiles/wheat_pad_glow.png"), (O[0] + cx - 48, O[1] + cy - 32))
    items = []
    for pid, (x, y) in room["props"]:
        fp = 2 if pid == "bone_throne" else 1
        sx, sy = x + fp - 1, y + fp - 1
        items.append((sx + sy, 0, "prop", pid, (sx, sy)))
    for kind, f, (x, y) in room["units"]:
        items.append((x + y, 1, "unit", (kind, f), (x, y)))
    for _, _, typ, what, (x, y) in sorted(items, key=lambda t: (t[0], t[1])):
        cx, cy = c2l(x, y)
        if typ == "prop":
            p = load("board/props/%s.png" % what)
            can.alpha_composite(p, (O[0] + cx - p.width // 2, O[1] + cy + 16 - p.height))
        else:
            u = unit_img(*what)
            if u is None:
                continue
            im, (px, py) = u
            can.alpha_composite(im, (int(O[0] + cx - px), int(O[1] + cy - py)))
    return can


def gkit_hash(x, y, k):
    return (((x * 73856093) ^ (y * 19349663) ^ (x * y * 83492791)) & 0x7fffffff) % k


def main():
    os.makedirs(MOCK, exist_ok=True)
    open(os.path.join(MOCK, ".gdignore"), "w").close()
    a = render(ROOM_A)
    b = render(ROOM_B)
    a.convert("RGB").save(os.path.join(MOCK, "room_a_mock.png"))
    b.convert("RGB").save(os.path.join(MOCK, "room_b_mock.png"))
    W = a.width + b.width + 30
    H = max(a.height, b.height) + 40
    sheet = Image.new("RGB", (W, H), (20, 18, 16))
    sheet.paste(a.convert("RGB"), (10, 30))
    sheet.paste(b.convert("RGB"), (a.width + 20, 30))
    d = ImageDraw.Draw(sheet)
    d.text((14, 8), "Room A: Old Granary Cellar (15x15 board, 1 board px = 1 screen px)", fill=(230, 210, 170))
    d.text((a.width + 24, 8), "Room B: the Ratking's lair (15x15)", fill=(230, 210, 170))
    sheet.save(os.path.join(MOCK, "rooms_mock.png"))
    print(os.path.join(MOCK, "rooms_mock.png"), sheet.size)


if __name__ == "__main__":
    main()
