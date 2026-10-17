"""Round 23: the buildings inside the ring, on the HD image plate.

Called by ring_v4_plate.py. All placement maths is in image px (1/4 of the
plate); sprites are scaled to plate px from the hero height (hero stays small:
a house is about 3 hero heights and shorter than the wall, the castle is the
tallest building, the cathedral next).

- place(): a footprint (iso ellipse 0.9w x 0.46w above the bottom-centre
  anchor) must sit on grass inside the ring, clear of streets, the river, the
  wall band, the gate approaches, the bridge landings, the player plots and
  every other building. Houses and workshops need a street just in front of
  their door (the art's door faces the viewer, so the street is south).
  Landmarks search round their GOAL spots; NPC houses fill the streets.
- match(): LAB transfer of the building's stone and roof pixels to the HD
  plate's own stone and roof (colour and contrast), so they read as one painting.
- bake(): plate trees and bushes under a building go (grass from a clean
  patch of the plate), and a soft contact shadow is laid down and to the right
  (the plate's light comes from the upper left).
"""
import math
import os
import random

import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage.color import rgb2lab, lab2rgb

UP = 4


def trim(im):
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def load(art_dir, rel, height_px, flip=False):
    im = trim(Image.open(os.path.join(art_dir, rel)).convert("RGBA"))
    w = max(1, int(round(im.width * height_px / im.height)))
    im = im.resize((w, int(round(height_px))), Image.LANCZOS)
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    return im


# ---------------------------------------------------------------- colour

def lab_stats(rgb, mask):
    lab = rgb2lab(rgb[mask].reshape(-1, 1, 3) / 255.0).reshape(-1, 3)
    return lab.mean(axis=0), lab.std(axis=0) + 1e-3


def plate_refs(hd_full, hd_walls, tower_boxes_plate):
    """Stone from the HD walls layer (opaque, low chroma), roof from the towers' red cones."""
    step = 3
    w = hd_walls[::step, ::step]
    rgb = w[..., :3].astype(np.float32)
    lab = rgb2lab(rgb / 255.0)
    chroma = np.hypot(lab[..., 1], lab[..., 2])
    stone = (w[..., 3] > 250) & (chroma < 22) & (lab[..., 0] > 30)
    s_mu, s_sd = lab_stats(rgb, stone)
    roofs = []
    for x0, y0, x1, y1 in tower_boxes_plate:
        sub = hd_full[y0:y1:2, x0:x1:2].astype(np.float32)
        lab_ = rgb2lab(sub / 255.0)
        m = (lab_[..., 1] > 14) & (lab_[..., 2] > 8) & (lab_[..., 0] < 70)
        if m.any():
            roofs.append(sub[m])
    r = np.concatenate(roofs)
    r_mu, r_sd = lab_stats(r.reshape(-1, 1, 3), np.ones((len(r), 1), bool))
    return {"stone": (s_mu, s_sd), "roof": (r_mu, r_sd)}


