#!/usr/bin/env python3
"""STASIUM XII PC: file-level import check for the fighter-class sprite sets.

Read-only on /workspace/art/<char>_full/<ver>/. Writes a JSON + markdown report.
Usage: python3 check_chars.py [--art /workspace/art] [--out /workspace/stasium-pc-look/ship/characters_pc]
"""
import argparse, glob, json, os, re, colorsys
from collections import Counter, defaultdict
import numpy as np
from PIL import Image

FACINGS = ["S", "W", "N", "E"]
# Claimed table (status PDF). frames, fps, cell, pivot per facing
def P(x, y): return {f: (x, y) for f in FACINGS}
VERSIONS = {"ironjaw": {
  "v2": dict(dir="ironjaw_full/v2", states={
      "walk": (12, 1000/58.33, (161,155), P(78,133)), "idle": (4, 4, (161,155), P(78,133)),
      "attack": (6, 12, (161,155), P(78,133)), "hit": (4, 12, (161,155), P(78,133)),
      "death": (6, 10, (205,178), P(102,133))}),
  # v3 (2026-10-03): v2 padded by integer shifts (+4/+2 px; death +2/+2), centred pivot x, pivot y on the soles (old 138)
  "v3": dict(dir="ironjaw_full/v3", states={
      "walk": (12, 1000/58.33, (165,157), P(82,140)), "idle": (4, 4, (165,157), P(82,140)),
      "attack": (6, 12, (165,157), P(82,140)), "hit": (4, 12, (165,157), P(82,140)),
      "death": (6, 10, (209,183), P(104,140))}),
}}
# v3.2 (2026-10-03): movement fix of v3.1 (walk N/E re-phased to start on the idle stance boot); same cells / pivots / fps
VERSIONS["ironjaw"]["v3.2"] = dict(VERSIONS["ironjaw"]["v3"], dir="ironjaw_full/v3.2")
CLAIM = {
  "ironjaw": VERSIONS["ironjaw"]["v3.2"],
  "kestrel": dict(dir="kestrel_full/v3", states={
      "walk": (12, 1000/58.33, (116,160), P(68,141)), "idle": (4, 4, (116,160), P(68,141)),
      "attack": (6, 12, (116,160), P(68,141)), "hit": (4, 12, (116,160), P(68,141)),
      "death": (6, 10, (296,160), P(158,141)), "cast": (6, 10, (116,160), P(68,141)),
      "cast_mark": (6, 12, (116,160), P(68,141))}),
  "gloam": dict(dir="gloam_full/v4", states={s: (n, fps, (135,160), {"S":(74,142),"N":(74,142),"W":(60,142),"E":(60,142)})
      for s, n, fps in [("walk",12,1000/58.33),("idle",4,4),("attack",5,12),("hit",4,12),("cast",4,10)]}),
  "bastion": dict(dir="bastion_full/v4", states={
      "walk": (12, 1000/58.33, (160,196), P(80,165)), "idle": (4, 4, (160,196), P(80,165)),
      "attack": (6, 12, (220,196), P(110,165)), "hit": (4, 12, (160,196), P(80,165)),
      "death": (6, 10, (330,196), P(165,165))}),
  "mender": dict(dir="mender_full/v3", states={
      "walk": (12, 1000/58.33, (129,183), P(64,175)), "idle": (4, 4, (129,179), P(64,175)),
      "hit": (4, 12, (129,179), P(64,175)), "cast": (6, 10, (129,200), P(64,196)),
      "death": (6, 10, (230,179), {"S":(64,175),"E":(64,175),"W":(165,175),"N":(165,175)})}),
}
CLAIM["gloam"]["states"]["death"] = (6, 10, (240,160), {"S":(90,142),"W":(149,142),"N":(150,142),"E":(89,142)})
# mirror pairs claimed: (target, source)
ONE_HAND = {"ironjaw": "two axes (one per hand)", "kestrel": "bow (left hand in S)", "gloam": "twin daggers",
            "bastion": "shield + mace", "mender": "staff (one hand)"}
