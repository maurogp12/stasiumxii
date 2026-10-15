import sys; sys.path.insert(0,'/workspace/foe_walks/coilspire_v2/attack_v1')
from stills import *
os.chdir('/workspace/foe_walks/coilspire_v2/spell_v1')
AD='/cursor/stores/store-c01dd204-c037-4a89-b6fe-7a06d7c1b2f9/grok-bot/agents/10888a55-2177-4c78-97bf-f62165f60d9b/attachments/'
def plate(h,box=None):
    a=np.asarray(Image.open(AD+h+'.jpg').convert('RGB')).astype(np.float32)
    a=np.clip((a-8)/(247),0,1)                    # luminance key: kill jpeg black noise
    if box: a=a[box[1]:box[3],box[0]:box[2]]
    m=a.max(-1)>0.04; ys,xs=np.nonzero(m); return a[ys.min():ys.max()+1,xs.min():xs.max()+1]
CHG=plate('6be7e30864b1a583c6197d45cc85919d7254bb7a3b6a6650d6c4c40f20dd88e9')
WEB=plate('379e36c8a7dc29c518c15c37529e6666555b25795c81106f04fa333b016b185f')
SN=[plate('79c94e7c4b151fa33f0bad38c7f125604ccbda0b9f20edc60004db44c59bb898',b) for b in ((0,0,640,720),(640,0,1280,720))]
BST=plate('e0fd94d1128a11e1fbab117d22ee2c253ee071f97f5c9d0d67bc2ea50040f09c')
def screen(g,p,c,w,h,k=1.0):   # screen-blend plate p (float rgb) centred at c, size w x h
    P=cv2.resize(p,(max(2,int(w)),max(2,int(h))),interpolation=cv2.INTER_AREA)*k
    G=np.asarray(g).astype(np.float32)/255; x0=int(c[0]-w/2); y0=int(c[1]-h/2)
    xa,ya=max(0,x0),max(0,y0); xb,yb=min(G.shape[1],x0+P.shape[1]),min(G.shape[0],y0+P.shape[0])
    if xb<=xa or yb<=ya: return g
    sub=P[ya-y0:yb-y0,xa-x0:xb-x0]; G[ya:yb,xa:xb,:3]=1-(1-G[ya:yb,xa:xb,:3])*(1-sub)
    return Image.fromarray((G*255).astype(np.uint8))
# phases: rear, lift, lunge, charge, fx
SK=[('1 WIND-UP',7,170,-15,0.8,dict(chg=1.0)),('2 CAST - WEB SPREADS',-7,0,25,1.0,dict(web=0.55)),
    ('3 IMPACT - SNARE',-6,0,25,0.9,dict(web=1.0,sn=1.0,hit=1)),('4 RELEASE - BURST',0,0,0,0.0,dict(web=0.3,bst=1.0))]
def sc(dn,kp,crop=True,label=True):
    name,rear,lift,lunge,charge,fx=kp; side,mir=MAP[dn]; R=RIG[side]
    g=FL.copy(); dv=np.array(DV[dn],float); dv/=np.linalg.norm(dv)
    C=np.array([480,352]); bp=C+dv*-75; tp=C+dv*175
    Tg={'ij':tp+np.array([-55,-6]),'ke':tp+np.array([55,6])}
    im,tip,orbs=pose(side,rear,lift,lunge,charge)
    if mir: im=im.transpose(Image.FLIP_LEFT_RIGHT); tip=(R['W']+2*PAD-tip[0],tip[1]); orbs=[(R['W']+2*PAD-o[0],o[1]) for o in orbs]
    im=im.resize((round(im.width*K),round(im.height*K)),Image.LANCZOS); ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K
    S=lambda p:(ox+p[0]*K,oy+p[1]*K)
    sh=Image.new('RGBA',g.size); sw=R['W']*K*0.62; sx=bp[0]+dv[0]*lunge*K*0.5
    ImageDraw.Draw(sh).ellipse([sx-sw/2,bp[1]-4-sw*.13,sx+sw/2,bp[1]-4+sw*.13],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    if 'web' in fx:   # floor web: from the feet to past both targets, flattened to the iso floor
        wc=bp*0.38+tp*0.62; s=fx['web']; wd=(np.linalg.norm(tp-bp)+230)*(0.55+0.45*s)
        g=screen(g,WEB,wc,wd,wd*0.5,0.9*fx.get('webk',1.0))
    items=[(bp[1],im,(round(ox),round(oy)))]
    for c,p in Tg.items():
        v=CH_[c]; hit='hit' in fx; fs=SP[(c,'hit' if hit else 'idle',TF[dn])]; hm=fs[1] if hit else fs[0]
        if hit: hm=tint(hm,0.1)
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
    for _,i_,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(i_,xy)
    if 'chg' in fx:
        ck=fx['chg']; st=S(tip); g=screen(g,CHG,st,30+60*ck,30+60*ck,min(1,0.3+ck))
        for o in orbs[:1]: g=screen(g,CHG,S(o),40+70*ck,40+70*ck,0.9*min(1,0.3+ck))
        if not orbs: g=screen(g,CHG,((st[0]+bp[0])/2,(st[1]+bp[1]-80)/2),40+60*ck,40+60*ck,0.7*min(1,0.3+ck))   # back view: charge along the spine
    if 'sn' in fx:
        r_=max(0.05,fx['sn'])
        for c,p in Tg.items():
            P_=SN[0 if c=='ij' else 1]; hh=int(P_.shape[0]*r_); P_=P_[P_.shape[0]-hh:]   # pillar rises from the floor
            H_=150*r_; g=screen(g,P_,(p[0],p[1]+13-H_/2),74,H_,fx.get('snk',1.0))
    if 'bst' in fx:
        m=np.mean(list(Tg.values()),0); g=screen(g,BST if dv[0]<0 else BST[:,::-1],(m[0],m[1]-55),300*fx.get('bsz',1.0),170*fx.get('bsz',1.0),fx['bst'])
    if crop:
        bb=im.getbbox(); xs_=[ox+bb[0],ox+bb[2]]+[p[0]+v for p in Tg.values() for v in (-62,62)]; cx=int(np.clip((max(xs_)+min(xs_))/2,240,720)); g=g.crop((cx-240,0,cx+240,540))
    if not label: return g
    d=ImageDraw.Draw(g); d.text((14,10),f'{dn.upper()}  {name}',font=fnt2,fill=(220,235,255,255),stroke_width=3,stroke_fill=(0,0,0,255)); return g
if __name__=='__main__':
    Sh=Image.new('RGB',(1920,1080))
    for r,dn in enumerate('we'):
        for c,kp in enumerate(SK): Sh.paste(sc(dn,kp).convert('RGB'),(c*480,r*540))
    Sh.save('coilspire14_spell_stills_WE.png')
    for i,(nm,kp) in enumerate((('spread',SK[1]),('snare',SK[2]),('burst',SK[3]))):
        sc('w',kp,False).convert('RGB').save(f'fx_{i+1}_{nm}_W.png')
    print('ok')
