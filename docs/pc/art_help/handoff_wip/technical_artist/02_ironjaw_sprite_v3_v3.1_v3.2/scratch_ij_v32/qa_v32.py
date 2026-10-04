#!/usr/bin/env python3
"""qa.json for Ironjaw v3.2 (same schema as v2/v3). semi, near_white, cyan, edge_touch recomputed on every v3.2 frame.
isolated_light: carried per frame from the v3.1 qa.json, following the frame's source file (v3.2 walk E/N fNN = v3.1 walk
E/N f(NN+3 mod 12), byte-identical pixels); light_fixed 0 (no pixel edits)."""
import json, glob, os, numpy as np
from PIL import Image
V31 = "/workspace/art/ironjaw_full/v3"; V32 = "/workspace/art/ironjaw_full/v3.2"; ROT = 3
q1 = json.load(open(f"{V31}/qa.json")); per = {}; sizes = set(); edge = {}
tot = dict(semi=0, near_white=0, cyan=0, isolated_light=0, light_fixed=0)
def src(name):
    p = name[:-4].split("_")            # ironjaw_walk_E_f00
    if p[1] == "walk" and p[2] in "EN":
        return f"ironjaw_walk_{p[2]}_f{(int(p[3][1:])+ROT) % 12:02d}.png"
    return name
for name in q1["per_frame"]:
    st = name.split("_")[1]
    a = np.array(Image.open(f"{V32}/{st}/{name}").convert("RGBA")); al = a[..., 3]; op = al > 0
    s = np.array(Image.open(f"{V31}/{st}/{src(name)}").convert("RGBA")); assert (a == s).all(), name   # provenance check
    rgb = a[..., :3].astype(float)/255; mx = rgb.max(-1); mn = rgb.min(-1)
    sat = np.where(mx > 0, (mx-mn)/np.maximum(mx, 1e-6), 0); d = np.maximum(mx-mn, 1e-6); r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(mx == r, ((g-b)/d) % 6, np.where(mx == g, (b-r)/d+2, (r-g)/d+4))*60
    e = int(op[0].sum()+op[-1].sum()+op[:, 0].sum()+op[:, -1].sum())
    per[name] = dict(size=[a.shape[1], a.shape[0]], semi=int(((al > 0) & (al < 255)).sum()),
                     near_white=int((op & (a[..., :3].min(-1) >= 235)).sum()),
                     cyan=int((op & (hue > 170) & (hue < 200) & (sat > 0.5) & (mx > 0.5)).sum()),
                     isolated_light=q1["per_frame"][src(name)]["isolated_light"], light_fixed=0, edge_touch=e)
    sizes.add((a.shape[1], a.shape[0]))
    for k in ("semi", "near_white", "cyan", "isolated_light"): tot[k] += per[name][k]
    if e: edge[name] = e
mm = 10**9; alph = set()
for p in glob.glob(f"{V32}/*/*_f??.png"):
    A = np.array(Image.open(p).convert("RGBA")); m = A[..., 3] > 0; ys, xs = np.where(m)
    mm = min(mm, xs.min(), ys.min(), m.shape[1]-1-xs.max(), m.shape[0]-1-ys.max())
    assert A[~m][:, :3].max() == 0; alph |= set(np.unique(A[..., 3]).tolist())
notes = dict(q1["notes"])
notes["isolated_light"] = "carried per frame from the v3.1 qa.json following each frame's source file (v3.2 pixels are byte-identical copies; v3.1 itself carried v2 values except the 8 v3.1 idle S/W frames, recomputed with the explicit 3x3 test = 0)"
notes["v3_2"] = "movement fix: walk E fNN = v3.1 walk E f(NN+3 mod 12), walk N = exact flip of the new walk E (= v3.1 walk N rotated the same way). No pixel edits, no frame moved inside its cell. All other frames byte-identical to v3.1."
notes["min_margin_px"] = int(mm); notes["alpha_values"] = sorted(alph); notes["rgb_under_alpha0"] = "all (0,0,0)"
out = dict(totals=tot, edge_touch=edge, sizes=sorted([list(s) for s in sizes]), per_frame=per, notes=notes)
json.dump(out, open(f"{V32}/qa.json", "w"), indent=1)
print(tot, edge, out["sizes"], "min margin", mm, "alpha", sorted(alph), "frames", len(per))
