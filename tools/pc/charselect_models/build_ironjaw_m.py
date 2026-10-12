# Builds the Ironjaw male character-select GLB (package P4).
#
#   /path/to/blender --background --python tools/pc/charselect_models/build_ironjaw_m.py
#
# Blender 4.2 LTS. Tested with 4.2.23. The script is deterministic.
#
# Writes:
#   art/pc/characters_3d/ironjaw/ironjaw_m.glb
#   art/pc/characters_3d/ironjaw/albedo.png
#   art/pc/characters_3d/ironjaw/mask.png
#   art/pc/characters_3d/ironjaw/dye_mask.png
#   art/pc/characters_3d/ironjaw/manifest.json
#   art/pc/characters_3d/ironjaw/uv_layout.json
#   art/pc/characters_3d/ironjaw/gear/cragmaw_<slot>.glb
#
# Coordinates while authoring: Blender Z-up, character faces -Y.
# glTF export converts that to Godot Y-up, facing +Z, feet at the origin.
#
# Mask: R = skin, G = hair, B = eyes. Cloth, leather, and metal stay black.
# No armour colours are authored as recolour channels. dye_mask is white
# only on Cragmaw, and the stage leaves dye disabled.
#
# Not built here (hooks only — see manifest.json "not_built"):
#   ironjaw_f.glb, the other four classes, Tyrantjaw, Pitmaw,
#   extra hairstyles (hair is the single mesh base_head).

import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT_DIR = os.path.join(ROOT, "art", "pc", "characters_3d", "ironjaw")
GEAR_DIR = os.path.join(OUT_DIR, "gear")
TEX = 2048

# Atlas rects, Blender UV (v = 0 at the bottom of the image). Gutters stay
# empty so dilation cannot bleed one island into the next.
RECTS = {
    "skin_head": (0.02, 0.52, 0.32, 0.98),
    "skin_body": (0.34, 0.72, 0.52, 0.98),
    "hair": (0.54, 0.72, 0.76, 0.98),
    "eyes": (0.80, 0.86, 0.96, 0.98),
    "sclera": (0.80, 0.72, 0.96, 0.84),
    "mouth": (0.54, 0.58, 0.70, 0.70),
    "tunic": (0.02, 0.28, 0.36, 0.50),
    "trousers": (0.38, 0.28, 0.66, 0.50),
    "leather": (0.68, 0.36, 0.98, 0.50),
    "steel": (0.02, 0.02, 0.40, 0.24),
    "blade": (0.42, 0.02, 0.64, 0.24),
    "leather_armor": (0.66, 0.02, 0.82, 0.16),
    "red": (0.84, 0.02, 0.98, 0.16),
}

# Neutral-grey skin / hair / eyes so lum * 2 * tint stays near the swatch.
# Cloth and metal are the real colours (mask black, not recoloured).
SKIN = (0.55, 0.50, 0.46)
HAIR_COL = (0.48, 0.46, 0.44)
EYE_COL = (0.70, 0.70, 0.70)
SCLERA_COL = (0.86, 0.82, 0.78)
MOUTH_COL = (0.42, 0.20, 0.18)
TUNIC = (0.80, 0.72, 0.58)
WOOL = (0.40, 0.27, 0.18)
LEATHER = (0.46, 0.30, 0.18)
IRON = (0.40, 0.38, 0.36)
STEEL = (0.32, 0.35, 0.40)
RED = (0.58, 0.16, 0.13)

MASK_SKIN = (1.0, 0.0, 0.0)
MASK_HAIR = (0.0, 1.0, 0.0)
MASK_EYES = (0.0, 0.0, 1.0)
MASK_OFF = (0.0, 0.0, 0.0)

NOT_BUILT = [
    "ironjaw_f.glb — female, same slot names, narrower shoulders, wider hips, height about 1.78",
    "face types stay face_<n>_* (this file ships 4). A later atlas can use the face_index uniform",
    "hairstyles — base_head is the only hair mesh. A later pass can split it the way faces are split",
    "kestrel, bastion, gloam, mender — same pipeline, own proportions and weapon",
    "Tyrantjaw and Pitmaw — further gear sets. Cragmaw is the only set in this trial",
]


def _rect(name):
    return RECTS[name]


class MeshBuilder:
    def __init__(self, name, smooth=True):
        self.name = name
        self.smooth = smooth
        self.flat = not smooth
        self.albedo = (0.5, 0.5, 0.5)
        self.mask = MASK_OFF
        self.dye = 0.0
        self.weave = "none"
        self.verts = []
        self.uvs = []
        self.weights = []
        self.faces = []
        self.face_albedo = []
        self.face_mask = []
        self.face_dye = []
        self.face_weave = []

    def v(self, co, uv, weight):
        if isinstance(weight, str):
            weight = {weight: 1.0}
        self.verts.append(Vector(co))
        self.uvs.append((float(uv[0]), float(uv[1])))
        self.weights.append(dict(weight))
        return len(self.verts) - 1

    def tri(self, a, b, c):
        if len({a, b, c}) < 3:
            return
        self.faces.append((a, b, c))
        self.face_albedo.append(tuple(self.albedo))
        self.face_mask.append(tuple(self.mask))
        self.face_dye.append(float(self.dye))
        self.face_weave.append(self.weave)

    def quad(self, a, b, c, d):
        self.tri(a, b, c)
        self.tri(a, c, d)

    def outward_fix(self, start, interior):
        interior = Vector(interior)
        for i in range(start, len(self.faces)):
            a, b, c = self.faces[i]
            fn = (self.verts[b] - self.verts[a]).cross(self.verts[c] - self.verts[a])
            if fn.length < 1e-10:
                continue
            centroid = (self.verts[a] + self.verts[b] + self.verts[c]) / 3.0
            if fn.dot(centroid - interior) < 0.0:
                for j in range(start, len(self.faces)):
                    aa, bb, cc = self.faces[j]
                    self.faces[j] = (aa, cc, bb)
            return

    def compute_normals(self):
        acc = [Vector((0.0, 0.0, 0.0)) for _ in self.verts]
        for a, b, c in self.faces:
            fn = (self.verts[b] - self.verts[a]).cross(self.verts[c] - self.verts[a])
            acc[a] += fn
            acc[b] += fn
            acc[c] += fn
        out = []
        for n in acc:
            out.append(n.normalized() if n.length > 1e-10 else Vector((0.0, -1.0, 0.0)))
        self.normals = out


def blend_w(a, b, t):
    keys = set(a) | set(b)
    return {k: a.get(k, 0.0) * (1.0 - t) + b.get(k, 0.0) * t for k in keys}


def ellipse_ring(z, rx, ry, y0, front_push, sides):
    pts = []
    for s in range(sides + 1):
        ang = math.tau * (s % sides) / sides + math.pi / 2.0
        x = math.cos(ang) * rx
        y = math.sin(ang) * ry + y0
        if math.sin(ang) < 0.0:
            y += math.sin(ang) * front_push
        pts.append(Vector((x, y, z)))
    return pts


