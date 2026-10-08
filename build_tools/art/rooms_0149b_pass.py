#!/usr/bin/env python3
"""Stormspire floor cleanup and a few more Windmere decorations.

View only. Terrain, elevation, lightning cells, and paint_only tags stay.
Water cells keep their bolts. Mud stays a dark pit (it blocks walking).
Ground cells that are a painted hole, a rubble pile, or a pink rim are
pulled back to the same stone as the clean tiles.
"""
import json
import os

import numpy as np
from PIL import Image

import install_scenario as inst

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ROOMS = os.path.join(ROOT, "art", "rooms")
HW, HH = 64.0, 32.0
STORM = (
    "koliseo_stormspire",
    "stasis_stormspire_room_a",
    "stasis_stormspire_room_b",
)
WIND = (
    "koliseo_windmere",
    "stasis_windmere_room_a",
    "stasis_windmere_room_b",
)
# Extra pieces per map: crystals, frost tufts. Room B had no crystal.
EXTRA = {
    "koliseo_windmere": (4, 4),
    "stasis_windmere_room_a": (4, 4),
    "stasis_windmere_room_b": (3, 4),
}
SLIM = "/tmp/scen/stormspire/centre_lightning_spire_slim.png"
CRYSTALS = [
    "/tmp/scen/windmere/prop_ice_crystal_a.png",
    "/tmp/scen/windmere/prop_ice_crystal_b.png",
    "/tmp/scen/windmere/prop_ice_crystal_c.png",
]


def cell_center(x, y):
    return int(((x - y) * 32 + 610) * 2), int(((x + y) * 16 + 366) * 2)


def tags_path(room_id):
    if room_id.startswith("stasis_"):
        return os.path.join(ROOT, "art", "maps", "stasis_v1", "%s_15x15_tags.json" % room_id[len("stasis_"):])
    return os.path.join(ROOT, "art", "maps", "arena_colosseum_v2", "tiled", "%s_15x15_tags.json" % room_id[len("koliseo_"):])


def load_tags(room_id):
    return json.load(open(tags_path(room_id)))["cells"]


def tight_magenta(rgb):
    """Pink or purple rim. Lightning (blue brighter than red) is not this."""
    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)
    bolt = (b > 160) & (b > r + 25)
    return (g + 10 < r) & (g + 10 < b) & (np.maximum(r, b) > 90) & (b < 220) & ~bolt


def window(arr, x, y):
    h, w = arr.shape[:2]
    cx, cy = cell_center(x, y)
    x0, x1 = max(0, cx - 70), min(w, cx + 71)
    y0, y1 = max(0, cy - 38), min(h, cy + 39)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    dist = np.abs(xx - cx) / HW + np.abs(yy - cy) / HH
    return x0, x1, y0, y1, dist, cx, cy


def box_mean(lum, radius):
    pad = np.pad(lum, radius, mode="edge")
    total = np.pad(pad, ((1, 0), (1, 0)), mode="constant").cumsum(0).cumsum(1)
    k = radius * 2 + 1
    windowed = total[k:, k:] - total[:-k, k:] - total[k:, :-k] + total[:-k, :-k]
    return windowed / float(k * k)


