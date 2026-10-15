import numpy as np,cv2
from PIL import Image,ImageDraw
V='/workspace/foe_walks/serra_v2/s5_walk/'
rec=[0,12,18,16,11,6,2,0]; tint=[0,.08,.06,.03,.01,0,0,0]
yy,xx=np.mgrid[:336,:288].astype(np.float32)
for d in 'nesw':
    a=np.array(Image.open(V+f'serra5_walk_{d}.png'))[:, :288]
    hard=a.copy(); hard[a[...,3]<255]=0; soft=a.copy(); soft[a[...,3]==255]=0
    sgn=-1 if d in 'ws' else 1   # recoil away from facing
    if d in 'sn': sgn=-sgn
    strip=Image.new('RGBA',(288*8,336),(0,0,0,0))
    for f in range(8):
        k=np.clip((300-yy)/260,0,1)*rec[f]*sgn
        b=cv2.remap(hard,(xx-k).astype(np.float32),yy,cv2.INTER_NEAREST,borderValue=(0,0,0,0))
        t=tint[f]; m=b[...,3]>0; b=b.astype(np.float32); b[m,:3]=b[m,:3]*(1-t)+np.array([215,240,255])*t
        o=Image.fromarray(soft); o.alpha_composite(Image.fromarray(b.astype(np.uint8))); strip.paste(o,(288*f,0))
    strip.save(f'serra5_hit_{d}.png')
# contact sheet: 4 rows on dark bg
S=Image.new('RGBA',(288*8,336*4),(36,40,52,255))
for i,d in enumerate('wsen'):
    S.alpha_composite(Image.open(f'serra5_hit_{d}.png'),(0,336*i)); ImageDraw.Draw(S).text((6,336*i+6),d.upper(),fill='white')
S.save('hit_stills_sheet.png'); S.resize((1152,672)).save('/tmp/hs.png')
