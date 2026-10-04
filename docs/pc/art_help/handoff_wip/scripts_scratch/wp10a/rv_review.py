import sys, json; sys.path.insert(0,'/workspace/scratch/wp10a')
import numpy as np
from pathlib import Path
from PIL import Image, ImageDraw
region=sys.argv[1]; scale=int(sys.argv[2]) if len(sys.argv)>2 else 2
kit=Path(f'/workspace/stasium-pc-look/ship/wp10a_{region}')
fs=sorted((kit/'props/_2x').glob('*.png'))
cells=[]
for f in fs:
    im=Image.open(f).convert('RGBA'); w,h=im.size
    bg=Image.new('RGBA',(w,h),(128,128,128,255)); d=ImageDraw.Draw(bg)
    n=2 if w>=384 else 1
    ax,ay=w/2,h
    # footprint diamond (south tip at anchor)
    pts=[(ax,ay),(ax-64*n,ay-32*n),(ax,ay-64*n),(ax+64*n,ay-32*n)]
    d.polygon(pts,outline=(255,255,0,255))
    bg.alpha_composite(im); d=ImageDraw.Draw(bg); d.ellipse((ax-2,ay-3,ax+2,ay+1),fill=(255,0,0,255))
    bg=bg.resize((w*scale//2*1,h*scale//2*1),Image.NEAREST) if scale!=2 else bg
    cells.append((f.stem,bg))
W=sum(c[1].size[0]+8 for c in cells); H=max(c[1].size[1] for c in cells)+16
sh=Image.new('RGB',(W,H),(30,30,30)); d=ImageDraw.Draw(sh); x=0
for n,c in cells:
    sh.paste(c,(x,H-16-c.size[1])); d.text((x,H-14),n[:22],fill=(255,255,255)); x+=c.size[0]+8
sh.save(f'/workspace/scratch/wp10a/rv/review_{region}.png'); print(sh.size)
