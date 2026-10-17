#!/usr/bin/env python3
"""Build the walled-city zone `crosshaven_city` from the Rosebud plate package.

Input: the `crosshaven/` folder of the map handoff (branch docs/pc-map-handoff,
docs/pc/map_handoff/crosshaven/), extracted anywhere. Output (repo paths):

  art/world/crosshaven_city/ground.jpg        the bare painted ground (5120x2880)
  art/world/crosshaven_city/ground_lite.jpg   half size, for Performance mode
  art/world/crosshaven_city/layers/*.png      the y-sorted sprite layers
  art/world/crosshaven_city/housing/*.png     plot house exteriors per tier
  art/world/crosshaven_city/pets/*.png        dog and cat
  data/world/crosshaven_city/city.json        zone, cell grid, plots, gates, fit
  data/world/crosshaven_city/layers.json      sprite layers (+ coarse alpha masks)

The plate is placed 1:1 (1 plate px = 1 world px). Only a translation is fitted:
the cell lattice is shifted so the three bridge decks and the gate passage run
down rows of cell centres (see docs/pc/CROSSHAVEN_CITY_BUILD.md).

Usage: python3 build_city.py <handoff crosshaven dir> <repo root> [--layout <json>] [--debug <dir>]

Size-agnostic: the plate size comes from ground.jpg; the wall polygon, the
plot table and the plot search box (fractions of the plate) come from the
layout file (default layout_rosebud_v9.json next to this script).
"""
import base64
import json
import math
import os
import shutil
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import city_gates as CG  # noqa: E402

Image.MAX_IMAGE_PIXELS = None

# Set from the plate's ground image in main(); every size below follows it.
PLATE_W, PLATE_H = 0, 0
LAYOUT = {}
MASK_STEP = 8          # alpha mask resolution for the fade test (plate px per bit)
FADE_MIN_HEIGHT = 40   # sprites shorter than this never hide the hero
# Tags that are part of the wall ring (plots keep clear of these).
WALL_TAGS = {"wall", "wall_g", "tower", "tower_g", "gate_back", "lintel", "watergate"}
# Tags that can be cleared off a plot's Legendary clearance.
LOOSE_TAGS = {"tree", "prop", "lamp"}
# Player plots and the layers of the old plot houses: from the layout file.
PLOTS = []
OLD_PLOT_LAYERS = {}
CLEARANCE = {"normal": 200, "rare": 260, "legendary": 350}
LEGENDARY = CLEARANCE["legendary"]


def load_mask(path):
    return np.asarray(Image.open(path).convert("L")) > 127


def ellipse_mask(shape, cx, cy, rx, ry):
    h, w = shape
    x0, x1 = max(0, int(cx - rx - 1)), min(w, int(cx + rx + 2))
    y0, y1 = max(0, int(cy - ry - 1)), min(h, int(cy + ry + 2))
    yy, xx = np.mgrid[y0:y1, x0:x1]
    inside = ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0
    return (slice(y0, y1), slice(x0, x1)), inside


def legendary_ellipse(ax, ay):
    """The Legendary clearance: an iso (2:1) ellipse 350 px wide whose bottom is the anchor."""
    rx = LEGENDARY / 2.0
    ry = rx / 2.0
    return ax, ay - ry, rx, ry


def dist_to_poly(px, py, poly):
    best = 1e9
    for a, b in zip(poly, poly[1:] + poly[:1]):
        ax, ay = a
        bx, by = b
        vx, vy = bx - ax, by - ay
        t = max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / (vx * vx + vy * vy)))
        best = min(best, math.hypot(px - ax - t * vx, py - ay - t * vy))
    return best


def point_in_poly(px, py, poly):
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi + 1e-12) + xi:
            inside = not inside
        j = i
    return inside


class Grid:
    """Cell lattice over the plate: cell (x, y) centre = cell00 + (32(x-y), 16(x+y))."""

    def __init__(self, cell00, width, height):
        self.c0 = cell00
        self.w = width
        self.h = height

    def centre(self, x, y):
        return (self.c0[0] + 32.0 * (x - y), self.c0[1] + 16.0 * (x + y))

    def cell_of(self, px, py):
        u = (px - self.c0[0]) / 32.0
        v = (py - self.c0[1]) / 16.0
        return (int(round((u + v) / 2.0)), int(round((v - u) / 2.0)))


def fit_lattice(zones, walk):
    """Choose cell00 so bridge decks (iso x rows) and the gate passage (iso y row) sit on cell centres."""
    cs = []
    for b in zones["bridges"]:
        a = b["entries"][0]["at"]
        c = b["entries"][1]["at"]
        cs.append(a[1] - 0.5 * a[0])
        slope = (c[1] - a[1]) / (c[0] - a[0])
        assert abs(slope - 0.5) < 0.01, "bridge %s is not on an iso axis (%.3f)" % (b["id"], slope)
    gate = zones["gates"][0]["arch"]
    d_gate = gate[1] + 0.5 * gate[0]
    # c residue: best common value for the bridges (minimise the worst offset).
    best = None
    for k in range(64):
        r = k * 0.5
        worst = max(abs(((c - r + 16) % 32) - 16) for c in cs)
        if best is None or worst < best[0]:
            best = (worst, r)
    c_res = best[1]
    d_res = d_gate % 32
    # O_y - 0.5 O_x = c_res, O_y + 0.5 O_x = d_res (mod 32)
    ox = (d_res - c_res) % 32
    oy = (c_res + d_res) / 2.0
    # Grid bounds: walkable pixels must map inside the grid.
    ys, xs = np.nonzero(walk)
    u = (xs - ox) / 32.0
    v = (ys - oy) / 16.0
    gx = (u + v) / 2.0
    gy = (v - u) / 2.0
    min_x, min_y = math.floor(gx.min()) - 1, math.floor(gy.min()) - 1
    max_x, max_y = math.ceil(gx.max()) + 1, math.ceil(gy.max()) + 1
    cell00 = (ox + 32.0 * (min_x - min_y), oy + 16.0 * (min_x + min_y))
    grid = Grid(cell00, max_x - min_x + 1, max_y - min_y + 1)
    residuals = []
    for b, c in zip(zones["bridges"], cs):
        off = ((c - c_res + 16) % 32) - 16
        residuals.append({"id": b["id"], "axis": "iso_x", "offset_px": round(off / math.sqrt(1.25), 2)})
    residuals.append({"id": zones["gates"][0]["id"], "axis": "iso_y", "offset_px": 0.0})
    return grid, residuals


