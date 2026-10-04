"""Kestrel v2 phase-key paint guides (Claude, #252 comment 5981325175): 3 PHASE KEYS per leg (fwd / under / back), each ONE
full hip-to-toe painting. Exports, from the best procedural one-piece leg (cut_legs_b.py + kbuild leg_one, shaded, AA):
  phase_guides/{S,E}_{near,far}_{fwd,under,back}.png   the single leg posed at that phase on flat grey 172, ~768 px tall
  phase_guides/{S,E}_{near,far}_{fwd,under,back}.json  joints in that image's px (hip, knee, ankle, heel, toe) + source frame,
                                                        export scale (image px per cell px) and the cell->image offset
  phase_guides/phase_guides_contact.png                 all 12 guides with the joints drawn (for checking only)
Phase frames per leg (from the v3 plants): fwd = heel strike (first heel-planted frame of the stance run), under = the stance
frame whose hip->ankle axis is closest to vertical, back = toe-off (last toe-planted frame). near = the leg drawn in front
in the majority of frames.  usage: phase_guides.py [out_dir]"""
import sys, os, json, math, numpy as np, cv2
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kbuild as KB
from kcommon import *
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'phase_guides')
R = 6; OH = 768; PAD = 0.07; GREY = 172

def phase_frames(F, sd):
    pl = plants(F)[sd]; st = [bool(pl['heel'][i] or pl['toe'][i]) for i in range(12)]
    hs = [i for i in range(12) if pl['heel'][i] and not (pl['heel'][(i - 1) % 12] or pl['toe'][(i - 1) % 12])]
    to = [i for i in range(12) if pl['toe'][i] and not st[(i + 1) % 12]]
    fwd, back = hs[0], to[0]; run = []; j = fwd
    while st[j]: run.append(j); j = (j + 1) % 12
    def bend(i):
        g = KB.leg_geo(F, i, sd); a, b = unit(g['kn'] - g['hip']), unit(g['an'] - g['kn']); return math.degrees(math.acos(np.clip(np.dot(a, b), -1, 1)))
    ax = {i: abs(math.degrees(math.atan2(*(KB.leg_geo(F, i, sd)['an'] - KB.leg_geo(F, i, sd)['hip'])))) for i in run}
    cand = [i for i in (run[1:-1] or run) if bend(i) <= 8.0] or run      # under = a STRAIGHT stance frame, axis closest to vertical
    under = min(cand, key=lambda i: ax[i])
    return dict(fwd=fwd, under=under, back=back)

def joints_cell(F, i, sd):
    g = KB.leg_geo(F, i, sd); A = KB.anchors(F); Mf = g['Mf']
    return dict(hip=g['hip'].tolist(), knee=g['kn'].tolist(), ankle=g['an'].tolist(),
                heel=KB.apm(Mf, A['heel']).tolist(), toe=KB.apm(Mf, A['toe']).tolist())