GUIDE = {"kestrel": "chalk sky, pale gold, feather white (not electric cyan)",
         "ironjaw": "ochre, baked clay, iron black (not plastic bronze)",
         "mender": "tide green, shell, linen (not hospital teal)",
         "gloam": "warm dusk, ink, dried flower (not magenta cyber)",
         "bastion": "limestone, olive, old gold (not hazard yellow)"}

def load(path):
    a = np.array(Image.open(path).convert("RGBA"))
    return a

def mask(a): return a[..., 3] > 127

def sole_row(m, minpx=1):
    rows = np.where(m.sum(1) >= minpx)[0]
    return int(rows.max()) if len(rows) else None

def bbox(m):
    ys, xs = np.where(m)
    if not len(ys): return None
    return [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]

def feet_x(m, band=6):
    s = sole_row(m)
    if s is None: return None
    sub = m[max(0, s-band+1):s+1]
    xs = np.where(sub.any(0))[0]
    return float((xs.min() + xs.max()) / 2.0)

def foot_columns(m, band=3):
    s = sole_row(m); sub = m[max(0, s-band+1):s+1]
    return np.where(sub.any(0))[0]

def edge_px(m, margin):
    h, w = m.shape
    b = np.zeros_like(m); b[:margin] = b[-margin:] = True; b[:, :margin] = b[:, -margin:] = True
    return int((m & b).sum())

def luma(rgb): return 0.299*rgb[..., 0] + 0.587*rgb[..., 1] + 0.114*rgb[..., 2]

def shift_img(a, dx, dy):
    out = np.zeros_like(a); h, w = a.shape[:2]
    xs0, xs1 = max(0, dx), min(w, w+dx); ys0, ys1 = max(0, dy), min(h, h+dy)
    out[ys0:ys1, xs0:xs1] = a[ys0-dy:ys1-dy, xs0-dx:xs1-dx]
    return out

def mirror_match(src, dst, srange=range(-6, 7)):
    """Is dst == horizontal flip of src (plus x shift)? returns best shift, alpha IoU, rgb-identical share."""
    if src.shape != dst.shape: return None
    fl = src[:, ::-1]
    best = None
    md = mask(dst)
    for s in srange:
        f = shift_img(fl, s, 0); mf = mask(f)
        u = (mf | md).sum(); i = (mf & md).sum()
        iou = i / u if u else 0
        if best is None or iou > best[1]:
            same = (mf & md)
            rgb_eq = (np.abs(f[..., :3].astype(int) - dst[..., :3].astype(int)).max(-1) <= 2) & same
            best = (s, float(iou), float(rgb_eq.sum() / max(1, u)))
    return best

def best_shift(a, b, r=10, rows=None):
    """translation (dx,dy) of b that best overlays a (mask IoU)."""
    ma, mb = mask(a), mask(b)
    if rows is not None:
        sel = np.zeros_like(ma); sel[rows[0]:rows[1]] = True; ma = ma & sel
    best = (0, 0, -1)
    for dy in range(-r, r+1):
        for dx in range(-r, r+1):
            m2 = shift_img(mb[..., None].astype(np.uint8), dx, dy)[..., 0] > 0
            if rows is not None: m2 = m2 & sel
            u = (ma | m2).sum(); i = (ma & m2).sum()
            iou = i / u if u else 0
            if iou > best[2]: best = (dx, dy, iou)
    return best

def planted_shift(a, b, piv_y, r_x=14, r_y=8):
    """Track the planted foot between consecutive walk frames: shift of the bottom band that best overlaps.
    Uses a narrow band at the sole; returns subpixel (dx, dy) via parabolic refine."""
    ma, mb = mask(a), mask(b)
    s = max(sole_row(ma), sole_row(mb))
    lo, hi = max(0, s-14), s+1
    A = np.zeros_like(ma); A[lo:hi] = ma[lo:hi]
    B = np.zeros_like(mb); B[lo-r_y if lo-r_y > 0 else 0:hi+r_y] = mb[lo-r_y if lo-r_y > 0 else 0:hi+r_y]
    sc = np.zeros((2*r_y+1, 2*r_x+1))
    for iy, dy in enumerate(range(-r_y, r_y+1)):
        for ix, dx in enumerate(range(-r_x, r_x+1)):
            m2 = shift_img(B[..., None].astype(np.uint8), dx, dy)[..., 0] > 0
            sc[iy, ix] = (A & m2).sum()
    iy, ix = np.unravel_index(np.argmax(sc), sc.shape)
    def refine(v, i):
        if 0 < i < len(v)-1:
            d = v[i-1] - 2*v[i] + v[i+1]
            return i + (0.5*(v[i-1]-v[i+1])/d if d != 0 else 0)
        return float(i)
    fx = refine(sc[iy], ix) - r_x; fy = refine(sc[:, ix], iy) - r_y
    return float(fx), float(fy), float(sc[iy, ix] / max(1, A.sum()))