def add_loft(mb, rings, rect, weight_list, interior, cap_bottom=False, cap_top=False):
    start = len(mb.faces)
    u0, v0, u1, v1 = rect
    sides = len(rings[0]) - 1
    ids = []
    for ri, ring in enumerate(rings):
        v = v0 + (ri / (len(rings) - 1)) * (v1 - v0)
        row = []
        for s, p in enumerate(ring):
            u = u0 + (s / sides) * (u1 - u0)
            row.append(mb.v(p, (u, v), weight_list[ri]))
        ids.append(row)
    for ri in range(len(rings) - 1):
        for s in range(sides):
            mb.quad(ids[ri][s], ids[ri][s + 1], ids[ri + 1][s + 1], ids[ri + 1][s])
    if cap_bottom:
        c = sum(rings[0], Vector()) / len(rings[0])
        ci = mb.v(c, ((u0 + u1) * 0.5, v0), weight_list[0])
        for s in range(sides):
            mb.tri(ci, ids[0][s + 1], ids[0][s])
    if cap_top:
        c = sum(rings[-1], Vector()) / len(rings[-1])
        ci = mb.v(c, ((u0 + u1) * 0.5, v1), weight_list[-1])
        for s in range(sides):
            mb.tri(ci, ids[-1][s], ids[-1][s + 1])
    mb.outward_fix(start, interior)
    return ids


def limb_rings(p0, p1, r0, r1, count, sides, squash=0.85):
    p0 = Vector(p0)
    p1 = Vector(p1)
    direction = (p1 - p0).normalized()
    hint = Vector((0.0, -1.0, 0.0)) if abs(direction.z) > 0.85 else Vector((0.0, 0.0, 1.0))
    side = direction.cross(hint).normalized()
    binorm = side.cross(direction).normalized()
    rings = []
    for i in range(count):
        t = i / (count - 1)
        center = p0.lerp(p1, t)
        radius = r0 * (1.0 - t) + r1 * t
        ring = []
        for s in range(sides + 1):
            ang = math.tau * (s % sides) / sides + math.pi / 2.0
            offset = side * math.cos(ang) * radius + binorm * math.sin(ang) * radius * squash
            ring.append(center + offset)
        rings.append(ring)
    return rings


def add_limb(mb, p0, p1, r0, r1, rect, w0, w1, count=4, sides=8, squash=0.85, caps=True):
    rings = limb_rings(p0, p1, r0, r1, count, sides, squash)
    weights = []
    for i in range(count):
        weights.append(blend_w(w0, w1, i / (count - 1)))
    mid = (Vector(p0) + Vector(p1)) * 0.5
    add_loft(mb, rings, rect, weights, mid, cap_bottom=caps, cap_top=caps)


def add_box(mb, center, hx, hy, hz, rect):
    start = len(mb.faces)
    c = Vector(center)
    u0, v0, u1, v1 = rect
    um, vm = (u0 + u1) * 0.5, (v0 + v1) * 0.5

    def corner(dx, dy, dz):
        co = Vector((c.x + dx * hx, c.y + dy * hy, c.z + dz * hz))
        return mb.v(co, (um, vm), mb.weights[-1] if False else None)

    # Weight is the builder's last-set weight passed via a closure attribute.
    weight = mb._box_weight
    ids = {}
    for dx in (-1.0, 1.0):
        for dy in (-1.0, 1.0):
            for dz in (-1.0, 1.0):
                co = (c.x + dx * hx, c.y + dy * hy, c.z + dz * hz)
                ids[(dx, dy, dz)] = mb.v(co, (um + dx * 0.01, vm + dz * 0.01), weight)
    # Unused local kept out of the way.
    del corner
    quads = [
        ((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)),
        ((-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)),
        ((-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)),
        ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)),
        ((1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)),
        ((-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)),
    ]
    for q in quads:
        mb.quad(ids[q[0]], ids[q[1]], ids[q[2]], ids[q[3]])
    mb.outward_fix(start, c)


def add_disc(mb, center, radius, normal, right, rect, segs=10):
    start = len(mb.faces)
    center = Vector(center)
    normal = Vector(normal).normalized()
    right = Vector(right).normalized()
    up = normal.cross(right).normalized()
    u0, v0, u1, v1 = rect
    cu, cv = (u0 + u1) * 0.5, (v0 + v1) * 0.5
    weight = mb._box_weight
    ci = mb.v(center, (cu, cv), weight)
    ring = []
    for s in range(segs + 1):
        ang = math.tau * (s % segs) / segs
        co = center + right * math.cos(ang) * radius + up * math.sin(ang) * radius
        u = cu + math.cos(ang) * (u1 - u0) * 0.46
        v = cv + math.sin(ang) * (v1 - v0) * 0.46
        ring.append(mb.v(co, (u, v), weight))
    for s in range(segs):
        mb.tri(ci, ring[s], ring[s + 1])
    mb.outward_fix(start, center - normal * 0.02)


def add_blade(mb, grip, tip, width, thick, sections=7, jagged=False, rect_name="steel"):
    grip = Vector(grip)
    tip = Vector(tip)
    direction = (tip - grip).normalized()
    side = Vector((1.0, 0.0, 0.0))
    if abs(direction.dot(side)) > 0.85:
        side = Vector((0.0, 0.0, 1.0))
    flat = direction.cross(side).normalized()
    side = flat.cross(direction).normalized()
    u0, v0, u1, v1 = _rect(rect_name)
    weight = mb._box_weight
    cols = []
    for i in range(sections):
        t = i / (sections - 1)
        c = grip.lerp(tip, t)
        w = width * (1.0 - t * 0.82)
        th = thick * (1.0 - t * 0.55)
        if jagged and 0.15 < t < 0.92:
            w *= 0.78 + 0.22 * math.sin(t * 36.0)
        u = u0 + t * (u1 - u0)
        cols.append((
            mb.v(c + side * w, (u, v1), weight),
            mb.v(c - side * w, (u, v0), weight),
            mb.v(c + flat * th, (u, (v0 + v1) * 0.5), weight),
            mb.v(c - flat * th, (u, (v0 + v1) * 0.5), weight),
        ))
    start = len(mb.faces)
    for i in range(sections - 1):
        a0, b0, c0, d0 = cols[i]
        a1, b1, c1, d1 = cols[i + 1]
        mb.quad(a0, a1, c1, c0)
        mb.quad(c0, c1, b1, b0)
        mb.quad(b0, b1, d1, d0)
        mb.quad(d0, d1, a1, a0)
    tip_i = mb.v(tip, ((u0 + u1) * 0.5, (v0 + v1) * 0.5), weight)
    a0, b0, c0, d0 = cols[-1]
    mb.tri(a0, tip_i, c0)
    mb.tri(c0, tip_i, b0)
    mb.tri(b0, tip_i, d0)
    mb.tri(d0, tip_i, a0)
    mb.outward_fix(start, (grip + tip) * 0.5)


