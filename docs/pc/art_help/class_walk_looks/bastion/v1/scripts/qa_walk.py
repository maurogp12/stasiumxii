"""Bastion walk QA: 48 frames (S, E as rendered; W, N = np.fliplr mirrors of S, E -> the shield swaps hands).
usage: qa_walk.py [FRAMES_DIR] [OUT_JSON]
Image checks run on the saved PNGs (mirrored for W/N); rig checks (limb/mace visibility, skate, hem) re-run the rig
in-process (build_hybrid.render_h) and compare that render with the saved PNG.
Differences from the Ironjaw qa (documented, both forced by the approved Bastion blockout):
 - bottom margin: the clay itself reaches 0-8 px from the cell bottom in S (the support sole sits there), so the rule is
   bottom >= min(10, clay bottom margin of the same frame - 2) instead of a flat 10; left/right/top stay >= 10.
 - bob: the head-top row must follow the clay's head-top row (|bob err| <= 1 px, the match_metric definition), not the
   Ironjaw 6-9 game-px range.
 - edge chroma: only green fringe counts (the deep-blue cape edge is legitimate art, not a key/fringe colour).
 - skate: fully planted pairs (heel AND toe planted in frame i and i+1) must move exactly with the ground (<= 1 px),
   measured from the boot rig transforms (painted heel/toe points) and from the visible boot sole; heel/toe pivot
   pairs are reported separately (they pivot like the blockout foot, plus the sole calibration nudges).
 - hem: lowest visible cape px >= 8 px above the blockout support sole (metric sole definition)."""
import sys, os, json, math, numpy as np
sys.argv, ARGS = sys.argv[:1], sys.argv[1:]
from PIL import Image
from scipy import ndimage as ndi
import build_hybrid as BH, build as BM, bastion_metric as MM, process_sheet as ps
HERE = os.path.dirname(os.path.abspath(__file__))
FR = ARGS[0] if ARGS else os.path.join(HERE, '..', 'frames'); OUT = ARGS[1] if len(ARGS) > 1 else os.path.join(FR, '..', 'qa_walk.json')
SRC = {'S': 'S', 'E': 'E', 'W': 'S', 'N': 'E'}; N8 = np.ones((3, 3), bool); MM.PREFIX = 'bastion'; CL = BH.B + 'clay'
MACE_R = 14.0                               # cell px radius of the mace head disk around the IK goal
def mir(a, F): return np.ascontiguousarray(a[:, ::-1]) if F in 'WN' else a
def sole_pt(m):
    ys, xs = np.nonzero(m)
    if not len(ys): return None
    y1 = ys.max(); sel = ys >= y1 - 2; return float(xs[sel].mean()), int(y1)