def palette(frames):
    px = np.concatenate([f[mask(f)][:, :3] for f in frames], 0).astype(float) / 255
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in px[::7]])
    neon = float(((hsv[:, 1] > 0.85) & (hsv[:, 2] > 0.85)).mean())
    hi_sat = float(((hsv[:, 1] > 0.7) & (hsv[:, 2] > 0.6)).mean())
    # weighted hue histogram (12 bins of 30 deg) over pixels with s>0.15
    sel = hsv[:, 1] > 0.15
    hist, _ = np.histogram(hsv[sel, 0]*360, bins=12, range=(0, 360))
    hist = hist / max(1, len(hsv))
    names = ["red","orange","yellow","yel-green","green","green-cyan","cyan","azure","blue","violet","magenta","rose"]
    top = sorted(zip(hist, names), reverse=True)[:4]
    # 5 dominant colours (median cut)
    q = Image.fromarray((px[::3]*255).astype(np.uint8).reshape(-1, 1, 3)).quantize(5, method=Image.MEDIANCUT)
    pal = q.getpalette()[:15]; cnt = sorted(q.getcolors(), reverse=True)
    dom = ["#%02x%02x%02x" % tuple(pal[i*3:i*3+3]) for _, i in cnt]
    cyanish = float(((hsv[:, 0]*360 > 170) & (hsv[:, 0]*360 < 200) & (hsv[:, 1] > 0.5) & (hsv[:, 2] > 0.5)).mean())
    magenta = float(((hsv[:, 0]*360 > 285) & (hsv[:, 0]*360 < 335) & (hsv[:, 1] > 0.5) & (hsv[:, 2] > 0.5)).mean())
    return dict(neon_share=round(neon, 5), high_sat_share=round(hi_sat, 4), grey_share=round(float((~sel).mean()), 3),
                top_hues=[(n, round(float(h), 3)) for h, n in top], dominant=dom, mean_value=round(float(hsv[:, 2].mean()), 3),
                vivid_cyan_share=round(cyanish, 5), vivid_magenta_share=round(magenta, 5))

