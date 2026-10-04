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
ARM_SWING = 15.0      # +- deg at the shoulder, opposite the legs
WRIST_FOLLOW = 0.4    # the heavy axe lags: the haft turns 0.4 x the shoulder swing (about the wrist, which stays inside the fist)
WRIST_IN_FIST = (0.0, -7.0, 7.0)   # wrist joint in the hand/axe frame (y along the haft): behind+above the handle, inside the fist
HEAD_TILT = 36.0      # axe head turned in its blade plane so the big crescent hangs ~down (see model.py)
# Per facing / side hold (idle values; the walk swings the whole arm rigidly about the travel X axis through the shoulder).
# Two ways to place the fist:
#   grip   : explicit idle grip point (|x| absolute; y, z relative to the shoulder), travel frame        -- or --
#   fist_x : fist lateral offset (+ = outward), reach: shoulder->wrist line deg below horizontal, bend: elbow bend
#   haft   : handle, deg below horizontal (forward and down)   yaw  : handle turned outward (deg) from the walk direction
#   pole   : elbow pole direction (out, fwd, up) in the travel frame
#   roll   : axe rolled about its own handle (deg, + = blade face turned toward the outside/up), default 0
#   wf     : wrist follow (default WRIST_FOLLOW): the haft turns wf x the shoulder swing about the wrist.
#            Negative = the heavy head lags/trails the swing.
# The painted cutouts are seen from two fixed cameras, so the hold is cheated per facing (v3, Scenario's notes):
#  * Luca's raise is baked in: the R axe_head_centre is level with L on screen (<= ~5 px through idle and walk).
#    Scenario no longer needs their +24.9 deg R-forearm correction.
#  * S: the near R fist swings out by the right hip (upper arm out/back, elbow bent ~124 deg = the old 100 + the raise),
#    the handle turned 30 deg outward and almost level, so the R head sits outside the right leg at thigh height.
#    The L (far) hold is the approved one with a slightly steeper handle (34 deg) to meet the R head.
#  * E: both elbows hang by the ribs (L elbow below the chest joint in every frame, R elbow pulled in from x 333 to 318).
#    Forearms run forward, the handles stay forward-down. The heads trail the arm swing (wf ~ -1); otherwise the
#    opposite swings on this camera push them ~45 px apart in the walk. The far L axe stays hidden behind the body.
ARM = {
    ('S', 'R'): dict(grip=(101.0, 15.0, -49.0), haft=5.0, yaw=30.0, roll=-60.0, pole=(0.7, -0.5, -1.0), wf=0.2),
    ('S', 'L'): dict(fist_x=92.0, reach=52.0, bend=100.0, haft=34.0, yaw=0.0, pole=(0.5, -1.0, -0.1), wf=-0.2),
    ('E', 'R'): dict(grip=(83.9, 43.9, -49.5), haft=42.2, yaw=14.5, pole=(38.2, -23.6, -58.8), wf=-1.0),
    ('E', 'L'): dict(grip=(72.4, 15.7, -67.9), haft=54.7, yaw=7.7, pole=(-26.0, -26.0, -64.0), wf=-0.9),
}
IDLE_HIP = 108.0
# ---- per-facing leg length (HD match, Luca / Claude review; step 1b) ----
# walk_S only: the thigh and shin bones are lengthened by LEG_SCALE and the whole body from the pelvis up is raised by
# LEG_RAISE_PX (512-cell px, straight up on screen). The idle is NOT changed: idle_S sits on the painted HD idle legs.
# The raise is solved so Scenario's walk rebuilt on these joints (their rig + qa_walk.py) scores height_vs_idle 1.000 on
# Claude's match_metric.py. The feet are IK-pinned: every ankle (planted and swing) is first solved exactly as in the base
# rig, then the longer legs are re-solved from the raised hips to those same ankles, so stride, phase, contacts, sole
# positions and the bob shape are unchanged. Arms, axes, head and cape ride the raised chest (rigid shift).
# LEG_SCALE keeps the straightest walk leg as straight as before (hip-ankle / leg length 0.979 on the unclamped frames).
# E is untouched.
VPX = PX_PER_UNIT * math.cos(math.radians(30.0))          # screen px per world unit, vertical (0.8054)
LEG_RAISE_PX = {'S': 2.0, 'E': 0.0}
HIP_RAISE = {F: px / VPX for F, px in LEG_RAISE_PX.items()}   # world units (S: 2.48)
LEG_SCALE = {'S': 1.0275, 'E': 1.0}


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


