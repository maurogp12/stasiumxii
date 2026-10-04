"""brief point 3: boot separation per frame = overlap px of the two boots (shin + foot layers) and the closest gap between them.
usage: boot_sep.py [F]"""
import sys, os, json, numpy as np
from scipy import ndimage as ndi
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kbuild as KB
from kcommon import *
def measure(F):
    KB.load_layers(F); out = []
    for i in range(12):
        acc, lay, owner, order, meta = KB.render(F, i)
        b = {sd: (lay[sd + '_shin'][..., 3] > 0.5) | (lay[sd + '_foot'][..., 3] > 0.5) for sd in 'RL'}
        f = {sd: lay[sd + '_foot'][..., 3] > 0.5 for sd in 'RL'}
        ov = int((b['R'] & b['L']).sum()); fov = int((f['R'] & f['L']).sum())
        dt = ndi.distance_transform_edt(~b['L']); gap = float(dt[b['R']].min()) if b['R'].any() else 0.0
        ftd = ndi.distance_transform_edt(~f['L']); fgap = float(ftd[f['R']].min())
        cR = np.argwhere(f['R']).mean(0)[::-1]; cL = np.argwhere(f['L']).mean(0)[::-1]
        out.append(dict(frame=i, boot_overlap_px=ov, foot_overlap_px=fov, boot_gap_px=round(gap, 1), foot_gap_px=round(fgap, 1),
                        foot_centre_dist=round(float(np.hypot(*(cR - cL))), 1)))
    return out
if __name__ == '__main__':
    for F in (sys.argv[1] if len(sys.argv) > 1 else 'SE'):
        r = measure(F)
        print(F, 'overlap', [q['boot_overlap_px'] for q in r], 'foot_ov', [q['foot_overlap_px'] for q in r], 'footgap', [q['foot_gap_px'] for q in r], 'dist', [q['foot_centre_dist'] for q in r])
