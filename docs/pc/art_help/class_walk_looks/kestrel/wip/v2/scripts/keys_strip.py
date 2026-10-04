"""before / after strip of the thigh keys: Kestrel v1 (tone-only keys) vs v2 (shape + angle keys), legs only.
Per facing and version: the R leg at its fwd / down / back key frame (thigh in colour, boot greyed), then an overlay of the
three key thighs pinned at the hip (outline colours fwd = red, down = green, back = blue) with the hip->knee axis, so a key that
only changes tone shows one outline. usage: keys_strip.py [out.png]   (internally: keys_strip.py --dump SCRIPTS_DIR OUT.npz)"""
import sys, os, json, subprocess, numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); V1 = os.path.join(HERE, '..', '..', 'v1', 'scripts')
KEYFR = {'S': dict(fwd=0, down=3, back=6), 'E': dict(fwd=4, down=7, back=10)}

def dump(sdir, out):
    sys.path.insert(0, sdir); import kbuild as KB
    res = {}
    for F in 'SE':
        KB.load_layers(F)
        # per key the most typical frame of the R leg: fwd = max thigh angle among fwd frames, back = min among back, down = |deg| min
        info = {}
        for i in range(12):
            acc, lay, owner, order, meta = KB.render(F, i); info[i] = (meta['R']['key'], meta['R']['knee'], meta['R']['hip'])
        def ang(i): kn, hp = info[i][1], info[i][2]; return float(np.degrees(np.arctan2(kn[0] - hp[0], kn[1] - hp[1])))
        mu = float(np.mean([ang(i) for i in range(12)])); pick = {}
        for k in ('fwd', 'down', 'back'):
            fr = [i for i in range(12) if info[i][0] == k] or list(range(12))
            pick[k] = max(fr, key=ang) if k == 'fwd' else (min(fr, key=ang) if k == 'back' else min(fr, key=lambda i: abs(ang(i) - mu)))
        for k, i in pick.items():
            acc, lay, owner, order, meta = KB.render(F, i)
            boot = [n for n in ('R_boot', 'R_shin', 'R_foot') if n in lay]
            b = np.zeros_like(lay['R_thigh'])
            for n in boot: L = lay[n]; b = L + b * (1 - L[..., 3:])
            res[f'{F}_{k}_thigh'] = lay['R_thigh']; res[f'{F}_{k}_boot'] = b
            res[f'{F}_{k}_meta'] = np.array(meta['R']['hip'] + meta['R']['knee'] + [i], float)
            res[f'{F}_{k}_key'] = np.array([meta['R']['key']])
    np.savez_compressed(out, **res)

def main(out):
    import cv2
    from PIL import Image, ImageDraw, ImageFont
    D = {}
    for nm, sd in (('v1', V1), ('v2', HERE)):
        p = f'/tmp/keys_{nm}.npz'; subprocess.run([sys.executable, os.path.abspath(__file__), '--dump', sd, p], check=True)
        D[nm] = np.load(p)
    try: font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 12); fb = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 13)
    except Exception: font = fb = ImageFont.load_default()
    Z = 3; CWd = 84; TW, THt = CWd * Z, 140 * Z; cols = dict(fwd=(220, 30, 30), down=(20, 150, 40), back=(30, 70, 230))
    rows = []
    for F in 'SE':
        for nm in ('v1', 'v2'):
            d = D[nm]; tiles = []; ov = Image.new('RGB', (TW, THt), 'white'); od = ImageDraw.Draw(ov)
            for k in ('fwd', 'down', 'back'):
                th, bo, me = d[f'{F}_{k}_thigh'], d[f'{F}_{k}_boot'], d[f'{F}_{k}_meta']; hip, kn = me[:2], me[2:4]
                x0, y0 = int((hip[0] + kn[0]) / 2 - CWd / 2), int(hip[1] - 10)
                crop = lambda a: a[y0:y0 + 140, x0:x0 + CWd]
                t_, b_ = crop(th), crop(bo)
                bg = np.ones(t_.shape[:2] + (3,)); g = b_[..., :3].mean(-1, keepdims=True) * 0.35 + 0.6 * b_[..., 3:]
                img = g + bg * (1 - b_[..., 3:]); img = t_[..., :3] + img * (1 - t_[..., 3:])
                im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((TW, THt), Image.NEAREST); dr = ImageDraw.Draw(im)
                P = lambda p: ((p[0] - x0) * Z, (p[1] - y0) * Z)
                dr.line([P(hip), P(kn)], fill=cols[k], width=2); dr.ellipse([P(kn)[0] - 4, P(kn)[1] - 4, P(kn)[0] + 4, P(kn)[1] + 4], outline=cols[k], width=2)
                ang = np.degrees(np.arctan2(kn[0] - hip[0], kn[1] - hip[1]))
                dr.text((3, 3), f'{nm} {F} R f{int(me[4]):02d}', fill='black', font=fb); dr.text((3, 19), f'key {d[f"{F}_{k}_key"][0]}', fill=cols[k], font=fb)
                dr.text((3, THt - 32), f'thigh {ang:+.1f} deg', fill='black', font=font); dr.text((3, THt - 17), f'knee dx {kn[0]-hip[0]:+.1f} dy {kn[1]-hip[1]:+.1f}', fill='black', font=font)
                tiles.append(im)
                # overlay outline at the hip (pinned)
                ox0 = int(hip[0] - CWd * 0.35); a = (th[y0:y0 + 140, ox0:ox0 + CWd][..., 3] > 0.5).astype(np.uint8); a = cv2.resize(a, (TW, THt), interpolation=cv2.INTER_NEAREST)
                Po = lambda p: ((p[0] - ox0) * Z, (p[1] - y0) * Z)
                cs, _ = cv2.findContours(a, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
                for c_ in cs: od.line([tuple(map(int, q[0])) for q in c_] + [tuple(map(int, c_[0][0]))], fill=cols[k], width=2)
                od.line([Po(hip), Po(kn)], fill=cols[k], width=1); od.text((Po(kn)[0] + 4, Po(kn)[1] + 2 + 12 * ['fwd', 'down', 'back'].index(k)), f'{k} {ang:+.0f}', fill=cols[k], font=font)
            od.text((3, 3), f'{nm} {F}: 3 keys pinned at hip', fill='black', font=fb)
            tiles.append(ov); rows.append(tiles)
    W = Image.new('RGB', (4 * (TW + 6) + 6, len(rows) * (THt + 6) + 30), (235, 235, 235)); dd = ImageDraw.Draw(W)
    dd.text((6, 8), 'Thigh keys before/after: v1 = one thigh shape, keys differ only in tone; v2 = shape (bend toward travel / trailing) + angle + knee position', fill='black', font=fb)
    for r, ts in enumerate(rows):
        for c, t in enumerate(ts): W.paste(t, (6 + c * (TW + 6), 30 + r * (THt + 6)))
    W.save(out); print('ok', out)

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--dump': dump(sys.argv[2], sys.argv[3])
    else: main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'legs_sheet', 'thigh_keys_v1_vs_v2.png'))
