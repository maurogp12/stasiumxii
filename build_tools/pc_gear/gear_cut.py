#!/usr/bin/env python3
"""Visible gear (paper doll), step 1: cut the paintings into rig parts.

Ironjaw pilot. Inputs (art/characters/painted/ironjaw_gear/source/, see the
README next to them):
  base_{S,E}.jpg               Ironjaw with nothing equipped (an edit of the
                               locked v7 turnaround targets, same pose, same axes).
  quarryhand_{S,E}_<slot>.jpg  the same painting with ONE Quarryhand piece added.
  legs_base.jpg                the v7 leg pieces repainted as trousers and shoes
                               (sheet laid out by legsheet_layout.json).
  legs_quarryhand_boots.jpg    the same sheet with the Quarryhand boots.

Output, per look, a parts folder in the format the locked action rig
(`ijrig.py`, claude/ironjaw-actions 9d784a1) reads: full 1280x720 canvases
named <part>_<F>.png, leg pieces leg_<side>_<seg>_<F>.png and ijoints_<F>.json.
  <work>/parts/base/       every part of the unarmoured body.
  <work>/parts/<look>/     only the parts the piece touches (head, body, cape or
                           leg_*_boot), transparent elsewhere.

The base is cut by hand-placed joints (CFG, base painting px) and the
foreground; holes the arms leave in the body, the upper arm under the shoulder
and the collar under the head are filled with real texture from the same
painting (block quilting, the actions_v1 lesson 4 fill). A piece is the pixels
that changed between its painting and the base (smoothed colour difference
inside its slot region); pixels that turned into background are dropped. Where
an arm or leg covered a piece in the painting (the belt or cape behind an arm)
the piece is closed under it with its own texture, so a swinging arm never
opens a gap.

usage: gear_cut.py [--work DIR]
"""
from __future__ import annotations

import argparse
import json
import os
import shutil

import cv2
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(ROOT, "art", "characters", "painted", "ironjaw_gear", "source")
SH = (720, 1280)
SLOTS = ("weapon", "head", "chest", "legs", "boots")
GROUPS = SLOTS + ("skin",)          # base split: one strip per slot, plus the bare hands
DATA = os.path.join(ROOT, "data", "pc", "gear_looks.json")
# The locked Ironjaw action rig: its parts, joints and scripts are read from git.
LOCK_COMMIT = "9d784a1678e92b0af633747f87c816346c765330"   # claude/ironjaw-actions
LOCK_DIR = "docs/pc/art_help/class_walk_looks/ironjaw/actions_v1"
WALK_COMMIT = "0f3eeb801f5bf679d6082e248e99490a81ff2580"   # art/ironjaw-walk-help (TA walk joints)
WALK_DIR = "docs/pc/art_help/ironjaw_walk/ta_joints"


def locked_tree(work: str) -> str:
    """Extract the locked action rig (and the TA walk joints) once into work."""
    import subprocess
    dst = os.path.join(work, "locked")
    if not os.path.exists(os.path.join(dst, LOCK_DIR, "scripts", "ijrig.py")):
        os.makedirs(dst, exist_ok=True)
        subprocess.run(f'git -C "{ROOT}" archive {LOCK_COMMIT} {LOCK_DIR}/parts {LOCK_DIR}/blockout/joints_actions_512.json '
                       f'{LOCK_DIR}/blockout/walk_fit.json {LOCK_DIR}/blockout/ta_idle_joints.json {LOCK_DIR}/scripts | tar -x -C "{dst}"',
                       shell=True, check=True)
        subprocess.run(f'git -C "{ROOT}" archive {WALK_COMMIT} {WALK_DIR}/joints_512.json | tar -x -C "{dst}"', shell=True, check=True)
    os.environ.setdefault("IJPARTS_LOCKED", os.path.join(dst, LOCK_DIR, "parts"))
    return dst


def sets_for(cls: str = "ironjaw") -> list[str]:
    doc = json.load(open(DATA))
    return [k for k, v in doc.get("sets", {}).items() if v.get("class") == cls]