def match(im, refs, strength=0.75):
    a = np.asarray(im).astype(np.float32)
    rgb, alpha = a[..., :3], a[..., 3]
    lab = rgb2lab(rgb / 255.0)
    chroma = np.hypot(lab[..., 1], lab[..., 2])
    solid = alpha > 128
    stone = solid & (chroma < 20) & (lab[..., 0] > 30)
    roof = solid & (lab[..., 1] > 14) & (lab[..., 2] > 6) & (lab[..., 0] < 72)
    out = lab.copy()
    for m, key in ((stone, "stone"), (roof, "roof")):
        if m.sum() < 30:
            continue
        mu, sd = lab[m].mean(axis=0), lab[m].std(axis=0) + 1e-3
        t_mu, t_sd = refs[key]
        moved = (lab[m] - mu) / sd * t_sd + t_mu
        out[m] = lab[m] * (1 - strength) + moved * strength
    rgb2 = np.clip(lab2rgb(out) * 255.0, 0, 255)
    return Image.fromarray(np.dstack([rgb2, alpha]).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------- placement

FP = {}


def footprint(ax, ay, w_img, key=None):
    rxf, ryf = FP.get(key, (0.45, 0.23))
    rx = rxf * w_img
    ry = ryf * w_img
    return ax, ay - ry, rx, ry


def ellipse_mask(shape, cx, cy, rx, ry):
    h, w = shape
    y0, y1 = max(0, int(cy - ry) - 1), min(h, int(cy + ry) + 2)
    x0, x1 = max(0, int(cx - rx) - 1), min(w, int(cx + rx) + 2)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    m = ((xx - cx) / max(rx, 0.5)) ** 2 + ((yy - cy) / max(ry, 0.5)) ** 2 <= 1.0
    return (slice(y0, y1), slice(x0, x1)), m


class Placer:
    def __init__(self, shape, bad, path, water, inside):
        self.shape = shape
        self.bad = bad.copy()
        self.path = path
        self.water = water
        self.inside = inside
        self.taken = np.zeros(shape, bool)

    def fits(self, ax, ay, w_img, door=True, gap=3, allow=None, near_water=False, key=None):
        cx, cy, rx, ry = footprint(ax, ay, w_img, key)
        h, w = self.shape
        if cx - rx < 2 or cy - ry < 2 or cx + rx >= w - 2 or cy + ry >= h - 2:
            return False
        sl, m = ellipse_mask(self.shape, cx, cy, rx + gap, ry + gap * 0.6)
        bad = self.bad[sl] | self.taken[sl]
        if allow is not None:
            bad = bad & ~allow[sl]
        if (bad & m).any():
            return False
        sl2, m2 = ellipse_mask(self.shape, cx, cy, rx, ry)
        if not self.inside[sl2][m2].all():
            return False
        if door:
            y0, y1 = int(ay + 1), int(ay + 32)
            x0, x1 = int(ax - 7), int(ax + 8)
            if not self.path[y0:y1, x0:x1].any():
                return False
        if near_water:
            sl3, m3 = ellipse_mask(self.shape, cx, cy, rx + 14, ry + 9)
            if not (self.water[sl3] & m3).any():
                return False
        return True

    def take(self, ax, ay, w_img, key=None):
        cx, cy, rx, ry = footprint(ax, ay, w_img, key)
        sl, m = ellipse_mask(self.shape, cx, cy, rx, ry)
        self.taken[sl] |= m

    def search(self, near, radius, w_img, **kw):
        best = None
        for nx, ny in near:
            for r in range(0, int(radius) + 1, 2):
                for k in range(max(1, int(2 * math.pi * r / 3))):
                    t = 2 * math.pi * k / max(1, int(2 * math.pi * r / 3))
                    ax, ay = nx + r * math.cos(t), ny + r * math.sin(t) * 0.6
                    if self.fits(ax, ay, w_img, **kw):
                        d = r
                        if best is None or d < best[0]:
                            best = (d, ax, ay)
                        break
                if best is not None and best[0] <= r:
                    break
        return None if best is None else (best[1], best[2])


# ---------------------------------------------------------------- ground

def tree_mask(img):
    """Plate trees and bushes (image px): textured or dark foliage, and blossom."""
    a = img.astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    L = a.mean(axis=2)
    green = (g > r + 4) & (g > b + 12)
    m = ndi.uniform_filter(L, 7)
    sd = np.sqrt(np.maximum(ndi.uniform_filter(L * L, 7) - m * m, 0))
    gm = float(np.median(L[green])) if green.any() else 80.0
    blossom = (r > g + 12) & (b > g - 4) & (r > 140)
    t = (green & ((sd > 14) | (L < gm - 28))) | blossom
    t = ndi.binary_closing(ndi.binary_opening(t, iterations=1), iterations=3)
    return ndi.binary_fill_holes(t)


def grass_patch(img, avoid, size=48):
    """A clean grass window (image px), the plate's own grass to fill from."""
    a = img.astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = (g > r + 4) & (g > b + 12) & ~avoid
    ok = ndi.uniform_filter(green.astype(np.float32), size) > 0.995
    ys, xs = np.nonzero(ok)
    if not len(xs):
        return None
    cy, cx = ys.mean(), xs.mean()
    k = int(np.argmin((ys - cy) ** 2 + (xs - cx) ** 2))
    return int(xs[k] - size // 2), int(ys[k] - size // 2), size


def bake(full, clean, remove_img, shadows, patch):
    """remove_img: image-px mask of plate trees to replace by grass; shadows:
    [(cx, cy, rx, ry)] plate px. Edits `full` (plate RGB) in place."""
    PH, PW = full.shape[:2]
    if patch is not None and remove_img.any():
        px, py, ps = patch
        tile = full[py * UP:(py + ps) * UP, px * UP:(px + ps) * UP].astype(np.float32)
        # mirror-tile so the seams match
        tile = np.concatenate([tile, tile[:, ::-1]], axis=1)
        tile = np.concatenate([tile, tile[::-1]], axis=0)
        th, tw = tile.shape[:2]
        m_up = np.asarray(Image.fromarray((remove_img * 255).astype(np.uint8)).resize((PW, PH), Image.BILINEAR)).astype(np.float32) / 255.0
        m_up = ndi.gaussian_filter(m_up, 2.0)
        ys, xs = np.nonzero(m_up > 0.01)
        if len(ys):
            y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            yy, xx = np.mgrid[y0:y1, x0:x1]
            fill = tile[yy % th, xx % tw]
            mm = m_up[y0:y1, x0:x1, None]
            full[y0:y1, x0:x1] = (full[y0:y1, x0:x1] * (1 - mm) + fill * mm).astype(np.uint8)
    for cx, cy, rx, ry, k in shadows:
        y0, y1 = max(0, int(cy - ry * 2)), min(PH, int(cy + ry * 2))
        x0, x1 = max(0, int(cx - rx * 2)), min(PW, int(cx + rx * 2))
        yy, xx = np.mgrid[y0:y1, x0:x1]
        d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
        sh = np.clip(1.0 - d, 0.0, 1.0) ** 0.8 * k
        full[y0:y1, x0:x1] = (full[y0:y1, x0:x1] * (1.0 - sh[..., None])).astype(np.uint8)


# ---------------------------------------------------------------- round 24

def clean_window(mask, size, prefer=None):
    """Top-left (image px) of a size x size window fully inside `mask`, nearest `prefer`."""
    ok = ndi.uniform_filter(mask.astype(np.float32), size) > 0.999
    ys, xs = np.nonzero(ok)
    if not len(xs):
        return None
    if prefer is None:
        prefer = (ys.mean(), xs.mean())
    k = int(np.argmin((ys - prefer[0]) ** 2 + (xs - prefer[1]) ** 2))
    return int(xs[k] - size // 2), int(ys[k] - size // 2)


def texture_fill(full, box_img, shape_plate, seed):
    """A plate-size texture from one clean plate window, laid as random
    offset tiles with soft seams (no mirror symmetry, no visible grid)."""
    PH, PW = shape_plate
    x0, y0, s = box_img
    src = full[y0 * UP:(y0 + s) * UP, x0 * UP:(x0 + s) * UP].astype(np.float32)
    t = src.shape[0]
    step = t // 2
    out = np.zeros((PH, PW, 3), np.float32)
    wsum = np.zeros((PH, PW, 1), np.float32)
    ramp = np.minimum(np.arange(t), np.arange(t)[::-1]).astype(np.float32)
    ramp = np.clip(ramp / (t * 0.25), 0.02, 1.0)
    win = (ramp[:, None] * ramp[None, :])[..., None]
    rng = np.random.RandomState(seed)
    for y in range(-step, PH, step):
        for x in range(-step, PW, step):
            k = rng.randint(4)
            tile = np.rot90(src, 2) if k == 1 else (src[:, ::-1] if k == 2 else (src[::-1] if k == 3 else src))
            ys, xs = slice(max(0, y), min(PH, y + t)), slice(max(0, x), min(PW, x + t))
            ty, tx = slice(ys.start - y, ys.stop - y), slice(xs.start - x, xs.stop - x)
            out[ys, xs] += tile[ty, tx] * win[ty, tx]
            wsum[ys, xs] += win[ty, tx]
    return out / np.maximum(wsum, 1e-3)


def rebuild_interior(full, interior_img, path_img, keep_img, seed=24):
    """Round 24: the interior ground is rebuilt from the plate's own clean grass
    and cobble, so nothing half-erased stays (old bushes, lamps, rocks)."""
    PH, PW = full.shape[:2]
    grass_src = interior_img & ~path_img & ~keep_img
    a = np.asarray(Image.fromarray(full).resize((full.shape[1] // UP, full.shape[0] // UP), Image.BILINEAR)).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    L = a.mean(axis=2)
    m = ndi.uniform_filter(L, 9)
    sd = np.sqrt(np.maximum(ndi.uniform_filter(L * L, 9) - m * m, 0))
    smooth = sd < np.percentile(sd[grass_src], 45)
    gwin = clean_window(grass_src & (g > r + 4) & smooth, 40)
    cwin = clean_window(path_img & interior_img & (sd < np.percentile(sd[path_img], 55)), 24)
    if gwin is None or cwin is None:
        return full
    grass = texture_fill(full, (gwin[0], gwin[1], 40), (PH, PW), seed)
    cob = texture_fill(full, (cwin[0], cwin[1], 24), (PH, PW), seed + 1)

    def up(mk, blur):
        u = np.asarray(Image.fromarray((mk * 255).astype(np.uint8)).resize((PW, PH), Image.BILINEAR)).astype(np.float32) / 255.0
        return ndi.gaussian_filter(u, blur)[..., None]
    pa = up(path_img, 2.5)
    new = grass * (1.0 - pa) + cob * pa
    ia = up(interior_img & ~keep_img, 3.0)
    return np.clip(full * (1.0 - ia) + new * ia, 0, 255).astype(np.uint8)
