#!/usr/bin/env python3
"""Ironjaw v3 = v2 + technical fixes only (integer padding, pivot, mirrors). No pixel of the art is changed.
v2 is read-only. Output /workspace/art/ironjaw_full/v3/<state>/..."""
import os, json, numpy as np
from PIL import Image
V2 = "/workspace/art/ironjaw_full/v2"; V3 = "/workspace/art/ironjaw_full/v3"
STATES = {"walk": 12, "idle": 4, "attack": 6, "hit": 4, "death": 6}
# old cell, old pivot x, old feet row (sole) -> new cell, shift
OLD = {s: ((161, 155), 78) for s in ("walk", "idle", "attack", "hit")}; OLD["death"] = ((205, 178), 102)
FEET_Y_OLD = 138          # measured sole row of idle S/W (+5 vs 133); N/E sole 137 (+4)
MARGIN = 4
def load(p): return np.array(Image.open(p).convert("RGBA"))

def plan():
    groups = {"A": ["walk", "idle", "attack", "hit"], "D": ["death"]}
    P = {}
    for g, sts in groups.items():
        (w, h), px = OLD[sts[0]]
        x0 = y0 = 10**9; x1 = y1 = -1
        for st in sts:
            for fc in "SWNE":
                for i in range(STATES[st]):
                    ys, xs = np.where(load(f"{V2}/{st}/ironjaw_{st}_{fc}_f{i:02d}.png")[..., 3] > 0)
                    x0, x1, y0, y1 = min(x0, xs.min()), max(x1, xs.max()), min(y0, ys.min()), max(y1, ys.max())
        hw = max(px - x0, x1 - px) + MARGIN           # centred pivot x -> W = plain fliplr(S)
        nw = 2*hw + 1; dx = hw - px
        dy = max(0, MARGIN - y0)                      # rows added on top
        nh = max(h + dy, y1 + dy + 1 + MARGIN)        # rows added at the bottom only if needed
        for st in sts:
            P[st] = dict(old_cell=[w, h], old_pivot=[px, 133], cell=[int(nw), int(nh)], shift=[int(dx), int(dy)],
                         pivot=[int(hw), int(FEET_Y_OLD + dy)], content_bbox_old=[int(x0), int(y0), int(x1), int(y1)])
    return P

def pad(a, cell, shift):
    out = np.zeros((cell[1], cell[0], 4), np.uint8)
    h, w = a.shape[:2]; out[shift[1]:shift[1]+h, shift[0]:shift[0]+w] = a
    return out

def main():
    P = plan()
    for st, n in STATES.items():
        os.makedirs(f"{V3}/{st}", exist_ok=True)
        p = P[st]; fr = {}
        for fc in ("S", "E"):
            fr[fc] = [pad(load(f"{V2}/{st}/ironjaw_{st}_{fc}_f{i:02d}.png"), p["cell"], p["shift"]) for i in range(n)]
        fr["W"] = [np.ascontiguousarray(a[:, ::-1]) for a in fr["S"]]   # exact mirror about centred pivot
        fr["N"] = [np.ascontiguousarray(a[:, ::-1]) for a in fr["E"]]
        for fc in "SWNE":
            for i, a in enumerate(fr[fc]):
                # identical to the padded v2 frame (v2 W/N were already exact flips about x=78 / 102)
                ref = pad(load(f"{V2}/{st}/ironjaw_{st}_{fc}_f{i:02d}.png"), p["cell"], p["shift"])
                assert np.array_equal(a, ref), (st, fc, i)
                assert set(np.unique(a[..., 3])) <= {0, 255}
                assert a[a[..., 3] == 0][:, :3].max() == 0
                m = a[..., 3] > 0; ys, xs = np.where(m)
                assert xs.min() >= MARGIN and ys.min() >= MARGIN and xs.max() <= a.shape[1]-1-MARGIN and ys.max() <= a.shape[0]-1-MARGIN, (st, fc, i)
                Image.fromarray(a, "RGBA").save(f"{V3}/{st}/ironjaw_{st}_{fc}_f{i:02d}.png", optimize=True)
            Image.fromarray(np.concatenate(fr[fc], 1), "RGBA").save(f"{V3}/{st}/ironjaw_{st}_{fc}_strip.png", optimize=True)
    json.dump(P, open(f"{V3}/_cells_pivots.json", "w"), indent=1)
    print(json.dumps(P, indent=1))

if __name__ == "__main__":
    main()