# Joints and regions on the base paintings (1280x720 px). S = front, near arm R
# (screen left); E = back, arms L (screen left) and R.
CFG = {
    "S": {
        "arms": {
            "R": {"shoulder": (482, 150), "elbow": (408, 248), "grip": (386, 360), "r": (46, 34), "eye": (492, 468)},
            "L": {"shoulder": (734, 150), "elbow": (764, 252), "grip": (776, 362), "r": (40, 32), "eye": (842, 462)},
        },
        "head": [(572, 0), (722, 0), (728, 60), (708, 108), (690, 148), (640, 156), (598, 146), (584, 104), (572, 52)],
        "neck": (636, 146),
        "pelvis": (630, 372),
        "hips": {"R": (585, 400), "L": (690, 392)},
        "torso": [(470, 120), (560, 70), (730, 80), (790, 150), (800, 300), (790, 440), (470, 440), (455, 300)],
        "pauld_r": 44,
        "cape_upper": (600, 140),
        "cape_lower_y": (330, 470),
        "near": "R",
    },
    "E": {
        "arms": {
            "L": {"shoulder": (494, 148), "elbow": (436, 262), "grip": (433, 382), "r": (44, 34), "eye": (352, 432)},
            "R": {"shoulder": (758, 148), "elbow": (792, 270), "grip": (826, 392), "r": (44, 34), "eye": (920, 452)},
        },
        "head": [(592, 18), (672, 18), (684, 60), (676, 106), (650, 116), (612, 116), (590, 104), (582, 60)],
        "neck": (632, 108),
        "pelvis": (620, 400),
        "hips": {"L": (560, 440), "R": (668, 440)},
        "torso": [(470, 110), (560, 95), (700, 95), (790, 120), (810, 300), (800, 440), (460, 440), (450, 300)],
        "pauld_r": 44,
        "cape_upper": (630, 110),
        "cape_lower_y": (320, 470),
        "near": None,
    },
}
def poly(pts, sh=SH):
    im = Image.new("L", (sh[1], sh[0]), 0)
    ImageDraw.Draw(im).polygon([tuple(map(float, p)) for p in pts], fill=1)
    return np.asarray(im) > 0


def seg_dist(a, b, sh=SH):
    yy, xx = np.indices(sh)
    a = np.asarray(a, float); b = np.asarray(b, float); d = b - a
    t = np.clip(((xx - a[0]) * d[0] + (yy - a[1]) * d[1]) / max((d ** 2).sum(), 1e-9), 0, 1)
    return np.hypot(xx - (a[0] + t * d[0]), yy - (a[1] + t * d[1]))


def biggest(m):
    lab, n = ndi.label(m, np.ones((3, 3)))
    if n == 0:
        return m
    s = np.bincount(lab.ravel()); s[0] = 0
    return lab == s.argmax()


def clean(m, k=40):
    lab, n = ndi.label(m, np.ones((3, 3)))
    s = np.bincount(lab.ravel()); s[0] = 0
    return np.isin(lab, np.nonzero(s >= k)[0])


def load_rgb(path, size=(1280, 720)):
    return np.asarray(Image.open(path).convert("RGB").resize(size, Image.LANCZOS))


def bg_colour(rgb):
    edge = np.concatenate([rgb[:24].reshape(-1, 3), rgb[-24:].reshape(-1, 3), rgb[:, :24].reshape(-1, 3), rgb[:, -24:].reshape(-1, 3)])
    return np.median(edge, 0)


def foreground(rgb, th=34.0):
    d = np.abs(rgb.astype(np.float32) - bg_colour(rgb)).sum(-1)
    d = cv2.GaussianBlur(d, (0, 0), 0.8)
    m = ndi.binary_opening(d > th, iterations=1)
    m = ndi.binary_fill_holes(ndi.binary_closing(m, iterations=2))
    lab, n = ndi.label(m, np.ones((3, 3)))
    s = np.bincount(lab.ravel()); s[0] = 0
    return np.isin(lab, np.nonzero(s > 3000)[0])


