import sys,os; sys.path.insert(0,'/workspace/foe_walks/coilspire5_v1/attack_v1')
from stills5 import *
os.chdir('/workspace/foe_walks/coilspire5_v1/attack_v2')
# tail, pincer, lunge(raw px, feet planted), charge, phase
KP=[('1 WIND-UP',-24,35,-10,0.7,'wind'),('2 STING',40,-12,30,1.0,'sting'),('3 IMPACT',38,-10,28,0.8,'impact'),('4 RECOVER',-6,8,0,0.2,'rest')]
def pose6(side,tail,pinc,lunge,charge,legoff=None):
    R=A5.RIG[side]; G=GEO[side]; a0=R['a']; tm=(R['tw']>0)|((R['yy']<G['base'][1])&(R['tw']>0))
    tm=nd.binary_dilation(R['tw']>0,iterations=1)&(R['yy']<G['base'][1])
    body=a0.copy(); body[tm]=0; tl=np.zeros_like(a0); tl[tm]=a0[tm]
    R['a']=body
    try: im,_=pose5(side,0,pinc,lunge,charge,legoff)
    finally: R['a']=a0
    u=A5.u_of(side); shx,shy=u[0]*lunge,u[1]*lunge*0.5-abs(lunge)*0.15
    tl=cv2.copyMakeBorder(tl,PAD,PAD,PAD,PAD,cv2.BORDER_CONSTANT,value=(0,0,0,0)); b=(G['base'][0]+PAD,G['base'][1]+PAD)
    ang=tail*G['f']; M=cv2.getRotationMatrix2D(b,-ang,1.0); M[0,2]+=shx; M[1,2]+=shy   # rigid tail swing about its root
    t2=cv2.warpAffine(tl,M,(tl.shape[1],tl.shape[0]),flags=cv2.INTER_LINEAR,borderValue=(0,0,0,0))
    c=t2[...,:3].astype(np.float32); pmk=((c[...,2]-c[...,1])>35); c[pmk]=np.clip(c[pmk]*(1+0.6*charge),0,255); t2[...,:3]=c.astype(np.uint8)
    t2[t2[...,3]<128]=0; t2[t2[...,3]>0,3]=255
    o=np.array(im); m2=t2[...,3]>0; o[m2]=t2[m2]
    ob=np.array(G['orb'],float)+PAD; orb=M@np.array([ob[0],ob[1],1.])
    return Image.fromarray(o),orb
import scipy.ndimage as nd
def boss(dn,kp,legoff=None):
    name,tail,pinc,lunge,charge,ph=kp; side,mir=A5.MAP[dn]; R=A5.RIG[side]
    im,orb=pose6(side,tail,pinc,lunge,charge,legoff)
    if mir: im=im.transpose(Image.FLIP_LEFT_RIGHT); orb=(im.width-orb[0],orb[1])
    _a=np.array(im); _m=_a[...,3]>0; _lb,_n=nd.label(_m,np.ones((3,3))); _s=nd.sum(_m,_lb,range(1,_n+1)); _a[np.isin(_lb,[i+1 for i,v in enumerate(_s) if v<20])]=0; im=Image.fromarray(_a)  # no detached pincer flecks
    im=im.resize((round(im.width*K),round(im.height*K)),Image.LANCZOS)
    rel=np.array([(orb[0]-(R['W']/2+PAD))*K,(orb[1]-(R['gy']+PAD))*K])   # orb relative to ground anchor
    return im,rel,R
def scene(dn,kp,bp=None):
    name,tail,pinc,lunge,charge,ph=kp; dv=np.array(A5.DV[dn],float); dv/=np.linalg.norm(dv)
    C=np.array([480,352]); tp=C+dv*120
    Tg={'ij':tp+np.array([-55,-6]) if dv[0]>0 else tp+np.array([-55,-6]),'ke':tp+np.array([55,6])}
    ij=Tg['ij'] if True else None
    hit_pt=np.array([ij[0],ij[1]-70])
    if bp is None:   # melee placement: strike-pose stinger lands on Ironjaw's upper body
        _,rel,_=boss(dn,KP[1]); bp=hit_pt-rel
    im,rel,R=boss(dn,kp); g=FL.copy(); ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K; so=bp+rel
    sh=Image.new('RGBA',g.size); sw=R['W']*K*0.62; ImageDraw.Draw(sh).ellipse([bp[0]-sw/2,bp[1]-4-sw*.13,bp[0]+sw/2,bp[1]-4+sw*.13],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    items=[(bp[1],im,(round(ox),round(oy)))]
    for c,p in Tg.items():
        v=CH_[c]; hit=(ph=='impact' and c=='ij'); fs=SP[(c,'hit' if hit else 'idle',S1.TF[dn])]; hm=fs[1] if hit else fs[0]
        if hit: hm=tint(hm,0.1)
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1]+(1000 if ph in('sting','impact') and c=='ij' and False else 0),hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
    for _,i_,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(i_,xy)
    if ph=='wind': g=screen(g,CHG,so,70,70,0.7)
    if ph=='sting': g=screen(g,CHG,so,60,60,0.9)
    if ph=='impact': g=screen(g,BST if dv[0]<0 else BST[:,::-1],so,110,70,0.85); g=screen(g,CHG,so,50,50,0.8)
    if ph=='rest': g=screen(g,CHG,so,34,34,0.3)
    return g,bp
if __name__=='__main__':
    Sh=Image.new('RGB',(1920,1080))
    for r,dn in enumerate('we'):
        _,bp=scene(dn,KP[0]); cells=[scene(dn,kp,bp)[0] for kp in KP]
        dv=np.array(A5.DV[dn],float); dv/=np.linalg.norm(dv); tp=np.array([480,352])+dv*120
        cx=int(np.clip((bp[0]+tp[0])/2,240,720))     # ONE fixed framing per row
        for c,(g,kp) in enumerate(zip(cells,KP)):
            g=g.crop((cx-240,0,cx+240,540)); d=ImageDraw.Draw(g); d.text((14,10),f'{dn.upper()}  {kp[0]}',font=fnt2,fill=(220,235,255,255),stroke_width=3,stroke_fill=(0,0,0,255))
            Sh.paste(g.convert('RGB'),(c*480,r*540))
        print(dn,'boss ground',bp.round(1))
    Sh.save('coilspire5_attack_sting_stills_WE.png'); Sh.save('/tmp/c5_sting_a1.png')
