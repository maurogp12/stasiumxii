#!/usr/bin/env python3
"""Cut a soft test puppet from the approved 1024x576 Ironjaw paintings.

The masters are the paintings. Nothing is upscaled. S is the front
three-quarter. B is the back view, cut from base_E.jpg and the
family_E_<slot>.jpg files. S mirrored is the other front three-quarter
and is not a third paint.

Each child keeps about 6 px of its parent's real edge colours under the
joint. Those pixels are the painting, clipped to the figure, never a flat
disk and never drawn past the silhouette. Alpha is binary, from a matte
eroded by about 1 px.

    python3 build_tools/pc_charselect/cut_puppet.py

Needs: pillow, numpy, opencv-python-headless, scipy.
"""

from __future__ import annotations

import json
import os
import shutil
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PUPPET = os.path.join(ROOT, "art", "pc", "character_select", "puppets", "ironjaw_m")
SRC = os.path.join(PUPPET, "source")
# Native painting. The old joint notes were taken on a 1280x720 upscale.
SCALE = 1024.0 / 1280.0
SH = (576, 1024)
OVERLAP = 6
FAMILIES = ("cragmaw", "tyrantjaw", "pitmaw")
SLOTS = {
    "head": ["hair"],
    "chest": ["torso", "upper_arm_l", "upper_arm_r", "lower_arm_l", "lower_arm_r"],
    "legs": ["thigh_l", "thigh_r", "shin_l", "shin_r"],
    "boots": ["foot_l", "foot_r"],
    "weapon": ["weapon"],
}
# Source file letter. B is the back view; the files stay *_E.jpg.
SRC_LETTER = {"S": "S", "B": "E"}

# Joints measured on the 1280 canvas. R and L are the character's right and left.
_RAW = {
    "S": {
        "arms": {
            "R": {"shoulder": (482, 150), "elbow": (408, 248), "grip": (386, 360), "r": (46, 34)},
            "L": {"shoulder": (734, 150), "elbow": (764, 252), "grip": (776, 362), "r": (40, 32)},
        },
        "head": [(572, 0), (722, 0), (728, 60), (708, 108), (690, 148), (640, 156), (598, 146), (584, 104), (572, 52)],
        "neck": (636, 146),
        "pelvis": (630, 372),
        "hips": {"R": (585, 400), "L": (690, 392)},
        "body_x": 630,
        "near": "R",
    },
    "B": {
        "arms": {
            "L": {"shoulder": (494, 148), "elbow": (436, 262), "grip": (433, 382), "r": (44, 34)},
            "R": {"shoulder": (758, 148), "elbow": (792, 270), "grip": (826, 392), "r": (44, 34)},
        },
        "head": [(592, 18), (672, 18), (684, 60), (676, 106), (650, 116), (612, 116), (590, 104), (582, 60)],
        "neck": (632, 108),
        "pelvis": (620, 400),
        "hips": {"L": (560, 440), "R": (668, 440)},
        "body_x": 640,
        "near": "R",
    },
}


def _pt(p):
    return (float(p[0]) * SCALE, float(p[1]) * SCALE)


def _cfg():
    out = {}
    for facing, raw in _RAW.items():
        arms = {}
        for sd, joint in raw["arms"].items():
            arms[sd] = {
                "shoulder": np.asarray(_pt(joint["shoulder"])),
                "elbow": np.asarray(_pt(joint["elbow"])),
                "grip": np.asarray(_pt(joint["grip"])),
                "r": (joint["r"][0] * SCALE, joint["r"][1] * SCALE),
            }
        out[facing] = {
            "arms": arms,
            "head": [_pt(p) for p in raw["head"]],
            "neck": np.asarray(_pt(raw["neck"])),
            "pelvis": np.asarray(_pt(raw["pelvis"])),
            "hips": {sd: np.asarray(_pt(p)) for sd, p in raw["hips"].items()},
            "body_x": raw["body_x"] * SCALE,
            "near": raw["near"],
        }
    return out


CFG = _cfg()


def poly(pts, sh=SH):
    im = Image.new("L", (sh[1], sh[0]), 0)
    ImageDraw.Draw(im).polygon([tuple(map(float, p)) for p in pts], fill=1)
    return np.asarray(im) > 0


def seg_dist(a, b, sh=SH):
    yy, xx = np.indices(sh)
    a = np.asarray(a, float)
    b = np.asarray(b, float)
    delta = b - a
    denom = max(float((delta ** 2).sum()), 1e-9)
    t = np.clip(((xx - a[0]) * delta[0] + (yy - a[1]) * delta[1]) / denom, 0, 1)
    return np.hypot(xx - (a[0] + t * delta[0]), yy - (a[1] + t * delta[1]))


def disk(joint, radius, sh=SH):
    yy, xx = np.indices(sh)
    return np.hypot(xx - joint[0], yy - joint[1]) <= radius


def clean(mask, k=40):
    lab, n = ndi.label(mask, np.ones((3, 3)))
    if n == 0:
        return mask
    sizes = np.bincount(lab.ravel())
    sizes[0] = 0
    return np.isin(lab, np.nonzero(sizes > k)[0])


def load_rgb(path):
    rgb = np.asarray(Image.open(path).convert("RGB"))
    if rgb.shape[0] != SH[0] or rgb.shape[1] != SH[1]:
        raise SystemExit(f"{path} is {rgb.shape[1]}x{rgb.shape[0]}, expected {SH[1]}x{SH[0]}")
    return rgb


def bg_colour(rgb):
    edge = np.concatenate([
        rgb[:16].reshape(-1, 3),
        rgb[-16:].reshape(-1, 3),
        rgb[:, :16].reshape(-1, 3),
        rgb[:, -16:].reshape(-1, 3),
    ])
    return np.median(edge, 0)