def clean_storm(room_id):
    path = os.path.join(ROOMS, room_id, "background_board_2x.webpbin")
    arr = np.array(Image.open(path).convert("RGB"))
    cells = load_tags(room_id)
    donors = []
    restamp = []
    rims = []
    for cell in cells:
        if cell["terrain"] != "ground":
            continue
        x0, x1, y0, y1, dist, cx, cy = window(arr, cell["x"], cell["y"])
        sub = arr[y0:y1, x0:x1]
        inside = dist <= 0.90
        if int(inside.sum()) < 80:
            continue
        lum = sub.mean(axis=2)
        mag = int((tight_magenta(sub) & inside).sum())
        dark = (lum < 32) & inside
        dark_n = int(dark.sum())
        center = inside & (dist < 0.45)
        rim = inside & (dist > 0.72)
        center_med = float(np.median(lum[center])) if center.any() else 80.0
        rim_med = float(np.median(lum[rim])) if rim.any() else 80.0
        pit = center_med < 38.0 and rim_med > 58.0
        clutter = dark_n > int(inside.sum() * 0.16) or pit
        rec = (cell["x"], cell["y"], mag, dark_n, center_med, rim_med)
        if clutter:
            restamp.append(rec)
        elif mag > 24:
            rims.append(rec)
        elif mag < 16 and dark_n < 70 and 48.0 < float(np.median(lum[inside])) < 92.0:
            donors.append((cell["x"], cell["y"]))
    if not donors:
        raise RuntimeError("no clean stone donor on %s" % room_id)
    painted = 0
    for index, (x, y, _mag, _dark, _c, _r) in enumerate(restamp):
        dx, dy = donors[(x * 3 + y * 5 + index) % len(donors)]
        sx0, sx1, sy0, sy1, _sd, scx, scy = window(arr, dx, dy)
        x0, x1, y0, y1, dist, cx, cy = window(arr, x, y)
        src = arr[sy0:sy1, sx0:sx1]
        yy, xx = np.mgrid[y0:y1, x0:x1]
        take = dist <= 0.98
        sy = np.clip(scy + (yy - cy) - sy0, 0, src.shape[0] - 1)
        sx = np.clip(scx + (xx - cx) - sx0, 0, src.shape[1] - 1)
        copied = src[sy, sx]
        base = arr[y0:y1, x0:x1]
        base[take] = copied[take]
        arr[y0:y1, x0:x1] = base
        painted += 1
    rimmed = 0
    for x, y, _mag, _dark, _c, _r in rims:
        x0, x1, y0, y1, dist, _cx, _cy = window(arr, x, y)
        sub = arr[y0:y1, x0:x1].astype(np.float32)
        inside = dist <= 0.96
        mag = tight_magenta(sub.astype(np.uint8)) & inside
        if not mag.any():
            continue
        stone = np.median(sub[inside & ~mag], axis=0) if (inside & ~mag).any() else np.array([62.0, 58.0, 54.0])
        sub[mag] = stone
        arr[y0:y1, x0:x1] = np.clip(sub, 0, 255).astype(np.uint8)
        rimmed += 1
    # Thin sticks left on stone or poking out of a mud pit. Broad dark pits stay.
    spikes = 0
    lum = arr.mean(axis=2)
    blur = box_mean(lum, 5)
    for cell in cells:
        if cell["terrain"] == "water":
            continue
        x0, x1, y0, y1, dist, _cx, _cy = window(arr, cell["x"], cell["y"])
        sub = arr[y0:y1, x0:x1].astype(np.float32)
        local = blur[y0:y1, x0:x1]
        here = sub.mean(axis=2)
        inside = dist <= 0.94
        if cell["terrain"] == "mud":
            field = float(np.median(here[inside])) if inside.any() else 40.0
            stick = inside & (np.abs(here - field) > 36.0) & (local > field + 8.0)
            if stick.any():
                sub[stick] = np.array([field * 0.92, field * 0.86, field * 0.78])
                spikes += int(stick.sum())
        else:
            stick = inside & (here < 30.0) & (local > 50.0)
            if stick.any():
                tone = np.array([local[stick], local[stick] * 0.94, local[stick] * 0.88]).T
                sub[stick] = tone
                spikes += int(stick.sum())
        arr[y0:y1, x0:x1] = np.clip(sub, 0, 255).astype(np.uint8)
    Image.fromarray(arr).save(path, "WEBP", quality=90, method=4)
    print("storm", room_id, "restamp", painted, "rims", rimmed, "spike px", spikes, "donors", len(donors))


def enlarge_spire():
    art = inst.contain_bottom(Image.open(SLIM), (104, 220))
    for room in STORM:
        inst.write_occluder(room, "tower", art, 0)


def edge(x, y):
    return x <= 2 or y <= 2 or x >= 12 or y >= 12


def far_from(x, y, taken, gap):
    for ox, oy in taken:
        if max(abs(x - ox), abs(y - oy)) < gap:
            return False
    return True


