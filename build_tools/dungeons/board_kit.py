"""Generic combat-board kit builder (floor tiles, glowing pads, props, floor decals, backdrops).

One `Board` per dungeon; the per-dungeon scripts (build_granary_board.py,
build_frostspire_board.py) only hold the piece list and the numbers. The
defaults here are the Old Granary Cellar's, and the Granary output must stay
byte-identical (check_granary_repro.py).

Board math is board_view.gd / BoardVisualSort: cell centre
cell_to_local(x, y) = ((x - y) * 32, (x + y) * 16), 64x32 diamonds.

* Floor tiles: top-down slab paintings mapped onto the 64x32 diamond
  (and 128x64 for the 2x master). Each slab is cropped on its painted grout
  line, so neighbouring tiles share a full grout line and tile seamlessly.
  Draw like KoliseoArt full-bleed tiles: centred on the cell centre.
* Props: chroma-keyed paintings, image bottom-centre on the south tip of the
  south-most footprint cell (tile.gd `_paint_prop`).
* Decals (drain grate, rune circle): full footprint-diamond canvas, ground layer.
* Glows: additive RGB, binary alpha, black elsewhere.
* Backdrops: the room shell painting, affinely fitted so its painted key-colour
  floor matches the NxN board diamond, with the board diamond cut out (alpha 0)
  and the dark surround keyed out.
"""
import os

import cv2
import numpy as np

import gkit

WARM = (1.0, 0.66, 0.2)


