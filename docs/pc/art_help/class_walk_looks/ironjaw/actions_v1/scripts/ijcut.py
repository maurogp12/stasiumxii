"""Ironjaw actions v1 - cut the painted parts of his current walk (ironjaw_walk v7) into the pieces the action rig needs.
Everything is written to ../parts as full 1280x720 target-px RGBA canvases (legs too, resampled into target px).

Source: the walk's own layer cut (v7/scripts/layers6.py, run unchanged on the walk's targets rp_S_turn_t1 / rp_E_stride_t2
with the walk's cfg6.json polygons), so idle f00 is the walk's upper body. Two changes to that cut:
  * the hidden cape behind the arms / legs (and, on E, the back plate behind the cape) is filled by copying real cloth /
    armour pixels from shifted patches of the same painting (patch_fill), not the walk's Telea + noise;
  * the arm layers are split into pieces that can be posed (below), and the holes they leave in the torso are filled the
    same way.
Pieces per facing F (side = his R / L; S: near = R, far = L; E: left = L, right = R):
  body_F        torso, helm-less neck, pauldron-free shoulders, belt, skulls, tassets and loincloth; holes filled.
  head_F        the helm (horns, visor, red eyes) as its own piece, for the head snap in hit and the death roll.
  cape_F        the cape (S behind him, E over his back), wcape_F its skin weights (R upper panel, G lower panel).
  pauld_{R,L}_F the pauldrons, rigid on the torso, drawn over the arm root.
  uarm_{R,L}_F  the upper arm (rerebrace), grown under the pauldron from its own painted section.
  fore_{R,L}_F  vambrace + gauntlet fist + axe as ONE rigid piece, the fist closed on the haft as painted.
  leg_{R,L}_{thigh,shin,boot}_F   the walk's painted leg pieces (legs_v6_pieces; S shins as in the walk's legs_v4 are not
                in the repo, so S uses the v6 shins), graded to the walk's leg colours (Lab mean/std, a*b* x0.4).
  ijoints_F.json  joints in target px, and the walk scale / f00 placement.
usage: ijcut.py [debug.png]     env IJ_SRC = extracted ironjaw_walk tree (default: git archive of art/ironjaw-walk-help)"""
import os, sys, json, types, subprocess
import numpy as np, cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from skimage.color import rgb2lab, lab2rgb
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '../../../../../../..'))
OUT = os.environ.get('IJPARTS', os.path.join(HERE, '..', 'parts'))
IJ_COMMIT = '0f3eeb801f5bf679d6082e248e99490a81ff2580'          # art/ironjaw-walk-help: v7 walk, targets, legs, cfg
REPLY_COMMIT = '19b4ac113d7906412b8481f9660a602f46aa5b5c'       # claude/ironjaw-walk-help-reply: cut.py, match_metric.py
SH = (720, 1280)

def src_root():
    root = os.environ.get('IJ_SRC', '/tmp/ironjaw_actions_v1_src')
    if not os.path.exists(f'{root}/docs/pc/art_help/ironjaw_walk/v7/scripts/layers6.py'):
        os.makedirs(root, exist_ok=True)
        subprocess.run(f'git -C "{REPO}" archive {IJ_COMMIT} docs/pc/art_help/ironjaw_walk | tar -x -C "{root}"', shell=True, check=True)
    if not os.path.exists(f'{root}/docs/pc/art_help/ironjaw_walk/claude/scripts/match_metric.py'):
        subprocess.run(f'git -C "{REPO}" archive {REPLY_COMMIT} docs/pc/art_help/ironjaw_walk/claude/scripts | tar -x -C "{root}"', shell=True, check=True)
    return f'{root}/docs/pc/art_help/ironjaw_walk/'

R = src_root()
sys.path.insert(0, R + 'claude/scripts'); sys.path.insert(0, R + 'v7/scripts')
sys.modules.setdefault('claude_proto', types.ModuleType('claude_proto'))
import layers6 as LC
from cut import cut_target
CFG6 = json.load(open(R + 'v7/scripts/cfg6.json'))
TGT = {'S': R + 'v7/targets/rp_S_turn_t1.jpg', 'E': R + 'v7/targets/rp_E_stride_t2.jpg'}
TAJ = json.load(open(R + 'ta_joints/joints_512.json'))['facings']

def poly(pts, sh=SH):
    im = Image.new('L', (sh[1], sh[0]), 0); ImageDraw.Draw(im).polygon([tuple(map(float, p)) for p in pts], fill=1); return np.asarray(im) > 0

