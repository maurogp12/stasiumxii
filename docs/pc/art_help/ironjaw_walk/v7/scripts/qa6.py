import sys, json, pickle, numpy as np
sys.path.insert(0, '/workspace/scratch/ij_walk/rig/lib')
from PIL import Image
from scipy import ndimage as ndi
import process_sheet as ps
import os
ROOT = os.environ.get('V5ROOT', '/workspace/art/ironjaw_full/v4_hd/_v7')
D = pickle.load(open(os.environ.get('PK', '/workspace/scratch/ij_walk/v7/walk7_data.pkl'), 'rb')); DATA = D['DATA']
V2QA = json.load(open('/workspace/art/ironjaw_full/v4_hd/_test/walk_qa.json'))
EXP = {'S': (-12, -6), 'E': (-12, 6), 'W': (12, -6), 'N': (12, 6)}; SRC = {'S': 'S', 'E': 'E', 'W': 'S', 'N': 'E'}
BGG = {'S': [169.0, 126.0], 'E': [144.0, 106.0]}   # E: new stride target backdrop 144 (+ old 106)
N8 = np.ones((3, 3), bool)
def load(tag, F, i):
    d = f'{ROOT}/walk' if tag == 'rim' else f'{ROOT}/_norim/walk'
    return Image.open(f'{d}/ironjaw_walk_{F}_f{i:02d}.png')
def mir(m, F): return m[:, ::-1] if F in 'WN' else m
def sole_pt(m):
    ys, xs = np.nonzero(m); y1 = ys.max(); sel = ys >= y1 - 2; return float(xs[sel].mean()), int(y1)
rep = {'frames': {}, 'summary': {}}
for F in 'SEWN':
    fac = SRC[F]; rows = []; tops = []; soles = {}
    for i in range(12):
        dd = DATA[fac][i]; fr = {}
        for tag in ('rim', 'norim'):
            im = load(tag, F, i); a = np.asarray(im)
            al = a[..., 3]; uniq = sorted(np.unique(al).tolist()); m = al > 0; ys, xs = np.nonzero(m)
            marg = dict(left=int(xs.min()), right=int(511 - xs.max()), top=int(ys.min()), bottom=int(359 - ys.max()))
            lab, n = ndi.label(m, N8); sz = sorted(np.bincount(lab.ravel())[1:].tolist(), reverse=True)
            hs = ps.halo_stats(a); edge = m & ~ndi.binary_erosion(m, N8); rgb = a[..., :3].astype(int)
            chroma = edge & ((rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2]) > 25) | (rgb[..., 2] - np.maximum(rgb[..., 0], rgb[..., 1]) > 25))
            # grey halo: edge px that look like the repaint's flat backdrop (neutral, within +-10 of its grey)
            neutral = (rgb.max(-1) - rgb.min(-1)) <= 6
            greyhalo = edge & neutral & np.any([np.abs(rgb.mean(-1) - g_) <= 10 for g_ in BGG[fac]], 0)
            # orphan px: transparent holes of 1-4 px fully inside, or opaque islands
            holes = ndi.binary_fill_holes(m) & ~m; hl, hn = ndi.label(holes); hsz = np.bincount(hl.ravel())[1:]
            fr[tag] = dict(rgba=im.mode == 'RGBA' and a.shape == (360, 512, 4), alpha_values=uniq, alpha_binary=uniq in ([0, 255], [255], [0]),
                           black_under_alpha0=bool((a[al == 0][:, :3] == 0).all()), margins=marg, margin_ok=min(marg.values()) >= 10,
                           components=n, comp_sizes=sz[:3], edge_near_white=hs['edge_px_near_white'], edge_chroma_px=int(chroma.sum()),
                           edge_grey_halo_px=int(greyhalo.sum()), edge_px=int(edge.sum()), pinholes_le4px=int((hsz <= 4).sum()))
        vis = dd['vis']
        legs = {s: vis[f'{s}_thigh'] + vis[f'{s}_shin'] + vis[f'{s}_boot'] for s in 'RL'}
        tops.append(dd['upper_top'])
        fr['rig'] = dict(legs_visible_px=legs, boot_visible_px={s: vis[f'{s}_boot'] for s in 'RL'}, planted=dd['planted'], upper_top_row=dd['upper_top'],
                         upper_visible_px={k: vis[k] for k in ('front', 'back', 'cape_low') if k in vis}, torso_rot_deg=dd['theta'],
                         arms='rigid in the upper piece (2 arms, 2 fists, 2 axes)')
        for s in 'RL': soles.setdefault(s, []).append(sole_pt(mir(dd['boot_layer'][s], F)))
        rows.append(fr)
    ex = EXP[F]
    for i in range(12):
        j = (i + 1) % 12; sup = sorted(set(DATA[fac][i]['planted']) & set(DATA[fac][j]['planted'])); sk = {}
        for s in sup:
            (x0, y0), (x1, y1) = soles[s][i], soles[s][j]; sk[s] = dict(dx=round(x1 - x0 - ex[0], 2), dy=round(y1 - y0 - ex[1], 2))
        comp = {}
        A = np.asarray(load('norim', F, i)); B = np.asarray(load('norim', F, j))
        for s in sup:
            v = mir(DATA[fac][i]['vis_boot'][s], F) & mir(DATA[fac][j]['vis_boot'][s], F)[np.clip(np.arange(360)[:, None] + ex[1], 0, 359), np.clip(np.arange(512)[None] + ex[0], 0, 511)]
            ys, xs = np.nonzero(v); same = (A[ys, xs] == B[ys + ex[1], xs + ex[0]]).all(1)
            comp[s] = dict(px=int(len(ys)), identical_frac=round(float(same.mean()) if len(ys) else 1.0, 4))
        rows[i]['skate_to_next'] = dict(support=sup, sole_err_px=sk, composite_shift_check=comp, max_err=max([max(abs(v['dx']), abs(v['dy'])) for v in sk.values()] or [0]))
    t = np.array(tops, float); steps = np.abs(np.diff(np.r_[t, t[0]]))
    bob = dict(helm_top_rows=tops, range_cell=float(np.ptp(t)), max_step_cell=float(steps.max()), range_game030=round(float(np.ptp(t)) * 0.3, 2), max_step_game030=round(float(steps.max()) * 0.3, 2))
    v2b = V2QA['summary'][F]['bob']; bob['v2'] = dict(range_cell=v2b['range_cell'], max_step_cell=v2b['max_step_cell'])
    off = np.array(tops) - np.array(v2b['helm_top_rows']); bob['offset_vs_v2_rows'] = sorted(set(off.tolist()))
    bob_ok = 6 <= bob['range_game030'] <= 9 and bob['max_step_game030'] <= 4 and len(set(off.tolist())) == 1
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
            if q['edge_grey_halo_px'] > 0.01 * q['edge_px']: fails.append(f'{tag}: grey halo {q["edge_grey_halo_px"]} edge px')
        for s in 'RL':
            if fr['rig']['legs_visible_px'][s] < 300: fails.append(f'{s} leg barely visible ({fr["rig"]["legs_visible_px"][s]} px)')
        if fr['skate_to_next']['max_err'] > 1: fails.append(f'skate {fr["skate_to_next"]["max_err"]} px')
        if not bob_ok: fails.append('bob out of range / differs from v2')
        fr['verdict'] = 'PASS' if not fails else 'FIX_REQUIRED'; fr['fails'] = fails
        rep['frames'][f'{F}_f{i:02d}'] = fr
    rep['summary'][F] = dict(bob=bob, bob_ok=bob_ok, verdicts=[fr['verdict'] for fr in rows], max_skate_px=max(fr['skate_to_next']['max_err'] for fr in rows),
                             min_margin=min(min(fr[t]['margins'].values()) for fr in rows for t in ('rim', 'norim')),
                             max_grey_halo_px=max(fr[t]['edge_grey_halo_px'] for fr in rows for t in ('rim', 'norim')),
                             min_composite_identical=min([v['identical_frac'] for fr in rows for v in fr['skate_to_next']['composite_shift_check'].values()] or [1.0]))
