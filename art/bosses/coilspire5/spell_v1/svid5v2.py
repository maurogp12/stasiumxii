import sys; sys.path.insert(0,'/workspace/foe_walks/coilspire5_v1/spell_v1')
from svid5 import *
LOOP=96
KA={Kk:S1.cells(f'/workspace/art/kestrel_full/v3/attack/kestrel_attack_{Kk}_strip.png',116,0.95) for Kk in 'NESW'}
PK=[(0,(0,0,0,0)),(4,(0,0,0,0)),(18,(-22,6,-8,1.0)),(26,(-10,0,0,0.6)),(34,(-4,0,0,0.4)),(70,(-4,0,0,0.3)),(84,(0,0,0,0.5)),(96,(0,0,0,0))]
def lay3(dn):
    L=lay2(dn); dv=L['dv']; perp=np.array([-dv[1],dv[0]])
    sd=np.sign(dv[0]); L['spawn']=[L['ij']+np.array([-sd*45,84]),L['ij']+np.array([sd*40,90]),L['ke']+np.array([sd*115,34]),L['ke']+np.array([sd*55,80])]
    return L
LAY3={dn:lay3(dn) for dn in 'nesw'}
def scorpA(g,c,h,flip,alpha):
    p=SCI.transpose(Image.FLIP_LEFT_RIGHT) if flip else SCI; w=h*p.width/p.height; p=p.resize((max(2,int(w)),max(2,int(h))),Image.LANCZOS)
    if alpha<1: a=np.array(p); a[...,3]=(a[...,3]*alpha).astype(np.uint8); p=Image.fromarray(a)
    g=screen(g,CHG,(c[0],c[1]-h*0.35),w*1.2,h,0.6*alpha); g=g.copy(); g.alpha_composite(p,(int(c[0]-w/2),int(c[1]-h))); return g
def bar(g,c,h,hp,mp):
    d=ImageDraw.Draw(g); x,y=c[0]-17,c[1]-h-12
    d.rectangle([x-1,y-1,x+35,y+8],fill=(0,0,0,220)); d.rectangle([x,y,x+34*hp/20,y+4],fill=(220,50,60,255) if hp>0 else (0,0,0,0)); d.rectangle([x,y+5,x+34*mp/5,y+7],fill=(80,150,255,255))
    return g
