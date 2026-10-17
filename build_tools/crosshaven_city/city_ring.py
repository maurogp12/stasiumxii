"""Wall ring assembler for the plate city (coordinator, 17 Oct: wall kit v2).

The ring is laid on the three plate directions only: the two iso diagonals
(slope +-0.5) and horizontal runs for the N and S sides. Every piece is a
painted module from data (`ring_kit.modules` in the layout): file, native
anchors (base line, arch, wall joins), the side that sorts behind a hero in
the arch, and its scale (module px per plate px = hero plate px / hero px the
art was painted at). Swapping in final art is a data change.

Assembly per edge:
* towers at every corner and every `tower_every_wall_heights` along an edge;
* gatehouses at the layout's gates, water gates where the river crosses;
* the runs between them tiled with the segment module for the edge's
  direction, each copy sheared to the exact slope and butted, then cut into
  64 px strips sorted on the wall line under them.

The walk follows: the old ring's band is opened inside the new ring, the area
that left the city becomes outside (roads only), the new band, towers and
gatehouse footprints block, and each gate gets a passage 2+ hero widths wide.
"""
import math
import os

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

import city_gates as CG

STRIP = 64


def edge_slope(a, b):
    return 0.0 if abs(b[0] - a[0]) < 1e-6 else (b[1] - a[1]) / (b[0] - a[0])


def line_y(a, b, x):
    t = 0.0 if abs(b[0] - a[0]) < 1e-6 else (x - a[0]) / (b[0] - a[0])
    return a[1] + (b[1] - a[1]) * t


def iso_normal(a, b, inward):
    """Screen direction of the ground-perpendicular to edge a-b, pointing inward."""
    sx, sy = b[0] - a[0], b[1] - a[1]
    gx, gy = sx / 2.0 + sy, sy - sx / 2.0
    px, py = -gy, gx
    ux, uy = px - py, (px + py) / 2.0
    n = math.hypot(ux, uy)
    u = (ux / n, uy / n)
    if u[0] * inward[0] + u[1] * inward[1] < 0:
        u = (-u[0], -u[1])
    return u


class Module:
    def __init__(self, kit_dir, spec, scale):
        self.spec = spec
        self.file = spec["file"]
        im = Image.open(os.path.join(kit_dir, spec["file"])).convert("RGBA")
        if "keep_x" in spec:
            # round 15: keep only these columns (a gatehouse's curtain, without
            # its painted towers), with a soft 4 px alpha edge
            x0k, x1k = [int(v) for v in spec["keep_x"]]
            ar = np.array(im)
            cols = np.arange(ar.shape[1])
            ramp = np.clip(np.minimum(cols - x0k, x1k - cols) / 4.0, 0.0, 1.0)
            ar[..., 3] = (ar[..., 3].astype(np.float32) * ramp[None, :]).astype(np.uint8)
            im = Image.fromarray(ar, "RGBA")
        for bx0, by0, bx1, by1 in spec.get("erase_boxes", []):
            ar = np.array(im)
            ar[int(by0):int(by1), int(bx0):int(bx1), 3] = 0
            im = Image.fromarray(ar, "RGBA")
        self.feet_level_px = None
        if "curtain_level" in spec:
            im, self.feet_level_px = curtain_level(im, spec["curtain_level"])
        if "taper" in spec:
            im = taper(im, spec["taper"])
        if "foot_ao" in spec:
            im = foot_ao(im, spec["foot_ao"])
        if "recolor" in spec:
            im = lab_transfer(im, spec["recolor"], kit_dir)
        self.k = scale * float(spec.get("scale_mul", 1.0))
        self.im = im.resize((max(1, int(round(im.width * self.k))), max(1, int(round(im.height * self.k)))), Image.LANCZOS)
        self.slope = float(spec.get("art_slope", 0.0))

    def p(self, key):
        v = self.spec[key]
        return (float(v[0]) * self.k, float(v[1]) * self.k)

    def sheared(self, slope):
        """Image sheared so the art's base slope becomes `slope`; returns (image, map_fn)."""
        kk = slope - self.slope
        im, off = CG.shear_sprite(self.im, kk, False)
        return im, (lambda pt: (pt[0], pt[1] + kk * pt[0] + off))


_REF_STATS = {}
## Round 11: measured mean chroma of each recoloured module vs the reference.
CHROMA_LOG = {}


def _stone(lab):
    """Stone pixels: lit enough and warm (not water, arch shadow or banners)."""
    return (lab[..., 0] > 30.0) & (lab[..., 2] > 8.0)


def lab_transfer(im, rc, kit_dir):
    """Round 10: LAB mean/std colour transfer to the reference stone (opaque
    pixels in rc["ref_box"] of rc["ref"]). Recolour only."""
    from skimage import color
    key = (rc["ref"], tuple(rc["ref_box"]))
    if key not in _REF_STATS:
        ref = np.asarray(Image.open(os.path.join(kit_dir, rc["ref"])).convert("RGBA")).astype(np.float32) / 255.0
        x0, y0, x1, y1 = rc["ref_box"]
        sub = ref[y0:y1, x0:x1]
        m = sub[..., 3] > 0.9
        lab = color.rgb2lab(sub[..., :3][m].reshape(-1, 1, 3)).reshape(-1, 3)
        lab = lab[_stone(lab)]
        _REF_STATS[key] = (lab.mean(0), lab.std(0), float(np.hypot(lab[:, 1], lab[:, 2]).mean()))
    rm, rs, rc_chroma = _REF_STATS[key]
    a = np.asarray(im).astype(np.float32) / 255.0
    m = a[..., 3] > 0.5
    allpx = color.rgb2lab(a[..., :3])
    # stats over stone only (not the dark arch, water or ivy shadows)
    sel = m & _stone(allpx)
    lab = allpx[sel]
    sm, ss = lab.mean(0), lab.std(0)
    # lightness: mean and spread (clamped); colour (a*, b*): mean only, so
    # the art's own shading keeps its hue range
    kl = float(np.clip(rs[0] / max(ss[0], 1e-3), float(rc.get("l_std_min", 0.85)), float(rc.get("l_std_max", 1.15))))
    out = allpx.copy()
    out[..., 0] = (allpx[..., 0] - sm[0]) * kl + rm[0]
    out[..., 1] = allpx[..., 1] - sm[1] + rm[1]
    out[..., 2] = allpx[..., 2] - sm[2] + rm[2]
    # round 11: clamp the chroma to the reference's mean chroma (hue kept)
    ch = np.hypot(out[..., 1], out[..., 2])
    c_now = float(ch[sel].mean())
    if c_now > 1e-3:
        k = rc_chroma / c_now
        out[..., 1] *= k
        out[..., 2] *= k
    rgb = np.clip(color.lab2rgb(out), 0, 1)
    # only warm pixels take the stone colour: water and other cool parts of the
    # art keep their own (soft ramp on b*)
    w = np.clip((allpx[..., 2] - 2.0) / 10.0, 0.0, 1.0)[..., None]
    rgb = rgb * w + a[..., :3] * (1.0 - w)
    res = a.copy()
    res[..., :3] = rgb
    chk = color.rgb2lab(rgb[sel].reshape(-1, 1, 3)).reshape(-1, 3)
    CHROMA_LOG[rc.get("_name", "?")] = {"chroma": round(float(np.hypot(chk[:, 1], chk[:, 2]).mean()), 2),
                                       "ref_chroma": round(rc_chroma, 2),
                                       "L": round(float(chk[:, 0].mean()), 2), "ref_L": round(float(rm[0]), 2)}
    return Image.fromarray((res * 255.0 + 0.5).astype(np.uint8), "RGBA")


