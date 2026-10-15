import numpy as np, sys
from PIL import Image, ImageDraw, ImageFont
src=open('/workspace/foe_walks/slag_out/work/poses.py').read(); exec(src[:src.index('OUT={}')])
RIG={'e':dict(LA=[(18,112),(80,100),(104,124),(96,200),(72,228),(62,276),(18,276)],RA=[(184,104),(232,108),(272,130),(272,276),(214,276),(212,232),(222,200),(198,170)],
              LL=[(50,206),(143,206),(143,306),(48,306)],RL=[(143,206),(214,206),(224,306),(143,306)],ls=(84,118),rs=(190,118),lh=(100,210),rh=(180,210)),
     'n':dict(LA=[(24,112),(82,104),(104,124),(98,200),(86,232),(86,284),(24,284)],RA=[(186,104),(236,108),(262,130),(262,284),(214,284),(210,232),(214,200),(196,170)],
              LL=[(68,200),(146,200),(146,306),(64,306)],RL=[(146,200),(216,200),(222,306),(146,306)],ls=(80,118),rs=(194,118),lh=(108,206),rh=(182,206))}
ELB={'e':((48,182),(234,178)),'n':((54,182),(222,182))}
ERU=[np.array(Image.open('/workspace/art/bosses/slagheart_caldera_crown_5star/slagheart_caldera_crown_fx_eruption.png').convert('RGBA').crop((i*192,0,i*192+192,160))) for i in range(10)]
def eru(o,i,ax,ay,s=1.0):  # existing eruption fx, anchor (96,112) = impact point on floor
    im=Image.fromarray(o); f=Image.fromarray(ERU[i]); f=f.resize((round(192*s),round(160*s)),Image.LANCZOS)
    L=Image.new('RGBA',(288,336)); L.alpha_composite(f,(int(ax-96*s),int(ay-112*s))) if 0<=int(ax-96*s) and int(ax-96*s)+f.width<=288 else L.paste(f,(int(ax-96*s),int(ay-112*s)),f)
    im.alpha_composite(L); return np.array(im)
def shards(rng,n,cx,cy,sx,sy):
    pts=[(cx+rng.normal(0,sx),cy+rng.normal(0,sy),rng.uniform(2,4),(28,24,30)) for _ in range(n)]; return fxlib.soft_dots(pts,1.3,1.0)