# --- fills: block quilting from the same painting (copied from ijcut.py,
# claude/ironjaw-actions 9d784a1, actions_v1 lesson 4: never Telea).
def patch_fill(rgb, hole, src_ok, B=14, ov=5, search=140, ncand=260, feather=1.2, seed=11, dy_max=None):
    hole = hole.copy()
    H, W = hole.shape
    out = rgb.astype(np.float32).copy()
    rng = np.random.default_rng(seed)
    valid = src_ok & ~hole
    if not hole.any() or valid.sum() < B * B:
        return rgb.copy()
    ii = np.pad(np.cumsum(np.cumsum((~valid).astype(np.int32), 0), 1), ((1, 0), (1, 0)))

    def block_ok(y, x):
        return (ii[y + B, x + B] - ii[y, x + B] - ii[y + B, x] + ii[y, x]) == 0
    known = ~hole
    todo = hole.copy()
    step = B - ov
    d = ndi.distance_transform_edt(hole)
    ys, xs = np.nonzero(hole)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    cells = [(y, x) for y in range(max(0, y0 - ov), min(H - B, y1) + 1, step) for x in range(max(0, x0 - ov), min(W - B, x1) + 1, step)]
    cells = [(y, x) for y, x in cells if hole[y:y + B, x:x + B].any()]
    cells.sort(key=lambda p: d[p[0]:p[0] + B, p[1]:p[1] + B][hole[p[0]:p[0] + B, p[1]:p[1] + B]].min())
    vy, vx = np.nonzero(valid[:H - B, :W - B])
    for y, x in cells:
        need = todo[y:y + B, x:x + B]
        if not need.any():
            continue
        cy = cx = np.zeros(0, int)
        for lim in ([dy_max, dy_max * 2, dy_max * 4] if dy_max else []) + [None]:
            near = (np.abs(vx - x) <= search) & ((np.abs(vy - y) <= lim) if lim else True)
            if near.sum() < 1:
                continue
            py_, px_ = vy[near], vx[near]
            k = rng.choice(len(py_), size=min(ncand * 4, len(py_)), replace=False)
            py_, px_ = py_[k], px_[k]
            ok = block_ok(py_, px_)
            cy, cx = py_[ok][:ncand], px_[ok][:ncand]
            if len(cy) >= 8:
                break
        if len(cy) == 0:
            continue
        kn = known[y:y + B, x:x + B]
        tgt = out[y:y + B, x:x + B]
        if kn.any():
            idx = np.nonzero(kn)
            cost = np.array([((out[sy:sy + B, sx:sx + B][idx] - tgt[idx]) ** 2).sum() for sy, sx in zip(cy, cx)])
            j = int(np.argmin(cost + rng.random(len(cost)) * 1e-3))
        else:
            j = 0
        sy, sx = cy[j], cx[j]
        blk = out[y:y + B, x:x + B]
        src = out[sy:sy + B, sx:sx + B]
        blk[need] = src[need]
        ovl = kn & hole[y:y + B, x:x + B]
        blk[ovl] = 0.5 * blk[ovl] + 0.5 * src[ovl]
        todo[y:y + B, x:x + B] &= ~need
        known[y:y + B, x:x + B] |= need
    if todo.any():
        _, (iy, ix) = ndi.distance_transform_edt(~known, return_indices=True)
        out[todo] = out[iy[todo], ix[todo]]
    if feather:
        bl = cv2.GaussianBlur(out, (0, 0), feather)
        dd = ndi.distance_transform_edt(hole)
        edge = hole & (dd <= 2.0)
        out[edge] = 0.5 * out[edge] + 0.5 * bl[edge]
    return np.clip(out, 0, 255).astype(np.uint8)


def sleeve(rgb, vis, a, b, r, t_ref):
    """The upper arm continued under the shoulder cap by copies of its painted
    cross-section (ijcut.py), so a raised arm never shows a gap at the root."""
    a = np.asarray(a, float); b = np.asarray(b, float)
    u = (b - a) / np.linalg.norm(b - a); n = np.array([-u[1], u[0]])
    yy, xx = np.indices(SH)
    t = (xx - a[0]) * u[0] + (yy - a[1]) * u[1]
    o = (xx - a[0]) * n[0] + (yy - a[1]) * n[1]
    reg = (t >= -r * 0.6) & (t < t_ref[0]) & (np.abs(o) <= r) & ~vis
    if not reg.any():
        return rgb.copy(), vis.copy()
    ref_t = t_ref[0] + np.mod(t[reg] - t_ref[0], t_ref[1] - t_ref[0])
    sx = (a[0] + ref_t * u[0] + o[reg] * n[0]).astype(np.float32).reshape(-1, 1)
    sy = (a[1] + ref_t * u[1] + o[reg] * n[1]).astype(np.float32).reshape(-1, 1)
    src = cv2.remap(rgb.astype(np.float32), sx, sy, cv2.INTER_LINEAR)[:, 0]
    sm = cv2.remap(vis.astype(np.float32), sx, sy, cv2.INTER_LINEAR)[:, 0] > 0.5
    out = rgb.copy(); m = vis.copy(); ys, xs = np.nonzero(reg)
    out[ys[sm], xs[sm]] = np.clip(src[sm], 0, 255).astype(np.uint8)
    m[ys[sm], xs[sm]] = True
    return out, m


def save(path, rgb, m):
    out = np.zeros(m.shape + (4,), np.uint8)
    out[..., :3] = np.where(m[..., None], rgb, 0)
    out[..., 3] = m * 255
    Image.fromarray(out).save(path)


def cape_weights(path, c, capem):
    """Cloth weights (ijcut.py): 0 at the collar, upper panel through the back,
    lower panel below the hips; full on the cloth and past its ragged edge."""
    grown = ndi.binary_dilation(capem, iterations=30)
    wc = cv2.GaussianBlur(grown.astype(np.float32), (0, 0), 8)
    y0, y1 = c["cape_lower_y"]
    yy = np.indices(SH)[0].astype(np.float32)
    t = np.clip((yy - y0) / (y1 - y0), 0, 1); t = t * t * (3 - 2 * t)
    wl = wc * t
    wu = wc * (1 - t) * np.clip((yy - c["cape_upper"][1]) / 80, 0, 1)
    Image.fromarray(np.dstack([(wu * 255).astype(np.uint8), (wl * 255).astype(np.uint8), np.zeros(SH, np.uint8)])).save(path)