def shoe_rings(x, sides=8):
    # Sole on z = 0. Heel toward +Y, toe toward -Y.
    specs = [
        (0.09, 0.045, 0.028),
        (0.01, 0.055, 0.034),
        (-0.07, 0.050, 0.026),
        (-0.13, 0.028, 0.014),
    ]
    rings = []
    for y, rx, rz in specs:
        ring = []
        for s in range(sides + 1):
            ang = math.tau * (s % sides) / sides
            px = x + math.cos(ang) * rx
            pz = (math.sin(ang) + 1.0) * rz
            ring.append(Vector((px, y, pz)))
        rings.append(ring)
    return rings


def mirror(p):
    return Vector((-p.x, p.y, p.z))


def build_character():
    """Heavy male. Height is the crown; the helm is the tallest piece."""
    sides_head = 14
    sides_body = 12
    meshes = []

    # Joints, character right is -X (faces -Y, so his right hand is on -X).
    shoulder_l = Vector((0.24, 0.02, 1.46))
    elbow_l = Vector((0.34, 0.07, 1.16))
    wrist_l = Vector((0.38, 0.11, 0.90))
    hand_l = Vector((0.40, 0.14, 0.80))
    hip_l = Vector((0.115, 0.015, 0.98))
    knee_l = Vector((0.125, 0.035, 0.50))
    ankle_l = Vector((0.125, 0.045, 0.08))
    grip_r = Vector((-0.42, -0.16, 0.78))
    tip_r = Vector((-0.30, -0.22, 0.10))
    grip_gear = Vector((-0.46, -0.20, 0.86))
    tip_gear = Vector((-0.26, -0.30, 0.08))

    # --- skin: head, neck, ears, hands ---
    body = MeshBuilder("base_body", smooth=True)
    body.albedo = SKIN
    body.mask = MASK_SKIN
    body.weave = "skin"
    head_spec = [
        (1.625, 0.048, 0.040, 0.000, 0.012),
        (1.665, 0.096, 0.070, -0.010, 0.042),
        (1.705, 0.100, 0.074, 0.000, 0.016),
        (1.748, 0.098, 0.076, 0.004, 0.010),
        (1.788, 0.102, 0.078, -0.004, 0.040),
        (1.835, 0.092, 0.074, 0.008, 0.006),
        (1.872, 0.064, 0.052, 0.010, 0.000),
    ]
    head_rings = [ellipse_ring(z, rx, ry, y0, fp, sides_head) for z, rx, ry, y0, fp in head_spec]
    head_w = [{"head": 1.0} for _ in head_rings]
    add_loft(body, head_rings, _rect("skin_head"), head_w, Vector((0, 0, 1.75)), cap_bottom=True, cap_top=True)
    neck_rings = [
        ellipse_ring(1.50, 0.062, 0.055, 0.0, 0.0, 10),
        ellipse_ring(1.56, 0.070, 0.060, 0.0, 0.0, 10),
        ellipse_ring(1.62, 0.058, 0.050, 0.0, 0.0, 10),
    ]
    add_loft(
        body,
        neck_rings,
        _rect("skin_body"),
        [{"neck": 1.0}, {"neck": 0.6, "head": 0.4}, {"head": 0.85, "neck": 0.15}],
        Vector((0, 0, 1.56)),
        cap_bottom=False,
        cap_top=False,
    )
    body._box_weight = {"head": 1.0}
    for sign in (1.0, -1.0):
        add_box(body, (sign * 0.112, 0.005, 1.74), 0.018, 0.012, 0.038, _rect("skin_head"))
    # Hands. Palm is a box; thumb is a smaller box on the inner side.
    for sign, bone, origin in ((1.0, "hand_l", hand_l), (-1.0, "hand_r", mirror(hand_l))):
        body._box_weight = {bone: 1.0}
        add_box(body, (origin.x, origin.y - 0.02, origin.z - 0.02), 0.038, 0.028, 0.046, _rect("skin_body"))
        add_box(
            body,
            (origin.x - sign * 0.03, origin.y - 0.045, origin.z + 0.01),
            0.016,
            0.02,
            0.02,
            _rect("skin_body"),
        )
    meshes.append(body)

    # --- hair ---
    hair = MeshBuilder("base_head", smooth=True)
    hair.albedo = HAIR_COL
    hair.mask = MASK_HAIR
    hair.weave = "hair"
    hair_rings = []
    for z, rx, ry, y0, fp in head_spec[3:]:
        hair_rings.append(ellipse_ring(z + 0.012, rx + 0.018, ry + 0.016, y0 - 0.006, fp, sides_head))
    # Fringe: pull the lowest hair ring's front down a little by using a lower z on that ring's copy.
    hair_w = [{"head": 1.0} for _ in hair_rings]
    add_loft(hair, hair_rings, _rect("hair"), hair_w, Vector((0, 0, 1.84)), cap_bottom=False, cap_top=True)
    meshes.append(hair)

    # --- tunic, sleeves, wrist wraps ---
    chest = MeshBuilder("base_chest", smooth=True)
    chest.albedo = TUNIC
    chest.mask = MASK_OFF
    chest.weave = "linen"
    tunic_spec = [
        (0.84, 0.22, 0.15, 0.00, 0.02),
        (0.96, 0.20, 0.14, 0.00, 0.01),
        (1.12, 0.175, 0.125, -0.005, 0.00),
        (1.28, 0.21, 0.145, -0.015, 0.02),
        (1.40, 0.25, 0.145, -0.008, 0.015),
        (1.50, 0.16, 0.105, 0.00, 0.00),
    ]
    tunic_rings = [ellipse_ring(z, rx, ry, y0, fp, sides_body) for z, rx, ry, y0, fp in tunic_spec]
    tunic_w = [
        {"hips": 0.75, "spine": 0.25},
        {"hips": 0.45, "spine": 0.55},
        {"spine": 0.7, "chest": 0.3},
        {"chest": 0.85, "spine": 0.15},
        {"chest": 1.0},
        {"chest": 1.0},
    ]
    add_loft(chest, tunic_rings, _rect("tunic"), tunic_w, Vector((0, 0, 1.2)))
    for sign, upper, fore, p0, p1 in (
        (1.0, "arm_l", "fore_l", shoulder_l, wrist_l),
        (-1.0, "arm_r", "fore_r", mirror(shoulder_l), mirror(wrist_l)),
    ):
        add_limb(chest, p0, p1, 0.078, 0.048, _rect("tunic"), {upper: 1.0}, {fore: 1.0}, count=5, sides=8)
    chest.albedo = LEATHER
    chest.weave = "leather"
    for sign, fore, wrist in ((1.0, "fore_l", wrist_l), (-1.0, "fore_r", mirror(wrist_l))):
        top = wrist + Vector((0, -0.005, 0.035))
        bot = wrist + Vector((0, -0.01, -0.02))
        add_limb(chest, bot, top, 0.052, 0.055, _rect("leather"), {fore: 1.0}, {fore: 1.0}, count=3, sides=8, squash=1.0)
    meshes.append(chest)

    # --- trousers ---
    legs = MeshBuilder("base_legs", smooth=True)
    legs.albedo = WOOL
    legs.mask = MASK_OFF
    legs.weave = "wool"
    for hip, knee, bone in ((hip_l, knee_l, "thigh_l"), (mirror(hip_l), mirror(knee_l), "thigh_r")):
        add_limb(
            legs,
            Vector((hip.x, hip.y, 0.48)),
            Vector((hip.x, hip.y, 1.00)),
            0.078,
            0.115,
            _rect("trousers"),
            {bone: 1.0},
            {bone: 0.65, "hips": 0.35},
            count=5,
            sides=8,
            squash=0.9,
        )
    meshes.append(legs)

    # --- boots zone: wool shin + soft shoe (one mesh, two colours) ---
    boots = MeshBuilder("base_boots", smooth=True)
    boots.albedo = WOOL
    boots.mask = MASK_OFF
    boots.weave = "wool"
    for hip, ankle, shin, foot in (
        (hip_l, ankle_l, "shin_l", "foot_l"),
        (mirror(hip_l), mirror(ankle_l), "shin_r", "foot_r"),
    ):
        add_limb(
            boots,
            Vector((ankle.x, ankle.y, 0.02)),
            Vector((hip.x, hip.y - 0.005, 0.54)),
            0.055,
            0.092,
            _rect("trousers"),
            {foot: 0.45, shin: 0.55},
            {shin: 1.0},
            count=4,
            sides=8,
        )
    boots.albedo = LEATHER
    boots.weave = "leather"
    for x, bone in ((ankle_l.x, "foot_l"), (-ankle_l.x, "foot_r")):
        rings = shoe_rings(x)
        weights = [{bone: 1.0} for _ in rings]
        mid = Vector((x, -0.02, 0.03))
        add_loft(boots, rings, _rect("leather"), weights, mid, cap_bottom=False, cap_top=True)
    meshes.append(boots)

    # --- base weapon, plain iron, point down ---
    weapon = MeshBuilder("base_weapon", smooth=True)
    weapon.albedo = IRON
    weapon.mask = MASK_OFF
    weapon.weave = "steel"
    weapon.dye = 0.0
    weapon._box_weight = {"weapon": 1.0}
    add_blade(weapon, grip_r, tip_r, 0.055, 0.012, sections=6, jagged=False)
    weapon.albedo = LEATHER
    weapon.weave = "leather"
    add_limb(weapon, grip_r + Vector((0, 0.02, 0.08)), grip_r + Vector((0, -0.02, -0.02)), 0.02, 0.018, _rect("leather"), {"weapon": 1.0}, {"weapon": 1.0}, count=3, sides=6, squash=1.0)
    weapon._box_weight = {"weapon": 1.0}
    weapon.albedo = IRON
    weapon.weave = "steel"
    guard = (grip_r + tip_r) * 0.0 + grip_r + Vector((0, -0.01, 0.06))
    add_box(weapon, guard, 0.09, 0.012, 0.012, _rect("steel"))
    meshes.append(weapon)

    # --- four faces. Same UVs, different placement. ---
    faces = [
        {"eye_x": 0.046, "eye_z": 1.755, "eye_y": -0.112, "brow_z": 1.805, "brow_tilt": 0.0, "nose": 0.020, "mouth": 0.050},
        {"eye_x": 0.032, "eye_z": 1.775, "eye_y": -0.108, "brow_z": 1.825, "brow_tilt": 0.01, "nose": 0.015, "mouth": 0.038},
        {"eye_x": 0.050, "eye_z": 1.735, "eye_y": -0.116, "brow_z": 1.778, "brow_tilt": -0.018, "nose": 0.026, "mouth": 0.055},
        {"eye_x": 0.040, "eye_z": 1.768, "eye_y": -0.104, "brow_z": 1.812, "brow_tilt": 0.006, "nose": 0.016, "mouth": 0.034},
    ]
    for n, spec in enumerate(faces):
        sclera = MeshBuilder("face_%d_sclera" % n, smooth=True)
        sclera.albedo = SCLERA_COL
        sclera.mask = MASK_OFF
        sclera.weave = "flat"
        sclera._box_weight = {"head": 1.0}
        eyes = MeshBuilder("face_%d_eyes" % n, smooth=True)
        eyes.albedo = EYE_COL
        eyes.mask = MASK_EYES
        eyes.weave = "eye"
        eyes._box_weight = {"head": 1.0}
        for sign in (1.0, -1.0):
            c = Vector((sign * spec["eye_x"], spec["eye_y"], spec["eye_z"]))
            add_disc(sclera, c, 0.022, Vector((0, -1, 0)), Vector((1, 0, 0)), _rect("sclera"))
            add_disc(eyes, c + Vector((0, -0.004, 0)), 0.014, Vector((0, -1, 0)), Vector((1, 0, 0)), _rect("eyes"))
        nose = MeshBuilder("face_%d_nose" % n, smooth=True)
        nose.albedo = SKIN
        nose.mask = MASK_SKIN
        nose.weave = "skin"
        nose._box_weight = {"head": 1.0}
        add_box(
            nose,
            (0.0, spec["eye_y"] - 0.012, spec["eye_z"] - 0.055),
            spec["nose"],
            0.018,
            0.028,
            _rect("skin_head"),
        )
        mouth = MeshBuilder("face_%d_mouth" % n, smooth=True)
        mouth.albedo = MOUTH_COL
        mouth.mask = MASK_OFF
        mouth.weave = "flat"
        mouth._box_weight = {"head": 1.0}
        add_box(
            mouth,
            (0.0, spec["eye_y"] - 0.006, spec["eye_z"] - 0.105),
            spec["mouth"],
            0.012,
            0.012,
            _rect("mouth"),
        )
        brow = MeshBuilder("face_%d_brow" % n, smooth=True)
        brow.albedo = HAIR_COL
        brow.mask = MASK_HAIR
        brow.weave = "hair"
        brow._box_weight = {"head": 1.0}
        add_box(
            brow,
            (0.0, spec["eye_y"] - 0.004, spec["brow_z"]),
            0.09,
            0.012,
            0.012 + abs(spec["brow_tilt"]),
            _rect("hair"),
        )
        meshes.extend([sclera, eyes, nose, mouth, brow])

    # --- Cragmaw. Separate objects, one per slot. Dye on, mask off. ---
    helm = MeshBuilder("gear_head", smooth=False)
    helm.albedo = STEEL
    helm.mask = MASK_OFF
    helm.dye = 1.0
    helm.weave = "steel"
    dome = []
    for z, rx, ry, y0, fp in head_spec[4:]:
        dome.append(ellipse_ring(z + 0.02, rx + 0.028, ry + 0.024, y0, fp, 12))
    add_loft(helm, dome, _rect("steel"), [{"head": 1.0} for _ in dome], Vector((0, 0, 1.86)), cap_top=True)
    helm._box_weight = {"head": 1.0}
    # Jaw plates and a nasal bar. The eye band stays open.
    for sign in (1.0, -1.0):
        add_box(helm, (sign * 0.078, -0.09, 1.66), 0.038, 0.03, 0.055, _rect("steel"))
    add_box(helm, (0.0, -0.12, 1.74), 0.012, 0.02, 0.07, _rect("steel"))
    meshes.append(helm)

    plate = MeshBuilder("gear_chest", smooth=False)
    plate.albedo = STEEL
    plate.mask = MASK_OFF
    plate.dye = 1.0
    plate.weave = "steel"
    plate_spec = [
        (0.90, 0.24, 0.17, 0.0, 0.02),
        (1.15, 0.22, 0.16, -0.01, 0.02),
        (1.38, 0.27, 0.17, -0.015, 0.02),
        (1.52, 0.20, 0.13, 0.0, 0.0),
    ]
    plate_rings = [ellipse_ring(z, rx, ry, y0, fp, 10) for z, rx, ry, y0, fp in plate_spec]
    plate_w = [{"spine": 0.4, "hips": 0.6}, {"chest": 0.5, "spine": 0.5}, {"chest": 1.0}, {"chest": 1.0}]
    add_loft(plate, plate_rings, _rect("steel"), plate_w, Vector((0, -0.02, 1.25)))
    plate._box_weight = {"chest": 0.5, "arm_l": 0.5}
    add_box(plate, (0.30, -0.02, 1.50), 0.09, 0.07, 0.045, _rect("steel"))
    plate._box_weight = {"chest": 0.5, "arm_r": 0.5}
    add_box(plate, (-0.30, -0.02, 1.50), 0.09, 0.07, 0.045, _rect("steel"))
    for sign, fore, hand, wrist in (
        (1.0, "fore_l", "hand_l", wrist_l),
        (-1.0, "fore_r", "hand_r", mirror(wrist_l)),
    ):
        add_limb(
            plate,
            wrist + Vector((sign * 0.01, -0.02, -0.08)),
            wrist + Vector((0, -0.01, 0.16)),
            0.058,
            0.07,
            _rect("steel"),
            {hand: 0.4, fore: 0.6},
            {fore: 1.0},
            count=3,
            sides=7,
            squash=0.8,
        )
    plate.albedo = RED
    plate.weave = "cloth"
    plate._box_weight = {"hips": 0.4, "spine": 0.6}
    add_box(plate, (0.0, -0.155, 1.02), 0.16, 0.02, 0.045, _rect("red"))
    plate.albedo = LEATHER
    plate.weave = "leather"
    add_box(plate, (0.12, -0.15, 1.22), 0.02, 0.015, 0.16, _rect("leather_armor"))
    meshes.append(plate)

    armour_legs = MeshBuilder("gear_legs", smooth=False)
    armour_legs.albedo = STEEL
    armour_legs.mask = MASK_OFF
    armour_legs.dye = 1.0
    armour_legs.weave = "steel"
    for hip, bone in ((hip_l, "thigh_l"), (mirror(hip_l), "thigh_r")):
        add_limb(
            armour_legs,
            Vector((hip.x, hip.y - 0.02, 0.52)),
            Vector((hip.x, hip.y - 0.01, 0.98)),
            0.09,
            0.125,
            _rect("steel"),
            {bone: 1.0},
            {bone: 0.7, "hips": 0.3},
            count=4,
            sides=7,
            squash=0.75,
        )
    armour_legs._box_weight = {"hips": 1.0}
    add_box(armour_legs, (0.0, -0.12, 0.90), 0.20, 0.04, 0.06, _rect("steel"))
    meshes.append(armour_legs)

    armour_boots = MeshBuilder("gear_boots", smooth=False)
    armour_boots.albedo = STEEL
    armour_boots.mask = MASK_OFF
    armour_boots.dye = 1.0
    armour_boots.weave = "steel"
    for hip, ankle, shin, foot in (
        (hip_l, ankle_l, "shin_l", "foot_l"),
        (mirror(hip_l), mirror(ankle_l), "shin_r", "foot_r"),
    ):
        add_limb(
            armour_boots,
            Vector((ankle.x, ankle.y - 0.01, 0.04)),
            Vector((hip.x, hip.y - 0.02, 0.56)),
            0.065,
            0.10,
            _rect("steel"),
            {foot: 0.5, shin: 0.5},
            {shin: 1.0},
            count=4,
            sides=7,
            squash=0.8,
        )
        armour_boots._box_weight = {foot: 1.0}
        add_box(armour_boots, (ankle.x, -0.02, 0.05), 0.065, 0.14, 0.04, _rect("steel"))
    meshes.append(armour_boots)

    big = MeshBuilder("gear_weapon", smooth=False)
    big.albedo = STEEL
    big.mask = MASK_OFF
    big.dye = 1.0
    big.weave = "steel"
    big._box_weight = {"weapon": 1.0}
    add_blade(big, grip_gear, tip_gear, 0.085, 0.016, sections=8, jagged=True, rect_name="blade")
    big.albedo = RED
    big.weave = "cloth"
    add_limb(
        big,
        grip_gear + Vector((0, 0.02, 0.10)),
        grip_gear + Vector((0, -0.015, -0.02)),
        0.024,
        0.022,
        _rect("red"),
        {"weapon": 1.0},
        {"weapon": 1.0},
        count=3,
        sides=6,
        squash=1.0,
    )
    big._box_weight = {"weapon": 1.0}
    big.albedo = STEEL
    big.weave = "steel"
    add_box(big, grip_gear + Vector((0, -0.02, 0.08)), 0.13, 0.016, 0.016, _rect("steel"))
    add_box(big, grip_gear + Vector((0, 0.0, 0.14)), 0.028, 0.028, 0.028, _rect("steel"))
    meshes.append(big)

    bones = [
        ("root", None, (0, 0, 0), (0, 0, 0.12)),
        ("hips", "root", (0, 0, 0.98), (0, 0, 1.12)),
        ("spine", "hips", (0, 0, 1.12), (0, 0, 1.30)),
        ("chest", "spine", (0, 0, 1.30), (0, 0, 1.50)),
        ("neck", "chest", (0, 0, 1.50), (0, 0, 1.62)),
        ("head", "neck", (0, 0, 1.64), (0, 0, 1.88)),
        ("arm_l", "chest", shoulder_l, elbow_l),
        ("fore_l", "arm_l", elbow_l, wrist_l),
        ("hand_l", "fore_l", wrist_l, hand_l),
        ("arm_r", "chest", mirror(shoulder_l), mirror(elbow_l)),
        ("fore_r", "arm_r", mirror(elbow_l), mirror(wrist_l)),
        ("hand_r", "fore_r", mirror(wrist_l), mirror(hand_l)),
        ("weapon", "hand_r", grip_r, tip_r),
        ("thigh_l", "hips", hip_l, knee_l),
        ("shin_l", "thigh_l", knee_l, ankle_l),
        ("foot_l", "shin_l", ankle_l, Vector((ankle_l.x, -0.08, 0.03))),
        ("thigh_r", "hips", mirror(hip_l), mirror(knee_l)),
        ("shin_r", "thigh_r", mirror(knee_l), mirror(ankle_l)),
        ("foot_r", "shin_r", mirror(ankle_l), Vector((-ankle_l.x, -0.08, 0.03))),
    ]
    return meshes, bones


