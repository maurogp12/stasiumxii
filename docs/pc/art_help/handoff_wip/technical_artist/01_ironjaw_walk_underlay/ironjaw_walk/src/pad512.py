"""Re-pad the 460x360 renders into 512x360 cells, export joints_512.json + joints_check.png + manifest_512.json,
and measure the axe hold (wrist/grip inside the fist) and axe-head visibility (from the id pass).
Run: .venv/bin/python src/pad512.py   (after src/render.py and src/post.py)
"""
import sys, os, math, json, hashlib
from pathlib import Path
sys.path.insert(0, os.path.dirname(__file__))
import bpy                                    # noqa: F401  (mathutils)
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import rig, model

BASE = Path('/workspace/art_src/blockout/ironjaw_walk')
SRC = BASE / 'renders'
OUT = BASE / 'renders_512'
OFF = {'S': (26, 15), 'E': (26, 31)}
PH_OFF = {'S': 0, 'E': 1}
FY = {'S': -90.0, 'E': 0.0}

# ------------------------------------------------------------------ pad
for pas in ('clay', 'sides', 'sil', 'grid'):
    (OUT / pas).mkdir(parents=True, exist_ok=True)
    for p in sorted((SRC / pas).glob('*.png')):
        if '_strip' in p.name:
            continue
        F = 'S' if ('_S_' in p.name or p.name.endswith('_S.png')) else 'E'
        im = Image.open(p).convert('RGBA')
        assert im.size == (460, 360), (p, im.size)
        if pas != 'grid':                       # grid = full-cell overlay (lines get cut, as before); figure passes must never clip
            ys = np.nonzero(np.array(im)[:, :, 3])[0]
            assert ys.max() + OFF[F][1] <= 359, ('would clip', p)
        cell = Image.new('RGBA', (512, 360), (0, 0, 0, 0))
        cell.alpha_composite(im, OFF[F])
        cell.save(OUT / pas / p.name, optimize=True)

# ------------------------------------------------------------------ joints
cam = json.loads((BASE / 'camera.json').read_text())
meta = json.loads((BASE / 'qa/model_meta.json').read_text())
XO, YO, SPX = meta['XO'], meta['YO'], meta['px_per_unit']
Rv = Vector(meta['Rv']); Uv = Vector(meta['Uv']); Bv = Vector(cam['toward_camera_world'])
P = model.parts()


def root_for(F):
    return Matrix.Rotation(math.radians(FY[F]), 4, 'Z')


def project(p, F):
    ox, oy = OFF[F]
    return [round(float(XO + SPX * Rv.dot(p) + ox), 3), round(float(YO - SPX * Uv.dot(p) + oy), 3)]


def point(root, m, v=(0, 0, 0)):
    return root @ (m @ Vector(v))


def meanv(vs):
    return sum((Vector(v) for v in vs), Vector((0, 0, 0))) / len(vs)


headv = P['head'][0]; zmax = max(v.z for v in headv)
head_top_local = meanv([v for v in headv if abs(v.z - zmax) < 1e-6])
axe_centre_local = meanv([Vector((0, y, z)) for y, z in model.AXE_HEAD])


def build_pose(F, ph, idle=False):
    root = root_for(F); Mc = rig.pose(ph, idle=idle, cheat=rig.CHEAT[F], facing=F)
    j = {}
    j['pelvis'] = root @ Mc['pelvis'].translation
    j['chest'] = root @ Mc['chest'].translation
    j['neck'] = root @ Mc['head'].translation
    j['head_top'] = point(root, Mc['head'], head_top_local)
    for s, n in ((1, 'R'), (-1, 'L')):
        j[n + '_shoulder'] = root @ Mc['upperarm_' + n].translation
        j[n + '_elbow'] = root @ Mc['forearm_' + n].translation
        j[n + '_wrist'] = point(root, Mc['forearm_' + n], (0, 0, -rig.FORE))      # end of the forearm bone, inside the fist
        j[n + '_axe_grip'] = root @ Mc['axe_' + n].translation                     # handle axis at the fist centre
        j[n + '_axe_head_centre'] = point(root, Mc['axe_' + n], axe_centre_local)
        j[n + '_hip'] = root @ Mc['thigh_' + n].translation
        j[n + '_knee'] = point(root, Mc['thigh_' + n], (0, 0, -rig.THIGH))
        j[n + '_ankle'] = root @ Mc['boot_' + n].translation
        j[n + '_toe'] = point(root, Mc['boot_' + n], (0, 42, -20))
        j[n + '_heel'] = point(root, Mc['boot_' + n], (0, -25, -20))
    parts = {'torso': (j['pelvis'], j['chest']), 'cape': (root @ Mc['cape_up'].translation, root @ Mc['cape_lo'].translation)}
    for n in 'RL':
        parts[n + '_upperarm'] = (j[n + '_shoulder'], j[n + '_elbow']); parts[n + '_forearm'] = (j[n + '_elbow'], j[n + '_wrist'])
        parts[n + '_axe'] = (j[n + '_axe_grip'], j[n + '_axe_head_centre'])
        parts[n + '_thigh'] = (j[n + '_hip'], j[n + '_knee']); parts[n + '_shin'] = (j[n + '_knee'], j[n + '_ankle'])
        parts[n + '_boot'] = (j[n + '_heel'], j[n + '_toe'])
    return root, Mc, j, parts


