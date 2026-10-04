"""per-frame support sole (metric definition) cand vs clay + contact sheet. usage: sole_dbg.py F DIR out.png"""
import sys, json, math, numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, __import__('os').path.dirname(__file__))
import bastion_metric as MM
F, D, OUT = sys.argv[1:4]
BB = '/workspace/handoff/class_walk_blockouts/bastion/blockout_v2/'
J = json.load(open(BB + 'joints_512.json'))['facings'][f'walk_{F}']
MM.PREFIX = 'bastion'
tiles = []
for i in range(12):
    jj = J[f'f{i:02d}']['joints']; sup = 'R' if jj['R_ankle'][1] >= jj['L_ankle'][1] else 'L'
    xs = [jj[f'{sup}_toe'][0], jj[f'{sup}_heel'][0], jj[f'{sup}_ankle'][0]]; y0 = jj[f'{sup}_ankle'][1] - 4
    rc, mc = MM.load(D, F, i); rv, mv = MM.load(BB + 'clay', F, i)
    pc = MM.sole(mc & ~MM.cloth(rc), min(xs) - 12, max(xs) + 12, y0); pv = MM.sole(mv & ~MM.cloth(rv), min(xs) - 12, max(xs) + 12, y0)
    print(i, sup, 'cand', pc, 'clay', pv, 'd', None if not (pc and pv) else (round(pc[0] - pv[0], 1), pc[1] - pv[1]))
    im = Image.fromarray(MM.comp(rc, mc).astype(np.uint8)).convert('RGB'); dr = ImageDraw.Draw(im)
    cm = (mv.astype(np.uint8)); 
    a = np.asarray(im).copy(); edge = mv ^ np.pad(mv, 1)[1:-1, 2:]; a[edge] = (255, 255, 0); im = Image.fromarray(a); dr = ImageDraw.Draw(im)
    dr.rectangle([min(xs) - 12, y0, max(xs) + 12, 359], outline=(0, 255, 0))
    for p, col in ((pc, (255, 0, 0)), (pv, (0, 128, 255))):
        if p: dr.ellipse([p[0] - 3, p[1] - 3, p[0] + 3, p[1] + 3], outline=col)
    tiles.append(im.crop((128, 180, 384, 360)))
W, H = tiles[0].size; sheet = Image.new('RGB', (W * 6, H * 2))
for k, t in enumerate(tiles): sheet.paste(t, ((k % 6) * W, (k // 6) * H))
sheet.save(OUT)
