"""Walk planting / bob analysis. T = travel per frame along the drawn 2:1 diagonal = 89.2/12 cell px.
Planted boot = tracked boot blob (RGB match, frame i -> i+1) whose motion is closest to -T; slide = d + T (0 = stuck).
Head = RGB template of walk f00 head rows (top 26 rows of bbox), dy per frame. Placement test per frame i:
o_foot = (d(i-1->i) - d(i->i+1))/2 and o_head = (h_i - (h_{i-1}+h_{i+1})/2); placement if both agree (same sign/size >= 2 px)."""
import sys, json, numpy as np
sys.path.insert(0, '.'); from m32 import *; from track import blobs, blob_track
TL = 89.2/12; U = np.array([2, 1])/np.sqrt(5)
DIRS = {"S": (1, 1), "W": (-1, 1), "N": (-1, -1), "E": (1, -1)}   # screen travel direction signs
def analyse(root, fc):
    T = TL*U*np.array(DIRS[fc]); fr = [load(root, "walk", fc, i) for i in range(12)]
    ref = fr[0]; b = bbox(ref); tpl = template(ref, (b[1], b[1]+26))
    heads = [match(tpl, a, r=12)[:2] for a in fr]
    rows = []
    for i in range(12):
        a, c = fr[i], fr[(i+1) % 12]; cands = []
        for ys, xs in blobs(a):
            dx, dy, e = blob_track(a, c, ys, xs)
            cands.append((float(np.hypot(dx+T[0], dy+T[1])), dx, dy, e, int(xs.mean())))
        cands.sort(); d = cands[0]
        rows.append(dict(pair=f"f{i:02d}->f{(i+1)%12:02d}", foot=(d[1], d[2]), err=round(float(d[3]), 1), slide=(round(d[1]+T[0], 1), round(d[2]+T[1], 1)),
                         slide_len=round(d[0], 1), boot_x=d[4]))
    hy = np.array([h[1] for h in heads], float); hx = np.array([h[0] for h in heads], float)
    place = []
    for i in range(12):
        p, n = rows[(i-1) % 12], rows[i]
        of = ((p["foot"][0]-n["foot"][0])/2, (p["foot"][1]-n["foot"][1])/2)
        oh = (hx[i]-(hx[i-1]+hx[(i+1) % 12])/2, hy[i]-(hy[i-1]+hy[(i+1) % 12])/2)
        place.append(dict(frame=i, o_foot=of, o_head=oh))
    return dict(T=[round(T[0], 2), round(T[1], 2)], heads=heads, steps=rows, placement_test=place,
                bob_range=int(hy.max()-hy.min()), bob_max_step=int(np.abs(np.diff(np.r_[hy, hy[0]])).max()))
if __name__ == "__main__":
    out = {fc: analyse(sys.argv[1], fc) for fc in sys.argv[2]}
    json.dump(out, open(sys.argv[3], "w"), indent=1, default=lambda o: o.tolist() if hasattr(o, 'tolist') else int(o))
    for fc, r in out.items():
        print("==", fc, "T", r["T"], "head x,y per frame", r["heads"], "bob range", r["bob_range"], "max step", r["bob_max_step"])
        for s, p in zip(r["steps"], r["placement_test"]):
            print(f"  {s['pair']} foot {s['foot']} e{s['err']:<5} slide {s['slide']} |{s['slide_len']}|  f{p['frame']:02d} o_foot {p['o_foot']} o_head {p['o_head']}")
