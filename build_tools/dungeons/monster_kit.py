"""Shared monster builder for the painted-part rigs (mrig.py): renders every action and
facing of one monster spec into <OUT>/[star5/]monsters/<id>/ and writes its meta.json.

A spec is a dict:
  name, rig(f) -> mrig.Facing, actions(f) -> {action: [pose, ...]}, cell, pivot
  optional: base {facing: pose-offsets}, release (attack frame; the rig has .pocket = (part, xy)),
            star5, glow (True), glow_fn(im, big) -> additive RGBA, base_of,
            signature {...} (copied into meta.json as is)
The Granary specs live in granary_monsters.py, the Frostspire ones in frostspire_monsters.py.
"""
from __future__ import annotations

import math
import os

import numpy as np

import gkit
import mrig

FPS = 17.144
CELL = (512, 360)
PIV = (256, 329)
CELL_BIG = (768, 540)
PIV_BIG = (384, 494)
LOOPS = {"idle": True, "walk": True, "attack": False, "hit": False, "death": False, "summon": False}

FWD = {"S": (math.cos(math.atan2(0.5, 1)), math.sin(math.atan2(0.5, 1))),
       "E": (math.cos(math.atan2(-0.5, 1)), math.sin(math.atan2(-0.5, 1)))}


def fwd(f, d):
    return {"dx": FWD[f][0] * d, "dy": FWD[f][1] * d}


def cyc(n, fn):
    return [fn(i / float(n)) for i in range(n)]


def keep_in(rig, poses):
    """Lift/shift a pose sequence smoothly so every frame stays inside the cell.

    Pass 1 measures the per-frame shift the renderer would need; the shift is
    widened (+-2 frames), smoothed, and added to the poses' dx/dy, so the
    correction eases in and out instead of popping.
    """
    need = []
    for p in poses:
        rig.render(p)
        need.append(rig.last_shift)
    if not any(abs(a) > 0.01 or abs(b) > 0.01 for a, b in need):
        return poses
    n = len(poses)
    out = []
    env = []
    for i in range(n):
        w = need[max(0, i - 2):i + 3]
        env.append((max(w, key=lambda t: abs(t[0]))[0], max(w, key=lambda t: abs(t[1]))[1]))
    for i in range(n):
        w = env[max(0, i - 1):i + 2]
        ex = sum(t[0] for t in w) / len(w)
        ey = sum(t[1] for t in w) / len(w)
        q = dict(poses[i])
        q["dx"] = q.get("dx", 0.0) + ex * 1.05
        q["dy"] = q.get("dy", 0.0) + ey * 1.05
        out.append(q)
    return out


def glow_from_mask(im, em_weight, big, col, core=(4, 1.4), halo=(14, 1.2), aura=(16, 0.10)):
    """Additive light map for one frame: the emissive weight map bloomed, plus a faint aura."""
    import cv2
    a = im[..., 3] > 0
    k = 1.5 if big else 1.0
    glow = cv2.GaussianBlur(em_weight, (0, 0), core[0] * k) * core[1] + cv2.GaussianBlur(em_weight, (0, 0), halo[0] * k) * halo[1]
    glow += cv2.GaussianBlur(a.astype(np.float32), (0, 0), aura[0] * k) * aura[1]
    glow = np.clip(glow, 0, 1)
    g8 = np.clip(glow[..., None] * np.array(col, np.float32) * 255 + 0.5, 0, 255).astype(np.uint8)
    on = g8.max(-1) >= 3
    out = np.zeros(im.shape, np.uint8)
    out[..., :3] = np.where(on[..., None], g8, 0)
    out[..., 3] = np.where(on, 255, 0)
    return out


def glow_green(im, big):
    """The Granary's radioactive glow: the green emissive paint, bloomed, plus a faint green aura."""
    a = im[..., 3] > 0
    r, g, b = [im[..., i].astype(np.float32) for i in range(3)]
    em = a & (g > r + 30) & (g > b + 50) & (g > 110)
    e = em.astype(np.float32) * np.clip((g - 110) / 120.0, 0.3, 1.0)
    return glow_from_mask(im, e, big, (0.55, 1.0, 0.18))


def build(mid, spec, check=False):
    star5 = spec.get("star5", False)
    root = os.path.join(gkit.OUT, "star5", "monsters") if star5 else os.path.join(gkit.OUT, "monsters")
    rel_root = "star5/monsters" if star5 else "monsters"
    mdir = os.path.join(root, mid)
    meta = {"id": mid, "name": spec["name"], "star5": star5, "base_of": spec.get("base_of"), "dir": rel_root + "/" + mid, "cell": list(spec["cell"]), "pivot": list(spec["pivot"]), "fps": FPS,
            "facings": ["S", "E"], "mirror": {"W": "E", "N": "S"}, "actions": {}, "qa": {}}
    if spec.get("role"):
        meta["role"] = spec["role"]
    if spec.get("signature"):
        meta["signature"] = spec["signature"]
    glow_fn = spec.get("glow_fn", glow_green)
    for f in ("S", "E"):
        rig = spec["rig"](f)
        acts = spec["actions"](f)
        meta["qa"]["hole_fill_px_" + f] = rig.hole_px
        base = spec.get("base", {}).get(f, {})
        for act, poses in acts.items():
            poses = mrig.add([dict(p) for p in poses], [base] * len(poses))
            if check and act not in ("idle", "attack", "death"):
                continue
            for _ in range(3):
                poses = keep_in(rig, poses)
            lost_max = 0
            shift_max = 0.0
            for i, pose in enumerate(poses):
                im, lost = rig.render(pose)
                if act == "attack" and spec.get("release") == i:
                    px, py = rig.point(pose, *rig.pocket)
                    meta.setdefault("release", {"action": "attack", "frame": i, "point_px": {}})["point_px"][f] = [round(px + rig.last_shift[0], 1), round(py + rig.last_shift[1], 1)]
                lost_max = max(lost_max, lost)
                shift_max = max(shift_max, abs(rig.last_shift[0]), abs(rig.last_shift[1]))
                path = os.path.join(mdir, act, "%s_%s_f%02d.png" % (act, f, i))
                gkit.save_png(path, im)
                if spec.get("glow"):
                    gkit.save_png(os.path.join(mdir, act, "%s_%s_f%02d_glow.png" % (act, f, i)), glow_fn(im, spec["cell"] == CELL_BIG))
            a = meta["actions"].setdefault(act, {"frames": len(poses), "loop": LOOPS[act], "files": {}})
            a["files"][f] = "%s/%s/%s/%s_%s_fNN.png" % (rel_root, mid, act, act, f)
            if spec.get("glow"):
                a.setdefault("glow_files", {})[f] = "%s/%s/%s/%s_%s_fNN_glow.png" % (rel_root, mid, act, act, f)
            meta["qa"]["px_outside_cell_%s_%s" % (act, f)] = lost_max
            meta["qa"]["keep_in_shift_px_%s_%s" % (act, f)] = round(shift_max, 1)
            print(mid, f, act, len(poses), "outside", lost_max, "keep-in shift", round(shift_max, 1), flush=True)
    gkit.write_json(os.path.join(mdir, "meta.json"), meta)
    return meta