def arm_swing(phase_f):
    """Shoulder swing (deg, + = forward) about the travel X axis per side (+1 R, -1 L); arms lag the legs half a frame."""
    if phase_f is None:
        return {1: 0.0, -1: 0.0}
    wl = 2 * math.pi * (phase_f - 0.5) / NF
    return {1: -ARM_SWING * math.cos(wl), -1: ARM_SWING * math.cos(wl)}


def arm_chain(sh, s, swing, prm):
    """Arm + axe for one side. sh = shoulder joint (character frame), s = +1 right / -1 left, swing = deg (+ forward),
    prm = ARM[(facing, side)]. The arm swings rigidly about the travel-frame X axis through the shoulder, so the
    shoulder->wrist distance (and the elbow angle) is held and the fist never moves sideways. The axe pivots about the wrist
    by WRIST_FOLLOW x swing, with the wrist fixed in the fist (WRIST_IN_FIST in the hand frame), so the fist always encloses
    wrist and handle. Returns frames: upperarm (shoulder, -Z to elbow), forearm (elbow, -Z to wrist), hand (= axe frame at
    the grip: +Y along the haft toward the head, +X = blade-face normal, horizontal, so the blade plane is vertical)."""
    Rs = R('X', swing).to_3x3()
    Rax = R('X', prm.get('wf', WRIST_FOLLOW) * swing) @ R('Z', -s * prm['yaw']) @ R('X', -prm['haft']) @ R('Y', s * prm.get('roll', 0.0))
    w_loc = Rax.to_3x3() @ Vector(WRIST_IN_FIST)
    if 'grip' in prm:
        # explicit idle grip target: (|x| absolute, y and z relative to the shoulder), swung rigidly about the shoulder
        gx, gy, gz = prm['grip']
        g0 = Vector((s * gx - sh.x, gy, gz))
        grip = sh + Vector((g0.x, 0, 0)) + Rs @ Vector((0, g0.y, g0.z))
        wrist = grip + w_loc
    else:
        bend = math.radians(prm['bend'])
        D = math.sqrt(UPPER ** 2 + FORE ** 2 + 2 * UPPER * FORE * math.cos(bend))   # law of cosines, interior angle 180-bend
        wx = s * prm['fist_x'] + w_loc.x
        dx = wx - sh.x
        r = math.sqrt(max(D * D - dx * dx, 1.0))
        a = math.radians(prm['reach'])
        wrist = sh + Vector((dx, 0, 0)) + Rs @ Vector((0, r * math.cos(a), -r * math.sin(a)))
        grip = wrist - w_loc
    px, py, pz = prm['pole']
    pole = Rs @ Vector((s * px, py, pz))
    elbow, wr = two_bone(sh, wrist, UPPER, FORE, pole)
    out = {}
    out['upperarm'] = seg_matrix(sh, elbow, Rs @ Vector((0, 1, 0)))
    out['forearm'] = seg_matrix(elbow, wr, Rs @ Vector((0, 0, 1)))
    out['hand'] = T(*grip) @ Rax
    out['_wrist'] = wr
    out['_elbow'] = elbow
    return out