def biggest(m):
    l, n = ndi.label(m, np.ones((3, 3)))
    if n == 0: return m
    s = np.bincount(l.ravel()); s[0] = 0; return l == s.argmax()

def clean(m, k=40):
    l, n = ndi.label(m, np.ones((3, 3))); s = np.bincount(l.ravel()); s[0] = 0; return np.isin(l, np.nonzero(s >= k)[0])

def patch_fill(rgb, hole, src_ok, B=14, ov=5, search=140, ncand=260, feather=1.2, seed=11, dy_max=None, tone=None):
    """fill `hole` with real painted texture: block quilting. The hole is covered by B x B blocks (overlap ov), taken from
    the nearest block outward; each block is copied from a fully valid source block of the same painting (inside
    `src_ok`, outside the hole, within `search` px) chosen to match the pixels already known around it (least SSD on the
    overlap), so the fill keeps the cloth / plate texture and continues its folds instead of smearing (no Telea)."""
    hole = hole & ~(src_ok & ~hole) if False else hole.copy()
    H, W = hole.shape; out = rgb.astype(np.float32).copy(); rng = np.random.default_rng(seed)
    valid = src_ok & ~hole
    if not hole.any() or valid.sum() < B * B: return rgb.copy()
    ii = np.pad(np.cumsum(np.cumsum((~valid).astype(np.int32), 0), 1), ((1, 0), (1, 0)))
    def block_ok(y, x):
        y = np.asarray(y); x = np.asarray(x)
        return (ii[y + B, x + B] - ii[y, x + B] - ii[y + B, x] + ii[y, x]) == 0
    known = ~hole; todo = hole.copy(); step = B - ov
    d = ndi.distance_transform_edt(hole)
    ys, xs = np.nonzero(hole); y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    cells = [(y, x) for y in range(max(0, y0 - ov), min(H - B, y1) + 1, step) for x in range(max(0, x0 - ov), min(W - B, x1) + 1, step)]
    cells = [(y, x) for y, x in cells if hole[y:y + B, x:x + B].any()]
    cells.sort(key=lambda p: d[p[0]:p[0] + B, p[1]:p[1] + B][hole[p[0]:p[0] + B, p[1]:p[1] + B]].min())
    vy, vx = np.nonzero(valid[:H - B, :W - B])
    for y, x in cells:
        need = todo[y:y + B, x:x + B]
        if not need.any(): continue
        cy = cx = np.zeros(0, int)
        for lim in ([dy_max, dy_max * 2, dy_max * 4] if dy_max else []) + [None]:
            near = (np.abs(vx - x) <= search) & ((np.abs(vy - y) <= lim) if lim else True)
            if near.sum() < 1: continue
            py_, px_ = vy[near], vx[near]
            k = rng.choice(len(py_), size=min(ncand * 4, len(py_)), replace=False); py_, px_ = py_[k], px_[k]
            ok = block_ok(py_, px_); cy, cx = py_[ok][:ncand], px_[ok][:ncand]
            if len(cy) >= 8: break
        if len(cy) == 0: continue
        kn = known[y:y + B, x:x + B]; tgt = out[y:y + B, x:x + B]
        if kn.any():
            idx = np.nonzero(kn)
            cost = np.array([((out[sy:sy + B, sx:sx + B][idx] - tgt[idx]) ** 2).sum() for sy, sx in zip(cy, cx)])
            j = int(np.argmin(cost + rng.random(len(cost)) * 1e-3))
        else:
            j = 0
        sy, sx = cy[j], cx[j]
        blk = out[y:y + B, x:x + B]; src = out[sy:sy + B, sx:sx + B]
        blk[need] = src[need]
        # blend the overlap with the block's own copy so block seams do not show
        ovl = kn & hole[y:y + B, x:x + B]
        blk[ovl] = 0.5 * blk[ovl] + 0.5 * src[ovl]
        todo[y:y + B, x:x + B] &= ~need; known[y:y + B, x:x + B] |= need
    if todo.any():
        _, (iy, ix) = ndi.distance_transform_edt(~known, return_indices=True); out[todo] = out[iy[todo], ix[todo]]
    if tone:
        # keep the copied texture (high-pass) but give the fill the local shading of the paint around it: the low-pass of
        # the known neighbourhood (normalised convolution), so a patch from a lit fold does not land in a shadow
        kn0 = (~hole & src_ok).astype(np.float32)
        lp_known = cv2.GaussianBlur(out * kn0[..., None], (0, 0), tone) / np.maximum(cv2.GaussianBlur(kn0, (0, 0), tone), 1e-4)[..., None]
        hp = out - cv2.GaussianBlur(out, (0, 0), tone * 0.5)
        lp_fill = cv2.GaussianBlur(out, (0, 0), tone * 0.5)
        wk = np.clip(cv2.GaussianBlur(kn0, (0, 0), tone) * 6, 0, 1)[..., None]
        out[hole] = (hp + lp_fill * (1 - wk) + lp_known * wk)[hole]
    if feather:
        bl = cv2.GaussianBlur(out, (0, 0), feather); dd = ndi.distance_transform_edt(hole)
        edge = hole & (dd <= 2.0); out[edge] = 0.5 * out[edge] + 0.5 * bl[edge]
    return np.clip(out, 0, 255).astype(np.uint8)

