"""v3 leg checks for one build (run with that build's scripts dir first on sys.path / PYTHONPATH):
greave width / shoulder width (cell) vs the same ratio on the approved target, and the hip midpoint vs the target belt
centre (target belt corners mapped like the f00 trunk layer + the per-frame blockout pelvis delta).
 - greave width: full greave layer (the piece as posed, before occlusion), perpendicular to its axis (piece A->B as mapped),
   mean over the middle 40-60% of the axis; target: the cut target greave (target px) measured the same way.
 - shoulder width: widest row of (trunk + near pauldron) target layers over the pauldron rows; target: same layers in target px.
usage: leg_ratio.py OUT_JSON [frames=0,6]"""
import sys, os, json, math, numpy as np
sys.argv, ARGS = sys.argv[:1], sys.argv[1:]
from PIL import Image
import build_hybrid as BH, build as BM
OUT = ARGS[0]; FR = [int(x) for x in (ARGS[1] if len(ARGS) > 1 else '0,6').split(',')]
BELT = {'S': [[642, 300], [762, 300]], 'E': [[614, 305], [722, 305]]}      # target px belt corners (v3 cfg leg_v3.belt)
P = BM.P; TL = json.load(open(P + 'target_layers.json'))['info']; TLEG = json.load(open(P + 'target_legs.json'))
def perp_width(m, A, B, t0=0.4, t1=0.6):
    A = np.asarray(A, float); B = np.asarray(B, float); L = np.linalg.norm(B - A); u = (B - A) / L; n = np.array([-u[1], u[0]])
    ys, xs = np.nonzero(m); Q = np.stack([xs, ys], 1) - A; a = Q @ u; b = Q @ n; ws = []
    for t in np.linspace(t0, t1, 9):
        sel = np.abs(a - t * L) <= 0.75
        if sel.sum() > 2: ws.append(b[sel].max() - b[sel].min() + 1)
    return float(np.mean(ws))
def shoulder_width(m, rows):
    w = [np.nonzero(m[y])[0] for y in rows]; return float(max(r.max() - r.min() + 1 for r in w if len(r)))
res = {}
for F in 'SE':
    # target ratio (target px)
    g = TLEG[f'{F}_greave']; gm = np.asarray(Image.open(P + g['file'] + '.png'))[..., 3] > 0
    tg = perp_width(gm, g['A'], g['B'])
    H = 720; Wd = 1280; tm = np.zeros((H, Wd), bool); pr = None
    for ly in ('trunk', 'R_pauld'):
        a = np.asarray(Image.open(P + f'T{F}_{ly}.png'))[..., 3] > 0; o = TL[F][ly]['origin']
        tm[o[1]:o[1] + a.shape[0], o[0]:o[0] + a.shape[1]] |= a
        if ly == 'R_pauld': pr = range(o[1], o[1] + a.shape[0])
    ts = shoulder_width(tm, pr)
    th = TLEG[f'{F}_thigh']; thm = np.asarray(Image.open(P + th['file'] + '.png'))[..., 3] > 0; tth = perp_width(thm, th['A'], th['B'])
    sb = TLEG[f'{F}_sabaton']; sba = int((np.asarray(Image.open(P + sb['file'] + '.png'))[..., 3] > 0).sum())
    res[F] = dict(target=dict(greave_w=round(tg, 2), shoulder_w=round(ts, 2), ratio=round(tg / ts, 4), thigh_w=round(tth, 2),
                              thigh_ratio=round(tth / ts, 4), sabaton_px=sba))
    BH.prepare_h(F); keys, _ = BH.thigh_keys(F); W = BH.frames(F); Mt0 = BH.trunk_M(F, W[0])
    for i in FR:
        rgb, al, layers, owner, Ms, meta, order = BH.render_h(F, i, keys)
        d = BM.DEF[(F, 'greave')]; gw = {}
        for sd in 'RL':
            M = Ms[sd + '_greave']; A = M[:, :2] @ np.array(d['A'], float) + M[:, 2]; B = M[:, :2] @ np.array(d['B'], float) + M[:, 2]
            gw[sd] = perp_width(layers[sd + '_greave'], A, B)
        tw = {}
        for sd in 'RL':
            dt = BM.DEF[(F, sd + '_thigh')]; M = Ms[sd + '_thigh']
            tw[sd] = perp_width(layers[sd + '_thigh'], M[:, :2] @ np.array(dt['A'], float) + M[:, 2], M[:, :2] @ np.array(dt['B'], float) + M[:, 2])
        s_up = BH.TCFG[F]['s_up']; sab = {sd: round(math.sqrt(layers[sd + '_boot'].sum() / (res[F]['target']['sabaton_px'] * s_up ** 2)), 3) for sd in 'RL'}
        sm = layers['trunk'] | layers['R_pauld']; ys = np.nonzero(layers['R_pauld'].any(1))[0]
        sw = shoulder_width(sm, range(ys.min(), ys.max() + 1))
        dp = np.array(W[i]['joints']['pelvis']) - np.array(W[0]['joints']['pelvis'])
        belt = Mt0[:, :2] @ np.mean(np.array(BELT[F], float), 0) + Mt0[:, 2] + dp
        if 'legs_v3' in meta: hips = {sd: np.array(meta['legs_v3'][sd]['hip']) for sd in 'RL'}
        else: hips = {sd: np.array(W[i]['joints'][sd + '_hip']) for sd in 'RL'}
        mid = (hips['R'] + hips['L']) / 2; gmean = (gw['R'] + gw['L']) / 2; r = gmean / sw
        res[F][f'f{i:02d}'] = dict(greave_w={k: round(v, 2) for k, v in gw.items()}, greave_w_mean=round(gmean, 2), shoulder_w=round(sw, 2),
                                   ratio=round(r, 4), ratio_vs_target_pct=round(100 * (r / res[F]['target']['ratio'] - 1), 1),
                                   thigh_w={k: round(v, 2) for k, v in tw.items()}, thigh_ratio_vs_target_pct={k: round(100 * (v / sw / res[F]['target']['thigh_ratio'] - 1), 1) for k, v in tw.items()},
                                   sabaton_linear_scale_vs_target=sab,
                                   hips={k: np.round(v, 2).tolist() for k, v in hips.items()}, hip_mid=np.round(mid, 2).tolist(),
                                   belt_centre=np.round(belt, 2).tolist(), hip_mid_off_px=round(float(np.linalg.norm(mid - belt)), 2),
                                   hip_mid_off_xy=np.round(mid - belt, 2).tolist())
json.dump(res, open(OUT, 'w'), indent=1); print(json.dumps(res))
