#!/usr/bin/env python3
"""Cut a soft test puppet from the 1024x576 Ironjaw gear sources.

The visible-gear paintings are 1024x576. This script upscales them to
1280x720, the canvas those joints were measured on, and cuts the world-walker
part split: head, hair, eyes, torso, upper and lower arms, hands, thighs,
shins, feet and weapon. Each child part keeps about 12 px of its parent past
the joint so a bend does not open a hole.

Writes the section 8 layout under art/pc/character_select/puppets/ironjaw_m/
(S and E masters, masks, generated _1x copies, rig.json). W is E mirrored
by the scene, not a third paint.

Needs: pillow, numpy, opencv-python-headless, scipy.
"""

from __future__ import annotations

import json
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PUPPET = os.path.join(ROOT, "art", "pc", "character_select", "puppets", "ironjaw_m")
SRC = os.path.join(PUPPET, "source")
SH = (720, 1280)  # height, width of the upscaled painting
OVERLAP = 12
FAMILIES = ("cragmaw", "tyrantjaw", "pitmaw")
SLOTS = {
    "head": ["hair"],
    "chest": ["torso", "upper_arm_l", "upper_arm_r", "lower_arm_l", "lower_arm_r"],
    "legs": ["thigh_l", "thigh_r", "shin_l", "shin_r"],
    "boots": ["foot_l", "foot_r"],
    "weapon": ["weapon"],
}

# Joints on the 1280x720 upscale. R and L are the character's right and left.
# S is the front three-quarter (near arm is R, screen left). E is the back.
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
        "near": "R",
    },
}


def poly(pts, sh=SH):
    im = Image.new("L", (sh[1], sh[0]), 0)
    ImageDraw.Draw(im).polygon([tuple(map(float, p)) for p in pts], fill=1)
    return np.asarray(im) > 0


def seg_dist(a, b, sh=SH):
    yy, xx = np.indices(sh)
    a = np.asarray(a, float)
    b = np.asarray(b, float)
    d = b - a
    t = np.clip(((xx - a[0]) * d[0] + (yy - a[1]) * d[1]) / max(float((d ** 2).sum()), 1e-9), 0, 1)
    return np.hypot(xx - (a[0] + t * d[0]), yy - (a[1] + t * d[1]))


def clean(mask, k=40):
    lab, n = ndi.label(mask, np.ones((3, 3)))
    if n == 0:
        return mask
    sizes = np.bincount(lab.ravel())
    sizes[0] = 0
    return np.isin(lab, np.nonzero(sizes > k)[0])


def load_rgb(path):
    return np.asarray(Image.open(path).convert("RGB").resize((SH[1], SH[0]), Image.LANCZOS))


def bg_colour(rgb):
    edge = np.concatenate([
        rgb[:24].reshape(-1, 3),
        rgb[-24:].reshape(-1, 3),
        rgb[:, :24].reshape(-1, 3),
        rgb[:, -24:].reshape(-1, 3),
    ])
    return np.median(edge, 0)


def foreground(rgb, th=34.0):
    d = np.abs(rgb.astype(np.float32) - bg_colour(rgb)).sum(-1)
    d = cv2.GaussianBlur(d, (0, 0), 0.8)
    m = ndi.binary_opening(d > th, iterations=1)
    m = ndi.binary_fill_holes(ndi.binary_closing(m, iterations=2))
    lab, _n = ndi.label(m, np.ones((3, 3)))
    sizes = np.bincount(lab.ravel())
    sizes[0] = 0
    return np.isin(lab, np.nonzero(sizes > 3000)[0])


def disk(joint, radius, sh=SH):
    yy, xx = np.indices(sh)
    return np.hypot(xx - joint[0], yy - joint[1]) <= radius


def fill_from(rgb, mask, hole):
    """Paint hole pixels with the nearest colour already in mask."""
    if not hole.any() or not mask.any():
        return rgb, mask
    _dist, (iy, ix) = ndi.distance_transform_edt(~mask, return_indices=True)
    out = rgb.copy()
    out[hole] = rgb[iy[hole], ix[hole]]
    grown = mask | hole
    return out, grown


def seal(rgb, mask, joint, radius=OVERLAP):
    """Keep a solid disk at the joint so a bend cannot open a hole."""
    blob = disk(joint, radius) & ~mask
    # Only seal through the figure, not out into the empty backdrop.
    near = disk(joint, radius + 8)
    if mask[near].sum() < 8:
        return rgb, mask
    return fill_from(rgb, mask, blob & ndi.binary_dilation(mask, iterations=radius))