def foreground(rgb, th=30.0):
    """Binary matte. No blur and no closing, so the grey backdrop cannot halo.
    Erode about 1 px with a disk to drop the fringe."""
    delta = np.abs(rgb.astype(np.float32) - bg_colour(rgb)).sum(-1)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    mask = cv2.morphologyEx((delta > th).astype(np.uint8) * 255, cv2.MORPH_OPEN, kernel) > 0
    # Fill only real interior gaps. A bay of the grey backdrop must stay empty.
    holes = ndi.binary_fill_holes(mask) & ~mask
    mask = mask | (holes & (delta > 48))
    lab, _n = ndi.label(mask, np.ones((3, 3)))
    sizes = np.bincount(lab.ravel())
    sizes[0] = 0
    mask = np.isin(lab, np.nonzero(sizes > 3000)[0])
    mask = cv2.erode((mask.astype(np.uint8) * 255), kernel, iterations=1) > 0
    mask = mask & (delta > th)
    return mask


def side_name(sd):
    return "r" if sd == "R" else "l"


def paint_hole(rgb, solid, hole):
    """Copy the nearest real part colour into hole. Hole must already be inside the figure."""
    if not hole.any() or not solid.any():
        return rgb
    _dist, (iy, ix) = ndi.distance_transform_edt(~solid, return_indices=True)
    out = rgb.copy()
    out[hole] = rgb[iy[hole], ix[hole]]
    return out


def find_haft_end(fg, grip, shoulder):
    """Walk away from the shoulder along the handle. The head is the fat end."""
    arm = np.asarray(shoulder, float) - np.asarray(grip, float)
    arm = arm / max(float(np.linalg.norm(arm)), 1e-9)
    grip = np.asarray(grip, float)
    best = None
    height, width = fg.shape
    for ang in np.linspace(-np.pi, np.pi, 72, endpoint=False):
        direc = np.array([np.cos(ang), np.sin(ang)])
        if float(np.dot(direc, arm)) > 0.15:
            continue
        last = None
        reach = 0
        for dist in range(16, 210, 4):
            point = grip + direc * dist
            x, y = int(point[0]), int(point[1])
            if not (8 <= x < width - 8 and 8 <= y < height - 8):
                break
            if fg[y - 5:y + 6, x - 5:x + 6].mean() < 0.25:
                break
            last = point.copy()
            reach = dist
        if last is None or reach < 48:
            continue
        x, y = int(last[0]), int(last[1])
        y0, y1 = max(0, y - 36), min(height, y + 37)
        x0, x1 = max(0, x - 36), min(width, x + 37)
        fat = int(fg[y0:y1, x0:x1].sum())
        score = reach + fat * 0.02
        if best is None or score > best[0]:
            best = (score, last, reach)
    if best is None:
        return grip + np.array([0.0, 40.0])
    return best[1]


def axe_mask(fg, grip, tip):
    """Full head: a narrow haft that widens at the tip. Clipped to the matte."""
    yy, xx = np.indices(fg.shape)
    grip = np.asarray(grip, float)
    tip = np.asarray(tip, float)
    delta = tip - grip
    length = max(float(np.linalg.norm(delta)), 1.0)
    unit = delta / length
    tip2 = tip + unit * 36.0
    span = tip2 - grip
    denom = max(float((span ** 2).sum()), 1e-9)
    t = np.clip(((xx - grip[0]) * span[0] + (yy - grip[1]) * span[1]) / denom, 0, 1)
    dist = np.hypot(xx - (grip[0] + t * span[0]), yy - (grip[1] + t * span[1]))
    along = (xx - grip[0]) * unit[0] + (yy - grip[1]) * unit[1]
    width = np.interp(along, [-6.0, length * 0.45, length + 36.0], [9.0, 14.0, 46.0])
    raw = fg & (along > -10) & (along < length + 48) & (dist <= width)
    lab, n = ndi.label(raw)
    if n == 0:
        return raw, along, length
    ti = int(np.clip(round(tip[1]), 0, fg.shape[0] - 1))
    tj = int(np.clip(round(tip[0]), 0, fg.shape[1] - 1))
    if lab[ti, tj] == 0:
        pts = np.argwhere(raw)
        if len(pts) == 0:
            return raw, along, length
        pick = pts[np.argmin((pts[:, 1] - tip[0]) ** 2 + (pts[:, 0] - tip[1]) ** 2)]
        ti, tj = int(pick[0]), int(pick[1])
    return lab == lab[ti, tj], along, length


def head_blob(facing, fg):
    loose = ndi.binary_dilation(poly(CFG[facing]["head"]), iterations=18)
    blob = fg & loose
    blob = clean(blob, 40)
    return blob


def split_head(rgb, head):
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(np.float32)
    ys, xs = np.nonzero(head)
    if len(ys) == 0:
        empty = np.zeros(SH, bool)
        return empty, empty, empty
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    height = max(y1 - y0, 1)
    yy, xx = np.indices(SH)
    brow = y0 + int(height * 0.42)
    chin = y0 + int(height * 0.72)
    dark = lab[..., 0] < 105
    hair = head & (dark | (yy <= brow) | ((yy >= chin) & (lab[..., 0] < 140)))
    hair = clean(hair, 30)
    skin = head & ~hair
    eye_band = skin & (yy > y0 + int(height * 0.28)) & (yy < y0 + int(height * 0.55))
    dark_eyes = clean(eye_band & (lab[..., 0] < 90), 4)
    if dark_eyes.sum() < 12:
        cx = (x0 + x1) * 0.5
        cy = y0 + height * 0.40
        span = (x1 - x0) * 0.16
        dark_eyes = head & (
            (np.hypot(xx - (cx - span), yy - cy) < 7) | (np.hypot(xx - (cx + span), yy - cy) < 7)
        )
    eyes = ndi.binary_dilation(dark_eyes, iterations=2) & head
    hair = hair & ~eyes
    skin = head & ~hair & ~eyes
    skin = skin | eyes
    return skin, hair, eyes


