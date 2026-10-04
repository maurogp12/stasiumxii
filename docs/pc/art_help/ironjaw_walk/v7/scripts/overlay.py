import sys, json, numpy as np
sys.path.insert(0, '/workspace/handoff/ironjaw_walk_claude/claude_reply/scripts')
import match_metric as MM
from PIL import Image
n=sys.argv[1]; d=f'var/{n}/out/walk'
r=json.load(open(f'var/{n}/mm_{n}_E.json'))['fit']
trgb, ta, _ = MM.cut_target('/workspace/scratch/ij_walk/repaint_E2/rp_E_stride_t2.jpg')
tr, tm = MM.place(trgb, ta, r['scale'], r['tx'], r['ty'])
cr, cm = MM.load(d, 'E', 0)
C=MM.comp(cr,cm); T=MM.comp(tr,tm)
ov=np.zeros((360,512,3),np.uint8); ov[...]=60; ov[cm&~tm]=(255,80,80); ov[tm&~cm]=(80,160,255); ov[cm&tm]=(200,200,200)
bl=(C.astype(int)//2+T.astype(int)//2).astype(np.uint8)
im=np.hstack([C,T,ov,bl])[60:360, 60:452*4]
im=np.hstack([x[:, 60:452] for x in (C[60:360],T[60:360],ov[60:360])])
Image.fromarray(im).resize((im.shape[1]*3//2, im.shape[0]*3//2)).save(f'ov_{n}.png')