def bridge(rgb, parent, child, hint, radius=OVERLAP):
    """Share a disk at the hinted joint. The pivot stays on that hint."""
    hint = np.asarray(hint, float)
    if not parent.any() or not child.any() or parent is child:
        return rgb, parent, child, hint
    hx, hy = int(round(hint[0])), int(round(hint[1]))
    hx = int(np.clip(hx, 0, SH[1] - 1))
    hy = int(np.clip(hy, 0, SH[0] - 1))
    pdist = ndi.distance_transform_edt(~parent)
    cdist = ndi.distance_transform_edt(~child)
    gap = float(pdist[hy, hx] + cdist[hy, hx])
    # Reach the pieces, then keep the 12 px overlap. Cap the disk so a
    # missed hint cannot paint a blob across the figure.
    radius = int(min(36, max(radius, gap / 2.0 + OVERLAP)))
    joint = np.array([float(hx), float(hy)])
    rgb, parent = seal(rgb, parent, joint, radius)
    rgb, child = seal(rgb, child, joint, radius)
    return rgb, parent, child, joint


def overlap_child(rgb, child, parent, joint, parent_joint):
    """Copy about 12 px of the parent onto the child, on the parent's side."""
    direction = np.asarray(parent_joint, float) - np.asarray(joint, float)
    norm = float(np.linalg.norm(direction))
    if norm < 1:
        direction = np.array([0.0, -1.0])
    else:
        direction = direction / norm
    yy, xx = np.indices(SH)
    rel = np.stack([xx - joint[0], yy - joint[1]], -1)
    along = rel[..., 0] * direction[0] + rel[..., 1] * direction[1]
    extra = parent & (np.hypot(xx - joint[0], yy - joint[1]) <= OVERLAP + 2) & (along >= -2)
    rgb, child = fill_from(rgb, child, extra & ~child)
    return rgb, child | extra


def side_name(sd):
    return "r" if sd == "R" else "l"


def arm_pieces(facing, fg, head, rgb):
    """Upper arm, lower arm, hand and axe for each side."""
    c = CFG[facing]
    yy, xx = np.indices(SH)
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(np.float32)
    chroma = np.hypot(lab[..., 1] - 128, lab[..., 2] - 128)
    steel = fg & (chroma < 16) & (lab[..., 0] > 70) & (lab[..., 0] < 210)
    out = {}
    for sd, joint in c["arms"].items():
        shoulder = np.asarray(joint["shoulder"], float)
        elbow = np.asarray(joint["elbow"], float)
        grip = np.asarray(joint["grip"], float)
        eye = np.asarray(joint["eye"], float)
        ru, rf = joint["r"]
        upper_band = seg_dist(shoulder, elbow) < ru
        fore_band = (seg_dist(elbow, grip) < rf) | (np.hypot(xx - grip[0], yy - grip[1]) < rf * 1.25)
        uu = (elbow - shoulder) / np.linalg.norm(elbow - shoulder)
        uf = (grip - elbow) / np.linalg.norm(grip - elbow)
        ub = uu + uf
        ub = ub / np.linalg.norm(ub)
        past_elbow = ((xx - elbow[0]) * ub[0] + (yy - elbow[1]) * ub[1]) > 0
        haft = seg_dist(grip, eye) < 14
        axe = fg & ~head & (haft | (steel & (seg_dist(grip, eye) < 36) & (np.hypot(xx - grip[0], yy - grip[1]) > rf * 0.55)))
        axe = clean(axe, 30)
        hand = fg & ~head & ~axe & (np.hypot(xx - grip[0], yy - grip[1]) < rf * 1.15)
        hand = clean(hand, 20)
        lower = fg & ~head & ~hand & ~axe & fore_band & past_elbow
        lower = clean(lower, 40)
        upper = fg & ~head & upper_band & ~past_elbow & ~lower & ~hand & ~axe
        upper = clean(upper, 40)
        out[sd] = {"upper": upper, "lower": lower, "hand": hand, "axe": axe}
    return out


def split_head(rgb, head):
    """Face skin, hair (and beard) and the two eyes."""
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
    # Eyes sit in the upper half of the skin, as the darkest small marks.
    eye_band = skin & (yy > y0 + int(height * 0.28)) & (yy < y0 + int(height * 0.55))
    dark_eyes = eye_band & (lab[..., 0] < 90)
    dark_eyes = clean(dark_eyes, 4)
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
    # Keep the painted eyes under the face so the eye sprite has something to cover.
    skin = skin | eyes
    return skin, hair, eyes


