"""Leg value (L*) measurement, same method for idle and walk frames.
Leg mask = alpha & union of capsules along TA's joints (hip->knee, knee->ankle, ankle->toe/heel) & not cloth (crimson)
& below the hip row - 4 (keeps the belt/skull out). Capsule radius 9 px (thigh/shin) 8 px (foot)."""
import sys, json, numpy as np, cv2
from PIL import Image
sys.path.insert(0, '/workspace/scratch/ij_walk/rig/lib'); import lab34 as LB
sys.path.insert(0, '/workspace/handoff/ironjaw_walk_claude/claude_reply/scripts'); import rig_fx as fx
JF = '/workspace/art_src/blockout/ironjaw_walk/renders_512/joints_512.json'; J = json.load(open(JF))['facings']
IDLE = '/workspace/handoff/ironjaw_walk_claude/hd_set_idle/ironjaw_idle_{F}_f00.png'
def leg_mask(rgba, j, r=9):
    a = rgba[..., 3] > 127; m = np.zeros(a.shape, bool)
    for s in 'RL':
        m |= fx.capsule(a.shape, j[f'{s}_hip'], j[f'{s}_knee'], r) | fx.capsule(a.shape, j[f'{s}_knee'], j[f'{s}_ankle'], r)
        m |= fx.capsule(a.shape, j[f'{s}_ankle'], j[f'{s}_toe'], r - 1) | fx.capsule(a.shape, j[f'{s}_ankle'], j[f'{s}_heel'], r - 1)
    hy = min(j['R_hip'][1], j['L_hip'][1]) - 4; m[:int(hy)] = False
    lab = LB.rgb2lab(rgba[..., :3]); cw = LB.cloth_weight(lab, a & m)
    return a & m & (cw < 0.3), lab
BOX = {'S': (170, 225, 345, 330), 'E': (180, 245, 345, 330)}   # idle leg box (x0, y0, x1, y1): below fists/tassets, between the axe heads
def idle_legs(F):
    """TA's idle joints do not sit on the painted idle legs (the HD idle is wider), so the idle uses a hand box + cloth reject."""
    im = np.asarray(Image.open(IDLE.format(F=F)).convert('RGBA')); a = im[..., 3] > 127; x0, y0, x1, y1 = BOX[F]
    b = np.zeros(a.shape, bool); b[y0:y1, x0:x1] = True; lab = LB.rgb2lab(im[..., :3]); cw = LB.cloth_weight(lab, a & b)
    return im, a & b & (cw < 0.3), lab
def walk_legs(path, F, i):
    im = np.asarray(Image.open(path).convert('RGBA')); m, lab = leg_mask(im, J[f'walk_{F}'][f'f{i:02d}']['joints']); return im, m, lab
def p95(lab, m): return float(np.percentile(lab[..., 0][m], 95))
if __name__ == '__main__':
    out = {}
    for F in 'SE':
        _, m, lab = idle_legs(F); r = dict(idle_p95=round(p95(lab, m), 1), idle_p50=round(float(np.median(lab[..., 0][m])), 1))
        for nm, d in [(a.split('=')[0], a.split('=')[1]) for a in sys.argv[1:]]:
            Ls = []
            for i in range(12):
                _, mw, lw = walk_legs(f'{d}/ironjaw_walk_{F}_f{i:02d}.png', F, i); Ls.append(lw[..., 0][mw])
            Ls = np.concatenate(Ls); r[nm + '_p95'] = round(float(np.percentile(Ls, 95)), 1); r[nm + '_p50'] = round(float(np.median(Ls)), 1)
        out[F] = r
    print(json.dumps(out))
