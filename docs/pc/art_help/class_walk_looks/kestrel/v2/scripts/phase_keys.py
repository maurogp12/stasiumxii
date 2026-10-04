"""Drop painted PHASE KEYS back into the Kestrel rig (Claude #252 comment 5981325175: 3 phase keys per leg, fwd / under / back,
each ONE hip-to-toe painting, swapped by phase and lightly warped to the frame's joints).

Folder:  kestrel/v2/phase_keys/{S,E}_{near,far}_{fwd,under,back}.png   (the repainted guide; RGBA or flat on grey 172)
         kestrel/v2/phase_keys/{S,E}_{near,far}_{fwd,under,back}.json  (joints in that png's px; copy the guide's JSON, or
                                                                          re-mark hip/knee/ankle/toe if the painter moved them)
Pipeline per frame and leg (kbuild.render calls leg_layer() when kcfg[F]['phase_keys'] is true and the key files exist):
 1. MASK: use the png alpha if it has any transparency; else key out the flat grey 172 (colour distance ramp 8..22,
    keep the largest component, close small holes, feather 1 px).  Painted keys are cached per file.
 2. PICK the key by phase: compare the frame's thigh angle (hip->knee) and leg axis (hip->ankle) with each key's (from its
    JSON joints) and take the nearest (cost = |d thigh| + 0.5 |d axis|), with the plant phase as a tie-break
    (heel planted only -> fwd, toe planted only -> back). near / far = the frame's draw order (meta['near']).
 3. ALIGN + LIGHT WARP: 3-bone linear-blend skin key->frame (thigh hip->knee, shin knee->ankle, foot ankle->toe); each bone is
    a similarity-plus-along-stretch map (across scale = the key's export scale, so widths stay at the target ratio), with
    smoothstep blends +-knee_blend / +-boot_blend (key px scaled) at knee and ankle - the same skin as kbuild.leg_skin, so
    in-betweens are the nearest key bent to the frame's joints (no cross-dissolves, no seams).
 4. The far leg gets the rig's far_dark (12 %) and rim gap as usual; the painted key is not re-shaded (shading is painted).
usage (check the round trip with the guides as keys):  phase_keys.py --selftest"""
import os, sys, json, math, glob, numpy as np, cv2
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kcommon import HERE, unit
KDIR = os.path.join(HERE, '..', 'phase_keys'); GREY = 172; _K = {}

def load_key(path):
    if path in _K: return _K[path]
    im = np.asarray(Image.open(path).convert('RGBA')).astype(np.float32) / 255.
    a = im[..., 3]
    if a.min() > 0.99:                                     # flat grey key -> alpha from colour distance to grey 172
        d = np.abs(im[..., :3] - GREY / 255.).max(-1) * 255; a = np.clip((d - 8) / 14, 0, 1)
        m = (a > 0.5).astype(np.uint8); n, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
        if n > 1: big = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA])); m = (lab == big).astype(np.uint8)
        m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
        a = np.maximum(a * m, cv2.GaussianBlur(m.astype(np.float32), (0, 0), 1.0) * (m > 0))
        rgb = np.clip((im[..., :3] - (1 - a[..., None]) * GREY / 255.) / np.maximum(a[..., None], 1e-3), 0, 1)  # un-mix the grey edge
    else:
        rgb = im[..., :3]
    J = json.load(open(path[:-4] + '.json')); _K[path] = (np.dstack([rgb * a[..., None], a]).astype(np.float32), J); return _K[path]

def keys_for(F, role, kdir=KDIR):
    out = {}
    for ph in ('fwd', 'under', 'back'):
        p = os.path.join(kdir, f'{F}_{role}_{ph}.png')
        if os.path.exists(p) and os.path.exists(p[:-4] + '.json'): out[ph] = p
    return out

def _ang(a, b): v = np.subtract(b, a); return math.degrees(math.atan2(v[0], v[1]))

def pick(keys, Jf, heel=False, toe=False):
    best, bc = None, 9e9
    for ph, p in keys.items():
        J = load_key(p)[1]['joints']
        c = abs(_ang(Jf['hip'], Jf['knee']) - _ang(J['hip'], J['knee'])) + 0.5 * abs(_ang(Jf['hip'], Jf['ankle']) - _ang(J['hip'], J['ankle']))
        if heel and not toe and ph == 'fwd': c -= 2.0
        if toe and not heel and ph == 'back': c -= 2.0
        if c < bc: best, bc = ph, c
    return best