def check_char(art, name, cfg):
    root = os.path.join(art, cfg["dir"])
    R = dict(char=name, dir=root, issues=[], states={})
    files = glob.glob(os.path.join(root, "*", "*.png"))
    rx = re.compile(r"^%s_(?P<state>[a-z_]+)_(?P<f>[SWNE])_f(?P<n>\d\d)\.png$" % name)
    rs = re.compile(r"^%s_(?P<state>[a-z_]+)_(?P<f>[SWNE])_strip\.png$" % name)
    frames = defaultdict(dict); strips = {}; odd = []
    for p in files:
        b = os.path.basename(p); m = rx.match(b); ms = rs.match(b)
        if m and os.path.basename(os.path.dirname(p)) == m["state"]:
            frames[(m["state"], m["f"])][int(m["n"])] = p
        elif ms: strips[(ms["state"], ms["f"])] = p
        else: odd.append(os.path.relpath(p, root))
    R["unexpected_files"] = sorted(o for o in odd if "contact" not in o)
    states_on_disk = sorted({s for s, _ in frames})
    R["extra_states"] = sorted(set(states_on_disk) - set(cfg["states"]))
    R["missing_states"] = sorted(set(cfg["states"]) - set(states_on_disk))
    img = {}
    for st, (n, fps, cell, piv) in cfg["states"].items():
        S = R["states"][st] = dict(claim=dict(frames=n, fps=round(fps, 3), cell=cell, pivot=piv), facings={})
        for fc in FACINGS:
            fr = frames.get((st, fc), {})
            F = S["facings"][fc] = {}
            idx = sorted(fr)
            F["frames"] = len(idx)
            if idx != list(range(n)):
                R["issues"].append(f"{st} {fc}: frames {idx} expected 0..{n-1}")
            arrs = [load(fr[i]) for i in idx]
            img[(st, fc)] = arrs
            sizes = sorted({(a.shape[1], a.shape[0]) for a in arrs})
            F["sizes"] = sizes
            if sizes != [tuple(cell)]:
                R["issues"].append(f"{st} {fc}: cell sizes {sizes} vs claim {cell}")
            if (st, fc) in strips:
                sa = Image.open(strips[(st, fc)]); F["strip"] = sa.size
                if sa.size != (cell[0]*n, cell[1]):
                    F["strip_note"] = f"strip {sa.size} != {cell[0]*n}x{cell[1]}"
            px, py = piv[fc]
            soles = [sole_row(mask(a)) for a in arrs]
            soles3 = [sole_row(mask(a), 3) for a in arrs]
            fxs = [feet_x(mask(a)) for a in arrs]
            F["sole_rows"] = soles; F["sole_rows_min3px"] = soles3
            F["sole_dev_vs_pivot_y"] = [s - py for s in soles]
            F["feet_x"] = [round(x, 1) for x in fxs]
            F["feet_x_dev_vs_pivot_x"] = [round(x - px, 1) for x in fxs]
            F["bbox"] = [bbox(mask(a)) for a in arrs]
            F["edge_touch_px"] = [edge_px(mask(a), 1) for a in arrs]
            F["edge_within2_px"] = [edge_px(mask(a), 2) for a in arrs]
            F["edge_within4_px"] = [edge_px(mask(a), 4) for a in arrs]
            F["min_margin_px"] = [min(b[0], b[1], a.shape[1]-1-b[2], a.shape[0]-1-b[3]) for a, b in ((a, bbox(mask(a))) for a in arrs)]
            # alpha / rgb under alpha0 / fringe
            al = set(); under = Counter(); bright_edge = 0; edge_n = 0; el = []; il = []
            for a in arrs:
                al |= set(np.unique(a[..., 3]).tolist())
                z = a[..., 3] == 0
                under.update(map(tuple, np.unique(a[z][:, :3], axis=0)[:5].tolist()))
                m = mask(a)
                inner = m.copy(); inner[1:] &= m[:-1]; inner[:-1] &= m[1:]; inner[:, 1:] &= m[:, :-1]; inner[:, :-1] &= m[:, 1:]
                edge = m & ~inner
                L = luma(a[..., :3].astype(float))
                el.append(L[edge].mean()); il.append(L[inner].mean() if inner.any() else 0)
                bright_edge += int(((L > 200) & edge).sum()); edge_n += int(edge.sum())
            F["alpha_values"] = sorted(al)
            F["rgb_under_alpha0"] = [list(k) for k in list(under)[:3]]
            F["edge_luma_mean"] = round(float(np.mean(el)), 1); F["interior_luma_mean"] = round(float(np.mean(il)), 1)
            F["bright_fringe_px"] = bright_edge
    R["_img"] = img
    return R

