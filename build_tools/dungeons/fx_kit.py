"""Shared builders for small effect pieces: one-cell floor hazard decals (the Granary's
toxic pool, the Frostspire frost patch) and projectile / impact sprites cut from a 2x2
sheet. Defaults are the Granary's; its output must stay byte-identical.
"""
import os

import cv2
import numpy as np

import gkit
from board_kit import addglow


def path(rel, two=False):
    d, f = os.path.split(rel)
    return os.path.join(gkit.OUT, d, "_2x", f) if two else os.path.join(gkit.OUT, rel)


def cell_decal(src, rel, grade=None, inset=0.93, lo=0.45, span=0.35, glow_col=(0.5, 1.0, 0.15), gain=(5, 3.2, 1.5, 0.8),
               min_island=40, bright_fn=None):
    """A top-down painting on a key colour -> a 64x32 (128x64 _2x) cell decal plus a 96x56 additive glow.
    Returns (file, glow_file)."""
    rgb = gkit.load_rgb(src)
    prem = gkit.clean_alpha(gkit.key_auto(rgb), min_island=min_island)
    if grade:
        prem = gkit.grade(prem, **grade)
    prem = cv2.resize(prem, (768, 768), interpolation=cv2.INTER_AREA)
    if bright_fn is None:
        lum = rgb.mean(-1) / 255.0
        bright = np.clip((lum - lo) / span, 0, 1).astype(np.float32)
    else:
        bright = bright_fn(rgb / 255.0).astype(np.float32)
    bright = cv2.resize(bright, (768, 768), interpolation=cv2.INTER_AREA) * prem[..., 3]
    grel = rel.replace(".png", "_glow.png")
    for k, two in ((1, False), (2, True)):
        W, H = 64 * k, 32 * k
        ss = 4
        ys, xs = np.mgrid[0:H * ss, 0:W * ss].astype(np.float32) + 0.5
        px = (xs - W * ss / 2) / (W * ss / 2)
        py = ys / (H * ss / 2)
        # Slight inset so the splashes stay inside the cell diamond.
        s = ((px + py) / 2.0 - 0.5) * inset + 0.5
        t = ((py - px) / 2.0 - 0.5) * inset + 0.5
        mx = (np.clip(s, 0, 1) * 767).astype(np.float32)
        my = (np.clip(t, 0, 1) * 767).astype(np.float32)
        big = cv2.remap(prem, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        big[(s < 0) | (s > 1) | (t < 0) | (t > 1)] = 0
        im = gkit.binarize(cv2.resize(big, (W, H), interpolation=cv2.INTER_AREA))
        gkit.save_png(path(rel, two), im)
        gb = cv2.remap(bright, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        gs = cv2.resize(gb, (W, H), interpolation=cv2.INTER_AREA)
        can = np.zeros((56 * k, 96 * k), np.float32)
        oy = 12 * k
        can[oy:oy + H, 16 * k:16 * k + W] = gs
        g = np.clip(cv2.GaussianBlur(can, (0, 0), gain[0] * k) * gain[1] + cv2.GaussianBlur(can, (0, 0), gain[2] * k) * gain[3], 0, 1)
        gkit.save_png(path(grel, two), addglow(g, glow_col))
    return rel, grel


def projectile_sheet(src, specs, source_rel):
    """Cut sprites from a 2x2 sheet. specs: list of dicts with
    id, quad (qx, qy), size (1x width), kind ('projectile' | 'impact_effect'), star (None | 5),
    note, keep_main (bool), dust_fix (bool: pull leftover key tint to grey-brown), glow_col (or None).
    Returns the manifest entries."""
    rgb = gkit.load_rgb(src)
    prem = gkit.key_auto(rgb)
    H, W = rgb.shape[:2]
    out_entries = []
    for sp in specs:
        pid = sp["id"]
        qx, qy = sp["quad"]
        if sp.get("box"):  # optional explicit source box (x0, y0, x1, y1) px, for items that cross the sheet's half-lines
            bx0, by0, bx1, by1 = sp["box"]
            q = prem[by0:by1, bx0:bx1].copy()
        else:
            q = prem[qy * H // 2:(qy + 1) * H // 2, qx * W // 2:(qx + 1) * W // 2].copy()
        a = (q[..., 3] > 0.5).astype(np.uint8)
        n, lab, st, _ = cv2.connectedComponentsWithStats(a, 8)
        if sp.get("keep_main", True):
            main = 1 + int(np.argmax(st[1:, 4]))
            q[lab != main] = 0
        else:
            q = gkit.clean_alpha(q, min_island=sp.get("min_island", 6), fill_holes=0)
            if sp.get("dust_fix"):
                # Leftover magenta tint in the soft dust: pull those pixels to the dust's grey-brown.
                a3 = np.maximum(q[..., 3:4], 1e-4)
                c = q[..., :3] / a3
                pink = (c[..., 0] > c[..., 1] + 0.02) & (c[..., 2] > c[..., 1] - 0.03)
                lum = c.mean(-1, keepdims=True)
                dust = lum * np.array(sp.get("dust_col", [1.12, 1.0, 0.84]), np.float32)
                c = np.where(pink[..., None], np.clip(dust, 0, 1), c)
                q[..., :3] = c * a3
        star = sp.get("star") == 5
        rel = ("star5/" if star else "") + "board/projectiles/%s.png" % pid
        crop, _ = gkit.crop_bbox(q, pad=6)
        out = {}
        glow_col = sp.get("glow_col")
        gsize = sp.get("glow_size", 40)
        for k, two in ((1, False), (2, True)):
            tw = sp["size"] * k
            th = max(2, int(round(crop.shape[0] * tw / crop.shape[1])))
            im = gkit.binarize(gkit.resize_prem(crop, tw, th))
            m = 2 * k
            can = np.zeros((th + 2 * m, tw + 2 * m, 4), np.uint8)
            can[m:m + th, m:m + tw] = im
            gkit.save_png(path(rel, two), can)
            out[k] = [can.shape[1], can.shape[0]]
            if glow_col:
                gw = max(gsize, can.shape[1] // k + 16) * k if sp.get("glow_fit") else gsize * k
                gh = max(gsize, can.shape[0] // k + 16) * k if sp.get("glow_fit") else gsize * k
                gc = np.zeros((gh, gw), np.float32)
                al = (can[..., 3] > 0).astype(np.float32)
                y0 = (gh - can.shape[0]) // 2
                x0 = (gw - can.shape[1]) // 2
                gc[y0:y0 + can.shape[0], x0:x0 + can.shape[1]] = al
                g = np.clip(cv2.GaussianBlur(gc, (0, 0), 3 * k) * 1.5 + cv2.GaussianBlur(gc, (0, 0), 8 * k) * 1.4, 0, 1)
                gkit.save_png(path(rel.replace(".png", "_glow.png"), two), addglow(g, glow_col))
                out["g%d" % k] = [gw, gh]
        e = {"id": pid, "kind": sp.get("kind", "projectile"), "star": 5 if star else None,
             "file": rel, "file_2x": os.path.dirname(rel) + "/_2x/" + os.path.basename(rel),
             "size": out[1], "size_2x": out[2],
             "anchor": "centred: draw with the image centre on the flight point (projectile) or the hit point (puff)",
             "source": source_rel}
        if sp.get("note_first"):
            e["note"] = sp["note"]
        if glow_col:
            e["glow"] = rel.replace(".png", "_glow.png")
            e["glow_2x"] = os.path.dirname(rel) + "/_2x/" + os.path.basename(rel).replace(".png", "_glow.png")
            e["glow_size"] = out["g1"]
        if not sp.get("note_first"):
            e["note"] = sp["note"]
        out_entries.append(e)
    return out_entries