def shift_fill(rgb, hole, src_ok, offsets, tone=None):
    """fill a hole with whole shifted copies of the painting (one offset at a time, the first whose source pixel is valid),
    so long vertical cloth folds continue across the hole; the shading is then matched to the surround (tone)."""
    out = rgb.astype(np.float32).copy(); rem = hole.copy(); H, W = hole.shape; yy, xx = np.indices(hole.shape)
    for dx, dy in offsets:
        sy, sx = yy - dy, xx - dx
        ok = rem & (sy >= 0) & (sy < H) & (sx >= 0) & (sx < W)
        ok[ok] = src_ok[sy[ok], sx[ok]] & ~hole[sy[ok], sx[ok]]
        out[ok] = rgb[sy[ok], sx[ok]]; rem &= ~ok
    if rem.any():
        _, (iy, ix) = ndi.distance_transform_edt(~(src_ok & ~hole), return_indices=True); out[rem] = rgb[iy[rem], ix[rem]]
    if tone:
        kn0 = (~hole & src_ok).astype(np.float32)
        lp_known = cv2.GaussianBlur(out * kn0[..., None], (0, 0), tone) / np.maximum(cv2.GaussianBlur(kn0, (0, 0), tone), 1e-4)[..., None]
        lp = cv2.GaussianBlur(out, (0, 0), tone * 0.5); hp = out - lp
        wk = np.clip(cv2.GaussianBlur(kn0, (0, 0), tone) * 6, 0, 1)[..., None]
        out[hole] = (hp + lp * (1 - wk) + lp_known * wk)[hole]
    bl = cv2.GaussianBlur(out, (0, 0), 1.0); dd = ndi.distance_transform_edt(hole); e = hole & (dd <= 2)
    out[e] = 0.5 * out[e] + 0.5 * bl[e]
    return np.clip(out, 0, 255).astype(np.uint8)

def mirror_fill(rgb, hole, src_ok, tone=None):
    """fill a hole that a limb cut out of a cloth panel with the cloth just beside it, mirrored about the hole's edge row by
    row (the edge smoothed over 21 rows): vertical folds run on unbroken; pixels whose mirror is not cloth fall back to
    shift_fill."""
    H, W = hole.shape; out = rgb.copy(); left = np.full(H, np.nan)
    for y in np.nonzero(hole.any(1))[0]: left[y] = np.nonzero(hole[y])[0].min()
    g = ~np.isnan(left)
    if not g.any(): return rgb
    left = np.interp(np.arange(H), np.nonzero(g)[0], left[g]); left = ndi.median_filter(left, 21)
    yy, xx = np.indices(hole.shape); sx = np.round(2 * left[:, None] - xx - 1).astype(int)
    ok = hole & (sx >= 0) & (sx < W); ok[ok] = src_ok[yy[ok], sx[ok]] & ~hole[yy[ok], sx[ok]]
    out[ok] = rgb[yy[ok], sx[ok]]
    rest = hole & ~ok
    if rest.any():
        offs = [(dx, dy) for dy in (0, -30, 30, -60, 60) for dx in (95, 120, 75, 145, 55, 170, 200)]
        out = shift_fill(out, rest, src_ok | ok, offs)
    if tone:
        f = out.astype(np.float32); kn0 = (~hole & src_ok).astype(np.float32)
        lp_known = cv2.GaussianBlur(f * kn0[..., None], (0, 0), tone) / np.maximum(cv2.GaussianBlur(kn0, (0, 0), tone), 1e-4)[..., None]
        lp = cv2.GaussianBlur(f, (0, 0), tone * 0.5); wk = np.clip(cv2.GaussianBlur(kn0, (0, 0), tone) * 6, 0, 1)[..., None]
        f[hole] = (f - lp + lp * (1 - wk) + lp_known * wk)[hole]; out = np.clip(f, 0, 255).astype(np.uint8)
    return out

