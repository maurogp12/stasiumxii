#!/usr/bin/env python3
"""Reusable sprite-sheet pipeline for STASIUM XII Ironjaw HD (v4_hd).

Cut -> clean -> scale -> feet-align -> package. No painting.

Steps per sheet
  1. White-key mask: non-white = sum(765-RGB) > key_thresh (40), then median 3.
  2. Connected components (8-conn; scipy.ndimage if present, numpy BFS fallback).
     Specks < min_speck px dropped. Largest component per sheet slot = body;
     every other component is attached to the NEAREST body by pixel distance
     (not by sheet third), so props crossing slot boundaries stay whole.
  3. Edge decontamination at source res: the outer `band` px of each figure are
     recoloured from the nearest interior pixel (kills white/JPEG-chroma halo).
  4. One shared, exact, isotropic scale (premultiplied Lanczos), alpha hard
     threshold at 128 -> {0,255}; RGB=0 where alpha=0; final 1 px edge pass that
     recolours any edge pixel noticeably lighter than the pixel inside it.
  5. Feet alignment: boots = bottom-most blobs near the body centre column;
     sole row = lowest opaque row of the boots (axe blades / cape ignored);
     whole-pixel shift so soles sit on pivot_y and the boot midpoint sits on
     pivot_x (= cell centre, W even, so a horizontal flip keeps the pivot).

CLI example (attack S of the v4_hd set):
  python process_sheet.py raw_full/sheet_attack_S.jpg --cols 3 --rows 2 \
      --order 5,1,2,3,4,5 --anim attack --facing S --mirror-as W \
      --out /workspace/art/ironjaw_full/v4_hd/attack --scale 0.9459 \
      --cell 512 360 --pivot-y 329 --spare 0:/workspace/art/ironjaw_full/v4_hd/_test/_spare_windup.png
Use --extents-only first on a new sheet to see whether the frames fit the cell.
Death example (own cell, dirt removal, mirrored slot, lying frames on the ground line):
  python process_sheet.py raw_full/sheet_death_E.jpg --cols 3 --rows 2 --order 1,2,3,4,5 \
      --anim death --facing E --mirror-as N --out /tmp/death --auto-scale-slot 0 \
      --cell 640 384 --body-slot 2 --body-slot 3 --body-slot 4 --body-slot 5 \
      --dirt 0:326 --dirt 1:326:526,300,588,341 --dirt 2:322:840,288,899,353;1163,284,1240,349 \
      --dirt 3:606 --dirt 4:556 --dirt 5:560
(The full v4_hd set, incl. idle f00 substitution, breathing, rim and previews, is
built by build_v4hd_set.py which imports these functions.)
For a death sheet use a bigger death cell (e.g. --cell 640 360 --pivot-y 329 or a
taller cell with the same 31 px under the soles) and record it separately in
_cells_pivots.json under "death_cell".
"""
import argparse, json, os, sys
from collections import deque
import numpy as np
from PIL import Image, ImageFilter

try:
    from scipy import ndimage as ndi
    HAVE_SCIPY = True
except Exception:  # pragma: no cover
    ndi = None
    HAVE_SCIPY = False

N8 = np.ones((3, 3), bool)

# ---------------------------------------------------------------- labelling
def _label_bfs(mask):
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32)
    n = 0
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys, xs):
        if lab[y0, x0]:
            continue
        n += 1
        lab[y0, x0] = n
        q = deque([(y0, x0)])
        while q:
            y, x = q.popleft()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not lab[yy, xx]:
                        lab[yy, xx] = n
                        q.append((yy, xx))
    return lab, n

def label(mask):
    mask = np.asarray(mask, bool)
    if HAVE_SCIPY:
        return ndi.label(mask, structure=N8)
    return _label_bfs(mask)

def erode(mask, it=1):
    m = np.asarray(mask, bool)
    if HAVE_SCIPY:
        return ndi.binary_erosion(m, structure=N8, iterations=it, border_value=0)
    for _ in range(it):
        p = np.pad(m, 1)
        out = np.ones_like(m)
        for dy in range(3):
            for dx in range(3):
                out &= p[dy:dy + m.shape[0], dx:dx + m.shape[1]]
        m = out
    return m

def nearest_index(src_mask):
    """For every pixel, (iy, ix) of the nearest True pixel in src_mask."""
    if HAVE_SCIPY:
        _, idx = ndi.distance_transform_edt(~src_mask, return_indices=True)
        return idx[0], idx[1]
    # fallback: BFS multi-source (4-conn)
    h, w = src_mask.shape
    iy = np.full((h, w), -1, np.int32); ix = np.full((h, w), -1, np.int32)
    q = deque()
    for y, x in zip(*np.nonzero(src_mask)):
        iy[y, x], ix[y, x] = y, x; q.append((y, x))
    while q:
        y, x = q.popleft()
        for yy, xx in ((y-1, x), (y+1, x), (y, x-1), (y, x+1)):
            if 0 <= yy < h and 0 <= xx < w and iy[yy, xx] < 0:
                iy[yy, xx], ix[yy, xx] = iy[y, x], ix[y, x]; q.append((yy, xx))
    return iy, ix

