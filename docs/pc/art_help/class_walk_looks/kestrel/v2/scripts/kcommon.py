"""Kestrel walk v1 (on Claude's v2 blockouts): shared paths, joints, plants, target loading."""
import json, math, os, numpy as np
from PIL import Image, ImageDraw
ROOT = '/workspace/handoff/class_walk_blockouts/'
B = ROOT + os.environ.get('KBLOCK', 'kestrel/blockout_v3_1/')   # blockout v3.1 (ec4beff, claude/class-walk-blockouts: wider foot track); KBLOCK=kestrel/blockout_v3/ for v3
T = ROOT + 'targets/'
HERE = os.path.dirname(os.path.abspath(__file__))
PARTS = os.environ.get('KPARTS', '/workspace/scratch/k3/parts/')
J = json.load(open(B + 'joints_512.json'))['facings']
EXP = {'S': np.array([-8.13, -4.07]), 'E': np.array([-8.13, 4.07])}   # v2 ground per frame (stride .32 H)
CW, CH = 512, 360

def frames(F): return [J['walk_' + F][f'f{i:02d}'] for i in range(12)]
def jnt(fr, k): return np.array(fr['joints'][k], float)

def plants(F, tol=0.6):
    """heel/toe planted in frame i = the joint moves with the ground into or out of frame i."""
    W = frames(F); out = {}
    for s in 'RL':
        out[s] = {}
        for k in ('heel', 'toe'):
            mv = [np.abs(jnt(W[(i + 1) % 12], f'{s}_{k}') - jnt(W[i], f'{s}_{k}') - EXP[F]).max() <= tol for i in range(12)]
            out[s][k] = [bool(mv[i] or mv[i - 1]) for i in range(12)]
    return out

def target(F):
    """approved target rgb + binary alpha. The S alpha file is an RGBA cutout: its alpha channel is the mask."""
    rgb = np.asarray(Image.open(f'{T}kestrel_rp_{F}_f00.jpg').convert('RGB'))
    a = Image.open(f'{T}kestrel_rp_{F}_f00_alpha.png')
    a = np.asarray(a)[..., 3] if a.mode == 'RGBA' else np.asarray(a.convert('L'))
    return rgb, a > 127

def poly_mask(poly, shape):
    im = Image.new('L', (shape[1], shape[0]), 0); ImageDraw.Draw(im).polygon([tuple(map(float, p)) for p in poly], fill=1)
    return np.asarray(im) > 0

def band_mask(pts, w, shape):
    im = Image.new('L', (shape[1], shape[0]), 0); ImageDraw.Draw(im).line([tuple(map(float, p)) for p in pts], fill=1, width=int(w), joint='curve')
    return np.asarray(im) > 0

def unit(v): v = np.asarray(v, float); return v / max(np.hypot(*v), 1e-9)
