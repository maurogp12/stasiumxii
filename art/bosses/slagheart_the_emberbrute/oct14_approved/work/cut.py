import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as nd
for d in 'en':
    m=Image.open(f'/workspace/art/bosses/slagheart_the_emberbrute/_work/matte/sh_{d}.png').convert('RGBA')
    m=m.resize((round(1280*0.39),round(720*0.39)),Image.LANCZOS); a=np.array(m)
    al=a[...,3]; c=a[...,:3].astype(float); L=c@[.299,.587,.114]; sat=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1)
    hard=al>=128; hard&=~((sat<0.12)&(L>95))   # drop grey bg/shadow residue
    lab,n=nd.label(hard); sz=nd.sum(hard,lab,range(1,n+1)); hard=lab==(np.argmax(sz)+1)
    a[...,3]=np.where(hard,255,0); a[~hard]=0
    ys,xs=np.nonzero(hard); cx=(xs.min()+xs.max())//2; bot=ys.max()
    o=np.zeros((336,288,4),np.uint8); sx,sy=cx-144,bot-302
    ys2,xs2=np.nonzero(hard); o[ys2-sy,xs2-sx]=a[ys2,xs2]
    Image.fromarray(o).save(f'base_{d}.png'); print(d,xs.min()-sx,xs.max()-sx,ys.min()-sy,bot-sy)
    g=Image.new('RGBA',(288,336),(30,34,40,255)); g.alpha_composite(Image.fromarray(o)); g=g.resize((576*2//2*2//2*2//1//1,672),Image.NEAREST) if False else g.resize((576,672),Image.NEAREST)
    dr=ImageDraw.Draw(g)
    for x in range(0,288,20): dr.line([(x*2,0),(x*2,672)],fill=(255,255,0,80)); dr.text((x*2+2,2),str(x),fill='yellow')
    for y in range(0,336,20): dr.line([(0,y*2),(576,y*2)],fill=(255,255,0,80)); dr.text((2,y*2+2),str(y),fill='yellow')
    g.save(f'/tmp/sg_{d}.png')
