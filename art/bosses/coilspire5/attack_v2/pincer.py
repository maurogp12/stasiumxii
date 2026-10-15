import sys,os; sys.path.insert(0,'/workspace/foe_walks/coilspire5_v1/attack_v2')
from sting import *
# tail, pincer, lunge, charge, phase, at(0=rest spot,1=melee spot)
KP=[('1 WIND-UP',-24,35,-14,0.7,'wind',0),('2 LUNGE + SNAP',22,-15,0,1.0,'snap',1),('3 IMPACT',20,-12,0,0.8,'impact',1),('4 RECOVER',-4,6,0,0.2,'rest',0)]
def streak(g,p0,p1,wd,k):
    v=np.array(p1)-np.array(p0); L=np.linalg.norm(v); ang=np.degrees(np.arctan2(v[1],v[0]))
    bm=cv2.resize(CHG,(int(L+20),int(wd)),interpolation=cv2.INTER_AREA)
    M=cv2.getRotationMatrix2D((bm.shape[1]/2,bm.shape[0]/2),-ang,1.0); c=(np.array(p0)+np.array(p1))/2; M[0,2]+=c[0]-bm.shape[1]/2; M[1,2]+=c[1]-bm.shape[0]/2
    cv_=cv2.warpAffine(bm,M,(g.width,g.height)); G_=np.asarray(g).astype(np.float32)/255
    G_[...,:3]=1-(1-G_[...,:3])*(1-np.clip(cv_*1.5*k,0,1)); return Image.fromarray((G_*255).astype(np.uint8))
def layout(dn):
    dv=np.array(A5.DV[dn],float); dv/=np.linalg.norm(dv); C=np.array([480,352])
    ij=C+dv*120; ke=ij+np.array([135*np.sign(dv[0]),12])   # Kestrel behind Ironjaw, off to the side
    # melee spot: boss front edge stops ~12px short of Ironjaw's body
    im,rel,R=boss(dn,KP[1][:6]); a=np.array(im)[...,3]>0; ys,xs=np.nonzero(a)
    ox_rel=-(R['W']/2+PAD)*K; front=(xs.max()+ox_rel) if dv[0]>0 else (xs.min()+ox_rel)
    s=( (ij[0]-np.sign(dv[0])*(34+12)) - front )/dv[0]; bp1=dv*s; bp1=ij-dv*(np.dot(ij,dv)-np.dot(bp1,dv))*0+bp1
    bp1=np.array([ij[0]-np.sign(dv[0])*22-front, 0.]); bp1[1]=ij[1]+(bp1[0]-ij[0])*dv[1]/dv[0]   # stay on the travel line
    bp0=bp1-dv*40
    return dict(ij=ij,ke=ke,bp0=bp0,bp1=bp1,dv=dv)
def cell(dn,kp,L):
    name,tail,pinc,lunge,charge,ph,at=kp; dv=L['dv']; bp=L['bp1'] if at else L['bp0']
    im,rel,R=boss(dn,(name,tail,pinc,lunge,charge,ph)); g=BIGF.crop((520,430,1480,970))
    ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K; so=bp+rel
    sh=Image.new('RGBA',g.size); sw=R['W']*K*0.62; ImageDraw.Draw(sh).ellipse([bp[0]-sw/2,bp[1]-4-sw*.13,bp[0]+sw/2,bp[1]-4+sw*.13],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    items=[(bp[1],im,(round(ox),round(oy)))]
    for c,p in (('ij',L['ij']),('ke',L['ke'])):
        v=CH_[c]; hit=(ph=='impact' and c=='ij'); fs=SP[(c,'hit' if hit else 'idle',S1.TF[dn])]; hm=fs[1] if hit else fs[0]
        if hit: hm=tint(hm,0.1)
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
    for _,i_,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(i_,xy)
    contact=np.array([L['ij'][0]-np.sign(dv[0])*30,L['ij'][1]-48]); zap=np.array([L['ij'][0]-np.sign(dv[0])*10,L['ij'][1]-95])
    if ph=='wind': g=screen(g,CHG,so,60,60,0.7)
    if ph=='snap':
        g=screen(g,CHG,so,46,46,0.9); vz=zap-so; p1=so+vz*min(1,95/np.linalg.norm(vz)); g=streak(g,so,p1,26,1.3); g=screen(g,CHG,zap,30,30,0.7)
    if ph=='impact':
        g=screen(g,BST if dv[0]<0 else BST[:,::-1],contact,110,70,0.85); g=screen(g,CHG,contact,40,40,0.7); g=screen(g,CHG,zap,36,36,0.5)
    if ph=='rest': g=screen(g,CHG,so,30,30,0.3)
    return g
BIGF=Image.new('RGBA',(2000,1400),(16,18,24,255)); _d=ImageDraw.Draw(BIGF); TWp,THp=120,60
for i in range(-25,26):
    for j in range(-25,26):
        x=1000+(i-j)*TWp/2; y=742+(i+j)*THp/2
        _d.polygon([(x,y-THp/2),(x+TWp/2,y),(x,y+THp/2),(x-TWp/2,y)],fill=(38,42,54,255) if (i+j)%2 else (30,34,44,255),outline=(48,54,68,255))
if __name__=='__main__':
    Sh=Image.new('RGB',(1920,1080))
    for r,dn in enumerate('we'):
        L=layout(dn); xs_=[];ys_=[]
        for kp in KP:
            im,rel,R=boss(dn,kp[:6]); bp=L['bp1'] if kp[6] else L['bp0']; bb=im.getbbox(); ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K
            xs_+=[ox+bb[0],ox+bb[2]]; ys_+=[oy+bb[1],oy+bb[3]]
        for p in (L['ij'],L['ke']): xs_+=[p[0]-65,p[0]+65]; ys_+=[p[1]-150,p[1]+15]
        w_=max(480,max(xs_)-min(xs_)+30,(max(ys_)-min(ys_)+70)*480/540); h_=w_*540/480; cx=(max(xs_)+min(xs_))/2; cy=(max(ys_)+min(ys_))/2+12
        print(dn,'frame w',round(w_))
        for c,kp in enumerate(KP):
            g=cell(dn,kp,L); big=BIGF.copy(); big.alpha_composite(g,(520,430))
            g=big.crop((int(cx-w_/2+520),int(cy-h_/2+430),int(cx+w_/2+520),int(cy+h_/2+430))).resize((480,540),Image.LANCZOS); d=ImageDraw.Draw(g); d.text((14,10),f'{dn.upper()}  {kp[0]}',font=fnt2,fill=(220,235,255,255),stroke_width=3,stroke_fill=(0,0,0,255))
            Sh.paste(g.convert('RGB'),(c*480,r*540))
    Sh.save('coilspire5_attack_stills_WE.png'); Sh.save('/tmp/c5_pin_a5.png')
