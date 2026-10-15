import numpy as np, glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter
G='/workspace/foe_walks/_prev_out/golden_court_v5b_1021/'; SB='/workspace/stasiumxii/art/stasis/bosses/sheaf_sovereign/'
fnt=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',22)
L=lambda p:Image.open(p).convert('RGBA')
def strip(p,n=6): im=L(p); w=im.width//n; return [im.crop((i*w,0,i*w+w,im.height)) for i in range(n)]
def anchor(im):
    a=np.array(im)[...,3]>40; ys,xs=np.nonzero(a); b=ys.max(); xs2=xs[ys>b-20]; return (xs2.min()+xs2.max())/2,b
def gold(im):
    a=np.array(im).astype(int); c=a[...,:3]; mx=c.max(-1); mn=c.min(-1); sat=(mx-mn)/np.maximum(mx,1)
    m=(a[...,3]>0)&(c[...,0]>150)&(c[...,1]>105)&(sat>0.2)&(mx>165); o=np.array(im).copy(); o[~m]=0; return Image.fromarray(o.astype(np.uint8)),m
def tint(im,t=0.14):
    a=np.array(im).astype(float); a[...,0]=a[...,0]*(1-t)+230*t; a[...,1]*=1-.35*t; a[...,2]*=1-.35*t; return Image.fromarray(np.clip(a,0,255).astype(np.uint8))
def screen(base,lay,xy,k=1.0):
    L2=Image.new('RGBA',base.size); L2.alpha_composite(lay,(int(xy[0]),int(xy[1])))
    b=np.array(base).astype(float)/255; l=np.array(L2).astype(float)/255; al=l[...,3:4]*k
    b[...,:3]=1-(1-b[...,:3])*(1-l[...,:3]*al); return Image.fromarray((b*255).astype(np.uint8))
def glow(lay,r=10,k=1.6):
    g=lay.filter(ImageFilter.GaussianBlur(r)); a=np.array(g).astype(float); a[...,3]=np.clip(a[...,3]*k,0,255); return Image.fromarray(a.astype(np.uint8))
def dissolve(im,amt,seed=1):
    a=np.array(im).copy(); r=np.random.default_rng(seed).random(a.shape[:2]); ys=np.arange(a.shape[0])[:,None]/a.shape[0]
    a[...,3]=np.where(r*0.7+(1-ys)*0.3<amt,0,a[...,3]); return Image.fromarray(a)
CW,CH=384,540
def floor():
    im=Image.new('RGBA',(CW,CH),(16,18,24,255)); d=ImageDraw.Draw(im); TW,TH=96,48
    for i in range(-12,13):
        for j in range(-12,13):
            x=192+(i-j)*TW/2; y=270+(i+j)*TH/2
            d.polygon([(x,y-TH/2),(x+TW/2,y),(x,y+TH/2),(x-TW/2,y)],fill=(38,42,54,255) if (i+j)%2 else (30,34,44,255),outline=(48,54,68,255))
    return im
FL=floor()
HERO={'ij':('/workspace/art/ironjaw_full/v2/{a}/ironjaw_{a}_{K}_f0{f}.png',0.95),'ke':('/workspace/art/kestrel_full/v3/{a}/kestrel_{a}_{K}_f0{f}.png',0.9)}
def hero(c,a,K,f):
    p,s=HERO[c]; im=L(p.format(a=a,K=K,f=f)); return im.resize((int(im.width*s),int(im.height*s)),Image.LANCZOS)
def put(g,im,ax,ay,shw):
    x,y=anchor(im); sh=Image.new('RGBA',g.size); ImageDraw.Draw(sh).ellipse([ax-shw,ay-shw*.28,ax+shw,ay+shw*.28],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(4)))
    g.alpha_composite(im,(int(ax-x),int(ay-y))); return (int(ax-x),int(ay-y))
LAY={'w':dict(b=(260,250),ij=(90,440),ke=(215,500),hk='E'),'e':dict(b=(115,500),ij=(230,250),ke=(335,300),hk='W')}
def cell(dn,boss,bs,label,heroes_hit=False,vfx=None,remains=None,bsh=46):
    g=FL.copy(); Ld=LAY[dn]; items=[]
    for c in ('ij','ke'): items.append((Ld[c][1],'h',c))
    if boss is not None or remains is not None: items.append((Ld['b'][1],'b',None))
    pos=None
    for _,t,c in sorted(items):
        if t=='h':
            im=hero(c,'hit' if heroes_hit else 'idle',Ld['hk'],1 if heroes_hit else 0)
            if heroes_hit: im=tint(im,0.07)
            put(g,im,*Ld[c],30)
        else:
            im=(boss if boss is not None else remains); im=im.resize((int(im.width*bs),int(im.height*bs)),Image.LANCZOS); pos=put(g,im,*Ld['b'],bsh)
    for lay,where,k in (vfx or []):
        if where=='boss': l=lay.resize((int(lay.width*bs),int(lay.height*bs)),Image.LANCZOS); xy=pos
        else:
            hx=(Ld['ij'][0]+Ld['ke'][0])/2; hy=(Ld['ij'][1]+Ld['ke'][1])/2-40; l=lay; xy=(hx-l.width/2,hy-l.height/2)
        g=screen(g,glow(l),xy,0.9*k); g=screen(g,l,xy,k)
    d=ImageDraw.Draw(g); d.text((10,8),f'{dn.upper()} {label}',font=fnt,fill=(255,236,170,255),stroke_width=3,stroke_fill=(0,0,0,255)); return g
def sheet(rows,out,title):
    S=Image.new('RGB',(1920,1080))
    for r,cells in enumerate(rows):
        for i,c in enumerate(cells): S.paste(c.convert('RGB'),(i*CW,r*CH))
    S.save(out); print(out)
