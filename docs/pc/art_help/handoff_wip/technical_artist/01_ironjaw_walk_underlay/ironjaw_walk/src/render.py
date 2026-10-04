"""Build the Ironjaw blockout in Blender (bpy, headless) and render clay / sides / sil (+ QA id) passes.
Run: .venv/bin/python src/render.py
"""
import sys, os, math, json
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Matrix, Vector
import rig, model

BASE = '/workspace/art_src/blockout/ironjaw_walk'
RND = os.path.join(BASE, 'renders')
QA = os.path.join(BASE, 'qa')
if os.environ.get('OUT'):
    RND = QA = os.environ['OUT']
W, H = 460, 360
PIVOT = (230, 329)
ELEV, AZ = 30.0, 45.0
ORTHO = 460.0 / rig.PX_PER_UNIT
S_PX = rig.PX_PER_UNIT
FACING_YAW = {'S': -90.0, 'E': 0.0}
CHEAT = {'S': float(os.environ.get('CHEAT_S', rig.CHEAT['S'])), 'E': float(os.environ.get('CHEAT_E', rig.CHEAT['E']))}
TEST = os.environ.get('TEST')          # char +Y -> world +X (screen down-right) for S, world +Y (up-right) for E
PHASE_OFFSET = {'S': 0, 'E': 1}              # E f00 = 1 frame after the right-boot contact (contacts on f05/f11, as v3.2 E)
L_CAM = Vector((-0.5, 0.62, 0.6)).normalized()   # key light: screen upper-left, toward viewer (camera space)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
coll = sc.collection

# ---- camera ----
cam_rot = (Matrix.Rotation(math.radians(AZ), 4, 'Z') @ Matrix.Rotation(math.radians(90 - ELEV), 4, 'X'))
Rv = cam_rot.col[0].xyz.normalized()     # screen right
Uv = cam_rot.col[1].xyz.normalized()     # screen up
Bv = cam_rot.col[2].xyz.normalized()     # toward camera
L_WORLD = (cam_rot.to_3x3() @ L_CAM).normalized()


def char_world(name_mats, facing):
    root = Matrix.Rotation(math.radians(FACING_YAW[facing]), 4, 'Z')
    return root, {k: root @ m for k, m in name_mats.items()}


P = model.parts()
# boot vertices in boot frame (for Yo + QA)
BOOT_V = {n: P['boot_' + n][0] for n in 'RL'}

# ---- choose the ground row: lowest planted sole over every walk frame (S and E) lands on row 329 ----
max_dn = -1e9
for F in 'SE':
    for f in range(rig.NF):
        ph = (f + PHASE_OFFSET[F]) % rig.NF
        root, Mw = char_world(rig.pose(ph, cheat=CHEAT[F], facing=F), F)
        for s, n in ((1, 'R'), (-1, 'L')):
            if not rig.foot_state(ph, s)[3]:
                continue
            for v in BOOT_V[n]:
                p = Mw['boot_' + n] @ v
                max_dn = max(max_dn, -S_PX * Uv.dot(p))
YO = 329.98 - max_dn          # continuous pixel row of the world origin (body ground point)
XO = 230.5                    # continuous pixel column of the world origin (centre of column 230)
C = (-(XO - W / 2) * Rv + (YO - H / 2) * Uv) / S_PX

cam_d = bpy.data.cameras.new('cam')
cam_d.type = 'ORTHO'
cam_d.ortho_scale = ORTHO
cam_d.sensor_fit = 'HORIZONTAL'
cam_d.clip_start = 1
cam_d.clip_end = 6000
cam = bpy.data.objects.new('cam', cam_d)
coll.objects.link(cam)
cam.matrix_world = Matrix.Translation(C + Bv * 3000) @ cam_rot
sc.camera = cam


def project(p):
    p = Vector(p)
    return (XO + S_PX * Rv.dot(p), YO - S_PX * Uv.dot(p))


# ---- render settings: Workbench, flat, no AA, transparent ----
sc.render.engine = 'BLENDER_WORKBENCH'
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = W, H, 100
sc.render.film_transparent = True
sc.render.dither_intensity = 0.0
sc.display.render_aa = 'OFF'
sh = sc.display.shading
sh.light = 'FLAT'
sh.color_type = 'VERTEX'
sh.show_object_outline = False
sh.show_cavity = False
sh.show_shadows = False
sh.show_xray = False
sh.show_backface_culling = False
sc.view_settings.view_transform = 'Standard'
sc.view_settings.look = 'None'
sc.view_settings.exposure = 0.0
sc.view_settings.gamma = 1.0
sc.display_settings.display_device = 'sRGB'
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGBA'
sc.render.image_settings.color_depth = '8'
sc.render.fps = 17
sc.render.fps_base = 17 / rig.FPS

# ---- objects / hierarchy ----
root = bpy.data.objects.new('root', None)
coll.objects.link(root)
OBJ = {}
NAMES = list(P.keys())
import bmesh
MESH = {}


