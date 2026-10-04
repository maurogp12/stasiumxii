"""Ironjaw part meshes in each part's own joint frame (see rig.py for the frames)."""
import math
from mathutils import Matrix, Vector
from geo import box, slab, cyl, merge, prism
import rig


def Ry(d):
    return Matrix.Rotation(math.radians(d), 4, 'Y')


# axe head outline in the blade plane, relative to the eye: (y along the haft, z perpendicular; +z = upper bit).
# Big crescent bit below (convex cutting edge between two sharp horns), smaller crescent above; narrow neck at the eye.
_AXE_HEAD0 = [(9, -10), (13, -26), (24, -40), (40, -50), (29, -57), (14, -61), (0, -63), (-14, -61), (-29, -57), (-40, -50),
              (-24, -40), (-13, -26), (-9, -10), (-9, 10), (-12, 22), (-20, 33), (-30, 40), (-19, 46), (-8, 49), (0, 50),
              (8, 49), (19, 46), (30, 40), (20, 33), (12, 22), (9, 10)]
EYE_Y = 60.0          # eye (head centre) distance along the haft from the grip (short war-axe, as in the reference)
HEAD_SCALE = 0.85
HEAD_TILT = rig.HAFT_DEG + 8.0   # deg: head turned in the blade plane about the eye so the big bit hangs down and 8 deg
#                                  forward (cutting edge leads forward/down) instead of pointing back at the legs
_ct, _st = math.cos(math.radians(HEAD_TILT)), math.sin(math.radians(HEAD_TILT))
AXE_HEAD = [(EYE_Y + HEAD_SCALE * (y * _ct - z * _st), HEAD_SCALE * (y * _st + z * _ct)) for y, z in _AXE_HEAD0]