def pose(phase_f=None, idle=False, cheat=0.0, facing=None):
    """Return dict name -> 4x4 matrix in the character frame. facing ('S'/'E') picks the arm hold (default: from cheat)."""
    if facing is None:
        facing = 'E' if abs(cheat - CHEAT['E']) < 1e-6 else 'S'
    M = {}
    if idle:
        zh, xp, yaw_p, yaw_c, lean = IDLE_HIP, 0.0, 0.0, 0.0, 6.0
        arm = {1: 0.0, -1: 0.0}
        paul = {1: 1.4, -1: 1.4}                 # pauldron tilt, unchanged from the previous rig (keeps the top silhouette)
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
        arm = arm_swing(p)                   # right arm back when right leg fwd
        paul = {1: -7.7 * math.cos(wl), -1: 7.7 * math.cos(wl)}               # pauldron tilt, unchanged from the previous rig
        cape_lo = 10.0 + 5.0 * math.sin(2 * math.pi * (p - 2) / 6.0)
        cape_sway = 3.0 * math.sin(2 * math.pi * (p - 2) / NF)
    pel0 = T(xp, 0, zh) @ R('Z', cheat + yaw_p)                # base-rig pelvis (feet are solved from it)
    k_leg, dz = (1.0, 0.0) if idle else (LEG_SCALE.get(facing, 1.0), HIP_RAISE.get(facing, 0.0))   # walk only
    pel = T(0, 0, dz) @ pel0
    RC = R('Z', cheat)
    M['pelvis'] = pel
    chest = pel @ T(0, 0, SPINE_Z) @ R('Z', yaw_c) @ R('X', lean)
    M['chest'] = chest
    M['head'] = chest @ T(0, 6, 84) @ R('X', -lean) @ R('Z', -0.4 * yaw_c)
    M['cape_up'] = chest @ T(0, -50, 82) @ R('X', -12.0)
    M['cape_lo'] = M['cape_up'] @ T(0, 0, -100) @ R('X', -cape_lo) @ R('Y', cape_sway)
    for s, n in ((1, 'R'), (-1, 'L')):
        sh = chest @ T(s * SHOULDER[0], SHOULDER[1], SHOULDER[2])
        M['shoulder_' + n] = sh @ R('X', paul[s])                # pauldron rides the chest, follows the swing a little
        A = arm_chain(sh.translation, s, arm[s], ARM[(facing, n)])
        M['upperarm_' + n] = A['upperarm']
        M['forearm_' + n] = A['forearm']
        M['hand_' + n] = A['hand']
        M['axe_' + n] = A['hand']                                 # the axe is rigid in the fist (same frame, grip = origin)
        # legs
        hip = (pel0 @ Vector((s * HIP_X, 0, 0)))
        if idle:
            yf, lift, pitch = (6.0 if s > 0 else -6.0), 0.0, 0.0
            fx = s * 42.0
        else:
            yf, lift, pitch, _ = foot_state(phase_f, s)
            fx = s * FOOT_X
        ank_t = (RC @ Vector((fx, 0, 0))) + Vector((0, yf, ANKLE_Z + lift))
        pole = RC.to_3x3() @ Vector((s * 0.15, 1.0, 0.0))
        knee, ank = two_bone(hip, ank_t, THIGH, SHIN, pole)
        if k_leg == 1.0 and dz == 0.0:
            M['thigh_' + n] = seg_matrix(hip, knee, pole)
            M['shin_' + n] = seg_matrix(knee, ank, pole)
        else:
            # longer bones from the raised hip to the SAME ankle (incl. the base rig's swing-leg clamp)
            hip = (pel @ Vector((s * HIP_X, 0, 0)))
            assert (ank - hip).length < (THIGH + SHIN) * k_leg * 0.9995, ('leg cannot reach the pinned ankle', facing, phase_f, n)
            knee, ank2 = two_bone(hip, ank, THIGH * k_leg, SHIN * k_leg, pole)
            assert (ank2 - ank).length < 1e-3          # mathutils is float32
            Sz = Matrix.Diagonal((1.0, 1.0, k_leg, 1.0))             # bone frames carry the length: -Z * THIGH/SHIN reaches the joint
            M['thigh_' + n] = seg_matrix(hip, knee, pole) @ Sz
            M['shin_' + n] = seg_matrix(knee, ank, pole) @ Sz
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
