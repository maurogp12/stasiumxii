import sys,os; import scipy.ndimage as nd; sys.path.insert(0,'/workspace/foe_walks/coilspire5_v1/attack_v2')
from pincer import *
os.chdir('/workspace/foe_walks/coilspire5_v1/spell_v1')
sys.path.insert(0,'/workspace/foe_walks/coilspire5_v1'); from cutfn import cut
_src=Image.open('/cursor/stores/store-c01dd204-c037-4a89-b6fe-7a06d7c1b2f9/grok-bot/agents/10888a55-2177-4c78-97bf-f62165f60d9b/attachments/0a447a27b6477f329bc2f741c80775e8da5d4ae0e57d962f93fae29742caa3d4.jpg').convert('RGB')
SCI=cut(_src); _a=np.array(SCI); _c=_a[...,:3].astype(int); _L=_c.mean(-1); _sat=_c.max(-1)-_c.min(-1)
_sd=np.sqrt(np.maximum(nd.uniform_filter(_L*_L.astype(float),5)-nd.uniform_filter(_L.astype(float),5)**2,0))
_a[(_sat<14)&(_sd<5)&(_L>70)]=0; SCI=Image.fromarray(_a); SCI=SCI.crop(SCI.getbbox()); SCI.save('scorpling_matte.png')
def scorp(g,c,h,flip,k=1.0):   # painted scorpling (alpha) + faint violet glow under it
    p=SCI.transpose(Image.FLIP_LEFT_RIGHT) if flip else SCI; w=h*p.width/p.height; p=p.resize((max(2,int(w)),max(2,int(h))),Image.LANCZOS)
    g=screen(g,CHG,(c[0],c[1]-h*0.35),w*1.2,h*1.0,0.6*k)
    g=g.copy(); g.alpha_composite(p,(int(c[0]-w/2),int(c[1]-h))); return g
# name, tail, pinc, lunge, charge
KP=[('1 CAST',-22,6,-8,1.0),('2 SPLIT',-10,0,4,1.0),('3 SWARM',-4,0,0,0.4),('4 CHAIN BLAST',-4,0,0,0.3),('5 REFORM',0,0,0,0.5)]
def lay(dn):
    dv=np.array(A5.DV[dn],float); dv/=np.linalg.norm(dv); C=np.array([480,352]); ij=C+dv*130; ke=ij+np.array([135*np.sign(dv[0]),12]); bp=ij-dv*250
    perp=np.array([-dv[1],dv[0]])
    land=[bp+dv*150+perp*o for o in (-95,-32,32,95)]
    tg=[ij+np.array([-30,4]),ij+np.array([30,-4]),ke+np.array([-28,4]),ke+np.array([26,-2])]
    return dict(dv=dv,ij=ij,ke=ke,bp=bp,land=land,tg=tg)
def cell(dn,i,L):
    name,tail,pinc,lunge,charge=KP[i]; dv=L['dv']; bp=L['bp']
    im,rel,R=boss(dn,(name,tail,pinc,lunge,charge,''))
    g=BIGF.crop((520,430,1480,970)); ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K; so=bp+rel
    sh_=82
    sh=Image.new('RGBA',g.size); sw=R['W']*K*0.62; ImageDraw.Draw(sh).ellipse([bp[0]-sw/2,bp[1]-4-sw*.13,bp[0]+sw/2,bp[1]-4+sw*.13],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    hit=(i==3)
    if i==2:   # trails first (on the floor)
        for a,b in zip(L['land'],L['tg']):
            m=a+(b-a)*0.4; g=streak(g,a,m-(m-a)*0.25,8,0.4)
    items=[(bp[1],im,(round(ox),round(oy)))]
    for c,p in (('ij',L['ij']),('ke',L['ke'])):
        v=CH_[c]; fs=SP[(c,'hit' if hit else 'idle',S1.TF[dn])]; hm=fs[1] if hit else fs[0]
        if hit: hm=tint(hm,0.1)
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
    for _,i_,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(i_,xy)
    flips=[dv[0]>0, dv[0]<0, dv[0]>0, dv[0]>0]   # face the heroes; one flipped for variety
    flips=[f_ if j!=1 else (not f_) for j,f_ in enumerate([dv[0]>0]*4)]
    if i==0: g=screen(g,CHG,so,150,150,1.0); g=screen(g,CHG,so,70,70,0.8)
    if i==1:
        g=screen(g,CHG,so,170,170,1.0)
        for j,(p,f_) in enumerate(zip(L['land'],flips)):
            mid=(np.array(so)+p)/2-np.array([0,40]); g=streak(g,so,mid,10,0.5); g=streak(g,mid,p-np.array([0,sh_*0.5]),10,0.5)
            g=scorp(g,p,sh_*(0.9+0.1*j%2),f_,0.95)
    if i==2:
        for j,(a,b,f_) in enumerate(zip(L['land'],L['tg'],flips)): p=a+(b-a)*0.4; g=scorp(g,p,sh_,f_,0.95)
        g=screen(g,CHG,so,30,30,0.3)
    if i==3:
        pts=L['tg']
        for a,b in zip(pts,pts[1:]+pts[:1]): g=streak(g,a-np.array([0,50]),b-np.array([0,55]),12,0.8)
        for j,p in enumerate(pts): g=screen(g,BST if j%2 else BST[:,::-1],(p[0],p[1]-45),160,105,0.95); g=screen(g,CHG,(p[0],p[1]-40),36,36,0.6)
    if i==4: g=screen(g,CHG,so,60,60,0.8)
    return g
if __name__=='__main__':
    CWc=384; Sh=Image.new('RGB',(1920,1080))
    for r,dn in enumerate('we'):
        L=lay(dn); xs_=[];ys_=[]
        for i in range(5):
            im,rel,R=boss(dn,KP[i][:5]+('',)); bb=im.getbbox(); ox=L['bp'][0]-(R['W']/2+PAD)*K; oy=L['bp'][1]-(R['gy']+PAD)*K; xs_+=[ox+bb[0],ox+bb[2]]; ys_+=[oy+bb[1]-60,oy+bb[3]]
        for p in (L['ij'],L['ke']): xs_+=[p[0]-70,p[0]+70]; ys_+=[p[1]-150,p[1]+20]
        w_=max(max(xs_)-min(xs_)+30,(max(ys_)-min(ys_)+60)*CWc/540); h_=w_*540/CWc; cx=(max(xs_)+min(xs_))/2; cy=(max(ys_)+min(ys_))/2+10
        print(dn,'fixed frame',round(w_),'x',round(h_))
        for i in range(5):
            big=BIGF.copy(); big.alpha_composite(cell(dn,i,L),(520,430))
            g=big.crop((int(cx-w_/2+520),int(cy-h_/2+430),int(cx+w_/2+520),int(cy+h_/2+430))).resize((CWc,540),Image.LANCZOS)
            d=ImageDraw.Draw(g); d.text((10,10),f'{dn.upper()} {KP[i][0]}',font=fnt2,fill=(220,235,255,255),stroke_width=3,stroke_fill=(0,0,0,255)); Sh.paste(g.convert('RGB'),(i*CWc,r*540))
    Sh.save('coilspire5_spell_stills_WE.png'); Sh.save('/tmp/c5_sp_a1.png')
