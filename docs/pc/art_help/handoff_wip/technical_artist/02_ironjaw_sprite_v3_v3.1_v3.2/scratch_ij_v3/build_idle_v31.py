#!/usr/bin/env python3
"""Ironjaw v3.1: new idle S (and W = file flip) whose legs are walk S f00's stride.
Composite per frame: rows above a hand-placed seam curve S(x) = the v3.0 idle S frame (upper body, axes, cape, breathing);
rows at/below S(x) = walk S f00 (legs, tabard, cape hem), plus walk pixels where idle was transparent inside the hip box
(walk thigh seen through the axe-blade notch), plus 19 hand-picked idle pixels (axe horn tip + its underside shade) kept
over the seam. Pure pixel selection at integer offset (0,0): no resampling, no new colours, alpha 0/255 only.
Sources are read from /workspace/scratch/ij_v3/idle_prev (v3.0 idle) and the v3 walk folder."""
import sys, numpy as np
from PIL import Image
sys.path.insert(0, "/workspace/scratch/ij_v3")
from idle_fix_comp import build
V3 = "/workspace/art/ironjaw_full/v3"; PREV = "/workspace/scratch/ij_v3/idle_prev"
walk0 = np.array(Image.open(f"{V3}/walk/ironjaw_walk_S_f00.png").convert("RGBA"))
S, W = [], []
for i in range(4):
    idle = np.array(Image.open(f"{PREV}/ironjaw_idle_S_f{i:02d}.png").convert("RGBA"))
    o = build(idle, walk0); assert set(np.unique(o[..., 3])) <= {0, 255}; assert o[o[..., 3] == 0].max() == 0
    S.append(o); W.append(o[:, ::-1].copy())
# legs planted: rows >= 73 identical across the 4 frames; breathing = rows <= 72 shifted down 1 in f1/f2 (as v3.0)
for i in range(4): assert (S[i][73:] == S[0][73:]).all()
assert (S[1][1:73] == S[0][0:72]).all() and (S[3] == S[0]).all() and (S[2] == S[1]).all()
for fc, fr in (("S", S), ("W", W)):
    for i, a in enumerate(fr):
        Image.fromarray(a, "RGBA").save(f"{V3}/idle/ironjaw_idle_{fc}_f{i:02d}.png", optimize=True)
    Image.fromarray(np.concatenate(fr, 1), "RGBA").save(f"{V3}/idle/ironjaw_idle_{fc}_strip.png", optimize=True)
# report pixel provenance for f0
idle0 = np.array(Image.open(f"{PREV}/ironjaw_idle_S_f00.png").convert("RGBA"))
op = S[0][..., 3] > 0
same_idle = op & (S[0] == idle0).all(-1); same_walk = op & (S[0] == walk0).all(-1)
print("f0 opaque", op.sum(), "from idle", (same_idle).sum(), "from walk only", (same_walk & ~same_idle).sum(),
      "neither (should be 0)", (op & ~same_idle & ~same_walk).sum())
