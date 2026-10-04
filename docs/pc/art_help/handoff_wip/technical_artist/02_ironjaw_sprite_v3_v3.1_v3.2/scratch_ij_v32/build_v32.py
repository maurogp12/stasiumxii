#!/usr/bin/env python3
"""Ironjaw v3.2 build (from a fresh copy of v3 = v3.1 at /workspace/art/ironjaw_full/v3.2).
Fix 1 (N/E idle -> walk feet): walk E is re-phased so the cycle starts on the frame whose planted boot sits exactly on the
idle/attack/hit/death stance boot: v3.2 walk E fNN = v3.1 walk E f((NN+3) mod 12) (byte copy of the frame file, no pixel change);
walk N = exact file flip of the new walk E. Strips rebuilt. Nothing else in the set is touched.
(Fixes 2/3: measured, no placement offsets found -> no frame moved. See README v3.2.)"""
import shutil, numpy as np
from PIL import Image
V3 = "/workspace/art/ironjaw_full/v3"; V32 = "/workspace/art/ironjaw_full/v3.2"; ROT = 3
for i in range(12):
    shutil.copyfile(f"{V3}/walk/ironjaw_walk_E_f{(i+ROT) % 12:02d}.png", f"{V32}/walk/ironjaw_walk_E_f{i:02d}.png")
E = [np.array(Image.open(f"{V32}/walk/ironjaw_walk_E_f{i:02d}.png").convert("RGBA")) for i in range(12)]
Nn = []
for i, a in enumerate(E):
    assert set(np.unique(a[..., 3])) <= {0, 255} and a[a[..., 3] == 0].max() == 0
    n = a[:, ::-1].copy(); Nn.append(n)
    Image.fromarray(n, "RGBA").save(f"{V32}/walk/ironjaw_walk_N_f{i:02d}.png", optimize=True)
    # the new N frame must equal the v3.1 N frame of the same source index (v3.1 N was already the exact flip of v3.1 E)
    old = np.array(Image.open(f"{V3}/walk/ironjaw_walk_N_f{(i+ROT) % 12:02d}.png").convert("RGBA"))
    assert (old == n).all(), i
for fc, fr in (("E", E), ("N", Nn)):
    Image.fromarray(np.concatenate(fr, 1), "RGBA").save(f"{V32}/walk/ironjaw_walk_{fc}_strip.png", optimize=True)
print("walk E/N re-phased by", ROT, "; N == v3.1 N pixels (rotated), flips exact")