rep['notes'] = ['skate: support-boot sole on the full boot layer (v2 matrices, planted boots shifted exactly by the in-place slide)',
                'bob: top row of the upper piece (helm/horns), game px = cell px x 0.30; must equal v2 frame-for-frame up to one constant lift (the longer legs)',
                'grey halo: silhouette-edge px that are neutral and within +-10 of the repaint backdrop grey; must be < 1% of edge px',
                'W/N = exact mirrors of S/E']
V2D = pickle.load(open('/workspace/scratch/ij_walk/rig/walk_data.pkl', 'rb'))
rep['v2_sole_rows'] = {}
for F in 'SE':
    diffs = []
    for i in range(12):
        for s_ in DATA[F][i]['planted']:
            m4 = DATA[F][i]['boot_layer'][s_]; y4 = int(np.nonzero(m4.any(1))[0].max())
            m2 = V2D['DATA'][F][i]['boot_layer'][s_]; y2 = int(np.nonzero(m2.any(1))[0].max())
            diffs.append(y4 - y2)
    rep['v2_sole_rows'][F] = dict(v4_minus_v2_planted_sole_row=sorted(set(diffs)), n=len(diffs))
json.dump(rep, open(f'{ROOT}/_test/walk_qa.json', 'w'), indent=1)
for F in 'SEWN':
    s = rep['summary'][F]; print(F, s['verdicts'].count('PASS'), '/12 PASS', 'bob', s['bob']['range_cell'], s['bob']['max_step_cell'], 'v2', s['bob']['v2'], 'skate', s['max_skate_px'], 'minmarg', s['min_margin'], 'greyhalo', s['max_grey_halo_px'], 'comp', s['min_composite_identical'])
print(rep['v2_sole_rows'])
for k, fr in rep['frames'].items():
    if fr['fails']: print(k, fr['fails'])
