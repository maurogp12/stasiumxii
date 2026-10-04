"""Ironjaw walk v4 (Claude-reviewed plan).
Upper: HD repaint cut into layers (cape / far arm / body / near arm, claude_proto.layers) at the idle-fitted scale,
anchored repaint-pelvis -> TA pelvis (minus the S leg raise), helm-top bob locked to v2 frame-for-frame.
Arms: rig_fx.lbs_swing (S in-plane, capped; E foreshortening). Cape: rig_fx.cape_sway.
Legs: NEW painted v4 sheets (thigh / knee-guard greave / boot) on v2's TA joints; boots ride v2's boot matrices
(skate 0, soles on v2's rows), hips raised by CFG raise (S +13 = TA's planned longer leg bones), knees by 2-bone IK."""
import sys, os, json, math, pickle
import numpy as np, cv2
sys.path.insert(0, '/workspace/scratch/ij_walk/v3'); sys.path.insert(0, '/workspace/scratch/ij_walk/rig'); sys.path.insert(0, '/workspace/scratch/ij_walk/rig/lib')
import build3 as B3
from build3 import *
sys.path.insert(0, '/workspace/handoff/ironjaw_walk_claude/claude_reply/scripts')
import rig_fx as fx
sys.path.insert(0, '/workspace/scratch/ij_walk/v4c')
sys.path.insert(0, '/workspace/scratch/ij_walk/v7')
import claude_proto as CP
import match_metric as MM
import layers6 as LC
from PIL import Image
from scipy import ndimage as ndi
import process_sheet as ps
import lab34 as LB

HERE = '/workspace/scratch/ij_walk/v7/'
LEGDIR = '/workspace/scratch/ij_walk/v4/legs_v4/'
ROOT = os.environ.get('V4ROOT', '/workspace/art/ironjaw_full/v4_hd/_v7')
OUTD = {'rim': f'{ROOT}/walk', 'norim': f'{ROOT}/_norim/walk'}
CFG = json.load(open(os.environ.get('CFG4C', HERE + 'cfg6.json')))
FIT = CP.FIT
V2D = pickle.load(open('/workspace/scratch/ij_walk/rig/walk_data.pkl', 'rb'))['DATA']
TAJ = CP.J
LEGL = {}
def ANNF(fac):
    a = CFG[fac].get('ann'); return a if a else CP.ANN[fac]
def H3(M): return np.vstack([M, [0, 0, 1]])
def apply(M, p): return M[:, :2] @ np.asarray(p, float) + M[:, 2]
def rows_centre(a, y0, y1):
    ys, xs = np.nonzero(a[y0:y1]); return np.array([xs.mean(), y0 + ys.mean()])
def width_at(a, y):
    xs = np.nonzero(a[int(y)])[0]; return float(xs.max() - xs.min() + 1)

# ------------------------------------------------------------------ painted leg pieces
PIECE = {}
def side_of(nm): return nm.split('_')[0]

def load_pieces(fac):
    C = CFG[fac]
    jobs = [(f'{side}_{seg}', seg, C['src'][f'{side}_{seg}']) for side in 'RL' for seg in ('thigh', 'shin', 'boot')]
    jobs += [(f'{side}_boot_alt', 'boot', src) for side, src in C.get('boot_alt_src', {}).items()]
    for nm, seg, src in jobs:
        if True:
            im = np.asarray(Image.open(f"{src[2] if len(src) > 2 else C.get('legdir', LEGDIR)}{fac}_{src[0]}.png").convert('RGBA')).copy()
            if src[1]: im = im[:, ::-1].copy()
            if seg == 'boot' and C.get('boot_keep'):      # tall boot: keep only the lower part (the shaft top hides under the greave)
                a0_ = im[..., 3] > 0; ys_ = np.nonzero(a0_.any(1))[0]; cut_ = int(ys_.max() - C['boot_keep'] * (ys_.max() - ys_.min()))
                im[:cut_] = 0
            a = im[..., 3] > 0; ys, xs = np.nonzero(a); y0, y1 = ys.min(), ys.max(); h = y1 - y0
            d = dict(img=im)
            if seg in ('thigh', 'shin'):
                top = rows_centre(a, y0, y0 + int(0.06 * h) + 1); bot = rows_centre(a, y1 - int(0.06 * h), y1 + 1)
                fa, fb = C['piv'][seg]
                d['P0'] = top + fa * (bot - top); d['P1'] = top + fb * (bot - top)
                d['w'] = width_at(a, y0 + 0.5 * h); d['s'] = C['piece_scale'].get(nm, C['width'][seg] / d['w']) if 'piece_scale' in C else C['width'][seg] / d['w']
                KC = C.get('knee')
                if seg == 'thigh' and KC:
                    xs_a = np.nonzero(a.any(0))[0]; xa, xb = xs_a.min(), xs_a.max(); xx_ = np.arange(im.shape[1]); xn = np.clip((xx_ - xa) / max(1, xb - xa), 0, 1)
                    l_, m_, r_ = KC['rim']; rim = (l_ * (1 - xn) * (1 - 2 * xn) + 4 * m_ * xn * (1 - xn) + r_ * xn * (2 * xn - 1))   # quadratic through 3 pts
                    rim_y = y0 + rim * h; yy_ = np.arange(im.shape[0])[:, None]
                    kim = im.copy(); kim[yy_ < rim_y[None, :] - 0.01 * h] = 0; kim[..., 3] = np.where(kim[..., 3] > 0, kim[..., 3], 0)
                    timg = im.copy(); timg[yy_ > rim_y[None, :] + KC.get('overlap', 0.08) * h] = 0
                    im = timg; d['img'] = im
                    kd = dict(img=kim, P0=d['P0'], P1=d['P1'], s=d['s'] * KC.get('scale', 1.0))
                    kd['pm'], kd['pre'] = premul_resize(kim, kd['s']); PIECE[(fac, f'{side_of(nm)}_knee')] = kd
            else:
                sole = rows_centre(a, y1 - 3, y1 + 1); sole[1] = y1
                d['sole'] = sole; d['h'] = h
                shaft = rows_centre(a, y0, y0 + int(0.25 * h))
                d['J'] = np.array([shaft[0], y1 - C['junction_frac'] * h])
                d['len'] = float(xs.max() - xs.min() + 1); d['s'] = C['piece_scale'].get(nm, C['width']['boot'] / d['len']) if 'piece_scale' in C else C['width']['boot'] / d['len']
            d['pm'], d['pre'] = premul_resize(im, d['s'])
            PIECE[(fac, nm)] = d