def analyse(R, cfg):
    name = R["char"]; img = R["_img"]; out = {}
    # pivot summary
    piv = {}
    for st, S in R["states"].items():
        for fc, F in S["facings"].items():
            d = F["sole_dev_vs_pivot_y"]; fx = F["feet_x_dev_vs_pivot_x"]
            piv[f"{st}_{fc}"] = dict(sole_min=min(F["sole_rows"]), sole_max=max(F["sole_rows"]), pivot=S["claim"]["pivot"][fc],
                                     dev_y_range=[min(d), max(d)], f0_dev_y=d[0], f0_feet_x_dev=fx[0])
    out["pivot"] = piv
    # state switch jump vs idle f0 (pivot aligned)
    jumps = {}
    for fc in FACINGS:
        ida = img[("idle", fc)][0]; ipv = cfg["states"]["idle"][3][fc]
        im_ = mask(ida); s0 = sole_row(im_); x0 = feet_x(im_)
        for st in R["states"]:
            if st == "idle": continue
            a = img[(st, fc)][0]; pv = cfg["states"][st][3][fc]; m = mask(a)
            s1 = sole_row(m); x1 = feet_x(m)
            # place both on a common canvas by pivot, measure body shift (IoU) in the upper body
            H = 2*max(a.shape[0], ida.shape[0]) + 20; W = 2*max(a.shape[1], ida.shape[1]) + 20
            def place(arr, p):
                c = np.zeros((H, W, 4), np.uint8); ox, oy = W//2 - p[0], H//2 - p[1]
                c[oy:oy+arr.shape[0], ox:ox+arr.shape[1]] = arr; return c
            ci, cs = place(ida, ipv), place(a, pv)
            dx, dy, iou = best_shift(ci, cs, r=8)
            jumps[f"{fc}_idle->{st}"] = dict(sole_jump=(s1 - pv[1]) - (s0 - ipv[1]), feetx_jump=round((x1 - pv[0]) - (x0 - ipv[0]), 1),
                                            body_best_shift=[dx, dy], body_iou=round(iou, 3))
    out["state_jumps_f0"] = jumps
    # mirrors
    mir = {}
    for st in R["states"]:
        for a_fc, b_fc in [("W", "S"), ("N", "E"), ("E", "N")]:
            A, B = img[(st, a_fc)], img[(st, b_fc)]
            res = [mirror_match(b, a) for a, b in zip(A, B)]
            if any(r is None for r in res): continue
            ious = [r[1] for r in res]; eq = [r[2] for r in res]; sh = Counter(r[0] for r in res).most_common(1)[0][0]
            mir[f"{st}_{a_fc}_vs_flip{b_fc}"] = dict(shift=sh, iou_min=round(min(ious), 4), rgb_identical_min=round(min(eq), 4),
                                                   is_flip=bool(min(eq) > 0.97))
    out["mirrors"] = mir
    # figure height
    hts = {}
    for fc in FACINGS:
        b = bbox(mask(img[("idle", fc)][0])); hts[fc] = dict(h=b[3]-b[1]+1, w=b[2]-b[0]+1, top=b[1], sole=b[3])
    out["idle_f0_height"] = hts
    # walk tracking
    wk = {}
    for fc in FACINGS:
        fr = img[("walk", fc)]; py = cfg["states"]["walk"][3][fc][1]
        sh = [planted_shift(fr[i], fr[(i+1) % len(fr)], py) for i in range(len(fr))]
        tx = -sum(s[0] for s in sh); ty = -sum(s[1] for s in sh)
        wk[fc] = dict(per_frame=[[round(-s[0], 2), round(-s[1], 2), round(s[2], 2)] for s in sh],
                      travel_xy=[round(tx, 1), round(ty, 1)], travel_len=round(float(np.hypot(tx, ty)), 1),
                      angle_deg=round(float(np.degrees(np.arctan2(ty, tx))), 1),
                      soles=R["states"]["walk"]["facings"][fc]["sole_rows"])
    out["walk_track"] = wk
    # palette
    allf = [a for k, v in img.items() for a in v]
    out["palette"] = palette(allf)
    out["palette"]["guide"] = GUIDE[name]
    # edge touches
    et = {}
    for st, S in R["states"].items():
        for fc, F in S["facings"].items():
            for i, (t, w2) in enumerate(zip(F["edge_touch_px"], F["edge_within2_px"])):
                if w2: et[f"{name}_{st}_{fc}_f{i:02d}"] = dict(touch_px=t, within2_px=w2)
    out["edge"] = et
    # one-line summary (added for the Ironjaw v3 re-check; generic for every set)
    fr_counts = {f"{st}_{fc}": F["frames"] for st, S in R["states"].items() for fc, F in S["facings"].items()}
    mm = [m for S in R["states"].values() for F in S["facings"].values() for m in F["min_margin_px"]]
    out["summary"] = dict(
        frames_total=sum(fr_counts.values()),
        edge_touch_px_total=int(sum(sum(F["edge_touch_px"]) for S in R["states"].values() for F in S["facings"].values())),
        frames_within2=len(et), frames_margin_lt4=int(sum(1 for m in mm if m < 4)), min_margin_px=int(min(mm)),
        idle_f0_sole_vs_pivot={fc: R["states"]["idle"]["facings"][fc]["sole_dev_vs_pivot_y"][0] for fc in FACINGS},
        f0_sole_vs_pivot={k: v["f0_dev_y"] for k, v in piv.items()},
        mirrors_exact={k: (v["is_flip"] and v["rgb_identical_min"] == 1.0, v["shift"]) for k, v in mir.items()},
        state_switch_f0={k: dict(sole=v["sole_jump"], body=v["body_best_shift"]) for k, v in jumps.items()})
    return out