def paint_atlas():
    """One painted tile per atlas rect. Cylindrical unwraps put the front at u=0.5."""
    albedo = np.full((TEX, TEX, 3), 0.16, dtype=np.float32)
    mask = np.zeros((TEX, TEX, 3), dtype=np.float32)
    dye = np.zeros((TEX, TEX, 3), dtype=np.float32)
    paints = {
        "skin_head": (SKIN, MASK_SKIN, 0.0, "skin"),
        "skin_body": (SKIN, MASK_SKIN, 0.0, "skin"),
        "hair": (HAIR_COL, MASK_HAIR, 0.0, "hair"),
        "sclera": (SCLERA_COL, MASK_OFF, 0.0, "flat"),
        "mouth": (MOUTH_COL, MASK_OFF, 0.0, "flat"),
        "tunic": (TUNIC, MASK_OFF, 0.0, "linen"),
        "trousers": (WOOL, MASK_OFF, 0.0, "wool"),
        "leather": (LEATHER, MASK_OFF, 0.0, "leather"),
        "steel": (STEEL, MASK_OFF, 1.0, "steel"),
        "blade": (STEEL, MASK_OFF, 1.0, "steel"),
        "leather_armor": (LEATHER, MASK_OFF, 1.0, "leather"),
        "red": (RED, MASK_OFF, 1.0, "cloth"),
    }
    pad = 8
    for name, (color, mask_col, dye_v, kind) in paints.items():
        _paint_rect(albedo, mask, dye, _rect(name), color, mask_col, dye_v, kind, pad)
    _paint_eyes(albedo, mask)
    return albedo, mask, dye


