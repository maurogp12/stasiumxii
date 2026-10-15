import sys; sys.path.insert(0,'/workspace/foe_walks/coilspire5_v1/spell_v1')
from storm import *
os.chdir('/workspace/foe_walks/coilspire5_v1/hitdeath_v1')
REM=Image.open('/workspace/foe_walks/coilspire5_v1/hitdeath_v1/remains5_matte.png').convert('RGBA')
KA={Kk:S1.cells(f'/workspace/art/kestrel_full/v3/attack/kestrel_attack_{Kk}_strip.png',116,0.95) for Kk in 'NESW'}
# name, tail, pinc, lunge, charge
KP=[('1 IDLE',0,0,0,0),('2 HIT',-8,-6,-6,0),('3 OVERLOAD',-14,4,0,1.0),('4 BURST',-14,4,0,1.0),('5 REMAINS',0,0,0,0)]
def cell(dn,i,L):
    name,tail,pinc,lunge,charge=KP[i]; dv=L['dv']; bp=L['bp']
    im,rel,R=boss(dn,(name,tail,pinc,lunge,charge,''))
    if i==1: im=tint(im,0.16)
    g=BIGF.crop((520,430,1480,970)); ox=bp[0]-(R['W']/2+PAD)*K; oy=bp[1]-(R['gy']+PAD)*K; so=bp+rel
    if i==1: ox-=dv[0]*5; oy-=dv[1]*5          # flinch: small recoil away from the heroes (no fall)
    sh=Image.new('RGBA',g.size); sw=R['W']*K*0.62; ImageDraw.Draw(sh).ellipse([bp[0]-sw/2,bp[1]-4-sw*.13,bp[0]+sw/2,bp[1]-4+sw*.13],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    items=[] if i>=3 else [(bp[1],im,(round(ox),round(oy)))]
    if i==3:   # boss gone in the flash; a faint ghost of the body inside the burst
        a=np.array(im); a[...,3]=(a[...,3]*0.35).astype(np.uint8); items=[(bp[1],Image.fromarray(a),(round(ox),round(oy)))]
    for c,p in (('ij',L['ij']),('ke',L['ke'])):
        v=CH_[c]
        if c=='ke' and i==1: fs=KA[S1.TF[dn]]; hm=fs[min(3,len(fs)-1)]
        else: fs=SP[(c,'idle',S1.TF[dn])]; hm=fs[0]
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
    if i==4:   # painted husk, scaled to the boss footprint, mirrored for E-side keys
        bb=im.getbbox(); bw=(bb[2]-bb[0])*0.95; rp=REM.transpose(Image.FLIP_LEFT_RIGHT) if dn in 'es' else REM
        rh=bw*rp.height/rp.width; rp=rp.resize((int(bw),int(rh)),Image.LANCZOS)
        items.append((bp[1],rp,(round(bp[0]-bw/2),round(bp[1]+8-rh))))
    for _,i_,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(i_,xy)
    body=np.array([bp[0],bp[1]-60])
    if i==1:   # Kestrel's arrow: pale streak with a head, ending in the impact spark
        hitp=np.array([body[0]+dv[0]*40,body[1]+dv[1]*40-10]); P0=L['ke']+np.array([0,-72]); u=(hitp-P0)/np.linalg.norm(hitp-P0)
        tail_=hitp-u*150; ln=Image.new('L',g.size); dr=ImageDraw.Draw(ln)
        for k_,wd in ((0,6),(0.35,4),(0.7,3)): dr.line([tuple(tail_+u*150*k_),tuple(hitp-u*6)],fill=int(90+150*k_),width=wd)
        nn=np.array([-u[1],u[0]]); dr.polygon([tuple(hitp),tuple(hitp-u*14+nn*6),tuple(hitp-u*14-nn*6)],fill=255)
        c_=Image.new('RGBA',g.size,(240,232,205,0)); c_.putalpha(ln.filter(ImageFilter.GaussianBlur(0.8))); g.alpha_composite(c_)
        g=screen(g,CHG,tuple(hitp),70,70,0.85)
    if i==2:   # orb overloads, lightning crawls over the carapace
        g=screen(g,CHG,so,190,190,1.0)
        for k_ in (-1,1): g=streak(g,so,body+np.array([k_*70,30]),9,0.8)
        g=streak(g,so,body,12,0.9)
    if i==3:
        g=screen(g,BST,(body[0],body[1]-10),420,280,1.0); g=screen(g,BST[:,::-1],(body[0],body[1]-30),300,200,0.8); g=screen(g,CHG,(so[0],so[1]),240,240,1.0)
    return g
if __name__=='__main__':
    CWc=384; Sh=Image.new('RGB',(1920,1080))
    for r,dn in enumerate('we'):
        L=lay(dn); xs_=[];ys_=[]
        im,rel,R=boss(dn,KP[0][:5]+('',)); bb=im.getbbox(); ox=L['bp'][0]-(R['W']/2+PAD)*K; oy=L['bp'][1]-(R['gy']+PAD)*K; xs_+=[ox+bb[0]-60,ox+bb[2]+60]; ys_+=[oy+bb[1]-90,oy+bb[3]]
        for p in (L['ij'],L['ke']): xs_+=[p[0]-70,p[0]+70]; ys_+=[p[1]-150,p[1]+20]
        w_=max(max(xs_)-min(xs_)+30,(max(ys_)-min(ys_)+60)*CWc/540); h_=w_*540/CWc; cx=(max(xs_)+min(xs_))/2; cy=(max(ys_)+min(ys_))/2+10
        for i in range(5):
            big=BIGF.copy(); big.alpha_composite(cell(dn,i,L),(520,430))
            g=big.crop((int(cx-w_/2+520),int(cy-h_/2+430),int(cx+w_/2+520),int(cy+h_/2+430))).resize((CWc,540),Image.LANCZOS)
            d=ImageDraw.Draw(g); d.text((10,10),f'{dn.upper()} {KP[i][0]}',font=fnt2,fill=(220,235,255,255),stroke_width=3,stroke_fill=(0,0,0,255)); Sh.paste(g.convert('RGB'),(i*CWc,r*540))
    Sh.save('coilspire5_hitdeath_stills_WE.png')