# ---------- extra checks (facing switch, walk torso, strips, edge sides, foot tracker) ----------
from collections import deque
def label(m):
    lab = np.zeros(m.shape, int); n = 0; h, w = m.shape
    for y0, x0 in zip(*np.where(m)):
        if lab[y0, x0]: continue
        n += 1; q = deque([(y0, x0)]); lab[y0, x0] = n
        while q:
            y, x = q.popleft()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y+dy, x+dx
                    if 0 <= yy < h and 0 <= xx < w and m[yy, xx] and not lab[yy, xx]:
                        lab[yy, xx] = n; q.append((yy, xx))
    return lab, n

def track_pair(a, b, rx=16, ry=10):
    """planted-foot motion between consecutive walk frames (RGB match of each foot blob in the sole band)."""
    ma = mask(a); s = sole_row(ma)
    band = np.zeros_like(ma); band[max(0, s-16):s+1] = True
    lab, n = label(ma & band); A = a.astype(float); B = b.astype(float); h, w = ma.shape; best = None
    for k in range(1, n+1):
        ys, xs = np.where(lab == k)
        if len(ys) < 25: continue
        errs = {}
        for dy in range(-ry, ry+1):
            for dx in range(-rx, rx+1):
                y2, x2 = ys+dy, xs+dx; ok = (y2 >= 0) & (y2 < h) & (x2 >= 0) & (x2 < w)
                if ok.mean() < 0.9: continue
                pa = A[ys[ok], xs[ok]]; pb = B[y2[ok], x2[ok]]
                errs[(dx, dy)] = (np.abs(pa[:, :3]-pb[:, :3]).mean(1)*(pb[:, 3] > 127) + 255*(pb[:, 3] <= 127)).mean()
        (dx, dy), e = min(errs.items(), key=lambda t: t[1])
        if best is None or e < best[0]: best = (float(e), dx, dy)
    return best