def vcell(dn,f,L):
    tail,pinc,lunge,charge=lerp(f,PK); dv=L['dv']; bp=L['bp']
    im,rel,R=boss(dn,('',tail,pinc,lunge,charge,''))
    g=BIGF.crop((520,430,1480,970)); ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K; so=bp+rel; H_=82
    sh=Image.new('RGBA',g.size); sw=R['W']*K*0.62; ImageDraw.Draw(sh).ellipse([bp[0]-sw/2,bp[1]-4-sw*.13,bp[0]+sw/2,bp[1]-4+sw*.13],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    sp=[]   # (pos, h, flip, alpha, hp, idx)
    for j,(s0,s1) in enumerate(zip(L['spawn'],L['stop'])):
        fl=(s1-s0)[0]>0
        if f<20: continue
        if j==3:   # killed early by Kestrel
            if f>=42: continue
            q=ez((f-28)/30); pos=s0+(s1-s0)*q
        else:
            if f>=56: continue
            q=ez((f-28)/26); pos=s0+(s1-s0)*q
        if f<28: rise=ez((f-20)/7); pos=pos+np.array([0,14*(1-rise)]); a_=rise; hh=H_*(0.5+0.5*rise)
        else: a_=1; hh=H_
        if 28<=f<54: pos=pos+np.array([0,-3*abs(np.sin((f+j*2)*1.6))])
        hp=0 if (j==3 and f>=41) else 20
        sp.append((pos,hh,fl,a_,hp,j))
    # Kestrel attack window
    kat=36<=f<42; hit=56<=f<66
    items=[(bp[1],'img',im,(round(ox),round(oy)))]
    for c,p in (('ij',L['ij']),('ke',L['ke'])):
        v=CH_[c]
        if c=='ke' and kat: fs=KA[S1.TF[dn]]; hm=fs[min(len(fs)-1,(f-36))]
        else: fs=SP[(c,'hit' if hit else 'idle',S1.TF[dn])]; hm=fs[min(len(fs)-1,(f-56)//2)] if hit else fs[(f//4)%len(fs)]
        if hit: hm=tint(hm,0.1)
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],'img',hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
    for s_ in sp:
        pos=s_[0]; s3=Image.new('RGBA',g.size); ImageDraw.Draw(s3).ellipse([pos[0]-16,pos[1]-4,pos[0]+16,pos[1]+4],fill=(0,0,0,int(80*s_[3]))); g.alpha_composite(s3.filter(ImageFilter.GaussianBlur(2)))
        items.append((pos[1],'sc',s_,None))
    for y_,kind,o,xy in sorted(items,key=lambda s:s[0]):
        if kind=='img': g.alpha_composite(o,xy)
        else: g=scorpA(g,o[0],o[1],o[2],o[3])
    for pos,hh,fl,a_,hp,j in sp:
        if f>=26: g=bar(g,pos,hh,hp,5)
    if 4<=f<20: k=ez((f-4)/14); g=screen(g,CHG,so,40+110*k,40+110*k,k)
    if 18<=f<28:   # remote summon flashes on the tiles
        k=np.sin(np.pi*(f-18)/10)
        for p in L['spawn']: g=screen(g,CHG,(p[0],p[1]-20),110*k+20,80*k+14,k)
    if 30<=f<54:
        for pos,hh,fl,a_,hp,j in sp: g=streak(g,pos-(pos-L['spawn'][j])*0.3,pos,7,0.3)
    # Kestrel's arrow (thin pale streak) + kill
    k4=None
    if 38<=f<41:
        u=(f-38+1)/3; P0=L['ke']+np.array([0,-70]); tgt=L['spawn'][3]+(L['stop'][3]-L['spawn'][3])*ez((f-28)/30)+np.array([0,-30])
        P1=P0+(tgt-P0)*u; P2=P0+(tgt-P0)*max(0,u-0.4)
        ln=Image.new('L',g.size); ImageDraw.Draw(ln).line([tuple(P2),tuple(P1)],fill=255,width=3); c_=Image.new('RGBA',g.size,(235,225,195,0)); c_.putalpha(ln.filter(ImageFilter.GaussianBlur(1)).point(lambda v:int(v*0.9))); g.alpha_composite(c_)
    if f>=41:
        kp=L['spawn'][3]+(L['stop'][3]-L['spawn'][3])*ez((41-28)/30)
        if f<44: g=screen(g,CHG,(kp[0],kp[1]-30),50,50,0.9); g=bar(g,kp,H_,0,5) if f<43 else g
        if 42<=f<54:
            away=kp-(L['ij']+L['ke'])/2; away=away/np.linalg.norm(away); bc=kp+away*35
            b=ez((f-42)/2)*(1-ez((f-46)/8)); g=screen(g,BST if away[0]>0 else BST[:,::-1],(bc[0],bc[1]-40),170*(0.8+0.3*(f-42)/12),110*(0.8+0.3*(f-42)/12),0.95*b)
    if 56<=f<68:
        b=ez((f-56)/2)*(1-ez((f-60)/8)); pts=L['stop'][:3]
        if f<64:
            for a,c2 in zip(pts[:-1],pts[1:]): g=streak(g,a-np.array([0,40]),c2-np.array([0,45]),12,0.8*(1-ez((f-60)/4)))
        for j,p in enumerate(pts): g=screen(g,BST if j%2 else BST[:,::-1],(p[0],p[1]-40),190*(0.8+0.3*(f-56)/12),125*(0.8+0.3*(f-56)/12),0.95*b); g=screen(g,CHG,(p[0],p[1]-35),44,44,0.7*b)
    if 70<=f<88: k=np.sin(np.pi*(f-70)/18); g=screen(g,CHG,so,30+40*k,30+40*k,0.8*k)
    d=ImageDraw.Draw(g); d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
    cc=np.array([150,48]); nn=np.array([-dv[1],dv[0]]); a_=cc-dv*40; b_=cc+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
    d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+nn*14),tuple(b_-dv*6-nn*14)],fill=(140,200,255,255))
    return g
def frame(n):
    G=Image.new('RGBA',(1920,1080))
    for q,dn in enumerate('nesw'): G.alpha_composite(vcell(dn,n%LOOP,LAY3[dn]),((q%2)*960,(q//2)*540))
    return G.convert('RGB')
if __name__=='__main__':
    os.makedirs('_f2',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a,b): frame(i).save(f'_f2/{i:05d}.png',compress_level=1)
