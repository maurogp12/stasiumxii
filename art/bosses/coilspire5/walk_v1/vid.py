import numpy as np, os, sys, json
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from anim5 import *
src=open('/workspace/foe_walks/serra_v2/hitdeath_v3/vid.py').read()
exec(src[src.index('def cells'):src.index('SR=')]); exec(src[src.index('CH_='):src.index('# timeline')])   # heroes + floor, same arena as Serra
def boss(dn,t,stats=None):
    side,mir=MAP[dn]; R=RIG[side]; o,tips,bob=sprite(side,t,stats); im=Image.fromarray(o)
    ax=R['cx']; 
    if mir: im=im.transpose(Image.FLIP_LEFT_RIGHT); tips=[(R['W']-x,y,l) for x,y,l in tips]
    im=im.resize((round(R['W']*K),round(R['H']*K)),Image.LANCZOS); return im,tips,R,bob
LOG={d:[] for d in 'nesw'}
def frame(n,log=False):
    t=n/FPS; G=Image.new('RGBA',(1920,1080))
    for q,dn in enumerate('nesw'):
        g=FL.copy(); dv=np.array(DV[dn],float); dv/=np.linalg.norm(dv)
        C=np.array([480,330]); s=P0+(P1-P0)*min(1,t/DUR); bp=C+dv*s; tp=C+dv*175
        T={'ij':tp+np.array([-55,-6]),'ke':tp+np.array([55,6])}
        st=[]; im,tips,R,bob=boss(dn,t,st)
        ox=bp[0]-R['W']/2*K; oy=bp[1]-R['gy']*K
        sh=Image.new('RGBA',(960,540)); sw=R['W']*K*0.62; cy=bp[1]-4
        ImageDraw.Draw(sh).ellipse([bp[0]-sw/2,cy-sw*0.13,bp[0]+sw/2,cy+sw*0.13],fill=(0,0,0,int(110-6*bob/2.5))); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
        items=[(bp[1],im,(round(ox),round(oy)))]
        for c,p in T.items():
            v=CH_[c]; fs=SP[(c,'idle',TF[dn])]; hm=fs[int(t*6)%len(fs)]
            s2=Image.new('RGBA',(960,540)); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
            items.append((p[1],hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
        for _,im_,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(im_,xy)
        if log: LOG[dn].append(dict(t=t,body=[float(bp[0]),float(bp[1])],tips=[[ox+x*K,oy+y*K,l] for x,y,l in tips]))
        d=ImageDraw.Draw(g); d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
        cc=np.array([150,48]); nn=np.array([-dv[1],dv[0]]); a_=cc-dv*40; b_=cc+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
        d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+nn*14),tuple(b_-dv*6-nn*14)],fill=(140,200,255,255))
        G.alpha_composite(g,((q%2)*960,(q//2)*540))
    return G.convert('RGB')
if __name__=='__main__':
    os.makedirs('_f',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2]); lg=len(sys.argv)>3
    for i in range(a,b): frame(i,lg).save(f'_f/{i:05d}.png',compress_level=1)
    if lg: json.dump(LOG,open('travel_log.json','w'))