# ---- rig pass (S, E)
RIG = {}
for fac in 'SE':
    BH.prepare_h(fac); keys, _ = BH.thigh_keys(fac); J = BH.frames(fac); pl = BM.plants(fac); rows = []
    for i in range(12):
        rgb, al, layers, owner, Ms, meta, order = BH.render_h(fac, i, keys)
        cell, _ = BH.clean_cell(BH.compose_cell(rgb, al))
        vis = {nm: owner == order.index(nm) for nm in order}
        cnt = lambda names: int(sum(vis[n].sum() for n in names if n in vis))
        arms = {'R': cnt(['arm', 'R_upper', 'R_fore', 'R_elbowcop']), 'L': cnt(['L_upper', 'L_fore', 'L_elbowcop', 'shield'])}
        legs = {s: cnt([f'{s}_thigh', f'{s}_greave', f'{s}_boot', f'{s}_kneecop']) for s in 'RL'}
        hx, hy = meta['mace_head_xy']; yy, xx = np.indices(al.shape); disk = np.hypot(xx - hx, yy - hy) <= MACE_R
        mace = dict(px=int((disk & layers['arm']).sum()), visible_px=int((disk & vis['arm']).sum()))
        mace['visible_frac'] = round(mace['visible_px'] / max(1, mace['px']), 3)
        boots = {}
        for s in 'RL':
            d = BM.DEF[(fac, s + '_boot')]; M = np.array(Ms[s + '_boot'])
            pts = [M[:, :2] @ np.array(d[k], float) + M[:, 2] for k in ('heel', 'toe')]
            boots[s] = dict(pts=pts, M=M, sole=sole_pt(layers[s + '_boot']), heel=pl[s]['heel'][i], toe=pl[s]['toe'][i],
                            jheel=BM.jnt(J[i], s + '_heel'), jtoe=BM.jnt(J[i], s + '_toe'))
        jj = J[i]['joints']; sup = 'R' if jj['R_ankle'][1] >= jj['L_ankle'][1] else 'L'
        xw = [jj[f'{sup}_toe'][0], jj[f'{sup}_heel'][0], jj[f'{sup}_ankle'][0]]
        rv, mv = MM.load(CL, fac, i); pv = MM.sole(mv & ~MM.cloth(rv), min(xw) - 12, max(xw) + 12, jj[f'{sup}_ankle'][1] - 4)
        hem = int(np.nonzero(vis['cape'].any(1))[0].max()) if 'cape' in vis and vis['cape'].any() else None
        clay_bottom = int(359 - np.nonzero(mv)[0].max())
        rows.append(dict(cell=cell, arms=arms, legs=legs, mace=mace, boots=boots, sole_clay=pv, hem=hem, clay_bottom=clay_bottom,
                         head_top_clay=MM.head_top(mv), helm_tilt=meta.get('helm_tilt')))
    RIG[fac] = rows