def curtain_level(im, c):
    """Round 15: lift the curtain columns (between a gatehouse's plinths) so
    the curtain's foot sits on the line through the two plinth bottoms (the
    towers stood above the curtain and road). Column shifts only. Returns the
    image and the largest remaining offset (art px)."""
    a = np.array(im)
    al = a[..., 3] > 128
    x0, x1 = [int(v) for v in c["x"]]
    e0, e1 = [int(v) for v in c.get("exclude", [0, 0])]
    (fx0, fy0), (fx1, fy1) = c["feet"]
    line = lambda x: fy0 + (fy1 - fy0) * (x - fx0) / float(fx1 - fx0)
    xs, bs = [], []
    for x in range(x0, x1):
        if e0 <= x < e1:
            continue
        r = np.nonzero(al[:, x])[0]
        if len(r):
            xs.append(x)
            bs.append(r.max())
    if len(xs) < 4:
        return im, None
    fit = np.polyfit(xs, bs, 1)
    out = a.copy()
    H = a.shape[0]
    for x in range(x0, x1):
        d = int(round(np.polyval(fit, x) - line(x)))
        if d > 0:
            out[:H - d, x] = a[d:, x]
            out[H - d:, x, 3] = 0
        elif d < 0:
            out[-d:, x] = a[:H + d, x]
            out[:-d, x, 3] = 0
    al2 = out[..., 3] > 128
    res = []
    for x in xs:
        r = np.nonzero(al2[:, x])[0]
        if len(r):
            res.append(r.max() - line(x))
    resid = float(np.polyval(np.polyfit(xs, res, 1), [x0, x1]).__abs__().max()) if res else None
    return Image.fromarray(out, "RGBA"), resid