def street_mask(ground_rgb, walk):
    g = ground_rgb.astype(np.int16)
    sat = g.max(2) - g.min(2)
    return (sat < 28) & (g.max(2) > 90) & walk


def alpha_bits(im):
    a = np.asarray(im)[..., 3] > 60
    h, w = a.shape
    bw, bh = (w + MASK_STEP - 1) // MASK_STEP, (h + MASK_STEP - 1) // MASK_STEP
    pad = np.zeros((bh * MASK_STEP, bw * MASK_STEP), bool)
    pad[:h, :w] = a
    bits = pad.reshape(bh, MASK_STEP, bw, MASK_STEP).any(axis=(1, 3))
    packed = np.packbits(bits.reshape(-1))
    return bw, bh, base64.b64encode(packed.tobytes()).decode("ascii")


def apply_change_list(layers, images, ground_np, walk, river, wall, zones):
    """Mauro's change list for the city base (look_target README, 16-17 Oct).

    4: cut the wall stubs off every tower and shrink the tower footprints.
    1-3: a gatehouse wherever a street meets the wall, plus a north gate with
    a street in and a road out toward Northgate. Mutates layers, images,
    ground_np and walk. Returns the log written to city.json.
    """
    log = {"modified": set(), "towers_cleaned": [], "gates": [], "contacts_before": [], "contacts_after": []}
    south = zones["gates"][0]
    known = [tuple(south["arch"])]
    log["contacts_before"] = CG.find_contacts(ground_np, river, wall, known)
    cx_city = sum(p[0] for p in wall) / len(wall)
    cy_city = sum(p[1] for p in wall) / len(wall)
    band = CG.line_mask(wall, 30)

    # -- 4: tower stubs
    towers = [l for l in layers if l["tag"] in ("tower", "tower_g")]
    city_in = np.asarray(_poly_img(wall)) > 0
    clean = None
    for l in towers:
        if clean is None:
            clean = CG.clean_tower(images[l["id"]])
        images[l["id"]] = clean.copy()
        log["modified"].add(l["id"])
        log["towers_cleaned"].append(l["id"])
        tx = l["x"] + images[l["id"]].width / 2.0
        ty = l["sort_y"] - 8.0
        old, new = CG.tower_footprints(tx, ty)
        sl, m = ellipse_mask(walk.shape, (old[0] + old[2]) / 2, (old[1] + old[3]) / 2, (old[2] - old[0]) / 2, (old[3] - old[1]) / 2)
        inside = city_in[sl]
        walk[sl] |= m & inside & ~band[sl] & ~river[sl]
        sl, m = ellipse_mask(walk.shape, (new[0] + new[2]) / 2, (new[1] + new[3]) / 2, (new[2] - new[0]) / 2, (new[3] - new[1]) / 2)
        walk[sl] &= ~m

    # -- 1-3: gates
    sample = CG.cobble_sampler(ground_np, CG.street_pixels(ground_np, river))
    back = images[next(l["id"] for l in layers if l["tag"] == "gate_back")]
    lintel = images[next(l["id"] for l in layers if l["tag"] == "lintel")]
    targets = []
    for c in log["contacts_before"]:
        if c["verdict"] in ("crosses", "dead_end"):
            targets.append({"why": c["verdict"], "at": c["at"], "edge": c["edge"]})
    # 2: north gate. The north street that comes closest to the north wall
    # (edge 1, between the corner towers) is extended to it.
    st = CG.street_pixels(ground_np, river)
    ne = int(LAYOUT.get("north_gate_edge", -1))
    if ne >= 0:
        na, nb = wall[ne], wall[(ne + 1) % len(wall)]
        x_lo, x_hi = int(min(na[0], nb[0]) + 0.15 * abs(nb[0] - na[0])), int(max(na[0], nb[0]) - 0.15 * abs(nb[0] - na[0]))
        y_hi = int(max(na[1], nb[1]) + 0.25 * PLATE_H)
        ys, xs = np.nonzero(st[:y_hi, x_lo:x_hi])
        k = int(np.argmin(ys))
        targets.append({"why": "north_gate", "at": [int(xs[k]) + x_lo, int(ys[k])], "edge": ne, "street": [int(xs[k]) + x_lo, int(ys[k])]})
    tower_rows = {l["id"]: (l["x"] + images[l["id"]].width / 2.0, l["sort_y"] - 8.0) for l in towers}
    next_id = 1000
    road_union = np.zeros(walk.shape, bool)
    for n, t in enumerate(targets):
        a, b = wall[t["edge"]], wall[(t["edge"] + 1) % len(wall)]
        slope = (b[1] - a[1]) / (b[0] - a[0])
        L = math.dist(a, b)
        ux, uy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        if t["why"] == "crosses":
            # centre of the street where it crosses the wall line
            m = st & CG.line_mask(wall, 24)
            yy, xx = np.nonzero(m[max(0, t["at"][1] - 120):t["at"][1] + 120, max(0, t["at"][0] - 120):t["at"][0] + 120])
            q0 = (float(xx.mean()) + max(0, t["at"][0] - 120), float(yy.mean()) + max(0, t["at"][1] - 120))
        else:
            q0 = t["at"]
        q0 = CG.project_on_edge(wall, t["edge"], q0[0], q0[1])
        inward = (cx_city - q0[0], cy_city - q0[1])
        nrm = math.hypot(*inward)
        inward = (inward[0] / nrm, inward[1] / nrm)
        # Slide along the wall (at most 90 px) so the gatehouse clears the towers
        # and the wall corners; drop a tower only when no slide works.
        half = None
        best = None
        for shift in sorted(range(-90, 91, 3), key=abs):
            q = (q0[0] + ux * shift, q0[1] + uy * shift)
            g = CG.fit_gate(back, lintel, q, slope, inward)
            half = math.dist(g["WL"], g["WR"]) / 2.0 + 40.0
            ok = all(math.dist(q, tp) > half + 30 for tp in tower_rows.values())
            ok = ok and math.dist(q, a) > half + 40 and math.dist(q, b) > half + 40
            if ok:
                best = g
                break
        dropped = []
        if best is None:
            best = CG.fit_gate(back, lintel, q0, slope, inward)
            for tid, tp in list(tower_rows.items()):
                if math.dist(q0, tp) < half + 30:
                    dropped.append(tid)
                    tower_rows.pop(tid)
            layers[:] = [l for l in layers if l["id"] not in dropped]
        g = best
        q = g["q"]
        u, v = g["u"], g["v"]
        half_span = math.dist(g["WL"], g["WR"]) / 2.0
        # Sprites: two new layers.
        cut = CG.cut_walls(layers, images, g)
        for lid, how in cut:
            log["modified"].add(lid)
        layers[:] = [l for l in layers if not (l["id"] in dict(cut) and dict(cut)[l["id"]] == "removed")]
        passage = CG.quad(q, u, v, -120.0, 150.0, CG.PASSAGE_HALF)
        py_min = min(p[1] for p in passage)
        lb = np.asarray(g["lintel"])[..., 3] > 40
        lint_bottom = g["pos"][1] + int(np.nonzero(lb.any(1))[0].max())
        gid = "gate_%d" % (n + 1)
        for tag, im, sort_y in (("gate_back", g["back"], py_min - 10.0), ("lintel", g["lintel"], float(lint_bottom) + 2.0)):
            lid = next_id
            next_id += 1
            images[lid] = im
            layers.append({"id": lid, "file": "layers/%d_%s_%s.png" % (lid, gid, tag), "tag": tag,
                           "x": g["pos"][0], "y": g["pos"][1], "sort_y": sort_y, "under_everything": False,
                           "fade": "occluding_only", "fade_min_alpha": 0.40 if tag == "lintel" else 0.45})
            log["modified"].add(lid)
        # Walk: gatehouse footprint blocks, the arch passage opens.
        foot = CG.poly_mask(CG.quad(q, u, v, -24.0, 70.0, half_span + 10.0))
        walk &= ~foot
        pm = CG.poly_mask(passage)
        walk |= pm & ~river
        # Roads: inside to the nearest street, outside to the plate edge.
        roads = []
        p_in = (q[0] + u[0] * 150.0, q[1] + u[1] * 150.0)
        p_out = (q[0] - u[0] * 120.0, q[1] - u[1] * 120.0)
        st_now = CG.street_pixels(ground_np, river)
        for end, sign in ((p_in, 1.0), (p_out, -1.0)):
            ex, ey = int(end[0]), int(end[1])
            win = st_now[max(0, ey - 30):ey + 30, max(0, ex - 30):ex + 30]
            if win.size and win.mean() > 0.3:
                continue
            target = t.get("street") if sign > 0 else None
            if sign > 0:
                if target is None:
                    yy, xx = np.nonzero(st_now)
                    dd = (xx - end[0]) ** 2 + (yy - end[1]) ** 2
                    ok = ~CG.poly_mask(passage)[yy, xx]
                    j = int(np.argmin(np.where(ok, dd, 1e18)))
                    target = [int(xx[j]), int(yy[j])]
                pts = [q, end, tuple(target)]
            else:
                # straight out along the passage axis to the plate edge
                tmax = 4000.0
                for lim, comp in ((0.0, 0), (PLATE_W - 1.0, 0), (0.0, 1), (PLATE_H - 1.0, 1)):
                    d_ = -u[comp]
                    if abs(d_) > 1e-6:
                        tt = (lim - end[comp]) / d_
                        if tt > 0:
                            tmax = min(tmax, tt)
                far = (end[0] - u[0] * tmax, end[1] - u[1] * tmax)
                pts = [q, end, far]
            hard = CG.paint_road(ground_np, walk, sample, pts)
            walk |= hard & ~(band & ~pm) & ~river & ~foot
            road_union |= hard
            roads.append([[round(p[0], 1), round(p[1], 1)] for p in pts])
        log["gates"].append({
            "id": gid, "why": t["why"], "edge": t["edge"], "wall_slope": round(slope, 3),
            "shear": g["kk"], "mirrored": g["flip"], "arch": [round(q[0], 1), round(q[1], 1)],
            "wall_join_left": [round(c, 1) for c in g["WL"]], "wall_join_right": [round(c, 1) for c in g["WR"]],
            "passage": [[round(p[0], 1), round(p[1], 1)] for p in passage],
            "art": "south gate cw4_gate_open (its gate_back + gate_front_lintel layers), mirrored if the wall falls, vertical shear to the wall slope",
            "walls_cut": [lid for lid, _ in cut], "towers_dropped": dropped, "roads_painted": roads,
        })
    # Trees, plants and lamps standing on a new road are lifted off it.
    near_road = ndi_dilate(road_union, 10)
    lifted = []
    for l in layers:
        if l["tag"] in LOOSE_TAGS:
            fx = int(l["x"] + images[l["id"]].width / 2.0)
            fy = int(l["sort_y"])
            if 0 <= fx < PLATE_W and 0 <= fy < PLATE_H and near_road[fy, fx]:
                lifted.append(l["id"])
    layers[:] = [l for l in layers if l["id"] not in lifted]
    log["lifted_off_roads"] = lifted
    # The south gate itself, for the record and the tests.
    log["gates"].insert(0, {"id": "gate_0", "why": "existing", "edge": 5, "arch": south["arch"],
                            "passage": south["passage"], "art": "handoff south gate (unchanged)"})
    log["contacts_after"] = CG.find_contacts(ground_np, river, wall, [tuple(g["arch"]) for g in log["gates"]])
    for c in log["contacts_after"]:
        print("contact after", c)
    return log