def v2_idle_sole(fac, side):
    idle = J['idle_' + fac]; Ms, _ = pose_matrices(fac, idle, idle, 0.0); nm = f'{side}_boot'
    _, l = to_layer(warp(TEX[(fac, nm)], Ms[nm], PRE[(fac, nm)]))
    ys, xs = np.nonzero(l); y1 = ys.max(); sel = ys >= y1 - 2
    return Ms[nm], np.array([xs[sel].mean(), float(y1)])

def boot_T(fac, side, key=None):
    d = PIECE[(fac, key or f'{side}_boot')]; Mv2, sole_v2 = v2_idle_sole(fac, side)
    R = rot(CFG[fac]['boot_rest_deg'][side]) @ np.diag([d['s'], d['s'] * CFG[fac].get('boot_vscale', 1.0)])
    t = sole_v2 + np.array(CFG[fac]['boot_sole_off'][side], float) - R @ d['sole']
    return np.linalg.inv(H3(Mv2)) @ H3(np.hstack([R, t[:, None]]))

def ik_knee(Hp, Ap, Lt, Ls, bend_sign):
    v = Ap - Hp; d = float(np.hypot(*v)); u = v / max(d, 1e-6); n = np.array([-u[1], u[0]])
    if d >= Lt + Ls - 1e-6: return Hp + u * d * Lt / (Lt + Ls), True
    d = max(d, abs(Lt - Ls) + 1e-3)
    a = (Lt * Lt - Ls * Ls + d * d) / (2 * d); h = math.sqrt(max(Lt * Lt - a * a, 0))
    return Hp + u * a + n * h * bend_sign, False

def hip_point(C, jf, s):
    P = np.array(jf['pelvis'], float); H = np.array(jf[f'{s}_hip'], float)
    return P + C['hip_w'] * (H - P) + np.array([C['hip_dx'], -C['raise']])