def axis_angle(a, b):
    return round(math.degrees(math.atan2(b[0] - a[0], b[1] - a[1])), 3)


def serialize(F, ph, idle, baselines):
    root, Mc, j, parts3 = build_pose(F, ph, idle)
    jp = {k: project(v, F) for k, v in j.items()}
    pp = {}
    for name, (a, b) in parts3.items():
        aa = project(a, F); bb = project(b, F)
        entry = {'rotation_deg': axis_angle(aa, bb), 'visible_length_scale': round(math.hypot(bb[0] - aa[0], bb[1] - aa[1]) / baselines[name], 6)}
        if name.endswith('_axe'):
            n = name[0]
            nn = (root.to_3x3() @ Mc['axe_' + n].to_3x3() @ Vector((1, 0, 0))).normalized()
            g = root @ Mc['axe_' + n].translation
            entry['blade_facing_angle_deg'] = axis_angle(project(g, F), project(g + nn, F))
        pp[name] = entry
    centers = {name: (a + b) * 0.5 for name, (a, b) in parts3.items()}
    order = ['torso', 'cape', 'R_upperarm', 'R_forearm', 'R_axe', 'L_upperarm', 'L_forearm', 'L_axe', 'R_thigh', 'R_shin', 'R_boot',
             'L_thigh', 'L_shin', 'L_boot']
    draw = sorted(order, key=lambda n: (-(Bv.dot(centers[n])), order.index(n)))
    draw = refine_order(F, ph, idle, Mc, root, draw)
    out = {'joints': jp, 'draw_order': draw, 'parts': pp}
    out.update(fx_keys(F, ph, idle, root, Mc, j))
    return out


# ------------------------------------------------------------------ additive keys for Claude's rig_fx (lbs_swing / cape_sway)
IDLE_REF = {}
CAPE_HEM_LOCAL = (0.0, 0.0, -74.0)        # bottom centre of the lower cape slab (model.py cape_lo, length 74)


def reach_ref(F, j):
    out = {}
    for n in 'RL':
        a, b = project(j[n + '_shoulder'], F), project(j[n + '_axe_grip'], F)
        out[n] = dict(angle=axis_angle(a, b), length=math.hypot(b[0] - a[0], b[1] - a[1]),
                      depth=float(Bv.dot(j[n + '_axe_grip'] - j[n + '_shoulder'])))
    return out


def fx_keys(F, ph, idle, root, Mc, j):
    sw = rig.arm_swing(None if idle else ph)
    cur = reach_ref(F, j); ref = IDLE_REF[F]
    d = {'arm_swing_deg': {n: round(sw[s], 3) for s, n in ((1, 'R'), (-1, 'L'))},
         'arm_swing_screen_deg': {n: round((cur[n]['angle'] - ref[n]['angle'] + 180) % 360 - 180, 3) for n in 'RL'},
         'cape_points': {'collar': project(root @ Mc['cape_up'].translation, F),
                         'hem': project(root @ (Mc['cape_lo'] @ Vector(CAPE_HEM_LOCAL)), F)}}
    if F == 'E':
        d['reach_vs_idle'] = {n: {'length_scale': round(cur[n]['length'] / ref[n]['length'], 4),
                                  'depth_delta_units': round(cur[n]['depth'] - ref[n]['depth'], 2),
                                  'toward_away': ('level' if abs(cur[n]['depth'] - ref[n]['depth']) < 0.5 else 'toward' if cur[n]['depth'] > ref[n]['depth'] else 'away')} for n in 'RL'}
    return d


