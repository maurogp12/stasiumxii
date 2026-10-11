#!/usr/bin/env python3
"""Visible gear (paper doll), step 2: pose the parts through the locked rig.

The locked Ironjaw action rig (`ijrig.py`, claude/ironjaw-actions 9d784a1, the
dark-steel v7 actions with the aimfix blockout) is imported unchanged and fed
the parts gear_cut.py wrote. Every frame is posed ONCE (torso, head, cape,
arms, legs: the locked numbers, so the base moves exactly like the locked
actions), then drawn several times:

  base           every base part in the rig's draw order -> the body strip.
  <look>         the look's parts in their rig slots, with every base part
                 that the rig draws ABOVE that slot erasing them ("over"
                 strip, drawn above the body in game). A belt behind the S
                 near arm is cut where the arm covers it, frame by frame.
  <look>__back   a look's cape mesh in a facing where the rig draws the cape
                 below everything (S): drawn raw, and the game draws it
                 BEHIND the body ("back" strip).

So every strip has the same cells, pivot and frame count as the body and the
game only stacks them. Kinds: the locked idle, attack, skill, hit, death, plus
walk, which is the same rig driven by the TA walk joints (the joints the
locked v7 walk was painted on), mapped onto the blockout's idle per joint.

Frames: 512x360, pivot (256,329), 17.144 fps, binary alpha, written to
<work>/frames/<strip>/<kind>_<F>_fNN.png.

usage: gear_rig.py [--work DIR] [--looks base,quarryhand_head,...] [--acts walk,idle,...]
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gear_cut as GC  # noqa: E402

KINDS = ("walk", "idle", "attack", "skill", "hit", "death")


def load_rig(work: str):
    tree = GC.locked_tree(work)
    base = os.path.join(tree, GC.LOCK_DIR)
    os.environ["IJPARTS"] = os.path.join(base, "parts")
    os.environ["IJBLOCK"] = os.path.join(base, "blockout")
    spec = importlib.util.spec_from_file_location("ijrig_locked", os.path.join(base, "scripts", "ijrig.py"))
    R = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(R)
    # The body placement keeps the locked helm-top fit (head_top_t reads the
    # locked helm), so the unarmoured body stands where the v7 body stood.
    for F in "SE":
        R.head_top_t(F)
    add_walk(R, tree)
    return R


def add_walk(R, tree):
    """walk_S / walk_E in the blockout format from the TA walk joints: each
    joint is the TA walk joint moved by (blockout idle - TA idle) for that joint,
    so idle-relative motion is the TA walk's and the feet land on the TA feet
    (the rig adds TA idle - blockout idle back to the feet)."""
    ta = json.load(open(os.path.join(tree, GC.WALK_DIR, "joints_512.json")))["facings"]
    names = ("pelvis", "neck", "head_top")
    side = ("shoulder", "elbow", "hand", "hip", "knee", "ankle", "heel", "toe")
    for F in "SE":
        bo0 = R.JF[f"idle_{F}"]["f00"]
        ti = ta[f"idle_{F}"]["joints"] if "joints" in ta[f"idle_{F}"] else ta[f"idle_{F}"]["f00"]["joints"]
        out = {}
        for i in range(12):
            tw = ta[f"walk_{F}"][f"f{i:02d}"]
            j = {}
            for k in list(names) + [f"{sd}_{s}" for sd in "RL" for s in side]:
                tk = k.replace("_hand", "_axe_grip")
                j[k] = (np.array(tw["joints"][tk], float) - np.array(ti[tk], float) + np.array(bo0["joints"][k], float)).tolist()
            depth = dict(bo0["depth"])
            order = tw.get("draw_order", [])
            for sd in "RL":
                pos = order.index(f"{sd}_shin") if f"{sd}_shin" in order else 0
                depth[f"{sd}_shin"] = 2000.0 - 10.0 * pos
                depth[f"{sd}_boot"] = 2000.0 - 10.0 * pos
            out[f"f{i:02d}"] = {"joints": j, "key": bo0["key"], "depth": depth}
        R.JF[f"walk_{F}"] = out
    R.ACTS["walk"] = 12
    R.LOOP.add("walk")


class PartSet:
    """One parts folder (base or a look). Missing parts are empty."""

    def __init__(self, R, d):
        self.R = R
        self.d = d
        self.tex = {}
        self.mesh = {}

    def has(self, name):
        p = f"{self.d}/{name}.png"
        if not os.path.exists(p):
            return False
        return bool((np.asarray(Image.open(p))[..., 3] > 127).any())

    def ptex(self, name):
        if name not in self.tex:
            R = self.R
            p = f"{self.d}/{name}.png"
            if os.path.exists(p):
                im = np.asarray(Image.open(p).convert("RGBA")).astype(np.float32)
            else:
                im = np.zeros((4, 4, 4), np.float32)
            s = R.CFG[name[-1]]["s"]
            a = im[..., 3:4] / 255.0
            pm = np.concatenate([im[..., :3] * a, a * 255.0], -1)
            h, w = im.shape[:2]
            nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
            out = np.stack([np.asarray(Image.fromarray(pm[..., c], "F").resize((nw, nh), Image.LANCZOS)) for c in range(4)], -1) / 255.0
            self.tex[name] = (np.clip(out, 0, 1).astype(np.float32), (nw / w, nh / h))
        return self.tex[name]

    def cape_mesh(self, F):
        if F not in self.mesh:
            p = f"{self.d}/cape_{F}.png"
            al = np.asarray(Image.open(p))[..., 3].astype(np.float32) / 255.0 if os.path.exists(p) else np.zeros(GC.SH, np.float32)
            if not (al > 0.01).any():
                self.mesh[F] = None
            else:
                R = self.R
                V, tris = R.grid_mesh(al, 6)
                wc = np.asarray(Image.open(f"{self.d}/wcape_{F}.png").convert("RGB")).astype(np.float32) / 255.0
                xi = np.clip(V[:, 0].astype(int), 0, 1279)
                yi = np.clip(V[:, 1].astype(int), 0, 719)
                wu, wl = wc[yi, xi, 0], wc[yi, xi, 1]
                W = np.stack([np.clip(1 - wu - wl, 0, 1), wu, wl], 1)
                W /= W.sum(1, keepdims=True)
                self.mesh[F] = (V, tris, W)
        return self.mesh[F]


def use_set(R, ps: PartSet):
    R.ptex = ps.ptex
    R.TEX = ps.tex


class Poser:
    """Poses a frame once; draws any part set through it."""

    def __init__(self, R, base: PartSet):
        self.R = R
        self.base = base
        use_set(R, base)

    def pose(self, F, act, i):
        R = self.R
        c = R.CFG[F]
        use_set(R, self.base)
        Mt, tinfo = R.torso_M(F, act, i)
        Mh, hdeg = R.head_M(F, act, i, Mt)
        au, al_ = R.CAPE.setdefault((F, act), R.cape_angles(F, act))
        au, al_ = au[i], al_[i]
        PJF = R.PJ[F]
        pu = R.apm(Mt, PJF["cape_upper"])
        hinge_t = (PJF["cape_upper"][0], sum(PJF["cape_lower_y"]) / 2)
        Mu = R.rot_about(Mt, pu, au)
        Ml = R.rot_about(Mu, R.apm(Mu, hinge_t), al_)
        if act == "death":
            fold = R.lie_w(math.radians(tinfo["phi"]))
            dn = R.unit(R.jt(F, act, i, "pelvis") - R.jt(F, act, i, "neck"))
            kk = 1 - (1 - c["cape_lie_k"]) * fold
            Mu = R.squash_about(Mu, pu, dn, kk)
            Ml = R.squash_about(Ml, pu, dn, kk)
        legs = {sd: R.leg_pose(F, act, i, sd, Mt) for sd in "RL"}
        dl = {sd: R.depth(F, act, i, f"{sd}_shin") + R.depth(F, act, i, f"{sd}_boot") for sd in "RL"}
        lorder = sorted("RL", key=lambda sd: -dl[sd])
        arms = {sd: R.arm_pose(F, act, i, sd, Mt) for sd in "RL"}
        front = {sd: R.arm_front(F, act, i, sd) for sd in "RL"}
        raised = {sd: front[sd] and arms[sd]["grip"][1] < arms[sd]["sh"][1] - 10 for sd in "RL"}
        # the rig's draw order (ijrig.render), as named slots
        order = []
        if not c["cape_front"]:
            order.append("cape")
        for sd in "RL":
            if not front[sd]:
                order += [f"uarm_{sd}", f"fore_{sd}", f"pauld_{sd}"]
        for sd in lorder:
            order += [f"leg_{sd}_boot", f"leg_{sd}_shin", f"leg_{sd}_thigh"]
        order.append("body")
        if c["cape_front"]:
            order.append("cape")
        for sd in "RL":
            if raised[sd]:
                order += [f"uarm_{sd}", f"fore_{sd}"]
        order.append("head")
        for sd in sorted("RL", key=lambda x: -(R.depth(F, act, i, f"{x}_farm"))):
            if front[sd]:
                order += ([] if raised[sd] else [f"uarm_{sd}", f"fore_{sd}"]) + [f"pauld_{sd}"]
        M = {"body": Mt, "head": Mh}
        for sd in "RL":
            M[f"uarm_{sd}"] = arms[sd]["Mu"]
            M[f"fore_{sd}"] = arms[sd]["Mf"]
            M[f"pauld_{sd}"] = Mt
            M[f"leg_{sd}_boot"] = legs[sd]["Mb"]
            M[f"leg_{sd}_shin"] = legs[sd]["Msh"]
            M[f"leg_{sd}_thigh"] = legs[sd]["Mth"]
        return {"F": F, "order": order, "M": M, "cape": (Mt, Mu, Ml)}

    def draw(self, pose, ps: PartSet, cv):
        """{slot: premultiplied image} for the slots this set has."""
        R = self.R
        F = pose["F"]
        use_set(R, ps)
        out = {}
        for slot in pose["order"]:
            if slot == "cape":
                mesh = ps.cape_mesh(F)
                if mesh is None:
                    continue
                V, tris, W = mesh
                Vd = R.lbs(V, W, pose["cape"])
                out[slot] = R.warp(ps.ptex(f"cape_{F}")[0], R.src_px(f"cape_{F}", V), cv.pts(Vd), tris, cv.H, cv.W)
                continue
            name = f"{slot}_{F}"
            if not ps.has(name):
                continue
            out[slot] = cv.affine(name, pose["M"][slot])
        use_set(R, self.base)
        return out


def composite(R, order, imgs, shape):
    img = np.zeros(shape, np.float32)
    for s in order:
        if s in imgs:
            img = R.over(img, imgs[s])
    return img


STACK = json.load(open(GC.DATA))["stack"]


def group_slot(name: str) -> str:
    return name.rsplit("_", 1)[1]


def strip_images(R, F, order, imgs, base_groups, slot):
    """(back, over) for one group strip.

    back: the group's parts the rig draws before the legs (the far arm in S),
    raw; the game draws it behind every other strip.
    over: the rest, in rig order; a part of a group stacked BELOW this one in
    the game but drawn later by the rig erases it (by the base silhouette of
    that group's part), e.g. the near leg over the far boot, the front arm's
    sleeve over the head."""
    stack = STACK[F]
    me = stack.index(slot)
    legs_at = min([i for i, s in enumerate(order) if s.startswith("leg_")] or [len(order)])
    shape = None
    for v in list(imgs.values()) + [x for g in base_groups.values() for x in g.values()]:
        shape = v.shape
        break
    back = np.zeros(shape, np.float32)
    over = np.zeros(shape, np.float32)
    for i, s in enumerate(order):
        if i >= legs_at and over[..., 3].any():
            for g, gi in base_groups.items():
                if stack.index(g) < me and s in gi:
                    over = over * (1.0 - gi[s][..., 3:4])
        if s in imgs:
            if i < legs_at:
                back = R.over(back, imgs[s])
            else:
                over = R.over(over, imgs[s])
    return back, over


def render_all(work: str, strips_wanted, acts):
    R = load_rig(work)
    parts = os.path.join(work, "parts")
    base = PartSet(R, os.path.join(parts, "base"))
    for F in "SE":
        R.PJ[F] = json.load(open(os.path.join(parts, "base", f"ijoints_{F}.json")))
    R.AP = os.path.join(parts, "base")      # the forearm hulls (edge turn) of the base
    poser = Poser(R, base)
    groups = sorted(d for d in os.listdir(parts) if d != "base" and os.path.isdir(os.path.join(parts, d)))
    if strips_wanted:
        groups = [g for g in groups if g in strips_wanted or g.startswith("base_")]
    sets = {g: PartSet(R, os.path.join(parts, g)) for g in groups}
    frames_root = os.path.join(work, "frames")
    stats = {}
    for F in "SE":
        for act in acts:
            n = R.ACTS[act]
            poses = [poser.pose(F, act, i) for i in range(n)]
            cv = R.Canvas(1)
            shape = (cv.H, cv.W, 4)
            base_full = [composite(R, p["order"], poser.draw(p, base, cv), shape) for p in poses]
            sy, sx = [0] * n, [0] * n
            if act == "death":
                need_y = [R.bottom_need(m) for m in base_full]
                need_x = [R.side_need(m) for m in base_full]
                if any(need_y) or any(need_x):
                    sy, sx = _shifts(R, F, need_y, need_x, n)
            names = set()

            def write(strip, i, img):
                d = os.path.join(frames_root, strip)
                os.makedirs(d, exist_ok=True)
                img = R.shift(img, sy[i], sx[i])
                cell, lost, cl = R.to_cell(img, cv)
                if strip != "base":
                    cell = _layer_clean(cell)
                Image.fromarray(cell).save(os.path.join(d, f"{act}_{F}_f{i:02d}.png"))
                st = stats.setdefault(strip, {"frames": 0, "lost": 0, "empty": 0})
                st["frames"] += 1
                st["lost"] += sum(lost.values())
                st["empty"] += 0 if cell[..., 3].any() else 1
                names.add(strip)
            for i, p in enumerate(poses):
                write("base", i, base_full[i])
                bg = {group_slot(h): poser.draw(p, sets[h], cv) for h in groups if h.startswith("base_")}
                for g in groups:
                    imgs = bg[group_slot(g)] if g.startswith("base_") else poser.draw(p, sets[g], cv)
                    b, o = strip_images(R, F, p["order"], imgs, bg, group_slot(g))
                    write(g, i, o)
                    write(g + "__back", i, b)
            base_full = None
            outs = sorted(names)
            print(F, act, len(outs), flush=True)
    json.dump(stats, open(os.path.join(frames_root, "_stats.json"), "w"), indent=1)
    return stats


def _layer_clean(cell):
    """Layers: binary alpha, black under alpha 0 (to_cell already did both);
    drop specks under 6 px left by the base parts' erase."""
    from scipy import ndimage as ndi
    a = cell[..., 3] > 0
    lab, n = ndi.label(a, np.ones((3, 3)))
    if n:
        s = np.bincount(lab.ravel())
        small = np.isin(lab, np.nonzero(s < 6)[0]) & a
        cell = cell.copy()
        cell[small] = 0
    return cell


def _shifts(R, F, need_y, need_x, n):
    """ijrig.death_shifts on already rendered frames."""
    first = next(i for i in range(1, n) if any(np.abs(R.jt(F, "death", i, f"{sd}_{k}") - R.jt(F, "death", 0, f"{sd}_{k}")).max() > 0.25
                                               for sd in "RL" for k in ("heel", "toe")))
    out = []
    for need in (need_y, need_x):
        sg = 1 if max(need, key=abs, default=0) >= 0 else -1
        sh = np.maximum.accumulate(np.array([sg * v for v in need], float).clip(0))
        for j in range(n - 2, first - 1, -1):
            sh[j] = max(sh[j], sh[j + 1] - 3)
        sh[:first] = 0
        out.append([int(sg * v) for v in sh])
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default=os.environ.get("GEAR_WORK", "/tmp/ironjaw_gear_work"))
    ap.add_argument("--looks", default="", help="comma list of look strips (default: every parts folder); the base strips always render")
    ap.add_argument("--acts", default=",".join(KINDS))
    a = ap.parse_args()
    st = render_all(a.work, [x for x in a.looks.split(",") if x], a.acts.split(","))
    print(json.dumps(st))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
