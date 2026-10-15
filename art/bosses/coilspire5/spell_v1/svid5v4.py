import sys; sys.path.insert(0,'/workspace/foe_walks/coilspire5_v1/spell_v1')
from svid5 import *
import cv2
from svid5 import lay2 as _l2
LOOP=144
ASCR=8.0   # screen px tip swing; stance glide = 2*ASCR per half step
KA={Kk:S1.cells(f'/workspace/art/kestrel_full/v3/attack/kestrel_attack_{Kk}_strip.png',116,0.95) for Kk in 'NESW'}
PK=[(0,(0,0,0,0)),(4,(0,0,0,0)),(18,(-22,6,-8,1.0)),(26,(-10,0,0,0.6)),(34,(-4,0,0,0.4)),(108,(-4,0,0,0.3)),(122,(0,0,0,0.5)),(144,(0,0,0,0))]
def lay3(dn):
    dv=np.array(A5.DV[dn],float); dv/=np.linalg.norm(dv); perp=np.array([-dv[1],dv[0]]); C=np.array([600,430])
    ij=C+dv*215; ke=ij+np.array([135*np.sign(dv[0]),12]); bp=C-dv*285
    L=dict(dv=dv,ij=ij,ke=ke,bp=bp)
    L['stop']=[ij-dv*82+perp*-42,ij-dv*82+perp*42,ke-dv*58+perp*-36,ke-dv*58+perp*36]
    im,rel,R=boss(dn,('',0,0,0,0,'')); A=np.array(im)[...,3]>40; ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K
    def hitboss(p):   # scorpling footprint (~70x50 above feet) vs boss legs/body
        x0,y0=int(p[0]-40-ox),int(p[1]-50-oy); sub=A[max(0,y0):max(0,y0+55),max(0,x0):max(0,x0+80)]; return sub.any()
    sp_=[]
    for ang in (-62,-22,22,62):   # fan on the heroes' side of the boss
        t=np.deg2rad(ang); u=np.array([dv[0]*np.cos(t)-dv[1]*np.sin(t),dv[0]*np.sin(t)+dv[1]*np.cos(t)]); u=u/np.hypot(u[0],u[1]*1.8)
        r=40
        while hitboss(bp+u*r) and r<400: r+=4
        sp_.append(bp+u*(r+55))   # +~1 tile beyond the legs
    sp_=[np.array([np.clip(p[0],80,1120),min(p[1],605)]) for p in sp_]
    for i in range(4):
        n_=0
        while hitboss(sp_[i]) and n_<60: sp_[i]=sp_[i]+dv*4; n_+=1
    os_=sorted(range(4),key=lambda i:float(L['stop'][i]@perp)); ss_=sorted(sp_,key=lambda p:float(p@perp)); sp_=[None]*4
    for i,p in zip(os_,ss_): sp_[i]=p
    L['spawn']=sp_; L['_sproof']=[(bool(hitboss(p))) for p in sp_]
    return L