def leg_geometry(fac):
    C = CFG[fac]; Wf = frames(fac); idle = J['idle_' + fac]; ov, planted = boot_overrides(fac)
    Ts = {s: boot_T(fac, s) for s in 'RL'}
    ALT = {s: {int(f) for f in C.get('boot_alt_frames', {}).get(s, [])} for s in 'RL'}
    TA_ = {s: boot_T(fac, s, f'{s}_boot_alt') for s in 'RL' if (fac, f'{s}_boot_alt') in PIECE}
    bk = lambda s_, i_: f'{s_}_boot_alt' if i_ in ALT[s_] else f'{s_}_boot'
    Mi, _ = pose_matrices(fac, idle, idle, 0.0); ji = idle['joints']; ref = {}
    for s in 'RL':
        Mb = (H3(Mi[f'{s}_boot']) @ Ts[s])[:2]; Ai = apply(Mb, PIECE[(fac, f'{s}_boot')]['J'])
        tot = float(np.hypot(*(Ai - hip_point(C, ji, s)))) / C['straight']
        ref[s] = dict(Lt=C['thigh_share'] * tot, Ls=(1 - C['thigh_share']) * tot,
                      ht=float(np.hypot(*np.subtract(ji[f'{s}_knee'], ji[f'{s}_hip']))), hs=float(np.hypot(*np.subtract(ji[f'{s}_ankle'], ji[f'{s}_knee']))))
    print('  ref', {s_: {k_: round(v_, 1) for k_, v_ in r_.items()} for s_, r_ in ref.items()}, {nm_: dict(s=round(PIECE[(fac, nm_)]['s'], 3), la=round(float(np.hypot(*(PIECE[(fac, nm_)]['P0'] - PIECE[(fac, nm_)]['P1']))), 1)) for nm_ in ('R_thigh', 'R_shin', 'L_thigh', 'L_shin')})
    G = []
    for i in range(12):
        fr = Wf[i]; Ms, _ = pose_matrices(fac, fr, idle, 0.0); Ms.update(ov[i]); jf = fr['joints']; g = {}
        Mb0 = {s_: (H3(Ms[f'{s_}_boot']) @ (TA_[s_] if i in ALT[s_] else Ts[s_]))[:2] for s_ in 'RL'}
        for s in 'RL':
            Mb = Mb0[s]
            corr = np.zeros(2)
            if C.get('match_swing_soles', True) and s not in planted[i]:
                d_ = PIECE[(fac, bk(s, i))]; _, lb = to_layer(warp(d_['pm'], Mb, d_['pre']))
                v2l = V2D[fac][i]['boot_layer'][s]
                def sp(m):
                    ys_, xs_ = np.nonzero(m); y1_ = ys_.max(); return np.array([xs_[ys_ >= y1_ - 2].mean(), float(y1_)])
                corr = sp(v2l) - sp(lb)
                if C.get('match_metric_window', True) and s == ('R' if jf['R_ankle'][1] >= jf['L_ankle'][1] else 'L'):
                    # this swing boot is the metric's support foot: match v2's composite sole point in the metric window
                    xs_w = [jf[f'{s}_toe'][0], jf[f'{s}_heel'][0], jf[f'{s}_ankle'][0]]; x0w, x1w = min(xs_w) - 12, max(xs_w) + 12; y0w = jf[f'{s}_ankle'][1] - 4
                    rv, mv = MM.load('/workspace/art/ironjaw_full/v4_hd/walk', fac, i); pv = MM.sole(mv & ~MM.cloth(rv), x0w, x1w, y0w)
                    for _ in range(3):
                        Mb2 = Mb.copy(); Mb2[:, 2] += corr; _, lbc = to_layer(warp(d_['pm'], Mb2, d_['pre']))
                        o_ = 'L' if s == 'R' else 'R'; do_ = PIECE[(fac, bk(o_, i))]
                        _, lbo = to_layer(warp(do_['pm'], Mb0[o_], do_['pre']))        # the other boot can sit in the window too
                        pc = MM.sole(lbc | lbo, x0w, x1w, y0w)
                        if pv is None or pc is None: break
                        corr = corr + (np.array(pv) - np.array(pc))
                Mb = Mb.copy(); Mb[:, 2] += corr
            Ap = apply(Mb, PIECE[(fac, bk(s, i))]['J'])
            H, K, A = (np.array(jf[f'{s}_{k}'], float) for k in ('hip', 'knee', 'ankle'))
            Hp = hip_point(C, jf, s); r = ref[s]
            Lt = r['Lt'] * float(np.clip(np.hypot(*(K - H)) / r['ht'], 0.3, 1.15))
            Ls = r['Ls'] * float(np.clip(np.hypot(*(A - K)) / r['hs'], 0.3, 1.15))
            u = (A - H) / max(np.hypot(*(A - H)), 1e-6); nrm = np.array([-u[1], u[0]]); bend = 1.0 if np.dot(K - H, nrm) >= 0 else -1.0
            Kp, straight = ik_knee(Hp, Ap, Lt, Ls, bend)
            g[s] = dict(bootkey=bk(s, i), H=Hp, K=Kp, A=Ap, Mboot=Mb, straight=straight, Lt=Lt, Ls=Ls, sole_corr=corr.round(2).tolist())
        G.append(g)
    return G, ov, planted

def seg_matrix(d, top_pt, bot_pt, klim, anchor_top=False):
    L = float(np.hypot(*(top_pt - bot_pt))); la = float(np.hypot(*(d['P0'] - d['P1']))) * d['s']
    k = float(np.clip(L / max(la, 1e-6), *klim))
    if anchor_top: return similarity(d['P0'], d['P1'], top_pt, bot_pt, k, d['s']), k
    return similarity(d['P1'], d['P0'], bot_pt, top_pt, k, d['s']), k

def side_order(fac, i):
    """legs near -> far from TA draw_order (front -> back)"""
    do = TAJ[f'walk_{fac}'][f'f{i:02d}']['draw_order']
    idx = {s: min(do.index(p) for p in do if p.startswith(s + '_') and any(k in p for k in ('thigh', 'shin', 'boot'))) for s in 'RL'}
    return sorted('RL', key=lambda s: idx[s]), idx, do

# ------------------------------------------------------------------ colour (painted legs -> repaint leg palette)
def ref_leg_lab(fac):
    if CFG[fac].get('grade') == 'idle':      # v7: grade legs to the APPROVED idle's legs (Mauro)
        import legval as LV; im_, m_, lab_ = LV.idle_legs(fac); cw_ = LB.cloth_weight(lab_, m_); return lab_[m_ & (cw_ < CFG[fac].get('grade_cw', 0.3))]
    if CFG[fac].get('target'):      # leg palette from the (new) target's own legs
        rgb_, m_ = LC.target_leg_pixels(fac, CFG[fac]); return LB.rgb2lab(rgb_)[m_]
    rc, rl = B3.ref_leg_pixels(fac); lab = LB.rgb2lab(rc); cw = LB.cloth_weight(lab, rl)
    return lab[rl & (cw < 0.05)]
def build_maps(fac, samples):
    src = np.concatenate(samples); ref = ref_leg_lab(fac); q = np.linspace(0, 1, 1024)
    maps = [(np.quantile(src[:, c], q), np.quantile(ref[:, c], q)) for c in range(3)]
    if CFG[fac].get('grade') == 'idle':
        # rig_fx.lab_match (Reinhard mean/std in Lab, ref = idle legs) expressed as a per-channel curve, then the L highlights
        # are pulled down so the walk-leg L* p95 lands on the idle's p95 (+ grade_p95_off): dark matte blackened steel
        maps = []
        for c in range(3):
            ms_, ss_ = src[:, c].mean(), src[:, c].std() + 1e-3; mr_, sr_ = ref[:, c].mean(), ref[:, c].std()
            xs_ = np.linspace(src[:, c].min() - 1, src[:, c].max() + 1, 512); ys_ = (xs_ - ms_) / ss_ * sr_ + mr_
            if c > 0: ys_ = xs_ + (ys_ - xs_) * CFG[fac].get('grade_ab', 1.0)
            if c == 0:
                Lw = (src[:, 0] - ms_) / ss_ * sr_ + mr_; tgt = np.percentile(ref[:, 0], 95) + CFG[fac].get('grade_p95_off', 0.0)
                k_ = np.percentile(ref[:, 0], CFG[fac].get('grade_knee_pct', 60)); p_ = np.percentile(Lw, 95)
                if p_ > tgt and p_ > k_ + 1: ys_ = np.where(ys_ > k_, k_ + (ys_ - k_) * (tgt - k_) / (p_ - k_), ys_)
                ys_ = np.clip(ys_, 0, 100)
            maps.append((xs_, ys_))
    st = dict(src_LAB_p10_50_90=[np.percentile(src[:, c], [10, 50, 90]).round(1).tolist() for c in range(3)],
              ref_LAB_p10_50_90=[np.percentile(ref[:, c], [10, 50, 90]).round(1).tolist() for c in range(3)])
    return maps, st