def parts():
    P = {}
    P['pelvis'] = merge([
        box((0, -2, 18), (90, 62, 44)),                 # hips / fauld
        box((0, -2, 36), (96, 70, 12)),                 # belt
        box((0, 34, -14), (42, 6, 64)),                 # front tabard
        box((0, -34, 0), (60, 6, 40)),                  # rear plate
        box((43, 0, 6), (20, 54, 38), top_scale=(0.7, 0.9)),   # tassets
        box((-43, 0, 6), (20, 54, 38), top_scale=(0.7, 0.9)),
    ])
    P['chest'] = merge([
        box((0, 0, 16), (84, 64, 36)),                                    # abdomen
        box((0, 4, 56), (92, 84, 52), top_scale=(1.25, 1.0)),            # big chest, flaring to the shoulders
        box((0, 45, 58), (82, 12, 42), top_scale=(1.15, 1.0)),           # chest plate bulge
        box((0, 2, 86), (100, 72, 12), top_scale=(0.8, 0.85)),           # top of chest / gorget base
    ])
    P['head'] = merge([
        box((0, 2, 18), (48, 50, 50), top_scale=(0.86, 0.86)),   # helm (z -7..43)
        box((0, 28, 12), (34, 6, 30)),                  # visor
        box((0, 2, 46), (12, 34, 8)),                   # crest
        cyl((20, 0, 30), (34, 2, 56), 7, 0, 6),         # horns
        cyl((-20, 0, 30), (-34, 2, 56), 7, 0, 6),
    ])
    P['cape_up'] = slab((0, 0, 0), 70, 82, 96, 8)
    P['cape_lo'] = slab((0, 0, 0), 82, 88, 74, 8)
    for s, n in ((1, 'R'), (-1, 'L')):
        P['shoulder_' + n] = merge([
            box((s * 12, 0, 14), (66, 74, 32), top_scale=(0.75, 0.8), rot=Ry(s * 14)),   # pauldron dome
            box((s * 27, 0, -4), (32, 76, 18), rot=Ry(s * 30)),                          # lower rim
            cyl((s * 8, 0, 26), (s * 12, 0, 60), 11, 0, 6),                              # big spike
            cyl((s * 30, 18, 18), (s * 48, 22, 42), 7, 0, 6),                            # side spikes
            cyl((s * 30, -18, 18), (s * 48, -22, 42), 7, 0, 6),
        ])
        # arms: as thick as the shin (~36), chunky plates. Frames: upperarm/forearm -Z runs down the bone.
        P['upperarm_' + n] = merge([
            box((0, 0, -rig.UPPER / 2 + 4), (36, 36, rig.UPPER + 8), top_scale=(1.1, 1.1)),      # rerebrace
            box((s * 4, 0, -rig.UPPER * 0.45), (36, 40, 26)),                                  # plate band
            box((0, 0, -rig.UPPER), (40, 40, 22)),                                              # elbow cop
        ])
        P['forearm_' + n] = merge([
            box((0, 0, -rig.FORE / 2), (34, 34, rig.FORE), top_scale=(0.95, 0.95)),             # vambrace (ends at the wrist)
            box((0, 0, -rig.FORE + 18), (44, 44, 22), top_scale=(0.86, 0.86)),                  # flared gauntlet cuff
        ])
        # fist: built in the hand/axe frame (+Y along the haft). Encloses the handle (axis = local Y) and the wrist joint.
        P['hand_' + n] = merge([
            box((0, -1, 4), (36, 34, 38)),                                    # clenched fist around the handle
            box((0, 2, 18), (32, 26, 12)),                                    # knuckle row / fingers over the top
            box((s * 15, -10, 8), (10, 16, 22)),                              # thumb wrapped over the outside
        ])
        P['axe_' + n] = merge([
            cyl((0, -32, 0), (0, EYE_Y + 10, 0), 6, 6, 6),               # haft: butt end just behind the fist, head ahead
            box((0, -34, 0), (15, 9, 15)),                                     # pommel knob (butt end sticks out of the fist)
            prism(AXE_HEAD, 8),                                                # double-bit crescent head (blade plane = local YZ)
            box((0, EYE_Y, 0), (13, 22, 22)),                                  # eye / socket
            cyl((0, EYE_Y + 10, 0), (0, EYE_Y + 26, 0), 5, 0, 5),              # top spike
        ])
        P['thigh_' + n] = merge([
            cyl((0, 0, 6), (0, 0, -rig.THIGH), 22, 19, 8),
            box((0, 7, -18), (36, 22, 30)),                              # cuisse plate
        ])
        P['shin_' + n] = merge([
            box((0, 2, 0), (30, 30, 18)),                                # knee cop
            cyl((0, 0, 0), (0, 0, -rig.SHIN), 18, 16, 8),
            box((0, 9, -22), (32, 12, 34)),                              # greave
        ])
        P['boot_' + n] = merge([
            box((0, 8, -5), (46, 66, 30)),                               # boot block: y -25..41, z -20..10
            box((0, 34, -12), (48, 16, 16)),                             # toe cap
            box((0, -2, 12), (42, 42, 14)),                              # cuff
        ])
    return P


SIDE_COL = {
    # near (= his right in both S and E): warm orange family
    'shoulder_R': (255, 196, 120), 'upperarm_R': (244, 152, 60), 'forearm_R': (222, 118, 36),
    'hand_R': (190, 92, 24), 'thigh_R': (244, 152, 60), 'shin_R': (222, 118, 36), 'boot_R': (170, 80, 22),
    # far (= his left): blue family
    'shoulder_L': (150, 196, 255), 'upperarm_L': (84, 142, 236), 'forearm_L': (52, 106, 206),
    'hand_L': (36, 78, 170), 'thigh_L': (84, 142, 236), 'shin_L': (52, 106, 206), 'boot_L': (32, 64, 150),
    # torso greys, cape, axes
    'pelvis': (120, 120, 120), 'chest': (152, 152, 152), 'head': (196, 196, 196),
    'cape_up': (128, 72, 72), 'cape_lo': (108, 58, 58),
    'axe_R': (40, 200, 90), 'axe_L': (220, 60, 210),
}
