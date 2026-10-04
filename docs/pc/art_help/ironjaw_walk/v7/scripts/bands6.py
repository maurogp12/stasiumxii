import sys, json, numpy as np, cv2
sys.path.insert(0, '/workspace/handoff/ironjaw_walk_claude/claude_reply/scripts')
import match_metric as MM
from skimage.metrics import structural_similarity
F = sys.argv[1]; d = sys.argv[2]
J = json.load(open('/workspace/art_src/blockout/ironjaw_walk/renders_512/joints_512.json'))['facings'][f'walk_{F}']
py = int(round(J['f00']['joints']['pelvis'][1]))
cr, cm = MM.load(d, F, 0); trgb, ta, _ = MM.cut_target(sys.argv[3] if len(sys.argv) > 3 else f'/workspace/scratch/ij_walk/repaint/rp_{F}_f00_t1.jpg')
iou, s, tx, ty = MM.fit(trgb, ta, cm, py); tr, tm = MM.place(trgb, ta, s, tx, ty)
C, T = MM.comp(cr, cm), MM.comp(tr, tm)
g = lambda x: cv2.resize(cv2.GaussianBlur(cv2.cvtColor(x, cv2.COLOR_RGB2GRAY), (0, 0), 1.2), (256, 180), interpolation=cv2.INTER_AREA)
_, S = structural_similarity(g(C), g(T), full=True, data_range=255, win_size=7)
U = cv2.resize((cm | tm).astype(np.uint8), (256, 180), interpolation=cv2.INTER_NEAREST) > 0
out = []
for y0 in range(0, 360, 20):
    y1 = y0 + 20; m = U[y0 // 2:y1 // 2]
    if m.sum() > 20: out.append((y0, round(float(S[y0 // 2:y1 // 2][m].mean()), 3), int(m.sum())))
print(F, d.split('/')[-3], 'fit', round(s, 4), tx, ty, out)
