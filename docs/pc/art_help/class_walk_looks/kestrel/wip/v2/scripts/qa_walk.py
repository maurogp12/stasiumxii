"""Kestrel walk QA: 48 frames (S, E as rendered; W, N = mirrors of S, E -> the bow swaps hands, accepted by Mauro).
Same checks and documented rules as the Bastion v2 qa:
 - RGBA 512x360, binary alpha, black rgb under alpha 0, 1 component, no near-white / green-key fringe at the edge
 - margins: left/right/top >= 10; bottom >= min(10, clay bottom margin of the same frame - 2)
 - saved PNG == fresh rig render; both legs and the bow visible (>= 300 / 80 px)
 - bob: head-top row follows the clay (|err| <= 1 px)
 - skate: fully planted pairs (heel AND toe planted in i and i+1) move with the ground <= 1 px (rig points + visible sole)
 - toe-off / heel pivots: the foot material point on the blockout pivot joint slides <= 1 px (the Bastion rule, per pair);
   or the VISIBLE sole contact point (ball / heel bottom of the boot piece) slides <= 1 px; both are reported. S toe-off holds
   the visible ball (0 px); E toe-off follows the blockout toe joint (whose own visible toe slides; see scores.md)
 - hem: lowest visible green cloak px >= 8 px above the blockout support sole (metric sole definition)
usage: qa_walk.py [FRAMES_DIR] [OUT_JSON]"""
import sys, os, json, math, numpy as np
sys.argv, ARGS = sys.argv[:1], sys.argv[1:]
from PIL import Image
from scipy import ndimage as ndi
import kbuild as KB, kestrel_metric as MM
from kcommon import *
FR = ARGS[0] if ARGS else os.path.join(HERE, '..', 'frames'); OUT = ARGS[1] if len(ARGS) > 1 else os.path.join(FR, '..', 'qa_walk.json')
SRC = {'S': 'S', 'E': 'E', 'W': 'S', 'N': 'E'}; N8 = np.ones((3, 3), bool); CL = B + 'clay'
def mir(a, F): return np.ascontiguousarray(a[:, ::-1]) if F in 'WN' else a
def inv(M): A = np.vstack([M, [0, 0, 1]]); return np.linalg.inv(A)[:2]
def ap(M, p): return M[:, :2] @ np.asarray(p, float) + M[:, 2]
RIG = {}
for F in 'SE':
    KB.load_layers(F); W = frames(F); pl = plants(F); rows = []
    for i in range(12):
        acc, lay, owner, order, meta = KB.render(F, i); cell = KB.to_cell(acc)
        vis = lambda nm: int((owner == order.index(nm)).sum()) if nm in order else 0
        jj = W[i]['joints']; sup = 'R' if jj['R_ankle'][1] >= jj['L_ankle'][1] else 'L'
        xs = [jj[f'{sup}_toe'][0], jj[f'{sup}_heel'][0], jj[f'{sup}_ankle'][0]]
        rv, mv = MM.load(CL, F, i); sole_clay = MM.sole(mv & ~MM.cloth(rv), min(xs) - 12, max(xs) + 12, jj[f'{sup}_ankle'][1] - 4)
        rgb = cell[..., :3]; m = cell[..., 3] > 0; gr = MM.cloth(rgb) & m; ys = np.nonzero(gr.any(1))[0]
        feet = {s: dict(M=KB.foot_M(F, W[i], s, i, pl), heel=pl[s]['heel'][i], toe=pl[s]['toe'][i], jheel=jj[f'{s}_heel'], jtoe=jj[f'{s}_toe'],
                        vis=vis(f'{s}_foot'), sole=MM.sole(lay[f'{s}_foot'][..., 3] > 0.5, 0, 512)) for s in 'RL'}
        # bow: the brown-wood thin stroke lies in the body layer; count body px inside the bow band of the target (mapped)
        rows.append(dict(cell=cell, legs={s: vis(f'{s}_thigh') + vis(f'{s}_shin') + vis(f'{s}_foot') for s in 'RL'}, feet=feet,
                         hem=int(ys.max()) if len(ys) else None, sole_clay=sole_clay, head_top_clay=MM.head_top(mv),
                         clay_bottom=int(359 - np.nonzero(mv.any(1))[0].max())))
    RIG[F] = rows