def ndi_dilate(m, n):
    from scipy.ndimage import binary_dilation
    return binary_dilation(m, iterations=n)


def _poly_img(poly):
    img = Image.new("L", (PLATE_W, PLATE_H), 0)
    ImageDraw.Draw(img).polygon(poly, fill=255)
    return img


def main():
    src = sys.argv[1]
    repo = sys.argv[2]
    lay_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "layout_rosebud_v9.json")
    if "--layout" in sys.argv:
        lay_path = sys.argv[sys.argv.index("--layout") + 1]
    LAYOUT.update(json.load(open(lay_path)))
    debug = None
    if "--debug" in sys.argv:
        debug = sys.argv[sys.argv.index("--debug") + 1]
        os.makedirs(debug, exist_ok=True)
    rb = os.path.join(src, "rosebud")
    zones = json.load(open(os.path.join(rb, "zones.json")))
    routes = json.load(open(os.path.join(rb, "routes.json")))
    layers_doc = json.load(open(os.path.join(rb, "layers.json")))
    tiers = json.load(open(os.path.join(src, "housing_tiers", "tiers.json")))
    walk = load_mask(os.path.join(rb, "walkmask.png")).copy()
    river = load_mask(os.path.join(rb, "river.png"))
    heights = np.asarray(Image.open(os.path.join(rb, "heightmap.png")).convert("L")).astype(np.float32)
    ground = Image.open(os.path.join(rb, "ground.jpg")).convert("RGB")
    global PLATE_W, PLATE_H
    PLATE_W, PLATE_H = ground.size
    CG.PLATE_W, CG.PLATE_H = ground.size
    ground_np = np.array(ground)
    wall_poly = [tuple(map(float, p)) for p in LAYOUT["wall_polygon"]]

    layers = layers_doc["layers"]
    PLOTS[:] = [{"id": p["id"], "tier": p["tier"], "label_tier": p["label_tier"]} for p in LAYOUT["plots"]]
    OLD_PLOT_LAYERS.clear()
    for p in LAYOUT["plots"]:
        best = None
        for l in layers:
            if l["tag"] != "house" or "house_" not in os.path.basename(l["file"]) or l["id"] in OLD_PLOT_LAYERS.values():
                continue
            im_ = Image.open(os.path.join(rb, l["file"]))
            d_ = math.hypot(l["x"] + im_.width / 2.0 - p["old_anchor"][0], l["sort_y"] - p["old_anchor"][1])
            if best is None or d_ < best[0]:
                best = (d_, l["id"])
        if best is not None and best[0] < 40:
            OLD_PLOT_LAYERS[p["id"]] = best[1]
    images = {}
    for l in layers:
        images[l["id"]] = Image.open(os.path.join(rb, l["file"])).convert("RGBA")

    # ---- Mauro's change list: tower stubs (4), gates at every road-wall contact (1-3)
    gate_log = apply_change_list(layers, images, ground_np, walk, river, wall_poly, zones)
    ground = Image.fromarray(ground_np)

    # ---- masks used for plot placement
    streets = street_mask(ground_np, walk)
    wall_sprites = np.zeros((PLATE_H, PLATE_W), bool)
    hard = np.zeros((PLATE_H, PLATE_W), bool)  # landmarks, houses, stalls: whole sprite
    for l in layers:
        im = images[l["id"]]
        a = np.asarray(im)[..., 3] > 40
        x, y = int(l["x"]), int(l["y"])
        h, w = a.shape
        ys = slice(max(0, y), min(PLATE_H, y + h))
        xs = slice(max(0, x), min(PLATE_W, x + w))
        part = a[ys.start - y:ys.stop - y, xs.start - x:xs.stop - x]
        if l["tag"] in WALL_TAGS:
            wall_sprites[ys, xs] |= part
        elif l["tag"] not in LOOSE_TAGS and l["id"] not in OLD_PLOT_LAYERS.values():
            hard[ys, xs] |= part

    # ---- free the old plot ground: old house footprints and their plants
    old_anchor = {}
    for pid, lid in OLD_PLOT_LAYERS.items():
        l = next(q for q in layers if q["id"] == lid)
        im = images[lid]
        old_anchor[pid] = (l["x"] + im.width / 2.0, l["sort_y"])

    def near_wall(px, py, margin):
        return dist_to_poly(px, py, wall_poly) < margin

    def unblock_ellipse(cx, cy, rx, ry):
        sl, m = ellipse_mask(walk.shape, cx, cy, rx, ry)
        ys, xs = np.nonzero(m)
        for yy, xx in zip(ys + sl[0].start, xs + sl[1].start):
            if not river[yy, xx] and point_in_poly(xx, yy, wall_poly) and not near_wall(xx, yy, 40):
                walk[yy, xx] = True

    plot_plants = {pid: [] for pid in old_anchor}
    for l in layers:
        if l["tag"] != "prop":
            continue
        im = images[l["id"]]
        ax, ay = l["x"] + im.width / 2.0, l["sort_y"]
        for pid, (px, py) in old_anchor.items():
            if abs(ax - px) < 200 and abs(ay - py) < 110:
                plot_plants[pid].append(l["id"])
                break
    for pid, (px, py) in old_anchor.items():
        im = images[OLD_PLOT_LAYERS[pid]]
        unblock_ellipse(px, py - (im.height * 0.36 - 6) / 2.0, im.width * 0.45 + 2, (im.height * 0.36 + 6) / 2.0 + 2)
    for pid, ids in plot_plants.items():
        for lid in ids:
            l = next(q for q in layers if q["id"] == lid)
            im = images[lid]
            ax, ay = l["x"] + im.width / 2.0, l["sort_y"]
            fh = max(8, im.height * 0.32)
            unblock_ellipse(ax, ay - fh / 2.0, im.width * 0.43 + 2, fh / 2.0 + 2)

    # ---- plot search
    grid, residuals = fit_lattice(zones, walk)
    hard_d = hard.copy()
    # Grow the "keep clear" masks a little: touching is not allowed.
    from scipy.ndimage import binary_dilation
    st_d = binary_dilation(streets, iterations=6)
    wall_d = binary_dilation(wall_sprites, iterations=10)
    blockers = st_d | wall_d | river | hard_d
    outside = np.ones_like(walk)
    poly_img = Image.new("L", (PLATE_W, PLATE_H), 0)
    ImageDraw.Draw(poly_img).polygon(wall_poly, fill=255)
    outside = np.asarray(poly_img) < 128
    blockers |= outside

    loose = []
    for l in layers:
        if l["tag"] in LOOSE_TAGS:
            im = images[l["id"]]
            loose.append((l["id"], l["x"] + im.width / 2.0, l["sort_y"]))

    # A 2:1 ellipse is a circle once y is doubled: clear iff the distance to
    # the nearest blocker (in doubled-y space) exceeds the radius.
    from scipy.ndimage import distance_transform_edt
    edt = distance_transform_edt(~np.repeat(blockers, 2, axis=0))

    def clear_of(ax, ay):
        cx, cy, rx, ry = legendary_ellipse(ax, ay)
        iy, ix = int(round(cy * 2)), int(round(cx))
        if not (0 <= ix < PLATE_W and 0 <= iy < PLATE_H * 2):
            return False
        return edt[iy, ix] > rx + 1

    def front_cells(ax, ay):
        c1 = grid.cell_of(ax, ay + 22)
        return c1

    # Candidate anchors on an 8 px raster.
    cands = []
    bx = LAYOUT["plot_search_box"]
    x0, y0, x1, y1 = int(bx[0] * PLATE_W), int(bx[1] * PLATE_H), int(bx[2] * PLATE_W), int(bx[3] * PLATE_H)
    for ay in range(y0, y1, 8):
        for ax in range(x0, x1, 8):
            if clear_of(ax, ay):
                cands.append((ax, ay))
    print("plot candidates", len(cands))
    if debug:
        dbg = Image.fromarray((blockers * 160).astype("uint8"))
        dd = ImageDraw.Draw(dbg)
        for ax, ay in cands:
            dd.point((ax, ay), fill=255)
        dbg.resize((1280, 720)).save(os.path.join(debug, "plot_candidates.png"))

    def loose_hits(ax, ay):
        cx, cy, rx, ry = legendary_ellipse(ax, ay)
        out = []
        for lid, lx, ly in loose:
            if ((lx - cx) / (rx + 20)) ** 2 + ((ly - cy) / (ry + 14)) ** 2 <= 1.0:
                out.append(lid)
        return out

    def disjoint(a, b):
        ca = legendary_ellipse(*a)
        cb = legendary_ellipse(*b)
        # Two equal axis-aligned 2:1 ellipses: scale y by 2 -> circles.
        d = math.hypot(ca[0] - cb[0], (ca[1] - cb[1]) * 2.0)
        return d > 2 * ca[2] + 16

    chosen = []
    targets = [old_anchor[p["id"]] for p in PLOTS]
    # Greedy per plot: nearest candidate to the old spot that is disjoint from
    # the plots placed so far, costing removed trees and props.
    order = sorted(range(len(PLOTS)), key=lambda i: 0 if PLOTS[i]["tier"] == "legendary" else 1)
    picked = {}
    for i in order:
        tx, ty = targets[i]
        best = None
        for c in cands:
            if not all(disjoint(c, o) for o in picked.values()):
                continue
            cost = math.hypot(c[0] - tx, (c[1] - ty) * 2.0) + 140.0 * len(loose_hits(*c))
            if best is None or cost < best[0]:
                best = (cost, c)
        if best is None:
            raise SystemExit("no room for plot %s" % PLOTS[i]["id"])
        picked[i] = best[1]
    removed = set()
    for i, p in enumerate(PLOTS):
        ax, ay = picked[i]
        chosen.append((p, ax, ay))
        removed |= set(loose_hits(ax, ay))
    print("plots", [(p["id"], ax, ay) for p, ax, ay in chosen], "removed loose layers", len(removed))

    # Free the footprints of removed trees and props.
    for lid in removed:
        l = next(q for q in layers if q["id"] == lid)
        im = images[lid]
        ax, ay = l["x"] + im.width / 2.0, l["sort_y"]
        fh = max(8, im.height * (0.12 if l["tag"] == "tree" else 0.32))
        fw = im.width * (0.3 if l["tag"] == "tree" else 0.86)
        unblock_ellipse(ax, ay - fh / 2.0, fw / 2.0 + 3, fh / 2.0 + 3)

    # Block the new houses' footprints (same ellipse rule as the handoff's place_plot).
    house_img = {t: Image.open(os.path.join(src, "housing_tiers", "house_%s.png" % t)).convert("RGBA") for t in CLEARANCE}
    for p, ax, ay in chosen:
        hs = house_img[p["tier"]]
        x0e, y0e, x1e, y1e = ax - hs.width * 0.45, ay - hs.height * 0.36, ax + hs.width * 0.45, ay + 6
        sl, m = ellipse_mask(walk.shape, (x0e + x1e) / 2, (y0e + y1e) / 2, (x1e - x0e) / 2, (y1e - y0e) / 2)
        walk[sl] &= ~m

    # ---- cells
    W, H = grid.w, grid.h
    inner_off = []
    for dy in range(-8, 9, 2):
        for dx in range(-16, 17, 2):
            if abs(dx) / 16.0 + abs(dy) / 8.0 <= 1.0:
                inner_off.append((dx, dy))
    kind = np.zeros((H, W), np.uint8)  # 0 void, 1 grass, 2 street, 3 water, 4 blocked
    hgt = np.zeros((H, W), np.int32)
    for y in range(H):
        for x in range(W):
            cx, cy = grid.centre(x, y)
            ix, iy = int(round(cx)), int(round(cy))
            if not (0 <= ix < PLATE_W and 0 <= iy < PLATE_H):
                continue
            ok = 0
            n = 0
            for dx, dy in inner_off:
                qx, qy = ix + dx, iy + dy
                if 0 <= qx < PLATE_W and 0 <= qy < PLATE_H:
                    n += 1
                    ok += walk[qy, qx]
            if heights[iy, ix] > 0:
                # Deck and stair pixels: the Rosebud walkmask and heightmap
                # hold them where the feet are drawn (ground y - z). Cells
                # are ground points, so bridges are laid below from their
                # ground lines instead.
                kind[y, x] = 3 if river[iy, ix] else 4
            elif walk[iy, ix] and ok >= 0.6 * len(inner_off):
                kind[y, x] = 2 if streets[iy, ix] else 1
            elif river[iy, ix]:
                kind[y, x] = 3
            else:
                kind[y, x] = 4
    # Bridges on the ground: the stair bottoms (z = 0) fix the ground line;
    # z along it is the Rosebud centreline z by screen x (a lift is vertical).
    for b in zones["bridges"]:
        a_ = b["entries"][0]["at"]
        c_ = b["entries"][1]["at"]
        xs_ = [p[0] for p in b["centreline"]]
        zs_ = list(b["centreline_z"])
        order = np.argsort(xs_)
        xs_ = list(np.array(xs_)[order])
        zs_ = list(np.array(zs_, dtype=float)[order])
        lx, ly = c_[0] - a_[0], c_[1] - a_[1]
        ln = math.hypot(lx, ly)
        for y in range(H):
            for x in range(W):
                cx, cy = grid.centre(x, y)
                t = ((cx - a_[0]) * lx + (cy - a_[1]) * ly) / (ln * ln)
                perp = abs((cx - a_[0]) * ly - (cy - a_[1]) * lx) / ln
                if -0.02 <= t <= 1.02 and perp <= 16.0:
                    kind[y, x] = 2
                    hgt[y, x] = int(round(float(np.interp(cx, xs_, zs_)) / 10.0))

    # Spawn and exit: the south road end at the plate edge (rosebud spawn.hero).
    sx, sy = zones["spawn"]["hero"]
    walkable = (kind == 1) | (kind == 2)

    def nearest(px, py):
        best = None
        for y in range(H):
            for x in range(W):
                if walkable[y, x]:
                    cx, cy = grid.centre(x, y)
                    d = math.hypot(cx - px, cy - py)
                    if best is None or d < best[0]:
                        best = (d, (x, y))
        return best[1]

    exit_cell = nearest(sx, sy)
    # Keep the component that holds the exit; the rest are crumbs under sprites.
    seen = np.zeros((H, W), bool)
    q = deque([exit_cell[::-1]])
    seen[exit_cell[1], exit_cell[0]] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and walkable[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    crumbs = int((walkable & ~seen).sum())
    kind[walkable & ~seen] = 4
    walkable = seen
    print("grid", W, H, "walkable", int(walkable.sum()), "dropped crumbs", crumbs)

    # Arrival: four cells up the road from the exit, toward the gate.
    gx, gy = zones["gates"][0]["arch"]
    arrive = exit_cell
    best = None
    for y in range(H):
        for x in range(W):
            if walkable[y, x]:
                cx, cy = grid.centre(x, y)
                d_exit = math.hypot(cx - grid.centre(*exit_cell)[0], cy - grid.centre(*exit_cell)[1])
                if 120 < d_exit < 200:
                    d = math.hypot(cx - gx, cy - gy)
                    if best is None or d < best[0]:
                        best = (d, (x, y))
    if best:
        arrive = best[1]

    # Rows: one char per cell. '.' void '#' blocked '~' water 'g' grass 'r' street.
    sym = {0: ".", 1: "g", 2: "r", 3: "~", 4: "#"}
    rows = ["".join(sym[int(k)] for k in kind[y]) for y in range(H)]
    hrows = []
    hcells = []
    for y in range(H):
        for x in range(W):
            if hgt[y, x] > 0 and walkable[y, x]:
                hcells.append([x, y, int(hgt[y, x])])

    def cellpx(c):
        return [round(v, 1) for v in grid.centre(*c)]

    # Gates and bridges in cells (tests walk them).
    gate_cells = []
    pas = zones["gates"][0]["passage"]
    for y in range(H):
        for x in range(W):
            if walkable[y, x]:
                cx, cy = grid.centre(x, y)
                if point_in_poly(cx, cy, pas):
                    gate_cells.append([x, y])
    gates_out = []
    for g in gate_log["gates"]:
        cells = []
        for y in range(H):
            for x in range(W):
                if walkable[y, x] and point_in_poly(*grid.centre(x, y), g["passage"]):
                    cells.append([x, y])
        rec = dict(g)
        rec["cells"] = cells
        gates_out.append(rec)
    bridges = []
    for b in zones["bridges"]:
        ends = []
        for e in b["entries"]:
            ends.append(list(nearest(*e["approach"])))
        deck = []
        for y in range(H):
            for x in range(W):
                if walkable[y, x] and hgt[y, x] >= 4:
                    cx, cy = grid.centre(x, y)
                    x0b, y0b, x1b, y1b = b["sprite_bbox"]
                    if x0b <= cx <= x1b and y0b <= cy <= y1b + 80:
                        deck.append([x, y])
        bridges.append({"id": b["id"], "ends": ends, "deck_cells": deck,
                        "crown_px": max(b["centreline_z"]), "sprite_bbox": b["sprite_bbox"]})

    # Plot records.
    plots = []
    for p, ax, ay in chosen:
        f1 = grid.cell_of(ax, ay + 22)
        # second front cell: the walkable ortho neighbour further down screen.
        cands2 = [(f1[0] + 1, f1[1]), (f1[0], f1[1] + 1)]
        f2 = next((c for c in cands2 if 0 <= c[0] < W and 0 <= c[1] < H and walkable[c[1], c[0]]), cands2[0])
        plots.append({
            "id": p["id"],
            "tier": p["tier"],
            "label_tier": p["label_tier"],
            "anchor_px": [ax, ay],
            "old_anchor_px": [round(v, 1) for v in old_anchor[p["id"]]],
            "front_cells": [list(f1), list(f2)],
        })

    # ---- layers out
    art_dir = os.path.join(repo, "art/world/crosshaven_city")
    data_dir = os.path.join(repo, "data/world/crosshaven_city")
    for d in ("layers", "housing", "pets"):
        os.makedirs(os.path.join(art_dir, d), exist_ok=True)
    os.makedirs(data_dir, exist_ok=True)
    dropped = set(OLD_PLOT_LAYERS.values()) | removed
    moved = {}
    for (p, ax, ay) in chosen:
        ox, oy = old_anchor[p["id"]]
        for lid in plot_plants[p["id"]]:
            moved[lid] = (ax - ox, ay - oy)
    out_layers = []
    for l in layers:
        lid = l["id"]
        if lid in dropped:
            continue
        im = images[lid]
        dx, dy = moved.get(lid, (0, 0))
        name = os.path.basename(l["file"])
        if lid in gate_log["modified"]:
            images[lid].save(os.path.join(art_dir, "layers", name), optimize=True)
        else:
            shutil.copyfile(os.path.join(rb, l["file"]), os.path.join(art_dir, "layers", name))
        under = bool(l.get("under_everything", False))
        # Luca's rule: every obstacle fades when the hero is behind it. The
        # Rosebud export kept walls, workshops and stalls opaque; here every
        # sprite tall enough to hide the hero fades, bridges stay under.
        fade = (not under) and im.height >= FADE_MIN_HEIGHT
        rec = {
            "id": lid, "file": "layers/" + name, "tag": l["tag"],
            "x": int(round(l["x"] + dx)), "y": int(round(l["y"] + dy)),
            "w": im.width, "h": im.height,
            "sort_y": round(float(l["sort_y"] if l.get("sort_y") is not None else l["y"] + im.height) + dy, 1),
            "under": under, "fade": fade,
            "fade_min_alpha": float(l.get("fade_min_alpha", 0.45)),
        }
        if lid in moved:
            rec["plot_plant"] = True
        if fade:
            bw, bh, bits = alpha_bits(im)
            rec["mask"] = {"step": MASK_STEP, "w": bw, "h": bh, "bits": bits}
        out_layers.append(rec)
    for t in CLEARANCE:
        shutil.copyfile(os.path.join(src, "housing_tiers", "house_%s.png" % t), os.path.join(art_dir, "housing", "house_%s.png" % t))
    house_masks = {}
    for t, im in house_img.items():
        bw, bh, bits = alpha_bits(im)
        house_masks[t] = {"w": im.width, "h": im.height, "mask": {"step": MASK_STEP, "w": bw, "h": bh, "bits": bits}}
    for pet in ("pet_dog", "pet_cat"):
        shutil.copyfile(os.path.join(rb, "layers", pet + ".png"), os.path.join(art_dir, "pets", pet + ".png"))
    ground.save(os.path.join(art_dir, "ground.jpg"), quality=90)
    ground.resize((PLATE_W // 2, PLATE_H // 2), Image.LANCZOS).save(os.path.join(art_dir, "ground_lite.jpg"), quality=88)

    pets = []
    for pt in routes.get("pets", []):
        pets.append({"name": pt["name"], "sprite": "pets/" + os.path.basename(pt["sprite"]),
                     "a": [round(v, 1) for v in pt["a"]], "b": [round(v, 1) for v in pt["b"]],
                     "speed": pt["speed"], "pause": pt["pause"], "hop_px": pt["hop_px"],
                     "night": "out" if "cat" in pt["name"] else "indoors"})
    # Townsfolk: the Rosebud route names are the game's NPC roles. Each gets
    # the walkable cell nearest its Rosebud post; the world's roam rules move
    # them. Night: only the warden stays out (lantern patrol); the rest go in.
    npcs = []
    used = set()
    for n in routes.get("npcs", []):
        if n.get("type") == "walker_pingpong":
            at = n["path"][0]
        elif n.get("type") == "patrol":
            at = n["a"]
        else:
            at = n["at"]
        c = nearest(*at)
        k = 0
        while tuple(c) in used and k < 8:
            c = (c[0] + 1, c[1])
            k += 1
        used.add(tuple(c))
        npcs.append({"id": "city_" + n["name"], "role": n["name"], "name": n["name"].replace("_", " ").title(),
                     "cell": {"x": int(c[0]), "y": int(c[1])}, "facing": str(n.get("facing", "S")),
                     "night": "out" if n["name"] == "warden" else "indoors"})

    city = {
        "format": "stasium.plate_city",
        "format_version": 1,
        "zone_id": "crosshaven_city",
        "region": "crosshaven_city",
        "name": "Crosshaven (walled city prototype)",
        "status": "prototype",
        "source": "docs/pc-map-handoff 98d2cc5c docs/pc/map_handoff/crosshaven/rosebud (v9)",
        "plate": {
            "size": [PLATE_W, PLATE_H],
            "ground": "ground.jpg",
            "ground_lite": "ground_lite.jpg",
            "art_root": "res://art/world/crosshaven_city/",
            "scale": 1.0,
            "cell00_px": [round(grid.c0[0], 2), round(grid.c0[1], 2)],
            "anchor": "plate pixel cell00_px lands on cell_to_local(0, 0); node position = -cell00_px",
            "fit": {
                "iso_slope_bridges": 0.5,
                "iso_slope_gate_passage": 0.5,
                "ground_texture_lattice_px": [128, 64],
                "rosebud_hero_px": 56,
                "residuals": residuals,
            },
        },
        "grid": {
            "width": W, "height": H,
            "legend": {".": "void (off the plate)", "#": "blocked", "~": "water", "g": "grass", "r": "street"},
            "rows": rows,
            "heights": hcells,
            "height_px_per_step": 10,
        },
        "spawn": list(arrive),
        "exit_cell": list(exit_cell),
        "gate_cells": gate_cells,
        "wall_polygon": [[round(a, 1), round(b, 1)] for a, b in wall_poly],
        "gates": gates_out,
        "wall_contacts": {"before": gate_log["contacts_before"], "after": gate_log["contacts_after"]},
        "towers_cleaned": gate_log["towers_cleaned"],
        "bridges": bridges,
        "plots": plots,
        "plot_rules": {
            "clearance_px": CLEARANCE,
            "legendary_ellipse": "iso ellipse 350x175 px whose bottom point is the anchor",
            "tier_art": {t: "housing/house_%s.png" % t for t in CLEARANCE},
            "house_art": house_masks,
            "footprint": "blocking ellipse 0.9w x 0.36h above the anchor (handoff place_plot)",
            "note": "Tier is data: change plots[].tier to swap the exterior in place. No garden beds, fences or yards (Luca).",
        },
        "pets": pets,
        "npcs": npcs,
        "day_hours": [6.0, 20.0],
        "gate_stubs": [
            {"id": "crossroads_to_city", "from": {"zone_id": "crosshaven_crossroads", "x": LAYOUT["crossroads_stub"]["from"][0], "y": LAYOUT["crossroads_stub"]["from"][1]},
             "to": {"zone_id": "crosshaven_city", "x": arrive[0], "y": arrive[1]},
             "label": "Crosshaven walled city (prototype)", "enabled": True},
            {"id": "city_to_crossroads", "from": {"zone_id": "crosshaven_city", "x": exit_cell[0], "y": exit_cell[1]},
             "to": {"zone_id": "crosshaven_crossroads", "x": LAYOUT["crossroads_stub"]["to"][0], "y": LAYOUT["crossroads_stub"]["to"][1]},
             "label": "To the Crossroads", "enabled": True},
        ],
        "layers": "layers.json",
    }
    json.dump(city, open(os.path.join(data_dir, "city.json"), "w"), indent=1)
    json.dump({"format": "stasium.plate_layers", "format_version": 1, "layers": out_layers},
              open(os.path.join(data_dir, "layers.json"), "w"), separators=(",", ":"))
    print("layers", len(out_layers), "fading", sum(1 for l in out_layers if l["fade"]))
    print("cell00", grid.c0, "residuals", residuals)
    print("spawn", arrive, "exit", exit_cell, "gate cells", len(gate_cells))
    for b in bridges:
        print(b["id"], "ends", b["ends"], "deck", len(b["deck_cells"]))

    if debug:
        plate = Image.open(os.path.join(rb, "plate.jpg")).convert("RGB")
        ov = np.asarray(plate).copy()
        ov[~walk] = (ov[~walk] * 0.5 + np.array([200, 30, 30]) * 0.5).astype("uint8")
        im = Image.fromarray(ov)
        d = ImageDraw.Draw(im)
        for y in range(H):
            for x in range(W):
                if walkable[y, x]:
                    cx, cy = grid.centre(x, y)
                    col = (255, 255, 0) if hgt[y, x] > 0 else (0, 255, 255)
                    d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=col)
        for p, ax, ay in chosen:
            cx, cy, rx, ry = legendary_ellipse(ax, ay)
            d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=(255, 0, 255), width=4)
            d.text((ax, ay + 8), p["id"], fill=(255, 0, 255))
        im.save(os.path.join(debug, "cells_overlay.jpg"), quality=85)


if __name__ == "__main__":
    main()