def get_mesh(n, kz=1.0):
    """Part mesh; kz != 1 = the same mesh stretched along its bone (-Z) by kz (the longer S thigh/shin, rig.LEG_SCALE)."""
    key = (n, round(kz, 6))
    if key not in MESH:
        v, f = P[n]
        me = bpy.data.meshes.new(n if kz == 1.0 else '%s_x%.3f' % (n, kz))
        me.from_pydata([(x[0], x[1], x[2] * kz) for x in v], [], f)
        me.update()
        bm = bmesh.new(); bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me); bm.free(); me.update()
        me.color_attributes.new(name='Col', type='BYTE_COLOR', domain='CORNER')
        me.color_attributes.active_color = me.color_attributes['Col']
        MESH[key] = me
    return MESH[key]


for n in NAMES:
    me = get_mesh(n)
    ob = bpy.data.objects.new(n, me)
    coll.objects.link(ob)
    OBJ[n] = ob
for n in NAMES:
    par = rig.PARENT[n]
    OBJ[n].parent = root if par == 'root' else OBJ[par]
    OBJ[n].matrix_parent_inverse = Matrix.Identity(4)

ID_COL = {n: (9 * (i + 1), 255 - 9 * (i + 1), (37 * (i + 3)) % 256) for i, n in enumerate(NAMES)}


def apply_pose(Mc, facing):
    rootM = Matrix.Rotation(math.radians(FACING_YAW[facing]), 4, 'Z')
    root.matrix_basis = rootM
    # A bone frame may carry a length scale along its -Z (S thigh/shin, rig.LEG_SCALE). Blender object matrices stay rigid:
    # the scale goes into a stretched copy of the mesh instead, so world vertices are identical to Mc[n] @ v.
    Mr = {}
    for n in NAMES:
        kz = Mc[n].to_3x3().col[2].length
        if abs(kz - 1.0) > 1e-6:
            Mr[n] = Mc[n] @ Matrix.Diagonal((1.0, 1.0, 1.0 / kz, 1.0))
        else:
            Mr[n], kz = Mc[n], 1.0
        if OBJ[n].data is not get_mesh(n, kz):
            OBJ[n].data = get_mesh(n, kz)
    full = {'root': Matrix.Identity(4)}
    full.update(Mr)
    for n in NAMES:
        par = rig.PARENT[n]
        OBJ[n].matrix_basis = full[par].inverted() @ Mr[n]
    bpy.context.view_layer.update()


def set_colors(mode):
    for n in NAMES:
        ob = OBJ[n]
        me = ob.data
        att = me.color_attributes['Col']
        cols = []
        R3 = ob.matrix_world.to_3x3()
        for poly in me.polygons:
            if mode == 'clay':
                nw = (R3 @ poly.normal).normalized()
                g = 0.26 + 0.68 * max(0.0, nw.dot(L_WORLD))
                c = (g, g, g)
            elif mode == 'sides':
                c = tuple(x / 255 for x in model.SIDE_COL[n])
            elif mode == 'sil':
                c = (0, 0, 0)
            else:
                c = tuple(x / 255 for x in ID_COL[n])
            cols.extend([c[0], c[1], c[2], 1.0] * poly.loop_total)
        att.data.foreach_set('color_srgb', cols)
        me.update()