def pick_cells(room_id, kind, count, taken):
    """Edge cells only. Crystals sit on water or mud so they add no blocker.

    Spacing is against the same kind. A tuft may sit near a crystal.
    """
    chosen = []
    cells = load_tags(room_id)
    place = json.load(open(os.path.join(ROOMS, room_id, "place.json")))
    busy = set(taken)
    same = []
    for occ in place["occluders"]:
        cell = occ.get("cell") or [0, 0]
        pos = (int(cell[0]), int(cell[1]))
        busy.add(pos)
        what = (occ.get("what") or [""])[0]
        if kind == "crystal" and what in ("crystal", "crystal_decor"):
            same.append(pos)
        elif kind == "frost_tuft" and what == "frost_tuft":
            same.append(pos)
    spawns = {(1, 13), (13, 1), (2, 2), (12, 12)}
    if room_id.startswith("stasis_"):
        tags = json.load(open(tags_path(room_id)))
        for item in tags.get("spawns") or []:
            if isinstance(item, list) and len(item) >= 2:
                spawns.add((int(item[0]), int(item[1])))
    ranked = []
    for cell in cells:
        x, y = int(cell["x"]), int(cell["y"])
        if (x, y) in busy or (x, y) in spawns:
            continue
        if int(cell["elevation"]) != 0 or not edge(x, y):
            continue
        if max(abs(x - 7), abs(y - 7)) <= 4:
            continue
        terrain = cell["terrain"]
        if kind == "crystal" and terrain not in ("water", "mud"):
            continue
        if kind == "frost_tuft" and terrain != "ground":
            continue
        # Corners first, then the outer ring.
        score = 0 if (x <= 1 or x >= 13) and (y <= 1 or y >= 13) else 1
        score = score * 10 + max(abs(x - 7), abs(y - 7)) * -1
        ranked.append((score, x, y))
    ranked.sort()
    for _score, x, y in ranked:
        if not far_from(x, y, same, 2):
            continue
        chosen.append((x, y))
        same.append((x, y))
        busy.add((x, y))
        if len(chosen) == count:
            break
    return chosen


def add_windmere():
    slot = next(item for item in inst.SLOTS if item["id"] == "windmere_crystal")
    arts = [inst.contain_bottom(Image.open(path), slot["size"]) for path in CRYSTALS]
    frost = Image.open(os.path.join(ROOT, "art/scenario/windmere_frost_tuft.webpbin"))
    crystal_i = 0
    for room_id in WIND:
        n_crystal, n_frost = EXTRA[room_id]
        place_path = os.path.join(ROOMS, room_id, "place.json")
        place = json.load(open(place_path))
        taken = []
        for occ in place["occluders"]:
            cell = occ.get("cell") or [0, 0]
            taken.append((int(cell[0]), int(cell[1])))
        crystals = pick_cells(room_id, "crystal", n_crystal, taken)
        taken.extend(crystals)
        tufts = pick_cells(room_id, "frost_tuft", n_frost, taken)
        for x, y in crystals:
            art = arts[crystal_i % len(arts)]
            crystal_i += 1
            rel = "occluders_2x/crystal_%d_%d.webpbin" % (x, y)
            inst.save_webp(os.path.join(ROOMS, room_id, rel), art)
            place["occluders"].append({
                "file": rel,
                "cell": [x, y],
                "offset": inst.bottom_offset(art, 12),
                "what": ["crystal_decor"],
                "size": [art.size[0], art.size[1]],
            })
        for x, y in tufts:
            rel = "occluders_2x/frost_%d_%d.webpbin" % (x, y)
            inst.save_webp(os.path.join(ROOMS, room_id, rel), frost)
            place["occluders"].append({
                "file": rel,
                "cell": [x, y],
                "offset": [-24, -18],
                "what": ["frost_tuft"],
                "size": [frost.size[0], frost.size[1]],
            })
        json.dump(place, open(place_path, "w"), separators=(",", ":"), ensure_ascii=False)
        print("wind", room_id, "crystals", crystals, "frost", tufts)


def main():
    for room_id in STORM:
        clean_storm(room_id)
    enlarge_spire()
    add_windmere()


if __name__ == "__main__":
    main()