CLOTH_SRC = dict(path='E', rect=(550, 125, 650, 400))     # the E target's cape: a plain run of the same crimson cloth
def cloth_fill(rgb, hole, ref_ok, tone=16):
    """fill the cape hidden behind the S near arm with real cloth of the same cape: the plain vertical-fold run of his
    cape in the E target (rect CLOTH_SRC), mirror-tiled across the hole and stretched down it (folds stay vertical and
    unbroken), colour-matched (Lab mean / std) to the S cape around the hole and given its local shading (tone)."""
    src = np.asarray(Image.open(TGT[CLOTH_SRC['path']]).convert('RGB'))
    x0, y0, x1, y1 = CLOTH_SRC['rect']; T = src[y0:y1, x0:x1]
    ys, xs = np.nonzero(hole); hy0, hy1, hx0, hx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    th = hy1 - hy0; T = cv2.resize(T, (T.shape[1], th), interpolation=cv2.INTER_CUBIC)
    reps = int(np.ceil((hx1 - hx0) / T.shape[1])) + 1
    tile = np.concatenate([T if k % 2 == 0 else T[:, ::-1] for k in range(reps)], 1)[:, :hx1 - hx0]
    lt = rgb2lab(tile); lr = rgb2lab(rgb)[ref_ok & ~hole]
    lt = (lt - lt.reshape(-1, 3).mean(0)) / (lt.reshape(-1, 3).std(0) + 1e-3) * lr.std(0) + lr.mean(0)
    tile = (np.clip(lab2rgb(lt), 0, 1) * 255).astype(np.float32)
    f = rgb.astype(np.float32); big = f.copy(); big[hy0:hy1, hx0:hx1] = tile
    f[hole] = big[hole]
    kn0 = (~hole & ref_ok).astype(np.float32)
    lp_known = cv2.GaussianBlur(f * kn0[..., None], (0, 0), tone) / np.maximum(cv2.GaussianBlur(kn0, (0, 0), tone), 1e-4)[..., None]
    lp = cv2.GaussianBlur(f, (0, 0), tone * 0.5); wk = np.clip(cv2.GaussianBlur(kn0, (0, 0), tone) * 4, 0, 1)[..., None] * 0.7
    f[hole] = (f - lp + lp * (1 - wk) + lp_known * wk)[hole]
    bl = cv2.GaussianBlur(f, (0, 0), 1.0); dd = ndi.distance_transform_edt(hole); e = hole & (dd <= 2); f[e] = 0.5 * f[e] + 0.5 * bl[e]
    return np.clip(f, 0, 255).astype(np.uint8)

def patch_inpaint(rgb, have, want, r=6, scale=0.5):
    """drop-in for layers6.inpaint_fill: real cloth texture copied from shifted patches instead of Telea + noise."""
    return patch_fill(rgb, want & ~have, have)
LC.inpaint_fill = patch_inpaint

def grow(rgb, m, region):
    _, (iy, ix) = ndi.distance_transform_edt(~m, return_indices=True); out = rgb.copy(); g = region & ~m
    out[g] = rgb[iy[g], ix[g]]; return out, m | region

def save(name, rgb, m):
    out = np.zeros(m.shape + (4,), np.uint8); out[..., :3] = np.where(m[..., None], rgb, 0); out[..., 3] = m * 255
    Image.fromarray(out).save(f'{OUT}/{name}.png')