# ---------------------------------------------------------------- base cut
def arm_masks(F, fg, head, axe):
    c = CFG[F]
    out = {}
    yy, xx = np.indices(SH)
    for sd, J in c["arms"].items():
        sh, el, gr = (np.asarray(J[k], float) for k in ("shoulder", "elbow", "grip"))
        ru, rf = J["r"]
        up = seg_dist(sh, el) < ru
        fo = (seg_dist(el, gr) < rf) | (np.hypot(xx - gr[0], yy - gr[1]) < rf * 1.25)
        uu = (el - sh) / np.linalg.norm(el - sh); uf = (gr - el) / np.linalg.norm(gr - el)
        ub = uu + uf; ub /= np.linalg.norm(ub)
        side_f = ((xx - el[0]) * ub[0] + (yy - el[1]) * ub[1]) > 0
        # the haft through the fist: from behind the fist (pommel) to the axe
        # head's eye (CFG "eye", painting px)
        eye = np.asarray(J["eye"], float)
        dv = (eye - gr) / np.linalg.norm(eye - gr)
        haft = seg_dist(gr - dv * 80, eye) < 13
        fore = fg & ~head & ((fo & side_f) | axe[sd] | haft)
        # keep what hangs together with the hand
        lab_, _ = ndi.label(fore, np.ones((3, 3)))
        seeds = np.unique(lab_[(np.hypot(xx - gr[0], yy - gr[1]) < rf) & fore])
        fore = np.isin(lab_, seeds[seeds > 0]) | (axe[sd] & ~head)
        fore = clean(fore, 200)
        upper = fg & ~head & up & ~side_f & ~fore
        # the fore piece splits by slot: the bare hand (skin), the axe
        # (weapon) and the sleeve / forearm between (chest)
        hand = fore & (np.hypot(xx - gr[0], yy - gr[1]) < rf * 1.3)
        axe_m = fore & (axe[sd] | haft) & ~hand
        out[sd] = (upper, fore, hand, axe_m)
    return out


def axe_masks(F, fg):
    """Each axe from the locked fore piece (the axes are kept pixel for pixel
    in the base paintings): its pixels away from the old vambrace."""
    P = os.environ["IJPARTS_LOCKED"]
    old = json.load(open(f"{P}/ijoints_{F}.json"))["arms"]
    out = {}
    # the axes are the pixels the base painting kept from the locked target
    tgt = load_rgb(os.path.join(SRC, f"locked_target_{F}.jpg"))
    base = load_rgb(os.path.join(SRC, f"base_{F}.jpg"))
    diff = np.abs(cv2.GaussianBlur(tgt.astype(np.float32), (0, 0), 2.0) - cv2.GaussianBlur(base.astype(np.float32), (0, 0), 2.0)).sum(-1)
    same = ndi.binary_opening(diff < 60, iterations=1)
    # cloth seen through the blade's crescent is not axe: the axe is grey steel
    # (its brown haft is added along the grip line by arm_masks)
    lab = cv2.cvtColor(base, cv2.COLOR_RGB2LAB).astype(np.float32)
    brown = np.hypot(lab[..., 1] - 128, lab[..., 2] - 128) > 13
    for sd in "RL":
        fo = np.asarray(Image.open(f"{P}/fore_{sd}_{F}.png"))[..., 3] > 127
        J = old[sd]
        keep = fo & (seg_dist(J["elbow"], J["grip"]) > 44) & (same if F == "S" else True) & ~brown
        keep = ndi.binary_dilation(clean(keep, 60), iterations=2) & fg
        out[sd] = keep
    # the S near axe head sits over the near leg: keep only the axe's own
    # silhouette there (no trouser pixels ride with it)
    return out


