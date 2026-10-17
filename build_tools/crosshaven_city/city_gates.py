"""Gates, roads and tower clean-up for the walled city (Mauro's change list, items 1-4).

Used by build_city.py. Works on the Rosebud layers and the plate ground in place:

* find_contacts(): every place where a street or road meets the wall ring, from
  the ground's street pixels against the wall line (the wall layers' footprint
  is a 26 px band on that line, plus the towers).
* clean_tower(): the round tower sprite with the short wall stubs at its base cut
  off (item 4). Same art for all 15 towers.
* add_gate(): a gatehouse at a wall point. It reuses the south gate's two
  sprites (gate_back + gate_front_lintel, cw4_gate_open) and fits them to the
  wall's slope the way the handoff build fits its gates and water gates: mirror
  for a falling wall, then a vertical shear so the wall joins sit on the wall
  line. The wall runs are cut over the gate's span, the walkmask gets the
  gatehouse footprint and a walkable passage through the arch, and a road is
  painted from the passage to the nearest street inside and out to the plate
  edge outside where there is none.
"""
import math

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

PLATE_W, PLATE_H = 0, 0  # set by build_city.py from the plate
# South gate (handoff layers 231/399, 256x308, top-left 2140,2256): wall joins and arch in sprite px.
GATE_LOCAL = {"WL": (26.6, 202.3), "WR": (184.8, 281.4), "arch": (110.0, 244.0)}
GATE_SLOPE = 0.5          # wall slope the south gate sprites are fitted to
ROAD_W = 68               # street width (= bridge deck width)
PASSAGE_HALF = 30         # half width of the walkable arch passage, along the wall
TOWER_CYL = (44, 132)     # tower sprite columns kept below the stubs' top (180x216 sprite)
TOWER_STUB_TOP = 128      # first sprite row of the stubs


def wall_points(wall_ref):
    return [(x * 5.0, y * 5.0) for x, y in wall_ref]


def line_mask(points, width, closed=True):
    img = Image.new("L", (PLATE_W, PLATE_H), 0)
    d = ImageDraw.Draw(img)
    pts = points + points[:1] if closed else points
    d.line(pts, fill=255, width=width)
    return np.asarray(img) > 0


def street_pixels(ground_np, river):
    g = ground_np.astype(np.int16)
    sat = g.max(2) - g.min(2)
    # The river shore band is low-saturation grey-green too: keep clear of it.
    return (sat < 28) & (g.max(2) > 90) & ~ndi.binary_dilation(river, iterations=40)


def find_contacts(ground_np, river, wall, gates_known, reach=140, touch=60, street=None):
    """Clusters of street pixels within `reach` px of the wall line.

    Each row: closest point, its distance, wall edge, and a verdict:
    'gate' (existing gate), 'crosses' (street runs through the wall line),
    'dead_end' (street ends at the wall within `touch` px), 'runs_along'
    (street passes the wall without ending at it).
    """
    if street is None:
        street = street_pixels(ground_np, river)
    img = Image.new("L", (PLATE_W, PLATE_H), 255)
    d = ImageDraw.Draw(img)
    d.line(wall + wall[:1], fill=0, width=3)
    dist = ndi.distance_transform_edt(np.asarray(img) > 0)
    near = street & (dist < reach)
    lab, n = ndi.label(ndi.binary_dilation(near, iterations=6))
    rows = []
    for i in range(1, n + 1):
        m = (lab == i) & near
        ys, xs = np.nonzero(m)
        if len(xs) < 200:
            continue
        k = int(np.argmin(dist[ys, xs]))
        px, py, dd = int(xs[k]), int(ys[k]), float(dist[ys[k], xs[k]])
        edge = nearest_edge(wall, px, py)
        a, b = wall[edge], wall[(edge + 1) % len(wall)]
        # Extent of the close part along the wall: a road end is short, a
        # road running beside the wall is long.
        close = dist[ys, xs] < dd + 40
        ux, uy = (b[0] - a[0]), (b[1] - a[1])
        ln = math.hypot(ux, uy)
        along = (xs[close] - a[0]) * ux / ln + (ys[close] - a[1]) * uy / ln
        span = float(along.max() - along.min()) if len(along) else 0.0
        known = None
        for g in gates_known:
            if math.hypot(px - g[0], py - g[1]) < 260:
                known = g
        if known is not None:
            verdict = "gate"
        elif dd <= 2:
            verdict = "crosses"
        elif dd <= touch and span < 160:
            verdict = "dead_end"
        else:
            verdict = "runs_along"
        rows.append({"at": [px, py], "dist_px": round(dd, 1), "edge": edge, "span_px": round(span),
                     "pixels": int(len(xs)), "verdict": verdict})
    rows.sort(key=lambda r: (r["at"][1], r["at"][0]))
    return rows