def render(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


PASSES = [('clay', RND), ('sides', RND)] if TEST else [('clay', RND), ('sides', RND), ('sil', RND), ('id', os.path.join(QA, 'idpass')),
    ('bootonly_R', os.path.join(QA, 'idpass')), ('bootonly_L', os.path.join(QA, 'idpass'))]
frames_meta = {}
for F in 'SE':
    jobs = [('walk_%s_f%02d' % (F, f), (f + PHASE_OFFSET[F]) % rig.NF) for f in range(rig.NF)]
    jobs.append(('idle_%s' % F, None))
    if TEST:
        jobs = [j for j in jobs if j[0] in TEST.split(',') or j[0].replace(F, 'X') in TEST.split(',')]
    for name, ph in jobs:
        Mc = rig.pose(ph, idle=(ph is None), cheat=CHEAT[F], facing=F)
        apply_pose(Mc, F)
        meta = {'facing': F, 'phase_frame': ph, 'idle': ph is None}
        rootM = root.matrix_world
        if ph is not None:
            fidx = int(name[-2:])
            meta['hip_z'] = rig.hip_z(ph) + rig.HIP_RAISE.get(F, 0.0)
            for s, n in ((1, 'R'), (-1, 'L')):
                y, lift, pitch, planted = rig.foot_state(ph, s)
                bw = OBJ['boot_' + n].matrix_world
                vw = [bw @ v for v in BOOT_V[n]]
                fwd = (rootM.to_3x3() @ Vector((0, 1, 0)))
                # world frame = in-place render frame + root travel (v per frame along facing)
                trav = fwd * (rig.V * fidx)
                tgt = (Matrix.Rotation(math.radians(CHEAT[F]), 4, 'Z') @ Vector((rig.FOOT_X * s, 0, 0))) + Vector((0, y, rig.ANKLE_Z + lift))
                ank_err = (Mc['boot_' + n].translation - tgt).length
                meta['boot_' + n] = {
                    'planted': planted,
                    'ik_ankle_error': ank_err,
                    'verts_inplace': [list(p) for p in vw],
                    'verts_world': [list(p + trav) for p in vw],
                    'min_z': min(p.z for p in vw),
                    'proj_lowest_y': max(project(p)[1] for p in vw),
                    'proj_ankle': list(project(bw.translation)),
                }
        meta['head_proj'] = list(project(OBJ['head'].matrix_world.translation))
        meta['pelvis_proj'] = list(project(OBJ['pelvis'].matrix_world.translation))
        frames_meta[name] = meta
        for mode, d in PASSES:
            only = 'boot_' + mode[-1] if mode.startswith('bootonly') else None
            for n in NAMES:
                OBJ[n].hide_render = bool(only) and n != only
            set_colors('sil' if only else mode)
            render(os.path.join(d, mode, name + '.png'))
        for n in NAMES:
            OBJ[n].hide_render = False

cam_json = {
    'type': 'orthographic',
    'engine': 'Blender %s Workbench (flat lighting, anti-aliasing OFF, transparent film, Standard view transform)' % bpy.app.version_string,
    'elevation_deg_below_horizontal': ELEV,
    'blender_rotation_euler_xyz_deg': [90 - ELEV, 0.0, AZ],
    'azimuth_deg': AZ,
    'ortho_scale': ORTHO,
    'sensor_fit': 'HORIZONTAL',
    'resolution': [W, H],
    'px_per_world_unit_horizontal': W / ORTHO,
    'vertical_px_per_world_unit': math.cos(math.radians(ELEV)) * W / ORTHO,
    'body_yaw_cheat_deg': CHEAT,
    'body_yaw_note': 'travel (and the planted-foot slide) runs along the 2:1 diagonal = 45 deg from the camera axis; the body (pelvis and up) is turned a further 20 deg toward the camera in S (body 25 deg off the camera axis) and 35 deg away in E (body 10 deg off a pure back view), measured from the v3.2 / HD references (near/far hand and boot heights). Boots split the difference (half the cheat).',
    'ground_ratio': '2:1 (world X/Y axes project to screen (+-2, +-1) diagonals)',
    'camera_location': list(cam.matrix_world.translation),
    'camera_matrix_world': [list(r) for r in cam.matrix_world],
    'screen_right_world': list(Rv), 'screen_up_world': list(Uv), 'toward_camera_world': list(Bv),
    'world_origin_pixel': [XO, YO],
    'world_origin_note': 'world origin = ground point under the pelvis (body pivot). Continuous pixel coords (pixel (i,j) centre = (i+0.5, j+0.5)). '
                         'The lowest planted sole over all walk frames lands on row 329 (cell pivot row); the body ground point is %.2f px above it.' % (330 - YO),
    'cell': [W, H], 'cell_pivot': list(PIVOT),
    'facing_yaw_deg': FACING_YAW,
    'facing_note': 'character +Y forward. S: forward = world +X = screen down-right (3/4 front). E: forward = world +Y = screen up-right (3/4 back). '
                   'Both facings show his RIGHT side nearest the camera. W/N are flips (not rendered).',
    'key_light_camera_space': list(L_CAM), 'key_light_world': list(L_WORLD),
    'clay_shade': 'per-face flat: grey = 0.26 + 0.68*max(0, n.L), written as sRGB',
    'project_formula': 'px = %.4f + %.4f*dot(R, p); py = %.4f - %.4f*dot(U, p)' % (XO, S_PX, YO, S_PX),
}
if TEST:
    print('YO', YO); sys.exit(0)
json.dump(cam_json, open(os.path.join(BASE, 'camera.json'), 'w'), indent=1)
json.dump({'frames': frames_meta, 'id_colors': ID_COL, 'YO': YO, 'XO': XO,
           'V_world_per_frame': rig.V, 'Rv': list(Rv), 'Uv': list(Uv), 'px_per_unit': S_PX},
          open(os.path.join(QA, 'model_meta.json'), 'w'))

# ---- keyframe the S walk into the .blend for inspection (frames 1-12, idle at 20) ----
for f in range(rig.NF):
    apply_pose(rig.pose(f, cheat=CHEAT['S'], facing='S'), 'S')
    for n in NAMES + []:
        OBJ[n].rotation_mode = 'QUATERNION'
        OBJ[n].keyframe_insert('location', frame=f + 1)
        OBJ[n].keyframe_insert('rotation_quaternion', frame=f + 1)
apply_pose(rig.pose(None, idle=True, cheat=CHEAT['S'], facing='S'), 'S')
for n in NAMES:
    OBJ[n].keyframe_insert('location', frame=20)
    OBJ[n].keyframe_insert('rotation_quaternion', frame=20)
root.keyframe_insert('rotation_euler', frame=1)
sc.frame_start, sc.frame_end = 1, 12
set_colors('sides')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BASE, 'ironjaw_blockout.blend'), compress=True)
print('YO', YO, 'done')
