"""Review mock: room A and room B assembled from a dungeon's kit at game camera scale
(1 board px = 1 screen px), reading every placement rule from its manifest.

  python3 mock_rooms.py frostspire_archive
Writes <OUT>/_mock/rooms_mock.png (and room_a_mock.png, room_b_mock.png). Monsters are
placed at pawn scale 0.5 with their cell pivot on the cell centre (pawn.gd SPRITE_SCALE);
heroes are the painted idle strips (art/characters/painted) as stand-ins.
The Granary keeps its own mock_granary_rooms.py.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402

HEROES = os.path.join(gkit.REPO, "art", "characters", "painted")
ROOMS = {
    "frostspire_archive": {
        "a": {"title": "Room A: the archive stacks (15x15 board, 1 board px = 1 screen px)", "backdrop": "room_a_archive_15x15",
              "pads": [(3, 4), (8, 2), (12, 6), (4, 11), (10, 10), (7, 13)],
              "props": [("frozen_bookshelf", (5, 4)), ("book_pile", (6, 4)), ("ice_crystals", (10, 5)), ("reading_desk", (11, 5)),
                        ("frozen_chest", (11, 6)), ("frozen_bookshelf", (6, 9)), ("ice_crystals", (2, 8)), ("book_pile", (13, 11)),
                        ("reading_desk", (9, 13)), ("frozen_chest", (1, 13))],
              "units": [("ice_construct", "S", (7, 6)), ("book_wraith", "S", (9, 3)), ("book_wraith", "S", (4, 7)),
                        ("ice_construct", "E", (11, 9)), ("hero:kestrel", "E", (8, 11)), ("hero:bastion", "E", (5, 12))]},
        "b": {"title": "Room B: the Pale Archivist's reading hall (15x15)", "backdrop": "room_b_hall_15x15",
              "pads": [(2, 7), (12, 7), (7, 12)],
              "decals": [("rune_circle", (6, 6))],
              "props": [("ice_throne", (6, 0)), ("frost_brazier", (4, 1)), ("frost_brazier", (9, 1)), ("book_pile", (1, 2)),
                        ("frozen_chest", (13, 2)), ("ice_crystals", (3, 10)), ("frozen_bookshelf", (11, 11))],
              "units": [("the_pale_archivist", "S", (7, 3)), ("book_wraith", "S", (5, 4)), ("ice_construct", "S", (10, 4)),
                        ("hero:kestrel", "E", (6, 11)), ("hero:bastion", "E", (9, 12))]},
    },
    "saltmaw_grotto": {
        "a": {"title": "Room A: the sea cave (15x15 board, 1 board px = 1 screen px)", "backdrop": "room_a_grotto_15x15",
              "pads": [(3, 4), (8, 2), (12, 6), (4, 11), (10, 10), (7, 13)],
              "props": [("sunken_crate", (5, 5)), ("barrel", (10, 4)), ("sunken_crate", (11, 5)), ("anchor", (10, 9)),
                        ("barnacle_rock", (6, 9)), ("coral_cluster", (2, 8)), ("coral_cluster", (13, 11)), ("barrel", (1, 13)),
                        ("barnacle_rock", (8, 13)), ("coral_cluster", (7, 1))],
              "units": [("reef_crab", "S", (7, 6)), ("drowned_harpooner", "S", (9, 2)), ("drowned_harpooner", "S", (4, 7)),
                        ("drowned_sailor", "S", (12, 8)), ("reef_crab", "S", (3, 2)), ("drowned_sailor", "E", (11, 11)),
                        ("hero:kestrel", "E", (8, 11)), ("hero:bastion", "E", (5, 12))]},
        "b": {"title": "Room B: Old Saltmaw's treasure lair (15x15)", "backdrop": "room_b_lair_15x15",
              "pads": [(2, 7), (12, 7), (7, 12)],
              "decals": [("whirlpool", (6, 6))],
              "props": [("rock_spire", (5, 5)), ("rock_spire", (7, 5)), ("rock_spire", (9, 5)), ("rock_spire", (9, 7)),
                        ("rock_spire", (9, 9)), ("rock_spire", (5, 9)), ("rock_spire", (5, 7)),
                        ("giant_clam", (1, 3)), ("treasure_chest", (12, 1)), ("sunken_statue", (2, 1)), ("barrel", (13, 4)),
                        ("sunken_crate", (1, 6)), ("barnacle_rock", (12, 12))],
              "units": [("old_saltmaw", "S", (7, 2)), ("reef_crab", "S", (4, 3)), ("drowned_sailor", "S", (10, 3)),
                        ("hero:kestrel", "E", (6, 12)), ("hero:bastion", "E", (9, 12))]},
    },
}
STAR5_REP = {
    "frostspire_archive": {"the_pale_archivist": "the_frozen_archivist", "ice_construct": "frozen_ice_construct", "book_wraith": "frozen_book_wraith"},
    "saltmaw_grotto": {"old_saltmaw": "abyssal_saltmaw", "reef_crab": "abyssal_reef_crab", "drowned_sailor": "abyssal_drowned_sailor",
                       "drowned_harpooner": "abyssal_drowned_harpooner"},
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
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(arr.shape[1], x + ww), min(arr.shape[0], y + hh)
    arr[y0:y1, x0:x1, :3] = np.clip(arr[y0:y1, x0:x1, :3] + g[y0 - y:y1 - y, x0 - x:x1 - x], 0, 255)
    return Image.fromarray(arr.astype(np.uint8))


class Kit:
    def __init__(self, star5=False):
        self.man = json.load(open(os.path.join(gkit.OUT, "manifest.json")))
        b = self.man["board"]
        self.props = {p["id"]: p for p in b["props"]}
        self.decals = {d["id"]: d for d in b["decals"]}
        self.backdrops = {d["id"]: d for d in b["backdrops"]}
        self.star5 = star5

    def load(self, rel):
        return Image.open(os.path.join(gkit.OUT, rel)).convert("RGBA")

    def unit(self, kind, facing):
        if kind.startswith("hero:"):
            cls = kind[5:]
            p = os.path.join(HEROES, cls, "%s_idle_%s.png" % (cls, facing))
            if not os.path.exists(p):
                return None
            strip = Image.open(p).convert("RGBA")
            fw = strip.width // 12
            fr = strip.crop((0, 0, fw, strip.height))
            s = 0.9
            fr = fr.resize((int(fr.width * s), int(fr.height * s)), Image.LANCZOS)
            return fr, (fw * s / 2, (strip.height - 7) * s), None
        for d in ("monsters/" + kind, "star5/monsters/" + kind):
            mm = os.path.join(gkit.OUT, d, "meta.json")
            if os.path.exists(mm):
                meta = json.load(open(mm))
                im = Image.open(os.path.join(gkit.OUT, d, "idle", "idle_%s_f00.png" % facing)).convert("RGBA")
                gp = os.path.join(gkit.OUT, d, "idle", "idle_%s_f00_glow.png" % facing)
                gl = Image.open(gp).convert("RGBA") if os.path.exists(gp) else None
                s = 0.5
                im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
                if gl:
                    gl = gl.resize(im.size, Image.LANCZOS)
                return im, (meta["pivot"][0] * s, meta["pivot"][1] * s), gl
        return None


def render(kit, room, n=15):
    bd = kit.backdrops[room["backdrop"]]
    bimg = kit.load(bd["file"])
    ox, oy = bd["cell00_centre_px"]
    pad = 20
    W, H = bimg.width + 2 * pad, bimg.height + 2 * pad + 40
    can = Image.new("RGBA", (W, H), (7, 6, 5, 255))
    O = (ox + pad, oy + pad)
    can.alpha_composite(bimg, (pad, pad))
    rid = "a" if room["backdrop"].startswith("room_a") else "b"
    rm = kit.man["board"]["rooms"][rid]
    pads = set(room.get("pads", []))
    pad_tile = kit.load("board/tiles/%s.png" % rm["pad"])
    pad_glow = kit.load("board/tiles/%s.png" % rm["pad_glow"])
    for s in range(2 * n - 1):
        for x in range(n):
            y = s - x
            if not 0 <= y < n:
                continue
            cx, cy = c2l(x, y)
            t = pad_tile if (x, y) in pads else kit.load("board/tiles/%s.png" % rm["floor"][h(x, y, 3)])
            can.alpha_composite(t, (O[0] + cx - 32, O[1] + cy - 16))
    for did, (x, y) in room.get("decals", []):
        d = kit.decals[did]
        m = d["footprint_size"][0] - 1
        im = kit.load(d["file"])
        cx, cy = c2l(x + m, y + m)
        pos = (O[0] + cx - im.width // 2, O[1] + cy + 16 - im.height)
        can.alpha_composite(im, pos)
        can = add(can, kit.load(d["file"].replace(".png", "_glow.png")), pos)
    for (x, y) in pads:
        cx, cy = c2l(x, y)
        can = add(can, pad_glow, (O[0] + cx - 48, O[1] + cy - 32))
    items = []
    for pid, (x, y) in room["props"]:
        fx, fy = kit.props[pid]["footprint_size"]
        sx, sy = x + fx - 1, y + fy - 1
        items.append((sx + sy, 0, "prop", pid, (sx, sy)))
    for kind, f, (x, y) in room["units"]:
        items.append((x + y, 1, "unit", (kind, f), (x, y)))
    for _, _, typ, what, (x, y) in sorted(items, key=lambda t: (t[0], t[1])):
        cx, cy = c2l(x, y)
        if typ == "prop":
            p = kit.props[what]
            im = kit.load(p["file"])
            pos = (O[0] + cx - im.width // 2, O[1] + cy + 16 - im.height)
            can.alpha_composite(im, pos)
            if p.get("glow"):
                can = add(can, kit.load(p["glow"]), pos)
        else:
            u = kit.unit(*what)
            if u is None:
                continue
            im, (px, py), gl = u
            pos = (int(O[0] + cx - px), int(O[1] + cy - py))
            can.alpha_composite(im, pos)
            if gl:
                can = add(can, gl, pos)
    return can


def main(did, star5=False):
    gkit.use(did)
    mock = os.path.join(gkit.OUT, "_mock")
    os.makedirs(mock, exist_ok=True)
    open(os.path.join(mock, ".gdignore"), "w").close()
    kit = Kit(star5)
    rooms = ROOMS[did]
    if star5:
        rooms = json.loads(json.dumps(rooms))
        rep = STAR5_REP[did]
        for r in rooms.values():
            r["units"] = [(rep.get(k, k), f, tuple(c)) for k, f, c in r["units"]]
            r["pads"] = [tuple(p) for p in r["pads"]]
            r["props"] = [(p, tuple(c)) for p, c in r["props"]]
            r["decals"] = [(d, tuple(c)) for d, c in r.get("decals", [])]
            r["title"] += " - star 5"
    a = render(kit, rooms["a"])
    b = render(kit, rooms["b"])
    tag = "_star5" if star5 else ""
    a.convert("RGB").save(os.path.join(mock, "room_a_mock%s.png" % tag))
    b.convert("RGB").save(os.path.join(mock, "room_b_mock%s.png" % tag))
    W = a.width + b.width + 30
    H = max(a.height, b.height) + 40
    sheet = Image.new("RGB", (W, H), (20, 18, 16))
    sheet.paste(a.convert("RGB"), (10, 30))
    sheet.paste(b.convert("RGB"), (a.width + 20, 30))
    d = ImageDraw.Draw(sheet)
    d.text((14, 8), rooms["a"]["title"], fill=(200, 220, 240))
    d.text((a.width + 24, 8), rooms["b"]["title"], fill=(200, 220, 240))
    out = os.path.join(mock, "rooms_mock%s.png" % tag)
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    main(args[0] if args else "frostspire_archive", star5="--star5" in sys.argv)
