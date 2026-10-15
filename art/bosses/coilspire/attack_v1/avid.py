import sys; sys.path.insert(0,'/workspace/foe_walks/coilspire_v2/attack_v1')
from stills import *
LOOP=72
REST=(0,0,0,0); WIND=(14,110,-20,1.0); STR=(-5,0,40,1.0); IMPc=(-3,0,34,0.6)
KEYS=[(0,REST),(6,REST),(16,WIND),(20,WIND),(23,STR),(33,IMPc),(52,REST),(72,REST)]
ez=lambda x:x*x*(3-2*x)
def params(f):
    for (a,pa),(b,pb) in zip(KEYS[:-1],KEYS[1:]):
        if a<=f<=b:
            e=ez((f-a)/(b-a)) if b>a else 1; return tuple(x+(y-x)*e for x,y in zip(pa,pb))
def qscene(dn,f):
    rear,lift,lunge,charge=params(f); side,mir=MAP[dn]; R=RIG[side]
    g=FL.copy(); dv=np.array(DV[dn],float); dv/=np.linalg.norm(dv)
    C=np.array([480,352]); bp=C+dv*-75; tp=C+dv*175
    Tg={'ij':tp+np.array([-55,-6]),'ke':tp+np.array([55,6])}
    im,tip,orbs=pose(side,rear,lift,lunge,charge)
    if mir: im=im.transpose(Image.FLIP_LEFT_RIGHT); tip=(R['W']+2*PAD-tip[0],tip[1]); orbs=[(R['W']+2*PAD-o[0],o[1]) for o in orbs]
    im=im.resize((round(im.width*K),round(im.height*K)),Image.LANCZOS); ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K
    S=lambda p:(ox+p[0]*K,oy+p[1]*K)
    sh=Image.new('RGBA',g.size); sw=R['W']*K*0.62; sx=bp[0]+dv[0]*lunge*K*0.5
    ImageDraw.Draw(sh).ellipse([sx-sw/2,bp[1]-4-sw*.13,sx+sw/2,bp[1]-4+sw*.13],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    hit=24<=f<32
    items=[(bp[1],im,(round(ox),round(oy)))]
    for c,p in Tg.items():
        v=CH_[c]; fs=SP[(c,'hit' if hit else 'idle',TF[dn])]
        hm=fs[min(len(fs)-1,(f-24)//2)] if hit else fs[(f//4)%len(fs)]
        if hit: hm=tint(hm,0.1*(1-(f-24)/8))
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
    for _,i_,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(i_,xy)
    st=S(tip); var=np.random.default_rng(11+(f//2)%3)   # 3 fork variations, swap every 2 frames
    if 6<=f<23:
        k=min(1,(f-6)/10)
        for o in orbs: glow(g,S(o),30*k+6,0.8*k)
        sp=[bolt((st[0]+var.normal(0,6),st[1]+30),(st[0]+var.normal(0,18),st[1]+110),var,0.3,4) for _ in range(3)]
        paint_bolt(g,sp,0.7*k); glow(g,st,14+22*k,k)
    if 22<=f<32:
        inten=1.0 if f<26 else 1.0-(f-26)/8*0.75
        hits=[(p[0],p[1]-60) for p in Tg.values()]; mid=(np.array(st)+np.mean(hits,0))/2-np.array([0,60])
        paths=[bolt(st,tuple(mid),var,0.22)]+[bolt(tuple(mid),h,var,0.2) for h in hits]
        paint_bolt(g,paths,inten); glow(g,st,40,inten)
        for o in orbs: glow(g,S(o),24,0.6*inten)
        for h in hits:
            if f>=24: sparks(g,h,np.random.default_rng(f),max(0,1-(f-24)/9))
            else: glow(g,h,20,0.7)
    if 32<=f<52: glow(g,st,14,0.35*(1-(f-32)/20))
    d=ImageDraw.Draw(g); d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
    cc=np.array([150,48]); nn=np.array([-dv[1],dv[0]]); a_=cc-dv*40; b_=cc+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
    d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+nn*14),tuple(b_-dv*6-nn*14)],fill=(140,200,255,255))
    return g
def frame(n):
    G=Image.new('RGBA',(1920,1080))
    for q,dn in enumerate('nesw'): G.alpha_composite(qscene(dn,n%LOOP),((q%2)*960,(q//2)*540))
    return G.convert('RGB')
if __name__=='__main__':
    os.makedirs('_f',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a,b): frame(i).save(f'_f/{i:05d}.png',compress_level=1)