def leg_chain(fg, hip, other_hip):
    hip = np.asarray(hip, float)
    other = np.asarray(other_hip, float)
    mid_x = (hip[0] + other[0]) * 0.5
    go_right = hip[0] >= other[0]
    yy, xx = np.indices(SH)
    column = fg & (yy >= hip[1] - 8)
    if go_right:
        column = column & (xx >= mid_x - 8)
    else:
        column = column & (xx <= mid_x + 8)
    centers = []
    x = float(hip[0])
    y = int(hip[1])
    miss = 0
    while y < SH[0] - 2 and miss < 10:
        lo = max(int(x) - 36, 0)
        hi = min(int(x) + 36, SH[1])
        row = column[y, lo:hi]
        if row.sum() < 6:
            miss += 1
            y += 2
            continue
        miss = 0
        xs = np.nonzero(row)[0] + lo
        x = float(xs.mean())
        centers.append((x, float(y)))
        y += 3
    if len(centers) < 8:
        toe = np.array([hip[0], min(hip[1] + 160, SH[0] - 8)])
        knee = hip + (toe - hip) * 0.42
        ankle = hip + (toe - hip) * 0.78
        return hip, knee, ankle, toe
    pts = np.asarray(centers)
    return pts[0], pts[int(len(pts) * 0.40)], pts[int(len(pts) * 0.78)], pts[-1]


def bone_mask(fg, a, b, radius):
    return fg & (seg_dist(a, b) <= radius)


def seat_joint(hint, mask, radius):
    """A joint pixel whose disk sits inside real paint, near the hint."""
    hint = np.asarray(hint, float)
    inside = ndi.distance_transform_edt(mask)
    yy, xx = np.indices(mask.shape)
    near = (np.hypot(xx - hint[0], yy - hint[1]) <= 80) & mask
    for need in (radius, 6, 5, 4):
        cand = near & (inside >= need)
        if cand.any():
            ys, xs = np.nonzero(cand)
            pick = np.argmin((xs - hint[0]) ** 2 + (ys - hint[1]) ** 2)
            return np.array([float(xs[pick]), float(ys[pick])])
    return np.array([round(hint[0]), round(hint[1])], float)


def close_bays(rgb, parts):
    union = np.zeros(SH, bool)
    for mask in parts.values():
        union |= mask
    bay = ndi.binary_fill_holes(union) & ~union
    if not bay.any():
        return rgb
    _dist, (iy, ix) = ndi.distance_transform_edt(~union, return_indices=True)
    out = rgb.copy()
    out[bay] = rgb[iy[bay], ix[bay]]
    labels = np.zeros(SH, np.int16)
    names = list(parts.keys())
    for i, name in enumerate(names, start=1):
        labels[parts[name]] = i
    owner = labels[iy, ix]
    for i, name in enumerate(names, start=1):
        parts[name] = parts[name] | (bay & (owner == i))
    return out


def share_under(rgb, parts, welds, child, parent, hint, fg):
    """Copy about 6 px of real painted pixels onto both sides of the joint.

    The disk is seated inside the figure. Parent pixels already there are the
    edge colours. Nothing is sampled from the backdrop and nothing is drawn
    outside the matte. The copy on the child is the weld, under the child's
    own paint (it only fills pixels the child did not already have)."""
    # The painted tuck is OVERLAP px. The parent keeps two extra pixels so a
    # bend's raster cannot step a weld texel off the silhouette.
    pad = OVERLAP + 2
    union = fg | parts[parent] | parts[child]
    joint = seat_joint(hint, union, pad)
    joint = np.array([round(float(joint[0])), round(float(joint[1]))], float)
    cover = disk(joint, pad) & ndi.binary_fill_holes(union)
    if int(cover.sum()) < 20:
        cover = disk(joint, pad) & union
    # Tuck pixels outside the matte take the nearest real figure colour, not the backdrop.
    fresh = cover & ~fg
    if fresh.any():
        rgb = paint_hole(rgb, fg, fresh)
    parts[parent] = parts[parent] | cover
    parts[child] = parts[child] | (disk(joint, OVERLAP) & (cover | fg))
    welds[child] = welds.get(child, np.zeros(SH, bool)) | (disk(joint, OVERLAP - 1) & parts[parent])
    return rgb, joint