def extra_checks(R, cfg):
    name = R["char"]; root = os.path.join("/workspace/art", cfg["dir"]); X = {}
    img = lambda st, fc, i=0: load(f"{root}/{st}/{name}_{st}_{fc}_f{i:02d}.png")
    # facing switch on idle f0: sole and head top relative to pivot
    fs = {}
    for fc in FACINGS:
        b = bbox(mask(img("idle", fc))); py = cfg["states"]["idle"][3][fc][1]
        fs[fc] = dict(sole_minus_pivot=b[3]-py, head_above_pivot=py-b[1], height=b[3]-b[1]+1)
    soles = [v["sole_minus_pivot"] for v in fs.values()]; hs = [v["height"] for v in fs.values()]
    X["facing_switch_idle"] = dict(per_facing=fs, feet_jump_px=max(soles)-min(soles), height_ratio=round(max(hs)/min(hs), 3))
    # walk torso vs idle f0 (upper 40% band)
    wt = {}
    for fc in FACINGS:
        idle = img("idle", fc); bb = bbox(mask(idle)); h = bb[3]-bb[1]; res = []
        for i in range(cfg["states"]["walk"][0]):
            wf = img("walk", fc, i)
            ii = idle
            if wf.shape != idle.shape:
                ii = np.zeros_like(wf); ii[:idle.shape[0], :idle.shape[1]] = idle
            dx, dy, _ = best_shift(ii, wf, r=12, rows=(bb[1], bb[1]+int(0.4*h))); res.append([dx, dy])
        r = np.array(res); wt[fc] = dict(per_frame=res, mean=[round(float(v), 1) for v in r.mean(0)], worst_dy=int(r[:, 1].min()) if abs(r[:, 1].min()) > abs(r[:, 1].max()) else int(r[:, 1].max()))
    X["walk_torso_vs_idle"] = wt
    # walk track direction: sole range + early-stance foot vectors
    wd = {}
    for fc in FACINGS:
        n = cfg["states"]["walk"][0]; fr = [img("walk", fc, i) for i in range(n)]
        soles = [sole_row(mask(f)) for f in fr]
        tr = [track_pair(fr[i], fr[(i+1) % n]) for i in range(n)]
        good = [t for t in tr if t and abs(t[1]) < 15 and abs(t[2]) < 9]
        e = np.array([t[0] for t in good]); good = [t for t in good if t[0] <= np.percentile(e, 50)]
        v = np.array([[t[1], t[2]] for t in good], float)
        ang = float(np.degrees(np.arctan2(np.abs(v[:, 1]).mean(), np.abs(v[:, 0]).mean()))) if len(v) else None
        wd[fc] = dict(sole_range=[min(soles), max(soles)], track="horizontal" if max(soles)-min(soles) <= 2 else "iso-diagonal",
                      foot_angle_deg=round(ang, 1) if ang is not None else None,
                      est_travel_per_cycle=round(float(np.hypot(*np.abs(v).mean(0))*n), 1) if len(v) else None)
    X["walk_direction"] = wd
    # strips == frames?
    sm = {}
    for st, (n, fps, cell, piv) in cfg["states"].items():
        for fc in FACINGS:
            cand = glob.glob(f"{root}/*/{name}_{st}_{fc}_strip.png")
            if not cand: sm[f"{st}_{fc}"] = "missing"; continue
            sa = load(cand[0]); cat = np.concatenate([img(st, fc, i) for i in range(n)], 1)
            sm[f"{st}_{fc}"] = "match" if sa.shape == cat.shape and (np.abs(sa.astype(int)-cat.astype(int))[..., 3].max() == 0) else "DIFFERS"
    X["strips"] = {k: v for k, v in sm.items() if v != "match"} or "all match frames"
    # edge sides
    es = defaultdict(Counter)
    for st, (n, fps, cell, piv) in cfg["states"].items():
        for fc in FACINGS:
            for i in range(n):
                m = mask(img(st, fc, i))
                for side, v in (("top", m[0]), ("bottom", m[-1]), ("left", m[:, 0]), ("right", m[:, -1])):
                    if v.any(): es[f"{st}_{fc}"][side] += 1
    X["edge_touch_sides"] = {k: dict(v) for k, v in es.items()}
    return X

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--art", default="/workspace/art")
    ap.add_argument("--out", default="/workspace/stasium-pc-look/ship/characters_pc/check_chars_report.json")
    ap.add_argument("--chars", nargs="*", default=list(CLAIM))
    ap.add_argument("--ver", nargs="*", default=[], help="override set version, e.g. --ver ironjaw=v2")
    a = ap.parse_args()
    for kv in a.ver:
        k, v = kv.split("="); CLAIM[k] = VERSIONS[k][v]
    full = {}
    for n in a.chars:
        R = check_char(a.art, n, CLAIM[n]); R["analysis"] = analyse(R, CLAIM[n]); R.pop("_img"); R["extra"] = extra_checks(R, CLAIM[n])
        full[n] = R
        print(f"== {n}: issues {len(R['issues'])}, extra states {R['extra_states']}, missing {R['missing_states']}, odd files {R['unexpected_files'][:6]}")
    json.dump(full, open(a.out, "w"), indent=1, default=lambda o: list(o) if isinstance(o, tuple) else str(o))
    print("wrote", a.out)

if __name__ == "__main__":
    main()
