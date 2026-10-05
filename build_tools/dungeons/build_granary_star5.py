"""Star-5 (radioactive) extras for the Old Granary Cellar: the toxic pool floor decal
(left behind by the Radioactive Ratking) and the Sling Rat projectiles.

Outputs under art/pc/dungeons/old_granary_cellar/:
  star5/board/toxic_pool.png (64x32), _2x/ (128x64), toxic_pool_glow.png (96x56 add)
  board/projectiles/sling_pebble.png, sling_seed.png, sling_impact_puff.png (+ _2x)
  star5/board/projectiles/sling_pebble_radioactive.png (+ _glow, + _2x)
"""
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402

META = {"decals": [], "glows": [], "projectiles": []}


def addglow(gray, col):
    g8 = np.clip(gray[..., None] * np.array(col, np.float32) * 255 + 0.5, 0, 255).astype(np.uint8)
    on = g8.max(-1) >= 3
    out = np.zeros(gray.shape + (4,), np.uint8)
    out[..., :3] = np.where(on[..., None], g8, 0)
    out[..., 3] = np.where(on, 255, 0)
    return out


def path(rel, two=False):
    d, f = os.path.split(rel)
    return os.path.join(gkit.OUT, d, "_2x", f) if two else os.path.join(gkit.OUT, rel)