def cut_base(facing):
    rgb = load_rgb(os.path.join(SRC, f"base_{SRC_LETTER[facing]}.jpg"))
    fg = foreground(rgb)
    c = CFG[facing]
    head_region = head_blob(facing, fg)
    skin, hair, eyes = split_head(rgb, head_region)
    axes = {}
    along = {}
    lengths = {}
    for sd, joint in c["arms"].items():
        tip = find_haft_end(fg, joint["grip"], joint["shoulder"])
        mask, ax_along, length = axe_mask(fg, joint["grip"], tip)
        axes[sd] = mask
        along[sd] = ax_along
        lengths[sd] = length
    axe_all = np.zeros(SH, bool)
    for mask in axes.values():
        axe_all |= mask

    arms = {}
    yy, xx = np.indices(SH)
    for sd, joint in c["arms"].items():
        shoulder, elbow, grip = joint["shoulder"], joint["elbow"], joint["grip"]
        ru, rf = joint["r"]
        past = ((xx - elbow[0]) * ((grip - elbow) / max(np.linalg.norm(grip - elbow), 1))[0]
                + (yy - elbow[1]) * ((grip - elbow) / max(np.linalg.norm(grip - elbow), 1))[1]) > -4
        reach = np.hypot(xx - grip[0], yy - grip[1])
        # The fist keeps the paint at the grip. The head of this axe is not the fist.
        own = axes[sd] & (reach > 18)
        upper = bone_mask(fg & ~head_region & ~own, shoulder, elbow, ru) & ~past
        lower = bone_mask(fg & ~head_region & ~own, elbow, grip, rf) & past
        hand = fg & ~head_region & ~own & (reach <= max(rf, 22))
        upper = clean(upper & ~lower & ~hand, 30)
        lower = clean(lower & ~hand, 20)
        hand = clean(hand, 12)
        arms[sd] = {"upper": upper, "lower": lower, "hand": hand}

    # The character's left axe stays on the left hand, so it cannot orbit the other grip.
    arms["L"]["hand"] = arms["L"]["hand"] | (axes["L"] & fg)
    weapon = axes["R"] & fg

    arm_all = np.zeros(SH, bool)
    for piece in arms.values():
        arm_all |= piece["upper"] | piece["lower"] | piece["hand"]

    hips = c["hips"]
    legs = {}
    for sd, hip in hips.items():
        other = hips["L" if sd == "R" else "R"]
        hip_p, knee, ankle, toe = leg_chain(fg & ~weapon, hip, other)
        clear = fg & ~head_region & ~arm_all & ~weapon
        thigh = bone_mask(clear, hip_p, knee, 26)
        shin = bone_mask(clear, knee, ankle, 22) & ~thigh
        foot = bone_mask(fg & ~weapon & ~arm_all, ankle, toe, 24) & ~thigh & ~shin
        # Where the right axe crosses a leg, rebuild the limb from its own edge colours.
        for name, bone_a, bone_b, radius, dest in (
            ("thigh", hip_p, knee, 26, "thigh"),
            ("shin", knee, ankle, 22, "shin"),
            ("foot", ankle, toe, 24, "foot"),
        ):
            pass
        covered = thigh | shin | foot
        hole = weapon & bone_mask(np.ones(SH, bool), hip_p, toe, 30) & fg & ~covered & ~head_region
        if hole.any() and covered.any():
            rgb = paint_hole(rgb, covered, hole)
            thigh = thigh | (hole & bone_mask(np.ones(SH, bool), hip_p, knee, 26))
            shin = shin | (hole & bone_mask(np.ones(SH, bool), knee, ankle, 22) & ~thigh)
            foot = foot | (hole & ~thigh & ~shin & bone_mask(np.ones(SH, bool), ankle, toe, 24))
        legs[sd] = {
            "thigh": clean(thigh, 20),
            "shin": clean(shin, 16),
            "foot": clean(foot, 12),
            "hip": hip_p,
            "knee": knee,
            "ankle": ankle,
            "toe": toe,
        }

    leg_all = np.zeros(SH, bool)
    for piece in legs.values():
        leg_all |= piece["thigh"] | piece["shin"] | piece["foot"]
    # Torso is whatever painted pixel is left. The hem is the silhouette, not a horizontal cut.
    tunic = clean(fg & ~head_region & ~arm_all & ~leg_all & ~weapon, 40)
    # Rebuild tunic behind the right axe, from the tunic's own edge, inside the body.
    torso_core = seg_dist(c["neck"], c["pelvis"]) <= 78
    hole = weapon & torso_core & fg & ~tunic & ~head_region & ~leg_all
    if hole.any() and tunic.any():
        rgb = paint_hole(rgb, tunic, hole)
        tunic = tunic | hole

    parts = {
        "head": (skin | eyes) & fg,
        "hair": hair & fg,
        "eyes": eyes & fg,
        "torso": tunic & fg,
        "weapon": weapon & fg,
    }
    for sd, piece in arms.items():
        name = side_name(sd)
        parts[f"upper_arm_{name}"] = piece["upper"] & fg
        parts[f"lower_arm_{name}"] = piece["lower"] & fg
        parts[f"hand_{name}"] = piece["hand"] & fg
    for sd, piece in legs.items():
        name = side_name(sd)
        parts[f"thigh_{name}"] = piece["thigh"] & fg
        parts[f"shin_{name}"] = piece["shin"] & fg
        parts[f"foot_{name}"] = piece["foot"] & fg

    joints = {
        "head": c["neck"].copy(),
        "hair": c["neck"].copy(),
        "eyes": c["neck"].copy(),
        "torso": c["pelvis"].copy(),
        "weapon": c["arms"]["R"]["grip"].copy(),
        "hip": c["pelvis"].copy(),
    }
    for sd, joint in c["arms"].items():
        name = side_name(sd)
        joints[f"upper_arm_{name}"] = joint["shoulder"].copy()
        joints[f"lower_arm_{name}"] = joint["elbow"].copy()
        joints[f"hand_{name}"] = joint["grip"].copy()
    for sd, piece in legs.items():
        name = side_name(sd)
        joints[f"thigh_{name}"] = np.asarray(piece["hip"], float)
        joints[f"shin_{name}"] = np.asarray(piece["knee"], float)
        joints[f"foot_{name}"] = np.asarray(piece["ankle"], float)

    # Close backdrop bays that the pose encloses, using the nearest real part colour.
    rgb = close_bays(rgb, parts)
    # Thighs hang off the torso so the hip tuck turns with the tunic.
    welds = {}
    order = [
        ("head", "torso", joints["head"]),
        ("upper_arm_r", "torso", joints["upper_arm_r"]),
        ("upper_arm_l", "torso", joints["upper_arm_l"]),
        ("lower_arm_r", "upper_arm_r", joints["lower_arm_r"]),
        ("lower_arm_l", "upper_arm_l", joints["lower_arm_l"]),
        ("hand_r", "lower_arm_r", joints["hand_r"]),
        ("hand_l", "lower_arm_l", joints["hand_l"]),
        ("thigh_r", "torso", joints["thigh_r"]),
        ("thigh_l", "torso", joints["thigh_l"]),
        ("shin_r", "thigh_r", joints["shin_r"]),
        ("shin_l", "thigh_l", joints["shin_l"]),
        ("foot_r", "shin_r", joints["foot_r"]),
        ("foot_l", "shin_l", joints["foot_l"]),
        ("weapon", "hand_r", joints["weapon"]),
    ]
    for child, parent, hint in order:
        rgb, joints[child] = share_under(rgb, parts, welds, child, parent, hint, fg)
    # Hair and eyes meet the face on the neck pixel. No extra disk.
    parts["hair"] = (parts["hair"] | (disk(joints["head"], 4) & parts["head"])) & ~parts["eyes"]
    parts["eyes"] = parts["eyes"] & ndi.binary_dilation(eyes, iterations=1)
    parts["head"] = parts["head"] | (disk(joints["head"], OVERLAP) & fg)

    blades = {}
    for sd in ("R", "L"):
        blades[sd] = axes[sd] & (along[sd] > lengths[sd] * 0.55)
    return rgb, fg, parts, welds, joints, blades