def apply_maps(rgb, m, maps, mix, loff):
    lab = LB.rgb2lab(rgb.astype(np.uint8)); out = lab.copy()
    for c in range(3): out[..., c] = np.interp(lab[..., c], *maps[c])
    out = lab * (1 - mix) + out * mix; out[..., 0] += loff
    return np.where(m[..., None], LB.lab2rgb(out).astype(np.float32), 0)

# ------------------------------------------------------------------ upper layers
def straight(u8):
    """remapped premultiplied (black-under-alpha) rgba -> straight float rgba"""
    f = u8.astype(np.float32); a = f[..., 3:4]
    f[..., :3] = np.where(a > 0, f[..., :3] * 255.0 / np.maximum(a, 1e-3), 0); return f

def to_cell_pm(layer, fac, off):
    s, tx, ty = FIT[fac]; s = CFG[fac].get('scale', s)
    pm, pre = premul_resize(straight(layer), s)
    M = np.array([[s, 0, tx + off[0]], [0, s, ty + off[1]]], float)
    return warp(pm, M, pre)          # premult float, alpha 0..255

def shift_rows(a, dy):
    if dy == 0: return a
    o = np.zeros_like(a)
    if dy > 0: o[dy:] = a[:-dy]
    else: o[:dy] = a[-dy:]
    return o

def swing_angles(fac):
    """per-arm lbs angle (deg, + = clockwise) and stretch from TA's final keys, relative to f00 (the repaint IS f00).
    S: arm_swing_screen_deg (in-plane), near arm softly capped forward.  E: swing_rot x screen deg + stretch from
    reach_vs_idle.length_scale (damped by swing_stretch_k), haft shortening handled separately."""
    C = CFG[fac]; W = TAJ[f'walk_{fac}']; out, st = {}, {}
    for arm, side in zip(ANNF(fac)['arms'], 'RL'):
        scr = np.array([W[f'f{i:02d}']['arm_swing_screen_deg'][side] for i in range(12)]); a = (scr - scr[0]) * C['swing_scale']
        if fac == 'S':
            cap = C['swing_cap_near'] if arm['name'] == 'near' else C['swing_cap_far']
            if cap < 90: a = np.where(a > 0, cap * np.tanh(a / cap), a)
            out[arm['name']] = a; st[arm['name']] = np.ones(12)
        else:
            ls = np.array([W[f'f{i:02d}']['reach_vs_idle'][side]['length_scale'] for i in range(12)])
            out[arm['name']] = C['swing_rot'] * a
            st[arm['name']] = 1 + C['swing_stretch_k'] * (ls / ls[0] - 1)
    return out, st

def cape_dx(fac):
    """TA cape_points: dx_hem = hem.x - collar.x, relative to f00, scaled to cape_amp_px at the extreme."""
    W = TAJ[f'walk_{fac}']
    d = np.array([W[f'f{i:02d}']['cape_points']['hem'][0] - W[f'f{i:02d}']['cape_points']['collar'][0] for i in range(12)])
    d = d - d[0]; m = np.abs(d).max()
    return d / max(m, 1e-6) * CFG[fac]['cape_amp_px']

def upper_frame(fac, i, L, ang, stv, cdx):
    C = CFG[fac]; A = ANNF(fac); s = C.get('scale', FIT[fac][0])
    jj = TAJ[f'walk_{fac}'][f'f{i:02d}']['joints']
    pel = np.array(jj['pelvis'], float) - (0, C['raise'])
    off = pel - (np.array(A['pelvis']) * s + np.array(FIT[fac][1:]))
    ph = 2 * np.pi * i / 12
    sway = float(cdx[i])
    c = A['cape']
    cape = cape_sway2(L['cape'], c['top'], c['hem'], sway / s,
                      lift=C['cape_lift'] - C.get('cape_lift_osc', 4) * np.cos(2 * ph - 1.0), lift_pow=C.get('cape_lift_pow', 2.0), ripple=C['cape_ripple'], phase=ph * 2, lift_x=C.get('cape_lift_x'))
    out = {'cape': to_cell_pm(cape, fac, off), 'body': to_cell_pm(L['body'], fac, off)}
    for k_ in [k for k in L if k.startswith('tas')]: out[k_] = to_cell_pm(L[k_], fac, off)
    if 'loin' in L:
        lo = L['loin']; y0 = C['loin_poly'][0][1]; h_, w_ = lo.shape[:2]; yy_, xx_ = np.mgrid[0:h_, 0:w_].astype(np.float32)
        sy = np.where(yy_ > y0, y0 + (yy_ - y0) / C['loin_len'], yy_)
        t_ = np.clip((yy_ - y0) / 120.0, 0, 1)
        lo = fx.remap(lo, xx_ - 0.5 * sway / s * t_ ** 1.6, sy)
        out['loin'] = to_cell_pm(lo, fac, off)
    for arm in A['arms']:
        a = float(ang[arm['name']][i])
        src = L[arm['name']]
        hf = C.get('haft', {}).get(arm['name'])
        if hf:      # shorten the haft below the fist (lifts the axe head clear of the shorter idle-size legs; upper body untouched)
            src = fx.lbs_swing(src, arm['pivot'], 0.0, hf[0], hf[1], stretch=hf[2], axis=arm.get('axis', (0.0, 1.0)))
        if fac == 'E':
            lay = fx.lbs_swing(src, arm['pivot'], a, arm['r0'], arm['r1'], stretch=float(stv[arm['name']][i]), axis=arm['axis'])
        else:
            lay = fx.lbs_swing(src, arm['pivot'], a, arm['r0'], arm['r1'])
        out[arm['name']] = to_cell_pm(lay, fac, off)
    return out, off, float(sway)