def bone_M(A, B, P, Q, s_w):
    """key segment A->B onto frame segment P->Q: along scale |PQ|/|AB|, across scale s_w (affine, A -> P)"""
    u = unit(np.subtract(B, A)); n = np.array([-u[1], u[0]]); v = unit(np.subtract(Q, P)); m = np.array([-v[1], v[0]])
    s_ax = math.dist(P, Q) / max(math.dist(A, B), 1e-6); L = np.outer(v, u) * s_ax + np.outer(m, n) * s_w
    return np.hstack([L, (np.asarray(P, float) - L @ np.asarray(A, float))[:, None]])

def inv_aff(M): L = np.linalg.inv(M[:, :2]); return np.hstack([L, (-L @ M[:, 2])[:, None]])

def skin(tex, Jk, Jf, out_hw, rs, s_w, knee_blend=16.0, boot_blend=14.0):
    """tex: premultiplied key (key px); Jk: key joints (key px); Jf: frame joints (cell px); out at render scale rs.
    s_w: frame px per key px across the bones (= 1 / the key's cell_to_img scale)."""
    H, K, A, T = (np.array(Jk[k], float) for k in ('hip', 'knee', 'ankle', 'toe'))
    Ms = [bone_M(H, K, Jf['hip'], Jf['knee'], s_w), bone_M(K, A, Jf['knee'], Jf['ankle'], s_w), bone_M(A, T, Jf['ankle'], Jf['toe'], s_w)]
    ut, us = unit(K - H), unit(A - K); bk, ba = knee_blend / s_w * 0.37, boot_blend / s_w * 0.37   # blends in key px (~target px * s_up)
    def wts(p):
        sk = np.clip(((p - K) @ ut + bk) / (2 * bk), 0, 1); sk = sk * sk * (3 - 2 * sk)
        sa = np.clip(((p - A) @ us + ba) / (2 * ba), 0, 1); sa = sa * sa * (3 - 2 * sa)
        return np.stack([1 - sk, sk * (1 - sa), sk * sa], -1)
    yy, xx = np.indices(out_hw).astype(np.float32); Q = np.stack([xx, yy], -1) / rs
    P = [Q @ inv_aff(M)[:, :2].T + inv_aff(M)[:, 2] for M in Ms]
    sw = np.stack([wts(P[j])[..., j] for j in range(3)], -1); p = np.choose(np.argmax(sw, -1)[..., None], P)
    for _ in range(5):
        w = wts(p); p = w[..., 0:1] * P[0] + w[..., 1:2] * P[1] + w[..., 2:3] * P[2]
    p = p.astype(np.float32)
    return cv2.remap(tex, p[..., 0], p[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)

def leg_layer(F, role, Jf, out_hw, rs, heel=False, toe=False, kdir=KDIR):
    """premultiplied RGBA leg layer for this frame from the painted keys, or None when no keys are present"""
    ks = keys_for(F, role, kdir)
    if not ks: return None, None
    ph = pick(ks, Jf, heel, toe); tex, J = load_key(ks[ph])
    return skin(tex, J['joints'], Jf, out_hw, rs, 1.0 / J['cell_to_img']['scale']), ph

if __name__ == '__main__' and '--selftest' in sys.argv:
    # round trip: guides as keys -> render the guide frames -> compare with the procedural leg (IoU of alpha)
    import kbuild as KB, shutil, tempfile
    from kcommon import plants, CH, CW
    td = tempfile.mkdtemp(); gd = os.path.join(HERE, '..', 'phase_guides')
    for p in glob.glob(os.path.join(gd, '*_*_*.png')):
        b = os.path.basename(p)
        if b.endswith('_alpha.png') or 'contact' in b: continue
        shutil.copy(p, td); shutil.copy(p[:-4] + '.json', td)
    KB.RS = 1
    for F in 'SE':
        KB.load_layers(F); pl = plants(F)
        for i in range(12):
            acc, lay, owner, order, meta = KB.render(F, i)
            for sd in 'RL':
                g = KB.leg_geo(F, i, sd); A = KB.anchors(F)
                Jf = dict(hip=g['hip'], knee=g['kn'], ankle=g['an'], toe=KB.apm(g['Mf'], A['toe']))
                role = 'near' if meta['near'] == sd else 'far'
                L, ph = leg_layer(F, role, Jf, (CH, CW), 1, pl[sd]['heel'][i], pl[sd]['toe'][i], td)
                a0 = lay[f'{sd}_leg'][..., 3] > 0.5; a1 = L[..., 3] > 0.5
                print(F, f'f{i:02d}', sd, role, ph, 'IoU vs procedural %.3f' % ((a0 & a1).sum() / max((a0 | a1).sum(), 1)))
