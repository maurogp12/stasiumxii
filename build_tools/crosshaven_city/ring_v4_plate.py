#!/usr/bin/env python3
"""Crosshaven city from Mauro's ring v4 concept image (round 18).

Mauro: "use this one, just with fewer towers". His 1280x720 image becomes the
city plate (x4 = 5120x2880, the plate size the zone already uses):

1. Fewer towers: the towers not on the keep list are painted out by cloning
   the same image's wall (and the grass around it) along the wall line, one
   half from each neighbouring wall, so the wall runs on where a tower stood.
2. The cleaned image, upscaled (LANCZOS + light unsharp), is the ground.
3. Walls and kept towers are cut back out of it as y-sorted layers: wall
   strips with the foot line as their sort line, one layer per tower.
4. The cell grid is read from the image: walls and towers block, the river
   blocks, gates are carved through the wall, bridges are walkable.

All geometry is image px (1280x720) in ring_v4.json; the plate is x4.

Usage: python3 ring_v4_plate.py <repo root> [--debug <dir>] [--sheet <jpg>]
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_city as BC  # noqa: E402  (alpha_bits, MASK_STEP, Grid)

UP = 4  # image px -> plate px


def load_cfg():
    return json.load(open(os.path.join(HERE, "ring_v4.json")))


def green_mask(a):
    """Grass and foliage (kept as is by the clone, cut away from the layers)."""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (g > r + 4) & (g > b + 12)


def water_mask(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (b > r + 45) & (g > r + 25)


def path_mask(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (r > g + 6) & (r > b + 40) & (r > 120)


def shifted(a, dx, dy):
    """a sampled at (x + dx, y + dy), bilinear, edge clamped."""
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    out = np.empty_like(a)
    for c in range(a.shape[2]):
        out[..., c] = ndi.map_coordinates(a[..., c], [yy + dy, xx + dx], order=1, mode="nearest")
    return out


def remove_towers(img, cfg):
    """Paint out every tower in cfg['remove']: left half cloned from the wall to
    its left (along that wall's slope), right half from the wall to its right,
    a short cross-fade in the middle. Grass and foliage pixels stay (trees in
    front of a tower and the grass behind its roof are already right)."""
    a = img.astype(np.float32)
    h, w = a.shape[:2]
    keep_boxes = [t["box"] for t in cfg["towers"] if t.get("keep")]
    green = green_mask(img)
    for t in cfg["towers"]:
        if t.get("keep"):
            continue
        x0, y0, x1, y1 = t["box"]
        xc = (x0 + x1) / 2.0
        half = (x1 - x0) / 2.0
        d = half + float(t.get("margin", 4))
        sl, sr = float(t["slope_left"]), float(t["slope_right"])
        dl = half + float(t.get("margin_left", t.get("margin", 4)))
        left = shifted(a, -dl, -sl * dl)
        right = shifted(a, d, sr * d)
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        wr = np.clip((xx - (xc - 6.0)) / 12.0, 0.0, 1.0)[..., None].copy()
        # optional row bands that take one side only (e.g. ground that would
        # otherwise copy a tree or a path end from the other side)
        for y0b, y1b, side in t.get("bands", []):
            wr[y0b:y1b] = 0.0 if side == "left" else 1.0
        fill = left * (1.0 - wr) + right * wr
        m = np.zeros((h, w), bool)
        m[y0:y1, x0:x1] = True
        # stone and roof only (not grass/foliage), grown 2 px to take the outline
        m &= ndi.binary_dilation(~green, iterations=2) | ~green
        # a kept tower in front stays: its roof (red) and its body below the roof
        r_, g_, b_ = img[..., 0].astype(int), img[..., 1].astype(int), img[..., 2].astype(int)
        roof = ndi.binary_dilation((r_ > g_ + 35) & (r_ > b_ + 45), iterations=2)
        for kb in keep_boxes:
            sub = np.zeros((h, w), bool)
            sub[kb[1]:kb[3], kb[0]:kb[2]] = True
            body = np.zeros((h, w), bool)
            body[kb[1] + 48:kb[3], kb[0]:kb[2]] = True
            m &= ~(sub & (roof | body))
        for eb in t.get("protect", []):
            m[eb[1]:eb[3], eb[0]:eb[2]] = False
        soft = ndi.gaussian_filter(m.astype(np.float32), 1.0)[..., None]
        soft = np.maximum(soft, m[..., None].astype(np.float32) * 0.0)
        a = a * (1.0 - soft) + fill * soft
    return np.clip(a, 0, 255).astype(np.uint8)


def passage_rgb(lab):
    from skimage.color import lab2rgb
    return lab2rgb(np.array([[lab]], float))[0, 0] * 255.0


def foot_y(seg, x):
    (ax, ay), (bx, by) = seg
    if abs(bx - ax) < 1e-6:
        return max(ay, by)
    t = (x - ax) / (bx - ax)
    return ay + (by - ay) * t


def main():
    root = sys.argv[1]
    debug = sys.argv[sys.argv.index("--debug") + 1] if "--debug" in sys.argv else None
    sheet = sys.argv[sys.argv.index("--sheet") + 1] if "--sheet" in sys.argv else None
    cfg = load_cfg()
    art_dir = os.path.join(root, "art", "world", "crosshaven_city")
    data_dir = os.path.join(root, "data", "world", "crosshaven_city")
    src = np.asarray(Image.open(os.path.join(art_dir, cfg["source"])).convert("RGB"))
    ih, iw = src.shape[:2]
    PW, PH = iw * UP, ih * UP

    def arg_or_cfg(flag, key):
        if flag in sys.argv:
            return sys.argv[sys.argv.index(flag) + 1]
        v = cfg.get(key)
        return os.path.join(art_dir, v) if v else None

    # HD source (Grok's 5120x2880 repaint, 1:1 with the plate): used as is, no
    # upscaling. The geometry stays in image px; the masks read it at 1/4.
    hd_full_path = arg_or_cfg("--hd", "hd_full")
    hd_walls_path = arg_or_cfg("--hd-walls", "hd_walls")
    hd_full = hd_walls = None
    if hd_full_path:
        hd_full = np.asarray(Image.open(hd_full_path).convert("RGB"))
        assert hd_full.shape[:2] == (PH, PW), "HD source must be %dx%d" % (PW, PH)
    if hd_walls_path:
        hd_walls = np.asarray(Image.open(hd_walls_path).convert("RGBA"))
        assert hd_walls.shape[:2] == (PH, PW), "HD walls layer must be %dx%d" % (PW, PH)

    def upscale(a):
        im_ = Image.fromarray(a).resize((PW, PH), Image.LANCZOS)
        return im_.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))

    if hd_full is not None:
        clean = np.asarray(Image.fromarray(hd_full).resize((iw, ih), Image.LANCZOS))
        if not cfg.get("hd_towers_removed", True):
            clean = remove_towers(clean, cfg)
        full = hd_full.copy() if cfg.get("hd_towers_removed", True) else np.asarray(upscale(clean)).copy()
    else:
        clean = remove_towers(src, cfg)
        full = np.asarray(upscale(clean)).copy()
    if sheet:
        Image.fromarray(clean).save(sheet, quality=92)

    # ---- portcullis: the grate is cut out of the plate into its own sprite;
    # behind it the passage is the arch's own dark pixels with the bars taken
    # out (a min filter over the opening), in the image and in the plate
    full_orig = full.copy()
    clean = clean.copy()
    portcullis = {}

    def gate_foot(g):
        """The gate's wall foot line under its arch (the grate sorts just in front of it)."""
        ax_, ay_ = g["arch"]
        best = None
        for w_ in cfg["walls"]:
            xa_, xb_ = sorted([w_["a"][0], w_["b"][0]])
            if xa_ - 2 <= ax_ <= xb_ + 2:
                fy_ = foot_y((tuple(w_["a"]), tuple(w_["b"])), ax_)
                if best is None or abs(fy_ - ay_) < abs(best - ay_):
                    best = fy_
        return ay_ if best is None else best
    hd_pc_dir = arg_or_cfg("--hd-portcullis", "hd_portcullis")
    hd_pc = json.load(open(os.path.join(hd_pc_dir, "portcullis_positions.json"))) if hd_pc_dir else {}
    for g in cfg["gates"]:
        if g["id"] in hd_pc:
            q = hd_pc[g["id"]]
            spr = Image.open(os.path.join(hd_pc_dir, "portcullis_%s_CONCEPTO.png" % g["id"])).convert("RGBA")
            assert spr.size == (q["w"], q["h"]), "portcullis %s size" % g["id"]
            os.makedirs(os.path.join(art_dir, "gates"), exist_ok=True)
            name = "gates/portcullis_%s.png" % g["id"]
            spr.save(os.path.join(art_dir, name), optimize=True)
            sa = np.asarray(spr)[..., 3] > 20
            from skimage.morphology import convex_hull_image
            op_hd = convex_hull_image(sa) if sa.any() else np.ones_like(sa)
            mask_name = "gates/portcullis_%s_opening.png" % g["id"]
            Image.fromarray((op_hd * 255).astype(np.uint8), "L").save(os.path.join(art_dir, mask_name), optimize=True)
            ys_, xs_ = np.nonzero(op_hd)
            portcullis[g["id"]] = {"file": name, "opening": mask_name, "x": q["x"], "y": q["y"], "w": q["w"], "h": q["h"],
                                   "source": "Grok HD kit6",
                                   "opening_top_px": float(q["y"] + ys_.min()),
                                   "sort_y": round(float(max(q["y"] + ys_.max(), gate_foot(g) * UP) + UP * 2), 1),
                                   "foot": [round(float(q["x"] + xs_.mean()), 1), round(float(q["y"] + ys_.max()), 1)]}
            continue
        if not g.get("portcullis_box"):
            continue
        x0, y0, x1, y1 = g["portcullis_box"]
        crop = clean[y0:y1, x0:x1].astype(np.float32)
        lum = crop.mean(axis=2)
        dark = lum < np.percentile(lum, 55)
        op = ndi.binary_closing(dark, iterations=2)
        op = ndi.binary_fill_holes(op)
        lab_, n_ = ndi.label(op)
        if n_ > 1:
            sizes = ndi.sum(op, lab_, range(1, n_ + 1))
            op = lab_ == (1 + int(np.argmax(sizes)))
        op = ndi.binary_fill_holes(ndi.binary_closing(op, iterations=1))
        # an arch opening is convex: the hull takes in bars the threshold missed
        from skimage.morphology import convex_hull_image
        op = convex_hull_image(op)
        # plate res opening, bars (brighter than the passage) as the grate alpha
        P0, P1 = (x0 * UP, y0 * UP), (x1 * UP, y1 * UP)
        op_up = np.asarray(Image.fromarray((op * 255).astype(np.uint8)).resize((P1[0] - P0[0], P1[1] - P0[1]), Image.BILINEAR)) / 255.0
        fc = full_orig[P0[1]:P1[1], P0[0]:P1[0]].astype(np.float32)
        fl = fc.mean(axis=2)
        lo, hi = np.percentile(fl[op_up > 0.5], 25), np.percentile(fl[op_up > 0.5], 80)
        bars = np.clip((fl - lo) / max(1.0, hi - lo), 0.0, 1.0)
        bars = ndi.gaussian_filter(bars, 0.8)
        inner = ndi.gaussian_filter(ndi.binary_erosion(op_up > 0.5, iterations=UP).astype(np.float32), 1.0)
        alpha = np.clip((bars - 0.3) * 2.5, 0.0, 1.0) * inner
        # round 19 (Mauro: the gates read too dark): the passage behind the
        # grate is warm mid-tone stone, lighter at the mouth (bottom), darker
        # deeper in (top), keeping a little of the arch's own texture
        pcfg = cfg.get("passage", {})
        deep = passage_rgb(pcfg.get("deep_lab", [30.0, 5.0, 14.0]))
        mouth = passage_rgb(pcfg.get("mouth_lab", [40.0, 6.0, 17.0]))
        tex = np.stack([ndi.minimum_filter(fc[..., c], size=5 * UP) for c in range(3)], -1)
        tex = ndi.gaussian_filter(tex.mean(axis=2), UP)
        tex = (tex - tex[op_up > 0.5].mean())[..., None] * float(pcfg.get("texture", 0.9))
        oy_, ox_ = np.nonzero(op_up > 0.5)
        ty = np.clip((np.arange(fc.shape[0]) - oy_.min()) / max(1.0, float(oy_.max() - oy_.min())), 0.0, 1.0)
        grad = deep[None, None, :] * (1.0 - ty[:, None, None]) + mouth[None, None, :] * ty[:, None, None]
        # depth: a little darker towards the sides of the opening
        side = ndi.distance_transform_edt(op_up > 0.5)
        side = np.clip(side / max(1.0, float(side.max()) * 0.6), 0.0, 1.0)[..., None]
        passage = np.clip((grad + tex) * (0.82 + 0.18 * side), 0, 255) * np.ones_like(fc)
        m3 = op_up[..., None]
        # the voussoirs: a soft lighter rim just outside the opening
        ring = ndi.gaussian_filter((ndi.binary_dilation(op_up > 0.5, iterations=3 * UP) & ~(op_up > 0.5)).astype(np.float32), UP * 0.8)
        lift_ = float(pcfg.get("rim_lift", 0.16))
        fc_rim = np.clip(fc * (1.0 + lift_ * ring[..., None]) + 10.0 * ring[..., None], 0, 255)
        full[P0[1]:P1[1], P0[0]:P1[0]] = (fc_rim * (1 - m3) + passage * m3).astype(np.uint8)
        small = np.asarray(Image.fromarray(full[P0[1]:P1[1], P0[0]:P1[0]]).resize((x1 - x0, y1 - y0), Image.LANCZOS))
        clean[y0:y1, x0:x1] = small
        name = "gates/portcullis_%s.png" % g["id"]
        os.makedirs(os.path.join(art_dir, "gates"), exist_ok=True)
        # the grate: a little brighter, with a highlight on the bars' upper-left edges
        hl = np.clip(alpha - ndi.shift(alpha, (UP * 0.6, UP * 0.6), order=1, mode="nearest"), 0.0, 1.0)
        bright = float(pcfg.get("grate_gain", 1.25))
        grate = np.clip(fc * bright + 12.0 + hl[..., None] * float(pcfg.get("grate_highlight", 70.0)), 0, 255)
        Image.fromarray(np.dstack([grate.astype(np.uint8), (alpha * 255).astype(np.uint8)]), "RGBA").save(os.path.join(art_dir, name), optimize=True)
        mask_name = "gates/portcullis_%s_opening.png" % g["id"]
        Image.fromarray((np.clip(op_up, 0, 1) * 255).astype(np.uint8), "L").save(os.path.join(art_dir, mask_name), optimize=True)
        oy, ox = np.nonzero(op)
        portcullis[g["id"]] = {"file": name, "opening": mask_name, "x": P0[0], "y": P0[1], "w": P1[0] - P0[0], "h": P1[1] - P0[1],
                               "opening_top_px": round(float((y0 + oy.min()) * UP), 1),
                               "sort_y": round(float(max(y0 + oy.max(), gate_foot(g)) * UP + UP * 2), 1),
                               "foot": [round(float((x0 + ox.mean()) * UP), 1), round(float((y0 + oy.max()) * UP), 1)]}

    # the layers take their pixels from the full image
    g_np = full
    stone_hd = None
    occl_hd = None
    if hd_full is not None:
        occl_hd = np.zeros((PH, PW), np.float32)
        stone_hd = ndi.gaussian_filter((~green_mask(hd_full) & ~water_mask(hd_full)).astype(np.float32), 0.7)
    occl = np.zeros((ih, iw), bool)

    # ---- masks (image px)
    green = green_mask(clean)
    water = ndi.binary_opening(water_mask(clean), iterations=1)
    path = path_mask(clean)
    yy, xx = np.mgrid[0:ih, 0:iw]
    segs = [(tuple(s["a"]), tuple(s["b"]), s) for s in cfg["walls"]]
    # the ring polygon: where each wall's foot line meets the next one (walls
    # are listed in ring order), so inside/outside follows the blocking band
    ring_poly = []
    for (a1, b1, _), (a2, b2, _) in zip(segs, segs[1:] + segs[:1]):
        (x1_, y1_), (x2_, y2_) = a1, b1
        (x3_, y3_), (x4_, y4_) = a2, b2
        den = (x1_ - x2_) * (y3_ - y4_) - (y1_ - y2_) * (x3_ - x4_)
        if abs(den) < 1e-9:
            ring_poly.append(((x2_ + x3_) / 2.0, (y2_ + y3_) / 2.0))
            continue
        t_ = ((x1_ - x3_) * (y3_ - y4_) - (y1_ - y3_) * (x3_ - x4_)) / den
        ring_poly.append((x1_ + t_ * (x2_ - x1_), y1_ + t_ * (y2_ - y1_)))

    # ---- layers
    old = json.load(open(os.path.join(data_dir, "layers.json")))
    lay_dir = os.path.join(art_dir, "layers")
    for rec in old["layers"]:
        f = os.path.join(art_dir, rec["file"])
        if rec["file"].startswith("layers/") and os.path.exists(f):
            os.remove(f)
    out_layers = []
    lid = 9000

    def add_layer(alpha_img, box, tag, sort_y, extra=None):
        nonlocal lid
        x0, y0, x1, y1 = box
        occl[y0:y1, x0:x1] |= alpha_img[y0:y1, x0:x1] > 0.5
        px0, py0, px1, py1 = x0 * UP, y0 * UP, x1 * UP, y1 * UP
        al = Image.fromarray((alpha_img[y0:y1, x0:x1] * 255).astype(np.uint8)).resize((px1 - px0, py1 - py0), Image.BILINEAR)
        if tag == "wall":
            # strips butt against each other: soften only vertically, so no seam shows between them
            al = Image.fromarray(ndi.gaussian_filter(np.asarray(al).astype(np.float32), (1.2, 0.0)).astype(np.uint8))
        else:
            al = al.filter(ImageFilter.GaussianBlur(1.2))
        if stone_hd is not None:
            # HD: the cut follows the HD stone itself (sharp), inside the band
            # (grown one image px) and inside Grok's walls layer when there is one
            grown = ndi.binary_dilation(alpha_img[y0:y1, x0:x1] > 0.5, iterations=1)
            band_up = np.repeat(np.repeat(grown, UP, axis=0), UP, axis=1).astype(np.float32)
            a_hd = band_up * stone_hd[py0:py1, px0:px1]
            if hd_walls is not None:
                a_hd = a_hd * (hd_walls[py0:py1, px0:px1, 3] / 255.0)
            src_rgb = hd_walls[py0:py1, px0:px1, :3] if hd_walls is not None else g_np[py0:py1, px0:px1]
            rgba = np.dstack([src_rgb, (np.clip(a_hd, 0, 1) * 255).astype(np.uint8)])
            np.maximum(occl_hd[py0:py1, px0:px1], a_hd.astype(np.float32), out=occl_hd[py0:py1, px0:px1])
        elif hd_walls is not None:
            hw = hd_walls[py0:py1, px0:px1]
            rgba = np.dstack([hw[..., :3], np.minimum(np.asarray(al), hw[..., 3])])
        else:
            rgba = np.dstack([g_np[py0:py1, px0:px1], np.asarray(al)])
        if (rgba[..., 3] > 60).sum() < 40:
            return None
        im = Image.fromarray(rgba, "RGBA")
        name = "layers/%d_v4_%s.png" % (lid, tag)
        im.save(os.path.join(art_dir, name), optimize=True)
        rec = {"id": lid, "file": name, "tag": tag, "x": px0, "y": py0, "w": im.width, "h": im.height,
               "k": 1.0, "flip": False, "sort_y": round(sort_y * UP, 1), "under": False,
               "fade": im.height >= BC.FADE_MIN_HEIGHT, "fade_min_alpha": 0.45}
        if extra:
            rec.update(extra)
        if rec["fade"]:
            bw, bh, bits = BC.alpha_bits(im)
            rec["mask"] = {"step": BC.MASK_STEP, "w": bw, "h": bh, "bits": bits}
        out_layers.append(rec)
        lid += 1
        return rec

    stone = ~green & ~water
    stone = ndi.binary_opening(stone, iterations=1)
    kept = [t for t in cfg["towers"] if t.get("keep")]
    tower_any = np.zeros((ih, iw), bool)
    for t in kept:
        x0, y0, x1, y1 = t["box"]
        tower_any[y0:y1, x0:x1] = True
    # wall strips: per wall segment, columns of strip px, from the foot up the wall height
    strip = int(cfg.get("strip_px", 6))
    for (a, b, s) in segs:
        xa, xb = sorted([a[0], b[0]])
        hgt = float(s.get("height", cfg["wall_height"]))
        below = float(s.get("below", 3))
        for x0 in range(int(xa), int(math.ceil(xb)), strip):
            x1 = min(int(math.ceil(xb)), x0 + strip)
            if x1 <= x0:
                continue
            fy0, fy1 = foot_y((a, b), x0), foot_y((a, b), x1)
            top = int(min(fy0, fy1) - hgt)
            bot = int(math.ceil(max(fy0, fy1) + below))
            m = np.zeros((ih, iw), bool)
            band = (yy <= (foot_y((a, b), xx + 0.0) + below)) & (yy >= foot_y((a, b), xx + 0.0) - hgt)
            # one image px of overlap with the next strip: no sub-pixel seam between them
            x1e = min(int(math.ceil(xb)), x1 + 1)
            m[top:bot, x0:x1e] = band[top:bot, x0:x1e]
            m &= stone & ~tower_any
            if s.get("gate"):
                m &= ~path | (yy < foot_y((a, b), xx + 0.0) - 2)
            # the box reaches a little below the foot (transparent): the sprite
            # rect then covers the cells right in front of the wall
            add_layer(m.astype(np.float32), (x0, max(0, top), x1e, min(ih, bot + int(cfg.get("pad_below", 8)))), "wall",
                      foot_y((a, b), (x0 + x1) / 2.0), {"edge": s["id"]})
    for t in kept:
        x0, y0, x1, y1 = t["box"]
        m = np.zeros((ih, iw), bool)
        m[y0:y1, x0:x1] = True
        m &= stone | (~green & ~water)
        m &= ~(path & (yy > t["base"][1] - 4))
        add_layer(m.astype(np.float32), (x0, y0, x1, y1), "tower", t["base"][1],
                  {"tower_kind": t.get("kind", "wall"), "wall_point": [t["base"][0] * UP, t["base"][1] * UP],
                   "name": t["name"]})

    # ---- cells
    lay = json.load(open(os.path.join(data_dir, "city.json")))
    plate = lay["plate"]
    sc = float(plate["scale"])
    c0 = plate["cell00_px"]
    W, H = lay["grid"]["width"], lay["grid"]["height"]
    blocked = np.zeros((ih, iw), bool)
    for (a, b, s) in segs:
        xa, xb = sorted([a[0], b[0]])
        inx = (xx >= xa - 1) & (xx <= xb + 1)
        fy = foot_y((a, b), xx + 0.0)
        blocked |= inx & (yy <= fy + float(cfg.get("block_below", 3))) & (yy >= fy - float(cfg.get("block_depth", 14)))
    for t in kept + [t for t in cfg["towers"] if t.get("block_only")]:
        cx, cy = t["base"]
        rx = (t["box"][2] - t["box"][0]) * 0.5
        blocked |= ((xx - cx) / rx) ** 2 + ((yy - (cy - rx * 0.45)) / (rx * 0.5)) ** 2 <= 1.0
    for eb in cfg.get("block_boxes", []):
        blocked[eb[1]:eb[3], eb[0]:eb[2]] = True
    gate_open = np.zeros((ih, iw), bool)
    gate_masks = {}
    for g in cfg["gates"]:
        p, q = np.array(g["outside"], float), np.array(g["inside"], float)
        v = q - p
        L = np.linalg.norm(v)
        u = v / L
        rel_x, rel_y = xx - p[0], yy - p[1]
        t_ = rel_x * u[0] + rel_y * u[1]
        n_ = np.abs(rel_x * -u[1] + rel_y * u[0])
        gm = (t_ >= 0) & (t_ <= L) & (n_ <= float(g.get("half_width", 8)))
        gate_masks[g["id"]] = (gm, p, u)
        gate_open |= gm
    bridge_ok = np.zeros((ih, iw), bool)
    for br in cfg["bridges"]:
        x0, y0, x1, y1 = br["deck"]
        bridge_ok[y0:y1, x0:x1] = True
    # the deck is the bridge's own stone (not the river around it)
    bridge_ok &= ~water_mask(clean)
    wet = ndi.binary_dilation(water, iterations=1) & ~bridge_ok
    walk_blocked = (blocked & ~gate_open) | wet

    def cell_px(x, y):
        return (c0[0] + 32.0 * (x - y) / sc, c0[1] + 16.0 * (x + y) / sc)

    rows = []
    cell_of = {}
    for y in range(H):
        row = []
        for x in range(W):
            px, py = cell_px(x, y)
            ix, iy = int(px / UP), int(py / UP)
            if not (2 <= ix < iw - 2 and 2 <= iy < ih - 2):
                row.append(".")
                continue
            if walk_blocked[iy, ix]:
                row.append("~" if wet[iy, ix] else "#")
            elif bridge_ok[iy, ix] or path[iy, ix] or gate_open[iy, ix]:
                row.append("r")
            else:
                row.append("g")
            cell_of[(x, y)] = (ix, iy)
        rows.append("".join(row))
    grid_w = np.array([[c in "gr" for c in r] for r in rows])

    # ---- plots (houses hidden for now: the footprints are reserved and block).
    # Each Legendary ellipse (350 x 175 plate px, bottom point = anchor) sits on
    # grass only: no street, wall, tower or water under it.
    leg_rx = float(lay["plot_rules"]["clearance_px"]["legendary"]) / UP / 2.0
    leg_ry = leg_rx / 2.0
    # margins: a street px, a cell (water reads per cell), the wall band
    bad = ndi.binary_dilation(path, iterations=2) | ndi.binary_dilation(water, iterations=9) | ndi.binary_dilation(occl | blocked, iterations=3)
    ey, ex = np.mgrid[-int(leg_ry) - 1:int(leg_ry) + 2, -int(leg_rx) - 1:int(leg_rx) + 2]
    ell = (ex / leg_rx) ** 2 + (ey / leg_ry) ** 2 <= 1.0
    ey, ex = ey[ell], ex[ell]

    def plot_ok(ax, ay):
        cx, cy = ax, ay - leg_ry
        ys_, xs_ = (cy + ey).astype(int), (cx + ex).astype(int)
        if xs_.min() < 4 or ys_.min() < 4 or xs_.max() >= iw - 4 or ys_.max() >= ih - 4:
            return False
        return not bad[ys_, xs_].any()

    cell_list = list(cell_of.items())

    def front_for(ax, ay):
        """Two touching walkable cells right in front of the anchor."""
        best = None
        for (x, y), (cx, cy) in cell_list:
            if not grid_w[y, x]:
                continue
            dy_, dx_ = (cy - ay) * UP, abs(cx - ax) * UP
            if 4.0 < dy_ < 44.0 and dx_ < 36.0:
                d = dx_ + abs(dy_ - 24.0)
                if best is None or d < best[0]:
                    best = (d, (x, y))
        if best is None:
            return None
        x, y = best[1]
        for n2 in [(x + 1, y), (x, y + 1), (x - 1, y), (x, y - 1)]:
            if 0 <= n2[0] < W and 0 <= n2[1] < H and grid_w[n2[1], n2[0]]:
                return [list(best[1]), list(n2)]
        return None

    chosen = []
    cands = [(x_, y_) for y_ in range(10, ih - 10, 4) for x_ in range(10, iw - 10, 4)]
    for spot in cfg["plot_spots"]:
        order = sorted(cands, key=lambda c: (c[0] - spot[0]) ** 2 + (c[1] - spot[1]) ** 2)
        for ax, ay in order:
            if any(((ax - bx) ** 2 + ((ay - by) * 2.0) ** 2) ** 0.5 <= leg_rx * 2.0 + 4.0 for bx, by, _ in chosen):
                continue
            if not plot_ok(ax, ay):
                continue
            fr = front_for(ax, ay)
            if fr is None:
                continue
            chosen.append((ax, ay, fr))
            break
    foot = np.zeros((ih, iw), bool)
    for ax, ay, _ in chosen:
        foot |= ((xx - ax) / (leg_rx * 0.8)) ** 2 + ((yy - (ay - leg_ry)) / (leg_ry * 0.8)) ** 2 <= 1.0
    rows = ["".join(("#" if (ch in "gr" and foot[cell_of[(x, y)][1], cell_of[(x, y)][0]]) else ch)
                    for x, ch in enumerate(r)) for y, r in enumerate(rows)]
    # keep only the walkable component the spawn is in (no islands)
    grid_w = np.array([[c in "gr" for c in r] for r in rows])

    def nearest_cell(ix, iy, ok=None):
        best = None
        for (x, y), (cx, cy) in cell_of.items():
            if not grid_w[y, x] or (ok is not None and not ok(x, y)):
                continue
            d = (cx - ix) ** 2 + (cy - iy) ** 2
            if best is None or d < best[0]:
                best = (d, (x, y))
        return best[1]

    spawn = nearest_cell(*cfg["spawn"])
    lab, n = ndi.label(grid_w, structure=[[0, 1, 0], [1, 1, 1], [0, 1, 0]])
    main_c = lab[spawn[1], spawn[0]]
    rows = ["".join(("#" if (ch in "gr" and lab[y, x] != main_c) else ch) for x, ch in enumerate(r)) for y, r in enumerate(rows)]
    grid_w = np.array([[c in "gr" for c in r] for r in rows])
    exit_c = nearest_cell(*cfg["exit"])

    def cells_on(p, q, step=1.0):
        out = []
        p, q = np.array(p, float), np.array(q, float)
        n_ = int(np.linalg.norm(q - p) / step) + 1
        for k in range(n_ + 1):
            ix, iy = p + (q - p) * k / max(1, n_)
            c = nearest_cell(ix, iy)
            if c not in out:
                out.append(c)
        return out

    gates_out, gate_cells = [], []
    for g in cfg["gates"]:
        # every walkable cell in the passage corridor, outside to inside
        gm, p0, u0 = gate_masks[g["id"]]
        cells = [c for c, (ix, iy) in cell_of.items() if gm[iy, ix] and grid_w[c[1], c[0]]]
        cells.sort(key=lambda c: (cell_of[c][0] - p0[0]) * u0[0] + (cell_of[c][1] - p0[1]) * u0[1])
        rec = {"id": g["id"], "why": "ring v4 image", "arch": [g["arch"][0] * UP, g["arch"][1] * UP],
               "wall_join_left": [g["join_left"][0] * UP, g["join_left"][1] * UP],
               "wall_join_right": [g["join_right"][0] * UP, g["join_right"][1] * UP],
               "passage": [[g["outside"][0] * UP, g["outside"][1] * UP], [g["inside"][0] * UP, g["inside"][1] * UP]],
               "cells": [list(c) for c in cells]}
        if g["id"] in portcullis:
            pc = dict(portcullis[g["id"]])
            fx, fy = pc["foot"][0] / UP, pc["foot"][1] / UP
            # the cells under the arch: these block while the grate is down
            pc["block_cells"] = [list(c) for c in cells if (cell_of[c][0] - fx) ** 2 + (cell_of[c][1] - fy) ** 2 <= 9.0 ** 2]
            pc["open_s"] = 0.6
            pc["close_after_s"] = 1.5
            pc["trigger_hero_heights"] = 3.0
            rec["portcullis"] = pc
        if g["id"] == "S":
            gate_cells = [list(c) for c in cells]
        gates_out.append(rec)
    bridges = []
    for br in cfg["bridges"]:
        x0, y0, x1, y1 = br["deck"]
        deck = [list(c) for c, (ix, iy) in cell_of.items() if x0 <= ix < x1 and y0 <= iy < y1 and grid_w[c[1], c[0]]
                and wet[max(0, iy - 12):iy + 12, max(0, ix - 12):ix + 12].any()]
        ends = [list(nearest_cell(*br["ends"][0])), list(nearest_cell(*br["ends"][1]))]
        bridges.append({"id": br["id"], "ends": ends, "deck_cells": sorted(deck), "crown_px": 0.0,
                        "sprite_bbox": [x0 * UP, y0 * UP, x1 * UP, y1 * UP]})
    npcs = []
    used = set()
    inside_poly = ring_poly

    def in_poly(pt):
        x_, y_ = pt
        c_ = False
        for (x1_, y1_), (x2_, y2_) in zip(inside_poly, inside_poly[1:] + inside_poly[:1]):
            if (y1_ > y_) != (y2_ > y_) and x_ < x1_ + (y_ - y1_) * (x2_ - x1_) / (y2_ - y1_):
                c_ = not c_
        return c_
    for k, n_ in enumerate(lay["npcs"]):
        tgt = cfg["npc_spots"][k % len(cfg["npc_spots"])]
        c = nearest_cell(*tgt, ok=lambda x, y: (x, y) not in used and in_poly(cell_of[(x, y)]))
        used.add(c)
        n2 = dict(n_)
        n2["cell"] = {"x": int(c[0]), "y": int(c[1])}
        npcs.append(n2)
    stubs = []
    for st in lay["gate_stubs"]:
        st = json.loads(json.dumps(st))
        if st["id"] == "crossroads_to_city":
            st["to"]["x"], st["to"]["y"] = spawn
        elif st["id"] == "city_to_crossroads":
            st["from"]["x"], st["from"]["y"] = exit_c
        elif st.get("gate"):
            g = next(g for g in cfg["gates"] if g["id"] == st["gate"])
            c = nearest_cell(*g["road_end"])
            st["from"]["x"], st["from"]["y"] = c
        stubs.append(st)
    plots = []
    for p, (ax, ay, fr) in zip(lay["plots"], chosen):
        p2 = dict(p)
        p2["anchor_px"] = [ax * UP, ay * UP]
        p2["front_cells"] = fr
        plots.append(p2)
    if len(plots) < len(lay["plots"]):
        print("WARNING: only", len(plots), "plots fit")

    # the ground behind every wall and tower is filled in from around it, so the
    # local fade (hero behind a wall) shows ground, not the wall again
    import cv2
    # only the solid core is filled in: the layers' soft edges sit over the original pixels
    hole = ndi.binary_erosion(occl, iterations=1).astype(np.uint8) * 255
    behind = cv2.inpaint(np.ascontiguousarray(clean[..., ::-1]), hole, 7, cv2.INPAINT_TELEA)[..., ::-1]
    occ_up = np.asarray(Image.fromarray(hole).resize((PW, PH), Image.BILINEAR)).astype(np.float32)[..., None] / 255.0
    if occl_hd is not None:
        # HD: fill in only under the layers' solid pixels; everywhere else the
        # ground keeps Grok's own pixels (nothing smeared shows at a layer edge)
        solid = ndi.binary_erosion(occl_hd > 0.98, iterations=2)
        occ_up = ndi.gaussian_filter(solid.astype(np.float32), 0.8)[..., None]
        small = np.asarray(Image.fromarray((solid * 255).astype(np.uint8)).resize((iw, ih), Image.BILINEAR)) > 40
        hole = ndi.binary_dilation(small, iterations=1).astype(np.uint8) * 255
        behind = cv2.inpaint(np.ascontiguousarray(clean[..., ::-1]), hole, 7, cv2.INPAINT_TELEA)[..., ::-1]
    ground = Image.fromarray((full * (1.0 - occ_up) + np.asarray(upscale(np.ascontiguousarray(behind))) * occ_up).astype(np.uint8))
    # leak audit (as the tests): from inside, gates shut, nothing outside is reached
    gate_set = {tuple(c) for g in gates_out for c in g["cells"]}
    start = tuple(bridges[0]["ends"][0])
    seen_, stack_, leaks_ = {start}, [start], []
    while stack_:
        cx_, cy_ = stack_.pop()
        for dx_, dy_ in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n_ = (cx_ + dx_, cy_ + dy_)
            if n_ in seen_ or n_ in gate_set or not (0 <= n_[0] < W and 0 <= n_[1] < H) or not grid_w[n_[1], n_[0]]:
                continue
            seen_.add(n_)
            if not in_poly(cell_of[n_]):
                leaks_.append(cell_of[n_])
                continue
            stack_.append(n_)
    print("inside cells", len(seen_), "leaks", len(leaks_), leaks_[:12])
    ground.save(os.path.join(art_dir, "ground.jpg"), quality=90)
    ground.resize((PW // 2, PH // 2), Image.LANCZOS).save(os.path.join(art_dir, "ground_lite.jpg"), quality=88)
    city = {}
    for k in ["format", "format_version", "zone_id", "region", "name", "status"]:
        city[k] = lay[k]
    city["source"] = "Mauro's ring v4 concept (" + cfg["source"] + "), towers painted out to the keep list"
    if hd_full is not None:
        city["source"] = "Grok HD ring v4 (docs/pc-map-handoff work/walls/kit6: %s%s%s), 1:1 with the plate" % (
            os.path.basename(hd_full_path), ", " + os.path.basename(hd_walls_path) if hd_walls_path else "",
            ", portcullis sprites" if hd_pc else "")
        if "--hd-ref" in sys.argv:
            city["source"] += " @ " + sys.argv[sys.argv.index("--hd-ref") + 1]
    plate = dict(plate)
    plate["fit"] = {"residuals": [], "note": "image plate: the cells keep the zone's lattice (cell00_px)"}
    plate["size"] = [PW, PH]
    plate["source_image_px"] = [iw, ih]
    plate["image_to_plate"] = UP
    city["plate"] = plate
    city["grid"] = {"width": W, "height": H, "legend": lay["grid"]["legend"], "rows": rows, "heights": [], "height_px_per_step": 10}
    city["spawn"] = list(spawn)
    city["exit_cell"] = list(exit_c)
    city["gate_cells"] = gate_cells
    city["wall_polygon"] = [[round(p[0] * UP, 1), round(p[1] * UP, 1)] for p in ring_poly]
    city["trees_keep"] = {}
    city["map_base_only"] = lay["map_base_only"]
    city["wall_ring"] = {"source": "image", "towers_kept": len(kept),
                         "towers_removed": [t["name"] for t in cfg["towers"] if not t.get("keep")],
                         "note": "Round 18: Mauro's ring v4 image is the plate; walls and kept towers are cut from it as y-sorted layers."}
    city["building_footprints"] = []
    city["wall_contacts"] = {"before": [], "after": []}
    city["gates"] = gates_out
    city["bridges"] = bridges
    city["plots"] = plots
    city["plot_rules"] = lay["plot_rules"]
    city["pets"] = []
    city["npcs"] = npcs
    city["day_hours"] = lay["day_hours"]
    city["gate_stubs"] = stubs
    city["layers"] = "layers.json"
    city["water"] = {}
    city["lights"] = {"on_from_hour": 16.0, "off_at_hour": 7.0,
                      "gate_glow": {"tint": [1.0, 0.72, 0.42], "radius_px": 170.0, "alpha": 0.95, "energy": 1.4, "lift_px": 30.0},
                      "note": "Round 19: no lamp layers on the image plate; a warm glow at each gate mouth by night."}
    city["water_gates"] = [{"id": w_["id"], "at": [w_["at"][0] * UP, w_["at"][1] * UP],
                            "flank_towers": [[t["base"][0] * UP, t["base"][1] * UP] for t in kept if t["name"] in w_["flanks"]]}
                           for w_ in cfg["water_gates"]]
    json.dump(city, open(os.path.join(data_dir, "city.json"), "w"), indent=1)
    json.dump({"format": "stasium.plate_layers", "format_version": 1, "layers": out_layers},
              open(os.path.join(data_dir, "layers.json"), "w"), separators=(",", ":"))
    st_ = np.asarray(Image.fromarray((path * 255).astype(np.uint8)).resize((PW // 4, PH // 4), Image.BILINEAR))
    Image.fromarray(st_).save(os.path.join(data_dir, "streets.png"), optimize=True)
    print("layers", len(out_layers), "towers kept", len(kept), "spawn", spawn, "exit", exit_c,
          "walkable", int(grid_w.sum()), "gates", [(g["id"], len(g["cells"])) for g in gates_out],
          "bridges", [(b["id"], len(b["deck_cells"]), b["ends"]) for b in bridges])
    if debug:
        os.makedirs(debug, exist_ok=True)
        ov = clean.copy()
        ov[walk_blocked] = (ov[walk_blocked] * 0.4 + np.array([220, 30, 30]) * 0.6).astype(np.uint8)
        ov[gate_open] = (ov[gate_open] * 0.4 + np.array([30, 220, 30]) * 0.6).astype(np.uint8)
        im = Image.fromarray(ov).resize((iw * 2, ih * 2), Image.NEAREST)
        from PIL import ImageDraw
        d = ImageDraw.Draw(im)
        for (x, y), (ix, iy) in cell_of.items():
            if rows[y][x] in "gr":
                d.point((ix * 2, iy * 2), fill=(255, 255, 0))
        for p_ in [spawn, exit_c]:
            ix, iy = cell_of[tuple(p_)]
            d.ellipse([ix * 2 - 5, iy * 2 - 5, ix * 2 + 5, iy * 2 + 5], outline=(255, 0, 255), width=2)
        im.save(os.path.join(debug, "cells.png"))


if __name__ == "__main__":
    main()
