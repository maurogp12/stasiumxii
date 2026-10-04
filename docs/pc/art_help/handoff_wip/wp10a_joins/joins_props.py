"""WP10a joins props: corridor pieces (stone ford, cliff-pass steps), level signs, border end caps.

All outputs are 2x masters + exact-half 1x (box), straight alpha, RGB 0 under alpha 0, Crosshaven prop anchor rule
(image bottom-centre = south tip of the footprint's south-most cell).
"""
from __future__ import annotations
import json, sys
from pathlib import Path
import numpy as np, cv2
sys.path.insert(0, str(Path(__file__).parent))
from wp10a_common import load_rgba, save_rgba, premul, unpremul, down_box, to_lab, hex2rgb, smoothstep, resize_pm

HERE = Path(__file__).parent
SHIP = Path('/workspace/stasium-pc-look/ship')
CHP = Path('/workspace/stasium-repo/art/world/crosshaven')
PLATE = json.loads((HERE / 'src' / 'plate_samples.json').read_text())


def lab_of(hx):
    return to_lab(hex2rgb(hx)[None, None])[0, 0]


# ------------------------------------------------------------------ grade (plate + Crosshaven stone), outlines kept
def crosshaven_stone_lab():
    vals = []
    for n in ('rock_large_b', 'quarry_rocks_a'):
        t = load_rgba(CHP / 'props/_2x' / f'{n}.png'); a = t[..., 3] > 0.9
        lab = to_lab(t[..., :3])[a]; vals.append(lab[lab[:, 0] > 35].mean(0))
    return np.mean(vals, 0)


def grade_corridor(rgba, t_stone=0.5, t_L=0.15, t_water=0.45, snow_keep=True):
    """Small hue/value moves: stone -> plate warm grey / cliff white (+ Crosshaven rock), water -> plate/Crosshaven blue.
    Dark outline pixels (L < 28) are untouched; weights fade in over L 28..40."""
    out = rgba.copy()
    lab = to_lab(rgba[..., :3]); L, A, B = lab[..., 0], lab[..., 1], lab[..., 2]
    chroma = np.hypot(A, B)
    grey, white = lab_of(PLATE['stone_warm_grey']['hex']), lab_of(PLATE['stone_cliff_white']['hex'])
    chs = crosshaven_stone_lab()
    # per-pixel target a/b: warm grey for mid values, cliff white for light, averaged with the Crosshaven rock
    k = smoothstep(55, 88, L)[..., None]
    tgt = (grey * (1 - k) + white * k) * 0.5 + chs * 0.5
    keep = smoothstep(28, 40, L)
    stone = keep * (1 - smoothstep(18, 30, chroma)) * (1 - smoothstep(-6, -12, B) * 0)   # low-chroma stone
    water = keep * smoothstep(4, 10, -B) * smoothstep(8, 16, chroma) * (A < 2)
    if snow_keep:
        stone = stone * (1 - smoothstep(90, 96, L))          # leave snow caps alone
    wt = (lab_of(PLATE['water_clear_blue']['hex']) + lab_of('#3285ab')) / 2   # plate blue + Crosshaven water_a mean
    lab2 = lab.copy()
    for ch, t in ((1, t_stone), (2, t_stone)):
        lab2[..., ch] += stone * t * (tgt[..., ch] - lab[..., ch])
    lab2[..., 0] += stone * t_L * (tgt[..., 0] - L)
    m = water > 0.01
    if m.any():
        mw = lab[m].mean(0)
        lab2 += water[..., None] * t_water * (wt - mw)[None, None]
    out[..., :3] = np.clip(cv2.cvtColor(lab2.astype(np.float32), cv2.COLOR_Lab2RGB), 0, 1)
    return out, dict(stone_px=int((stone > 0.5).sum()), water_px=int((water > 0.5).sum()),
                     stone_target_lab=[round(float(x), 1) for x in tgt[stone > 0.5].mean(0)] if (stone > 0.5).any() else None)


# ------------------------------------------------------------------ iso helpers (2x px, relative to the footprint N vertex)
def w2s(x, y):
    return 64.0 * (x - y), 32.0 * (x + y)


def s2w(X, Y):
    return X / 128.0 + Y / 64.0, Y / 64.0 - X / 128.0


