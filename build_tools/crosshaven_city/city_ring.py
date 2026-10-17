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
        if "taper" in spec:
            im = taper(im, spec["taper"])
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
    k = mods_scale
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
        new_s = s
        corner = None
        if lim > 0 and s - half < lim:
            new_s, corner = half, list(a)
        elif lim > 0 and (L - s) - half < lim:
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


def _measure_end(strips, end, a, b, span=160):
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
    feet = minimum_filter1d(np.array(feet, float)[o], 40)
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
    for name, spec in cfg["modules"].items():
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
        feats[i].append({"kind": "gate", "s": s, "half": half})
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
                              "art_height_px": round(m.im.height, 1), "art_width_px": round(m.im.width, 1), "shear": round(sl - m.slope, 3),
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
        if back_left:
            la[:, cut:, 3] = 0
            fa[:, :cut, 3] = 0
        else:
            la[:, :cut, 3] = 0
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
        gates_geo.append({"id": g["id"], "why": g.get("why", "layout"), "edge": i, "arch": [round(q[0], 1), round(q[1], 1)],
                          "wall_join_left": [round(WL[0], 1), round(WL[1], 1)], "wall_join_right": [round(WR[0], 1), round(WR[1], 1)],
                          "u": u, "v": v, "half_span": half, "passage": [[round(p_[0], 1), round(p_[1], 1)] for p_ in passage],
                          "passage_half_width_px": round(hw, 1), "art": m.file, "wall_slope": round(sl, 3),
                          "art_height_px": round(m.im.height, 1), "art_width_px": round(m.im.width, 1), "shear": round(sl - m.slope, 3),
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
        feats[i].append({"kind": "water", "s": s, "half": half})
        ab = np.nonzero((np.array(im)[..., 3] > 40).any(1))[0]
        add(im, x0, y0, q[1] + 6.0, "watergate", {"module": m.file})
        waters.append({"edge": i, "at": [round(q[0], 1), round(q[1], 1)], "art": m.file, "art_width_px": round(m.im.width, 1)})
    # ---- towers: corners and every N wall heights
    tm = mods["tower"]
    t_anchor = tm.p("base")
    wall_h = float(cfg["wall_height_px_in_art"]) * scale
    every = float(cfg["tower_every_wall_heights"]) * wall_h
    t_half = tm.im.width * 0.42
    spots = []
    for i, (a, b) in enumerate(edges):
        L = math.dist(a, b)
        spots.append((i, 0.0))
        n_mid = max(0, int(L // every))
        for kk in range(1, n_mid + 1):
            spots.append((i, L * kk / (n_mid + 1)))
    towers = []
    corner_flags = []
    tower_drops = []
    r_base = float(tm.spec.get("base_radius", tm.im.width / tm.k * 0.47)) * tm.k
    # Coordinator review 3: no ring tower within about one wall height of a
    # gatehouse (its own flanking towers are smaller); corners included.
    gate_gap = float(cfg.get("no_tower_near_gate_wall_heights", 1.0)) * wall_h
    dropped = []
    for i, s in spots:
        p = at(i, s)
        clash = False
        near_gate = False
        for f in feats[i]:
            if abs(s - f["s"]) < f["half"] + t_half:
                clash = True
            if f["kind"] in ("gate", "gtower") and abs(s - f["s"]) < f["half"] + t_half + gate_gap:
                near_gate = True
        # corner towers also count on the previous edge
        if s == 0.0:
            j = (i - 1) % len(edges)
            Lj = math.dist(*edges[j])
            for f in feats[j]:
                if abs(Lj - f["s"]) < f["half"] + t_half:
                    clash = True
                if f["kind"] in ("gate", "gtower") and abs(Lj - f["s"]) < f["half"] + t_half + gate_gap:
                    near_gate = True
        if s == 0.0 and cfg.get("corner_towers") == "always":
            # round 5: corners keep their tower (no bare cut where two runs
            # meet) unless a gatehouse span covers the corner itself
            covered = False
            for f in feats[i]:
                if f["kind"] in ("gate", "gtower") and abs(s - f["s"]) < f["half"] + 10.0:
                    covered = True
            j = (i - 1) % len(edges)
            Lj = math.dist(*edges[j])
            for f in feats[j]:
                if f["kind"] in ("gate", "gtower") and abs(Lj - f["s"]) < f["half"] + 10.0:
                    covered = True
            near_gate = covered
        if near_gate:
            dropped.append([round(p[0], 1), round(p[1], 1)])
            continue
        if clash and s != 0.0:
            continue
        towers.append(p)
        corner_flags.append(s == 0.0)
        # Round 8: the v5 tower is painted face-on, so its painted bottom is the
        # front of its base ellipse: on a diagonal it stands |slope| x base
        # radius in front of the wall line (the wall foot where the near run
        # comes out from behind it).
        sls = [abs(edge_slope(*edges[i]))]
        if s == 0.0:
            sls.append(abs(edge_slope(*edges[(i - 1) % len(edges)])))
        tower_drops.append(max(sls) * r_base)
        feats[i].append({"kind": "tower", "s": s, "half": t_half * 0.7, "tower_y": p[1]})
        if s == 0.0:
            j = (i - 1) % len(edges)
            feats[j].append({"kind": "tower", "s": math.dist(*edges[j]), "half": t_half * 0.7, "tower_y": p[1]})
    tower_sorts = []
    for p, is_corner, drop in zip(towers, corner_flags, tower_drops):
        tower_sorts.append((p[0], p[1], p[1] + drop + 2.0))
        add(tm.im, p[0] - t_anchor[0], p[1] + drop - t_anchor[1], p[1] + drop + 2.0, "tower",
            {"module": tm.file, "corner": is_corner, "base_drop_px": round(drop, 1), "wall_point": [round(p[0], 1), round(p[1], 1)]})
    # ---- wall runs
    strips = 0
    runs = []
    tuck = cfg.get("tower_tuck", {})
    r_body = float(tm.spec.get("body_radius", tm.im.width / tm.k * 0.37)) * tm.k
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
            while x < xb - 1:
                w = min(u1 - u0, xb - x)
                # window [u0, u0 + w] of the sheared image; its base line at column c:
                # y = base0.y + sl * (c - base0.x)
                c0 = int(round(u0))
                c1 = int(round(u0 + w))
                ox = x - c0
                oy = line_y(a, b, x) - (base0[1] + sl * (c0 - base0[0]))
                cuts = []
                for f_ in (f0, f1):
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
    # ---- walk: new band, towers, gate footprints, then the passages
    band = CG.line_mask(poly, int(cfg.get("band_px", 40)))
    walk &= ~band
    for p in towers:
        rx = tm.im.width * 0.45
        yy, xx = np.ogrid[0:H_, 0:W_]
        y0_, y1_ = max(0, int(p[1] - rx)), min(H_, int(p[1] + rx))
        x0_, x1_ = max(0, int(p[0] - rx)), min(W_, int(p[0] + rx))
        sub_y, sub_x = np.ogrid[y0_:y1_, x0_:x1_]
        walk[y0_:y1_, x0_:x1_] &= ~(((sub_x - p[0]) / rx) ** 2 + ((sub_y - p[1] + rx * 0.15) / (rx * 0.5)) ** 2 <= 1.0)
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
    for gg in gates_geo:
        gg.pop("u", None)
        gg.pop("v", None)
    return recs, gates_geo, inside_old, inside_new