def cut_base(F, out_dir, dbg):
    c = CFG[F]
    rgb = load_rgb(os.path.join(SRC, f"base_{F}.jpg"))
    fg = foreground(rgb)
    yy, xx = np.indices(SH)
    head = poly(c["head"]) & fg
    axe = axe_masks(F, fg)
    arms = arm_masks(F, fg, head, axe)
    armall = np.zeros(SH, bool)
    for sd, (u, f_, _h, _a) in arms.items():
        armall |= u | f_
    torso = poly(c["torso"])
    # tunic: the light cloth; legs below its hem are the rig's leg pieces
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(np.float32)
    light = fg & (lab[..., 0] > 120) & torso & ~armall & ~head
    light = biggest(ndi.binary_closing(light, iterations=3))
    hem = np.full(SH[1], -1)
    for x in np.nonzero(light.any(0))[0]:
        hem[x] = np.nonzero(light[:, x])[0].max()
    good = hem >= 0
    hem = np.interp(np.arange(SH[1]), np.nonzero(good)[0], hem[good])
    hem = ndi.maximum_filter1d(hem, 9) + 2
    body = fg & torso & ~armall & ~head & (yy <= hem[None, :])
    body = biggest(body)
    pa = {}
    for sd, J in c["arms"].items():
        cap = (np.hypot(xx - J["shoulder"][0], yy - J["shoulder"][1]) < c["pauld_r"]) & (arms[sd][0] | body) & fg & ~head
        pa[sd] = clean(cap, 30)
    rgbb = rgb.copy()
    closed = cv2.morphologyEx(body.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (61, 61))).astype(bool)
    hole = armall & closed & ~body & (yy < hem[None, :])
    rgbb = patch_fill(rgbb, hole, ndi.binary_erosion(body, iterations=3))
    body |= hole
    nk = c["neck"]
    under = head & (yy > nk[1] - 60) & ndi.binary_dilation(closed, iterations=6)
    rgbb = patch_fill(rgbb, under, ndi.binary_erosion(body & (yy > nk[1]) & (yy < nk[1] + 120), iterations=3))
    body = (body & ~head) | under
    body = clean(body, 80)
    save(f"{out_dir}/body_{F}.png", rgbb, body)
    save(f"{out_dir}/head_{F}.png", rgb, clean(head, 40))
    for sd, J in c["arms"].items():
        upper, fore = arms[sd][0], arms[sd][1]
        el = np.asarray(J["elbow"], float); sh_ = np.asarray(J["shoulder"], float)
        L = float(np.linalg.norm(el - sh_))
        urgb, um = sleeve(rgb, upper, J["shoulder"], J["elbow"], J["r"][0] * 0.8, (L * 0.35, L * 0.6))
        save(f"{out_dir}/uarm_{sd}_{F}.png", urgb, clean(um, 30))
        save(f"{out_dir}/fore_{sd}_{F}.png", rgb, fore)
        save(f"{out_dir}/pauld_{sd}_{F}.png", rgbb, pa[sd])
    empty = np.zeros(SH, bool)
    save(f"{out_dir}/cape_{F}.png", rgb, empty)
    Image.fromarray(np.zeros(SH + (3,), np.uint8)).save(f"{out_dir}/wcape_{F}.png")
    joints = {
        "arms": {sd: {k: list(map(float, J[k])) for k in ("shoulder", "elbow", "grip")} for sd, J in c["arms"].items()},
        "neck": list(c["neck"]), "pelvis": list(c["pelvis"]), "hips": {k: list(v) for k, v in c["hips"].items()},
        "cape_upper": list(c["cape_upper"]), "cape_lower_y": list(c["cape_lower_y"]), "near": c["near"],
    }
    if dbg is not None:
        o = np.full(SH + (3,), 235, np.uint8)
        cols = {"body": (200, 200, 200), "head": (0, 200, 0)}
        o[body] = (rgbb[body] * 0.5 + np.array(cols["body"]) * 0.5).astype(np.uint8)
        o[head] = (rgb[head] * 0.4 + np.array(cols["head"]) * 0.6).astype(np.uint8)
        for sd, colu, colf in (("R", (220, 200, 0), (0, 200, 220)), ("L", (150, 130, 0), (0, 120, 150))):
            u, f_ = arms[sd][0], arms[sd][1]
            o[u] = (rgb[u] * 0.4 + np.array(colu) * 0.6).astype(np.uint8)
            o[f_] = (rgb[f_] * 0.4 + np.array(colf) * 0.6).astype(np.uint8)
            o[pa[sd]] = (o[pa[sd]] * 0.5 + np.array([0, 0, 220]) * 0.5).astype(np.uint8)
        dbg[F] = o[:, 250:1030]
    masks = dict(fg=fg, body=body, head=head, arms=armall, hem=hem,
                 fore={sd: arms[sd][1] for sd in arms}, upper={sd: arms[sd][0] for sd in arms},
                 hand={sd: arms[sd][2] for sd in arms}, axe={sd: arms[sd][3] for sd in arms}, pauld=pa)
    return joints, masks, rgb