def rectify(rgba, res=96):
    """Raw screen art -> ground-rectified grid (x_r, y_r raw units, res px per unit), premultiplied remap."""
    h, w = rgba.shape[:2]
    a = rgba[..., 3] > 0.5
    ys, xs = np.nonzero(a)
    xr = xs / 128 + ys / 64; yr = ys / 64 - xs / 128
    x0, x1, y0, y1 = xr.min() - 0.1, xr.max() + 0.1, yr.min() - 0.1, yr.max() + 0.1
    W, H = int((x1 - x0) * res), int((y1 - y0) * res)
    gx, gy = np.meshgrid(x0 + (np.arange(W) + 0.5) / res, y0 + (np.arange(H) + 0.5) / res)
    X = 64 * (gx - gy) - 0.5; Y = 32 * (gx + gy) - 0.5
    R = cv2.remap(premul(rgba), X.astype(np.float32), Y.astype(np.float32), cv2.INTER_CUBIC, borderValue=0)
    return np.clip(R, 0, 1), (x0, y0, res)


def unrectify(Rpm, geom, shape):
    x0, y0, res = geom
    h, w = shape
    Y, X = np.indices((h, w), np.float32)
    X += 0.5; Y += 0.5
    gx = X / 128 + Y / 64; gy = Y / 64 - X / 128
    u = (gx - x0) * res - 0.5; v = (gy - y0) * res - 0.5
    out = cv2.remap(Rpm, u.astype(np.float32), v.astype(np.float32), cv2.INTER_CUBIC, borderValue=0)
    return unpremul(np.clip(out, 0, 1))


def stitch_shorten(rgba, keep_frac_len, band=(0.38, 0.62)):
    """Shorten a causeway along world x by cutting out its middle: one seam path p(y) that runs through dark joints / gaps in
    BOTH the left cut (x = p) and the right cut (x = p + D); the right part slides back by D so the join lands on joints."""
    Rpm, geom = rectify(rgba)
    H, W = Rpm.shape[:2]
    al = Rpm[..., 3]
    cols = np.nonzero(al.max(0) > 0.5)[0]; xa, xb = cols.min(), cols.max()
    Ltot = xb - xa; keep = int(round(Ltot * keep_frac_len)); D = Ltot - keep
    rgb = unpremul(Rpm)[..., :3]
    lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)
    cost = np.where(al > 0.3, lum + 0.15, 0.0).astype(np.float32)      # joints (dark) and empty pixels are cheap
    cost = cv2.GaussianBlur(cost, (0, 0), 1.2)
    lo = xa + int(band[0] * keep); hi = xa + int(band[1] * keep)
    span = np.arange(lo, hi)
    C = cost[:, span] + cost[:, span + D]
    # DP top -> bottom, path moves at most 1 column per row
    acc = C.copy(); back = np.zeros_like(C, np.int32)
    for r in range(1, H):
        prev = acc[r - 1]
        cand = np.stack([np.r_[np.inf, prev[:-1]], prev, np.r_[prev[1:], np.inf]])
        k = np.argmin(cand, 0); back[r] = k - 1
        acc[r] += cand[k, np.arange(len(span))]
    p = np.zeros(H, np.int32); p[-1] = int(np.argmin(acc[-1]))
    for r in range(H - 1, 0, -1):
        p[r - 1] = p[r] + back[r, p[r]]
    p = span[np.clip(p, 0, len(span) - 1)]
    out = np.zeros_like(Rpm)
    xx = np.arange(W)
    for r in range(H):
        left = xx < p[r]
        out[r, left] = Rpm[r, left]
        src = xx + D
        ok = (~left) & (src < W)
        out[r, ok] = Rpm[r, src[ok]]
    # 2 px cross-fade along the stitch so the two joints merge
    res = unrectify(out, geom, rgba.shape[:2])
    return res, dict(removed_frac=round(D / Ltot, 3), seam_cost=float(acc[-1].min() / H), seam_cols=[int(p.min()), int(p.max())])


# ------------------------------------------------------------------ placement
def art_ground_bbox(rgba):
    a = rgba[..., 3] > 0.5
    ys, xs = np.nonzero(a)
    xr = xs / 128 + ys / 64; yr = ys / 64 - xs / 128
    return np.percentile(xr, 0.3), np.percentile(xr, 99.7), np.percentile(yr, 0.3), np.percentile(yr, 99.7)


def place_flat(rgba, fx, fy, ss=4):
    """Scale + place a flat corridor art so its ground bbox fills the fx x fy footprint. Returns a big 2x canvas and the
    canvas position of the footprint N vertex."""
    x0, x1, y0, y1 = art_ground_bbox(rgba)
    s = min(fx / (x1 - x0), fy / (y1 - y0))        # raw units -> cells
    # raw px -> 2x px scale: 1 raw unit = 1 cell => (128,64) raw px per (1,0) == (128,64) 2x px per cell => factor s
    return place_scaled(rgba, s, (x0, y0), fx, fy, ss), s