def cape_lag(F, n=1200):
    """Frames by which the cape hem's sideways swing trails the pelvis' sideways sway, measured in the character frame
    (X = sideways to the travel) by circular cross-correlation over the walk cycle at 1/100-frame steps."""
    ps = np.arange(n) * rig.NF / n
    pel, hem = [], []
    for p in ps:
        Mc = rig.pose(p, cheat=rig.CHEAT[F], facing=F)
        pel.append(Mc['pelvis'].translation.x); hem.append((Mc['cape_lo'] @ Vector(CAPE_HEM_LOCAL)).x)
    a = np.array(pel) - np.mean(pel); b = np.array(hem) - np.mean(hem)
    cc = [float(np.dot(np.roll(a, k), b)) for k in range(n)]
    lag = int(np.argmax(cc)) * rig.NF / n
    return round(lag if lag <= rig.NF / 2 else lag - rig.NF, 2)


# Draw-order refinement from the rendered id pass. The centroid sort above is ambiguous where an arm or axe hangs right
# against the body (e.g. the far arm by the ribs in E). For every arm/axe part that overlaps another part on screen we
# look at the overlap in the id pass and put whichever is actually visible there in front, then topologically sort
# (keeping the centroid order wherever the render does not decide).
CUT_MESH = {'torso': ['pelvis', 'chest'], 'cape': ['cape_up', 'cape_lo']}
for _n in 'RL':
    CUT_MESH.update({_n + '_upperarm': ['upperarm_' + _n], _n + '_forearm': ['forearm_' + _n, 'hand_' + _n], _n + '_axe': ['axe_' + _n],
                     _n + '_thigh': ['thigh_' + _n], _n + '_shin': ['shin_' + _n], _n + '_boot': ['boot_' + _n]})
ARM_PARTS = {n + s for n in 'RL' for s in ('_upperarm', '_forearm', '_axe')}
ORDER_FIXES = []
PAIR_LOG = []


def refine_order(F, ph, idle, Mc, root, draw):
    key = 'idle_' + F if idle else 'walk_%s_f%02d' % (F, (ph - PH_OFF[F]) % rig.NF)
    idp = BASE / 'qa/idpass/id' / (key + '.png')
    if not idp.exists():
        return draw
    ida = np.array(Image.open(idp).convert('RGBA'))
    idc = {k: tuple(v) for k, v in json.loads((BASE / 'qa/model_meta.json').read_text())['id_colors'].items()}
    masks, seen = {}, {}
    for cut, meshes in CUT_MESH.items():
        m = Image.new('1', (460, 360)); d = ImageDraw.Draw(m); sv = np.zeros((360, 460), bool)
        for k in meshes:
            vs = [project(root @ (Mc[k] @ v), F) for v in P[k][0]]
            vs = [(x - OFF[F][0], y - OFF[F][1]) for x, y in vs]
            for f in P[k][1]:
                d.polygon([vs[i] for i in f], fill=1)
            c = idc[k]
            sv |= (ida[:, :, 3] > 0) & (ida[:, :, 0] == c[0]) & (ida[:, :, 1] == c[1]) & (ida[:, :, 2] == c[2])
        masks[cut] = np.array(m, dtype=bool); seen[cut] = sv
    # ignore the pixels around the joints where a limb plugs into its parent (shoulder, elbow, wrist/grip, hip, knee, ankle)
    yy, xx = np.mgrid[0:360, 0:460]; near_joint = np.zeros((360, 460), bool)
    for n in 'RL':
        for jp_ in (Mc['upperarm_' + n].translation, Mc['forearm_' + n].translation, Mc['forearm_' + n] @ Vector((0, 0, -rig.FORE)),
                    Mc['axe_' + n].translation, Mc['thigh_' + n].translation, Mc['shin_' + n].translation, Mc['boot_' + n].translation):
            x, y = project(root @ jp_, F); x -= OFF[F][0]; y -= OFF[F][1]
            near_joint |= (xx - x) ** 2 + (yy - y) ** 2 < 16 ** 2
    front = []                                        # (a, b): a is in front of b
    for a in draw:
        for b in draw:
            if a >= b or not ({a, b} & ARM_PARTS):
                continue
            ov = masks[a] & masks[b] & ~near_joint
            small = min(masks[a].sum(), masks[b].sum())
            if ov.sum() < max(30, 0.15 * small):            # only parts that substantially overlap on screen
                continue
            na, nb = int((seen[a] & ov).sum()), int((seen[b] & ov).sum())
            if max(na, nb) >= 20 and max(na, nb) >= 4 * min(na, nb):
                front.append((a, b) if na > nb else (b, a))
                PAIR_LOG.append((key, front[-1], na, nb, int(ov.sum())))
    pos = {n: i for i, n in enumerate(draw)}
    out, rest = [], list(draw)
    while rest:
        free = [n for n in rest if not any(b == n and a in rest for a, b in front)]
        n = min(free, key=pos.get) if free else rest[0]  # cycle (should not happen): fall back to the centroid order
        out.append(n); rest.remove(n)
    if out != draw:
        ORDER_FIXES.append(key)
    return out


