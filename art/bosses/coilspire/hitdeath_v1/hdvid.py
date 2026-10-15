import sys,io,contextlib
with contextlib.redirect_stdout(io.StringIO()):
    src=open('sheet_hd.py').read(); exec(src[:src.index('Sh=Image.new')])
NF=122
ez=lambda x:float(np.clip(x,0,1))**2*(3-2*float(np.clip(x,0,1)))
def lerp(f,keys):
    for (a,pa),(b,pb) in zip(keys[:-1],keys[1:]):
        if a<=f<=b: e=ez((f-a)/(b-a)) if b>a else 1; return tuple(x+(y-x)*e for x,y in zip(pa,pb))
    return keys[-1][1]
PK=[(0,(0,0,0,0)),(12,(0,0,0,0)),(14,(4,25,-16,0.3)),(22,(0,0,0,0)),(34,(0,0,0,0)),(58,(0,0,0,1.0))]
def vcell(dn,f):
    g=FL.copy(); dv=np.array(DV[dn],float); dv/=np.linalg.norm(dv)
    C=np.array([480,352]); bp=C+dv*-75; tp=C+dv*175
    Tg={'ij':tp+np.array([-55,-6]),'ke':tp+np.array([55,6])}
    im,tip,orbs,R=body_img(dn,*lerp(min(f,58),PK))
    im=im.resize((round(im.width*K),round(im.height*K)),Image.LANCZOS); ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K
    S=lambda p:(ox+p[0]*K,oy+p[1]*K); cen=(bp[0],bp[1]-120); st=S(tip)
    if 12<=f<22: im=tint(im,(0.05 if dv[0]<0 else 0.03)*(1-ez((f-14)/8)))
    ov=ez((f-34)/24) if f>=34 else 0
    if ov>0: im=tint(im,0.25*ov)
    dis=ez((f-58)/16) if f>=58 else 0
    if dis>0:
        a=np.array(im); n=nd.gaussian_filter(np.random.default_rng(5).random(a.shape[:2]),3); a[n<np.quantile(n,min(0.999,dis)),3]=0; im=Image.fromarray(a)
    ra=ez((f-62)/20) if f>=62 else 0
    rm=REM if dv[0]<0 else REM.transpose(Image.FLIP_LEFT_RIGHT); rm=rm.resize((int(rm.width*0.32),int(rm.height*0.32)),Image.LANCZOS); rxy=(int(bp[0]-rm.width/2),int(bp[1]+10-rm.height))
    if ra<1: ar=np.array(rm); ar[...,3]=(ar[...,3]*ra).astype(np.uint8); rmi=Image.fromarray(ar)
    else: rmi=rm
    sh=Image.new('RGBA',g.size); sw=R['W']*K*(0.62*(1-ra)+0.55*ra); ImageDraw.Draw(sh).ellipse([bp[0]-sw/2,bp[1]-4-sw*.13,bp[0]+sw/2,bp[1]-4+sw*.13],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    items=[]
    if dis<1: items.append((bp[1],im,(round(ox),round(oy))))
    if ra>0: items.append((bp[1]-1,rmi,rxy))
    for c,p in Tg.items():
        v=CH_[c]; fs=SP[(c,'idle',TF[dn])]; hm=fs[(f//4)%len(fs)]
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
    for _,i_,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(i_,xy)
    fl=0.85+0.3*np.random.default_rng(f).random()
    if ov>0 and dis<1:
        k=ov*(1-dis); g=screen(g,CHG,st,40+70*ov,40+70*ov,k*fl); g=screen(g,CHG,cen,60+110*ov,60+110*ov,0.8*k*fl)
        for o in orbs[:1]: g=screen(g,CHG,S(o),50+70*ov,50+70*ov,k*fl)
    if f>=58:
        b=ez((f-58)/4)*(1-ez((f-70)/16)); sz=0.8+0.4*ez((f-58)/28)
        if b>0.01: g=screen(g,BST,cen,330*sz,200*sz,0.85*b); g=screen(g,BST[:,::-1],(cen[0],cen[1]-30),280*sz,180*sz,0.6*b); g=screen(g,CHG,cen,200*sz,200*sz,0.9*b)
    if ra>0.3:   # faint flickering sparks: spine break + eyes
        fx_=0.62 if dv[0]<0 else 0.38; r2=np.random.default_rng(f*3+1)
        g=screen(g,CHG,(rxy[0]+rm.width*fx_,rxy[1]+rm.height*0.5),30+12*r2.random(),30+12*r2.random(),(0.2+0.35*r2.random())*ra)
        g=screen(g,CHG,(rxy[0]+rm.width*0.5,rxy[1]+rm.height*0.24),26,18,(0.25+0.15*np.sin(f*0.5))*ra)
    d=ImageDraw.Draw(g); d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
    cc=np.array([150,48]); nn=np.array([-dv[1],dv[0]]); a_=cc-dv*40; b_=cc+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
    d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+nn*14),tuple(b_-dv*6-nn*14)],fill=(140,200,255,255))
    return g
def frame(n):
    G=Image.new('RGBA',(1920,1080))
    for q,dn in enumerate('nesw'): G.alpha_composite(vcell(dn,n),((q%2)*960,(q//2)*540))
    return G.convert('RGB')
if __name__=='__main__':
    os.makedirs('_f',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a,b): frame(i).save(f'_f/{i:05d}.png',compress_level=1)