def main():
    os.makedirs(OUT, exist_ok=True); KB.RS = 1
    for F in 'SE': KB.load_layers(F)
    nearside = {}
    for F in 'SE':
        cnt = {'R': 0, 'L': 0}
        for i in range(12): cnt[KB.render(F, i)[4]['near']] += 1
        nearside[F] = max(cnt, key=cnt.get)
    KB.RS = R; KB.TEX.clear(); index = {}; tiles = []
    for F in 'SE':
        KB.load_layers(F); rim0 = KB.KCFG[F].get('rim_px', 1.5); KB.KCFG[F]['rim_px'] = 0.0      # no rim cut in a standalone leg
        fd0 = KB.KCFG[F].get('far_dark', 0.12); KB.KCFG[F]['far_dark'] = 0.0   # guides un-darkened: the rig darkens the far leg itself
        for role, sd in (('near', nearside[F]), ('far', 'L' if nearside[F] == 'R' else 'R')):
            for ph, i in phase_frames(F, sd).items():
                acc, lay, owner, order, meta = KB.render(F, i)
                L = lay[f'{sd}_leg']
                rgba = KB.to_rgba_aa(L).astype(np.float32) / 255.
                ys, xs = np.nonzero(rgba[..., 3] > 0.02); y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
                p = int((y1 - y0) * PAD); y0 -= p; y1 += p; x0 -= p; x1 += p
                k = OH / (y1 - y0)                                                 # image px per hi-res px
                W_ = int(round((x1 - x0) * k)); crop = np.zeros((y1 - y0, x1 - x0, 4), np.float32)
                sy0, sx0 = max(y0, 0), max(x0, 0); sy1, sx1 = min(y1, rgba.shape[0]), min(x1, rgba.shape[1])
                crop[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = rgba[sy0:sy1, sx0:sx1]
                pm = np.dstack([crop[..., :3] * crop[..., 3:], crop[..., 3:]])
                pm = cv2.resize(pm, (W_, OH), interpolation=cv2.INTER_AREA)
                img = pm[..., :3] + (1 - pm[..., 3:]) * (GREY / 255.)
                name = f'{F}_{role}_{ph}'
                Image.fromarray(np.clip(img * 255 + .5, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + '.png'))
                Image.fromarray(np.clip(np.dstack([pm[..., :3] / np.maximum(pm[..., 3:], 1e-6), pm[..., 3:]]) * 255 + .5, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + '_alpha.png'))
                sc = R * k; off = [-x0 * k, -y0 * k]                                 # image = cell * sc + off
                Jc = joints_cell(F, i, sd); Ji = {kk: [round(v[0] * sc + off[0], 1), round(v[1] * sc + off[1], 1)] for kk, v in Jc.items()}
                g = KB.leg_geo(F, i, sd)
                info = dict(facing=F, role=role, side=sd, phase=ph, frame=f'f{i:02d}', size=[W_, OH], grey=GREY, joints=Ji,
                            joints_cell=Jc, cell_to_img=dict(scale=round(sc, 5), offset=[round(off[0], 2), round(off[1], 2)]),
                            stretch_k=round(g['st'], 3), knee_bend_deg=meta[sd]['knee_bend_deg'],
                            drawn_in_frame_as=('near' if meta['near'] == sd else 'far'), shading='volume only; far-leg 12 % darkening NOT baked (rig applies it)',
                            note='alpha version: ' + name + '_alpha.png; joints in this image px (x right, y down)')
                json.dump(info, open(os.path.join(OUT, name + '.json'), 'w'), indent=1); index[name] = info
                t = Image.fromarray(np.clip(img * 255 + .5, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(t)
                for kk, col in (('hip', (40, 90, 230)), ('knee', (240, 140, 0)), ('ankle', (0, 160, 60)), ('heel', (200, 0, 200)), ('toe', (200, 0, 0))):
                    x, y = Ji[kk]; d.ellipse([x - 7, y - 7, x + 7, y + 7], outline=col, width=3)
                d.line([tuple(Ji['hip']), tuple(Ji['knee']), tuple(Ji['ankle']), tuple(Ji['toe'])], fill=(255, 255, 255), width=2)
                d.text((8, 8), f'{name}  f{i:02d}  bend {meta[sd]["knee_bend_deg"]} deg', fill=(0, 0, 0)); tiles.append(t)
                print(name, f'f{i:02d}', 'size', W_, OH, 'k', g['st'], 'bend', meta[sd]['knee_bend_deg'], flush=True)
        KB.KCFG[F]['rim_px'] = rim0; KB.KCFG[F]['far_dark'] = fd0
    json.dump(index, open(os.path.join(OUT, 'phase_guides_index.json'), 'w'), indent=1)
    th = 384; ts = [t.resize((int(t.width * th / t.height), th)) for t in tiles]
    rows = [ts[k:k + 6] for k in range(0, 12, 6)]; Wc = max(sum(t.width for t in r) for r in rows)
    C = Image.new('RGB', (Wc, th * len(rows)), (GREY,) * 3)
    for r, row in enumerate(rows):
        x = 0
        for t in row: C.paste(t, (x, r * th)); x += t.width
    C.save(os.path.join(OUT, 'phase_guides_contact.png'))

if __name__ == '__main__': main()