def sleeve(rgb, vis, a, b, r, t_ref):
    """the upper arm as one sleeve a (shoulder) -> b (elbow): its painted visible part, continued under the pauldron by
    copies of the painted cross-section at t_ref (tiled along the bone), so the grown part keeps the plate texture."""
    a = np.asarray(a, float); b = np.asarray(b, float); u = (b - a) / np.linalg.norm(b - a); n = np.array([-u[1], u[0]])
    yy, xx = np.indices(SH); t = (xx - a[0]) * u[0] + (yy - a[1]) * u[1]; o = (xx - a[0]) * n[0] + (yy - a[1]) * n[1]
    reg = (t >= -r * 0.6) & (t < t_ref[0]) & (np.abs(o) <= r) & ~vis
    ref_t = t_ref[0] + np.mod(t[reg] - t_ref[0], t_ref[1] - t_ref[0])
    sx = (a[0] + ref_t * u[0] + o[reg] * n[0]).astype(np.float32).reshape(-1, 1); sy = (a[1] + ref_t * u[1] + o[reg] * n[1]).astype(np.float32).reshape(-1, 1)
    src = cv2.remap(rgb.astype(np.float32), sx, sy, cv2.INTER_LINEAR)[:, 0]
    sm = cv2.remap(vis.astype(np.float32), sx, sy, cv2.INTER_LINEAR)[:, 0] > 0.5
    out = rgb.copy(); m = vis.copy(); ys, xs = np.nonzero(reg)
    out[ys[sm], xs[sm]] = np.clip(src[sm], 0, 255).astype(np.uint8); m[ys[sm], xs[sm]] = True
    return out, m

# ------------------------------------------------------------------ facing configs (target px)
CFG = {
 'S': dict(
   arms={'R': 'near', 'L': 'far'},
   J={'R': dict(shoulder=(500, 190), elbow=(440, 318), grip=(462, 425)),
      'L': dict(shoulder=(748, 200), elbow=(768, 312), grip=(783, 418))},
   pauld={'R': [(375, 30), (612, 25), (612, 150), (575, 212), (520, 232), (470, 236), (420, 232), (385, 205)],
          'L': [(712, 80), (850, 80), (856, 245), (810, 246), (760, 240), (728, 222), (718, 180)]},
   sleeve_r={'R': 34, 'L': 28}, sleeve_ref={'R': (60, 92), 'L': (52, 82)},
   helm=[(552, 0), (775, 0), (775, 120), (742, 150), (712, 178), (668, 182), (622, 168), (590, 140), (560, 110)],
   neck=(660, 185), pelvis=(640, 360),
   hips={'R': (585, 400), 'L': (690, 392)},
   cape_hinge=dict(upper=(560, 160), lower_y=(330, 470)),
   chest_x=592,
   cape_poly=[(392, 150), (560, 150), (585, 330), (585, 470), (560, 600), (470, 640), (300, 640), (290, 560), (330, 380)],
 ),
 'E': dict(
   arms={'L': 'left', 'R': 'right'},
   J={'L': dict(shoulder=(482, 170), elbow=(445, 278), grip=(432, 385)),
      'R': dict(shoulder=(742, 170), elbow=(800, 278), grip=(822, 385))},
   pauld={'L': [(395, 40), (565, 35), (570, 175), (545, 212), (480, 222), (420, 214), (392, 180)],
          'R': [(668, 35), (860, 40), (868, 178), (842, 214), (782, 222), (705, 214), (672, 180)]},
   sleeve_r={'L': 34, 'R': 34}, sleeve_ref={'L': (58, 90), 'R': (58, 90)},
   helm=[(570, 8), (690, 8), (692, 70), (680, 108), (650, 120), (608, 120), (580, 106), (568, 70)],
   neck=(630, 118), pelvis=(610, 415),
   hips={'L': (560, 440), 'R': (668, 440)},
   cape_hinge=dict(upper=(615, 110), lower_y=(320, 470)),
 )}

def cape_weights(F, c, capem):
    """cloth weights: 0 at the collar (rides the torso), the upper panel through the back, the lower panel below the hips;
    full on the cloth and out past its ragged edge, so the hem tatters move as one with their panel (no shear)."""
    grown = ndi.binary_dilation(capem, iterations=30)
    wc = cv2.GaussianBlur(grown.astype(np.float32), (0, 0), 8)
    y0, y1 = c['cape_hinge']['lower_y']; yy = np.indices(SH)[0].astype(np.float32)
    t = np.clip((yy - y0) / (y1 - y0), 0, 1); t = t * t * (3 - 2 * t)
    wl = wc * t; wu = wc * (1 - t) * np.clip((yy - c['cape_hinge']['upper'][1]) / 80, 0, 1)
    Image.fromarray(np.dstack([(wu * 255).astype(np.uint8), (wl * 255).astype(np.uint8), np.zeros(SH, np.uint8)])).save(f'{OUT}/wcape_{F}.png')