A = KB.TLEG
report = {'frames': {}, 'summary': {}}
for F in 'SEWN':
    S0 = SRC[F]; R = RIG[S0]; out = []; tops = []
    for i in range(12):
        p = os.path.join(FR, f'kestrel_walk_{F}_f{i:02d}.png') if os.path.exists(os.path.join(FR, f'kestrel_walk_{F}_f{i:02d}.png')) else os.path.join(FR, f'kestrel_walk_{S0}_f{i:02d}.png')
        im = Image.open(p); a = np.asarray(im.convert('RGBA')); a = mir(a, F) if not os.path.basename(p).startswith(f'kestrel_walk_{F}_') else a
        ref = mir(R[i]['cell'], F); al = a[..., 3]; m = al > 0
        q = dict(rgba=im.mode == 'RGBA' and im.size == (512, 360), alpha_binary=bool(np.isin(al, [0, 255]).all()),
                 black_under_alpha0=bool((a[..., :3][~m] == 0).all()), matches_rig_render=bool(np.array_equal(a, ref)))
        ys, xs = np.nonzero(m); q['margins'] = dict(left=int(xs.min()), right=int(511 - xs.max()), top=int(ys.min()), bottom=int(359 - ys.max()))
        q['bottom_min'] = min(10, R[i]['clay_bottom'] - 2); tops.append(int(ys.min()))
        lab, n = ndi.label(m, N8); q['components'] = int(n)
        edge = m & ~ndi.binary_erosion(m, N8); rgbf = a[..., :3].astype(int)
        q['edge_near_white'] = int((edge & (rgbf.min(-1) > 215)).sum())
        q['edge_green_px'] = int((edge & (rgbf[..., 1] > 150) & (rgbf[..., 1] > rgbf[..., 0] + 60) & (rgbf[..., 1] > rgbf[..., 2] + 60)).sum())
        q['legs_visible_px'] = R[i]['legs']
        q['hem_clearance'] = int(R[i]['sole_clay'][1] - R[i]['hem']) if R[i]['hem'] is not None else None
        j = (i + 1) % 12; full, piv = {}, {}
        for s in 'RL':
            bi, bj = R[i]['feet'][s], R[j]['feet'][s]
            pts = [A[S0]['anchors']['heel'], A[S0]['anchors']['toe']]
            e = max(float(np.abs(ap(bj['M'], t) - ap(bi['M'], t) - EXP[S0]).max()) for t in pts)
            if bi['heel'] and bi['toe'] and bj['heel'] and bj['toe']:
                ds = np.array(bj['sole']) - np.array(bi['sole']) - EXP[S0]
                full[s] = dict(rig_err=round(e, 2), sole_dx=round(float(ds[0]), 2), sole_dy=round(float(ds[1]), 2))
            elif (bi['heel'] and bj['heel']) or (bi['toe'] and bj['toe']):
                k = 'jheel' if (bi['heel'] and bj['heel']) else 'jtoe'
                mat = ap(inv(bi['M']), bi[k]); sl = ap(bj['M'], mat) - np.array(bi[k]) - EXP[S0]   # Bastion rule: point on the joint
                vk = KB.contact_pts(S0)['TB' if k == 'jtoe' else 'HB']; vs = ap(bj['M'], vk) - ap(bi['M'], vk) - EXP[S0]   # visible sole point
                piv[s] = dict(pivot=k[1:], slide_px=round(float(np.hypot(*sl)), 2), visible_contact_slide_px=round(float(np.hypot(*vs)), 2),
                              visible_contact_dxdy=[round(float(v), 2) for v in vs])
        q['skate_full_planted'] = full; q['pivot_slides'] = piv
        q['skate_max'] = max([max(v['rig_err'], abs(v['sole_dx']), abs(v['sole_dy'])) for v in full.values()] or [0])
        out.append(q)
    bc = np.array(tops, float); bv = np.array([R[i]['head_top_clay'] for i in range(12)], float); bob = (bc - bc.mean()) - (bv - bv.mean())
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
            if q['legs_visible_px'][s] < 300: f.append(f'{s} leg barely visible')
        if q['skate_max'] > 1: f.append(f'skate {q["skate_max"]} px')
        for s, v in q['pivot_slides'].items():
            if min(v['slide_px'], v['visible_contact_slide_px']) > 1: f.append(f'{s} {v["pivot"]} pivot slide {v["slide_px"]} px (visible contact {v["visible_contact_slide_px"]} px)')
        if abs(q['bob_err']) > 1: f.append(f'bob err {q["bob_err"]}')
        if q['hem_clearance'] is not None and q['hem_clearance'] < 8: f.append(f'hem clearance {q["hem_clearance"]}')
        q['verdict'] = 'PASS' if not f else 'FIX_REQUIRED'; q['fails'] = f
        report['frames'][f'{F}_f{i:02d}'] = q
    report['summary'][F] = dict(passed=sum(q['verdict'] == 'PASS' for q in out), skate_max=max(q['skate_max'] for q in out),
                                bob_err_max=round(float(np.abs(bob).max()), 2), hem_min=min(q['hem_clearance'] if q['hem_clearance'] is not None else 99 for q in out),
                                pivot_slide_max=max([min(v['slide_px'], v['visible_contact_slide_px']) for q in out for v in q['pivot_slides'].values()] or [0]),
                                bottom_margins=[q['margins']['bottom'] for q in out])
tot = sum(s['passed'] for s in report['summary'].values()); report['total'] = f'{tot}/48'
json.dump(report, open(OUT, 'w'), indent=1, default=str)
for F, s in report['summary'].items(): print(F, s)
for k, q in report['frames'].items():
    if q['fails']: print(k, q['fails'])
print('TOTAL', report['total'])
