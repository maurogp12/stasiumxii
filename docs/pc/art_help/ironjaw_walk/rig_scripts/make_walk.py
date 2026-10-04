"""Ironjaw HD walk S/E (+W/N mirrors) as a 2D cutout rig on the TA joints (joints_512.json).
Writes v4_hd/walk, v4_hd/_norim/walk, rig/parts.json, rig/build_info.json, raw layer data for QA."""
import sys; sys.path.insert(0, '/workspace/scratch/ij_walk/rig')
from build import *
import process_sheet as ps
ROOT = '/workspace/art/ironjaw_full/v4_hd'
OUTD = {'rim': f'{ROOT}/walk', 'norim': f'{ROOT}/_norim/walk'}
for d in OUTD.values(): os.makedirs(d, exist_ok=True)
RIM = 0.45
EXP = {'S': (-12, -6), 'E': (-12, 6)}
MIR = {'S': 'W', 'E': 'N'}

# ---- pass 1: raw parts -> idle pose -> colour maps vs un-rimmed idle f00
prepare()
FIX = {}
for fac in 'SE':
    FIX[fac] = near_axe_fix(fac) if CFG['near_axe_fix'][fac] else (0.0, {'note': 'not applied'})
idle_raw = {}
MAPS, CMSTAT = {}, {}
for fac in 'SE':
    idle = J['idle_' + fac]
    rgb, al, *_ = render(fac, idle, idle, FIX[fac][0])
    idle_raw[fac] = compose_cell(rgb, al)
    ref = np.asarray(Image.open(f'{ROOT}/_norim/idle/ironjaw_idle_{fac}_f00.png').convert('RGBA'))
    MAPS[fac], CMSTAT[fac] = build_maps(idle_raw[fac], ref)
# ---- pass 2: colour-matched parts
TEX.clear(); PRE.clear()
prepare(MAPS)
json.dump(dict(scales=SCALE, arm_scale=INFO['arm_scale'], parts=INFO['parts']), open(OUT + 'parts.json', 'w'), indent=1,
          default=lambda o: o.tolist() if hasattr(o, 'tolist') else str(o))

def planted_runs(fac, side):
    W = frames(fac); ex = EXP[fac]; linked = []
    for i in range(12):
        a = W[i]['joints'][f'{side}_ankle']; b = W[(i - 1) % 12]['joints'][f'{side}_ankle']
        r0 = round(W[i]['parts'][f'{side}_boot']['rotation_deg'], 2); r1 = round(W[(i - 1) % 12]['parts'][f'{side}_boot']['rotation_deg'], 2)
        linked.append(abs(a[0] - b[0] - ex[0]) < 0.05 and abs(a[1] - b[1] - ex[1]) < 0.05 and r0 == r1)
    return linked     # linked[i]: frame i is frame i-1 shifted by EXP (both planted)

def boot_overrides(fac):
    W = frames(fac); idle = J['idle_' + fac]; ov = {i: {} for i in range(12)}; planted = {i: set() for i in range(12)}
    for side in 'RL':
        lk = planted_runs(fac, side); nm = f'{side}_boot'
        for i in range(12):
            if lk[i] and not lk[(i - 1) % 12]:      # i-1 is the run start (contact frame)
                st = (i - 1) % 12
                M0, _ = pose_matrices(fac, W[st], idle, FIX[fac][0]); M = M0[nm].copy()
                planted[st].add(side); ov[st][nm] = M.copy(); j = i
                while lk[j % 12] and (j % 12) != st:
                    M = M.copy(); M[0, 2] += EXP[fac][0]; M[1, 2] += EXP[fac][1]
                    ov[j % 12][nm] = M; planted[j % 12].add(side); j += 1
    return ov, planted

def clean_cell(cell):
    cell, nsmall = ps.drop_small(cell, 60)
    cell, nfix = ps.edge_fix(cell)
    return cell, dict(dropped_small_px=nsmall, edge_fix_px=nfix)