def key_excess(rgb, key):
    """How strongly each pixel is the key colour (green: g - max(r,b); magenta: min(r,b) - g)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    if key == "magenta":
        return np.minimum(r, b) - g
    return g - np.maximum(r, b)


def keyer(key):
    return gkit.key_magenta if key == "magenta" else gkit.key_green


def addglow(gray, col):
    g8 = np.clip(gray[..., None] * np.array(col, np.float32) * 255 + 0.5, 0, 255).astype(np.uint8)
    on = g8.max(-1) >= 3
    out = np.zeros(gray.shape + (4,), np.uint8)
    out[..., :3] = np.where(on[..., None], g8, 0)
    out[..., 3] = np.where(on, 255, 0)
    return out


def grout_crop(rgb):
    L = rgb.mean(-1)
    h, w = L.shape
    t = int(np.argmin(L[:50].mean(1)))
    b = h - 1 - int(np.argmin(L[-50:][::-1].mean(1)))
    lf = int(np.argmin(L[:, :50].mean(0)))
    r = w - 1 - int(np.argmin(L[:, -50:][:, ::-1].mean(0)))
    return rgb[t:b + 1, lf:r + 1]


def fit_floor_corners(green):
    """Corners (top, right, bottom, left) of the painted floor diamond.

    Each edge is a robust line fit (Huber) through the key region's contour
    points nearest to that edge of the rough extreme-point diamond; corners are
    the intersections of adjacent edge lines. This ignores clutter bumps at the
    wall bases far better than the raw extreme points.
    """
    ys, xs = np.nonzero(green)
    rough = np.array([
        [xs[ys.argmin()], ys.min()], [xs.max(), ys[xs.argmax()]],
        [xs[ys.argmax()], ys.max()], [xs.min(), ys[xs.argmin()]]], np.float32)
    cs, _ = cv2.findContours(green.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    pts = max(cs, key=len)[:, 0, :].astype(np.float32)
    lines = []
    for i in range(4):
        a, b = rough[i], rough[(i + 1) % 4]
        ab = b - a
        t = ((pts - a) @ ab) / (ab @ ab)
        proj = a + np.clip(t, 0, 1)[:, None] * ab
        dist = np.linalg.norm(pts - proj, axis=1)
        sel = pts[(t > 0.12) & (t < 0.88) & (dist < 40)]
        vx, vy, x0, y0 = cv2.fitLine(sel, cv2.DIST_HUBER, 0, 0.01, 0.01).ravel()
        lines.append((np.array([x0, y0]), np.array([vx, vy])))
    corners = []
    for i in range(4):
        p1, d1 = lines[(i - 1) % 4]
        p2, d2 = lines[i]
        A = np.array([d1, -d2]).T
        st = np.linalg.solve(A, p2 - p1)
        corners.append(p1 + st[0] * d1)
    return np.array(corners, np.float32)


class Board:
    def __init__(self, key="green", floor_fill=(28, 22, 18)):
        self.dir = os.path.join(gkit.OUT, "board")
        self.key = key
        self.floor_fill = floor_fill
        self.META = {"tiles": [], "props": [], "decals": [], "glows": [], "backdrops": []}

    def _path(self, sub, part, name):
        return os.path.join(self.dir, part, sub, name) if sub else os.path.join(self.dir, part, name)

    # ------------------------------------------------------------ tiles
    def tile(self, src, out_id, room, kind="floor"):
        rgb = grout_crop(gkit.load_rgb(src)) / 255.0
        rgb = cv2.resize(rgb, (768, 768), interpolation=cv2.INTER_AREA)
        for sub, (w, h) in (("", (64, 32)), ("_2x", (128, 64))):
            im = gkit.binarize(gkit.project_square(rgb.astype(np.float32), w, h))
            gkit.save_png(self._path(sub, "tiles", out_id + ".png"), im)
        self.META["tiles"].append({
            "id": out_id, "room": room, "kind": kind,
            "file": "board/tiles/%s.png" % out_id, "file_2x": "board/tiles/_2x/%s.png" % out_id,
            "size": [64, 32], "size_2x": [128, 64],
            "anchor": "image centre = cell centre (cell_to_local); full 64x32 diamond, 0.5 px bleed on the diagonal edges",
            "walkable": True, "blocks": False, "source": src,
        })
        return rgb

    def pad_glow(self, rgb, out_id, for_id, col=WARM, lo=0.55, span=0.35, gain=(2.0, 0.6), bright=None):
        """Additive glow for a pad tile: its bright parts, blurred, on a 96x56 canvas centred on the cell."""
        if bright is None:
            lum = rgb.mean(-1)
            bright = np.clip((lum - lo) / span, 0, 1).astype(np.float32)
        for sub, sc in (("", 1), ("_2x", 2)):
            W, H = 96 * sc, 56 * sc
            dia = gkit.project_square(np.dstack([bright] * 3), 64 * sc, 32 * sc)[..., 0]
            can = np.zeros((H, W), np.float32)
            oy = (H - 32 * sc) // 2 + 4 * sc
            can[oy:oy + 32 * sc, 16 * sc:16 * sc + 64 * sc] = dia
            g = cv2.GaussianBlur(can, (0, 0), 5 * sc) * gain[0] + cv2.GaussianBlur(can, (0, 0), 1.2 * sc) * gain[1]
            g = np.clip(g, 0, 1)
            col_ = np.array(col, np.float32)
            g8 = np.clip(g[..., None] * col_ * 255 + 0.5, 0, 255).astype(np.uint8)
            on = g8.max(-1) >= 3
            out = np.zeros((H, W, 4), np.uint8)
            out[..., :3] = np.where(on[..., None], g8, 0)
            out[..., 3] = np.where(on, 255, 0)
            gkit.save_png(self._path(sub, "tiles", out_id + ".png"), out)
        self.META["glows"].append({
            "id": out_id, "for": for_id, "blend": "add",
            "file": "board/tiles/%s.png" % out_id, "file_2x": "board/tiles/_2x/%s.png" % out_id,
            "size": [96, 56], "size_2x": [192, 112],
            "anchor": "image centre = cell centre + (0, -4) at 1x (draw at cell_to_local - (48, 32)); additive, pulse its modulate (e.g. 0.6..1.0 over 1.6 s)",
        })

    # ------------------------------------------------------------ props
    def prop(self, src, out_id, room, target_w, footprint=(1, 1), grade=None, notes="", key=None, glow=None):
        """glow: optional (mask_fn(straight_rgb01, alpha) -> float map, colour, sigma, gain) for a same-canvas additive glow."""
        prem = gkit.clean_alpha(keyer(key or self.key)(gkit.load_rgb(src)))
        if grade:
            prem = gkit.grade(prem, **grade)
        a = prem[..., 3] > 0.5
        ys, xs = np.nonzero(a)
        y0, y1 = ys.min(), ys.max() + 1
        # Horizontal anchor: centre of the body rows (ignores low spills).
        body = a[y0:int(y0 + (y1 - y0) * 0.85)]
        bx = np.nonzero(body.any(0))[0]
        cx = (bx.min() + bx.max() + 1) / 2.0
        half = max(cx - xs.min(), xs.max() + 1 - cx) + 3
        x0, x1 = int(np.floor(cx - half)), int(np.ceil(cx + half))
        can = np.zeros((y1 - y0 + 3, x1 - x0, 4), np.float32)
        sx0, sx1 = max(0, x0), min(prem.shape[1], x1)
        can[3:, sx0 - x0:sx1 - x0] = prem[y0:y1, sx0:sx1]
        content_w = xs.max() + 1 - xs.min()
        scale = target_w / float(content_w)
        sizes = {}
        for sub, k in (("", 1), ("_2x", 2)):
            w = int(round(can.shape[1] * scale * k / 2)) * 2
            h = int(round(can.shape[0] * scale * k))
            small = gkit.resize_prem(can, w, h)
            im = gkit.binarize(small)
            ys2, xs2 = np.nonzero(im[..., 3])
            im = im[ys2.min():]
            gkit.save_png(self._path(sub, "props", out_id + ".png"), im)
            sizes[k] = [im.shape[1], im.shape[0]]
            if glow:
                fn, col, sig, gain = glow
                sm = small[ys2.min():]
                al = sm[..., 3]
                st = sm[..., :3] / np.maximum(al, 1e-4)[..., None]
                m = fn(st, al) * (im[..., 3] > 0)
                g = cv2.GaussianBlur(m.astype(np.float32), (0, 0), sig * k) * gain + m * 0.3
                gkit.save_png(self._path(sub, "props", out_id + "_glow.png"), addglow(np.clip(g, 0, 1), col))
        fx, fy = footprint
        cells = [[x, y] for y in range(fy) for x in range(fx)]
        south = [fx - 1, fy - 1]
        bc = [((fx - 1) - (fy - 1)) * 32, ((fx - 1) + (fy - 1)) * 16 + 16]
        e = {
            "id": out_id, "room": room, "kind": "obstacle", "blocks": True, "walkable": False,
            "file": "board/props/%s.png" % out_id, "file_2x": "board/props/_2x/%s.png" % out_id,
            "size": sizes[1], "size_2x": sizes[2],
            "footprint_size": [fx, fy], "footprint_from_nw": cells, "anchor_cell_from_nw": south,
            "anchor": "image bottom-centre = south tip of cell origin+%s (draw at cell_to_local(south_cell) + (-w/2, 16 - h))" % south,
            "bottom_centre_from_nw_centre_1x": bc,
            "y_sort": "by the south-most footprint cell (x+y), like units; y-sort point = image bottom - 16 px",
            "source": src, "note": notes,
        }
        self.META["props"].append(e)
        if glow:
            e["glow"] = "board/props/%s_glow.png" % out_id
            e["glow_2x"] = "board/props/_2x/%s_glow.png" % out_id
            self.META["glows"].append({
                "id": out_id + "_glow", "for": out_id, "blend": "add",
                "file": e["glow"], "file_2x": e["glow_2x"], "size": sizes[1], "size_2x": sizes[2],
                "anchor": "same canvas and anchor as %s; additive; flicker its modulate 0.75..1.0" % out_id,
            })

    # ------------------------------------------------------------ decals
    def decal(self, src, out_id, n=3, room="b", glow_mask=None, glow_col=(1.0, 0.6, 0.18), glow_gain=(3, 1.3, 0.25),
              key=None, anchor_note=None, layer=None):
        """A top-down painted decal mapped onto the full n x n footprint diamond, plus its additive glow.

        glow_mask(rgb01_768, alpha_768) -> float map; default = the Granary's warm light from below.
        """
        rgb8 = gkit.load_rgb(src)
        prem = gkit.clean_alpha(keyer(key or self.key)(rgb8))
        prem = cv2.resize(prem, (768, 768), interpolation=cv2.INTER_AREA)
        rgb = rgb8 / 255.0
        rgb = cv2.resize(rgb, (768, 768), interpolation=cv2.INTER_AREA)
        if glow_mask is None:
            lum_warm = np.clip((rgb[..., 0] - rgb[..., 2] - 0.35) / 0.4, 0, 1) * np.clip((rgb.mean(-1) - 0.3) / 0.4, 0, 1)
            lum_warm *= prem[..., 3]
        else:
            lum_warm = glow_mask(rgb, prem[..., 3])
        for sub, k in (("", 1), ("_2x", 2)):
            W, H = 64 * n * k, 32 * n * k
            ss = 4
            Wb, Hb = W * ss, H * ss
            ys, xs = np.mgrid[0:Hb, 0:Wb].astype(np.float32) + 0.5
            px = (xs - Wb / 2) / (Wb / 2)
            py = ys / (Hb / 2)
            s = (px + py) / 2.0
            t = (py - px) / 2.0
            mx = (np.clip(s, 0, 1) * 767).astype(np.float32)
            my = (np.clip(t, 0, 1) * 767).astype(np.float32)
            big = cv2.remap(prem, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
            small = cv2.resize(big, (W, H), interpolation=cv2.INTER_AREA)
            im = gkit.binarize(small)
            gkit.save_png(self._path(sub, "props", out_id + ".png"), im)
            gb = cv2.remap(lum_warm.astype(np.float32), mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
            gs = cv2.resize(gb, (W, H), interpolation=cv2.INTER_AREA)
            g = np.clip(cv2.GaussianBlur(gs, (0, 0), glow_gain[0] * k) * glow_gain[1] + gs * glow_gain[2], 0, 1)
            g8 = np.clip(g[..., None] * np.array(glow_col) * 255 + 0.5, 0, 255).astype(np.uint8)
            on = g8.max(-1) >= 3
            go = np.zeros((H, W, 4), np.uint8)
            go[..., :3] = np.where(on[..., None], g8, 0)
            go[..., 3] = np.where(on, 255, 0)
            gkit.save_png(self._path(sub, "props", out_id + "_glow.png"), go)
        cells = [[x, y] for y in range(n) for x in range(n)]
        last = n - 1
        self.META["decals"].append({
            "id": out_id, "room": room, "kind": "floor_decal", "blocks": False, "walkable": True,
            "file": "board/props/%s.png" % out_id, "file_2x": "board/props/_2x/%s.png" % out_id,
            "size": [64 * n, 32 * n], "size_2x": [128 * n, 64 * n],
            "footprint_size": [n, n], "footprint_from_nw": cells, "anchor_cell_from_nw": [last, last],
            "anchor": anchor_note or ("image = the %dx%d footprint diamond: bottom-centre on the south tip of origin+[%d,%d]; top-centre on the north tip of the origin cell" % (n, n, last, last)),
            "bottom_centre_from_nw_centre_1x": [0, 32 * last + 16],
            "layer": layer or "ground: after floor tiles, before props and units (no y-sort)",
            "source": src,
        })
        self.META["glows"].append({
            "id": out_id + "_glow", "for": out_id, "blend": "add",
            "file": "board/props/%s_glow.png" % out_id, "file_2x": "board/props/_2x/%s_glow.png" % out_id,
            "size": [64 * n, 32 * n], "size_2x": [128 * n, 64 * n],
            "anchor": "same canvas and anchor as %s; additive; flicker its modulate 0.7..1.0" % out_id,
        })

    # ------------------------------------------------------------ backdrops
    def extend_floor(self, small, gmask, minx, miny, floor, dim=0.72):
        """Paint the floor tiles past the board edge where the painting had open floor,
        so the floor meets the walls; darkened toward the walls."""
        from PIL import Image
        tiles = [np.asarray(Image.open(os.path.join(self.dir, "tiles", "%s_%s.png" % (floor, v))).convert("RGBA"), np.float32) / 255.0 for v in "abc"]
        ys, xs = np.nonzero(gmask)
        lx = xs + 0.5 + minx
        ly = ys + 0.5 + miny
        fx = np.floor((lx / 32.0 + (ly + 16) / 16.0) / 2.0).astype(int)
        fy = np.floor(((ly + 16) / 16.0 - lx / 32.0) / 2.0).astype(int)
        cx = (fx - fy) * 32
        cy = (fx + fy) * 16
        tx = np.clip((lx - cx + 32).astype(int), 0, 63)
        ty = np.clip((ly - cy + 16).astype(int), 0, 31)
        hv = (((fx * 73856093) ^ (fy * 19349663) ^ (fx * fy * 83492791)) & 0x7fffffff) % 3
        col = np.zeros((len(xs), 3), np.float32)
        for v in range(3):
            sel = hv == v
            col[sel] = tiles[v][ty[sel], tx[sel], :3]
        col *= dim
        out = small.copy()
        out[ys, xs, :3] = col
        out[ys, xs, 3] = 1.0
        return out

    def backdrop(self, src, out_id, room, n, floor, dim=0.72, dark_lum=16):
        rgb = gkit.load_rgb(src)
        ex = key_excess(rgb, self.key)
        m = (ex > 120).astype(np.uint8)
        cnt, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
        gi = 1 + int(np.argmax(st[1:, 4]))
        green = lab == gi
        src_pts = fit_floor_corners(green)
        dst = np.array([[0, -16], [32 * n, 16 * n - 16], [0, 32 * n - 16], [-32 * n, 16 * n - 16]], np.float32)
        # Least squares affine from 4 correspondences.
        X = np.hstack([src_pts, np.ones((4, 1), np.float32)])
        sol, *_ = np.linalg.lstsq(X, dst, rcond=None)
        A = sol.T  # 2x3
        resid = np.abs(X @ sol - dst).max()
        # Destination canvas: transform the source frame corners.
        h, w = rgb.shape[:2]
        corners = np.array([[0, 0, 1], [w, 0, 1], [w, h, 1], [0, h, 1]], np.float32) @ sol
        minx, miny = np.floor(corners.min(0))
        maxx, maxy = np.ceil(corners.max(0))
        # Key the dark surround (connected to the frame border) and the key-colour floor.
        lum = rgb.mean(-1)
        dark = (lum < dark_lum).astype(np.uint8)
        dark = cv2.morphologyEx(dark, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
        cnt2, lab2, _, _ = cv2.connectedComponentsWithStats(dark, 4)
        border = set(np.unique(np.concatenate([lab2[0], lab2[-1], lab2[:, 0], lab2[:, -1]]))) - {0}
        surround = np.isin(lab2, list(border))
        alpha = (~surround).astype(np.float32)
        col = rgb / 255.0
        gfill = ex >= 60
        gfill = cv2.dilate(gfill.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
        col[gfill] = np.array(self.floor_fill, np.float32) / 255.0
        prem = np.dstack([col * alpha[..., None], alpha]).astype(np.float32)
        out = {}
        for tag, k in (("", 1),):
            W, H = int(maxx - minx), int(maxy - miny)
            M = A.copy()
            M[:, 2] -= [minx, miny]
            ss = 2
            Ms = M * ss
            big = cv2.warpAffine(prem, Ms, (W * ss, H * ss), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
            small = cv2.resize(np.clip(big, 0, 1), (W, H), interpolation=cv2.INTER_AREA)
            gw = cv2.warpAffine(gfill.astype(np.float32), M, (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0) > 0.3
            small = self.extend_floor(small, gw, minx, miny, floor, dim)
            # Cut the board diamond (exact, grown 1 px so no wall pixel peeks between tiles).
            yy, xx = np.mgrid[0:H, 0:W].astype(np.float32) + 0.5
            lx, ly = xx + minx, yy + miny
            cxl, cyl = 0.0, 16.0 * n - 16.0
            d = np.abs(lx - cxl) / (32.0 * n) + np.abs(ly - cyl) / (16.0 * n)
            small[d <= 1.0 + 1.0 / (16.0 * n)] = 0
            im = gkit.binarize(small)
            ys3, xs3 = np.nonzero(im[..., 3])
            cy0, cy1, cx0, cx1 = ys3.min(), ys3.max() + 1, xs3.min(), xs3.max() + 1
            im = im[cy0:cy1, cx0:cx1]
            origin = [int(-minx - cx0), int(-miny - cy0)]
            path = os.path.join(self.dir, "backdrops", "%s_%dx%d.png" % (out_id, n, n))
            gkit.save_png(path, im)
            out = {"size": [im.shape[1], im.shape[0]], "origin": origin, "file": gkit.rel(path)}
        self.META["backdrops"].append({
            "id": "%s_%dx%d" % (out_id, n, n), "room": room, "board_size": [n, n],
            "file": out["file"], "size": out["size"],
            "cell00_centre_px": out["origin"],
            "anchor": "draw the image so pixel cell00_centre_px lands on cell_to_local(0,0) (the board-local origin): position = -cell00_centre_px",
            "layer": "behind the floor tiles (z below every tile); the board diamond is cut out (alpha 0) so the tiles fill it",
            "surround": "the dark area outside the walls is alpha 0; clear the viewport to near-black #070605 behind it",
            "camera_note": "the back walls rise about %d px above the board's top tip; fit the camera to this image's bounds, not only the board, to show them" % int(out["origin"][1] - 16 + 0),
            "fit_residual_px": round(float(resid), 2), "source": src, "only_1x": True,
        })

    def write_meta(self, name):
        gkit.write_json(os.path.join(gkit.HERE, name), self.META)