# ------------------------------------------------------------------ legs
def leg_pieces(F, walk_leg_lab, s_cell):
    """walk legs_v6 pieces, graded to the walk's own leg colours, resampled into target px (piece_scale / s)."""
    C6 = CFG6[F]; info = {}
    raw = {}; pix = []
    for sd in 'RL':
        for seg in ('thigh', 'shin', 'boot'):
            im = np.asarray(Image.open(R + f'v7/legs_v6_pieces/{F}_{sd}_{seg}.png').convert('RGBA')).copy()
            if seg == 'boot' and C6.get('boot_keep'):
                a0 = im[..., 3] > 0; ys = np.nonzero(a0.any(1))[0]; cut = int(ys.max() - C6['boot_keep'] * (ys.max() - ys.min())); im[:cut] = 0
            raw[(sd, seg)] = im; pix.append(rgb2lab(im[..., :3])[im[..., 3] > 127])
    src = np.concatenate(pix); ref = walk_leg_lab
    ms, ss = src.mean(0), src.std(0) + 1e-3; mr, sr = ref.mean(0), ref.std(0)
    for (sd, seg), im in raw.items():
        a = im[..., 3] > 127; lab = rgb2lab(im[..., :3]); g = (lab - ms) / ss * sr + mr
        g[..., 1:] = lab[..., 1:] + (g[..., 1:] - lab[..., 1:]) * 0.4
        g[..., 0] = np.clip(g[..., 0], 0, 100)
        rgb = (np.clip(lab2rgb(g), 0, 1) * 255 + 0.5).astype(np.uint8)
        # into target px: piece px * (piece_scale / s_cell)
        k = C6['piece_scale'][f'{sd}_{seg}'] / s_cell
        h, w = a.shape; nw, nh = int(round(w * k)), int(round(h * k))
        pm = np.dstack([rgb.astype(np.float32) * a[..., None], a.astype(np.float32) * 255])
        big = np.stack([np.asarray(Image.fromarray(pm[..., c], 'F').resize((nw, nh), Image.LANCZOS)) for c in range(4)], -1)
        al = big[..., 3] / 255.0; m = al > 0.5
        col = np.clip(big[..., :3] / np.maximum(al[..., None], 1e-3), 0, 255).astype(np.uint8)
        ys, xs = np.nonzero(m); y0, y1 = ys.min(), ys.max(); hh = y1 - y0
        def rows_centre(y_a, y_b):
            yy_, xx_ = np.nonzero(m[y_a:y_b]); return [float(xx_.mean()), float(y_a + yy_.mean())]
        d = dict(k_to_target=k, size=[nw, nh])
        if seg in ('thigh', 'shin'):
            top = np.array(rows_centre(y0, y0 + int(0.06 * hh) + 1)); bot = np.array(rows_centre(y1 - int(0.06 * hh), y1 + 1))
            fa, fb = C6['piv'][seg]; d['P0'] = (top + fa * (bot - top)).tolist(); d['P1'] = (top + fb * (bot - top)).tolist()
        else:
            sole = rows_centre(y1 - 3, y1 + 1); sole[1] = float(y1); d['sole'] = sole; d['h'] = float(hh)
            shaft = rows_centre(y0, y0 + int(0.25 * hh)); d['J'] = [shaft[0], float(y1 - C6['junction_frac'] * hh)]
        out = np.zeros((nh, nw, 4), np.uint8); out[m, :3] = col[m]; out[m, 3] = 255
        Image.fromarray(out).save(f'{OUT}/leg_{sd}_{seg}_{F}.png'); info[f'{sd}_{seg}'] = d
    return info

def walk_leg_lab(F):
    """the walk f00's leg pixels (below the pelvis line, not crimson), Lab."""
    w = np.asarray(Image.open(R + f'v7/frames/ironjaw_walk_{F}_f00.png').convert('RGBA'))
    py = int(TAJ[f'walk_{F}']['f00']['joints']['pelvis'][1]) + 12
    m = w[..., 3] > 127; m[:py] = False; lab = rgb2lab(w[..., :3])
    red = (lab[..., 1] > 10) & (lab[..., 1] > lab[..., 2] * 1.2)
    return lab[m & ~ndi.binary_dilation(red, iterations=2)]