allout = {}
for F in 'SE':
    _, _, ij_, ip = build_pose(F, None, True)
    IDLE_REF[F] = reach_ref(F, ij_)
    baselines = {name: math.hypot(project(b, F)[0] - project(a, F)[0], project(b, F)[1] - project(a, F)[1]) for name, (a, b) in ip.items()}
    allout['walk_' + F] = {'f%02d' % f: serialize(F, (f + PH_OFF[F]) % rig.NF, False, baselines) for f in range(rig.NF)}
    allout['idle_' + F] = serialize(F, None, True, baselines)

obj = {'meta': {
    'cell': [512, 360], 'pivot': [256, 329],
    'camera': {'type': cam['type'], 'azimuth_deg': cam['azimuth_deg'], 'elevation_deg_below_horizontal': cam['elevation_deg_below_horizontal'],
               'ortho_scale': cam['ortho_scale'], 'world_origin_pixel': [XO + 26, YO + 15]},
    'offsets': {'x': 26, 'y_S': 15, 'y_E': 31},
    'notes': 'Joint coordinates are camera projections in the padded 512x360 cells. S/E use y offsets 15/31; draw_order is nearest-camera first '
             '(part-centre depth, corrected from the rendered id pass wherever an arm or axe overlaps another part). '
             'Part rotation: 0 = straight down, positive = clockwise on screen. visible_length_scale is projected 2D axis length divided by the '
             'corresponding idle-frame projected length for that facing. Axe blade facing angle is the screen angle of the blade flat-face normal. '
             'wrist = end of the forearm bone (inside the fist block); axe_grip = handle axis at the fist centre (the fist encloses both).'},
    'facings': allout}
# additive meta keys (existing keys above are unchanged)
obj['meta']['walk_leg_raise'] = {
    F: {'raise_px': rig.LEG_RAISE_PX[F], 'leg_bone_scale': rig.LEG_SCALE[F], 'applies_to': 'walk frames only (idle unchanged)'} for F in 'SE'}
LAG = {F: cape_lag(F) for F in 'SE'}
obj['meta']['fx'] = {
    'cape_lag_frames': LAG,
    'notes': 'Per-frame additive keys for rig_fx. arm_swing_deg {R,L}: the rig shoulder swing about the travel X axis (+ = forward), '
             'the whole arm + axe swings rigidly by it (0 in idle). arm_swing_screen_deg {R,L}: in-plane screen angle of shoulder->axe_grip '
             'minus the idle angle (same sign convention as parts rotation_deg: 0 = down, + = clockwise); use it as the lbs_swing deg '
             '(S). reach_vs_idle {R,L} (E only): length_scale = 2D |shoulder->axe_grip| / idle; depth_delta_units = change of the '
             'grip depth relative to the shoulder vs idle (+ = toward the camera), toward_away = its sign (level if < 0.5 units); use length_scale as the '
             'lbs_swing stretch along shoulder->grip. cape_points: collar = top centre of the cape (cape_up hinge), hem = bottom centre '
             'of the lower cape slab, in cell px; cape_sway top/hem rows and dx_hem = hem x - collar x. cape_lag_frames: frames by which '
             'the cape hem sideways swing trails the pelvis sideways sway (character frame, circular cross-correlation over the cycle).'}
print('cape lag', LAG)
print('draw_order refined from the id pass in:', sorted(set(ORDER_FIXES)))
outp = OUT / 'joints_512.json'
outp.write_text(json.dumps(obj, indent=1) + '\n')

# ------------------------------------------------------------------ hold QA: wrist + grip inside the fist, distances
fist_v = {n: P['hand_' + n][0] for n in 'RL'}
hold = {'frames': {}, 'summary': {}}
dmax = 0.0; dmin = 1e9; allin = True; pxmax = 0.0
ground_min = 1e9