def ground_of(layers, al):
    boots = []; sole = 0
    for side in 'RL':
        m = layers[f'{side}_boot'] & al
        if m.any():
            ys, xs = np.nonzero(m); boots.append([int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]); sole = max(sole, int(ys.max()))
    return dict(sole_y=sole, boots=boots)

NR, RM, DATA = {}, {}, {}
for fac in 'SE':
    W = frames(fac); idle = J['idle_' + fac]; ov, planted = boot_overrides(fac)
    NR[fac], RM[fac], DATA[fac] = [], [], []
    for i, fr in enumerate(W):
        rgb, al, layers, owner, Ms, meta, order = render(fac, fr, idle, FIX[fac][0], ov[i])
        cell = compose_cell(rgb, al)
        cell, cinfo = clean_cell(cell)
        al2 = cell[..., 3] > 0
        vis = {}; top_owner = {}
        # visible px per layer (exact per-pixel owner after draw order + overrides + clean-up)
        names = list(PARTS[fac])
        for nm in order:
            v = (owner == names.index(nm)) & al2; vis[nm] = int(v.sum()); top_owner[nm] = v
        g = ground_of(layers, al2)
        el = ps.rim_eligible(cell, g)
        rim, rinfo = ps.apply_rim(cell, RIM, el)
        NR[fac].append(cell); RM[fac].append(rim)
        DATA[fac].append(dict(layers={k: v for k, v in layers.items()}, vis=vis, order=order, meta=meta, clean=cinfo, rim=rinfo,
                              planted=sorted(planted[i]), torso_top=int(np.nonzero(layers['torso'].any(1))[0].min()),
                              boot_layer={s: layers[f'{s}_boot'] for s in 'RL'}, vis_boot={s: top_owner[f'{s}_boot'] for s in 'RL'},
                              fore_vis={s: top_owner[f'{s}_forearm'] for s in 'RL'}, axe_vis={s: top_owner[f'{s}_axe'] for s in 'RL'}, fist_vis={s: top_owner[f'{s}_fist'] for s in 'RL'}, owner=owner, Ms={k: v.tolist() for k, v in Ms.items()}))

def save(arr, path): Image.fromarray(arr, 'RGBA').save(path)
def strip(fr): return np.concatenate(fr, 1)
for tag, SET in (('norim', NR), ('rim', RM)):
    for fac in 'SE':
        for F, frs in ((fac, SET[fac]), (MIR[fac], [ps.mirror(c) for c in SET[fac]])):
            for i, c in enumerate(frs): save(c, f'{OUTD[tag]}/ironjaw_walk_{F}_f{i:02d}.png')
            save(strip(frs), f'{OUTD[tag]}/ironjaw_walk_{F}_strip.png')
import pickle
pickle.dump(dict(DATA=DATA, FIX=FIX, CMSTAT=CMSTAT, idle_raw=idle_raw, CFG=CFG), open(OUT + 'walk_data.pkl', 'wb'))
json.dump(dict(scales=SCALE, arm_scale=INFO['arm_scale'], near_axe_fix=FIX, cfg=CFG, colour_match=CMSTAT,
               per_frame={fac: [dict(order=d['order'], k=d['meta'], clean=d['clean'], rim=d['rim'], planted=d['planted']) for d in DATA[fac]] for fac in 'SE'}),
          open(OUT + 'build_info.json', 'w'), indent=1, default=lambda o: o.tolist() if hasattr(o, 'tolist') else str(o))
print('fix', FIX); print('arm', INFO['arm_scale'])
for fac in 'SE':
    for i, d in enumerate(DATA[fac]): print(fac, i, d['planted'], d['meta'], d['clean'], 'vis', {k: d['vis'][k] for k in ('R_forearm', 'L_forearm', 'R_axe', 'L_axe', 'R_upperarm', 'L_upperarm', 'L_boot', 'R_boot')})