# ---------------------------------------------------------------- legs
def leg_pieces(sheet_path, out_dir, only=None, grade=None):
    """Leg pieces from a repainted leg sheet: the locked piece silhouettes
    (alpha) with the new paint inside. Returns {name: (rgb, alpha)}."""
    P = os.environ["IJPARTS_LOCKED"]
    lay = json.load(open(os.path.join(SRC, "legsheet_layout.json")))
    sheet = np.asarray(Image.open(sheet_path).convert("RGB").resize((1536, 1024), Image.LANCZOS)).astype(np.float32)
    bg = bg_colour(sheet.astype(np.uint8))
    res = {}
    for name, (x, y, nw, nh, w, h) in lay.items():
        sd, seg, F = name.split("_")
        if only and seg not in only:
            continue
        old = np.asarray(Image.open(f"{P}/leg_{sd}_{seg}_{F}.png").convert("RGBA"))
        a = old[..., 3] > 127
        crop = sheet[y:y + nh, x:x + nw]
        small = np.asarray(Image.fromarray(crop.astype(np.uint8)).resize((w, h), Image.LANCZOS)).astype(np.float32)
        isbg = np.abs(small - bg).sum(-1) < 30
        # the locked silhouettes carry armour bits (the E spur) the new paint
        # left as background: those pixels leave the piece
        a = clean(ndi.binary_fill_holes(a & ~ndi.binary_opening(isbg, iterations=1)), 30)
        ok = a & ~isbg
        if ok.sum() > 0 and (a & ~ok).any():
            _, (iy, ix) = ndi.distance_transform_edt(~ok, return_indices=True)
            small = small[iy, ix]
        if grade is not None and seg != "boot":
            small = grade(small, a)
        out = np.zeros((h, w, 4), np.uint8)
        out[..., :3] = np.where(a[..., None], np.clip(small, 0, 255), 0).astype(np.uint8)
        out[..., 3] = a * 255
        Image.fromarray(out).save(f"{out_dir}/leg_{sd}_{seg}_{F}.png")
        res[f"{sd}_{seg}_{F}"] = out
    return res


def trouser_grade(F, rgb_base, masks):
    """Grade the repainted trousers toward the trousers of the base painting
    (Lab mean / std, chroma at 50 %), so legs and body read as one outfit."""
    from skimage.color import rgb2lab, lab2rgb
    yy = np.indices(SH)[0]
    legs = masks["fg"] & ~masks["arms"] & (yy > masks["hem"][None, :] + 6) & (yy < 560)
    lab_b = rgb2lab(rgb_base / 255.0)
    legs &= np.hypot(lab_b[..., 1], lab_b[..., 2]) > 12      # the brown cloth, not the steel
    ref = lab_b[legs]
    mr, sr = ref.mean(0), ref.std(0)

    def g(small, a):
        lab = rgb2lab(np.clip(small, 0, 255) / 255.0)
        src = lab[a]
        ms, ss = src.mean(0), src.std(0) + 1e-3
        t = (lab - ms) / ss * sr + mr
        t[..., 1:] = lab[..., 1:] + (t[..., 1:] - lab[..., 1:]) * 0.85
        t[..., 0] = np.clip(t[..., 0], 0, 100)
        return np.clip(lab2rgb(t), 0, 1) * 255.0
    return g


# ---------------------------------------------------------------- base split
# Which slot each base part belongs to. The fore piece is split three ways.
PART_GROUP = {"head": "head", "body": "chest", "pauld": "chest", "uarm": "chest", "thigh": "legs", "shin": "legs", "boot": "boots"}


def split_base(F, base_dir, parts_root, masks):
    """The base parts of a facing copied into one folder per slot group
    (base_<group>), so each slot is its own strip and a worn look can replace it."""
    dirs = {g: os.path.join(parts_root, f"base_{g}") for g in GROUPS}
    for d in dirs.values():
        os.makedirs(d, exist_ok=True)
    for f in sorted(os.listdir(base_dir)):
        if not f.endswith(f"_{F}.png") or f.startswith("wcape") or f.startswith("cape"):
            continue
        name = f[:-4]
        kind = name.split("_")[0]
        if kind == "leg":
            kind = name.split("_")[2]
        im = np.asarray(Image.open(os.path.join(base_dir, f)).convert("RGBA"))
        if kind == "fore":
            sd = name.split("_")[1]
            a = im[..., 3] > 127
            hand, axe_m = masks["hand"][sd], masks["axe"][sd]
            for g, m in (("skin", a & hand), ("weapon", a & axe_m), ("chest", a & ~hand & ~axe_m)):
                out = im.copy()
                out[~m] = 0
                if m.any():
                    Image.fromarray(out).save(os.path.join(dirs[g], f))
            continue
        g = PART_GROUP.get(kind)
        if g:
            shutil.copy(os.path.join(base_dir, f), os.path.join(dirs[g], f))


