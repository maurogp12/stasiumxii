import sys; sys.path.insert(0,'/workspace/foe_walks/coilspire5_v1/spell_v1')
import io,contextlib
from storm import *
LOOP=84
ez=lambda x:float(np.clip(x,0,1))**2*(3-2*float(np.clip(x,0,1)))
def lerp(f,keys):
    for (a,pa),(b,pb) in zip(keys[:-1],keys[1:]):
        if a<=f<=b: e=ez((f-a)/(b-a)) if b>a else 1; return [x+(y-x)*e for x,y in zip(pa,pb)]
    return list(keys[-1][1])
PK=[(0,(0,0,0,0)),(4,(0,0,0,0)),(18,(-22,6,-8,1.0)),(26,(-10,0,4,1.0)),(34,(-4,0,0,0.4)),(62,(-4,0,0,0.3)),(74,(0,0,0,0.5)),(84,(0,0,0,0))]
def lay2(dn):
    L=lay(dn); dv=L['dv']; perp=np.array([-dv[1],dv[0]])
    L['stop']=[L['ij']-dv*82+perp*-42,L['ij']-dv*82+perp*42,L['ke']-dv*58+perp*-36,L['ke']-dv*58+perp*36]   # stop short of the heroes' feet
    return L
LAY={dn:lay2(dn) for dn in 'nesw'}
def vcell(dn,f,L):
    tail,pinc,lunge,charge=lerp(f,PK); dv=L['dv']; bp=L['bp']
    im,rel,R=boss(dn,('',tail,pinc,lunge,charge,''))
    g=BIGF.crop((520,430,1480,970)); ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K; so=bp+rel; H_=82
    sh=Image.new('RGBA',g.size); sw=R['W']*K*0.62; ImageDraw.Draw(sh).ellipse([bp[0]-sw/2,bp[1]-4-sw*.13,bp[0]+sw/2,bp[1]-4+sw*.13],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    flips=[(dv[0]>0) if j!=1 else not (dv[0]>0) for j in range(4)]
    # scorpling positions
    sp=[]
    if 18<=f<26:
        q=(f-18)/8
        for j,p in enumerate(L['land']):
            pos=np.array(so)+(p-np.array(so))*q; pos[1]-=60*np.sin(np.pi*q)*(1-q*0.3); sp.append((pos,H_*(0.35+0.65*q),flips[j],0.0))
    elif 26<=f<48:
        q=ez((f-28)/18)
        for j,(a,b) in enumerate(zip(L['land'],L['stop'])):
            pos=a+(b-a)*q; bob=2.5*abs(np.sin((f+j*2)*1.6)) if f<46 else 0; pos=pos+np.array([0,-bob]); sp.append((pos,H_,flips[j],q))
    if 30<=f<48:   # faint arc trails on the floor
        for (pos,h,fl,q),a in zip(sp,L['land']): g=streak(g,a+(pos-a)*0.35,pos,7,0.35*(1-max(0,(f-44)/4)))
    # draw: boss, heroes, scorplings y-sorted
    hit=48<=f<58
    items=[(bp[1],im,(round(ox),round(oy)),None)]
    for c,p in (('ij',L['ij']),('ke',L['ke'])):
        v=CH_[c]; fs=SP[(c,'hit' if hit else 'idle',S1.TF[dn])]; hm=fs[min(len(fs)-1,(f-48)//2)] if hit else fs[(f//4)%len(fs)]
        if hit: hm=tint(hm,0.1)
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k'])),None))
    for pos,h,fl,q in sp:
        if f>=26: s3=Image.new('RGBA',g.size); ImageDraw.Draw(s3).ellipse([pos[0]-16,pos[1]-4,pos[0]+16,pos[1]+4],fill=(0,0,0,80)); g.alpha_composite(s3.filter(ImageFilter.GaussianBlur(2)))
        items.append((pos[1],None,None,(pos,h,fl)))
    for y_,im_,xy,scp in sorted(items,key=lambda s:s[0]):
        if scp is None: g.alpha_composite(im_,xy)
        else: g=scorp(g,scp[0],scp[1],scp[2],1.0)
    if 4<=f<18: k=ez((f-4)/14); g=screen(g,CHG,so,40+110*k,40+110*k,k)
    if 18<=f<24: k=1-ez((f-20)/4); g=screen(g,CHG,so,170,170,k)
    for pos,h,fl,q in sp:
        if 18<=f<26: g=streak(g,so,(pos[0],pos[1]-h*0.4),9,0.45)
    if 48<=f<60:
        b=ez((f-48)/2)*(1-ez((f-52)/8)); pts=L['stop']
        for a,c2 in zip(pts,pts[1:]+pts[:1]): 
            if f<56: g=streak(g,a-np.array([0,40]),c2-np.array([0,45]),12,0.8*(1-ez((f-52)/4)))
        for j,p in enumerate(pts): g=screen(g,BST if j%2 else BST[:,::-1],(p[0],p[1]-40),160*(0.8+0.3*(f-48)/12),105*(0.8+0.3*(f-48)/12),0.95*b); g=screen(g,CHG,(p[0],p[1]-35),40,40,0.7*b)
    if 62<=f<80: k=np.sin(np.pi*(f-62)/18); g=screen(g,CHG,so,30+40*k,30+40*k,0.8*k)
    d=ImageDraw.Draw(g); d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
    cc=np.array([150,48]); nn=np.array([-dv[1],dv[0]]); a_=cc-dv*40; b_=cc+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
    d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+nn*14),tuple(b_-dv*6-nn*14)],fill=(140,200,255,255))
    return g
fnt=S1.ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',56) if hasattr(S1,'ImageFont') else fnt2
def frame(n):
    G=Image.new('RGBA',(1920,1080))
    for q,dn in enumerate('nesw'): G.alpha_composite(vcell(dn,n%LOOP,LAY[dn]),((q%2)*960,(q//2)*540))
    return G.convert('RGB')
if __name__=='__main__':
    os.makedirs('_f',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a,b): frame(i).save(f'_f/{i:05d}.png',compress_level=1)