def inside_fist(n, Mh, p):
    loc = Mh.inverted() @ p
    v = fist_v[n][:8]                                    # main fist block = first box (8 verts)
    lo = Vector((min(q.x for q in v), min(q.y for q in v), min(q.z for q in v)))
    hi = Vector((max(q.x for q in v), max(q.y for q in v), max(q.z for q in v)))
    return all(lo[i] + 1 <= loc[i] <= hi[i] - 1 for i in range(3)), loc


for F in 'SE':
    for key, ph, idle in [('walk_%s_f%02d' % (F, f), (f + PH_OFF[F]) % rig.NF, False) for f in range(rig.NF)] + [('idle_' + F, None, True)]:
        Mc = rig.pose(ph, idle=idle, cheat=rig.CHEAT[F], facing=F)
        row = {}
        for n in 'RL':
            w = Mc['forearm_' + n] @ Vector((0, 0, -rig.FORE))
            g = Mc['axe_' + n].translation
            iw, wl = inside_fist(n, Mc['hand_' + n], w)
            ig, gl = inside_fist(n, Mc['hand_' + n], g)
            d = (w - g).length
            jj = allout[key[:6] if key.startswith('walk') else key]
            jj = jj[key[-3:]] if key.startswith('walk') else jj
            dpx = math.dist(jj['joints'][n + '_wrist'], jj['joints'][n + '_axe_grip'])
            az = min((Mc['axe_' + n] @ v).z for v in P['axe_' + n][0])
            ground_min = min(ground_min, az)
            row[n] = {'wrist_to_grip_units': round(d, 3), 'wrist_to_grip_px_512': round(dpx, 2), 'wrist_inside_fist': iw, 'grip_inside_fist': ig,
                      'handle_angle_below_horizontal_deg': round(math.degrees(math.asin(-(Mc['axe_' + n].to_3x3() @ Vector((0, 1, 0))).z)), 2),
                      'axe_lowest_z_units': round(az, 2)}
            dmax = max(dmax, d); dmin = min(dmin, d); pxmax = max(pxmax, dpx); allin &= iw and ig
        hold['frames'][key] = row
# arm/axe vs leg intersections (BVH)
hits = []
for F in 'SE':
    for ph in list(range(rig.NF)) + [None]:
        Mc = rig.pose(ph, idle=ph is None, cheat=rig.CHEAT[F], facing=F)
        tr = {k: BVHTree.FromPolygons([Mc[k] @ v for v in P[k][0]], P[k][1]) for k in P}
        for n in 'RL':
            for k in ('axe_', 'hand_', 'forearm_', 'upperarm_'):
                for o in 'RL':
                    for lk in ('thigh_', 'shin_', 'boot_'):
                        if tr[k + n].overlap(tr[lk + o]):
                            hits.append([F, ph, k + n, lk + o])
hold['summary'] = {'wrist_to_grip_units_min_max': [round(dmin, 3), round(dmax, 3)], 'wrist_to_grip_px_max': round(pxmax, 2),
                   'wrist_and_grip_inside_fist_all_frames': bool(allin), 'arm_axe_leg_intersections': hits,
                   'axe_lowest_point_z_units': round(ground_min, 2)}

# ------------------------------------------------------------------ axe-head visibility (id pass)
NAMES = list(P.keys())
IDC = {k: tuple(v) for k, v in meta['id_colors'].items()}
vis = {}
for F in 'SE':
    root = root_for(F)
    for key, ph, idle in [('walk_%s_f%02d' % (F, f), (f + PH_OFF[F]) % rig.NF, False) for f in range(rig.NF)] + [('idle_' + F, None, True)]:
        Mc = rig.pose(ph, idle=idle, cheat=rig.CHEAT[F], facing=F)
        a = np.array(Image.open(BASE / 'qa/idpass/id' / (key + '.png')).convert('RGBA'))
        row = {}
        for n in 'RL':
            hv = [Vector((x, y, z)) for x in (-4, 4) for y, z in model.AXE_HEAD]
            q = [project(root @ (Mc['axe_' + n] @ v), F) for v in hv]
            q = [(x - OFF[F][0], y - OFF[F][1]) for x, y in q]
            m = len(model.AXE_HEAD)
            mask = Image.new('1', (460, 360)); d = ImageDraw.Draw(mask)
            d.polygon(q[:m], fill=1); d.polygon(q[m:], fill=1)
            for i in range(m):
                d.polygon([q[i], q[(i + 1) % m], q[m + (i + 1) % m], q[m + i]], fill=1)
            mk = np.array(mask, dtype=bool)
            c = IDC['axe_' + n]
            seen = (a[:, :, 3] > 0) & (a[:, :, 0] == c[0]) & (a[:, :, 1] == c[1]) & (a[:, :, 2] == c[2]) & mk
            row[n] = round(float(seen.sum()) / max(1, int(mk.sum())), 3)
        vis[key] = row