def leg_chain(fg, hip, pelvis, other_hip):
    """Walk down one leg and return hip, knee, ankle and toe points."""
    hip = np.asarray(hip, float)
    other = np.asarray(other_hip, float)
    mid_x = (hip[0] + other[0]) * 0.5
    go_right = hip[0] >= other[0]
    yy, xx = np.indices(SH)
    column = fg & (yy >= hip[1] - 8)
    if go_right:
        column &= xx >= mid_x - 6
    else:
        column &= xx <= mid_x + 6
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
        toe = np.array([hip[0], min(hip[1] + 180, SH[0] - 8)])
        knee = hip + (toe - hip) * 0.42
        ankle = hip + (toe - hip) * 0.78
        return hip, knee, ankle, toe
    pts = np.asarray(centers)
    hip_p = pts[0]
    toe = pts[-1]
    knee = pts[int(len(pts) * 0.40)]
    ankle = pts[int(len(pts) * 0.78)]
    return hip_p, knee, ankle, toe


def bone_mask(fg, a, b, radius):
    return fg & (seg_dist(a, b) <= radius)


def cut_base(facing):
    rgb = load_rgb(os.path.join(SRC, f"base_{facing}.jpg"))
    fg = foreground(rgb)
    c = CFG[facing]
    head_region = poly(c["head"]) & fg
    skin, hair, eyes = split_head(rgb, head_region)
    arms = arm_pieces(facing, fg, head_region, rgb)
    arm_all = np.zeros(SH, bool)
    axe_all = np.zeros(SH, bool)
    for piece in arms.values():
        arm_all |= piece["upper"] | piece["lower"] | piece["hand"]
        axe_all |= piece["axe"]
    torso_region = poly(c["torso"])
    pelvis = np.asarray(c["pelvis"], float)
    hem = int(pelvis[1] + 36)
    yy, _xx = np.indices(SH)
    tunic = fg & torso_region & ~arm_all & ~head_region & ~axe_all & (yy <= hem)
    tunic = clean(tunic, 80)
    # Close the holes the arms and axes leave in the tunic and the legs.
    arm_hole = torso_region & (yy <= hem + 8) & ~tunic & ~head_region & ndi.binary_dilation(arm_all | axe_all, iterations=2)
    rgb, tunic = fill_from(rgb, tunic, arm_hole & ~fg | (arm_hole & (arm_all | axe_all)))
    tunic = clean(tunic, 40)

    hips = c["hips"]
    legs = {}
    for sd, hip in hips.items():
        other = hips["L" if sd == "R" else "R"]
        hip_p, knee, ankle, toe = leg_chain(fg & ~axe_all, hip, pelvis, other)
        thigh = bone_mask(fg & ~axe_all & ~tunic & ~head_region, hip_p, knee, 28)
        shin = bone_mask(fg & ~axe_all & ~tunic & ~head_region, knee, ankle, 24) & ~thigh
        foot = bone_mask(fg & ~axe_all, ankle, toe, 26) & ~thigh & ~shin
        # Fill axe holes in the leg so the weapon can move without a gap.
        leg_union = thigh | shin | foot
        hole = ndi.binary_dilation(leg_union, iterations=6) & axe_all & (yy > hem - 10)
        rgb, filled = fill_from(rgb, leg_union, hole)
        thigh = thigh | (filled & bone_mask(np.ones(SH, bool), hip_p, knee, 28) & hole)
        shin = shin | (filled & bone_mask(np.ones(SH, bool), knee, ankle, 24) & hole & ~thigh)
        foot = foot | (filled & ~thigh & ~shin & hole)
        legs[sd] = {
            "thigh": clean(thigh, 30),
            "shin": clean(shin, 20),
            "foot": clean(foot, 20),
            "hip": hip_p,
            "knee": knee,
            "ankle": ankle,
            "toe": toe,
        }

    weapon = clean(axe_all, 20)
    parts = {
        "head": skin | eyes,
        "hair": hair,
        "eyes": eyes,
        "torso": tunic,
        "weapon": weapon,
    }
    joints = {
        "head": np.asarray(c["neck"], float),
        "hair": np.asarray(c["neck"], float),
        "eyes": np.asarray(c["neck"], float),
        "torso": pelvis,
        "weapon": np.asarray(c["arms"]["R"]["grip"], float),
    }
    parents = {
        "head": "torso",
        "hair": "head",
        "eyes": "head",
        "torso": "hip",
        "weapon": "hand_r",
    }
    for sd, piece in arms.items():
        name = side_name(sd)
        parts[f"upper_arm_{name}"] = piece["upper"]
        parts[f"lower_arm_{name}"] = piece["lower"]
        parts[f"hand_{name}"] = piece["hand"]
        joints[f"upper_arm_{name}"] = np.asarray(c["arms"][sd]["shoulder"], float)
        joints[f"lower_arm_{name}"] = np.asarray(c["arms"][sd]["elbow"], float)
        joints[f"hand_{name}"] = np.asarray(c["arms"][sd]["grip"], float)
        parents[f"upper_arm_{name}"] = "torso"
        parents[f"lower_arm_{name}"] = f"upper_arm_{name}"
        parents[f"hand_{name}"] = f"lower_arm_{name}"
    for sd, piece in legs.items():
        name = side_name(sd)
        parts[f"thigh_{name}"] = piece["thigh"]
        parts[f"shin_{name}"] = piece["shin"]
        parts[f"foot_{name}"] = piece["foot"]
        joints[f"thigh_{name}"] = np.asarray(piece["hip"], float)
        joints[f"shin_{name}"] = np.asarray(piece["knee"], float)
        joints[f"foot_{name}"] = np.asarray(piece["ankle"], float)
        parents[f"thigh_{name}"] = "hip"
        parents[f"shin_{name}"] = f"thigh_{name}"
        parents[f"foot_{name}"] = f"shin_{name}"

    joints["hip"] = pelvis
    # The neck is hair in the painting. Give the face, the hair and the tunic
    # the same 12 px disk there so the head cannot lift off the shoulders.
    neck = np.asarray(c["neck"], float)
    neck_disk = disk(neck, OVERLAP)
    for neck_part in ("head", "hair", "torso"):
        rgb, parts[neck_part] = fill_from(rgb, parts[neck_part], neck_disk & ~parts[neck_part])
    # Meet each child with its parent and keep about 12 px of shared paint.
    order = [
        ("torso", "hip"),
        ("head", "torso"),
        ("hair", "head"),
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
    for name, parent in order:
        if parent == "hip":
            rgb, parts[name] = seal(rgb, parts[name], joints[name])
            continue
        rgb, parts[parent], parts[name], joints[name] = bridge(
            rgb, parts[parent], parts[name], joints[name]
        )
    # Eyes stay a layer on the face. Hair stays off the eye pixels.
    parts["eyes"] = parts["eyes"] & ndi.binary_dilation(eyes, iterations=1)
    parts["hair"] = parts["hair"] & ~parts["eyes"]
    return rgb, parts, joints, parents


def crop(rgb, mask):
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        return None
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    patch = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
    cut = rgb[y0:y1, x0:x1]
    alpha = mask[y0:y1, x0:x1]
    patch[..., :3] = cut
    patch[..., 3] = np.where(alpha, 255, 0)
    return patch, (x0, y0)


def mask_image(part, patch_alpha):
    """R skin, G hair, B eyes. Clothes stay black."""
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


def write_part(facing, folder, name, rgb, mask, one_x_root):
    cropped = crop(rgb, mask)
    if cropped is None:
        return None
    patch, origin = cropped
    # Binary alpha. The cut is already a hard mask.
    patch[..., 3] = np.where(patch[..., 3] > 127, 255, 0)
    rel = os.path.join(facing, folder, f"{name}.png")
    save_png(os.path.join(PUPPET, rel), patch)
    mask_arr = mask_image(name, patch[..., 3])
    save_png(os.path.join(PUPPET, facing, folder, f"{name}_mask.png"), mask_arr)
    save_png(os.path.join(one_x_root, rel), half(patch))
    save_png(os.path.join(one_x_root, facing, folder, f"{name}_mask.png"), half(mask_arr))
    return {"origin": origin, "size": [int(patch.shape[1]), int(patch.shape[0])], "opaque": int((patch[..., 3] > 127).sum())}


def face_variants(head_rgba):
    """Four test faces, same pixels size and same pivot. Soft, not a repaint."""
    out = {"f1": head_rgba}
    # f2 narrow: shade the sides of the face.
    f2 = head_rgba.copy()
    w = f2.shape[1]
    shade = np.linspace(0.72, 1.0, w // 2)
    ramp = np.concatenate([shade, shade[::-1]])
    if ramp.shape[0] < w:
        ramp = np.pad(ramp, (0, w - ramp.shape[0]), constant_values=1)
    ramp = ramp[:w][None, :, None]
    rgb = f2[..., :3].astype(np.float32) * ramp
    f2[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out["f2"] = f2
    # f3 soft: lift the mid cheeks.
    f3 = head_rgba.copy()
    yy, xx = np.indices(f3.shape[:2])
    cx, cy = w * 0.5, f3.shape[0] * 0.55
    glow = np.exp(-(((xx - cx) / (w * 0.28)) ** 2 + ((yy - cy) / (f3.shape[0] * 0.28)) ** 2))
    lifted = f3[..., :3].astype(np.float32) + glow[..., None] * 28
    f3[..., :3] = np.clip(lifted, 0, 255).astype(np.uint8)
    out["f3"] = f3
    # f4 sharp: a darker brow band.
    f4 = head_rgba.copy()
    brow = (yy > f3.shape[0] * 0.28) & (yy < f3.shape[0] * 0.40)
    f4[brow, :3] = (f4[brow, :3].astype(np.float32) * 0.72).astype(np.uint8)
    out["f4"] = f4
    return out


def look_mask(base_rgb, edit_rgb, region):
    b = cv2.GaussianBlur(base_rgb.astype(np.float32), (0, 0), 1.6)
    e = cv2.GaussianBlur(edit_rgb.astype(np.float32), (0, 0), 1.6)
    changed = (np.abs(e - b).sum(-1) > 42) & region & foreground(edit_rgb)
    changed = ndi.binary_fill_holes(ndi.binary_closing(clean(changed, 40), iterations=2))
    return changed & foreground(edit_rgb)


def cut_gear(facing, base_rgb, parts):
    """Each worn piece replaces the base parts in its zone. No base cloth remains there."""
    pending = {}
    for family in FAMILIES:
        for slot, names in SLOTS.items():
            path = os.path.join(SRC, f"{family}_{facing}_{slot}.jpg")
            if not os.path.exists(path):
                continue
            edit = load_rgb(path)
            if slot == "head":
                # The helm replaces the hair. The face stays the base head.
                changed = look_mask(base_rgb, edit, ndi.binary_dilation(parts["hair"], iterations=8))
                rgb = edit.copy()
                rgb, hair = fill_from(rgb, changed, parts["hair"] & ~changed & ~foreground(edit))
                hair = (hair | parts["hair"]) & ~parts["eyes"]
                face = parts["head"] & ~parts["hair"]
                hair = hair & ~ndi.binary_erosion(face, iterations=1)
                # Keep every base hair pixel, and any helm pixel past it.
                hair = clean(hair | parts["hair"], 10) & ~parts["eyes"]
                pending[f"{family}_{slot}"] = {"hair": (rgb, hair)}
            else:
                # The one-piece painting already wears this slot, on the same
                # silhouette as the base, so the crop and the pivot match.
                rgb = edit.copy()
                pending[f"{family}_{slot}"] = {name: (rgb, parts[name]) for name in names}
    return pending


def bbox_of(mask):
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def take_rect(rgb, mask, rect):
    x0, y0, x1, y1 = rect
    patch = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
    cut = rgb[y0:y1, x0:x1]
    alpha = mask[y0:y1, x0:x1]
    patch[..., :3] = cut
    patch[..., 3] = np.where(alpha, 255, 0)
    return patch


def publish_part(facing, folder, name, rgb, mask, rect, one_x):
    patch = take_rect(rgb, mask, rect)
    rel = os.path.join(facing, folder, f"{name}.png")
    save_png(os.path.join(PUPPET, rel), patch)
    mask_arr = mask_image(name, patch[..., 3])
    save_png(os.path.join(PUPPET, facing, folder, f"{name}_mask.png"), mask_arr)
    save_png(os.path.join(one_x, rel), half(patch))
    save_png(os.path.join(one_x, facing, folder, f"{name}_mask.png"), half(mask_arr))
    return {"origin": [rect[0], rect[1]], "size": [int(patch.shape[1]), int(patch.shape[0])], "opaque": int((patch[..., 3] > 127).sum())}


def rest_pose(joints):
    pelvis = joints["hip"]
    pose = {"hip": {"pos": [0.0, 0.0], "rot": 0.0, "scale": [1.0, 1.0]}}
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
        "thigh_r": "hip",
        "thigh_l": "hip",
        "shin_r": "thigh_r",
        "shin_l": "thigh_l",
        "foot_r": "shin_r",
        "foot_l": "shin_l",
        "dust": "hip",
    }
    for name, parent in parents.items():
        if name == "dust":
            pose[name] = {"pos": [0.0, 80.0], "rot": 0.0, "scale": [1.0, 1.0]}
            continue
        if name not in joints:
            continue
        origin = pelvis if parent == "hip" else joints[parent]
        delta = joints[name] - origin
        pose[name] = {"pos": [round(float(delta[0]), 2), round(float(delta[1]), 2)], "rot": 0.0, "scale": [1.0, 1.0]}
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
    select = {
        "length": 2.0,
        "loop": False,
        "tracks": {
            "torso": [k(0, 0, 1, curve="ease"), k(0.45, -0.04, 1.02, curve="ease"), k(1.05, 0.06, 0.98, curve="ease"), k(2.0, 0, 1, curve="ease")],
            "head": [k(0, 0, curve="ease"), k(0.45, -0.08, curve="ease"), k(1.05, 0.1, curve="ease"), k(2.0, 0, curve="ease")],
            "upper_arm_r": [k(0, 0, curve="ease"), k(0.5, -1.05, curve="ease"), k(1.05, 0.35, curve="ease"), k(2.0, 0, curve="ease")],
            "lower_arm_r": [k(0, 0, curve="ease"), k(0.5, -0.45, curve="ease"), k(1.05, 0.25, curve="ease"), k(2.0, 0, curve="ease")],
            "upper_arm_l": [k(0, 0, curve="ease"), k(0.5, 0.35, curve="ease"), k(1.05, -0.1, curve="ease"), k(2.0, 0, curve="ease")],
            "weapon": [k(0, 0, curve="ease"), k(0.5, -0.9, curve="ease"), k(1.05, 0.45, curve="ease"), k(2.0, 0, curve="ease")],
            "dust": [k(0, a=0, curve="ease"), k(1.0, a=0, curve="ease"), k(1.15, a=1, curve="ease"), k(1.7, a=0, curve="ease"), k(2.0, a=0, curve="ease")],
        },
        "secondary": [],
    }
    return {"idle": idle, "select": select}


def z_order(facing):
    # Far limbs sit behind the torso. The near arm and the weapon sit in front.
    far = "l" if facing == "S" else "l"
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
    if facing == "E":
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


def composite(rgb, parts, joints, order, path):
    canvas = np.zeros((SH[0], SH[1], 4), np.uint8)
    for name, _z in sorted(order.items(), key=lambda kv: kv[1]):
        if name not in parts:
            continue
        mask = parts[name]
        canvas[mask, :3] = rgb[mask]
        canvas[mask, 3] = 255
    Image.fromarray(canvas, "RGBA").resize((640, 360), Image.NEAREST).save(path)


def pivot_of(meta, joint):
    return [round(float(joint[0] - meta["origin"][0]), 2), round(float(joint[1] - meta["origin"][1]), 2)]


def build_rig(metas, joints, figure_h, feet_y):
    pose_s, parents = rest_pose(joints["S"])
    pose_e, _ = rest_pose(joints["E"])
    parts = {}
    names = list(parents.keys())
    for name in ["hip"] + names:
        entry = {
            "parent": "" if name == "hip" else parents.get(name, ""),
            "z": {"S": z_order("S").get(name, 0), "E": z_order("E").get(name, 0)},
            "rest": {"S": pose_s.get(name, pose_s["hip"]), "E": pose_e.get(name, pose_e["hip"])},
        }
        if name == "hip":
            entry["sprite"] = False
        elif name == "dust":
            entry["sprite"] = True
            entry["file"] = "dust.png"
            entry["pivot"] = {"S": [48, 70], "E": [48, 70]}
        elif name == "head":
            entry["sprite"] = True
            entry["file"] = "head_f1.png"
            entry["faces"] = ["head_f1.png", "head_f2.png", "head_f3.png", "head_f4.png"]
            entry["pivot"] = {
                "S": pivot_of(metas["S"]["head_f1"], joints["S"]["head"]),
                "E": pivot_of(metas["E"]["head_f1"], joints["E"]["head"]),
            }
        else:
            entry["sprite"] = True
            entry["file"] = f"{name}.png"
            entry["pivot"] = {
                "S": pivot_of(metas["S"][name], joints["S"][name]),
                "E": pivot_of(metas["E"][name], joints["E"][name]),
            }
        parts[name] = entry
    pelvis_s = joints["S"]["hip"]
    rig = {
        "format": "stasium.charselect_puppet",
        "format_version": 1,
        "class_id": "ironjaw",
        "gender": "m",
        "soft_test": True,
        "note": "Cut from the 1024x576 visible-gear sources. Soft on purpose. The real 2x puppet is P4.",
        "canvas": [SH[1], SH[0]],
        "source_px": [1024, 576],
        "figure_px": figure_h,
        "feet_from_hip": round(float(feet_y - pelvis_s[1]), 2),
        "overlap_px": OVERLAP,
        "fps": 60,
        "turn": {"order": ["S", "E", "W"], "sec": 0.18, "squash": 0.96, "return_s_sec": 4.0, "drag_px": 60},
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
        blob = disk(joint, 6)
        both = parts[child] & parts[parent] & blob
        if both.sum() < 8:
            bad.append(f"{child}/{parent} overlap {int(both.sum())}")
    return bad


def main():
    if not os.path.isdir(SRC):
        print("missing sources:", SRC, file=sys.stderr)
        return 1
    one_x = os.path.join(PUPPET, "_1x")
    metas = {}
    joints = {}
    base_rgb = {}
    base_parts = {}
    for facing in ("S", "E"):
        rgb, parts, joint, _parents = cut_base(facing)
        base_rgb[facing] = rgb
        base_parts[facing] = parts
        joints[facing] = joint
        holes = overlap_report(parts, joint)
        if holes:
            print(facing, "JOINT HOLES:", "; ".join(holes))
            return 1
        pending = cut_gear(facing, rgb, parts)
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
            if name == "head":
                meta = write_part(facing, "base", "head_f1", rgb, mask, one_x)
            else:
                if rects.get(name) is None:
                    print("empty part", facing, name)
                    return 1
                meta = publish_part(facing, "base", name, rgb, mask, rects[name], one_x)
            if meta is None:
                print("empty part", facing, name)
                return 1
            metas[facing]["head_f1" if name == "head" else name] = meta
            if name == "head":
                cropped = crop(rgb, mask)
                variants = face_variants(cropped[0])
                for face, arr in variants.items():
                    if face == "f1":
                        continue
                    rel_name = f"head_{face}"
                    save_png(os.path.join(PUPPET, facing, "base", f"{rel_name}.png"), arr)
                    msk = mask_image("head", arr[..., 3])
                    save_png(os.path.join(PUPPET, facing, "base", f"{rel_name}_mask.png"), msk)
                    save_png(os.path.join(one_x, facing, "base", f"{rel_name}.png"), half(arr))
                    save_png(os.path.join(one_x, facing, "base", f"{rel_name}_mask.png"), half(msk))
                    metas[facing][rel_name] = {
                        "origin": meta["origin"],
                        "size": meta["size"],
                        "opaque": int((arr[..., 3] > 127).sum()),
                    }
        for folder, pieces in pending.items():
            for name, (grgb, gmask) in pieces.items():
                publish_part(facing, folder, name, grgb, gmask, rects[name], one_x)
        dust = dust_sprite()
        save_png(os.path.join(PUPPET, facing, "base", "dust.png"), dust)
        save_png(os.path.join(PUPPET, facing, "base", "dust_mask.png"), np.zeros_like(dust))
        save_png(os.path.join(one_x, facing, "base", "dust.png"), half(dust))
        save_png(os.path.join(one_x, facing, "base", "dust_mask.png"), half(np.zeros_like(dust)))
        composite(rgb, parts, joint, z_order(facing), f"/tmp/puppet_composite_{facing}.png")
        span, top, bot = figure_span(parts)
        print(f"{facing} figure {span}px  top {top}  feet {bot}  parts {len(parts)}")
    span, _top, feet = figure_span(base_parts["S"])
    rig = build_rig(metas, joints, span, feet)
    with open(os.path.join(PUPPET, "rig.json"), "w", encoding="utf-8") as handle:
        json.dump(rig, handle, indent=2)
        handle.write("\n")
    print("wrote", os.path.join(PUPPET, "rig.json"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
