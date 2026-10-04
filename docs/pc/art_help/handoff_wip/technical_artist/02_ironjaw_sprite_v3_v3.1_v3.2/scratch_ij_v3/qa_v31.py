#!/usr/bin/env python3
"""qa.json for Ironjaw v3.1 (v3 + new idle S/W stance; idle S/W isolated_light recomputed, see notes).
qa.json for Ironjaw v3 (same schema as v2). Recomputed: size, semi, near_white, cyan, edge_touch.
isolated_light: carried per frame from v2 qa.json (v3 pixels are byte-identical to v2, only translated; the 3x3 test is
translation-invariant). light_fixed: 0 (v3 applied no light fixes; v2 had 666)."""
import json, glob, os, colorsys, numpy as np
from PIL import Image
V2 = "/workspace/art/ironjaw_full/v2"; V3 = "/workspace/art/ironjaw_full/v3"
q2 = json.load(open(f"{V2}/qa.json"))
per = {}; sizes = set(); tot = dict(semi=0, near_white=0, cyan=0, isolated_light=0, light_fixed=0); edge = {}
order = list(q2["per_frame"])
import itertools
def iso_count(a):
    """explicit test: opaque px with luma >= 120 that is >= 40 brighter than every opaque 8-neighbour"""
    a = a.astype(float); L = 0.299*a[..., 0] + 0.587*a[..., 1] + 0.114*a[..., 2]; op = a[..., 3] > 0
    P = np.pad(np.where(op, L, -1), 1, constant_values=-1); h, w = L.shape
    mx = np.max([P[1+dy:1+dy+h, 1+dx:1+dx+w] for dy, dx in itertools.product((-1, 0, 1), repeat=2) if dy or dx], 0)
    return int((op & (L >= 120) & (L - mx >= 40)).sum())
for name in order:
    st = name.split("_")[1]
    a = np.array(Image.open(f"{V3}/{st}/{name}").convert("RGBA")); al = a[..., 3]; op = al > 0
    rgb = a[..., :3].astype(float) / 255
    semi = int(((al > 0) & (al < 255)).sum())
    near_white = int((op & (a[..., :3].min(-1) >= 235)).sum())
    mx = rgb.max(-1); mn = rgb.min(-1); sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.zeros_like(mx); d = np.maximum(mx - mn, 1e-6)
    hue = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    cyan = int((op & (hue > 170) & (hue < 200) & (sat > 0.5) & (mx > 0.5)).sum())
    m = op; e = int(m[0].sum() + m[-1].sum() + m[:, 0].sum() + m[:, -1].sum())
    iso = q2["per_frame"][name]["isolated_light"]
    if name.startswith("ironjaw_idle_S_") or name.startswith("ironjaw_idle_W_"):
        iso = iso_count(a)   # v3.1 frames have new pixel content (walk S f00 legs); v2 value was 0
    per[name] = dict(size=[a.shape[1], a.shape[0]], semi=semi, near_white=near_white, cyan=cyan,
                     isolated_light=iso, light_fixed=0, edge_touch=e)
    sizes.add((a.shape[1], a.shape[0]))
    for k in ("semi", "near_white", "cyan", "isolated_light"): tot[k] += per[name][k]
    if e: edge[name] = e
out = dict(totals=tot, edge_touch=edge, sizes=sorted([list(s) for s in sizes]), per_frame=per,
           notes={"definitions": "semi = 0<alpha<255; near_white = opaque px with min(R,G,B)>=235; cyan = opaque px hue 170-200 deg, sat>0.5, value>0.5; edge_touch = opaque px in the outermost row/column of the cell",
                  "isolated_light": "carried from v2 qa.json per frame (v3 pixels identical to v2, integer translation only; painted metal highlights, none near-white), EXCEPT the 8 v3.1 idle S/W frames: recomputed with the explicit test (opaque, luma >= 120, >= 40 brighter than every opaque 8-neighbour) = 0 (v2 value 0; the same test also gives 0 on the v3.0 idle and on walk S f00)",
                  "v3_1": "idle S/W replaced (stance fix): pixels selected from v3.0 idle S f0-f3 + walk S f00 at offset (0,0), no new colours, no resampling",
                  "light_fixed": "0 in v3 (no pixel edits); v2 total was 666",
                  "min_margin_px": int(min(min(np.where(np.array(Image.open(p))[..., 3] > 0)[0].min(), np.where(np.array(Image.open(p))[..., 3] > 0)[1].min()) for p in glob.glob(f"{V3}/*/*_f??.png"))),
                  "rgb_under_alpha0": "all (0,0,0)"})
# true min margin on all four sides
mm = 10**9
for p in glob.glob(f"{V3}/*/*_f??.png"):
    a = np.array(Image.open(p))[..., 3] > 0; ys, xs = np.where(a)
    mm = min(mm, xs.min(), ys.min(), a.shape[1]-1-xs.max(), a.shape[0]-1-ys.max())
    assert np.array(Image.open(p).convert("RGBA"))[~a][:, :3].max() == 0
out["notes"]["min_margin_px"] = int(mm)
json.dump(out, open(f"{V3}/qa.json", "w"), indent=1)
print(tot, edge, out["sizes"], "min margin", mm, "frames", len(per))