def dist_to(mask):
    if HAVE_SCIPY:
        return ndi.distance_transform_edt(~mask)
    iy, ix = nearest_index(mask)
    yy, xx = np.indices(mask.shape)
    return np.hypot(yy - iy, xx - ix)

# ---------------------------------------------------------------- segmentation
def key_mask(rgb, thresh=40):
    a = rgb.astype(np.int32)
    m = ((765 - a.sum(2)) > thresh).astype(np.uint8) * 255
    return np.asarray(Image.fromarray(m).filter(ImageFilter.MedianFilter(3))) > 0

def segment_sheet(rgb, cols, rows, key_thresh=40, min_speck=30, max_attach_dist=None):
    """Return list (len cols*rows, sheet order) of boolean figure masks + report."""
    H, W = rgb.shape[:2]
    m = key_mask(rgb, key_thresh)
    lab, n = label(m)
    sizes = np.bincount(lab.ravel(), minlength=n + 1)
    comps = []
    for k in range(1, n + 1):
        if sizes[k] < min_speck:
            continue
        ys, xs = np.nonzero(lab == k)
        cy, cx = ys.mean(), xs.mean()
        slot = int(min(rows - 1, cy // (H / rows)) * cols + min(cols - 1, cx // (W / cols)))
        comps.append(dict(k=k, size=int(sizes[k]), slot=slot,
                          bbox=[int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]))
    dropped = int(sum(1 for k in range(1, n + 1) if 0 < sizes[k] < min_speck))
    bodies = {}
    for c in comps:
        if c['slot'] not in bodies or c['size'] > bodies[c['slot']]['size']:
            bodies[c['slot']] = c
    missing = [s for s in range(cols * rows) if s not in bodies]
    if missing:
        raise SystemExit(f'no body found for sheet slots {missing}')
    body_dist = {s: dist_to(lab == b['k']) for s, b in bodies.items()}
    figs = {s: (lab == b['k']) for s, b in bodies.items()}
    attach, far_dropped = [], []
    for c in comps:
        if bodies[c['slot']] is c:
            continue
        cm = lab == c['k']
        d = {s: float(body_dist[s][cm].min()) for s in bodies}
        s_best = min(d, key=d.get)
        if max_attach_dist is not None and d[s_best] > max_attach_dist:
            far_dropped.append(dict(size=c['size'], bbox=c['bbox'], dist=round(d[s_best], 1)))
            continue
        figs[s_best] |= cm
        attach.append(dict(comp=c, to_slot=s_best, dist=round(d[s_best], 1),
                           crossed_slot=s_best != c['slot']))
    rep = dict(n_components=int(n), kept=len(comps), dropped_specks=dropped,
               bodies={s: dict(size=b['size'], bbox=b['bbox']) for s, b in bodies.items()},
               attached=[dict(size=a['comp']['size'], bbox=a['comp']['bbox'], from_slot=a['comp']['slot'],
                              to_slot=a['to_slot'], dist=a['dist'], crossed_slot=a['crossed_slot'])
                         for a in attach],
               dropped_far=far_dropped)
    return [figs[s] for s in range(cols * rows)], rep

# ---------------------------------------------------------------- cleaning / scaling
def decontaminate_src(rgb, mask, band=2):
    """Recolour the outer `band` px of the figure from the nearest interior pixel."""
    inner = erode(mask, band)
    out = rgb.copy()
    if inner.any():
        iy, ix = nearest_index(inner)
        ring = mask & ~inner
        out[ring] = rgb[iy[ring], ix[ring]]
    return out

def scale_figure(rgb, mask, s, pad=6):
    """Exact isotropic scale s (premultiplied Lanczos). Returns RGBA uint8 + origin."""
    ys, xs = np.nonzero(mask)
    x0, y0 = xs.min() - pad, ys.min() - pad
    x1, y1 = xs.max() + 1 + pad, ys.max() + 1 + pad
    wo, ho = int(np.ceil((x1 - x0) * s)), int(np.ceil((y1 - y0) * s))
    box = (float(x0), float(y0), x0 + wo / s, y0 + ho / s)
    al = mask.astype(np.float32) * 255.0
    big = np.zeros((rgb.shape[0] + 2 * pad + 4, rgb.shape[1] + 2 * pad + 4, 4), np.float32)
    off = pad + 2
    big[off:off + rgb.shape[0], off:off + rgb.shape[1], :3] = rgb * mask[..., None]
    big[off:off + rgb.shape[0], off:off + rgb.shape[1], 3] = al
    box = (box[0] + off, box[1] + off, box[2] + off, box[3] + off)
    ch = [np.asarray(Image.fromarray(big[..., c], 'F').resize((wo, ho), Image.LANCZOS, box=box))
          for c in range(4)]
    A = ch[3]
    opaque = A >= 128.0
    rgbo = np.stack([np.clip(ch[c] / np.maximum(A, 1e-3) * 255.0, 0, 255) for c in range(3)], -1)
    out = np.zeros((ho, wo, 4), np.uint8)
    out[..., :3] = np.where(opaque[..., None], np.round(rgbo), 0).astype(np.uint8)
    out[..., 3] = np.where(opaque, 255, 0)
    return out

def lum(rgb):
    rgb = rgb.astype(np.float32)
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]

def drop_small(rgba, min_px=5):
    al = rgba[..., 3] > 0
    lab, n = label(al)
    sz = np.bincount(lab.ravel(), minlength=n + 1)
    kill = np.isin(lab, [k for k in range(1, n + 1) if sz[k] < min_px])
    rgba = rgba.copy(); rgba[kill] = 0
    return rgba, int(kill.sum())

def edge_fix(rgba, light_tol=24.0, white_lum=170.0, ring=2):
    """Kill any light / white fringe on the silhouette (no painting, only recolour).

    Outer 1 px ring: a pixel is recoloured from the nearest pixel inside it when it
    is lighter than that pixel by > light_tol (halo) or when it is light/near-white
    itself (lum > white_lum). Near-white pixels (lum > 200, low saturation) in the
    outer `ring` px are recoloured too. Replacement colour comes from the nearest
    pixel at depth >= ring+1 whose lum <= white_lum (so a pale painted bevel stays
    one pixel inside the edge, but never forms a white rim on the silhouette)."""
    al = rgba[..., 3] > 0
    inner1 = erode(al, 1)
    deep = erode(al, ring)
    if not deep.any():
        return rgba, 0
    L = lum(rgba[..., :3])
    sat = rgba[..., :3].max(-1).astype(np.float32) - rgba[..., :3].min(-1)
    src = deep & (L <= white_lum)
    if not src.any():
        src = deep
    iy, ix = nearest_index(src)
    jy, jx = nearest_index(inner1) if inner1.any() else (iy, ix)
    edge = al & ~inner1
    band = al & ~deep
    bad = (edge & ((L > L[jy, jx] + light_tol) | (L > white_lum))) | (band & (L > 200) & (sat < 40))
    out = rgba.copy()
    out[bad, :3] = rgba[iy[bad], ix[bad], :3]
    return out, int(bad.sum())

def halo_stats(rgba):
    al = rgba[..., 3] > 0
    inner = erode(al, 1); edge = al & ~inner; deep = erode(al, 3)
    L = lum(rgba[..., :3]); r, g, b = [rgba[..., i].astype(np.float32) for i in range(3)]
    sat = np.max(rgba[..., :3], -1).astype(np.float32) - np.min(rgba[..., :3], -1)
    return dict(edge_px=int(edge.sum()), edge_mean_lum=round(float(L[edge].mean()), 1),
                interior_mean_lum=round(float(L[deep].mean()), 1),
                edge_px_lum_gt_170=int((edge & (L > 170)).sum()),
                edge_px_near_white=int((edge & (L > 200) & (sat < 40)).sum()))

# ---------------------------------------------------------------- boots / soles
def _blob_stats(rgba, lab, k, y_off):
    yy, xx = np.nonzero(lab == k)
    yy = yy + y_off
    rgb = rgba[yy, xx, :3].astype(np.float32)
    L = lum(rgb)
    red = rgb[:, 0] - (rgb[:, 1] + rgb[:, 2]) / 2
    return dict(size=len(yy), bottom=int(yy.max()), top=int(yy.min()), cx=float(xx.mean()),
                lum=float(L.mean()), red=float(red.mean()),
                bbox=[int(xx.min()), int(yy.min()), int(xx.max()), int(yy.max())])

def find_boots(rgba, dark_max=58.0, red_max=28.0,
               passes=((0.12, 0.06), (0.16, 0.10), (0.20, 0.15))):
    """Return dict(sole_y, mid_x, boots=[bbox..]) for an RGBA figure (standing poses).

    Boots = the bottom-most DARK blobs near the body centre column. For each pass
    (band_frac, near_frac): the bottom band (band_frac of figure height) is
    labelled; candidate blobs reach within near_frac*H of the lowest row, are dark
    (mean lum < dark_max; axe blades are lighter steel), not cape red (mean
    R-(G+B)/2 < red_max) and within 0.45*width of the body centre column (median
    column of the 45-75% height rows). One boot is taken on each side of the centre
    column (largest of the two closest). The first pass that yields two boots at
    least 0.06*H apart wins (pass 1 is the original attack-S rule; later passes
    handle a raised / crouched boot). sole_y = lowest boot row, mid_x = mean of the
    two boot centroids."""
    al = rgba[..., 3] > 0
    ys, xs = np.nonzero(al)
    top, bot = ys.min(), ys.max()
    Hf = bot - top + 1
    width = xs.max() - xs.min() + 1
    r0, r1 = top + int(0.45 * Hf), top + int(0.75 * Hf)
    cx = float(np.median(np.nonzero(al[r0:r1])[1]))
    best = None
    for pi, (band_frac, near_frac) in enumerate(passes):
        b0 = bot - int(band_frac * Hf)
        lab, n = label(al[b0:bot + 1])
        blobs = [_blob_stats(rgba, lab, k, b0) for k in range(1, n + 1)]
        good = [b for b in blobs if b['lum'] < dark_max and b['red'] < red_max
                and abs(b['cx'] - cx) < 0.45 * width]
        if not good:
            continue
        low = max(b['bottom'] for b in good)
        big = max(b['size'] for b in good)
        cand = [b for b in good if b['bottom'] >= low - near_frac * Hf and b['size'] >= 0.2 * big]
        cand.sort(key=lambda b: abs(b['cx'] - cx))
        left = [b for b in cand if b['cx'] < cx]
        right = [b for b in cand if b['cx'] >= cx]
        boots = []
        if left: boots.append(max(left[:2], key=lambda b: b['size']))
        if right: boots.append(max(right[:2], key=lambda b: b['size']))
        if len(boots) < 2 and len(cand) > 1:
            boots = [cand[0]] + [max([b for b in cand[1:] if abs(b['cx'] - cand[0]['cx']) > 0.06 * Hf] or cand[1:2],
                                     key=lambda b: b['size'])]
        boots.sort(key=lambda b: b['cx'])
        ok = len(boots) == 2 and abs(boots[1]['cx'] - boots[0]['cx']) > 0.06 * Hf
        if best is None or ok:
            best = (boots, pi)
        if ok:
            break
    boots, pi = best
    sole = max(b['bottom'] for b in boots)
    mid = float(np.mean([b['cx'] for b in boots]))
    return dict(sole_y=int(sole), mid_x=mid, body_cx=cx, boots=[b['bbox'] for b in boots],
                boot_stats=[{k: (round(v, 1) if isinstance(v, float) else v) for k, v in b.items()
                             if k in ('size', 'lum', 'red')} for b in boots],
                n_boots=len(boots), boot_pass=pi, lowest_opaque_row=int(bot))

def body_ground(rgba):
    """For lying / kneeling / falling frames: lowest row of the MAIN body component
    (separate dropped props ignored) and its column centroid."""
    al = rgba[..., 3] > 0
    lab, n = label(al)
    sz = np.bincount(lab.ravel(), minlength=n + 1); sz[0] = 0
    main = lab == int(np.argmax(sz))
    ys, xs = np.nonzero(main)
    return dict(sole_y=int(ys.max()), mid_x=float(xs.mean()), boots=[], n_boots=0,
                lowest_opaque_row=int(np.nonzero(al)[0].max()), mode='body_lowest_row')

# ---------------------------------------------------------------- placement
def place(fig, cell_w, cell_h, pivot_y, boots=None, mode='boots'):
    """Whole-pixel placement: soles -> pivot_y, boot midpoint -> pivot x.
    pivot x = cell_w/2 as a pixel-edge coordinate (between columns w/2-1 and w/2)."""
    b = boots or (find_boots(fig) if mode == 'boots' else body_ground(fig))
    dx = int(round(cell_w / 2.0 - 0.5 - b['mid_x']))
    dy = int(pivot_y - b['sole_y'])
    cell = np.zeros((cell_h, cell_w, 4), np.uint8)
    h, w = fig.shape[:2]
    ys, xs = np.nonzero(fig[..., 3])
    lost = int(((ys + dy < 0) | (ys + dy >= cell_h) | (xs + dx < 0) | (xs + dx >= cell_w)).sum())
    sy0, sx0 = max(0, -dy), max(0, -dx)
    sy1, sx1 = min(h, cell_h - dy), min(w, cell_w - dx)
    cell[sy0 + dy:sy1 + dy, sx0 + dx:sx1 + dx] = fig[sy0:sy1, sx0:sx1]
    return cell, dict(dx=dx, dy=dy, clipped_px=lost, **b)

def extents(fig, b, pivot_y):
    """Extents of a figure relative to pivot (sole row, boot midpoint)."""
    ys, xs = np.nonzero(fig[..., 3])
    mid = b['mid_x'] + 0.5  # edge coordinate of pivot
    return dict(left=float(mid - xs.min()), right=float(xs.max() + 1 - mid),
                up=int(b['sole_y'] - ys.min()), down=int(ys.max() - b['sole_y']))

def margins(cell):
    al = cell[..., 3] > 0
    ys, xs = np.nonzero(al)
    h, w = al.shape
    return dict(left=int(xs.min()), right=int(w - 1 - xs.max()), top=int(ys.min()), bottom=int(h - 1 - ys.max()))

def save_rgba(arr, path):
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    Image.fromarray(arr, 'RGBA').save(path, optimize=True)

def mirror(arr):
    return arr[:, ::-1].copy()

def strip(frames):
    h, w = frames[0].shape[:2]
    out = np.zeros((h, w * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        out[:, i * w:(i + 1) * w] = f
    return out

def breath_frame(cell, frac=0.55, px=1, boots=None):
    """Rows above the hip line (top `frac` of figure height, helm->soles) moved down px.
    Rows at/below the hip line are untouched (legs pixel-identical)."""
    b = boots or find_boots(cell)
    ys = np.nonzero(cell[..., 3])[0]
    top = int(ys.min()); H = b['sole_y'] - top
    hip = top + int(round(frac * H))  # first untouched row is hip+1
    out = cell.copy()
    out[top + px:hip + 1] = cell[top:hip + 1 - px]
    out[top:top + px] = 0
    return out, dict(hip_row=hip, figure_top=top, figure_h=H)


# ---------------------------------------------------------------- ground dirt (painted streaks)
def remove_ground_dirt(rgb, fig_mask, band_top, protect=(), sat_max=22, lum_min=40, min_keep=150):
    """Remove painted ground dirt / shadow streaks fused to the figure (source res).

    Only the figure's main body component is touched (separate dropped props are
    kept as they are), and only rows >= band_top. Dirt = low-saturation
    (max-min < sat_max), not-black (lum >= lum_min) pixels connected (8-conn,
    through such pixels) to the outside background: the painted armour keeps its
    dark outline / red cape so the flood stops there. protect = list of
    (x0, y0, x1, y1[, 'below_line' slope]) boxes never removed (e.g. axe blades that
    lie in the dirt, a pale boot toe). Afterwards detached leftovers of the former
    body smaller than min_keep px (dark dirt specks) are dropped."""
    rgb = rgb.astype(np.float32)
    lab, n = label(fig_mask)
    sz = np.bincount(lab.ravel(), minlength=n + 1); sz[0] = 0
    body = lab == int(np.argmax(sz))
    L = lum(rgb); S = rgb.max(-1) - rgb.min(-1)
    band = np.zeros_like(fig_mask); band[band_top:] = True
    prot = np.zeros_like(fig_mask)
    for bx in protect:
        x0, y0, x1, y1 = bx[:4]
        prot[y0:y1 + 1, x0:x1 + 1] = True
    cand = body & band & (S < sat_max) & (L >= lum_min) & ~prot
    bgd = np.pad(~fig_mask, 1, constant_values=True)
    near_bg = np.zeros_like(fig_mask)
    for dy in range(3):
        for dx in range(3):
            near_bg |= bgd[dy:dy + fig_mask.shape[0], dx:dx + fig_mask.shape[1]]
    cl, cn = label(cand)
    ids = np.unique(cl[cand & near_bg]); ids = ids[ids > 0]
    dirt = np.isin(cl, ids)
    out = fig_mask & ~dirt
    rl, rn = label(out & body)
    rs = np.bincount(rl.ravel(), minlength=rn + 1); rs[0] = 0
    keep_main = int(np.argmax(rs))
    specks = (rl > 0) & (rl != keep_main) & (rs[rl] < min_keep)
    out &= ~specks
    return out, dict(dirt_px=int(dirt.sum()), speck_px=int(specks.sum()), band_top=int(band_top),
                     protect=[list(b) for b in protect])

def process_figures(sheet, cols, rows, scale, slots=None, dirt=None, mirror_slots=(),
                    key_thresh=40, min_speck=30, band=2, max_attach_dist=None):
    """Like process() but with per-slot options.
    dirt = {slot: dict(band_top=.., protect=[..])}; mirror_slots = slots flipped
    horizontally after scaling (before feet/x detection)."""
    rgb = np.asarray(Image.open(sheet).convert('RGB')).astype(np.float32)
    masks, seg = segment_sheet(rgb.astype(np.uint8), cols, rows, key_thresh, min_speck, max_attach_dist)
    figs, info = {}, {}
    for i, m in enumerate(masks):
        if slots is not None and i not in slots:
            continue
        rec = dict(sheet_slot=i)
        if dirt and i in dirt:
            m, rec['dirt'] = remove_ground_dirt(rgb, m, **dirt[i])
        clean = decontaminate_src(rgb, m, band)
        f = scale_figure(clean, m, scale)
        f, rec['dropped_px_after_scale'] = drop_small(f, 40 if (dirt and i in dirt) else 5)
        f, rec['edge_px_recoloured'] = edge_fix(f)
        if i in mirror_slots:
            f = mirror(f); rec['mirrored'] = True
        ys, xs = np.nonzero(m)
        rec['src_bbox'] = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
        rec['raw_mask'] = m
        figs[i] = f; info[i] = rec
    return figs, info, seg

def ready_height(fig):
    """helm-top (topmost opaque row) to sole row, for a standing figure."""
    b = find_boots(fig)
    return b['sole_y'] - int(np.nonzero(fig[..., 3])[0].min())

def scale_for_height(sheet, cols, rows, slot, target=265, s0=None, ref=(281, 0.9459), dirt=None,
                     max_attach_dist=None):
    """Pick the sheet scale so the ready stance (slot) measures `target` px helm->sole
    after scaling. Start from the raw-height ratio against attack S (281 raw px at
    0.9459) and nudge in 0.0005 steps until the measured height equals target."""
    rgb = np.asarray(Image.open(sheet).convert('RGB'))
    masks, _ = segment_sheet(rgb, cols, rows, max_attach_dist=max_attach_dist)
    m = masks[slot]
    if dirt and slot in dirt:
        m, _ = remove_ground_dirt(rgb, m, **dirt[slot])
    raw = np.zeros(m.shape + (4,), np.uint8); raw[..., :3] = rgb; raw[..., 3] = m * 255; raw[~m] = 0
    h_raw = ready_height(raw)
    s = s0 or round(ref[1] * ref[0] / h_raw, 4)
    rgbf = rgb.astype(np.float32)
    clean = decontaminate_src(rgbf, m, 2)
    tried = {}
    for _ in range(40):
        f, _ = drop_small(scale_figure(clean, m, s), 5)
        h = ready_height(f); tried[s] = h
        if h == target:
            break
        s = round(s + (0.0005 if h < target else -0.0005), 4)
        if s in tried:
            break
    best = min(tried, key=lambda k: (abs(tried[k] - target), abs(k - ref[1] * ref[0] / h_raw)))
    return best, dict(raw_ready_height=int(h_raw), measured_ready_height=int(tried[best]), tried=tried)

# ---------------------------------------------------------------- warm rim (recolour only)
RIM_COLOR = (0x9a, 0x7a, 0x58)

def rim_eligible(rgba, ground=None, hip_frac=0.55, lying=False):
    """Pixels allowed to take the rim: not cape/blood red; standing frames only above
    the hip line (helm, horns, pauldrons, spikes, raised axes) or outside the leg
    column span below it (axe heads / hands held out); lying frames everywhere
    except cape."""
    a = rgba.astype(np.float32)
    mx, mn = a[..., :3].max(-1), a[..., :3].min(-1)
    sat = (mx - mn) / np.maximum(mx, 1)
    redhue = (a[..., 0] >= a[..., 1]) & (a[..., 0] >= a[..., 2]) & (a[..., 0] - np.maximum(a[..., 1], a[..., 2]) > 12)
    cape = redhue & (sat > 0.33)
    al = rgba[..., 3] > 0
    elig = al & ~cape
    if not lying:
        g = ground or find_boots(rgba)
        ys = np.nonzero(al)[0]; top = ys.min(); H = g['sole_y'] - top
        hip = top + int(round(hip_frac * H))
        if g.get('boots'):
            lx = min(b[0] for b in g['boots']) - 4; rx = max(b[2] for b in g['boots']) + 4
        else:
            lx = rx = -1
        yy, xx = np.indices(al.shape)
        legs = (yy > hip) & (xx >= lx) & (xx <= rx)
        elig &= ~legs
    return elig

def apply_rim(rgba, strength, elig=None, color=RIM_COLOR, width=2, light=(-1.0, -1.0), lit_min=0.25,
              lit_full=0.70, ring2=0.6, light_px_factor=0.4):
    """Warm rim: recolour (never alpha) the outer `width` px on edges whose outward
    normal faces the light (upper-left). a = strength * w(normal) on ring 1,
    ring2*strength*w on ring 2; pixels already lighter than the rim colour get
    light_px_factor of that (warm tint, no darkening of pale bevels)."""
    al = rgba[..., 3] > 0
    if elig is None:
        elig = al
    if HAVE_SCIPY:
        d = ndi.distance_transform_edt(al)
        sm = ndi.gaussian_filter(al.astype(np.float32), 1.5)
        gy, gx = np.gradient(sm)
    else:  # pragma: no cover
        raise RuntimeError('rim needs scipy')
    nx, ny = -gx, -gy
    nn = np.hypot(nx, ny) + 1e-6
    lx, ly = light; ln = np.hypot(lx, ly)
    lit = (nx * lx + ny * ly) / nn / ln
    w = np.clip((lit - lit_min) / (lit_full - lit_min), 0, 1)
    ringw = np.where(d <= 1.0, 1.0, np.where(d <= width + 0.5, ring2, 0.0))
    a = strength * w * ringw * elig
    rimL = lum(np.array(color, np.float32)[None, None])[0, 0]
    L = lum(rgba[..., :3])
    a = np.where(L > rimL, a * light_px_factor, a)
    out = rgba.copy()
    col = np.array(color, np.float32)
    rgb = rgba[..., :3].astype(np.float32)
    out[..., :3] = np.where(al[..., None], np.round(rgb * (1 - a[..., None]) + col * a[..., None]), 0).astype(np.uint8)
    return out, dict(rim_px=int((a > 0.01).sum()), mean_a=round(float(a[a > 0.01].mean()) if (a > 0.01).any() else 0, 3))

def rim_warmth(rgba, elig=None, light=(-1.0, -1.0)):
    """Mean warmth (R-B) and lum over lit-edge eligible ring-1 pixels."""
    al = rgba[..., 3] > 0
    if elig is None: elig = al
    d = ndi.distance_transform_edt(al)
    sm = ndi.gaussian_filter(al.astype(np.float32), 1.5)
    gy, gx = np.gradient(sm)
    lit = (-gx * light[0] - gy * light[1]) / (np.hypot(gx, gy) + 1e-6) / np.hypot(*light)
    sel = elig & (d <= 1.0) & (lit > 0.5)
    a = rgba[..., :3].astype(np.float32)
    return dict(n=int(sel.sum()), warm=round(float((a[..., 0] - a[..., 2])[sel].mean()), 2),
                lum=round(float(lum(a)[sel].mean()), 2))

def pad_to_cell(cell, w, h, pivot_y_src, pivot_y_dst):
    """Re-centre a standard-cell frame into a bigger cell (pivot x = centre)."""
    H0, W0 = cell.shape[:2]
    out = np.zeros((h, w, 4), np.uint8)
    ox = (w - W0) // 2; oy = pivot_y_dst - pivot_y_src
    out[oy:oy + H0, ox:ox + W0] = cell
    return out

# ---------------------------------------------------------------- main pipeline
def process(sheet, cols, rows, scale, key_thresh=40, min_speck=30, band=2):
    rgb = np.asarray(Image.open(sheet).convert('RGB')).astype(np.float32)
    masks, seg = segment_sheet(rgb.astype(np.uint8), cols, rows, key_thresh, min_speck)
    figs, info = [], []
    for i, m in enumerate(masks):
        clean = decontaminate_src(rgb, m, band)
        f = scale_figure(clean, m, scale)
        f, n_drop = drop_small(f, 5)
        f, n_fix = edge_fix(f)
        b = find_boots(f)
        figs.append(f)
        ys, xs = np.nonzero(m)
        info.append(dict(sheet_slot=i, src_bbox=[int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
                         dropped_px_after_scale=n_drop, edge_px_recoloured=n_fix,
                         halo=halo_stats(f), boots=b))
    return figs, info, seg

def _parse_dirt(items):
    """--dirt SLOT:BAND_TOP[:x0,y0,x1,y1[;x0,y0,x1,y1...]]"""
    out = {}
    for it in items:
        parts = it.split(':')
        d = dict(band_top=int(parts[1]))
        if len(parts) > 2 and parts[2]:
            d['protect'] = [tuple(int(v) for v in bx.split(',')) for bx in parts[2].split(';')]
        out[int(parts[0])] = d
    return out

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('sheet')
    ap.add_argument('--cols', type=int, required=True)
    ap.add_argument('--rows', type=int, required=True)
    ap.add_argument('--order', required=True, help='comma list: output frame i = sheet slot order[i]')
    ap.add_argument('--anim', required=True)
    ap.add_argument('--facing', required=True)
    ap.add_argument('--mirror-as', default=None, help='also write horizontal flips under this facing (W for S, N for E)')
    ap.add_argument('--out', required=True)
    ap.add_argument('--scale', type=float, default=None, help='ONE shared scale factor for the sheet')
    ap.add_argument('--auto-scale-slot', type=int, default=None,
                    help='instead of --scale: pick the scale so this ready-stance slot measures --target-height')
    ap.add_argument('--target-height', type=int, default=265, help='ready stance helm-top to sole, px')
    ap.add_argument('--cell', type=int, nargs=2, default=[512, 360], metavar=('W', 'H'))
    ap.add_argument('--pivot-y', type=int, default=329)
    ap.add_argument('--margin', type=int, default=8)
    ap.add_argument('--char', default='ironjaw')
    ap.add_argument('--spare', action='append', default=[], help='slot:path to save a dropped sheet frame')
    ap.add_argument('--mirror-slot', type=int, action='append', default=[], help='flip this sheet slot before placing')
    ap.add_argument('--body-slot', type=int, action='append', default=[],
                    help='place this slot by lowest main-body row + body centroid (lying / kneeling death frames)')
    ap.add_argument('--dirt', action='append', default=[],
                    help='remove painted ground dirt: SLOT:BAND_TOP[:x0,y0,x1,y1;...protect boxes] (source px)')
    ap.add_argument('--max-attach-dist', type=float, default=80, help='drop components farther than this from any body')
    ap.add_argument('--extents-only', action='store_true')
    ap.add_argument('--report', default=None, help='write a JSON report here')
    a = ap.parse_args(argv)
    W, H = a.cell
    if W % 2:
        raise SystemExit('cell width must be even so the pivot x = W/2 survives a horizontal flip')
    order = [int(v) for v in a.order.split(',')]
    dirt = _parse_dirt(a.dirt)
    scale_info = None
    if a.auto_scale_slot is not None:
        a.scale, scale_info = scale_for_height(a.sheet, a.cols, a.rows, a.auto_scale_slot, a.target_height,
                                               dirt=dirt, max_attach_dist=a.max_attach_dist)
        print(f'auto scale {a.scale} ({scale_info["raw_ready_height"]} raw px -> {scale_info["measured_ready_height"]})')
    if a.scale is None:
        raise SystemExit('give --scale or --auto-scale-slot')
    figs_d, info_d, seg = process_figures(a.sheet, a.cols, a.rows, a.scale, dirt=dirt, mirror_slots=tuple(a.mirror_slot),
                                          max_attach_dist=a.max_attach_dist)
    n = a.cols * a.rows
    figs = [figs_d[i] for i in range(n)]
    info = [{k: v for k, v in info_d[i].items() if k != 'raw_mask'} for i in range(n)]
    for i in range(n):
        info[i]['boots'] = body_ground(figs[i]) if i in a.body_slot else find_boots(figs[i])
        info[i]['mode'] = 'body' if i in a.body_slot else 'boots'
    ext = [extents(f, i['boots'], a.pivot_y) for f, i in zip(figs, info)]
    need_w = 2 * int(np.ceil(max(max(e['left'], e['right']) for e in ext) + a.margin))
    need_up = max(e['up'] for e in ext) + a.margin
    need_down = max(e['down'] for e in ext) + a.margin
    summary = dict(sheet=a.sheet, scale=a.scale, scale_info=scale_info, segmentation=seg, extents=ext,
                   min_cell_w=need_w, min_pivot_y=need_up, min_rows_below_pivot=need_down)
    if a.extents_only:
        print(json.dumps(summary, indent=1, default=str)); return summary
    if a.pivot_y < need_up or H - 1 - a.pivot_y < need_down or W < need_w:
        raise SystemExit(f'cell {W}x{H} pivot_y {a.pivot_y} too small: need W>={need_w}, '
                         f'pivot_y>={need_up}, rows below pivot>={need_down}')
    placed = {}
    for slot in set(order) | {int(s.split(':')[0]) for s in a.spare}:
        placed[slot] = place(figs[slot], W, H, a.pivot_y, info[slot]['boots'], info[slot]['mode'])
    frames, rep = [], []
    for i, slot in enumerate(order):
        cell, pl = placed[slot]
        frames.append(cell)
        p = os.path.join(a.out, f'{a.char}_{a.anim}_{a.facing}_f{i:02d}.png')
        save_rgba(cell, p)
        rep.append(dict(frame=i, sheet_slot=slot, path=p, margins=margins(cell), placement=pl))
        if a.mirror_as:
            save_rgba(mirror(cell), os.path.join(a.out, f'{a.char}_{a.anim}_{a.mirror_as}_f{i:02d}.png'))
    save_rgba(strip(frames), os.path.join(a.out, f'{a.char}_{a.anim}_{a.facing}_strip.png'))
    if a.mirror_as:
        save_rgba(strip([mirror(f) for f in frames]), os.path.join(a.out, f'{a.char}_{a.anim}_{a.mirror_as}_strip.png'))
    for s in a.spare:
        slot, path = s.split(':', 1)
        save_rgba(placed[int(slot)][0], path)
    summary.update(frames=rep, figures_info=info, cell=[W, H], pivot=[W / 2, a.pivot_y])
    if a.report:
        with open(a.report, 'w') as fh:
            json.dump(summary, fh, indent=1, default=str)
    return summary, placed, figs, info

if __name__ == '__main__':
    main()