# ------------------------------------------------------------------ cut
def cut(F, dbg):
    c = CFG[F]; C6 = dict(CFG6[F]); C6['target'] = TGT[F]
    C6['fill_cape'] = False; C6['fill_body_behind_cape'] = False      # own fills below (real texture, block quilting)
    L = LC.layers(F, C6); M = L['_masks']
    rgb, al, bg = cut_target(TGT[F])
    yy, xx = np.indices(SH)
    helm = poly(c['helm']) & al
    # ---------------- arms
    pieces = {}; armall = np.zeros(SH, bool); paulds = {}
    for sd, nm in c['arms'].items():
        arm = M[nm] & ~helm
        J = c['J'][sd]; pa = poly(c['pauld'][sd]) & arm
        sh, el, gr = (np.asarray(J[k], float) for k in ('shoulder', 'elbow', 'grip'))
        uu = (el - sh) / np.linalg.norm(el - sh); uf = (gr - el) / np.linalg.norm(gr - el); ub = uu + uf; ub /= np.linalg.norm(ub)
        side_f = ((xx - el[0]) * ub[0] + (yy - el[1]) * ub[1]) > 0
        fore = biggest(ndi.binary_opening(arm & side_f & ~pa, iterations=1))
        fore = ndi.binary_fill_holes(fore) & arm | fore
        upper = arm & ~fore & ~pa
        upper = biggest(ndi.binary_opening(upper, iterations=1)) if upper.any() else upper
        urgb, um = sleeve(rgb, upper, sh, el, c['sleeve_r'][sd], c['sleeve_ref'][sd])
        # the grown sleeve stays under the pauldron (it is redrawn over it); nothing grows past the elbow cut
        um &= ~side_f
        save(f'uarm_{sd}_{F}', urgb, clean(um, 30)); save(f'fore_{sd}_{F}', rgb, fore); save(f'pauld_{sd}_{F}', rgb, clean(pa, 30))
        pieces[sd] = (um, fore, pa); armall |= arm; paulds[sd] = pa
    # ---------------- cape
    cp = L['cape']; capem = cp[..., 3] > 127; cprgb = cp[..., :3].copy()
    if F == 'S':
        # the cape hidden behind the near arm, the axe and the legs: inside the cape outline, down to the hem profile
        want = poly(c['cape_poly']) & ~capem
        cols = np.where(capem.any(0))[0]; hem = np.full(SH[1], -1.0)
        for x_ in cols: hem[x_] = np.nonzero(capem[:, x_])[0].max()
        g = hem >= 0; hem = np.interp(np.arange(SH[1]), np.nonzero(g)[0], hem[g]); hem = ndi.uniform_filter1d(ndi.maximum_filter1d(hem, 81), 41) - 25
        want &= yy <= hem[None, :]
        want &= yy >= 190
        # ... and never past the cape's own left (outer) edge: per row the painted edge, eased over +-25 rows
        rows = np.where(capem[:, :640].any(1))[0]; le = np.full(SH[0], np.nan)
        for y_ in rows: le[y_] = np.nonzero(capem[y_, :640])[0].min()
        g_ = ~np.isnan(le); le = np.interp(np.arange(SH[0]), np.nonzero(g_)[0], le[g_]); le = ndi.maximum_filter1d(ndi.minimum_filter1d(le, 51), 25) + 4
        want &= xx >= le[:, None]
        labc = rgb2lab(cp[..., :3]); crim = capem & (labc[..., 1] > 9) & (labc[..., 1] > labc[..., 2] * 1.2)
        crim = ndi.binary_closing(crim, iterations=2) & capem
        cprgb = cloth_fill(cp[..., :3], want, ndi.binary_erosion(crim, iterations=1) & (xx < 600) & (yy > 190))
        capem = capem | want
    chest = np.zeros(SH, bool)
    if F == 'S':      # the crimson tabard on his chest is cloth sewn to the armour: it stays rigid with the torso
        chest = capem & (xx >= c['chest_x']) & (yy < c['pelvis'][1] + 60)
        capem = capem & ~chest
    # ---------------- body (walk body + tassets + loincloth), holes where the arms covered it filled from the same paint
    body = M['body'].copy()
    body_chest = chest.copy()
    extra = [k for k in L if k.startswith('tas') or k == 'loin']
    rgbb = rgb.copy(); rgbb[body_chest] = cprgb[body_chest]; body |= body_chest
    for k in extra:
        m_ = L[k][..., 3] > 127; rgbb[m_] = L[k][..., :3][m_]; body |= m_
    if F == 'E':      # the back plate under the cape (the cape swings and lifts): real plate texture
        under_c = poly(CFG6[F]['torso_poly']) & ~body & ~armall & (M['cape'] | M['capef'])
        rgbb = patch_fill(rgbb, under_c, ndi.binary_erosion(body & poly(CFG6[F]['torso_poly']) & ~helm, iterations=2), B=24, ov=8, search=200, dy_max=30, tone=18)
        body |= under_c
    torso_cl = cv2.morphologyEx(body.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (61, 61))).astype(bool)
    hole = armall & torso_cl & ~body & (yy < c['pelvis'][1] + 40)
    rgbb = patch_fill(rgbb, hole, ndi.binary_erosion(body & ~helm, iterations=3))
    body |= hole
    # the helm is its own piece; under it the body keeps a filled collar (neck plate) so a turned head never shows a gap
    nk = c['neck']
    under = helm & (yy > nk[1] - 75) & torso_cl
    rgbb = patch_fill(rgbb, under, ndi.binary_erosion(body & ~helm & (yy > nk[1]) & (yy < nk[1] + 120), iterations=3))
    body = (body & ~helm) | under
    body = clean(body, 80)
    save(f'body_{F}', rgbb, body); save(f'head_{F}', rgb, clean(helm, 40))
    save(f'cape_{F}', cprgb, capem); cape_weights(F, c, capem)
    # ---------------- legs
    walk = json.load(open(os.path.join(HERE, '..', 'blockout', 'walk_fit.json')))[F] if os.path.exists(os.path.join(HERE, '..', 'blockout', 'walk_fit.json')) else None
    s_cell = walk['s'] if walk else CFG6[F]['scale']
    legs = leg_pieces(F, walk_leg_lab(F), s_cell)
    # ---------------- joints
    J = dict(arms={sd: {k: list(map(float, v)) for k, v in c['J'][sd].items()} for sd in 'RL'},
             neck=list(c['neck']), pelvis=list(c['pelvis']), hips={k: list(v) for k, v in c['hips'].items()},
             cape_upper=list(c['cape_hinge']['upper']), cape_lower_y=list(c['cape_hinge']['lower_y']), legs=legs,
             near=('R' if F == 'S' else None))
    json.dump(J, open(f'{OUT}/ijoints_{F}.json', 'w'), indent=1)
    if dbg is not None:
        o = np.full(SH + (3,), 200, np.uint8); o[body] = rgbb[body]; o[capem & ~body] = cprgb[capem & ~body]
        o2 = o.copy(); cols = [(255, 80, 80), (255, 220, 0), (0, 220, 255)]
        for sd in 'RL':
            for m_, col in zip(pieces[sd], cols): o2[m_] = (rgb[m_] * 0.4 + np.array(col) * 0.6).astype(np.uint8)
        hm = helm; o2[hm] = (rgb[hm] * 0.4 + np.array([0, 255, 0]) * 0.6).astype(np.uint8)
        for sd in 'RL':
            for k in ('shoulder', 'elbow', 'grip'):
                p = tuple(int(v) for v in c['J'][sd][k]); cv2.circle(o2, p, 6, (255, 0, 255), -1)
        dbg[F] = np.hstack([o[:, 250:1030], o2[:, 250:1030]])

