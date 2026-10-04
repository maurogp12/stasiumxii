import sys, json, pickle, math, numpy as np
sys.path.insert(0, '/workspace/scratch/ij_walk/rig'); sys.path.insert(0, '/workspace/scratch/ij_walk/rig/lib')
from PIL import Image
from scipy import ndimage as ndi
import process_sheet as ps
from rig_def import PARTS
ROOT = '/workspace/art/ironjaw_full/v4_hd'
D = pickle.load(open('/workspace/scratch/ij_walk/rig/walk_data.pkl', 'rb')); DATA = D['DATA']
EXP = {'S': (-12, -6), 'E': (-12, 6), 'W': (12, -6), 'N': (12, 6)}
SRC = {'S': 'S', 'E': 'E', 'W': 'S', 'N': 'E'}
N8 = np.ones((3, 3), bool)
def load(tag, F, i):
    d = f'{ROOT}/walk' if tag == 'rim' else f'{ROOT}/_norim/walk'
    return Image.open(f'{d}/ironjaw_walk_{F}_f{i:02d}.png')
def mir(m, F): return m[:, ::-1] if F in 'WN' else m
def sole_pt(m):
    ys, xs = np.nonzero(m); y1 = ys.max(); sel = ys >= y1 - 2
    return float(xs[sel].mean()), int(y1)
def head_region(fac, side, Ms, layer):
    d = PARTS[fac][f'{side}_forearm']; M = np.array(Ms[f'{side}_forearm'])
    G = M[:, :2] @ np.array(d['G'], float) + M[:, 2]; H = M[:, :2] @ np.array(d['H'], float) + M[:, 2]
    u = H - G; L2 = (u ** 2).sum(); yy, xx = np.indices(layer.shape)
    t = ((xx - G[0]) * u[0] + (yy - G[1]) * u[1]) / L2
    return layer & (t > 0.55)
report = {'frames': {}, 'summary': {}}
for F in 'SEWN':
    fac = SRC[F]; rows = []
    tops = []; soles = {}
    for i in range(12):
        dd = DATA[fac][i]; fr = {}
        for tag in ('rim', 'norim'):
            im = load(tag, F, i); a = np.asarray(im)
            ok_mode = im.mode == 'RGBA' and a.shape == (360, 512, 4)
            al = a[..., 3]; uniq = sorted(np.unique(al).tolist())
            black = bool((a[al == 0][:, :3] == 0).all())
            m = al > 0; ys, xs = np.nonzero(m)
            marg = dict(left=int(xs.min()), right=int(511 - xs.max()), top=int(ys.min()), bottom=int(359 - ys.max()))
            lab, n = ndi.label(m, N8); sz = sorted(np.bincount(lab.ravel())[1:].tolist(), reverse=True)
            hs = ps.halo_stats(a)
            edge = m & ~ndi.binary_erosion(m, N8)
            rgb = a[..., :3].astype(int)
            chroma = edge & ((rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2]) > 25) | (rgb[..., 2] - np.maximum(rgb[..., 0], rgb[..., 1]) > 25))
            fr[tag] = dict(rgba=ok_mode, alpha_values=uniq, alpha_binary=uniq in ([0, 255], [255], [0]), black_under_alpha0=black,
                           margins=marg, margin_ok=min(marg.values()) >= 10, components=n, comp_sizes=sz[:4],
                           edge_near_white=hs['edge_px_near_white'], edge_lum_gt170=hs['edge_px_lum_gt_170'], edge_chroma_px=int(chroma.sum()))
        # limb / axe visibility from the rig layers (S/E; mirrored for W/N)
        vis = dd['vis']
        arms = {s: vis[f'{s}_upperarm'] + vis[f'{s}_forearm'] for s in 'RL'}
        legs = {s: vis[f'{s}_thigh'] + vis[f'{s}_shin'] + vis[f'{s}_boot'] for s in 'RL'}
        axes = {}
        for s in 'RL':
            hr = head_region(fac, s, dd['Ms'], dd['layers'][f'{s}_forearm']); hv = hr & dd['fore_vis'][s]
            axes[s] = dict(px=int(hr.sum()), visible_px=int(hv.sum()), visible_frac=round(float(hv.sum() / max(hr.sum(), 1)), 3))
        top = dd['torso_top']; tops.append(top)
        fr['rig'] = dict(arms_visible_px=arms, legs_visible_px=legs, axe_head_visibility=axes, planted=dd['planted'], torso_top_row=top,
                         boot_visible_px={s: vis[f'{s}_boot'] for s in 'RL'})
        for s in 'RL':
            soles.setdefault(s, []).append(sole_pt(mir(dd['boot_layer'][s], F)))
        rows.append(fr)
    # skate: support boot = planted in both i and i+1
    ex = EXP[F]
    for i in range(12):
        j = (i + 1) % 12; pi, pj = set(DATA[fac][i]['planted']), set(DATA[fac][j]['planted'])
        sup = sorted(pi & pj); sk = {}
        for s in sup:
            (x0, y0), (x1, y1) = soles[s][i], soles[s][j]
            sk[s] = dict(dx=round(x1 - x0 - ex[0], 2), dy=round(y1 - y0 - ex[1], 2))
        # composite check: visible support boot px of frame i, shifted, equal in frame j (un-rimmed)
        comp = {}
        A = np.asarray(load('norim', F, i)); B = np.asarray(load('norim', F, j))
        for s in sup:
            v = mir(DATA[fac][i]['vis_boot'][s], F) & mir(DATA[fac][j]['vis_boot'][s], F)[np.clip(np.arange(360)[:, None] + ex[1], 0, 359), np.clip(np.arange(512)[None] + ex[0], 0, 511)]
            ys, xs = np.nonzero(v)
            same = (A[ys, xs] == B[ys + ex[1], xs + ex[0]]).all(1)
            comp[s] = dict(px=int(len(ys)), identical_frac=round(float(same.mean()) if len(ys) else 1.0, 4))
        rows[i]['skate_to_next'] = dict(support=sup, sole_err_px=sk, composite_shift_check=comp,
                                        max_err=max([max(abs(v['dx']), abs(v['dy'])) for v in sk.values()] or [0]))
    # bob
    t = np.array(tops, float); steps = np.abs(np.diff(np.r_[t, t[0]]))
    bob = dict(helm_top_rows=tops, range_cell=float(np.ptp(t)), max_step_cell=float(steps.max()),
               range_game030=round(float(np.ptp(t)) * 0.3, 2), max_step_game030=round(float(steps.max()) * 0.3, 2))
    bob_ok = 6 <= bob['range_game030'] <= 9 and bob['max_step_game030'] <= 4
    # verdicts
    for i, fr in enumerate(rows):
        fails = []
        for tag in ('rim', 'norim'):
            q = fr[tag]
            if not q['rgba']: fails.append(f'{tag}: not RGBA 512x360')
            if not q['alpha_binary']: fails.append(f'{tag}: alpha not 0/255')
            if not q['black_under_alpha0']: fails.append(f'{tag}: RGB under alpha 0 not black')
            if not q['margin_ok']: fails.append(f'{tag}: margin < 10 ({q["margins"]})')
            if q['components'] != 1: fails.append(f'{tag}: {q["components"]} components {q["comp_sizes"]}')
            if q['edge_near_white'] > 0: fails.append(f'{tag}: {q["edge_near_white"]} near-white edge px')
            if q['edge_chroma_px'] > 0: fails.append(f'{tag}: {q["edge_chroma_px"]} chroma edge px')
        rg = fr['rig']
        for s in 'RL':
            if rg['arms_visible_px'][s] < 300: fails.append(f'{s} arm barely visible ({rg["arms_visible_px"][s]} px)')
            if rg['legs_visible_px'][s] < 300: fails.append(f'{s} leg barely visible ({rg["legs_visible_px"][s]} px)')
        near = 'R'; far = 'L'
        if rg['axe_head_visibility'][near]['visible_frac'] < 0.5: fails.append('near axe head mostly hidden')
        if fac == 'S' and rg['axe_head_visibility'][far]['visible_frac'] < 0.5: fails.append('far axe head mostly hidden (S)')
        if fac == 'E' and rg['axe_head_visibility'][far]['visible_frac'] > 0.10: fails.append('far axe should be hidden in E')
        if fr['skate_to_next']['max_err'] > 1: fails.append(f'skate {fr["skate_to_next"]["max_err"]} px')
        if not bob_ok: fails.append('bob out of range')
        fr['verdict'] = 'PASS' if not fails else 'FIX_REQUIRED'; fr['fails'] = fails
        report['frames'][f'{F}_f{i:02d}'] = fr
    report['summary'][F] = dict(bob=bob, bob_ok=bob_ok, verdicts=[fr['verdict'] for fr in rows],
                                max_skate_px=max(fr['skate_to_next']['max_err'] for fr in rows))
