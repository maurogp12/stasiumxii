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
        hw = float(cfg["passage_hero_widths"]) * float(cfg["hero_width_ratio"]) * hero_plate / 2.0
        depth = float(cfg.get("passage_depth_px", 120.0))
        v = ((b[0] - a[0]) / math.dist(a, b), (b[1] - a[1]) / math.dist(a, b))
        passage = CG.quad(q, u, v, -depth, depth, hw)
        py_min = min(p_[1] for p_ in passage)
        if "split" not in m.spec:
            # flat facade (kit3 horizontal): one piece on the wall line
            add(im, x0, y0, q[1] + 2.0, "gate_back", {"gate": g["id"], "module": m.file})
            gates_geo.append({"id": g["id"], "why": g.get("why", "layout"), "edge": i, "arch": [round(q[0], 1), round(q[1], 1)],
                              "wall_join_left": [round(WL[0], 1), round(WL[1], 1)], "wall_join_right": [round(WR[0], 1), round(WR[1], 1)],
                              "u": u, "v": v, "half_span": half, "passage": [[round(p_[0], 1), round(p_[1], 1)] for p_ in passage],
                              "passage_half_width_px": round(hw, 1), "art": m.file, "wall_slope": round(sl, 3),
                              "art_height_px": round(m.im.height, 1), "shear": round(sl - m.slope, 3),
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
        add(lb, x0, y0, py_min - 10.0, "gate_back", {"gate": g["id"], "module": m.file})
        add(ff, x0, y0, front_bottom + 2.0, "lintel", {"gate": g["id"], "module": m.file})
        gates_geo.append({"id": g["id"], "why": g.get("why", "layout"), "edge": i, "arch": [round(q[0], 1), round(q[1], 1)],
                          "wall_join_left": [round(WL[0], 1), round(WL[1], 1)], "wall_join_right": [round(WR[0], 1), round(WR[1], 1)],
                          "u": u, "v": v, "half_span": half, "passage": [[round(p_[0], 1), round(p_[1], 1)] for p_ in passage],
                          "passage_half_width_px": round(hw, 1), "art": m.file, "wall_slope": round(sl, 3),
                          "art_height_px": round(m.im.height, 1), "shear": round(sl - m.slope, 3),
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
        waters.append({"edge": i, "at": [round(q[0], 1), round(q[1], 1)], "art": m.file})
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
            if f["kind"] == "gate" and abs(s - f["s"]) < f["half"] + t_half + gate_gap:
                near_gate = True
        # corner towers also count on the previous edge
        if s == 0.0:
            j = (i - 1) % len(edges)
            Lj = math.dist(*edges[j])
            for f in feats[j]:
                if abs(Lj - f["s"]) < f["half"] + t_half:
                    clash = True
                if f["kind"] == "gate" and abs(Lj - f["s"]) < f["half"] + t_half + gate_gap:
                    near_gate = True
        if near_gate:
            dropped.append([round(p[0], 1), round(p[1], 1)])
            continue
        if clash and s != 0.0:
            continue
        towers.append(p)
        feats[i].append({"kind": "tower", "s": s, "half": t_half * 0.7})
        if s == 0.0:
            j = (i - 1) % len(edges)
            feats[j].append({"kind": "tower", "s": math.dist(*edges[j]), "half": t_half * 0.7})
    for p in towers:
        add(tm.im, p[0] - t_anchor[0], p[1] - t_anchor[1], p[1] + 10.0, "tower", {"module": tm.file})
    # ---- wall runs
    strips = 0
    for i, (a, b) in enumerate(edges):
        L = math.dist(a, b)
        sl = edge_slope(a, b)
        m = pick(mods, "segment", sl)
        im, mp = m.sheared(sl)
        u0, u1 = float(m.spec["usable_x"][0]) * m.k, float(m.spec["usable_x"][1]) * m.k
        base0 = mp(m.p("base_left"))
        fs = sorted(feats[i], key=lambda f: f["s"])
        stops = [(0.0, 0.0)] + [(f["s"], f["half"]) for f in fs] + [(L, 0.0)]
        for (s0, h0), (s1, h1) in zip(stops, stops[1:]):
            # runs tuck a little under the gatehouses and towers: no seam
            ra, rb = s0 + h0 * 0.86, s1 - h1 * 0.86
            if rb - ra < 8:
                continue
            pa, pb = at(i, ra), at(i, rb)
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
                for k0 in range(c0, c1, STRIP):
                    k1 = min(c1, k0 + STRIP)
                    part = im.crop((k0, 0, k1, im.height))
                    if part.getbbox() is None:
                        continue
                    sy = max(line_y(a, b, ox + k0), line_y(a, b, ox + k1)) + 2.0
                    add(part, ox + k0, oy, sy, "wall", {"module": m.file})
                    strips += 1
                x += w
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
        walk |= CG.poly_mask(gg["passage"]) & ~river
    log["ring_pieces"] = {"wall_strips": strips, "towers": len(towers), "gates": len(gates_geo), "water_gates": len(waters)}
    log["water_gates"] = waters
    log["towers_dropped_near_gates"] = dropped
    for gg in gates_geo:
        gg.pop("u", None)
        gg.pop("v", None)
    return recs, gates_geo, inside_old, inside_new