def walk_fit():
    """the walk f00 placement of the target (cell = s * target + t), fitted on the upper body as the walk metric does."""
    import match_metric as MM
    out = {}
    for F in 'SE':
        rgb, ta, _ = cut_target(TGT[F]); cr, cm = MM.load(R + 'v7/frames', F, 0)
        py = int(round(TAJ[f'walk_{F}']['f00']['joints']['pelvis'][1]))
        iou, s, tx, ty = MM.fit(rgb, ta, cm, py)
        out[F] = dict(s=float(s), t=[float(tx), float(ty)], iou_upper=float(iou), walk_f00_pelvis=TAJ[f'walk_{F}']['f00']['joints']['pelvis'])
    return out

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True); dbg = {} if len(sys.argv) > 1 else None
    wf = os.path.join(HERE, '..', 'blockout', 'walk_fit.json')
    if not os.path.exists(wf):
        os.makedirs(os.path.dirname(wf), exist_ok=True); json.dump(walk_fit(), open(wf, 'w'), indent=1)
    json.dump({F: TAJ[f'idle_{F}']['joints'] for F in 'SE'}, open(os.path.join(HERE, '..', 'blockout', 'ta_idle_joints.json'), 'w'), indent=1)
    for F in 'SE': cut(F, dbg)
    if dbg is not None: Image.fromarray(np.vstack([dbg['S'], dbg['E']])).save(sys.argv[1])
    print('ok')
