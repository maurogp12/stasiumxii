exec(open('rig.py').read())
import cv2
from PIL import ImageFont
import json
K=0.66; BX,BY=320,404
DV={'e':(2,-1),'w':(-2,1)}; TF={'e':'W','w':'E'}
def strip(p,cw,k): im=Image.open(p).convert('RGBA'); return [im.crop((x*cw,0,x*cw+cw,im.height)).resize((round(cw*k),round(im.height*k)),Image.LANCZOS) for x in range(im.width//cw)]
CHR={'ij':dict(cw=161,piv=(80,133),k=1.03,p='/workspace/art/ironjaw_full/v2/{a}/ironjaw_{a}_{K}_strip.png'),'ke':dict(cw=116,piv=(68,141),k=0.95,p='/workspace/art/kestrel_full/v3/{a}/kestrel_{a}_{K}_strip.png')}
SPR={(c,a,K_):strip(v['p'].format(a=a,K=K_),v['cw'],v['k']) for c,v in CHR.items() for a in ('idle','hit') for K_ in 'EW'}
TWp,THp=120,60
def floor():
    im=Image.new('RGBA',(960,540),(16,18,24,255)); d=ImageDraw.Draw(im)
    for i in range(-10,11):
        for j in range(-10,11):
            x=480+(i-j)*TWp/2; y=300+(i+j)*THp/2
            d.polygon([(x,y-THp/2),(x+TWp/2,y),(x,y+THp/2),(x-TWp/2,y)],fill=(38,42,54,255) if (i+j)%2 else (30,34,44,255),outline=(48,54,68,255))
    return im
def soft(fn,blur,col,al,size=(960,540)):
    L=Image.new('L',size); fn(ImageDraw.Draw(L)); L=L.filter(ImageFilter.GaussianBlur(blur)); c=Image.new('RGBA',size,col+(0,)); c.putalpha(L.point(lambda v:int(v*al))); return c
def tint(im,t):
    a=np.array(im); m=a[...,3]>0; f=a[...,:3].astype(float); f=f*(1-t)+np.array([150,200,255])*t; a[...,:3][m]=np.clip(f[m],0,230).astype(np.uint8); return Image.fromarray(a)
POSE={'front':{'raise':(-60,-30,-20),'slam':(-20,-12,-22)},'back':{'raise':(-55,-25,-12),'slam':(40,30,-14)}}
CONN={}
def spikes(c,rad,h,seed,front):   # list of crystal spike polygons around point c (feet); front=True -> those with base below c
    rr=np.random.default_rng(seed); out=[]
    for i in range(14):
        a=np.pi*2*i/14+rr.uniform(-.2,.2); bx=c[0]+np.cos(a)*rad; by=c[1]+np.sin(a)*rad*0.45
        if (by>=c[1])!=front: continue
        H=h*rr.uniform(.75,1.1); w=rr.uniform(6,10)
        tipp=(c[0]+(bx-c[0])*0.25,by-H)   # lean inward: tips converge over the head -> cage
        out.append([(bx-w,by),(tipp[0],tipp[1]),(bx+w,by),(bx+w*0.3,by+4)])
    return out
def draw_spk(g,polys,grow,broken=False):
    if not polys: return
    L=Image.new('RGBA',(960,540)); d=ImageDraw.Draw(L)
    for p in polys:
        b=np.array(p); base=(b[0]+b[2])/2; tp=base+(b[1]-base)*grow*(0.35 if broken else 1)
        q=[tuple(b[0]),tuple(tp),tuple(b[2]),tuple(b[3])]
        d.polygon(q,fill=(120,170,215,175),outline=(205,232,250,255)); d.line([tuple(base),tuple(tp)],fill=(185,220,245,255),width=2)
    g.alpha_composite(L)
AD='/cursor/stores/store-c01dd204-c037-4a89-b6fe-7a06d7c1b2f9/grok-bot/agents/10888a55-2177-4c78-97bf-f62165f60d9b/attachments/'
def load(h):
    a=np.asarray(Image.open(AD+h+'.jpg').convert('RGB')).astype(np.float32)
    L=a.max(-1); a=a*np.clip((L-10)/30,0,1)[...,None]          # crush jpeg black noise -> no grey box
    ys,xs=np.nonzero(L>18); return a[ys.min():ys.max()+1,xs.min():xs.max()+1]
CAGE=load('9c62a2f102f6089789c5f587ba36f89c4f187e7f288ae16070883baebbc78f2c')
RING=load('69891fa769754eb11727a7215969d9ca029162d44265e4588878dfb3a4f6ebb1')
BURST=load('535c346ea611fcd5503d668bcbfc957fce289bc6a51d926e985b69bccc066e82')
def rs(a,w,h): return cv2.resize(a,(max(1,int(w)),max(1,int(h))),interpolation=cv2.INTER_AREA)
def add(g,a,cx,cy,al,anchor='c'):   # additive (screen-like) blend of black-bg asset into opaque RGBA image g
    G=np.array(g).astype(np.float32); h,w=a.shape[:2]; x0=int(cx-w/2); y0=int(cy-h/2) if anchor=='c' else int(cy-h)
    X0,Y0=max(0,x0),max(0,y0); X1,Y1=min(G.shape[1],x0+w),min(G.shape[0],y0+h)
    if X1<=X0 or Y1<=Y0: return g
    sub=a[Y0-y0:Y1-y0,X0-x0:X1-x0]; G[Y0:Y1,X0:X1,:3]=255-(255-G[Y0:Y1,X0:X1,:3])*(1-np.clip(sub*al/255,0,1))   # screen blend
    return Image.fromarray(G.clip(0,255).astype(np.uint8))
def cage_parts(width,grow=1.0):
    h=CAGE.shape[0]*width/CAGE.shape[1]*1.65; c=rs(CAGE,width,h)   # taller: crystals rise above the heads
    if grow<1: hh=max(2,int(c.shape[0]*grow)); c=rs(c,width,hh)
    yy_=np.linspace(0,1,c.shape[0])[:,None,None]; fm=np.clip((yy_-0.55)/0.12,0,1)   # lower part = front shards
    return c*(1-fm), c*fm, c.shape[0]
def stumps(a):
    st=a[int(a.shape[0]*0.62):].copy(); r=np.linspace(0,1,st.shape[0])[:,None,None]; return st*np.clip(r/0.35,0,1)   # soft top edge, no cut line
def panel(dn,moment):
    k='front' if dn=='w' else 'back'
    g=floor(); dv=np.array(DV[dn],float); dv/=np.linalg.norm(dv)
    C=np.array([480,312]); sp=C-dv*100; tp=C+dv*95; T={'ij':tp+np.array([-46,-5]),'ke':tp+np.array([46,5])}
    a0=BUILD[k][2]; du,df,da=POSE[k]['raise' if moment=='raise' else 'slam']
    o,c,lo,hi,_=pose(k,du,df,a0+da,f=0); CONN[(dn,moment)]=c
    im=o.resize((round(CW*K),round(CH*K)),Image.LANCZOS); lov=sp+(np.array(lo,float)-[BX,BY])*K; hiv=sp+(np.array(hi,float)-[BX,BY])*K
    if moment in ('slam','spikes','shatter'):      # rune ring: iso squash 0.5, smaller, additive 0.8
        rw=190; ring=rs(RING,rw,rw*RING.shape[0]/RING.shape[1]*0.5); g=add(g,ring,lov[0],lov[1],0.8 if moment!='shatter' else 0.5)
    items=[(sp[1],im,(round(sp[0]-BX*K),round(sp[1]-BY*K)),None,None)]
    for cn,p in T.items():
        v=CHR[cn]; hit=moment in ('spikes','shatter'); fs=SPR[(cn,'hit' if hit else 'idle',TF[dn])]; tim=fs[1 if moment=='spikes' else min(2,len(fs)-1) if moment=='shatter' else 0]
        if moment=='spikes': tim=tint(tim,0.12)
        if moment=='shatter': tim=tint(tim,0.10); p=p+dv*6
        sh=Image.new('RGBA',(960,540)); ImageDraw.Draw(sh).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],tim,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k'])),cn,p))
    items.sort(key=lambda s:s[0])
    for it in items:
        cn,p=it[3],it[4]; cw_=150 if cn=='ij' else 128
        if cn and moment=='spikes': back,front,ch_=cage_parts(cw_); g=add(g,back,p[0],p[1]+14,1.0,'b')
        if cn and moment=='shatter':
            back,front,ch_=cage_parts(cw_); st=stumps(back+front)    # leftover stumps: base of the cage
            g=add(g,st,p[0],p[1]+14,0.9,'b')
        g.alpha_composite(it[1],it[2])
        if cn and moment=='spikes': g=add(g,front,p[0],p[1]+14,0.6,'b')
        if cn and moment=='shatter':
            bw=135 if cn=='ij' else 118; g=add(g,rs(BURST,bw,bw*BURST.shape[0]/BURST.shape[1]),p[0],p[1]-55,0.8)
            st2=stumps(back+front); g=add(g,st2,p[0],p[1]+14,0.45,'b')
    if moment=='raise':   # soft cyan glow at the staff tip
        g.alpha_composite(soft(lambda d:d.ellipse([hiv[0]-22,hiv[1]-22,hiv[0]+22,hiv[1]+22],fill=255),10,(80,220,255),0.75))
        g.alpha_composite(soft(lambda d:d.ellipse([hiv[0]-7,hiv[1]-7,hiv[0]+7,hiv[1]+7],fill=255),3,(200,245,255),0.9))
    if moment=='slam':    # frost flash at the contact
        g=add(g,rs(BURST,80,80*BURST.shape[0]/BURST.shape[1]*0.6),lov[0],lov[1]-4,0.85)
        g.alpha_composite(soft(lambda d:d.ellipse([lov[0]-34,lov[1]-15,lov[0]+34,lov[1]+15],fill=255),9,(150,225,255),0.6))
    return g.crop((240,0,720,540))
fnt=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',28)
S=Image.new('RGB',(1920,1080),(10,11,15)); d=ImageDraw.Draw(S)
for r,dn in enumerate('we'):
    for c,m in enumerate(('raise','slam','spikes','shatter')):
        p=panel(dn,m); S.paste(p.convert('RGB'),(c*480,r*540)); p.save(f'panel_{dn}_{m}.png')
        d.text((c*480+14,r*540+10),f'{dn.upper()}  {c+1}. {m}',font=fnt,fill=(220,235,255),stroke_width=3,stroke_fill=(0,0,0))
for x in (480,960,1440): d.line([(x,0),(x,1080)],fill=(60,64,78),width=2)
d.line([(0,540),(1920,540)],fill=(60,64,78),width=2)
S.save('serra5_spell_stills.png'); print({f'{a}_{b}':v for (a,b),v in CONN.items()})