# idle f00 -> walk f00 offsets
off = {}
for F in 'SEWN':
    a = np.asarray(Image.open(f'{ROOT}/_norim/idle/ironjaw_idle_{F}_f00.png'))[..., 3] > 0
    b = np.asarray(load('norim', F, 0))[..., 3] > 0
    def st(m):
        ys, xs = np.nonzero(m); return dict(top=int(ys.min()), bottom=int(ys.max()), left=int(xs.min()), right=int(xs.max()),
                                            cx=round(float(xs.mean()), 1), cy=round(float(ys.mean()), 1), px=int(m.sum()))
    sa, sb = st(a), st(b)
    off[F] = dict(idle_f00=sa, walk_f00=sb, delta={k: round(sb[k] - sa[k], 1) for k in sa})
report['idle_to_walk_f00'] = off
report['notes'] = ['skate: support-boot sole tracked on the full boot layer; error = frame-to-frame sole shift minus the in-place slide (12,6)/frame (= 0 drift in game at 161 cell px/cycle)',
                   'bob: helm-top row of the rigid torso layer; game px = cell px x 0.30',
                   'axe_head_visibility: visible share of the forearm+axe piece beyond 55% of grip->head',
                   'W/N are exact horizontal mirrors of S/E (np.fliplr of the 512 cell, pivot x=256)']
json.dump(report, open(f'{ROOT}/_test/walk_qa.json', 'w'), indent=1)
for F in 'SEWN':
    s = report['summary'][F]; print(F, s['verdicts'], 'bob', s['bob']['range_cell'], s['bob']['max_step_cell'], s['bob']['range_game030'], s['bob']['max_step_game030'], 'skate', s['max_skate_px'])
for k, fr in report['frames'].items():
    if fr['fails']: print(k, fr['fails'])
print(json.dumps(off['S']['delta']), json.dumps(off['E']['delta']))