# ---------------------------------------------------------------- looks
def owner_map(F, masks, base_dir):
    """Which base part each painting pixel belongs to (the part drawn on top in
    the rig's rest order), grown outward so armour bigger than the body still
    finds its part. Returns (label map, names)."""
    names = ["body", "pauld_R", "pauld_L", "uarm_R", "uarm_L", "fore_R", "fore_L", "head"]
    near = CFG[F]["near"]
    if F == "S":   # far arm behind the body, near arm in front
        far = "L" if near == "R" else "R"
        prio = [f"uarm_{far}", f"fore_{far}", f"pauld_{far}", "body", "head", f"uarm_{near}", f"fore_{near}", f"pauld_{near}"]
    else:
        prio = ["body", "head", "uarm_R", "fore_R", "uarm_L", "fore_L", "pauld_R", "pauld_L"]
    lab = np.zeros(SH, np.int32)
    for n in prio:
        a = np.asarray(Image.open(os.path.join(base_dir, f"{n}_{F}.png")))[..., 3] > 127
        lab[a] = names.index(n) + 1
    _, (iy, ix) = ndi.distance_transform_edt(lab == 0, return_indices=True)
    return lab[iy, ix] - 1, names


def look_region(F, slot, masks):
    yy, xx = np.indices(SH)
    c = CFG[F]
    axes = masks["axe"]["R"] | masks["axe"]["L"]
    hands = masks["hand"]["R"] | masks["hand"]["L"]
    if slot == "weapon":
        core = ndi.binary_erosion(masks["body"] | masks["head"], iterations=3)
        return ndi.binary_dilation(axes | hands, iterations=50) & ~core
    if slot == "head":
        return ndi.binary_dilation(masks["head"], iterations=34) & (yy < c["neck"][1] + 40) & ~ndi.binary_dilation(axes, iterations=3)
    if slot == "chest":
        fa = np.zeros(SH, bool)
        for J in c["arms"].values():
            fa |= seg_dist(J["elbow"], J["grip"]) < 36
        upper = masks["upper"]["R"] | masks["upper"]["L"] | masks["pauld"]["R"] | masks["pauld"]["L"]
        reg = (ndi.binary_dilation(masks["body"] | upper, iterations=40) | fa) & (yy < c["pelvis"][1] + 120)
        return reg & ~ndi.binary_dilation(axes, iterations=4) & ~ndi.binary_erosion(hands, iterations=4)
    raise KeyError(slot)


def look_mask(F, slot, base_rgb, edit_rgb, masks):
    b = cv2.GaussianBlur(base_rgb.astype(np.float32), (0, 0), 1.6)
    e = cv2.GaussianBlur(edit_rgb.astype(np.float32), (0, 0), 1.6)
    d = np.abs(e - b).sum(-1)
    m = (d > 42) & look_region(F, slot, masks)
    m = ndi.binary_opening(m, iterations=1)
    m = clean(m, 300)
    m = ndi.binary_fill_holes(ndi.binary_closing(m, iterations=4))
    return m & foreground(edit_rgb)


def close_under(rgb, m, cover, span=41):
    """Close a piece under the arms that covered it in the painting."""
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (span, span))
    hull = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, k).astype(bool)
    hole = hull & cover & ~m
    if hole.sum() < 20:
        return rgb, m
    return patch_fill(rgb, hole, ndi.binary_erosion(m, iterations=2), B=10, ov=4, search=120), m | hole


def cut_look(F, family, slot, masks, base_rgb, base_dir, out_dir):
    """One worn piece of an upper-body slot (weapon, head, chest) into rig parts."""
    path = os.path.join(SRC, f"{family}_{F}_{slot}.jpg")
    if not os.path.exists(path):
        return {}
    edit = load_rgb(path)
    m = look_mask(F, slot, base_rgb, edit, masks)
    rgb = edit.copy()
    parts = {}
    if slot == "head":
        parts["head"] = m
    elif slot == "weapon":
        yy, xx = np.indices(SH)
        d = {sd: np.hypot(xx - CFG[F]["arms"][sd]["grip"][0], yy - CFG[F]["arms"][sd]["grip"][1]) for sd in "RL"}
        for sd, other in (("R", "L"), ("L", "R")):
            parts[f"fore_{sd}"] = m & (d[sd] <= d[other])
    elif slot == "chest":
        lab, names = owner_map(F, masks, base_dir)
        for i, n in enumerate(names):
            if n == "head":
                continue
            pm = m & (lab == i)
            if n == "body":
                rgb, pm = close_under(rgb, pm, masks["arms"] & ~ndi.binary_dilation(m & ~pm, iterations=0))
            parts[n] = pm
        # anything the owner map gave the head stays with the torso
        parts["body"] = parts["body"] | (m & (lab == names.index("head")))
    if slot in ("head", "chest"):
        # A worn piece REPLACES its whole base zone: every pixel of that slot's
        # base parts stays covered (the neck under a helm, the hem under a
        # cuirass), painted from the one-piece painting; where the painting
        # shows background there (a smaller helm), the piece's own paint
        # around it fills in, so the base zone never opens a hole.
        gdir = os.path.join(os.path.dirname(out_dir), f"base_{slot}")
        bg = bg_colour(edit).astype(np.float32)
        isbg = np.abs(edit.astype(np.float32) - bg).sum(-1) < 30
        allm = np.zeros(SH, bool)
        for pm in parts.values():
            allm |= pm
        for f in sorted(os.listdir(gdir)):
            if not f.endswith(f"_{F}.png"):
                continue
            name = f[:-6]
            ab = np.asarray(Image.open(os.path.join(gdir, f)))[..., 3] > 127
            if not ab.any():
                continue
            u = parts.get(name, np.zeros(SH, bool)) | ab
            need = u & ~allm & isbg
            if need.any() and allm.any():
                _, (iy, ix) = ndi.distance_transform_edt(~allm, return_indices=True)
                rgb[need] = rgb[iy[need], ix[need]]
            parts[name] = u
    out = {}
    for part, pm in parts.items():
        pm = clean(pm, 40)
        if pm.any():
            save(f"{out_dir}/{part}_{F}.png", rgb, pm)
            out[part] = int(pm.sum())
    return out