def foot_ao(im, c):
    """Round 15: darken the bottom of every column (the foot of a wall face or
    a plinth) by up to c["dark"], fading to 0 over c["band_px"] (native px)."""
    a = np.array(im).astype(np.float32)
    al = a[..., 3] > 40
    H, W = al.shape
    band = float(c["band_px"])
    dark = float(c.get("dark", 0.35))
    rows = np.arange(H, dtype=np.float32)
    for x in range(W):
        r = np.nonzero(al[:, x])[0]
        if not len(r):
            continue
        foot = float(r.max())
        t = np.clip((rows - (foot - band)) / band, 0.0, 1.0)
        k = 1.0 - dark * t * t
        a[:, x, :3] *= k[:, None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def taper(im, t):
    """Round 8: the kit's wall face is painted with a little perspective (the
    merlon line is not parallel to the foot), so a run cut at a tower showed
    a step. Scale each column about the foot line so the merlon line runs
    parallel to the foot at a face height of `t["face"]` (native px).
    t: {"foot": [x0, y0, slope], "tip": [x0, y0, slope], "face": px}."""
    from scipy.ndimage import map_coordinates
    a = np.asarray(im).astype(np.float32)
    H, W = a.shape[:2]
    fx0, fy0, fs = [float(v) for v in t["foot"]]
    tx0, ty0, ts = [float(v) for v in t["tip"]]
    cols = np.arange(W, dtype=np.float32)
    foot = fy0 + fs * (cols - fx0)
    tip = ty0 + ts * (cols - tx0)
    face = np.maximum(1.0, foot - tip)
    ratio = face / float(t["face"])
    yy = np.arange(H, dtype=np.float32)[:, None]
    ysrc = foot[None, :] - (foot[None, :] - yy) * ratio[None, :]
    xsrc = np.broadcast_to(cols[None, :], (H, W))
    alpha = a[..., 3] / 255.0
    out = np.zeros_like(a)
    na = map_coordinates(alpha, [ysrc, xsrc], order=1, mode="constant", cval=0.0)
    for c in range(3):
        pm = map_coordinates(a[..., c] * alpha, [ysrc, xsrc], order=1, mode="constant", cval=0.0)
        out[..., c] = np.where(na > 1e-4, pm / np.maximum(na, 1e-4), 0.0)
    out[..., 3] = na * 255.0
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def gate_half(kit_dir, cfg, mods_scale, a, b):
    """Half the distance between a gatehouse's flanking tower feet on edge a-b (plate px)."""
    sl = edge_slope(a, b)
    key = "gatehouse" + ("_flat" if abs(sl) < 0.05 else ("_pos" if sl > 0 else "_neg"))
    spec = cfg["modules"].get(key) or cfg["modules"]["gatehouse_neg"]
    kk = sl - float(spec.get("art_slope", 0.0))
    k = mods_scale * float(spec.get("scale_mul", 1.0))
    wl = (spec["wall_left"][0] * k, spec["wall_left"][1] * k + kk * spec["wall_left"][0] * k)
    wr = (spec["wall_right"][0] * k, spec["wall_right"][1] * k + kk * spec["wall_right"][0] * k)
    return math.dist(wl, wr) / 2.0


def snap_gates(cfg, poly, kit_dir, hero_plate):
    """Round 8: a gatehouse whose outer flanking tower stands within
    `snap_corner_tower_widths` tower widths of a ring corner slides along its
    edge so that tower sits on the corner (the gatehouse tower becomes the
    corner tower: no doubled tower, no gap). Returns (gates, log)."""
    k = hero_plate / float(cfg["hero_px_in_art"])
    lim = float(cfg.get("snap_corner_tower_widths", 0.0)) * float(cfg.get("gate_tower_width_art", 433.0)) * k
    out, log = [], []
    n = len(poly)
    for g in cfg["gates"]:
        g2 = dict(g)
        i = int(g["edge"])
        a, b = poly[i], poly[(i + 1) % n]
        L = math.dist(a, b)
        s = ((g["at"][0] - a[0]) * (b[0] - a[0]) + (g["at"][1] - a[1]) * (b[1] - a[1])) / L
        half = gate_half(kit_dir, cfg, k, a, b)
        sl_ = edge_slope(a, b)
        key_ = "gatehouse" + ("_flat" if abs(sl_) < 0.05 else ("_pos" if sl_ > 0 else "_neg"))
        lim_g = lim * float((cfg["modules"].get(key_) or {}).get("scale_mul", 1.0))
        new_s = s
        corner = None
        if lim > 0 and s - half < lim_g:
            new_s, corner = half, list(a)
        elif lim > 0 and (L - s) - half < lim_g:
            new_s, corner = L - half, list(b)
        if corner is not None:
            q = (a[0] + (b[0] - a[0]) * new_s / L, a[1] + (b[1] - a[1]) * new_s / L)
            g2["at"] = [round(q[0], 1), round(q[1], 1)]
            g2["snapped_to_corner"] = corner
            log.append({"id": g["id"], "from": list(g["at"]), "to": g2["at"], "corner": corner,
                        "moved_px": round(math.dist(g["at"], q), 1)})
        out.append(g2)
    return out, log


def _feat_ref(f, at, i):
    if f is None:
        return None
    p = at(i, f["s"])
    return {"kind": f["kind"], "at": [round(p[0], 1), round(p[1], 1)]}


def _measure_end(strips, end, a, b, span=320):
    """Foot and merlon-tip lines at a run end (plate px, relative to the edge
    line): the drawn strips' foot (topmost bottom, between buttresses) and
    merlon tips over the last `span` px of the run, each fitted with a line
    and read at the end, so one stone or buttress does not decide it."""
    from scipy.ndimage import minimum_filter1d
    xs, feet, tips = [], [], []
    for im, x0, y0 in strips:
        al = np.asarray(im)[..., 3] > 128
        for cc in range(al.shape[1]):
            gx = x0 + cc
            if abs(gx - end[0]) > span:
                continue
            rows = np.nonzero(al[:, cc])[0]
            if len(rows):
                xs.append(gx)
                feet.append(rows.max() + y0 - line_y(a, b, gx))
                tips.append(rows.min() + y0 - line_y(a, b, gx))
    if len(xs) < 8:
        return None
    o = np.argsort(xs)
    xs = np.array(xs, float)[o]
    # wider than a pilaster (their painted bases sit a few px lower)
    feet = minimum_filter1d(np.array(feet, float)[o], 90)
    tips = minimum_filter1d(np.array(tips, float)[o], 30)
    pf = np.polyfit(xs, feet, 1)
    pt = np.polyfit(xs, tips, 1)
    return {"foot": round(float(np.polyval(pf, end[0])), 1), "tip": round(float(np.polyval(pt, end[0])), 1)}


def pick(mods, kind, slope):
    """Module of `kind` for an edge slope: '_neg' (-0.5), '_pos' (+0.5), '_flat' (0); falls back to neg."""
    key = kind + ("_flat" if abs(slope) < 0.05 else ("_pos" if slope > 0 else "_neg"))
    return mods.get(key) or mods.get(kind + "_neg") or mods.get(kind)


def assemble(layers, images, walk, river, old_poly, poly, cfg, kit_dir, hero_plate, log, next_id=7000):
    mods = {}
    scale = hero_plate / float(cfg["hero_px_in_art"])
    rc = cfg.get("stone_recolor")
    for name, spec in cfg["modules"].items():
        if rc and name in rc.get("targets", []):
            spec = dict(spec, recolor=dict(rc, _name=name))
        mods[name] = Module(kit_dir, spec, scale)
    H_, W_ = walk.shape
    inside_old = CG.poly_mask(old_poly)
    inside_new = CG.poly_mask(poly)
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    edges = [(poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly))]

    # ---- the walk: open the old band inside, close what left the city
    old_band = CG.line_mask(old_poly, 70)
    for l in layers:
        if l["tag"] in ("tower", "tower_g", "gate_back", "lintel", "watergate"):
            im = images[l["id"]]
            fx, fy = l["x"] + im.width / 2.0, float(l["sort_y"])
            yy, xx = np.ogrid[max(0, int(fy - 80)):min(H_, int(fy + 40)), max(0, int(fx - 120)):min(W_, int(fx + 120))]
            sl = (slice(max(0, int(fy - 80)), min(H_, int(fy + 40))), slice(max(0, int(fx - 120)), min(W_, int(fx + 120))))
            old_band[sl] |= ((xx - fx) / 120.0) ** 2 + ((yy - fy) / 60.0) ** 2 <= 1.0
    walk |= old_band & inside_new & ~river
    left = inside_old & ~inside_new
    log["left_city_px"] = int(left.sum())

    removed = [l["id"] for l in layers if l["tag"] in ("wall", "wall_g", "tower", "tower_g", "gate_back", "lintel", "watergate")]
    layers[:] = [l for l in layers if l["id"] not in set(removed)]
    log["prototype_ring_removed"] = len(removed)

    recs = []
    nid = next_id

    def add(im, x, y, sort_y, tag, extra=None):
        nonlocal nid
        rec = {"id": nid, "file": "layers/%d_ring_%s.png" % (nid, tag), "tag": tag, "x": int(round(x)), "y": int(round(y)),
               "sort_y": round(float(sort_y), 1), "under_everything": False, "fade": "occluding_only", "fade_min_alpha": 0.45}
        if extra:
            rec.update(extra)
        images[nid] = im
        recs.append(rec)
        log["modified"].add(nid)
        nid += 1
        return rec

    def along(i, p):
        a, b = edges[i]
        L = math.dist(a, b)
        return ((p[0] - a[0]) * (b[0] - a[0]) + (p[1] - a[1]) * (b[1] - a[1])) / L

    def at(i, s):
        a, b = edges[i]
        L = math.dist(a, b)
        return (a[0] + (b[0] - a[0]) * s / L, a[1] + (b[1] - a[1]) * s / L)

    feats = {i: [] for i in range(len(edges))}
    gates_geo = []
    # ---- gatehouses
    for g in cfg["gates"]:
        i = int(g["edge"])
        a, b = edges[i]
        s = along(i, g["at"])
        q = at(i, s)
        sl = edge_slope(a, b)
        m = pick(mods, "gatehouse", sl)
        # Face fit (coordinator review 2): the gatehouse curtain's front face
        # (front merlon top to foot) is scaled to the run's face on this edge and
        # its foot is set on the wall line, so the parapet lines meet at the joins.
        seg = pick(mods, "segment", sl)
        fit = 1.0
        if "face_px" in m.spec and "face_px" in seg.spec:
            fit = float(seg.spec["face_px"]) / float(m.spec["face_px"])
            m = Module(kit_dir, dict(m.spec, scale_mul=fit), scale)
        im, mp = m.sheared(sl)
        arch = mp(m.p("arch"))
        wl, wr = mp(m.p("wall_left")), mp(m.p("wall_right"))
        x0, y0 = q[0] - arch[0], q[1] - arch[1]
        drop = 0.0
        if "curtain_foot" in m.spec:
            cf = mp(m.p("curtain_foot"))
            y_new = line_y(a, b, cf[0] + x0) - cf[1]
            drop = y_new - y0
            y0 = y_new
        # kit3: a small downward drop so the curtain parapet meets the runs'
        drop_k = float(m.spec.get("drop_px", 0.0)) * m.k
        y0 += drop_k
        drop += drop_k
        WL, WR = (wl[0] + x0, wl[1] + y0), (wr[0] + x0, wr[1] + y0)
        arch_open = 0.0
        if "arch_open_x" in m.spec:
            arch_open = (float(m.spec["arch_open_x"][1]) - float(m.spec["arch_open_x"][0])) * m.k
        inward = (cx - q[0], cy - q[1])
        u = iso_normal(a, b, inward)
        half = math.dist(WL, WR) / 2.0
        # round 15: where the ring towers flank this gatehouse (data flank_x, art
        # columns; default the painted towers' feet), on the wall line
        fx_art = m.spec.get("flank_x", [m.spec["wall_left"][0], m.spec["wall_right"][0]])
        flank_s = [along(i, (x0 + float(fx) * m.k, line_y(a, b, x0 + float(fx) * m.k))) for fx in fx_art]
        feats[i].append({"kind": "gate", "s": s, "half": half, "flank_s": flank_s})
        if g.get("snapped_to_corner"):
            # the gatehouse's outer tower is the corner: the neighbour edge's
            # run ends under it like under a corner tower
            c_ = g["snapped_to_corner"]
            if math.dist(c_, a) < 1.0:
                j_ = (i - 1) % len(edges)
                feats[j_].append({"kind": "gtower", "s": math.dist(*edges[j_]), "half": 0.0, "tower_y": a[1]})
            else:
                k_ = (i + 1) % len(edges)
                feats[k_].append({"kind": "gtower", "s": 0.0, "half": 0.0, "tower_y": b[1]})
        hw = float(cfg["passage_hero_widths"]) * float(cfg["hero_width_ratio"]) * hero_plate / 2.0
        depth = float(cfg.get("passage_depth_px", 120.0))
        v = ((b[0] - a[0]) / math.dist(a, b), (b[1] - a[1]) / math.dist(a, b))
        passage = CG.quad(q, u, v, -depth, depth, hw)
        py_min = min(p_[1] for p_ in passage)
        if "split" not in m.spec:
            # flat facade (kit3 horizontal): one piece on the wall line
            # just in front of the run strips that tuck under its towers (they sort at line + 2)
            add(im, x0, y0, q[1] + 6.0, "gate_back", {"gate": g["id"], "module": m.file})
            gates_geo.append({"id": g["id"], "why": g.get("why", "layout"), "edge": i, "arch": [round(q[0], 1), round(q[1], 1)],
                              "wall_join_left": [round(WL[0], 1), round(WL[1], 1)], "wall_join_right": [round(WR[0], 1), round(WR[1], 1)],
                              "u": u, "v": v, "half_span": half, "passage": [[round(p_[0], 1), round(p_[1], 1)] for p_ in passage],
                              "passage_half_width_px": round(hw, 1), "art": m.file, "wall_slope": round(sl, 3),
                              "art_height_px": round(m.im.height, 1), "art_width_px": round(m.im.width, 1), "feet_level_art_px": None if m.feet_level_px is None else round(m.feet_level_px, 1), "scale_mul": float(m.spec.get("scale_mul", 1.0)), "shear": round(sl - m.slope, 3),
                              "face_fit": round(fit, 3), "art_drop_px": round(drop, 1), "arch_open_px": round(arch_open, 1)})
            continue
        # split: the back side (behind a hero in the arch) and the front
        split = mp((m.p("split")[0], 0))[0]
        back_left = m.spec.get("back_side", "left") == "left"
        w_ = im.width
        lb = im.copy()
        ff = im.copy()
        la = np.array(lb)
        fa = np.array(ff)
        cut = int(round(split))
        # round 12: the back half runs 2 px under the front half, so the two
        # filtered edges do not leave a seam down the passage
        if back_left:
            la[:, cut + 2:, 3] = 0
            fa[:, :cut, 3] = 0
        else:
            la[:, :max(0, cut - 2), 3] = 0
            fa[:, cut:, 3] = 0
        lb, ff = Image.fromarray(la, "RGBA"), Image.fromarray(fa, "RGBA")
        fb = np.nonzero((fa[..., 3] > 40).any(1))[0]
        front_bottom = y0 + (fb.max() if len(fb) else im.height)
        # The back half's far tower stands over the run's tucked-in strips:
        # sort it just in front of the far join, still behind a hero in the arch.
        far_y = WR[1] if not back_left else WL[1]
        back_sort = min(max(py_min - 10.0, far_y + 20.0), q[1] - 8.0)
        add(lb, x0, y0, back_sort, "gate_back", {"gate": g["id"], "module": m.file})
        add(ff, x0, y0, front_bottom + 2.0, "lintel", {"gate": g["id"], "module": m.file})
        # round 15: wall strips under a gatehouse tower's plinth sort behind that tower
        feats[i][-1]["flank_sorts"] = [(WL[0], back_sort if back_left else front_bottom + 2.0),
                                       (WR[0], front_bottom + 2.0 if back_left else back_sort)]
        gates_geo.append({"id": g["id"], "why": g.get("why", "layout"), "edge": i, "arch": [round(q[0], 1), round(q[1], 1)],
                          "wall_join_left": [round(WL[0], 1), round(WL[1], 1)], "wall_join_right": [round(WR[0], 1), round(WR[1], 1)],
                          "u": u, "v": v, "half_span": half, "passage": [[round(p_[0], 1), round(p_[1], 1)] for p_ in passage],
                          "passage_half_width_px": round(hw, 1), "art": m.file, "wall_slope": round(sl, 3),
                          "art_height_px": round(m.im.height, 1), "art_width_px": round(m.im.width, 1), "feet_level_art_px": None if m.feet_level_px is None else round(m.feet_level_px, 1), "scale_mul": float(m.spec.get("scale_mul", 1.0)), "shear": round(sl - m.slope, 3),
                          "face_fit": round(fit, 3),
                          "art_drop_px": round(drop, 1), "arch_open_px": round(arch_open, 1)})
    # ---- water gates where the river crosses
    xing = CG.line_mask(poly, 3) & river
    lab, n = ndi.label(ndi.binary_dilation(xing, iterations=10))
    waters = []
    for j in range(1, n + 1):
        ys, xs = np.nonzero((lab == j) & xing)
        if len(xs) < 20:
            continue
        p0 = (float(xs.mean()), float(ys.mean()))
        i = CG.nearest_edge(poly, p0[0], p0[1])
        a, b = edges[i]
        s = along(i, p0)
        q = at(i, s)
        sl = edge_slope(a, b)
        m = pick(mods, "watergate", sl)
        im, mp = m.sheared(sl)
        arch = mp(m.p("arch"))
        wl, wr = mp(m.p("wall_left")), mp(m.p("wall_right"))
        x0, y0 = q[0] - arch[0], q[1] - arch[1]
        half = math.dist(wl, wr) / 2.0
        # round 15: the painted water keeps only to the river channel (no pool)
        from skimage import color as _color
        ar = np.array(im)
        labw = _color.rgb2lab(ar[..., :3] / 255.0)
        cool = (ar[..., 3] > 0) & (labw[..., 2] < 6.0)
        hh_, ww_ = cool.shape
        rd = ndi.binary_dilation(river, iterations=4)
        yy_, xx_ = np.nonzero(cool)
        px_ = (xx_ + int(round(x0))).clip(0, W_ - 1)
        py_ = (yy_ + int(round(y0))).clip(0, H_ - 1)
        off = ~rd[py_, px_]
        ar[yy_[off], xx_[off], 3] = 0
        im = Image.fromarray(ar, "RGBA")
        wrec = add(im, x0, y0, q[1] + 6.0, "watergate", {"module": m.file})
        feats[i].append({"kind": "water", "s": s, "half": half, "rec": wrec})
        # the channel's centreline either side of the wall vs the arch centre
        u_n = iso_normal(a, b, (cx - q[0], cy - q[1]))
        vv = ((b[0] - a[0]) / math.dist(a, b), (b[1] - a[1]) / math.dist(a, b))
        cents = []
        for dn in (-70.0, 70.0):
            pts_ = []
            for t_ in np.arange(-300.0, 300.0, 1.0):
                px = q[0] + u_n[0] * dn + vv[0] * t_
                py = q[1] + u_n[1] * dn + vv[1] * t_
                if 0 <= int(py) < H_ and 0 <= int(px) < W_ and river[int(py), int(px)]:
                    pts_.append((px, py))
            if pts_:
                cents.append((sum(p_[0] for p_ in pts_) / len(pts_), sum(p_[1] for p_ in pts_) / len(pts_)))
        ch_off = None
        if len(cents) == 2:
            (ax_, ay_), (bx_, by_) = cents
            ln_ = math.hypot(bx_ - ax_, by_ - ay_)
            ch_off = abs((bx_ - ax_) * (ay_ - q[1]) - (by_ - ay_) * (ax_ - q[0])) / max(ln_, 1e-6)
        waters.append({"edge": i, "at": [round(q[0], 1), round(q[1], 1)], "art": m.file, "art_width_px": round(m.im.width, 1),
                       "channel_offset_px": None if ch_off is None else round(ch_off, 1),
                       "channel_centres": [[round(c_[0], 1), round(c_[1], 1)] for c_ in cents]})
    # ---- towers (round 10, the GOAL): an even rhythm on every side. Fixed
    # anchors are the corners, the gatehouses' own towers and the water
    # gates' flanking towers; each stretch between anchors is divided evenly
    # with one spacing per side (about 2.5-3 wall heights). Every tower is the
    # same v5 tower, upright and centred on the wall line (or corner point).
    tm = mods["tower"]
    t_anchor = tm.p("base")
    wall_h = float(cfg["wall_height_px_in_art"]) * scale
    sp_lo, sp_hi = [float(v) * wall_h for v in cfg.get("tower_spacing_wall_heights", [2.5, 3.0])]
    sp_pref = float(cfg.get("tower_spacing_preferred", 2.5)) * wall_h
    t_half = tm.im.width * 0.42
    r_base = float(tm.spec.get("base_radius", tm.im.width / tm.k * 0.47)) * tm.k
    r_body = float(tm.spec.get("body_radius", tm.im.width / tm.k * 0.37)) * tm.k
    ne = len(edges)
    anchors = {i: [] for i in range(ne)}
    no_tower = {i: [] for i in range(ne)}
    for i in range(ne):
        for f in feats[i]:
            if f["kind"] == "gate":
                anchors[i] += [f["s"] - f["half"], f["s"] + f["half"]]
                no_tower[i].append((f["s"] - f["half"] - 1.0, f["s"] + f["half"] + 1.0))
            elif f["kind"] == "gtower":
                anchors[i].append(f["s"])
    # water gates: a v5 tower at each wall join, slid out along the wall until
    # its base is off the water
    water_towers = []
    river_d = river
    if (cfg.get("water_gate_towers") or {}).get("enabled"):
        for i in range(ne):
            for f in [f for f in feats[i] if f["kind"] == "water"]:
                L = math.dist(*edges[i])
                pair = []
                for sign in (-1.0, 1.0):
                    # round 13: from the block centre outward to the first spot
                    # where the tower's whole base outline is on dry ground
                    st = f["s"]
                    for _ in range(400):
                        qx, qy = at(i, st)
                        y0b, y1b = int(qy - r_base * 0.5) - 1, int(qy + r_base * 0.5) + 2
                        x0b, x1b = int(qx - r_base) - 1, int(qx + r_base) + 2
                        sub = river[max(0, y0b):min(H_, y1b), max(0, x0b):min(W_, x1b)]
                        yy_, xx_ = np.mgrid[max(0, y0b):min(H_, y1b), max(0, x0b):min(W_, x1b)]
                        inside_e = ((xx_ - qx) / r_base) ** 2 + ((yy_ - qy) / (r_base * 0.5)) ** 2 <= 1.0
                        if not (sub & inside_e).any():
                            break
                        st += sign * 2.0
                    st = min(max(st, 0.0), L)
                    pair.append(st)
                    # a gatehouse tower (or a corner) already standing there flanks it
                    taken_by = [x for x in anchors[i] if abs(x - st) < 2.0 * r_body]
                    if st < 2.0 * r_body or st > L - 2.0 * r_body or taken_by:
                        pair[-1] = taken_by[0] if taken_by else (0.0 if st < 2.0 * r_body else L)
                        continue
                    water_towers.append((i, st))
                    anchors[i].append(st)
                no_tower[i].append((pair[0] + 1.0, pair[1] - 1.0))
                f["towers_s"] = pair
    corner_tower = []
    for i in range(ne):
        j = (i - 1) % ne
        Lj = math.dist(*edges[j])
        covered = any(abs(x) < 2.0 for x in anchors[i]) or any(abs(x - Lj) < 2.0 for x in anchors[j])
        if not covered:
            corner_tower.append(i)
            anchors[i].append(0.0)
            anchors[j].append(Lj)
    placed = {i: [] for i in range(ne)}
    spacing_log = []

    def even_split(i, anc, nt):
        L = math.dist(*edges[i])
        xs = sorted(set([round(x, 3) for x in anc] + [0.0, L]))
        segs = []
        for x0_, x1_ in zip(xs, xs[1:]):
            mid = (x0_ + x1_) / 2.0
            if any(lo_ < mid < hi_ for lo_, hi_ in nt):
                continue
            if x1_ - x0_ > 1.0:
                segs.append((x0_, x1_))
        best = None
        for kq in range(41):
            sp = sp_lo + (sp_hi - sp_lo) * kq / 40.0
            ns = [max(1, int(round((x1_ - x0_) / sp))) for x0_, x1_ in segs]
            gaps = [(x1_ - x0_) / n_ for (x0_, x1_), n_ in zip(segs, ns)]
            if not gaps:
                break
            # spread of the spacing on this side; prefer spacings near the middle
            score = max(gaps) / min(gaps) + 0.02 * abs(sp - sp_pref) / wall_h
            if best is None or score < best[0]:
                best = (score, ns, gaps, segs)
        return best

    # round 13: a water-gate tower may slide outward (its block end staying
    # inside the tower's footprint) so the side's rhythm comes out even
    for i in (range(ne) if (cfg.get("tower_rule") or {}).get("mode") != "midpoint" else []):
        movable = [(f, k) for f in feats[i] if f["kind"] == "water" and f.get("towers_s")
                   for k in range(2) if any(abs(w[1] - f["towers_s"][k]) < 0.01 and w[0] == i for w in water_towers)]
        if not movable:
            continue
        opts = []
        for f, k in movable:
            sign = -1.0 if f["towers_s"][k] < f["s"] else 1.0
            reach = f["s"] + sign * (f["half"] + r_body * 0.8)
            span = max(0.0, (reach - f["towers_s"][k]) * sign)
            opts.append([f["towers_s"][k] + sign * d for d in np.arange(0.0, span + 0.1, 4.0)])
        base_anchors = [x for x in anchors[i] if not any(abs(x - f["towers_s"][k]) < 0.01 for f, k in movable)]
        best = None
        import itertools
        for combo in itertools.product(*opts):
            anc = base_anchors + list(combo)
            nt = [t for t in no_tower[i] if not any(abs(t[0] - 1.0 - min(f["towers_s"])) < 0.01 for f, _ in movable)]
            for f, k in movable:
                pass
            pairs = {}
            for (f, k), st in zip(movable, combo):
                pairs.setdefault(id(f), [f, list(f["towers_s"])])[1][k] = st
            nt = [t for t in no_tower[i] if not any(abs(t[0] - 1.0 - min(f["towers_s"])) < 0.01 for f, _ in movable)]
            nt += [(min(v[1]) + 1.0, max(v[1]) - 1.0) for v in pairs.values()]
            r = even_split(i, anc, nt)
            if r and (best is None or r[0] < best[0] - 1e-6):
                best = (r[0], combo, anc, nt)
        if best:
            _, combo, anc, nt = best
            for (f, k), st in zip(movable, combo):
                old = f["towers_s"][k]
                f["towers_s"][k] = st
                water_towers[:] = [(w[0], st) if (w[0] == i and abs(w[1] - old) < 0.01) else w for w in water_towers]
            anchors[i] = anc
            no_tower[i] = nt
    rule = cfg.get("tower_rule", {})
    if rule.get("mode") == "midpoint":
        min_len = float(rule.get("min_stretch_wall_heights", 6.0)) * wall_h
        for i in range(ne):
            L = math.dist(*edges[i])
            xs = sorted(set([round(x, 3) for x in anchors[i]] + [0.0, L]))
            ints = []
            for x0_, x1_ in zip(xs, xs[1:]):
                mid = (x0_ + x1_) / 2.0
                if any(lo_ < mid < hi_ for lo_, hi_ in no_tower[i]) or x1_ - x0_ <= 1.0:
                    continue
                n_ = 2 if (x1_ - x0_) > min_len else 1
                if n_ == 2:
                    placed[i].append(mid)
                ints.append([round(x0_, 1), round(x1_, 1), n_])
            spacing_log.append({"edge": i, "rule": "midpoint", "min_len": round(min_len, 1), "intervals": ints,
                                "gaps": [round((b_ - a_) / n_, 1) for a_, b_, n_ in ints]})
    for i in (range(ne) if rule.get("mode") != "midpoint" else []):
        best = even_split(i, anchors[i], no_tower[i])
        if best is None:
            spacing_log.append({"edge": i, "gaps": []})
            continue
        _, ns, gaps, segs = best
        for (x0_, x1_), n_ in zip(segs, ns):
            for kk in range(1, n_):
                placed[i].append(x0_ + (x1_ - x0_) * kk / n_)
        spacing_log.append({"edge": i, "gaps": [round(g, 1) for g in gaps],
                            "intervals": [[round(x0_, 1), round(x1_, 1), n_] for (x0_, x1_), n_ in zip(segs, ns)]})
    towers = []
    corner_flags = []
    kinds = []
    for i in corner_tower:
        towers.append((i, 0.0))
        corner_flags.append(True)
        kinds.append("corner")
    for i in range(ne):
        for st in placed[i]:
            towers.append((i, st))
            corner_flags.append(False)
            kinds.append("wall")
    for i, st in water_towers:
        towers.append((i, st))
        corner_flags.append(False)
        kinds.append("water_gate")
    if cfg.get("gate_flank_towers"):
        # round 15: every gatehouse is its curtain plus two identical ring towers
        for i in range(ne):
            for f in feats[i]:
                if f["kind"] == "gate":
                    for st in f.get("flank_s", (f["s"] - f["half"], f["s"] + f["half"])):
                        towers.append((i, st))
                        corner_flags.append(False)
                        kinds.append("gatehouse")
    dropped = []
    tower_sorts = []
    tower_pts = []
    for (i, st), is_corner, kind in zip(towers, corner_flags, kinds):
        p = at(i, st)
        tower_pts.append(p)
        feats[i].append({"kind": "tower", "s": st, "half": t_half * 0.7, "tower_y": p[1]})
        if is_corner:
            j = (i - 1) % ne
            feats[j].append({"kind": "tower", "s": math.dist(*edges[j]), "half": t_half * 0.7, "tower_y": p[1]})
        # round 15: the iso tower's ground centre is on the wall point; it sorts
        # at the front of its plinth, so both run ends hide behind its body
        sort_y = p[1] + float(tm.spec.get("plinth_front", 3.0 / tm.k)) * tm.k + 2.0
        tower_sorts.append((p[0], p[1], sort_y))
        tk = mods.get("tower_" + kind) or tm
        tka = tk.p("base")
        add(tk.im, p[0] - tka[0], p[1] - tka[1], sort_y, "tower",
            {"module": tk.file, "corner": is_corner, "tower_kind": kind, "edge": i, "s": round(st, 1),
             "wall_point": [round(p[0], 1), round(p[1], 1)], "axis_x": round(p[0], 1),
             "anchor_frac": round(float(tk.spec["base"][0]) / (tk.im.width / tk.k), 4)})
    log["tower_spacing"] = spacing_log
    log["stone_chroma"] = dict(CHROMA_LOG)
    towers = tower_pts
    # a water gate draws behind its own flanking towers (its wall ends tuck under them)
    for i in range(ne):
        for f in feats[i]:
            if f["kind"] == "water" and f.get("towers_s"):
                ts_ = [t[2] for t in tower_sorts if any(math.dist((t[0], t[1]), at(i, st_)) < 1.0 for st_ in f["towers_s"])]
                if ts_:
                    f["rec"]["sort_y"] = round(min(float(f["rec"]["sort_y"]), min(ts_) - 1.0), 1)
                # round 13: the block ends inside its towers: nothing of it beyond
                # the tower axes, and nothing below a tower's base (no wedge)
                rec_ = f["rec"]
                im_ = images[rec_["id"]]
                arr = np.array(im_)
                hh_, ww_ = arr.shape[:2]
                axes = sorted(at(i, st_)[0] for st_ in f["towers_s"])
                cols = rec_["x"] + np.arange(ww_)
                arr[:, (cols < axes[0]) | (cols > axes[1]), 3] = 0
                # round 14: the block keeps its piers and stonework down to the
                # ground and the water; the tower draws in front of it
                images[rec_["id"]] = Image.fromarray(arr, "RGBA")
                f["axes"] = axes
    for i in range(ne):
        for f in feats[i]:
            f.pop("rec", None)
    # ---- wall runs
    strips = 0
    runs = []
    tuck = cfg.get("tower_tuck", {})
    for i, (a, b) in enumerate(edges):
        L = math.dist(a, b)
        sl = edge_slope(a, b)
        m = pick(mods, "segment", sl)
        im, mp = m.sheared(sl)
        u0, u1 = float(m.spec["usable_x"][0]) * m.k, float(m.spec["usable_x"][1]) * m.k
        base0 = mp(m.p("base_left"))
        fs = sorted(feats[i], key=lambda f: f["s"])
        # Round 8: at a tower the run on the near side (lower on screen, drawn
        # in front of the tower) ends at the tower's surface; the far side
        # tucks well under it (the tower draws in front). Gatehouses as before.
        dyds = (b[1] - a[1]) / L
        r_front = r_body * float(tuck.get("front_mul", 1.0))
        if tuck.get("front_mode") == "silhouette":
            # end where the run meets the tower body's silhouette (x offset = body radius)
            # round 13: start 20% inside the body so the foot meets the base curve
            r_front = r_body * float(tuck.get("front_inset", 0.8)) / max(0.2, abs(b[0] - a[0]) / L)
        r_back = r_body * float(tuck.get("back_mul", 0.5))

        def tucks(f):
            if f["kind"] in ("tower", "gtower"):
                before = r_front if dyds < -1e-6 else r_back
                after = r_front if dyds > 1e-6 else r_back
                return before, after
            return f["half"] * 0.86, f["half"] * 0.86
        stops = [(0.0, 0.0, 0.0, None)] + [(f["s"],) + tucks(f) + (f,) for f in fs] + [(L, 0.0, 0.0, None)]
        for (s0, _b0, a0, f0), (s1, b1, _a1, f1) in zip(stops, stops[1:]):
            ra, rb = s0 + a0, s1 - b1
            if rb - ra < 8:
                continue
            pa, pb = at(i, ra), at(i, rb)
            run_rec = {"edge": i, "a": [round(pa[0], 1), round(pa[1], 1)], "b": [round(pb[0], 1), round(pb[1], 1)],
                       "start_at": _feat_ref(f0, at, i), "end_at": _feat_ref(f1, at, i), "strips": []}
            runs.append(run_rec)
            xa, xb = min(pa[0], pb[0]), max(pa[0], pb[0])
            x = xa
            ex0 = min(a[0], b[0])
            while x < xb - 1:
                # round 15: the tile phase follows the position along the edge,
                # so the runs either side of a tower continue one coursing
                tile = u1 - u0
                ph = (x - ex0) % tile
                if tile - ph < 8:
                    ph = 0.0
                w = min(tile - ph, xb - x)
                # window [u0 + ph, u0 + ph + w] of the sheared image; its base line at column c:
                # y = base0.y + sl * (c - base0.x)
                c0 = int(round(u0 + ph))
                c1 = int(round(u0 + ph + w))
                ox = x - c0
                oy = line_y(a, b, x) - (base0[1] + sl * (c0 - base0[0]))
                cuts = []
                for f_ in ((f0, f1) if not tuck.get("front_mode") else ()):
                    if f_ is not None and f_["kind"] == "gate":
                        for fx_, fs_ in f_.get("flank_sorts", []):
                            cuts.append((fx_ - r_base, fx_ + r_base, fs_))
                    if f_ is not None and f_["kind"] == "tower":
                        tp = at(i, f_["s"])
                        ts = next((t[2] for t in tower_sorts if abs(t[0] - tp[0]) < 1 and abs(t[1] - tp[1]) < 1), None)
                        if ts is not None:
                            cuts.append((tp[0] - r_base, tp[0] + r_base, ts))
                for k0 in range(c0, c1, STRIP):
                    k1 = min(c1, k0 + STRIP)
                    # Round 8: a strip crossing a tower's silhouette is split so
                    # the part inside it sorts behind the tower
                    pieces = [(k0, k1)]
                    for lo_x, hi_x, _ts in cuts:
                        nxt = []
                        for p0, p1 in pieces:
                            for edge_x in (lo_x - ox, hi_x - ox):
                                if p0 < edge_x < p1:
                                    nxt.append((p0, int(round(edge_x))))
                                    p0 = int(round(edge_x))
                            nxt.append((p0, p1))
                        pieces = [pc for pc in nxt if pc[1] > pc[0]]
                    for p0, p1 in pieces:
                        part = im.crop((p0, 0, p1, im.height))
                        if part.getbbox() is None:
                            continue
                        sy = max(line_y(a, b, ox + p0), line_y(a, b, ox + p1)) + 2.0
                        mid_x = ox + (p0 + p1) / 2.0
                        for lo_x, hi_x, ts in cuts:
                            if lo_x <= mid_x <= hi_x:
                                sy = min(sy, ts - 1.0)
                        add(part, ox + p0, oy, sy, "wall", {"module": m.file})
                        run_rec["strips"].append((part, ox + p0, oy))
                        strips += 1
                x += w
    # Run ends: measured from the drawn strips (foot = wall face foot between
    # buttresses, tip = merlon tips) so the tests can check the lines run on.
    for rr in runs:
        a_, b_ = edges[rr["edge"]]
        for end, key in ((rr["a"], "a_px"), (rr["b"], "b_px")):
            rr[key] = _measure_end(rr["strips"], end, a_, b_)
        rr.pop("strips")
    log["wall_runs"] = runs
    log["tower_body_radius_px"] = round(r_body, 1)
    log["tower_base_radius_px"] = round(r_base, 1)
    log["water_gate_axes"] = [[round(x, 1) for x in f.get("axes", [])] for i in range(ne) for f in feats[i] if f["kind"] == "water"]
    # ---- walk: new band, towers, gate footprints, then the passages
    band = CG.line_mask(poly, int(cfg.get("band_px", 40)))
    walk &= ~band
    # round 15: the whole plinth ellipse of every tower blocks (ring towers and
    # the gatehouses' own towers), not just the shaft
    plinths = [tuple(p) for p in towers] + [tuple(gg[k]) for gg in gates_geo for k in ("wall_join_left", "wall_join_right")]
    for p in plinths:
        rx = r_base + 4.0
        y0_, y1_ = max(0, int(p[1] - rx)), min(H_, int(p[1] + rx))
        x0_, x1_ = max(0, int(p[0] - rx)), min(W_, int(p[0] + rx))
        sub_y, sub_x = np.ogrid[y0_:y1_, x0_:x1_]
        walk[y0_:y1_, x0_:x1_] &= ~(((sub_x - p[0]) / rx) ** 2 + ((sub_y - p[1]) / (rx * 0.5)) ** 2 <= 1.0)
    log["plinths"] = [[round(p[0], 1), round(p[1], 1)] for p in plinths]
    for gg in gates_geo:
        q = gg["arch"]
        foot = CG.poly_mask(CG.quad(q, gg["u"], gg["v"], -60.0, 90.0, gg["half_span"]))
        walk &= ~foot
    for gg in gates_geo:
        # the flanking towers block like ring towers (a snapped one stands past the corner)
        for key in ("wall_join_left", "wall_join_right"):
            p = gg[key]
            rx = r_body
            y0_, y1_ = max(0, int(p[1] - rx)), min(H_, int(p[1] + rx))
            x0_, x1_ = max(0, int(p[0] - rx)), min(W_, int(p[0] + rx))
            sub_y, sub_x = np.ogrid[y0_:y1_, x0_:x1_]
            walk[y0_:y1_, x0_:x1_] &= ~(((sub_x - p[0]) / rx) ** 2 + ((sub_y - p[1]) / (rx * 0.5)) ** 2 <= 1.0)
    for gg in gates_geo:
        walk |= CG.poly_mask(gg["passage"]) & ~river
    log["ring_pieces"] = {"wall_strips": strips, "towers": len(towers), "gates": len(gates_geo), "water_gates": len(waters)}
    log["water_gates"] = waters
    log["towers_dropped_near_gates"] = dropped
    log["tower_body_radius_px"] = round(r_body, 1)
    for gg in gates_geo:
        gg.pop("u", None)
        gg.pop("v", None)
    return recs, gates_geo, inside_old, inside_new