def nearest_edge(wall, px, py):
    best = None
    for i in range(len(wall)):
        a, b = wall[i], wall[(i + 1) % len(wall)]
        vx, vy = b[0] - a[0], b[1] - a[1]
        t = max(0.0, min(1.0, ((px - a[0]) * vx + (py - a[1]) * vy) / (vx * vx + vy * vy)))
        dd = math.hypot(px - a[0] - t * vx, py - a[1] - t * vy)
        if best is None or dd < best[0]:
            best = (dd, i)
    return best[1]


def project_on_edge(wall, edge, px, py):
    a, b = wall[edge], wall[(edge + 1) % len(wall)]
    vx, vy = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((px - a[0]) * vx + (py - a[1]) * vy) / (vx * vx + vy * vy)))
    return (a[0] + t * vx, a[1] + t * vy)


def clean_tower(im):
    """Cut the wall stubs off the tower base: keep the cylinder columns below the stub top."""
    a = np.array(im.convert("RGBA"))
    h, w = a.shape[:2]
    x0, x1 = TOWER_CYL
    a[TOWER_STUB_TOP:, :x0, 3] = 0
    a[TOWER_STUB_TOP:, x1:, 3] = 0
    # The stubs overlap the cylinder's outer 6 px: repaint those columns from
    # the cylinder just inside them, a little darker at the rim.
    for x, src, k in ((x0, x0 + 6, 0.86), (x0 + 1, x0 + 7, 0.9), (x0 + 2, x0 + 8, 0.94), (x0 + 3, x0 + 9, 0.97),
                      (x1 - 1, x1 - 7, 0.78), (x1 - 2, x1 - 8, 0.84), (x1 - 3, x1 - 9, 0.9), (x1 - 4, x1 - 10, 0.95)):
        col = a[TOWER_STUB_TOP:, src].astype(np.float32)
        col[:, :3] *= k
        keep = a[TOWER_STUB_TOP:, x, 3] > 0
        a[TOWER_STUB_TOP:, x][keep] = col[keep].astype(np.uint8)
    # The cylinder's base: round off the bottom like the tower's own ellipse.
    cx = (x0 + x1) / 2.0
    rx = (x1 - x0) / 2.0
    base = h - 14
    for x in range(x0, x1):
        dy = 10.0 * math.sqrt(max(0.0, 1.0 - ((x + 0.5 - cx) / rx) ** 2))
        a[int(base + dy) + 1:, x, 3] = 0
    return Image.fromarray(a, "RGBA")


def tower_footprints(cx, cy):
    """Old (handoff) and new walk footprint ellipses of a tower at plate (cx, cy)."""
    old = (cx - 55, cy - 30, cx + 55, cy + 18)
    new = (cx - 46, cy - 26, cx + 46, cy + 14)
    return old, new


def shear_sprite(im, kk, flip):
    """Mirror (optional) then shear y += kk * x. Returns image and the y offset added."""
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    w, h = im.size
    off = -kk * w if kk < 0 else 0.0
    nh = int(math.ceil(h + abs(kk) * w)) + 2
    out = im.transform((w, nh), Image.AFFINE, (1, 0, 0, -kk, 1, -off), resample=Image.BICUBIC)
    return out, off


def map_local(p, w, kk, off, flip):
    x, y = p
    if flip:
        x = w - x
    return (x, y + kk * x + off)


def cobble_sampler(ground_np, street):
    """The cobble field is one tile repeated on the lattice (128, 0), (64, 32)
    from the plate origin (handoff build.py `field`). Rebuild its 128x32 cell
    as the per-phase median of every street pixel, then sample it anywhere."""
    # The mask is speckled (dark mortar): close it, then keep the road cores.
    core = ndi.binary_erosion(ndi.binary_closing(street, iterations=3), iterations=8)
    ys, xs = np.nonzero(core)
    k = ys // 32
    yr = ys - 32 * k
    xr = (xs - 64 * k) % 128
    key = yr * 128 + xr
    order = np.argsort(key, kind="stable")
    key = key[order]
    cols = ground_np[ys[order], xs[order]].astype(np.float32)
    tile = np.zeros((32 * 128, 3), np.float32)
    bounds = np.searchsorted(key, np.arange(32 * 128 + 1))
    for i in range(32 * 128):
        a_, b_ = bounds[i], bounds[i + 1]
        if b_ > a_:
            tile[i] = np.median(cols[a_:b_], axis=0)
    tile = tile.reshape(32, 128, 3)

    def sample(xx, yy):
        kk = yy // 32
        return tile[yy - 32 * kk, (xx - 64 * kk) % 128]
    return sample