def bbox_of(mask):
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def take_rect(rgb, mask, rect):
    x0, y0, x1, y1 = rect
    patch = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
    patch[..., :3] = rgb[y0:y1, x0:x1]
    alpha = mask[y0:y1, x0:x1]
    patch[..., 3] = np.where(alpha, 255, 0)
    return patch


def mask_image(part, patch_alpha):
    h, w = patch_alpha.shape
    out = np.zeros((h, w, 4), np.uint8)
    on = patch_alpha > 127
    if part == "hair":
        out[on, 1] = 255
    elif part == "eyes":
        out[on, 2] = 255
    elif part.startswith("hand") or part.startswith("head"):
        out[on, 0] = 255
    out[..., 3] = 255
    return out


def save_png(path, arr):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(arr, "RGBA").save(path)


def half(arr):
    im = Image.fromarray(arr, "RGBA")
    w = max(arr.shape[1] // 2, 1)
    h = max(arr.shape[0] // 2, 1)
    return np.asarray(im.resize((w, h), Image.NEAREST))


def weld_image(mask, rect):
    x0, y0, x1, y1 = rect
    patch = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
    on = mask[y0:y1, x0:x1]
    patch[on] = (255, 255, 255, 255)
    return patch


def publish_part(facing, folder, name, rgb, mask, weld, rect, half_root):
    patch = take_rect(rgb, mask, rect)
    rel = os.path.join(facing, folder, f"{name}.png")
    save_png(os.path.join(PUPPET, rel), patch)
    mask_arr = mask_image(name, patch[..., 3])
    save_png(os.path.join(PUPPET, facing, folder, f"{name}_mask.png"), mask_arr)
    weld_arr = weld_image(weld, rect)
    save_png(os.path.join(PUPPET, facing, folder, f"{name}_weld.png"), weld_arr)
    save_png(os.path.join(half_root, rel), half(patch))
    save_png(os.path.join(half_root, facing, folder, f"{name}_mask.png"), half(mask_arr))
    save_png(os.path.join(half_root, facing, folder, f"{name}_weld.png"), half(weld_arr))
    return {
        "origin": [rect[0], rect[1]],
        "size": [int(patch.shape[1]), int(patch.shape[0])],
        "opaque": int((patch[..., 3] > 127).sum()),
    }


def face_variants(head_rgba):
    out = {"f1": head_rgba}
    f2 = head_rgba.copy()
    w = f2.shape[1]
    shade = np.linspace(0.72, 1.0, max(w // 2, 1))
    ramp = np.concatenate([shade, shade[::-1]])
    if ramp.shape[0] < w:
        ramp = np.pad(ramp, (0, w - ramp.shape[0]), constant_values=1)
    ramp = ramp[:w][None, :, None]
    f2[..., :3] = np.clip(f2[..., :3].astype(np.float32) * ramp, 0, 255).astype(np.uint8)
    out["f2"] = f2
    f3 = head_rgba.copy()
    yy, xx = np.indices(f3.shape[:2])
    cx, cy = w * 0.5, f3.shape[0] * 0.55
    glow = np.exp(-(((xx - cx) / (w * 0.28)) ** 2 + ((yy - cy) / (max(f3.shape[0], 1) * 0.28)) ** 2))
    f3[..., :3] = np.clip(f3[..., :3].astype(np.float32) + glow[..., None] * 28, 0, 255).astype(np.uint8)
    out["f3"] = f3
    f4 = head_rgba.copy()
    brow = (yy > f3.shape[0] * 0.28) & (yy < f3.shape[0] * 0.40)
    f4[brow, :3] = (f4[brow, :3].astype(np.float32) * 0.72).astype(np.uint8)
    out["f4"] = f4
    return out


def cut_gear(facing, parts):
    """Same crops as the base. Colours come from that painting, inside the matte."""
    pending = {}
    for family in FAMILIES:
        for slot, names in SLOTS.items():
            path = os.path.join(SRC, f"{family}_{SRC_LETTER[facing]}_{slot}.jpg")
            if not os.path.exists(path):
                continue
            edit = load_rgb(path)
            edit_fg = foreground(edit)
            if slot == "head":
                changed = (np.abs(edit.astype(np.float32) - edit.astype(np.float32)).sum(-1) >= 0)
                # The helm replaces the hair. Keep the cut on the base hair silhouette.
                hair = parts["hair"] & ~parts["eyes"]
                rgb = edit.copy()
                # Sample helm colours only where this painting is actually figure.
                hole = hair & ~edit_fg
                if hole.any():
                    rgb = paint_hole(rgb, edit_fg, hole)
                pending[f"{family}_{slot}"] = {"hair": (rgb, hair)}
                continue
            rgb = edit.copy()
            pending[f"{family}_{slot}"] = {}
            for name in names:
                mask = parts[name]
                hole = mask & ~edit_fg
                if hole.any() and (mask & edit_fg).any():
                    rgb = paint_hole(rgb, mask & edit_fg, hole)
                pending[f"{family}_{slot}"][name] = (rgb, mask)
    return pending


def rest_pose(joints):
    pelvis = joints["hip"]
    pose = {"hip": {"pos": [0, 0], "rot": 0.0, "scale": [1.0, 1.0]}}
    parents = {
        "torso": "hip",
        "head": "torso",
        "hair": "head",
        "eyes": "head",
        "upper_arm_r": "torso",
        "upper_arm_l": "torso",
        "lower_arm_r": "upper_arm_r",
        "lower_arm_l": "upper_arm_l",
        "hand_r": "lower_arm_r",
        "hand_l": "lower_arm_l",
        "weapon": "hand_r",
        "thigh_r": "torso",
        "thigh_l": "torso",
        "shin_r": "thigh_r",
        "shin_l": "thigh_l",
        "foot_r": "shin_r",
        "foot_l": "shin_l",
        "dust": "hip",
    }
    for name, parent in parents.items():
        if name == "dust":
            pose[name] = {"pos": [0, 64], "rot": 0.0, "scale": [1.0, 1.0]}
            continue
        if name not in joints:
            continue
        origin = joints[parent]
        delta = joints[name] - origin
        pose[name] = {
            "pos": [int(round(float(delta[0]))), int(round(float(delta[1])))],
            "rot": 0.0,
            "scale": [1.0, 1.0],
        }
    return pose, parents


def anims():
    def k(t, rot=0.0, sy=1.0, sx=1.0, x=None, y=None, a=None, curve="sine"):
        row = {"t": t, "rot": rot, "sx": sx, "sy": sy, "curve": curve}
        if x is not None:
            row["x"] = x
        if y is not None:
            row["y"] = y
        if a is not None:
            row["a"] = a
        return row

    idle = {
        "length": 3.6,
        "loop": True,
        "tracks": {
            "torso": [k(0, 0, 1.0), k(1.8, 0.02, 1.015), k(3.6, 0, 1.0)],
            "head": [k(0, 0), k(0.9, 0.05), k(1.8, 0.0), k(2.7, -0.04), k(3.6, 0)],
            "hair": [k(0, 0), k(1.2, 0.07), k(2.1, -0.02), k(3.0, 0.05), k(3.6, 0)],
            "upper_arm_r": [k(0, 0), k(1.8, 0.06), k(3.6, 0)],
            "upper_arm_l": [k(0, 0), k(1.8, -0.05), k(3.6, 0)],
            "lower_arm_r": [k(0, 0), k(1.8, 0.04), k(3.6, 0)],
            "lower_arm_l": [k(0, 0), k(1.8, -0.03), k(3.6, 0)],
            "weapon": [k(0, 0), k(2.0, 0.05), k(3.6, 0)],
            "dust": [k(0, a=0), k(3.6, a=0)],
        },
        "secondary": ["hair", "weapon"],
    }
    # The arm carries the axe. The weapon only cocks a little in the hand.
    select = {
        "length": 2.0,
        "loop": False,
        "tracks": {
            "torso": [k(0, 0, 1, curve="ease"), k(0.45, -0.04, 1.02, curve="ease"), k(1.05, 0.06, 0.98, curve="ease"), k(2.0, 0, 1, curve="ease")],
            "head": [k(0, 0, curve="ease"), k(0.45, -0.08, curve="ease"), k(1.05, 0.1, curve="ease"), k(2.0, 0, curve="ease")],
            "upper_arm_r": [k(0, 0, curve="ease"), k(0.5, -1.05, curve="ease"), k(1.05, 0.35, curve="ease"), k(2.0, 0, curve="ease")],
            "lower_arm_r": [k(0, 0, curve="ease"), k(0.5, -0.45, curve="ease"), k(1.05, 0.25, curve="ease"), k(2.0, 0, curve="ease")],
            "upper_arm_l": [k(0, 0, curve="ease"), k(0.5, 0.35, curve="ease"), k(1.05, -0.1, curve="ease"), k(2.0, 0, curve="ease")],
            "weapon": [k(0, 0, curve="ease"), k(0.5, -0.18, curve="ease"), k(1.05, 0.1, curve="ease"), k(2.0, 0, curve="ease")],
            "dust": [k(0, a=0, curve="ease"), k(1.0, a=0, curve="ease"), k(1.15, a=1, curve="ease"), k(1.7, a=0, curve="ease"), k(2.0, a=0, curve="ease")],
        },
        "secondary": [],
    }
    return {"idle": idle, "select": select}


def z_order(facing):
    far = "l"
    near = "r"
    z = {
        f"thigh_{far}": 2,
        f"shin_{far}": 3,
        f"foot_{far}": 4,
        f"upper_arm_{far}": 5,
        f"lower_arm_{far}": 6,
        f"hand_{far}": 7,
        "torso": 10,
        f"thigh_{near}": 12,
        f"shin_{near}": 13,
        f"foot_{near}": 14,
        "head": 20,
        "hair": 21,
        "eyes": 22,
        f"upper_arm_{near}": 30,
        f"lower_arm_{near}": 31,
        f"hand_{near}": 32,
        "weapon": 33,
        "dust": 40,
        "hip": 0,
    }
    if facing == "B":
        # Both arms are in front of the back.
        z["upper_arm_l"] = 16
        z["lower_arm_l"] = 17
        z["hand_l"] = 18
    return z


def dust_sprite():
    size = 96
    arr = np.zeros((size, size, 4), np.uint8)
    yy, xx = np.mgrid[0:size, 0:size]
    for cx, cy, rad, alpha in ((30, 58, 22, 140), (58, 50, 28, 110), (78, 64, 16, 90)):
        blob = np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (rad ** 2)))
        arr[..., 0] = np.maximum(arr[..., 0], (blob * 186).astype(np.uint8))
        arr[..., 1] = np.maximum(arr[..., 1], (blob * 170).astype(np.uint8))
        arr[..., 2] = np.maximum(arr[..., 2], (blob * 140).astype(np.uint8))
        arr[..., 3] = np.maximum(arr[..., 3], (blob * alpha).astype(np.uint8))
    arr[..., 3] = np.where(arr[..., 3] > 40, 255, 0)
    return arr


def figure_span(parts):
    stack = np.zeros(SH, bool)
    for mask in parts.values():
        stack |= mask
    ys = np.nonzero(stack)[0]
    if len(ys) == 0:
        return 1, 0, 0
    return int(ys.max() - ys.min() + 1), int(ys.min()), int(ys.max())


def composite(rgb, parts, order, path):
    canvas = np.zeros((SH[0], SH[1], 4), np.uint8)
    for name, _z in sorted(order.items(), key=lambda kv: kv[1]):
        if name not in parts:
            continue
        mask = parts[name]
        canvas[mask, :3] = rgb[mask]
        canvas[mask, 3] = 255
    Image.fromarray(canvas, "RGBA").resize((512, 288), Image.NEAREST).save(path)


def pivot_of(meta, joint):
    return [int(round(float(joint[0] - meta["origin"][0]))), int(round(float(joint[1] - meta["origin"][1])))]


def build_rig(metas, joints, figure_h, feet_y):
    pose_s, parents = rest_pose(joints["S"])
    pose_b, _ = rest_pose(joints["B"])
    parts = {}
    names = list(parents.keys())
    for name in ["hip"] + [n for n in names if n != "hip"]:
        entry = {
            "parent": "" if name == "hip" else parents.get(name, ""),
            "z": {"S": z_order("S").get(name, 0), "B": z_order("B").get(name, 0)},
            "rest": {
                "S": pose_s.get(name, pose_s["hip"]),
                "B": pose_b.get(name, pose_b["hip"]),
            },
        }
        if name == "hip":
            entry["sprite"] = False
        elif name == "dust":
            entry["sprite"] = True
            entry["file"] = "dust.png"
            entry["pivot"] = {"S": [48, 70], "B": [48, 70]}
        elif name == "head":
            entry["sprite"] = True
            entry["file"] = "head_f1.png"
            entry["faces"] = ["head_f1.png", "head_f2.png", "head_f3.png", "head_f4.png"]
            entry["pivot"] = {
                "S": pivot_of(metas["S"]["head_f1"], joints["S"]["head"]),
                "B": pivot_of(metas["B"]["head_f1"], joints["B"]["head"]),
            }
        else:
            entry["sprite"] = True
            entry["file"] = f"{name}.png"
            entry["pivot"] = {
                "S": pivot_of(metas["S"][name], joints["S"][name]),
                "B": pivot_of(metas["B"][name], joints["B"][name]),
            }
        parts[name] = entry
    pelvis_s = joints["S"]["hip"]
    rig = {
        "format": "stasium.charselect_puppet",
        "format_version": 1,
        "class_id": "ironjaw",
        "gender": "m",
        "soft_test": True,
        "note": "Cut 1:1 from the approved 1024x576 paintings. B is the back view (base_E.jpg). S mirrored is not a third paint.",
        "canvas": [SH[1], SH[0]],
        "source_px": [1024, 576],
        "figure_px": figure_h,
        "feet_from_hip": int(round(float(feet_y - pelvis_s[1]))),
        "overlap_px": OVERLAP,
        "fps": 60,
        "turn": {"order": ["S", "Sm", "B"], "sec": 0.18, "squash": 0.96, "return_s_sec": 4.0, "drag_px": 60},
        "faces": [
            {"id": "broad", "file": "head_f1"},
            {"id": "narrow", "file": "head_f2"},
            {"id": "soft", "file": "head_f3"},
            {"id": "sharp", "file": "head_f4"},
        ],
        "slots": SLOTS,
        "families": list(FAMILIES),
        "parts": parts,
        "anims": anims(),
    }
    return rig


def overlap_report(parts, joints):
    bad = []
    pairs = [
        ("head", "torso"),
        ("upper_arm_r", "torso"),
        ("upper_arm_l", "torso"),
        ("lower_arm_r", "upper_arm_r"),
        ("lower_arm_l", "upper_arm_l"),
        ("hand_r", "lower_arm_r"),
        ("hand_l", "lower_arm_l"),
        ("thigh_r", "torso"),
        ("thigh_l", "torso"),
        ("shin_r", "thigh_r"),
        ("shin_l", "thigh_l"),
        ("foot_r", "shin_r"),
        ("foot_l", "shin_l"),
        ("weapon", "hand_r"),
    ]
    for child, parent in pairs:
        joint = joints[child]
        cx, cy = int(round(float(joint[0]))), int(round(float(joint[1])))
        points = ((cx, cy), (cx + 4, cy), (cx - 4, cy), (cx, cy + 4), (cx, cy - 4))
        for px, py in points:
            inside = 0 <= py < SH[0] and 0 <= px < SH[1]
            if not inside or not parts[child][py, px] or not parts[parent][py, px]:
                bad.append(f"{child}/{parent} hole at {px},{py}")
                break
    return bad


def check_blades(facing, blades, parts):
    """The head of each axe, taken from the painting, has to survive the cut."""
    bad = []
    right = blades["R"]
    left = blades["L"]
    if int(right.sum()) < 350 or not np.all(parts["weapon"][right]):
        bad.append(f"{facing} right head {int(right.sum())} px is not on the weapon")
    if int(left.sum()) < 350 or not np.all(parts["hand_l"][left]):
        bad.append(f"{facing} left head {int(left.sum())} px is not on the left hand")
    for sd, mask in (("R", right), ("L", left)):
        ys, xs = np.nonzero(mask)
        if len(ys) == 0:
            bad.append(f"{facing} {sd} head empty")
            continue
        span = min(int(xs.max() - xs.min()), int(ys.max() - ys.min()))
        if span < 28:
            bad.append(f"{facing} {sd} head span {span}px is a stub")
    return bad


def save_blade_ref(facing, name, blade, rect, half_root):
    patch = weld_image(blade, rect)
    save_png(os.path.join(PUPPET, facing, "base", f"{name}_blade.png"), patch)
    save_png(os.path.join(half_root, facing, "base", f"{name}_blade.png"), half(patch))


def clear_old_faces():
    for folder in ("E", "_1x"):
        path = os.path.join(PUPPET, folder)
        if os.path.isdir(path):
            shutil.rmtree(path)


def main():
    if not os.path.isdir(SRC):
        print("missing sources:", SRC, file=sys.stderr)
        return 1
    clear_old_faces()
    half_root = os.path.join(PUPPET, "_half")
    metas = {}
    joints = {}
    base_parts = {}
    for facing in ("S", "B"):
        rgb, _fg, parts, welds, joint, blades = cut_base(facing)
        holes = overlap_report(parts, joint)
        if holes:
            print(facing, "JOINT HOLES:", "; ".join(holes))
            return 1
        missed = check_blades(facing, blades, parts)
        if missed:
            print(facing, "BLADES:", "; ".join(missed))
            return 1
        base_parts[facing] = parts
        joints[facing] = joint
        pending = cut_gear(facing, parts)
        rects = {}
        for name, mask in parts.items():
            if name == "head":
                continue
            box = bbox_of(mask)
            for pieces in pending.values():
                if name not in pieces:
                    continue
                gbox = bbox_of(pieces[name][1])
                if gbox is None:
                    continue
                if box is None:
                    box = gbox
                else:
                    box = (min(box[0], gbox[0]), min(box[1], gbox[1]), max(box[2], gbox[2]), max(box[3], gbox[3]))
            rects[name] = box
        metas[facing] = {}
        for name, mask in parts.items():
            weld = welds.get(name, np.zeros(SH, bool))
            if name == "head":
                box = bbox_of(mask)
                meta = publish_part(facing, "base", "head_f1", rgb, mask, weld, box, half_root)
            else:
                if rects.get(name) is None:
                    print("empty part", facing, name)
                    return 1
                meta = publish_part(facing, "base", name, rgb, mask, weld, rects[name], half_root)
            if meta is None:
                print("empty part", facing, name)
                return 1
            key = "head_f1" if name == "head" else name
            metas[facing][key] = meta
            if name == "head":
                patch = take_rect(rgb, mask, box)
                for face, arr in face_variants(patch).items():
                    if face == "f1":
                        continue
                    rel_name = f"head_{face}"
                    save_png(os.path.join(PUPPET, facing, "base", f"{rel_name}.png"), arr)
                    msk = mask_image("head", arr[..., 3])
                    save_png(os.path.join(PUPPET, facing, "base", f"{rel_name}_mask.png"), msk)
                    save_png(os.path.join(PUPPET, facing, "base", f"{rel_name}_weld.png"), weld_image(weld, box))
                    save_png(os.path.join(half_root, facing, "base", f"{rel_name}.png"), half(arr))
                    save_png(os.path.join(half_root, facing, "base", f"{rel_name}_mask.png"), half(msk))
                    save_png(os.path.join(half_root, facing, "base", f"{rel_name}_weld.png"), half(weld_image(weld, box)))
                    metas[facing][rel_name] = {
                        "origin": meta["origin"],
                        "size": meta["size"],
                        "opaque": int((arr[..., 3] > 127).sum()),
                    }
        if facing == "S":
            # The Godot test compares these crops to the weapon and the left hand.
            save_blade_ref("S", "weapon", blades["R"], rects["weapon"], half_root)
            save_blade_ref("S", "hand_l", blades["L"], rects["hand_l"], half_root)
        for folder, pieces in pending.items():
            for name, (grgb, gmask) in pieces.items():
                publish_part(facing, folder, name, grgb, gmask, welds.get(name, np.zeros(SH, bool)), rects[name], half_root)
        dust = dust_sprite()
        empty = np.zeros_like(dust)
        for root in (PUPPET, half_root):
            save_png(os.path.join(root, facing, "base", "dust.png"), dust if root == PUPPET else half(dust))
            save_png(os.path.join(root, facing, "base", "dust_mask.png"), empty if root == PUPPET else half(empty))
            save_png(os.path.join(root, facing, "base", "dust_weld.png"), empty if root == PUPPET else half(empty))
        composite(rgb, parts, z_order(facing), f"/tmp/puppet_composite_{facing}.png")
        span, top, bot = figure_span(parts)
        print(f"{facing} figure {span}px  top {top}  feet {bot}  parts {len(parts)}  right head {int(blades['R'].sum())}  left head {int(blades['L'].sum())}")
    span, _top, feet = figure_span(base_parts["S"])
    rig = build_rig(metas, joints, span, feet)
    with open(os.path.join(PUPPET, "rig.json"), "w", encoding="utf-8") as handle:
        json.dump(rig, handle, indent=2)
        handle.write("\n")
    print("wrote", os.path.join(PUPPET, "rig.json"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
