"""Ironjaw blockout mannequin: geometry + procedural walk (own code, no third-party rigs).

Character frame: +Y forward, +X = his RIGHT, +Z up, origin = ground point under the pelvis.
All lengths in world units; the camera maps 1 world unit to 1 px horizontally (ortho_scale 460).
"""
import math
from mathutils import Matrix, Vector

NF = 12
FPS = 17.144
# planted boot slides back by exactly (12, 6) px per frame on the 2:1 diagonal
PX_PER_UNIT = 0.93    # camera zoom: 1 world unit = 0.93 px horizontally (figure ~260 px helm-to-sole)
V = 12.0 / (math.cos(math.radians(45.0)) * PX_PER_UNIT)   # 18.248 world units per frame = exactly (12, 6) px on screen
STEP = 6 * V                                 # 101.82 per step, 203.65 per cycle
HALF = STEP / 2.0
STANCE = 6                                   # planted frames f0..f6 (7 frames incl. both contacts)

# ---- proportions (locked to the HD refs, see README) ----
HIP_HI = 106.0        # pelvis height at the top of the bob (passing)
BOB = 29.5            # pelvis drop, world units (x cos30 x 0.93 = 23.8 px; with the lateral sway ~25.5 px screen = ~7.6 px at draw 0.30)
ANKLE_Z = 20.0
THIGH = 46.0
SHIN = 44.0
HIP_X = 28.0
FOOT_X = 34.0
LIFT = 32.0
SPINE_Z = 38.0
SHOULDER = (58.0, 0.0, 78.0)
# ---- arms + axe hold (matched to Luca's reference picture / HD idle) ----
# The arm chain is solved in the TRAVEL frame (+Y = walk direction, the frame the stride runs in), so the swing and
# the blade planes stay exactly along the walk in every frame and never drift sideways with the chest/cheat yaw.
UPPER = 74.0          # shoulder -> elbow
FORE = 70.0           # elbow -> wrist
ELBOW_BEND = 100.0    # held in every frame (interior angle 80 deg)
FIST_X = 92.0         # fist / axe plane lateral offset: outside the hips (arms read on both sides), clear of the legs (legs stay inside |x| < 63)
REACH_DEG = 52.0      # shoulder->wrist line, degrees below horizontal (upper arm hangs ~vertical, forearm forward)
HAFT_DEG = 35.0       # handle runs forward and down from the fist, degrees below horizontal (idle / mid swing)
ARM_SWING = 15.0      # +- deg at the shoulder, opposite the legs
WRIST_FOLLOW = 0.4    # the heavy axe lags: the haft turns 0.4 x the shoulder swing (about the wrist, which stays inside the fist)
WRIST_IN_FIST = (0.0, -7.0, 7.0)   # wrist joint in the hand/axe frame (y along the haft): behind+above the handle, inside the fist
IDLE_HIP = 108.0


def T(x, y=0.0, z=0.0):
    return Matrix.Translation(Vector((x, y, z)))