def paint_road(ground_np, walk, sample, pts, width=ROAD_W, feather=3):
    """Paint a cobble strip along a polyline into the ground and open it in the walkmask."""
    img = Image.new("L", (PLATE_W, PLATE_H), 0)
    ImageDraw.Draw(img).line([tuple(p) for p in pts], fill=255, width=width, joint="curve")
    for p in (pts[0], pts[-1]):
        r = width / 2.0
        ImageDraw.Draw(img).ellipse([p[0] - r, p[1] - r * 0.5, p[0] + r, p[1] + r * 0.5], fill=255)
    m = np.asarray(img).astype(np.float32) / 255.0
    if feather:
        m = ndi.gaussian_filter(m, feather)
    ys, xs = np.nonzero(m > 0.01)
    cob = sample(xs, ys).astype(np.float32)
    a = m[ys, xs][:, None]
    ground_np[ys, xs] = np.clip(ground_np[ys, xs] * (1 - a) + cob * a, 0, 255).astype(np.uint8)
    hard = m > 0.5
    return hard


def quad(p, u, v, t0, t1, s):
    return [(p[0] + u[0] * t0 - v[0] * s, p[1] + u[1] * t0 - v[1] * s),
            (p[0] + u[0] * t1 - v[0] * s, p[1] + u[1] * t1 - v[1] * s),
            (p[0] + u[0] * t1 + v[0] * s, p[1] + u[1] * t1 + v[1] * s),
            (p[0] + u[0] * t0 + v[0] * s, p[1] + u[1] * t0 + v[1] * s)]


def poly_mask(poly):
    img = Image.new("L", (PLATE_W, PLATE_H), 0)
    ImageDraw.Draw(img).polygon([tuple(p) for p in poly], fill=255)
    return np.asarray(img) > 0


def fit_gate(back, lintel, q, slope, inward):
    """Place the south gate's sprites at wall point q on a wall of `slope`.

    `inward` is a unit screen vector toward the city. Returns the two sheared
    images, their top-left plate position, the wall joins, the passage axis
    (unit, toward the city) and the wall axis.
    """
    flip = slope < 0
    base = -GATE_SLOPE if flip else GATE_SLOPE
    kk = slope - base
    w = back.width
    b2, off = shear_sprite(back, kk, flip)
    l2, _ = shear_sprite(lintel, kk, flip)
    wl = map_local(GATE_LOCAL["WL"], w, kk, off, flip)
    wr = map_local(GATE_LOCAL["WR"], w, kk, off, flip)
    ar = map_local(GATE_LOCAL["arch"], w, kk, off, flip)
    # The arch is on the wall join line; put it on q.
    x0 = q[0] - ar[0]
    y0 = q[1] - ar[1]
    WL = (x0 + wl[0], y0 + wl[1])
    WR = (x0 + wr[0], y0 + wr[1])
    # Passage: the south gate's iso axis (2, -1), mirrored and sheared with the art.
    ux, uy = (-2.0, -1.0) if flip else (2.0, -1.0)
    uy = uy + kk * ux
    n = math.hypot(ux, uy)
    u = (ux / n, uy / n)
    if u[0] * inward[0] + u[1] * inward[1] < 0:
        u = (-u[0], -u[1])
    v = ((WR[0] - WL[0]) / math.dist(WL, WR), (WR[1] - WL[1]) / math.dist(WL, WR))
    return {"back": b2, "lintel": l2, "pos": (int(round(x0)), int(round(y0))), "WL": WL, "WR": WR,
            "u": u, "v": v, "kk": round(kk, 3), "flip": flip, "q": q}


def cut_walls(layers, images, gate, wall_tags=("wall", "wall_g")):
    """Clear the wall-run pixels over the gate's span (between its two joins)."""
    xa, xb = sorted((gate["WL"][0], gate["WR"][0]))
    ya, yb = sorted((gate["WL"][1], gate["WR"][1]))
    cut = []
    for l in layers:
        if l["tag"] not in wall_tags:
            continue
        im = images[l["id"]]
        lx0, ly0 = l["x"], l["y"]
        if lx0 + im.width < xa or lx0 > xb or ly0 > yb + 40 or ly0 + im.height < ya - 200:
            continue
        a = np.array(im)
        c0 = int(max(0, math.floor(xa - lx0)))
        c1 = int(min(im.width, math.ceil(xb - lx0)))
        if c1 <= c0:
            continue
        a[:, c0:c1, 3] = 0
        if (a[..., 3] > 0).sum() < 40:
            cut.append((l["id"], "removed"))
        else:
            cut.append((l["id"], "trimmed"))
        images[l["id"]] = Image.fromarray(a, "RGBA")
    return cut
