"""State-transition measurements (pivot-aligned): idle f0 -> action f0 and action last -> idle f0.
sole = lowest-row jump, fx = check_chars feet-centre jump, foot = planted-boot move (RGB-tracked boot blob, best match),
head = head/torso offset (RGB template of the 'from' frame's top 34 rows)."""
import sys, json, numpy as np
sys.path.insert(0, '.'); from m32 import *; from track import blobs, blob_track
def head_off(idle, b):
    """head/torso offset of frame b vs idle f0: RGB template = idle top 26 rows, helmet core columns (bbox x +8..-8), search +-12"""
    bb = bbox(idle); m = idle[bb[1]:bb[1]+26, :, 3] > 127; xs = np.where(m.any(0))[0]
    r = match(template(idle, (bb[1], bb[1]+26)), b, r=12, cols=(xs.min()+8, xs.max()-8)); return (int(r[0]), int(r[1])), round(float(r[2]), 1)
def pair(a, b, idle=None, ret=False):
    sa, fa = feet(a); sb, fb = feet(b)
    best = None
    for ys, xs in blobs(a):
        dx, dy, e = blob_track(a, b, ys, xs)
        if best is None or e < best[2]: best = (dx, dy, round(float(e), 1))
    if ret: (hx, hy), he = head_off(b, a); hd = (-hx, -hy)     # last frame -> idle: minus the offset of the last frame vs idle
    else: hd, he = head_off(a, b)
    return dict(sole=int(sb - sa), fx=round(float(fb - fa), 1), foot=best[:2], foot_err=best[2], head=hd, head_err=he)
def run(root):
    out = {}
    for fc in "SWNE":
        idle = load(root, "idle", fc, 0)
        for st in ("walk", "attack", "hit", "death"):
            out[f"{fc} idle->{st}_f00"] = pair(idle, load(root, st, fc, 0))
            if st != "death":
                out[f"{fc} {st}_f{N[st]-1:02d}->idle"] = pair(load(root, st, fc, N[st]-1), idle, ret=True)
    return out
if __name__ == "__main__":
    r = run(sys.argv[1]); json.dump(r, open(sys.argv[2], "w"), indent=1)
    for k, v in r.items(): print(f"{k:24s} sole {v['sole']:+3d} fx {v['fx']:+6.1f} foot {v['foot']} e{v['foot_err']:<5} head {v['head']} e{v['head_err']}")
