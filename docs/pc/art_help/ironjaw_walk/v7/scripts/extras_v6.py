#!/usr/bin/env python3
"""v5 scorer extras (the official numbers stay match_metric.py's, untouched).

  motion_bootsole  VARIANT, not official: same as motion_score, except the v2 reference sole is taken from v2's boot-only
                   layers (rig/walk_data.pkl boot_layer R|L) instead of v2's composite frame. Justification: v2's composite
                   at S f02 has a stray dark cape tip one row below its boot, which the official metric treats as v2's sole.
                   Candidate sole is still taken from the candidate's composite (cape hem below the boots still counts).
  leg_ratio_true   info: official leg_ratio_vs_repaint clips the fitted repaint at the cell's bottom row (359); this one uses
                   the unclipped repaint sole row and the fitted repaint pelvis row: (cand sole - tgt pelvis)/(tgt sole - tgt pelvis)
  secondary_look   E only, SECONDARY: ssim_lower / iou vs the repaint at the v2 frame whose stance is closest to the repaint's
                   closed stance (chosen once, from v2 alone: max lower-body IoU of v2 vs the repaint moved with the pelvis).
usage: extras_v5.py --facing F --cand DIR --official mm.json --out extras.json
"""
import argparse, json, math, pickle, sys
import numpy as np
sys.path.insert(0, '/workspace/handoff/ironjaw_walk_claude/claude_reply/scripts')
import match_metric as MM
V2 = '/workspace/art/ironjaw_full/v4_hd/walk'
JS = '/workspace/art_src/blockout/ironjaw_walk/renders_512/joints_512.json'
V2PKL = '/workspace/scratch/ij_walk/rig/walk_data.pkl'
RP_PELVIS = {'S': 330, 'E': 330}
NEW_E_TARGET = '/workspace/scratch/ij_walk/repaint_E2/rp_E_stride_t2.jpg'

def lower_scores(F, d, i, fitp, J, trgb, ta):
    py = J['f00']['joints']['pelvis'][1]; s, tx, ty = fitp
    dd = np.array(J[f'f{i:02d}']['joints']['pelvis']) - np.array(J['f00']['joints']['pelvis'])
    r, m = MM.load(d, F, i); tr, tm = MM.place(trgb, ta, s, tx + dd[0], ty + dd[1])
    U = m | tm; lo = np.zeros_like(U); lo[int(round(py + dd[1])):] = True
    return dict(ssim_lower=round(MM.mssim(MM.comp(r, m), MM.comp(tr, tm), U & lo), 3),
                iou=round(float((m & tm).sum() / U.sum()), 3),
                iou_lower=round(float((m & tm & lo).sum() / max(1, (U & lo).sum())), 3))

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--facing'); ap.add_argument('--cand'); ap.add_argument('--official'); ap.add_argument('--out'); ap.add_argument('--target', default=None, help='target override (default: the old rp_{F}_f00_t1.jpg)'); ap.add_argument('--rp_pelvis', type=float, default=None)
    a = ap.parse_args(); F = a.facing; off = json.load(open(a.official))
    J = json.load(open(JS))['facings'][f'walk_{F}']; py = int(round(J['f00']['joints']['pelvis'][1]))
    trgb, ta, _ = MM.cut_target(a.target or f'/workspace/scratch/ij_walk/repaint/rp_{F}_f00_t1.jpg')
    BL = pickle.load(open(V2PKL, 'rb'))['DATA'][F]
    r = {}
    # motion_bootsole
    errs = []
    for i in range(12):
        jj = J[f'f{i:02d}']['joints']; sup = 'R' if jj['R_ankle'][1] >= jj['L_ankle'][1] else 'L'
        xs = [jj[f'{sup}_toe'][0], jj[f'{sup}_heel'][0], jj[f'{sup}_ankle'][0]]; y0 = jj[f'{sup}_ankle'][1] - 4
        rc, mc = MM.load(a.cand, F, i)
        pc = MM.sole(mc & ~MM.cloth(rc), min(xs) - 12, max(xs) + 12, y0)
        mv = BL[i]['boot_layer']['R'] | BL[i]['boot_layer']['L']
        pv = MM.sole(mv, min(xs) - 12, max(xs) + 12, y0)
        errs.append(round(math.dist(pc, pv), 2) if pc and pv else None)
    bob = off['bob_err_per_frame']
    ok = [(e is not None and e <= 2 and abs(b) <= 1) for e, b in zip(errs, bob)]
    r['motion_bootsole'] = round(100 * sum(ok) / 12, 1); r['sole_err_bootsole'] = errs
    # leg_ratio_true
    cr, cm = MM.load(a.cand, F, 0); f = off['fit']; tys = np.nonzero(ta)[0]
    ts = f['ty'] + f['scale'] * tys.max(); tp = f['ty'] + f['scale'] * (a.rp_pelvis if a.rp_pelvis is not None else RP_PELVIS[F]); cs = np.nonzero(cm)[0].max()
    r['leg_ratio_true'] = round(float((cs - tp) / (ts - tp)), 3)
    r['leg_ratio_true_detail'] = dict(cand_sole_row=int(cs), tgt_sole_row_unclipped=round(float(ts), 1), tgt_pelvis_row=round(float(tp), 1))
    # secondary look (E)
    if F == 'E':
        vr, vm = MM.load(V2, F, 0); _, s2, tx2, ty2 = MM.fit(trgb, ta, vm, py)
        sel = [(lower_scores(F, V2, i, (s2, tx2, ty2), J, trgb, ta)['iou_lower'], i) for i in range(12)]
        k = max(sel)[1]
        r['secondary_look'] = dict(label='SECONDARY (not official): repaint vs closest-stance v2 frame', frame=k,
                                   v2_lower_iou_per_frame=[v for v, _ in sel],
                                   cand=lower_scores(F, a.cand, k, (f['scale'], f['tx'], f['ty']), J, trgb, ta),
                                   cand_f00=lower_scores(F, a.cand, 0, (f['scale'], f['tx'], f['ty']), J, trgb, ta))
    json.dump(r, open(a.out, 'w'), indent=1); print(F, json.dumps({k: v for k, v in r.items() if 'detail' not in k and 'per_frame' not in str(v)[:0]}))
main()
