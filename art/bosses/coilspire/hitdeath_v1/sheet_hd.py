exec(open('remains.py').read())
REM=Image.open('remains_plate.png'); REM=REM.crop(REM.getbbox())
_m=Image.fromarray(((np.array(REM)[...,3]>0)*255).astype(np.uint8)); _pad=Image.new('L',(REM.width+60,REM.height+60)); _pad.paste(_m,(30,30))
_g=Image.new('RGBA',_pad.size,(140,70,230,0)); _g.putalpha(_pad.filter(ImageFilter.GaussianBlur(12)).point(lambda v:int(v*0.35)))
_g.alpha_composite(REM,(30,30)); REM=_g   # soft violet glow behind the heap
def body_img(dn,rear,lift,lunge,charge):
    side,mir=MAP[dn]; R=RIG[side]; im,tip,orbs=pose(side,rear,lift,lunge,charge)
    if mir: im=im.transpose(Image.FLIP_LEFT_RIGHT); tip=(R['W']+2*PAD-tip[0],tip[1]); orbs=[(R['W']+2*PAD-o[0],o[1]) for o in orbs]
    return im,tip,orbs,R
def cell(dn,name,mode):
    g=FL.copy(); dv=np.array(DV[dn],float); dv/=np.linalg.norm(dv)
    C=np.array([480,352]); bp=C+dv*-75; tp=C+dv*175
    Tg={'ij':tp+np.array([-55,-6]),'ke':tp+np.array([55,6])}
    P=dict(hit=(4,25,-16,0.3),over=(0,0,0,1.0),burst=(0,0,0,1.0),rem=(0,0,0,0))[mode]
    im,tip,orbs,R=body_img(dn,*P)
    im=im.resize((round(im.width*K),round(im.height*K)),Image.LANCZOS); ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K
    S=lambda p:(ox+p[0]*K,oy+p[1]*K); cen=(bp[0],bp[1]-120)
    if mode=='hit': im=tint(im,0.05 if dv[0]<0 else 0.03)
    if mode=='over': im=tint(im,0.25)
    if mode=='burst':   # dissolve: noise mask eats the body
        a=np.array(im); n=nd.gaussian_filter(np.random.default_rng(5).random(a.shape[:2]),3); a[n<np.quantile(n,0.7),3]=0; im=tint(Image.fromarray(a),0.4)
    rem=None
    if mode in('burst','rem'):
        rm=REM if dv[0]<0 else REM.transpose(Image.FLIP_LEFT_RIGHT); rm=rm.resize((int(rm.width*0.32),int(rm.height*0.32)),Image.LANCZOS)
        if mode=='burst': ar=np.array(rm); ar[...,3]=(ar[...,3]*0.55).astype(np.uint8); rm=Image.fromarray(ar)
        rem=(rm,(int(bp[0]-rm.width/2),int(bp[1]+10-rm.height)))
    sh=Image.new('RGBA',g.size); sw=R['W']*K*(0.62 if mode!='rem' else 0.55); ImageDraw.Draw(sh).ellipse([bp[0]-sw/2,bp[1]-4-sw*.13,bp[0]+sw/2,bp[1]-4+sw*.13],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    items=[]
    if mode!='rem': items.append((bp[1],im,(round(ox),round(oy))))
    if rem: items.append((bp[1]-1,)+rem)
    for c,p in Tg.items():
        v=CH_[c]; fs=SP[(c,'idle',TF[dn])]; hm=fs[0]
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
    for _,i_,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(i_,xy)
    st=S(tip)
    pass
    if mode=='over':
        g=screen(g,CHG,st,110,110,1.0); g=screen(g,CHG,cen,170,170,0.8)
        for o in orbs[:1]: g=screen(g,CHG,S(o),120,120,1.0)
    if mode=='burst':
        g=screen(g,BST,cen,330,200,0.85); g=screen(g,BST[:,::-1],(cen[0],cen[1]-30),280,180,0.6); g=screen(g,CHG,cen,200,200,0.9)
    if mode=='rem':   # faint sparks at the cracked spine + skull eyes
        rm,xy=rem; g=screen(g,CHG,(xy[0]+rm.width*(0.75 if dv[0]<0 else 0.25),xy[1]+rm.height*0.4),46,46,0.45); g=screen(g,CHG,(bp[0],xy[1]+rm.height*0.5),40,40,0.3)
    bb=(im.getbbox()); xs_=[ox+bb[0],ox+bb[2]]+[p[0]+v for p in Tg.values() for v in (-62,62)]; cx=int(np.clip((max(xs_)+min(xs_))/2,240,720))
    g=g.crop((cx-240,0,cx+240,540)); d=ImageDraw.Draw(g); d.text((14,10),f'{dn.upper()}  {name}',font=fnt2,fill=(220,235,255,255),stroke_width=3,stroke_fill=(0,0,0,255)); return g
Sh=Image.new('RGB',(1920,1080))
for r,dn in enumerate('we'):
    for c,(nm,md) in enumerate((('HIT flinch','hit'),('DEATH overload','over'),('DEATH burst','burst'),('REMAINS','rem'))): Sh.paste(cell(dn,nm,md).convert('RGB'),(c*480,r*540))
Sh.save('coilspire14_hitdeath_stills_WE.png'); print('ok')