def _paint_rect(albedo, mask, dye, rect, color, mask_col, dye_v, kind, pad):
    u0, v0, u1, v1 = rect
    x0 = max(int(u0 * (TEX - 1)) - pad, 0)
    x1 = min(int(u1 * (TEX - 1)) + pad, TEX - 1)
    y0 = max(int(v0 * (TEX - 1)) - pad, 0)
    y1 = min(int(v1 * (TEX - 1)) + pad, TEX - 1)
    xs = np.arange(x0, x1 + 1)
    ys = np.arange(y0, y1 + 1)
    grid_x, grid_y = np.meshgrid(xs, ys)
    u = grid_x / (TEX - 1)
    v = grid_y / (TEX - 1)
    lu = np.clip((u - u0) / max(u1 - u0, 1e-4), 0.0, 1.0)
    lv = np.clip((v - v0) / max(v1 - v0, 1e-4), 0.0, 1.0)
    base = np.array(color, dtype=np.float32)
    # Front of a cylindrical unwrap sits at u = 0.5. Darken the back seam.
    front = 1.0 - np.clip(np.abs(lu - 0.5) * 1.35, 0.0, 1.0)
    shade = 0.78 + 0.22 * front
    if kind == "skin":
        blotch = 0.96 + 0.04 * np.sin(grid_x * 0.02) * np.cos(grid_y * 0.017)
        shade = np.clip(shade * blotch, 0.66, 0.94)
    elif kind == "hair":
        streak = np.where(np.sin(grid_x * 0.55 + grid_y * 0.02) > 0.35, 0.72, 1.0)
        shade = shade * streak * (0.85 + 0.15 * lv)
    elif kind == "linen":
        thread = np.where((grid_y % 5) == 0, 0.92, 1.0)
        fold = 0.93 + 0.07 * np.sin(lu * 18.0)
        stitch = np.where((lv < 0.08) & ((grid_x // 7) % 2 == 0), 0.72, 1.0)
        shade = shade * thread * fold * stitch * (0.86 + 0.14 * lv)
    elif kind == "wool":
        fiber = np.where((grid_x % 3) == 0, 0.88, 1.0)
        mottled = 0.94 + 0.06 * np.sin(grid_x * 0.03 + 2.0) * np.cos(grid_y * 0.02)
        shade = shade * fiber * mottled
    elif kind == "leather":
        grain = 0.93 + 0.07 * np.sin(grid_x * 0.21 + grid_y * 0.07)
        wear = 0.92 + 0.08 * front
        shade = shade * grain * wear
    elif kind == "steel":
        band = np.clip(1.0 - np.abs(lu * 0.7 + lv * 0.7 - 0.75) * 6.0, 0.0, 1.0)
        scratch = np.where((grid_y % 17) == 0, 1.12, 1.0)
        pit = np.where((np.sin(grid_x * 0.2) > 0.92) & (np.cos(grid_y * 0.17) > 0.85), 0.75, 1.0)
        shade = shade * (0.82 + 0.45 * band) * scratch * pit
    elif kind == "cloth":
        shade = shade * np.where((grid_y % 4) == 0, 0.86, 1.0)
    col = base * shade[..., None]
    albedo[y0 : y1 + 1, x0 : x1 + 1] = np.clip(col, 0.0, 1.0)
    mask[y0 : y1 + 1, x0 : x1 + 1] = np.array(mask_col, dtype=np.float32)
    dye[y0 : y1 + 1, x0 : x1 + 1] = dye_v


def _paint_eyes(albedo, mask, valid=None):
    u0, v0, u1, v1 = _rect("eyes")
    x0, x1 = int(u0 * (TEX - 1)), int(u1 * (TEX - 1))
    y0, y1 = int(v0 * (TEX - 1)), int(v1 * (TEX - 1))
    ys, xs = np.ogrid[y0 : y1 + 1, x0 : x1 + 1]
    cx, cy = (x0 + x1) * 0.5, (y0 + y1) * 0.5
    rx, ry = max((x1 - x0) * 0.5, 1.0), max((y1 - y0) * 0.5, 1.0)
    r = np.sqrt(((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2)
    lum = np.where(r < 0.18, 0.10, np.where(r < 0.58, 0.66, np.where(r < 0.74, 0.38, 0.72)))
    inside = r <= 1.0
    patch = np.repeat(lum[..., None], 3, axis=-1)
    albedo[y0 : y1 + 1, x0 : x1 + 1][inside] = patch[inside]
    mask[y0 : y1 + 1, x0 : x1 + 1][inside] = (0.0, 0.0, 1.0)


def _fill_rect(albedo, valid, rect, color):
    u0, v0, u1, v1 = rect
    x0, x1 = int(u0 * (TEX - 1)), int(u1 * (TEX - 1))
    y0, y1 = int(v0 * (TEX - 1)), int(v1 * (TEX - 1))
    albedo[y0 : y1 + 1, x0 : x1 + 1] = np.array(color, dtype=np.float32)
    valid[y0 : y1 + 1, x0 : x1 + 1] = True


def _shift(src, dy, dx):
    out = np.zeros_like(src)
    h, w = src.shape[:2]
    y0s, y0d = max(dy, 0), max(-dy, 0)
    y1s, y1d = h + min(dy, 0), h + min(-dy, 0)
    x0s, x0d = max(dx, 0), max(-dx, 0)
    x1s, x1d = w + min(dx, 0), w + min(-dx, 0)
    out[y0d:y1d, x0d:x1d] = src[y0s:y1s, x0s:x1s]
    return out


def _dilate(color, valid, radius):
    if color.ndim == 2:
        color = color[..., None]
        squeeze = True
    else:
        squeeze = False
    valid = valid.astype(bool)
    out_c = color.copy()
    out_v = valid.copy()
    for _ in range(radius):
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sv = _shift(out_v, dy, dx)
            sc = _shift(out_c, dy, dx)
            take = (~out_v) & sv
            out_c[take] = sc[take]
            out_v[take] = True
    if squeeze:
        out_c = out_c[..., 0]
    return out_c, out_v


def save_png(name, arr, path):
    h, w, _ = arr.shape
    image = bpy.data.images.new(name, w, h, alpha=False, float_buffer=False)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(arr, 0.0, 1.0)
    image.pixels.foreach_set(np.ascontiguousarray(rgba).ravel())
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    return image


def new_armature(bone_specs):
    data = bpy.data.armatures.new("Skeleton3D")
    obj = bpy.data.objects.new("Skeleton3D", data)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    created = {}
    for name, parent, head, tail in bone_specs:
        bone = data.edit_bones.new(name)
        bone.head = Vector(head)
        bone.tail = Vector(tail)
        bone.use_deform = True
        if parent:
            bone.parent = created[parent]
            bone.use_connect = False
        created[name] = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def to_object(mb, arm):
    mesh = bpy.data.meshes.new(mb.name + "_mesh")
    obj = bpy.data.objects.new(mb.name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh_new_from(mb)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    groups = {}
    for vi, weight in enumerate(mb.weights):
        total = sum(weight.values()) or 1.0
        for bone, value in weight.items():
            if value <= 0.0001:
                continue
            group = groups.get(bone)
            if group is None:
                group = obj.vertex_groups.new(name=bone)
                groups[bone] = group
            group.add([vi], value / total, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    obj.parent = arm
    obj.matrix_parent_inverse = arm.matrix_world.inverted()
    return obj


def bmesh_new_from(mb):
    import bmesh

    bm = bmesh.new()
    for co in mb.verts:
        bm.verts.new(co)
    bm.verts.ensure_lookup_table()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    for ia, ib, ic in mb.faces:
        try:
            face = bm.faces.new((bm.verts[ia], bm.verts[ib], bm.verts[ic]))
        except ValueError:
            continue
        face.smooth = mb.smooth
        for loop, idx in zip(face.loops, (ia, ib, ic)):
            loop[uv_layer].uv = mb.uvs[idx]
    bm.normal_update()
    return bm


def animate(arm):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for bone in arm.pose.bones:
        bone.rotation_mode = "XYZ"

    def action_for(name, keys):
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        arm.animation_data_create()
        arm.animation_data.action = action
        for frame, pose in keys:
            for bone in arm.pose.bones:
                bone.rotation_euler = (0.0, 0.0, 0.0)
                bone.location = (0.0, 0.0, 0.0)
            for bone_name, euler in pose.items():
                bone = arm.pose.bones[bone_name]
                if isinstance(euler, tuple) and euler and euler[0] == "loc":
                    bone.location = euler[1]
                    bone.keyframe_insert("location", frame=frame)
                    continue
                bone.rotation_euler = euler
                bone.keyframe_insert("rotation_euler", frame=frame)
        for curve in action.fcurves:
            for kp in curve.keyframe_points:
                kp.interpolation = "LINEAR"
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 1, action)
        track.mute = True
        arm.animation_data.action = None
        return action

    z = math.radians
    idle = [
        (1, {"chest": (0, 0, 0), "head": (0, 0, 0), "arm_l": (0, 0, 0), "arm_r": (0, 0, 0), "hips": ("loc", Vector((0, 0, 0)))}),
        (31, {"chest": (z(2.0), 0, 0), "head": (z(1.5), 0, z(3.0)), "arm_l": (0, 0, z(4.0)), "arm_r": (0, 0, z(-4.0)), "hips": ("loc", Vector((0, 0.01, 0)))}),
        (61, {"chest": (0, 0, 0), "head": (z(3.0), 0, z(5.0)), "arm_l": (0, 0, 0), "arm_r": (0, 0, 0), "hips": ("loc", Vector((0, 0, 0)))}),
        (91, {"chest": (z(-1.2), 0, 0), "head": (z(1.0), 0, z(-3.0)), "arm_l": (0, 0, z(-3.0)), "arm_r": (0, 0, z(3.0)), "hips": ("loc", Vector((0, -0.006, 0)))}),
        (121, {"chest": (0, 0, 0), "head": (0, 0, 0), "arm_l": (0, 0, 0), "arm_r": (0, 0, 0), "hips": ("loc", Vector((0, 0, 0)))}),
    ]
    select = [
        (1, {"arm_r": (0, 0, 0), "fore_r": (0, 0, 0), "weapon": (0, 0, 0), "chest": (0, 0, 0), "arm_l": (0, 0, 0)}),
        (14, {"arm_r": (z(-75), 0, z(-18)), "fore_r": (z(-25), 0, 0), "weapon": (0, 0, z(20)), "chest": (z(-8), 0, z(6)), "arm_l": (0, 0, z(18))}),
        (34, {"arm_r": (z(-75), 0, z(-18)), "fore_r": (z(-25), 0, 0), "weapon": (0, 0, z(20)), "chest": (z(4), 0, 0), "arm_l": (0, 0, z(12))}),
        (61, {"arm_r": (0, 0, 0), "fore_r": (0, 0, 0), "weapon": (0, 0, 0), "chest": (0, 0, 0), "arm_l": (0, 0, 0)}),
    ]
    action_for("idle", idle)
    action_for("select", select)
    for track in arm.animation_data.nla_tracks:
        track.mute = False
    for bone in arm.pose.bones:
        bone.rotation_euler = (0.0, 0.0, 0.0)
        bone.location = (0.0, 0.0, 0.0)
    bpy.ops.object.mode_set(mode="OBJECT")


def export_glb(path, objects, animations):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="NONE",
        export_animations=animations,
        export_animation_mode="NLA_TRACKS",
        export_nla_strips=True,
        export_frame_step=1,
        export_force_sampling=True,
        export_skins=True,
        export_influence_nb=4,
        export_morph=False,
        export_lights=False,
        export_cameras=False,
        export_leaf_bone=False,
        export_def_bones=False,
        export_optimize_animation_size=False,
        export_anim_slide_to_zero=True,
        export_rest_position_armature=True,
        export_reset_pose_bones=True,
        export_current_frame=False,
    )


def bounds(meshes):
    xs, ys, zs = [], [], []
    for mb in meshes:
        for v in mb.verts:
            xs.append(v.x)
            ys.append(v.y)
            zs.append(v.z)
    return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)


def render_stills(arm, objects, by_name):
    mode = os.environ.get("IRONJAW_RENDER", "preview")
    if mode == "off":
        return
    samples = int(os.environ.get("IRONJAW_SAMPLES", "12" if mode == "preview" else "32"))
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 768
    scene.render.resolution_y = 1024
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("Stage")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.30, 0.30, 0.32, 1.0)
    bg.inputs[1].default_value = 0.9
    sun_data = bpy.data.lights.new("Key", "SUN")
    sun_data.energy = 2.6
    sun = bpy.data.objects.new("Key", sun_data)
    sun.rotation_euler = (math.radians(48), math.radians(8), math.radians(-30))
    scene.collection.objects.link(sun)
    image = bpy.data.images.load(os.path.join(OUT_DIR, "albedo.png"))
    mat = bpy.data.materials.new("Bake")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.84
    for obj in objects:
        if obj.type == "MESH":
            if obj.data.materials:
                obj.data.materials[0] = mat
            else:
                obj.data.materials.append(mat)
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.sensor_fit = "VERTICAL"
    cam_data.angle = math.radians(30)
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    def aim(loc):
        cam.location = Vector(loc)
        direction = Vector((0.0, 0.0, 0.95)) - cam.location
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    def shot(folder, name):
        os.makedirs(folder, exist_ok=True)
        scene.render.filepath = os.path.join(folder, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("RENDER", scene.render.filepath)

    folder = os.path.join(ROOT, "docs", "pc", "media", "charselect", "ironjaw_raw")
    views = {
        "front": (0.0, -3.55, 1.15),
        "three_quarter": (1.35, -3.15, 1.22),
        "back": (0.0, 3.55, 1.15),
    }
    gear_names = ["gear_weapon", "gear_head", "gear_chest", "gear_legs", "gear_boots"]
    base_hide = ["base_head", "base_chest", "base_legs", "base_boots", "base_weapon"]

    def show_base():
        for obj in objects:
            if obj.type != "MESH":
                continue
            hide = obj.name in gear_names or (obj.name.startswith("face_") and not obj.name.startswith("face_0"))
            obj.hide_render = hide

    def show_cragmaw():
        for obj in objects:
            if obj.type != "MESH":
                continue
            hide = obj.name in base_hide or (obj.name.startswith("face_") and not obj.name.startswith("face_0"))
            obj.hide_render = hide

    show_base()
    if mode == "preview":
        aim(views["front"])
        shot(folder, "base_front")
        show_cragmaw()
        shot(folder, "cragmaw_front")
        return
    for name, loc in views.items():
        aim(loc)
        show_base()
        shot(folder, "base_" + name)
        show_cragmaw()
        shot(folder, "cragmaw_" + name)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 30
    scene.render.fps_base = 1.0
    scene.unit_settings.system = "METRIC"

    meshes, bone_specs = build_character()
    tris = sum(len(mb.faces) for mb in meshes)
    min_x, max_x, min_y, max_y, min_z, max_z = bounds(meshes)
    print("VERTS", sum(len(mb.verts) for mb in meshes), "TRIS", tris, "BONES", len(bone_specs))
    print("BBOX x", round(min_x, 3), round(max_x, 3), "y", round(min_y, 3), round(max_y, 3), "z", round(min_z, 3), round(max_z, 3))
    if tris > 15000:
        raise SystemExit("triangle budget exceeded: %d" % tris)
    if len(bone_specs) > 60:
        raise SystemExit("bone budget exceeded")
    if min_z < -0.02 or min_z > 0.05:
        raise SystemExit("feet not on the origin: %s" % min_z)
    if max_z < 1.75 or max_z > 1.95:
        raise SystemExit("height out of range: %s" % max_z)

    print("painting", TEX)
    albedo, mask, dye = paint_atlas()
    os.makedirs(GEAR_DIR, exist_ok=True)
    save_png("albedo", albedo, os.path.join(OUT_DIR, "albedo.png"))
    save_png("mask", mask, os.path.join(OUT_DIR, "mask.png"))
    save_png("dye", np.clip(dye, 0.0, 1.0).astype(np.float32), os.path.join(OUT_DIR, "dye_mask.png"))

    arm = new_armature(bone_specs)
    objects = [arm]
    by_name = {}
    for mb in meshes:
        obj = to_object(mb, arm)
        objects.append(obj)
        by_name[mb.name] = obj
    animate(arm)
    hero_path = os.path.join(OUT_DIR, "ironjaw_m.glb")
    export_glb(hero_path, objects, True)
    print("WROTE", hero_path)
    for slot in ("weapon", "head", "chest", "legs", "boots"):
        path = os.path.join(GEAR_DIR, "cragmaw_%s.glb" % slot)
        export_glb(path, [arm, by_name["gear_" + slot]], False)
        print("WROTE", path)

    manifest = {
        "class_id": "ironjaw",
        "gender": "m",
        "tool": "Blender %s" % bpy.app.version_string,
        "script": "tools/pc/charselect_models/build_ironjaw_m.py",
        "triangles": tris,
        "bones": len(bone_specs),
        "height_m": round(max_z, 4),
        "min_z": round(min_z, 4),
        "textures": TEX,
        "mask": "R skin, G hair, B eyes",
        "gear_set": "cragmaw",
        "faces": 4,
        "animations": {"idle": 4.0, "select": 2.0},
        "not_built": NOT_BUILT,
    }
    with open(os.path.join(OUT_DIR, "manifest.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")
    with open(os.path.join(OUT_DIR, "uv_layout.json"), "w", encoding="utf-8") as handle:
        json.dump({"size": TEX, "v_origin": "bottom", "rects": RECTS}, handle, indent=2)
        handle.write("\n")
    render_stills(arm, objects, by_name)
    print("DONE")


if __name__ == "__main__":
    main()