def cape_sway2(rgba, top, hem, dx_hem, lift=0.0, lift_pow=2.0, ripple=0.0, phase=0.0, k=0.035, lift_x=None):
    h, w = rgba.shape[:2]; yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = np.clip((yy - top) / max(1, hem - top), 0, 1)
    off = dx_hem * t ** 1.6 + ripple * t ** 2 * np.sin(phase - k * yy)
    if lift_x:      # extra lift for the strands over one foot (per-column smoothstep): trims those tips clear of the boot
        u = np.clip((xx - lift_x[0]) / max(1, lift_x[1] - lift_x[0]), 0, 1); u = u * u * (3 - 2 * u)
        lift = lift * (1 + lift_x[2] * u)
    return fx.remap(rgba, xx - off, yy + lift * t ** lift_pow)

def head_top(alpha):
    ys = np.nonzero((alpha[:, 200:312] >= 127.5).any(1))[0]; return int(ys.min())

def over_pm(dst, src):
    a = src[..., 3:4] / 255.0
    return src + dst * (1 - a)

def render(fac):
    C = CFG[fac]; load_pieces(fac)
    L = LC.layers(fac, C); ang, stv = swing_angles(fac); cdx = cape_dx(fac)
    hip_gap = C.get('hip_gap')
    if hip_gap is not None: C['raise'] = 0
    # pass 1: upper layers + natural helm tops
    UPS = [upper_frame(fac, i, L, ang, stv, cdx) for i in range(12)]
    nat = []
    for up, _, _ in UPS:
        a = np.zeros((CH, CW), np.float32)
        for v in up.values(): a = np.maximum(a, v[..., 3])
        nat.append(head_top(a))
    v2top = np.array(B3.V2TOP[fac]); c0 = int(round(np.mean(np.array(nat) - v2top)))
    if C.get('top_min') is not None: c0 = int(C['top_min'] - v2top.min())
    dys = [int(v2top[i] + c0 - nat[i]) for i in range(12)]
    if hip_gap is not None:
        C['raise'] = int(max(0, round(-np.mean(dys) - hip_gap)))      # legs lengthen when the upper gets smaller
    G, ov, planted = leg_geometry(fac)
    TASA = {}
    TL_ = C.get('tas_list') or ([dict(poly=C['tas_poly'], side=C.get('tas_side', 'R'))] if C.get('tas_poly') else [])
    for k_, t_ in enumerate(TL_):        # tasset swing: thigh angle of its side, centred over the cycle, scaled to +-tas_deg
        sd_ = t_['side']; jj_ = [TAJ[f'walk_{fac}'][f'f{i:02d}']['joints'] for i in range(12)]; th = np.array([math.degrees(math.atan2(j_[f'{sd_}_knee'][0] - j_[f'{sd_}_hip'][0], j_[f'{sd_}_knee'][1] - j_[f'{sd_}_hip'][1])) for j_ in jj_])   # TA's final joints
        if C.get('tas_ref_side') and sd_ != C['tas_ref_side']:      # back view: the far thigh's screen angle is noisy -> mirror the reference side
            rs_ = C['tas_ref_side']; th = -np.array([math.degrees(math.atan2(j_[f'{rs_}_knee'][0] - j_[f'{rs_}_hip'][0], j_[f'{rs_}_knee'][1] - j_[f'{rs_}_hip'][1])) for j_ in jj_])
        th = th - th.mean(); th = (np.roll(th, 1) + 2 * th + np.roll(th, -1)) / 4       # circular [1 2 1] smoothing
        TASA[f'tas{k_}'] = C.get('tas_deg', 3.0) * th / max(1e-6, np.abs(th).max())
        print('  tasset', k_, sd_, 'deg', np.round(TASA[f'tas{k_}'], 1).tolist())
    LDX = {int(k): v for k, v in C.get('leg_dx', {}).get('L', {}).items()}
    # pass 2: legs
    raw = []
    for i in range(12):
        cols, lays, Ms, ks = {}, {}, {}, {}
        for s in 'RL':
            g = G[i][s]; dT, dS = (PIECE[(fac, f'{s}_{p}')] for p in ('thigh', 'shin')); dB = PIECE[(fac, g['bootkey'])]
            Ms[f'{s}_thigh'], ks[f'{s}_thigh'] = seg_matrix(dT, g['H'], g['K'], C['klim_thigh'])
            Ms[f'{s}_shin'], ks[f'{s}_shin'] = seg_matrix(dS, g['K'], g['A'], C['klim_shin'], C.get('shin_anchor_top', False))
            Ms[f'{s}_boot'] = g['Mboot']
            if (fac, f'{s}_knee') in PIECE:
                dK = PIECE[(fac, f'{s}_knee')]; ut = (g['K'] - g['H']) / max(1e-6, np.hypot(*(g['K'] - g['H']))); us = (g['A'] - g['K']) / max(1e-6, np.hypot(*(g['A'] - g['K'])))
                um = ut + us; um = um / max(1e-6, np.hypot(*um)); up_ = (dK['P1'] - dK['P0']); up_ = up_ / max(1e-6, np.hypot(*up_))
                th_ = math.atan2(um[1], um[0]) - math.atan2(up_[1], up_[0]); Rk = np.array([[math.cos(th_), -math.sin(th_)], [math.sin(th_), math.cos(th_)]]) * dK['s']
                kof = np.array(C['knee'].get('offset', [0, 0]), float)
                Ms[f'{s}_knee'] = np.hstack([Rk, (g['K'] + kof - Rk @ dK['P1'])[:, None]])
            for seg, d in (('thigh', dT), ('shin', dS), ('boot', dB)) + ((('knee', PIECE[(fac, f'{s}_knee')]),) if (fac, f'{s}_knee') in PIECE else ()):
                nm = f'{s}_{seg}'; cols[nm], lays[nm] = to_layer(warp(d['pm'], Ms[nm], d['pre']))
                if seg == 'shin':
                    u_ = g['A'] - g['K']; Lk = float(np.hypot(*u_)); u_ = u_ / max(Lk, 1e-6)
                    yy_, xx_ = np.mgrid[0:CH, 0:CW]
                    keep = ((xx_ - g['K'][0]) * u_[0] + (yy_ - g['K'][1]) * u_[1]) <= Lk + C.get('shin_margin', 4)
                    lays[nm] &= keep; cols[nm][~lays[nm]] = 0
        if i in LDX:      # far-leg readability: screen-space lateral offset (swing: rigid; planted: sheared hip->ankle, boot and sole untouched)
            dx_ = float(LDX[i]); g = G[i]['L']; hy, ay = float(g['H'][1]), float(g['A'][1])
            planted_L = 'L' in planted[i]
            for p_ in [q_ for q_ in (('thigh', 'shin', 'knee') if planted_L else ('thigh', 'shin', 'boot', 'knee')) if f'L_{q_}' in lays]:
                nm = f'L_{p_}'
                if not planted_L:
                    lays[nm] = np.roll(lays[nm], int(round(dx_)), 1); cols[nm] = np.roll(cols[nm], int(round(dx_)), 1); continue
                for y in range(CH):
                    sh = int(round(dx_ * np.clip((ay - y) / max(1.0, ay - hy), 0, 1)))
                    if sh: lays[nm][y] = np.roll(lays[nm][y], sh); cols[nm][y] = np.roll(cols[nm][y], sh, 0)
        raw.append((cols, lays, Ms, ks))
    samples = []
    for cols, lays, _, _ in raw:
        for nm in lays:
            m = ndi.binary_erosion(lays[nm], iterations=1); samples.append(LB.rgb2lab(cols[nm].astype(np.uint8))[m])
    maps, mstat = build_maps(fac, samples)
    out = []
    for i in range(12):
        cols, lays, Ml, ks = raw[i]
        for nm in lays:
            cols[nm] = apply_maps(cols[nm], lays[nm], maps, C['colour_mix'], C['L_offset'])
            g_ = C.get('detail_gain', 0.0)
            if g_ > 0:
                m_ = lays[nm].astype(np.float32); w_ = cv2.GaussianBlur(m_, (0, 0), 1.0)
                bl = cv2.GaussianBlur(cols[nm] * m_[..., None], (0, 0), 1.0) / np.maximum(w_[..., None], 1e-3)
                cols[nm] = np.where(lays[nm][..., None], np.clip(cols[nm] + g_ * (cols[nm] - bl), 0, 255), 0).astype(np.float32)
        up, off, sway = UPS[i]; up = {k: shift_rows(v, dys[i]) for k, v in up.items()}
        for k_, TA_k in (TASA or {}).items():
            if k_ not in up: continue
            a_ = up[k_][..., 3] > 127.5
            if a_.any():
                ys_, xs_ = np.nonzero(a_); pv_ = (float(xs_.mean()), float(ys_.min()))
                Mr = cv2.getRotationMatrix2D(pv_, float(TA_k[i]), 1.0)
                up[k_] = cv2.warpAffine(up[k_], Mr, (CW, CH), flags=cv2.INTER_LINEAR, borderValue=0)
        near_first, idx, do = side_order(fac, i)
        fd_ = C.get('far_dark', 0.0)
        if fd_:       # far leg reads ~10-15% darker (depth), same pieces as the near leg
            for nm in lays:
                if nm.startswith(near_first[1] + '_'): cols[nm] = cols[nm] * (1 - fd_)
        within = C['within']
        legpm = {}
        for nm in lays:
            m = lays[nm].astype(np.float32)[..., None]; legpm[nm] = np.concatenate([cols[nm] * m, m * 255.0], -1)
        def leg_stack(side):        # back -> front list inside one leg
            return [f'{side}_{w}' for w in reversed(within)] + ([f'{side}_knee'] if f'{side}_knee' in lays else [])
        far_s, near_s = near_first[1], near_first[0]
        if fac == 'S':
            iL = do.index('L_axe')
            stack = ['cape']
            # far arm vs each leg from TA draw_order (front->back): far arm over a leg when L_axe is listed before it
            seq = [('leg', far_s), ('leg', near_s)]
            pos = 0
            for k_, (_, sd) in enumerate(seq):
                if iL < idx[sd]: break
                pos = k_ + 1
            seq.insert(pos, ('arm', 'far'))
            for t_, v_ in seq:
                stack += leg_stack(v_) if t_ == 'leg' else ['far']
            stack += ['body'] + sorted(k for k in up if k.startswith('tas')) + (['loin'] if 'loin' in up else []) + ['near']
        else:
            stack = leg_stack(far_s) + leg_stack(near_s) + ['body'] + sorted(k for k in up if k.startswith('tas')) + ['cape', 'left', 'right']
        layers = dict(legpm); layers.update(up)
        pm = np.zeros((CH, CW, 4), np.float32); owner = np.full((CH, CW), -1, np.int16)
        for k_, nm in enumerate(stack):
            pm = over_pm(pm, layers[nm]); owner[layers[nm][..., 3] >= 127.5] = k_
        al = pm[..., 3] >= 127.5
        if os.environ.get('DBG_OWNER'):
            pal_ = np.array([[60,60,60],[255,0,0],[0,255,0],[0,0,255],[255,255,0],[255,0,255],[0,255,255],[255,128,0],[128,0,255],[0,128,0],[128,128,255],[255,128,128],[128,255,128],[200,200,200],[90,40,0],[0,90,90],[150,0,60],[60,150,0]], np.uint8)
            o_ = pal_[np.clip(owner, 0, len(pal_) - 1)]; o_[owner < 0] = 0; os.makedirs(f'{ROOT}/_dbg', exist_ok=True)
            Image.fromarray(o_).save(f'{ROOT}/_dbg/owner_{fac}_{i:02d}.png'); json.dump(stack, open(f'{ROOT}/_dbg/stack_{fac}_{i:02d}.json', 'w'))
        rgb = np.where(al[..., None], np.clip(pm[..., :3] / np.maximum(pm[..., 3:4], 1e-3) * 255.0, 0, 255), 0)
        # contact shadow on leg px just below the body layer's lower edge
        legown = np.isin(owner, [stack.index(n) for n in legpm])
        upm = layers['body'][..., 3] >= 127.5
        if 'loin' in layers: upm |= layers['loin'][..., 3] >= 127.5
        for k_ in [k for k in layers if k.startswith('tas')]: upm |= layers[k_][..., 3] >= 127.5
        if fac == 'E': upm |= layers['cape'][..., 3] >= 127.5
        done = np.zeros((CH, CW), bool); nsh = 0
        for dy, f_ in enumerate(C['cut_shadow'], 1):
            sh = np.zeros_like(upm); sh[dy:] = upm[:-dy]; sh &= legown & ~done; rgb[sh] *= f_; done |= sh; nsh += int(sh.sum())
        cell = np.zeros((CH, CW, 4), np.uint8); cell[..., :3] = np.round(rgb).astype(np.uint8); cell[..., 3] = al * 255
        _labc = LB.rgb2lab(cell[..., :3]); LEGL.setdefault(fac, []).append(_labc[..., 0][legown & al & (LB.cloth_weight(_labc, legown & al) < 0.3)])
        cell, nsmall = ps.drop_small(cell, C.get('drop_small', 60)); cell, nfix = ps.edge_fix(cell)
        # pinholes (<= 6 px transparent holes fully inside the figure) -> filled with the local median
        a0 = cell[..., 3] > 0; holes = ndi.binary_fill_holes(a0) & ~a0; hl, hn = ndi.label(holes); npin = 0
        if hn:
            hs = np.bincount(hl.ravel()); small_h = np.isin(hl, np.nonzero(hs <= 6)[0]) & holes
            if small_h.any():
                med = cv2.medianBlur(cell[..., :3].copy(), 5); _, (iy, ix) = ndi.distance_transform_edt(~a0, return_indices=True)
                cell[..., :3][small_h] = cell[..., :3][iy[small_h], ix[small_h]]; cell[..., 3][small_h] = 255; npin = int(small_h.sum())
        # grey-halo recolour: silhouette edge px that still carry the repaint backdrop grey take the colour 2 px inside
        a_ = cell[..., 3] > 0; inner = ndi.binary_erosion(a_, np.ones((3, 3)), iterations=2)
        edge2 = a_ & ~ndi.binary_erosion(a_, np.ones((3, 3)), iterations=2)
        c3 = cell[..., :3].astype(int); neutral = (c3.max(-1) - c3.min(-1)) <= 8
        halo = edge2 & neutral & np.any([np.abs(c3.mean(-1) - g_) <= 12 for g_ in C.get('halo_greys', [126, 106])], 0)
        nhalo = int(halo.sum())
        if nhalo and inner.any():
            _, (iy, ix) = ndi.distance_transform_edt(~inner, return_indices=True)
            cell[..., :3][halo] = cell[..., :3][iy[halo], ix[halo]]
        # whatever still reads as backdrop grey on the 1 px silhouette ring (legit mid-grey steel) gets a slight dark outline
        ring = a_ & ~ndi.binary_erosion(a_, np.ones((3, 3)))
        c3 = cell[..., :3].astype(int); neutral = (c3.max(-1) - c3.min(-1)) <= 8
        h2 = ring & neutral & np.any([np.abs(c3.mean(-1) - g_) <= 12 for g_ in C.get('halo_greys', [126, 106])], 0)
        cell[..., :3][h2] = (cell[..., :3][h2] * 0.8).astype(np.uint8); nhalo += int(h2.sum())
        al2 = cell[..., 3] > 0
        vis = {nm: int(((owner == k_) & al2).sum()) for k_, nm in enumerate(stack)}
        g = ground_of([lays['R_boot'], lays['L_boot']], al2)
        rim, _ = ps.apply_rim(cell, RIM, ps.rim_eligible(cell, g))
        up_all = np.zeros((CH, CW), bool)
        for k in up: up_all |= up[k][..., 3] >= 127.5
        geo = {s: {k: (v.tolist() if hasattr(v, 'tolist') else v) for k, v in G[i][s].items() if k != 'Mboot'} for s in 'RL'}
        vis2 = dict(vis); vis2['front'] = vis.get('body', 0) + vis.get('near', 0) + vis.get('far', 0) + vis.get('left', 0) + vis.get('right', 0); vis2['back'] = vis.get('cape', 0)
        soles_ = [int(np.nonzero(lays[f'{s_}_boot'].any(1))[0].max()) for s_ in 'RL']
        clear = {}
        for k_ in up:
            if k_ in ('body', 'cape', 'loin') or k_.startswith('tas'): continue
            mm = up[k_][..., 3] >= 127.5
            if mm.any(): clear[k_] = int(max(soles_) - np.nonzero(mm.any(1))[0].max())
        mm = up['cape'][..., 3] >= 127.5; clear['cape_hem'] = int(max(soles_) - np.nonzero(mm.any(1))[0].max())
        out.append(dict(clear=clear, norim=cell, rim=rim, order=stack, vis=vis2, planted=sorted(planted[i]), theta=0.0, sway=round(sway, 3),
                        upper_top=head_top(sum(v[..., 3] for v in up.values()) * 0 + np.maximum.reduce([v[..., 3] for v in up.values()])),
                        off=list(map(float, off)), dy=dys[i], arm_deg={k: round(float(v[i]), 2) for k, v in ang.items()},
                        boot_layer={s: lays[f'{s}_boot'] for s in 'RL'}, vis_boot={s: (owner == stack.index(f'{s}_boot')) & al2 for s in 'RL'},
                        leg_layers=lays, upper_layers={k: v[..., 3] >= 127.5 for k, v in up.items()}, upper_mask=up_all, owner=owner, geo=geo, k=ks,
                        clean=dict(pinholes_filled_px=npin, grey_halo_recoloured_px=nhalo, dropped_small_px=nsmall, edge_fix_px=nfix, contact_shadow_px=nsh)))
    _L = np.concatenate(LEGL.pop(fac, [np.zeros(1)]))
    print('  walk leg L* p95', round(float(np.percentile(_L, 95)), 1), 'p50', round(float(np.median(_L)), 1))
    return out, dict(leg_L_p95=round(float(np.percentile(_L, 95)), 1), leg_L_p50=round(float(np.median(_L)), 1), raise_px=C['raise'], colour_map=mstat, c0=c0, dys=dys, nat_tops=nat, arm_deg={k: np.round(v, 2).tolist() for k, v in ang.items()}, arm_stretch={k: np.round(v, 3).tolist() for k, v in stv.items()}, cape_dx=np.round(cdx, 2).tolist())