hidden = sorted('%s %s' % (k, n) for k, r in vis.items() for n, v in r.items() if v < 0.5)
hold['axe_head_visible_fraction'] = vis
hold['axe_head_mostly_hidden(<50%)'] = hidden
(BASE / 'qa/hold_check.json').write_text(json.dumps(hold, indent=1) + '\n')

# ------------------------------------------------------------------ joints_check.png: S f00 + E f05 + idle S, joints on the clay
try:
    FONT = ImageFont.load_default(size=10)
except TypeError:
    FONT = ImageFont.load_default()
checks = [('walk_S', 'f00', 'S f00', 'walk_S_f00'), ('walk_E', 'f05', 'E f05', 'walk_E_f05'), ('idle_S', None, 'idle S', 'idle_S')]
canvas = Image.new('RGBA', (512 * len(checks), 380), (238, 236, 230, 255))
colors = {'pelvis': (255, 50, 50, 255), 'chest': (255, 150, 30, 255), 'neck': (255, 220, 30, 255), 'head_top': (255, 255, 255, 255),
          'L': (70, 130, 255, 255), 'R': (50, 230, 100, 255)}
dd = ImageDraw.Draw(canvas)
for col, (key, fr, label, fn) in enumerate(checks):
    canvas.alpha_composite(Image.open(OUT / 'clay' / (fn + '.png')).convert('RGBA'), (col * 512, 20))
    dd.text((col * 512 + 8, 3), label + '  (wrist = small ring, axe_grip = big ring, both inside the fist)', fill=(0, 0, 0, 255), font=FONT)
    dat = obj['facings'][key][fr] if fr else obj['facings'][key]
    J = dat['joints']
    for n in 'RL':      # bones
        for a_, b_ in (('shoulder', 'elbow'), ('elbow', 'wrist'), ('axe_grip', 'axe_head_centre')):
            pa = J[n + '_' + a_]; pb = J[n + '_' + b_]
            dd.line([(pa[0] + col * 512, pa[1] + 20), (pb[0] + col * 512, pb[1] + 20)], fill=colors[n], width=2)
    for name, xy in J.items():
        x, y = xy[0] + col * 512, xy[1] + 20
        side = name[0] if name[0] in 'RL' and name[1] == '_' else name
        c = colors.get(side, colors.get(name, (255, 40, 180, 255)))
        r = 3 if any(t in name for t in ('ankle', 'toe', 'heel', 'wrist')) else 4
        if 'axe_grip' in name:
            dd.ellipse((x - 6, y - 6, x + 6, y + 6), outline=(0, 0, 0, 255), width=2)
        dd.ellipse((x - r, y - r, x + r, y + r), fill=c, outline=(0, 0, 0, 255), width=1)
        if name in ('pelvis', 'head_top', 'R_axe_head_centre', 'L_axe_head_centre', 'R_wrist', 'L_wrist'):
            dd.text((x + 6, y - 5), name, fill=(0, 0, 0, 255), font=FONT)
canvas.convert('RGB').save(OUT / 'joints_check.png', optimize=True)

# ------------------------------------------------------------------ manifest_512
sha = {str(p.relative_to(OUT)): hashlib.sha256(p.read_bytes()).hexdigest()
       for p in sorted(list(OUT.glob('*/*.png')) + [OUT / 'joints_512.json', OUT / 'joints_check.png'])}
man = {'cell': [512, 360], 'pivot': [256, 329], 'offset_from_460_render': {'x': 26, 'y_S': 15, 'y_E': 31},
       'note': 'Pivot = idle soles per facing, to match the HD paintings (idle soles on row 329). Walk contact soles land up to ~15 px (S) / ~20 px (E) '
               'below the pivot in a true 2:1 view; that is correct, keep it.',
       'sha256': sha}
(OUT / 'manifest_512.json').write_text(json.dumps(man, indent=1) + '\n')
print(json.dumps(hold['summary'], indent=1))
print('mostly hidden heads:', hidden)