report = {'frames': {}, 'summary': {}}
for F in 'SEWN':
    fac = SRC[F]; R = RIG[fac]; ex = np.array(BM.EXP[fac]) * (np.array([-1, 1]) if F in 'WN' else 1); out = []
    tops_c = []
    for i in range(12):
        im = Image.open(f'{FR}/bastion_walk_{fac}_f{i:02d}.png'); a0 = np.asarray(im); a = mir(a0, F)
        q = dict(rgba=im.mode == 'RGBA' and a.shape == (360, 512, 4))
        al = a[..., 3]; uniq = sorted(np.unique(al).tolist()); m = al > 0
        q['alpha_binary'] = uniq in ([0, 255], [255]); q['black_under_alpha0'] = bool((a[al == 0][:, :3] == 0).all())
        ys, xs = np.nonzero(m)
        q['margins'] = dict(left=int(xs.min()), right=int(511 - xs.max()), top=int(ys.min()), bottom=int(359 - ys.max()))
        q['bottom_min'] = min(10, R[i]['clay_bottom'] - 2)
        lab, n = ndi.label(m, N8); q['components'] = int(n)
        hs = ps.halo_stats(a); q['edge_near_white'] = hs['edge_px_near_white']
        edge = m & ~ndi.binary_erosion(m, N8); rgb = a[..., :3].astype(int)
        q['edge_green_px'] = int((edge & (rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2]) > 25)).sum())
        q['matches_rig_render'] = bool(np.array_equal(a0, R[i]['cell']))
        tops_c.append(int(ys[xs >= 0].min()) if False else MM.head_top(m))
        r = R[i]; q['arms_visible_px'] = r['arms']; q['legs_visible_px'] = r['legs']; q['mace_head'] = r['mace']
        if r['hem'] is not None: q['hem_clearance'] = int(r['sole_clay'][1] - r['hem'])
        # skate to the next frame
        j = (i + 1) % 12; full, piv = {}, {}
        for s in 'RL':
            bi, bj = r['boots'][s], R[j]['boots'][s]
            dp = [np.array(pj) - np.array(pi) - BM.EXP[fac] for pi, pj in zip(bi['pts'], bj['pts'])]
            e = round(float(max(np.abs(v).max() for v in dp)), 2)
            if bi['heel'] and bi['toe'] and bj['heel'] and bj['toe']:
                ds = np.array(bj['sole']) - np.array(bi['sole']) - BM.EXP[fac]
                full[s] = dict(rig_err=e, sole_dx=round(float(ds[0]), 2), sole_dy=round(float(ds[1]), 2))
            elif (bi['heel'] and bj['heel']) or (bi['toe'] and bj['toe']):
                # slide of the boot material point that sits on the blockout pivot joint in frame i (the blockout's own
                # pivot joint moves with the ground there): M_j(M_i^-1(joint_i)) - joint_i - ground
                k = 'jheel' if (bi['heel'] and bj['heel']) else 'jtoe'
                Mi = np.vstack([bi['M'], [0, 0, 1]]); mat = np.linalg.solve(Mi, np.r_[bi[k], 1.0])
                pj = bj['M'] @ mat; dj = bj[k] - bi[k] - BM.EXP[fac]
                piv[s] = dict(pivot=k[1:], slide_px=round(float(np.hypot(*(pj - bi[k] - BM.EXP[fac]))), 2),
                              blockout_joint_slide_px=round(float(np.hypot(*dj)), 2))
        q['skate_full_planted'] = full; q['pivot_slides'] = piv
        q['skate_max'] = max([max(v['rig_err'], abs(v['sole_dx']), abs(v['sole_dy'])) for v in full.values()] or [0])
        out.append(q)
    bc = np.array(tops_c, float); bv = np.array([R[i]['head_top_clay'] for i in range(12)], float)
    bob = (bc - bc.mean()) - (bv - bv.mean())
    for i, q in enumerate(out):
        q['bob_err'] = round(float(bob[i]), 2); f = []
        if not q['rgba']: f.append('not RGBA 512x360')
        if not q['alpha_binary']: f.append('alpha not binary')
        if not q['black_under_alpha0']: f.append('rgb under alpha 0 not black')
        mg = q['margins']
        if min(mg['left'], mg['right'], mg['top']) < 10: f.append(f'margin < 10 {mg}')
        if mg['bottom'] < q['bottom_min']: f.append(f'bottom margin {mg["bottom"]} < {q["bottom_min"]}')
        if q['components'] != 1: f.append(f'{q["components"]} components')
        if q['edge_near_white']: f.append(f'{q["edge_near_white"]} near-white edge px')
        if q['edge_green_px']: f.append(f'{q["edge_green_px"]} green fringe px')
        if not q['matches_rig_render']: f.append('saved PNG != rig render')
        for s in 'RL':
            if q['arms_visible_px'][s] < 300: f.append(f'{s} arm barely visible')
            if q['legs_visible_px'][s] < 300: f.append(f'{s} leg barely visible')
        if q['mace_head']['visible_frac'] < 0.5: f.append('mace head mostly hidden')
        if q['skate_max'] > 1: f.append(f'skate {q["skate_max"]} px')
        if abs(q['bob_err']) > 1: f.append(f'bob err {q["bob_err"]}')
        if q.get('hem_clearance') is not None and q['hem_clearance'] < 8: f.append(f'hem clearance {q["hem_clearance"]}')
        q['verdict'] = 'PASS' if not f else 'FIX_REQUIRED'; q['fails'] = f
        report['frames'][f'{F}_f{i:02d}'] = q
    report['summary'][F] = dict(passed=sum(q['verdict'] == 'PASS' for q in out), skate_max=max(q['skate_max'] for q in out),
                                bob_err_max=round(float(np.abs(bob).max()), 2), hem_min=min(q.get('hem_clearance', 99) for q in out),
                                pivot_slide_max=max([v['slide_px'] for q in out for v in q['pivot_slides'].values()] or [0]),
                                bottom_margins=[q['margins']['bottom'] for q in out])
tot = sum(s['passed'] for s in report['summary'].values()); report['total'] = f'{tot}/48'
json.dump(report, open(OUT, 'w'), indent=1, default=str)
for F, s in report['summary'].items(): print(F, s)
for k, q in report['frames'].items():
    if q['fails']: print(k, q['fails'])
print('TOTAL', report['total'])