if __name__ == '__main__':
    facs = sys.argv[1:] or ['S', 'E']
    for d in OUTD.values(): os.makedirs(d, exist_ok=True)
    os.makedirs(f'{ROOT}/_test', exist_ok=True)
    pk = os.environ.get('PK', HERE + 'walk7_data.pkl')
    D = pickle.load(open(pk, 'rb')) if os.path.exists(pk) else dict(DATA={}, INFO={})
    for fac in facs:
        D['DATA'][fac], D['INFO'][fac] = render(fac)
        for tag in ('norim', 'rim'):
            frs = [d[tag] for d in D['DATA'][fac]]
            for F, fl in ((fac, frs), (MIR[fac], [ps.mirror(c) for c in frs])):
                for i, c in enumerate(fl): Image.fromarray(c, 'RGBA').save(f'{OUTD[tag]}/ironjaw_walk_{F}_f{i:02d}.png')
                Image.fromarray(np.concatenate(fl, 1), 'RGBA').save(f'{OUTD[tag]}/ironjaw_walk_{F}_strip.png')
        print(fac, 'raise', D['INFO'][fac]['raise_px'], 'c0', D['INFO'][fac]['c0'], 'dys', D['INFO'][fac]['dys'], 'arm', D['INFO'][fac]['arm_deg'])
        print('  k', [{k: round(v, 2) for k, v in d['k'].items()} for d in D['DATA'][fac][:2]])
        print('  clear', [d['clear'] for d in D['DATA'][fac]])
        print('  straight', [[s for s in 'RL' if d['geo'][s]['straight']] for d in D['DATA'][fac]])
    D['CFG'] = CFG
    pickle.dump(D, open(pk, 'wb'))
    json.dump(dict(cfg=CFG, info=D['INFO'], per_frame={f: [dict(order=d['order'], sway=d['sway'], planted=d['planted'], vis=d['vis'], upper_top=d['upper_top'], dy=d['dy'], arm_deg=d['arm_deg'], k=d['k'], geo=d['geo'], clean=d['clean']) for d in D['DATA'][f]] for f in D['DATA']}),
              open(f'{ROOT}/_test/build6_info.json', 'w'), indent=1, default=lambda o: o.tolist() if hasattr(o, 'tolist') else str(o))