def R(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def seg_matrix(top, bottom, pole):
    """Frame at `top` whose -Z runs to `bottom`, +Y toward the pole."""
    z = (top - bottom).normalized()
    y = (pole - pole.dot(z) * z).normalized()
    x = y.cross(z)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = top
    return m


def two_bone(hip, ankle, l1, l2, pole):
    d = ankle - hip
    L = d.length
    L = min(L, (l1 + l2) * 0.9995)
    u = d.normalized()
    a = (l1 * l1 - l2 * l2 + L * L) / (2 * L)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    p = (pole - pole.dot(u) * u).normalized()
    knee = hip + u * a + p * h
    ank = hip + u * L
    return knee, ank


def swing_profile(s):
    """s in (0,1): world-forward fraction (cycloid: zero world speed at lift-off/landing), lift, pitch."""
    c = s - math.sin(2 * math.pi * s) / (2 * math.pi)
    lift = LIFT * math.sin(math.pi * (s ** 0.8))
    pitch = -22.0 * math.exp(-((s - 0.15) / 0.18) ** 2) + 8.0 * math.exp(-((s - 0.72) / 0.15) ** 2)
    return c, lift, pitch


def foot_state(phase_f, side):
    """phase_f in frames (0..12). side +1 right, -1 left. Right contacts at 0, left at 6.
    Returns (y_local, lift, pitch, planted)."""
    f = (phase_f - (0 if side > 0 else 6)) % NF
    if f <= STANCE + 1e-9:
        return HALF - V * f, 0.0, 0.0, True
    s = (f - STANCE) / (NF - STANCE)
    c, lift, pitch = swing_profile(s)
    y = -HALF + 2 * STEP * c - STEP * s
    return y, lift, pitch, False


def hip_z(phase_f):
    # one smooth bob per step: lowest 1 frame after contact (f1, f7), highest at f4/f10
    return HIP_HI - BOB * (1 + math.cos(2 * math.pi * (phase_f - 1) / 6.0)) / 2.0


CHEAT = {'S': -20.0, 'E': 35.0}   # body yaw on top of the travel diagonal, matched to the v3.2/HD views: S ~25 deg off the camera axis, E ~10 deg off a pure back view; stride stays on the 2:1 diagonal   # extra body yaw (deg) on top of the travel direction, per facing


def arm_chain(sh, s, swing):
    """Arm + axe for one side. sh = shoulder joint (character frame), s = +1 right / -1 left, swing = deg (+ forward).
    The arm swings rigidly about the travel-frame X axis through the shoulder, so the shoulder->wrist distance (and the
    elbow angle) is held and x never changes (no sideways swing). The axe pivots about the wrist by WRIST_FOLLOW x swing,
    with the wrist fixed in the fist (WRIST_IN_FIST in the hand frame), so the fist always encloses wrist and handle.
    Returns frames: upperarm (shoulder, -Z to elbow), forearm (elbow, -Z to wrist), hand (= axe frame at the grip:
    +Y along the haft toward the head, +X = blade-face normal = lateral, so the blade plane is vertical and along the walk)."""
    Rs = R('X', swing).to_3x3()
    bend = math.radians(ELBOW_BEND)
    D = math.sqrt(UPPER ** 2 + FORE ** 2 + 2 * UPPER * FORE * math.cos(bend))   # law of cosines, interior angle 180-bend
    Rax = R('X', WRIST_FOLLOW * swing - HAFT_DEG)
    w_loc = Rax.to_3x3() @ Vector(WRIST_IN_FIST)
    wx = s * FIST_X + w_loc.x
    dx = wx - sh.x
    r = math.sqrt(max(D * D - dx * dx, 1.0))
    a = math.radians(REACH_DEG)
    wrist = sh + Vector((dx, 0, 0)) + Rs @ Vector((0, r * math.cos(a), -r * math.sin(a)))
    grip = wrist - w_loc
    pole = Rs @ Vector((s * 0.5, -1.0, -0.1))                     # elbow points back and a little out
    elbow, wr = two_bone(sh, wrist, UPPER, FORE, pole)
    out = {}
    out['upperarm'] = seg_matrix(sh, elbow, Rs @ Vector((0, 1, 0)))
    out['forearm'] = seg_matrix(elbow, wr, Rs @ Vector((0, 0, 1)))
    out['hand'] = T(*grip) @ Rax
    out['_wrist'] = wr
    out['_elbow'] = elbow
    return out


def pose(phase_f=None, idle=False, cheat=0.0):
    """Return dict name -> 4x4 matrix in the character frame."""
    M = {}
    if idle:
        zh, xp, yaw_p, yaw_c, lean = IDLE_HIP, 0.0, 0.0, 0.0, 6.0
        arm = {1: 0.0, -1: 0.0}
        cape_lo, cape_sway = 9.0, 0.0
    else:
        p = phase_f
        w = 2 * math.pi * p / NF
        zh = hip_z(p)
        xp = 4.0 * math.cos(2 * math.pi * (p - 3) / NF)
        yaw_p = 6.0 * math.cos(w)            # right hip forward at f0 (right leg forward)
        yaw_c = -14.0 * math.cos(w)          # chest counter-rotates: net shoulders -8 deg
        lean = 8.0
        wl = 2 * math.pi * (p - 0.5) / NF    # arms lag the legs half a frame (weight)
        arm = {1: -ARM_SWING * math.cos(wl), -1: ARM_SWING * math.cos(wl)}   # right arm back when right leg fwd
        cape_lo = 10.0 + 5.0 * math.sin(2 * math.pi * (p - 2) / 6.0)
        cape_sway = 3.0 * math.sin(2 * math.pi * (p - 2) / NF)
    pel = T(xp, 0, zh) @ R('Z', cheat + yaw_p)
    RC = R('Z', cheat)
    M['pelvis'] = pel
    chest = pel @ T(0, 0, SPINE_Z) @ R('Z', yaw_c) @ R('X', lean)
    M['chest'] = chest
    M['head'] = chest @ T(0, 6, 84) @ R('X', -lean) @ R('Z', -0.4 * yaw_c)
    M['cape_up'] = chest @ T(0, -50, 82) @ R('X', -12.0)
    M['cape_lo'] = M['cape_up'] @ T(0, 0, -100) @ R('X', -cape_lo) @ R('Y', cape_sway)
    for s, n in ((1, 'R'), (-1, 'L')):
        sh = chest @ T(s * SHOULDER[0], SHOULDER[1], SHOULDER[2])
        M['shoulder_' + n] = sh @ R('X', 0.3 * arm[s])          # pauldron rides the chest, follows the swing a little
        A = arm_chain(sh.translation, s, arm[s])
        M['upperarm_' + n] = A['upperarm']
        M['forearm_' + n] = A['forearm']
        M['hand_' + n] = A['hand']
        M['axe_' + n] = A['hand']                                 # the axe is rigid in the fist (same frame, grip = origin)
        # legs
        hip = (pel @ Vector((s * HIP_X, 0, 0)))
        if idle:
            yf, lift, pitch = (6.0 if s > 0 else -6.0), 0.0, 0.0
            fx = s * 42.0
        else:
            yf, lift, pitch, _ = foot_state(phase_f, s)
            fx = s * FOOT_X
        ank_t = (RC @ Vector((fx, 0, 0))) + Vector((0, yf, ANKLE_Z + lift))
        pole = RC.to_3x3() @ Vector((s * 0.15, 1.0, 0.0))
        knee, ank = two_bone(hip, ank_t, THIGH, SHIN, pole)
        M['thigh_' + n] = seg_matrix(hip, knee, pole)
        M['shin_' + n] = seg_matrix(knee, ank, pole)
        M['boot_' + n] = T(*ank) @ R('Z', 0.5 * cheat) @ R('X', pitch)   # toes split body/travel
    return M


PARENT = {
    'pelvis': 'root', 'chest': 'pelvis', 'head': 'chest', 'cape_up': 'chest', 'cape_lo': 'cape_up',
}
for _n in 'RL':
    PARENT.update({
        'shoulder_' + _n: 'chest', 'upperarm_' + _n: 'shoulder_' + _n, 'forearm_' + _n: 'upperarm_' + _n,
        'hand_' + _n: 'forearm_' + _n, 'axe_' + _n: 'hand_' + _n,
        'thigh_' + _n: 'pelvis', 'shin_' + _n: 'thigh_' + _n, 'boot_' + _n: 'shin_' + _n})
