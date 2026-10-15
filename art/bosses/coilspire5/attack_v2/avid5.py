import sys; sys.path.insert(0,'/workspace/foe_walks/coilspire5_v1/attack_v2')
from pincer import *
LOOP=80
ez=lambda x:float(np.clip(x,0,1))**2*(3-2*float(np.clip(x,0,1)))
def lerp(f,keys):
    for (a,pa),(b,pb) in zip(keys[:-1],keys[1:]):
        if a<=f<=b: e=ez((f-a)/(b-a)) if b>a else 1; return [x+(y-x)*e for x,y in zip(pa,pb)]
    return list(keys[-1][1])
# tail, pinc, lunge, charge
PK=[(0,(0,0,0,0)),(8,(0,0,0,0)),(18,(-30,40,-14,0.8)),(24,(-30,40,0,0.9)),(26,(-30,-22,0,1.0)),(28,(32,-22,0,1.0)),(40,(28,-18,0,0.7)),(50,(26,-16,0,0.5)),(56,(-4,4,0,0.2)),(66,(0,0,0,0)),(80,(0,0,0,0))]
SR=40/K   # raw step length (two-beat step)
def stepinfo(f):
    # returns body progress 0..1 between rest spot and melee spot, and per-group (rel offset raw, lift)
    if 18<=f<24: q=(f-18)/6; fwd=True
    elif 50<=f<56: q=(f-50)/6; fwd=False
    else: return (1.0 if 24<=f<50 else 0.0),None
    S=SR if fwd else -SR; body=q*S
    def tip(g):   # g0 swings first half, g1 second half (world positions)
        a,b=(0,0.5) if g==0 else (0.5,1)
        if q<a: w=0
        elif q>b: w=S
        else: w=S*ez((q-a)/(b-a))
        lift=14*np.sin(np.pi*np.clip((q-a)/(b-a),0,1)) if a<=q<=b else 0
        return (w-body,lift)
    prog=q if fwd else 1-q
    return prog,{0:tip(0),1:tip(1)}
def vcell(dn,f,L):
    tail,pinc,lunge,charge=lerp(f,PK); prog,lo=stepinfo(f); dv=L['dv']
    if pinc>0: pinc=pinc*(18 if A5.MAP[dn][0]=='front' else 16)/40   # largest opening that keeps the claw intact
    bp=L['bp0']+(L['bp1']-L['bp0'])*prog
    im,rel,R=boss(dn,('',tail,pinc,lunge,charge,''),lo)
    g=BIGF.crop((520,430,1480,970)); ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K; so=bp+rel
    sh=Image.new('RGBA',g.size); sw=R['W']*K*0.62; ImageDraw.Draw(sh).ellipse([bp[0]-sw/2,bp[1]-4-sw*.13,bp[0]+sw/2,bp[1]-4+sw*.13],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    items=[(bp[1],im,(round(ox),round(oy)))]; hit=28<=f<38
    for c,p in (('ij',L['ij']),('ke',L['ke'])):
        v=CH_[c]; h=hit and c=='ij'; fs=SP[(c,'hit' if h else 'idle',S1.TF[dn])]; hm=fs[min(len(fs)-1,(f-28)//2)] if h else fs[(f//4)%len(fs)]
        if h: hm=tint(hm,0.1)
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
    for _,i_,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(i_,xy)
    contact=np.array([L['ij'][0]-np.sign(dv[0])*30,L['ij'][1]-48]); zap=np.array([L['ij'][0]-np.sign(dv[0])*10,L['ij'][1]-95])
    if 8<=f<26: g=screen(g,CHG,so,30+30*ez((f-8)/10),30+30*ez((f-8)/10),0.7)
    if 27<=f<31:
        k=1.0 if f<30 else 0.5; vz=zap-so; p1=so+vz*min(1,105/np.linalg.norm(vz)); g=streak(g,so,p1,28,1.3*k); g=screen(g,CHG,so,46,46,0.9*k); g=screen(g,CHG,zap,30,30,0.7*k)
    if 26<=f<40:
        b=ez((f-26)/2)*(1-ez((f-30)/10)); g=screen(g,BST if dv[0]<0 else BST[:,::-1],contact,110*(0.8+0.4*(f-26)/14),70*(0.8+0.4*(f-26)/14),0.85*b); g=screen(g,CHG,contact,40,40,0.7*b)
    if 40<=f<56: g=screen(g,CHG,so,30,30,0.3)
    d=ImageDraw.Draw(g); d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
    cc=np.array([150,48]); nn=np.array([-dv[1],dv[0]]); a_=cc-dv*40; b_=cc+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
    d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+nn*14),tuple(b_-dv*6-nn*14)],fill=(140,200,255,255))
    return g
LAY={dn:layout(dn) for dn in 'nesw'}
fnt=S1.fnt if hasattr(S1,'fnt') else fnt2
def frame(n):
    G=Image.new('RGBA',(1920,1080))
    for q,dn in enumerate('nesw'): G.alpha_composite(vcell(dn,n%LOOP,LAY[dn]),((q%2)*960,(q//2)*540))
    return G.convert('RGB')
if __name__=='__main__':
    os.makedirs('_f',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a,b): frame(i).save(f'_f/{i:05d}.png',compress_level=1)