def toxic_pool():
    rgb = gkit.load_rgb("toxic_pool.jpg")
    prem = gkit.clean_alpha(gkit.key_auto(rgb), min_island=40)
    prem = gkit.grade(prem, mul=(0.86, 0.86, 0.8), sat=0.82)
    prem = cv2.resize(prem, (768, 768), interpolation=cv2.INTER_AREA)
    lum = rgb.mean(-1) / 255.0
    bright = np.clip((lum - 0.45) / 0.35, 0, 1).astype(np.float32)
    bright = cv2.resize(bright, (768, 768), interpolation=cv2.INTER_AREA) * prem[..., 3]
    for k, two in ((1, False), (2, True)):
        W, H = 64 * k, 32 * k
        ss = 4
        ys, xs = np.mgrid[0:H * ss, 0:W * ss].astype(np.float32) + 0.5
        px = (xs - W * ss / 2) / (W * ss / 2)
        py = ys / (H * ss / 2)
        # Slight inset so the splashes stay inside the cell diamond.
        s = ((px + py) / 2.0 - 0.5) * 0.93 + 0.5
        t = ((py - px) / 2.0 - 0.5) * 0.93 + 0.5
        mx = (np.clip(s, 0, 1) * 767).astype(np.float32)
        my = (np.clip(t, 0, 1) * 767).astype(np.float32)
        big = cv2.remap(prem, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        big[(s < 0) | (s > 1) | (t < 0) | (t > 1)] = 0
        im = gkit.binarize(cv2.resize(big, (W, H), interpolation=cv2.INTER_AREA))
        gkit.save_png(path("star5/board/toxic_pool.png", two), im)
        gb = cv2.remap(bright, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        gs = cv2.resize(gb, (W, H), interpolation=cv2.INTER_AREA)
        can = np.zeros((56 * k, 96 * k), np.float32)
        oy = 12 * k
        can[oy:oy + H, 16 * k:16 * k + W] = gs
        g = np.clip(cv2.GaussianBlur(can, (0, 0), 5 * k) * 3.2 + cv2.GaussianBlur(can, (0, 0), 1.5 * k) * 0.8, 0, 1)
        gkit.save_png(path("star5/board/toxic_pool_glow.png", two), addglow(g, (0.5, 1.0, 0.15)))
    META["decals"].append({
        "id": "toxic_pool", "kind": "floor_decal", "star": 5, "blocks": False, "walkable": True,
        "file": "star5/board/toxic_pool.png", "file_2x": "star5/board/_2x/toxic_pool.png",
        "size": [64, 32], "size_2x": [128, 64], "footprint_size": [1, 1],
        "anchor": "image centre = cell centre (cell_to_local), same as a floor tile; draw on the ground layer over the floor tile",
        "note": "left behind by the Radioactive Ratking (his star-5 special); fade it in over ~0.3 s and out when it expires",
        "source": "build_tools/dungeons/granary_src/toxic_pool.jpg",
    })
    META["glows"].append({
        "id": "toxic_pool_glow", "for": "toxic_pool", "blend": "add", "star": 5,
        "file": "star5/board/toxic_pool_glow.png", "file_2x": "star5/board/_2x/toxic_pool_glow.png",
        "size": [96, 56], "size_2x": [192, 112],
        "anchor": "image centre = cell centre + (0, -4) at 1x (draw at cell_to_local - (48, 32)); pulse modulate 0.6..1.0",
    })


def projectiles():
    rgb = gkit.load_rgb("sling_projectiles.jpg")
    prem = gkit.key_auto(rgb)
    H, W = rgb.shape[:2]
    quads = {"sling_pebble": (0, 0), "sling_seed": (1, 0), "sling_impact_puff": (0, 1), "sling_pebble_radioactive": (1, 1)}
    sizes = {"sling_pebble": 12, "sling_seed": 11, "sling_impact_puff": 44, "sling_pebble_radioactive": 13}
    for pid, (qx, qy) in quads.items():
        q = prem[qy * H // 2:(qy + 1) * H // 2, qx * W // 2:(qx + 1) * W // 2].copy()
        a = (q[..., 3] > 0.5).astype(np.uint8)
        n, lab, st, _ = cv2.connectedComponentsWithStats(a, 8)
        if pid != "sling_impact_puff":
            main = 1 + int(np.argmax(st[1:, 4]))
            q[lab != main] = 0
        else:
            q = gkit.clean_alpha(q, min_island=6, fill_holes=0)
            # Leftover magenta tint in the soft dust: pull those pixels to the dust's grey-brown.
            a3 = np.maximum(q[..., 3:4], 1e-4)
            c = q[..., :3] / a3
            pink = (c[..., 0] > c[..., 1] + 0.02) & (c[..., 2] > c[..., 1] - 0.03)
            lum = c.mean(-1, keepdims=True)
            dust = lum * np.array([1.12, 1.0, 0.84], np.float32)
            c = np.where(pink[..., None], np.clip(dust, 0, 1), c)
            q[..., :3] = c * a3
        star = pid.endswith("radioactive")
        rel = ("star5/" if star else "") + "board/projectiles/%s.png" % pid
        crop, _ = gkit.crop_bbox(q, pad=6)
        out = {}
        for k, two in ((1, False), (2, True)):
            tw = sizes[pid] * k
            th = max(2, int(round(crop.shape[0] * tw / crop.shape[1])))
            # pad to even and a margin for the glow
            im = gkit.binarize(gkit.resize_prem(crop, tw, th))
            m = 2 * k
            can = np.zeros((th + 2 * m, tw + 2 * m, 4), np.uint8)
            can[m:m + th, m:m + tw] = im
            gkit.save_png(path(rel, two), can)
            out[k] = [can.shape[1], can.shape[0]]
            if star:
                gw = 40 * k
                gc = np.zeros((gw, gw), np.float32)
                al = (can[..., 3] > 0).astype(np.float32)
                y0 = (gw - can.shape[0]) // 2
                x0 = (gw - can.shape[1]) // 2
                gc[y0:y0 + can.shape[0], x0:x0 + can.shape[1]] = al
                g = np.clip(cv2.GaussianBlur(gc, (0, 0), 3 * k) * 1.5 + cv2.GaussianBlur(gc, (0, 0), 8 * k) * 1.4, 0, 1)
                gkit.save_png(path(rel.replace(".png", "_glow.png"), two), addglow(g, (0.5, 1.0, 0.15)))
        e = {"id": pid, "kind": "impact_effect" if "puff" in pid else "projectile", "star": 5 if star else None,
             "file": rel, "file_2x": os.path.dirname(rel) + "/_2x/" + os.path.basename(rel),
             "size": out[1], "size_2x": out[2],
             "anchor": "centred: draw with the image centre on the flight point (projectile) or the hit point (puff)",
             "source": "build_tools/dungeons/granary_src/sling_projectiles.jpg"}
        if "puff" in pid:
            e["note"] = "one-shot puff: scale 0.6 -> 1.2 and fade alpha 1 -> 0 over ~0.25 s at the target's chest (about 40 px above the cell centre at board scale)"
        elif star:
            e["glow"] = rel.replace(".png", "_glow.png")
            e["glow_2x"] = os.path.dirname(rel) + "/_2x/" + os.path.basename(rel).replace(".png", "_glow.png")
            e["glow_size"] = [40, 40]
            e["note"] = "radioactive pebble for the star-5 Radioactive Sling Rat; draw its glow (add) centred on it; may leave a toxic_pool on impact"
        else:
            e["note"] = "sling stone; fly it on a shallow arc (peak ~24 px) from the release point to the target, spin it ~720 deg/s; sling_seed is an alternative (grain-hard seed) ammo"
        META["projectiles"].append(e)


def build():
    for v in META.values():
        v.clear()
    toxic_pool()
    projectiles()
    return META


if __name__ == "__main__":
    import json
    print(json.dumps({k: [e["id"] for e in v] for k, v in build().items()}))