LAY3={dn:lay3(dn) for dn in 'nesw'}
_SA=np.array(SCI); _HH,_WW=_SA.shape[:2]; _YY,_XX=np.mgrid[0:_HH,0:_WW].astype(np.float32)
TIPS=[((385,592),0),((478,522),1),((548,442),0),((265,470),1),((205,330),0),((470,330),1)]   # leg tips, alternating pair groups
def _g(cx,cy,sg): return np.exp(-((_XX-cx)**2+(_YY-cy)**2)/(2*sg*sg)).astype(np.float32)
GT=[_g(x,y,74) for (x,y),_ in TIPS]; GTAIL=_g(560,150,120)*np.clip((330-_YY)/150,0,1)
def tri(u): u=u%1.0; return np.where(u<0.5,1-4*u,-1+4*(u-0.5))   # stance: +1 -> -1 (linear), swing: back
def scuttle(ph,amp):   # ph = step phase (cycles), amp = matte px; returns warped RGBA (unflipped, head left)
    dx=np.zeros_like(_XX); dy=np.zeros_like(_XX)
    for ((x,y),grp),G in zip(TIPS,GT):
        u=(ph+0.5*grp)%1.0; t=float(tri(u)); lift=float(np.sin(np.pi*(u-0.5)/0.5)) if u>=0.5 else 0.0
        dx+=G*(t*amp); dy+=G*(-lift*amp*0.35)
    dy+=GTAIL*(3.5*np.sin(2*np.pi*ph*0.5)+1.5); dx+=GTAIL*(2*np.cos(2*np.pi*ph*0.5))
    sw=np.deg2rad(1.2*np.sin(2*np.pi*ph)); cx,cy=330,420; ca,sa=np.cos(sw),np.sin(sw)
    mx=_XX-dx; my=_YY-dy; rx=cx+(mx-cx)*ca-(my-cy)*sa; ry=cy+(mx-cx)*sa+(my-cy)*ca
    out=cv2.remap(_SA,rx.astype(np.float32),ry.astype(np.float32),cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
    return Image.fromarray(out)
def scorpA(g,c,h,flip,alpha,ph=None,amp=0):
    p=SCI if ph is None else scuttle(ph,amp)
    p=p.transpose(Image.FLIP_LEFT_RIGHT) if flip else p; w=h*p.width/p.height; p=p.resize((max(2,int(w)),max(2,int(h))),Image.LANCZOS)
    if alpha<1: a=np.array(p); a[...,3]=(a[...,3]*alpha).astype(np.uint8); p=Image.fromarray(a)
    g=screen(g,CHG,(c[0],c[1]-h*0.35),w*1.2,h,0.6*alpha); g=g.copy(); g.alpha_composite(p,(int(c[0]-w/2),int(c[1]-h))); return g
def bar(g,c,h,hp,mp):
    d=ImageDraw.Draw(g); x,y=c[0]-17,c[1]-h-12
    d.rectangle([x-1,y-1,x+35,y+8],fill=(0,0,0,220)); d.rectangle([x,y,x+34*hp/20,y+4],fill=(220,50,60,255) if hp>0 else (0,0,0,0)); d.rectangle([x,y+5,x+34*mp/5,y+7],fill=(80,150,255,255))
    return g
def vcell(dn,f,L):
    tail,pinc,lunge,charge=lerp(f,PK); dv=L['dv']; bp=L['bp']
    im,rel,R=boss(dn,('',tail,pinc,lunge,charge,''))
    g=BIGF.crop((400,362,1600,1037)); ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K; so=bp+rel; H_=82
    sh=Image.new('RGBA',g.size); sw=R['W']*K*0.62; ImageDraw.Draw(sh).ellipse([bp[0]-sw/2,bp[1]-4-sw*.13,bp[0]+sw/2,bp[1]-4+sw*.13],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    sp=[]   # (pos, h, flip, alpha, hp, idx)
    for j,(s0,s1) in enumerate(zip(L['spawn'],L['stop'])):
        fl=(s1-s0)[0]>0
        if f<20: continue
        if j==3:   # killed early by Kestrel
            if f>=70: continue
            q=np.clip((f-28)/80,0,1); pos=s0+(s1-s0)*q
        else:
            if f>=94: continue
            q=np.clip((f-28)/64,0,1); pos=s0+(s1-s0)*q
        if f<28: rise=ez((f-20)/7); pos=pos+np.array([0,14*(1-rise)]); a_=rise; hh=H_*(0.5+0.5*rise)
        else: a_=1; hh=H_
        hp=0 if (j==3 and f>=69) else 20
        dist=float(np.linalg.norm(s1-s0))*q; ph=dist/(4*ASCR)+j*0.3 if 0<q<1 else None
        sp.append((pos,hh,fl,a_,hp,j,ph))
    # Kestrel attack window
    kat=64<=f<70; hit=94<=f<104
    items=[(bp[1],'img',im,(round(ox),round(oy)))]
    for c,p in (('ij',L['ij']),('ke',L['ke'])):
        v=CH_[c]
        if c=='ke' and kat: fs=KA[S1.TF[dn]]; hm=fs[min(len(fs)-1,(f-64))]
        else: fs=SP[(c,'hit' if hit else 'idle',S1.TF[dn])]; hm=fs[min(len(fs)-1,(f-94)//2)] if hit else fs[(f//4)%len(fs)]
        if hit: hm=tint(hm,0.1)
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],'img',hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
    for s_ in sp:
        pos=s_[0]; s3=Image.new('RGBA',g.size); ImageDraw.Draw(s3).ellipse([pos[0]-16,pos[1]-4,pos[0]+16,pos[1]+4],fill=(0,0,0,int(80*s_[3]))); g.alpha_composite(s3.filter(ImageFilter.GaussianBlur(2)))
        items.append((pos[1],'sc',s_,None))
    for y_,kind,o,xy in sorted(items,key=lambda s:s[0]):
        if kind=='img': g.alpha_composite(o,xy)
        else: g=scorpA(g,o[0],o[1],o[2],o[3],o[6],ASCR*_HH/o[1])
    for pos,hh,fl,a_,hp,j,ph in sp:
        if f>=26: g=bar(g,pos,hh,hp,5)
    if 4<=f<20: k=ez((f-4)/14); g=screen(g,CHG,so,40+110*k,40+110*k,k)
    if 18<=f<28:   # remote summon flashes on the tiles
        k=np.sin(np.pi*(f-18)/10)
        for p in L['spawn']: g=screen(g,CHG,(p[0],p[1]-20),110*k+20,80*k+14,k)
    if 30<=f<92:
        for pos,hh,fl,a_,hp,j,ph in sp: g=streak(g,pos-(pos-L['spawn'][j])*0.3,pos,7,0.3)
    # Kestrel's arrow (thin pale streak) + kill
    k4=None
    if 66<=f<69:
        u=(f-66+1)/3; P0=L['ke']+np.array([0,-70]); tgt=L['spawn'][3]+(L['stop'][3]-L['spawn'][3])*((f-28)/80)+np.array([0,-30])
        P1=P0+(tgt-P0)*u; P2=P0+(tgt-P0)*max(0,u-0.4)
        ln=Image.new('L',g.size); ImageDraw.Draw(ln).line([tuple(P2),tuple(P1)],fill=255,width=3); c_=Image.new('RGBA',g.size,(235,225,195,0)); c_.putalpha(ln.filter(ImageFilter.GaussianBlur(1)).point(lambda v:int(v*0.9))); g.alpha_composite(c_)
    if f>=69:
        kp=L['spawn'][3]+(L['stop'][3]-L['spawn'][3])*((69-28)/80)
        if f<72: g=screen(g,CHG,(kp[0],kp[1]-30),50,50,0.9); g=bar(g,kp,H_,0,5) if f<71 else g
        if 70<=f<82:
            away=kp-(L['ij']+L['ke'])/2; away=away/np.linalg.norm(away); bc=kp+away*35
            b=ez((f-70)/2)*(1-ez((f-74)/8)); g=screen(g,BST if away[0]>0 else BST[:,::-1],(bc[0],bc[1]-40),170*(0.8+0.3*(f-70)/12),110*(0.8+0.3*(f-70)/12),0.95*b)
    if 94<=f<106:
        b=ez((f-94)/2)*(1-ez((f-98)/8)); pts=L['stop'][:3]
        if f<102:
            for a,c2 in zip(pts[:-1],pts[1:]): g=streak(g,a-np.array([0,40]),c2-np.array([0,45]),12,0.8*(1-ez((f-98)/4)))
        for j,p in enumerate(pts): g=screen(g,BST if j%2 else BST[:,::-1],(p[0],p[1]-40),190*(0.8+0.3*(f-94)/12),125*(0.8+0.3*(f-94)/12),0.95*b); g=screen(g,CHG,(p[0],p[1]-35),44,44,0.7*b)
    if 108<=f<126: k=np.sin(np.pi*(f-108)/18); g=screen(g,CHG,so,30+40*k,30+40*k,0.8*k)
    g=g.resize((960,540),Image.LANCZOS)
    d=ImageDraw.Draw(g); d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
    cc=np.array([150,48]); nn=np.array([-dv[1],dv[0]]); a_=cc-dv*40; b_=cc+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
    d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+nn*14),tuple(b_-dv*6-nn*14)],fill=(140,200,255,255))
    return g
def frame(n):
    G=Image.new('RGBA',(1920,1080))
    for q,dn in enumerate('nesw'): G.alpha_composite(vcell(dn,n%LOOP,LAY3[dn]),((q%2)*960,(q//2)*540))
    return G.convert('RGB')
if __name__=='__main__':
    os.makedirs('_f4',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a,b): frame(i).save(f'_f4/{i:05d}.png',compress_level=1)