def tint_dir(src_dir, dst_dir, colour):
    """A stand-in look: the base slot strip tinted (layering tests before the
    real pieces are approved). Never shipped."""
    os.makedirs(dst_dir, exist_ok=True)
    for f in os.listdir(src_dir):
        if not f.endswith(".png"):
            continue
        im = np.asarray(Image.open(os.path.join(src_dir, f)).convert("RGBA")).astype(np.float32)
        a = im[..., 3:] > 0
        im[..., :3] = np.where(a, im[..., :3] * 0.4 + np.array(colour, np.float32) * 0.6, 0)
        Image.fromarray(im.astype(np.uint8)).save(os.path.join(dst_dir, f))


PLACEHOLDER_TINT = {"weapon": (230, 200, 40), "head": (200, 60, 60), "chest": (60, 120, 200), "legs": (60, 170, 80), "boots": (190, 70, 200)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default=os.environ.get("GEAR_WORK", "/tmp/ironjaw_gear_work"))
    ap.add_argument("--debug", default=None)
    ap.add_argument("--families", default=None, help="comma list of set families to cut (default: data/pc/gear_looks.json sets)")
    ap.add_argument("--placeholder", default=None, help="family name for tinted stand-in looks of every slot (tests only)")
    a = ap.parse_args()
    locked_tree(a.work)
    parts_root = os.path.join(a.work, "parts")
    if os.path.isdir(parts_root):
        shutil.rmtree(parts_root)
    base_dir = os.path.join(parts_root, "base")
    os.makedirs(base_dir)
    dbg = {} if a.debug else None
    info = {}
    P = os.environ["IJPARTS_LOCKED"]
    for F in "SE":
        joints, masks, rgb = cut_base(F, base_dir, dbg)
        locked = json.load(open(f"{P}/ijoints_{F}.json"))
        joints["legs"] = locked["legs"]
        json.dump(joints, open(f"{base_dir}/ijoints_{F}.json", "w"), indent=1)
        info[F] = (joints, masks, rgb)
    rgbS = info["S"][2]
    grade = trouser_grade("S", rgbS, info["S"][1])
    leg_pieces(os.path.join(SRC, "legs_base.jpg"), base_dir, grade=grade)
    for F in "SE":
        split_base(F, base_dir, parts_root, info[F][1])
    report = {}
    fams = a.families.split(",") if a.families is not None else sets_for("ironjaw")
    for fam in fams:
        if not fam:
            continue
        for slot in SLOTS:
            d = os.path.join(parts_root, f"{fam}_{slot}")
            os.makedirs(d, exist_ok=True)
            if slot in ("legs", "boots"):
                sheet = os.path.join(SRC, f"{fam}_legsheet_{slot}.jpg")
                if os.path.exists(sheet):
                    segs = ("thigh", "shin") if slot == "legs" else ("boot",)
                    leg_pieces(sheet, d, only=segs, grade=None)
                    report[f"{fam}_{slot}"] = list(segs)
                continue
            for F in "SE":
                joints, masks, rgb = info[F]
                report[f"{fam}_{slot}_{F}"] = cut_look(F, fam, slot, masks, rgb, base_dir, d)
            if not os.listdir(d):
                os.rmdir(d)
    if a.placeholder:
        for slot in SLOTS:
            tint_dir(os.path.join(parts_root, f"base_{slot}"), os.path.join(parts_root, f"{a.placeholder}_{slot}"), PLACEHOLDER_TINT[slot])
    for d in os.listdir(parts_root):
        if os.path.isdir(os.path.join(parts_root, d)) and not os.listdir(os.path.join(parts_root, d)):
            os.rmdir(os.path.join(parts_root, d))
    print(json.dumps(report))
    if dbg is not None:
        Image.fromarray(np.vstack([dbg["S"], dbg["E"]])).save(a.debug)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