def place_scaled(rgba, s, origin_r, fx, fy, ss=4, pad=(260, 420)):
    """Big working canvas (2x px): footprint N vertex at (cx, cy); raw point origin_r (x_r, y_r) -> world (0,0)."""
    Wc = int((fx + fy) * 64 + 2 * pad[0]); Hc = int((fx + fy) * 32 + pad[1] + 40)
    cx, cy = pad[0] + fy * 64, pad[1]
    # affine raw px -> canvas: canvas = s * raw + t, with raw point of origin_r landing on (cx, cy)
    X0, Y0 = 64 * (origin_r[0] - origin_r[1]), 32 * (origin_r[0] + origin_r[1])
    M = np.float32([[s, 0, cx - s * X0], [0, s, cy - s * Y0]])
    Mss = M.copy(); Mss *= ss
    big = cv2.warpAffine(premul(rgba), Mss, (Wc * ss, Hc * ss), flags=cv2.INTER_AREA if s * ss < 1 else cv2.INTER_CUBIC, borderValue=0)
    big = np.clip(big, 0, 1)
    can = unpremul(big.reshape(Hc, ss, Wc, ss, 4).mean((1, 3)))
    return can, (cx, cy)


def split_halves(can, nvert, fx, fy, axis, half_canvas=(384, 512)):
    """Cut a placed fx x fy corridor canvas into two halves across `axis` ('y': y<fy/2 | y>=fy/2, 'x': same for x).
    Partition = the ground line at the half boundary, extended vertically past its ends (halves are complementary, so the
    two sprites drawn at their anchors rebuild the full piece exactly). Returns [(sprite2x, footprint, offset_cells)]."""
    cx, cy = nvert
    Hc, Wc = can.shape[:2]
    Y, X = np.indices((Hc, Wc), np.float32); X = X + 0.5 - cx; Y = Y + 0.5 - cy
    if axis == 'y':
        m = fy / 2.0                                   # line y = m, x in [0, fx]: (64(x-m), 32(x+m))
        Xa, Ya = w2s(0, m); Xb, Yb = w2s(fx, m)       # left-top end -> right-bottom end (slope +0.5)
        Xc = np.clip(X, Xa, Xb); Yl = Ya + (Xc - Xa) * 0.5
        second = np.where(X < Xa, False, np.where(X > Xb, True, Y > Yl))
        # beyond the right end use the vertical extension: the y>=m half owns everything right of the line end
        parts = [(~second, (fx, int(m)), (0, 0)), (second, (fx, fy - int(m)), (0, int(m)))]
    else:
        m = fx / 2.0                                   # line x = m, y in [0, fy]: slope -0.5
        Xa, Ya = w2s(m, 0); Xb, Yb = w2s(m, fy)       # top-right end (Xa > Xb)
        Xc = np.clip(X, Xb, Xa); Yl = Ya + (Xa - Xc) * 0.5
        second = np.where(X > Xa, True, np.where(X < Xb, False, Y < Yl))
        parts = [(~second, (int(m), fy), (0, 0)), (second, (fx - int(m), fy), (int(m), 0))]
    outs = []
    hw, hh = half_canvas
    for mask, (pfx, pfy), (ox, oy) in parts:
        # anchor: south tip of this half's south-most cell = world (ox + pfx, oy + pfy)
        AX, AY = w2s(ox + pfx, oy + pfy)
        ax, ay = int(round(cx + AX)), int(round(cy + AY))
        piece = can.copy(); piece[..., 3] *= mask
        x0, y0 = ax - hw // 2, ay - hh
        spr = np.zeros((hh, hw, 4), np.float32)
        sx0, sy0 = max(0, x0), max(0, y0); sx1, sy1 = min(Wc, x0 + hw), min(Hc, y0 + hh)
        spr[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = piece[sy0:sy1, sx0:sx1]
        lost = float(piece[..., 3].sum() - spr[..., 3].sum())
        outs.append(dict(sprite=spr, footprint=[pfx, pfy], offset=[ox, oy], clipped_alpha=round(lost, 1)))
    return outs


def finish_sprite(spr2):
    """2x -> (2x clean, 1x exact half via box on premultiplied)."""
    s2 = spr2.copy(); s2[..., 3] = np.where(s2[..., 3] < 1.5 / 255, 0, s2[..., 3])
    s1 = down_box(s2, 2)
    return s2, s1


def save_prop(out, pid, s2, s1):
    save_rgba(out / 'props' / '_2x' / f'{pid}.png', s2)
    save_rgba(out / 'props' / f'{pid}.png', s1)


def measure(s2):
    a = s2[..., 3] > 0.5
    ys, xs = np.nonzero(a)
    H, W = a.shape
    return dict(art_x_from_anchor_2x=[int(xs.min() - W / 2), int(xs.max() - W / 2)], art_height_2x=int(H - ys.min()),
                lowest_gap_2x=int(H - 1 - ys.max()))


# ------------------------------------------------------------------ signs
def max_rect(mask):
    """Largest axis-aligned all-True rectangle (x, y, w, h)."""
    h, w = mask.shape; best = (0, 0, 0, 0, 0); hist = np.zeros(w, int)
    for r in range(h):
        hist = np.where(mask[r], hist + 1, 0)
        st = []
        for i in range(w + 1):
            cur = hist[i] if i < w else 0
            start = i
            while st and st[-1][1] >= cur:
                s0, hh = st.pop()
                area = hh * (i - s0)
                if area > best[0]:
                    best = (area, s0, r - hh + 1, i - s0, hh)
                start = s0
            st.append((start, cur))
    return best[1:]


def build_sign(raw_cut, pid, out, board_rule, max_h=168, max_w=118):
    rgba = load_rgba(raw_cut)
    a = rgba[..., 3] > 0.5; ys, xs = np.nonzero(a)
    crop = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = crop.shape[:2]
    s = min(max_h / h, max_w / w)
    W2, H2 = 128, 224
    nw, nh = int(round(w * s)), int(round(h * s))
    sc = resize_pm(crop, (nw, nh))
    spr = np.zeros((H2, W2, 4), np.float32)
    # bottom-most opaque point (post foot / pedestal tip) sits 2 px above the canvas bottom, centred on the anchor column
    al = sc[..., 3] > 0.5
    yb = np.nonzero(al.any(1))[0].max()
    xb = np.nonzero(al[max(0, yb - 6):yb + 1].any(0))[0]; xc = (xb.min() + xb.max()) / 2
    x0 = int(round(W2 / 2 - xc)); y0 = H2 - 2 - yb
    sx0, sy0 = max(0, x0), max(0, y0)
    spr[sy0:y0 + nh, sx0:x0 + nw] = sc[sy0 - y0:, sx0 - x0:][:H2 - sy0, :W2 - sx0]
    s2, s1 = finish_sprite(spr)
    # label rect: largest rectangle inside the blank board face, emblem excluded
    lab = to_lab(s2[..., :3]); L, A, B = lab[..., 0], lab[..., 1], lab[..., 2]
    board, emblem = board_rule(s2, L, A, B)
    board &= s2[..., 3] > 0.98
    board = cv2.erode(board.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    emb = cv2.dilate(emblem.astype(np.uint8), np.ones((9, 9), np.uint8)) > 0
    x, y, rw, rh = max_rect(board & ~emb)
    save_prop(out, pid, s2, s1)
    m = measure(s2)
    return dict(id=pid, label_rect_2x=[int(x), int(y), int(rw), int(rh)],
                label_rect_1x=[int(x // 2), int(y // 2), int(rw // 2), int(rh // 2)], scale_raw_to_2x=round(s, 4), **m)


def board_rowanvale(s2, L, A, B):
    hsv = cv2.cvtColor(s2[..., :3].astype(np.float32), cv2.COLOR_RGB2HSV)
    wood = (hsv[..., 0] > 15) & (hsv[..., 0] < 40) & (hsv[..., 1] > 0.45) & (L > 35)
    emblem = (hsv[..., 0] > 38) & (hsv[..., 0] < 60) & (hsv[..., 1] > 0.55) & (L > 60)
    # board rows: wood wider than 60% of the widest wood row
    wr = wood.sum(1); rows = wr > 0.6 * wr.max()
    return wood & rows[:, None], emblem


def board_windmere(s2, L, A, B):
    plank = (B > 9) & (L > 62) & (np.hypot(A, B) < 40)
    emblem = (B < -8) & (L > 40)
    return plank, emblem


# ------------------------------------------------------------------ end caps (seam crop of the shipped border art)
def end_cap(src2, side, win=(14, 62), target=40, outline_hex='#2a1c12'):
    """Trim one screen side of a 1-cell border sprite along a minimum-cost vertical path that prefers transparent pixels
    and the art's own dark outlines (clump / trunk boundaries), then feather 1 px and darken the cut rim slightly.
    side: 'right' trims x > anchor + path, 'left' trims x < anchor - path. Returns (sprite2x, report)."""
    s = src2.copy()
    H, W = s.shape[:2]; ax = W // 2
    if side == 'left':
        s = s[:, ::-1].copy()
    al = s[..., 3]; lum = s[..., :3] @ np.array([0.3, 0.59, 0.11], np.float32)
    cost = np.where(al > 0.2, 0.25 + lum, 0.0) * np.maximum(al, 0.0)
    cols = np.arange(ax + win[0], min(W - 1, ax + win[1]))
    C = cost[:, cols] + 0.004 * np.abs(cols - (ax + target))[None, :]
    acc = C.copy(); back = np.zeros_like(C, np.int32)
    for r in range(1, H):
        prev = acc[r - 1]
        cand = np.stack([np.r_[np.inf, prev[:-1]], prev, np.r_[prev[1:], np.inf]])
        k = np.argmin(cand, 0); back[r] = k - 1; acc[r] += cand[k, np.arange(len(cols))]
    p = np.zeros(H, np.int32); p[-1] = int(np.argmin(acc[-1]))
    for r in range(H - 1, 0, -1):
        p[r - 1] = p[r] + back[r, p[r]]
    px = cols[np.clip(p, 0, len(cols) - 1)].astype(np.float32)
    X = np.arange(W, dtype=np.float32)[None, :] + 0.5
    keep = 1 - smoothstep(px[:, None] - 0.8, px[:, None] + 0.8, X)
    cut_opaque = al * (1 - keep)
    out = s.copy(); out[..., 3] = al * keep
    # rim darkening where the path crossed opaque fill (not outline): reads as the art's own outline
    rim = (np.abs(X - px[:, None]) < 2.2) & (al > 0.6) & (lum[...] > 0.25)
    ol = hex2rgb(outline_hex)
    out[..., :3] = np.where(rim[..., None], out[..., :3] * 0.45 + ol * 0.55, out[..., :3])
    crossed = float((cost[np.arange(H), px.astype(int)] > 0.3).sum())
    rep = dict(path_x_range=[int(px.min() - ax), int(px.max() - ax)], crossed_fill_rows=int(crossed),
               removed_alpha_frac=round(float(cut_opaque.sum() / max(al.sum(), 1)), 3))
    if side == 'left':
        out = out[:, ::-1].copy()
    return out, rep


def end_cap_squash(src2, side, a=10, b=60):
    """Alternative end cap: no cut. The gap-side part of the art (x > anchor + a) is remapped so its outermost column lands
    at anchor + b (a smooth, monotone x squash; outlines and whole boughs/clumps are kept, the run just stops short of the
    neighbour cell). side 'left' mirrors."""
    s = src2.copy()
    H, W = s.shape[:2]; ax = W / 2
    if side == 'left':
        s = s[:, ::-1].copy()
    al = s[..., 3]
    xmax = np.nonzero(al.max(0) > 0.02)[0].max() + 1.0 - ax           # outermost art column (rel. anchor)
    if xmax <= b:
        out = s
    else:
        # output column t in [a, b] samples source u in [a, xmax]; ease so du/dt = 1 at t = a
        t = np.arange(W, dtype=np.float32) + 0.5 - ax
        k = np.clip((t - a) / (b - a), 0, None)
        span = xmax - a
        # u = a + (b-a)*k + (span-(b-a)) * k^2 for k in [0,1]  (slope 1 at k=0, reaches xmax at k=1)
        u = np.where(t <= a, t, a + (b - a) * k + (span - (b - a)) * np.minimum(k, 1) ** 2 + np.maximum(k - 1, 0) * (b - a) * 3)
        mapx = np.tile((u + ax - 0.5)[None, :], (H, 1)).astype(np.float32)
        mapy = np.tile((np.arange(H, dtype=np.float32))[:, None], (1, W))
        out = unpremul(np.clip(cv2.remap(premul(s), mapx, mapy, cv2.INTER_AREA if False else cv2.INTER_LINEAR, borderValue=0), 0, 1))
    if side == 'left':
        out = out[:, ::-1].copy()
    return out, dict(method='squash', art_edge_before=int(xmax), art_edge_after=int(b))
