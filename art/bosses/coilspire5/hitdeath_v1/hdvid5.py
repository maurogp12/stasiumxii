import sys; sys.path.insert(0,'/workspace/foe_walks/coilspire5_v1/hitdeath_v1')
from hd5 import *
ez=lambda x:float(np.clip(x,0,1))**2*(3-2*float(np.clip(x,0,1)))
from PIL import ImageFont
fnt=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',56)
LOOP=120; HITS=(19,47)
def hitk(f):   # 0..1 hit reaction strength
    k=0
    for h in HITS:
        if h<=f<h+8: k=max(k,1-(f-h)/8)
    return k
def vcell(dn,f,L):
    dv=L['dv']; bp=L['bp']; hk=hitk(f)
    ov=ez((f-54)/14) if f<74 else 1.0
    tail=-8*hk-14*ov; pinc=-6*hk+4*ov; lunge=-6*hk; charge=ov
    im,rel,R=boss(dn,('',tail,pinc,lunge,charge,''))
    if hk>0: im=tint(im,0.16*hk)
    g=BIGF.crop((520,430,1480,970)); ox=bp[0]-(R['W']/2+PAD)*K-dv[0]*5*hk; oy=bp[1]-(R['gy']+PAD)*K-dv[1]*5*hk; so=bp+rel
    if 54<=f<74: ox+=np.sin(f*2.3)*1.2*ov; oy+=np.cos(f*3.1)*0.8*ov   # overload tremble
    sh=Image.new('RGBA',g.size); sw=R['W']*K*0.62; ImageDraw.Draw(sh).ellipse([bp[0]-sw/2,bp[1]-4-sw*.13,bp[0]+sw/2,bp[1]-4+sw*.13],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    items=[]
    ba=1.0 if f<74 else max(0.0,1-(f-74)/5)
    if ba>0:
        a=np.array(im); a[...,3]=(a[...,3]*ba).astype(np.uint8); items.append((bp[1],Image.fromarray(a),(round(ox),round(oy))))
    if f>=76:
        ra=ez((f-76)/8); bb=boss(dn,('',0,0,0,0,''))[0].getbbox(); bw=(bb[2]-bb[0])*0.95
        rp=REM.transpose(Image.FLIP_LEFT_RIGHT) if dn in 'es' else REM; rh=bw*rp.height/rp.width; rp=rp.resize((int(bw),int(rh)),Image.LANCZOS)
        if ra<1: a=np.array(rp); a[...,3]=(a[...,3]*ra).astype(np.uint8); rp=Image.fromarray(a)
        items.append((bp[1],rp,(round(bp[0]-bw/2),round(bp[1]+8-rh))))
    for c,p in (('ij',L['ij']),('ke',L['ke'])):
        v=CH_[c]; hm=None
        if c=='ke':
            for h in HITS:
                if h-7<=f<h-1: fs=KA[S1.TF[dn]]; hm=fs[min(len(fs)-1,f-(h-7))]
        if hm is None: fs=SP[(c,'idle',S1.TF[dn])]; hm=fs[(f//4)%len(fs)]
        s2=Image.new('RGBA',g.size); ImageDraw.Draw(s2).ellipse([p[0]-30,p[1]-8,p[0]+30,p[1]+8],fill=(0,0,0,90)); g.alpha_composite(s2.filter(ImageFilter.GaussianBlur(2)))
        items.append((p[1],hm,(round(p[0]-v['piv'][0]*v['k']),round(p[1]-v['piv'][1]*v['k']))))
    for _,i_,xy in sorted(items,key=lambda s:s[0]): g.alpha_composite(i_,xy)
    body=np.array([bp[0],bp[1]-60]); hitp=np.array([body[0]+dv[0]*40,body[1]+dv[1]*40-10])
    for h in HITS:
        if h-3<=f<h:   # arrow in flight: 3 frames
            P0=L['ke']+np.array([0,-72]); u=(hitp-P0)/np.linalg.norm(hitp-P0); D=np.linalg.norm(hitp-P0)
            head=P0+u*D*(f-h+4)/3; tail_=head-u*min(150,np.linalg.norm(head-P0))
            ln=Image.new('L',g.size); dr=ImageDraw.Draw(ln); n_=np.array([-u[1],u[0]])
            for k_,wd in ((0,5),(0.35,4),(0.7,3)): dr.line([tuple(tail_+(head-tail_)*k_),tuple(head-u*6)],fill=int(90+150*k_),width=wd)
            dr.polygon([tuple(head),tuple(head-u*14+n_*6),tuple(head-u*14-n_*6)],fill=255)
            c_=Image.new('RGBA',g.size,(240,232,205,0)); c_.putalpha(ln.filter(ImageFilter.GaussianBlur(0.8))); g.alpha_composite(c_)
        if h<=f<h+5: k=1-(f-h)/5; g=screen(g,CHG,tuple(hitp),50+40*(1-k),50+40*(1-k),0.9*k)
    if 54<=f<76:   # orb overload + lightning crawling over the carapace (flickering painted streaks)
        g=screen(g,CHG,so,80+120*ov,80+120*ov,min(1,0.4+0.6*ov))
        rng=np.random.RandomState(f)
        for _ in range(2+int(2*ov)):
            tgt=body+np.array([rng.uniform(-80,80),rng.uniform(-10,45)]); g=streak(g,so,tgt,8+5*ov,0.5+0.4*ov)
    if 74<=f<96:
        b=ez((f-74)/3)*(1-ez((f-80)/16)); s_=0.8+0.5*ez((f-74)/16)
        g=screen(g,BST,(body[0],body[1]-10),420*s_,280*s_,b); g=screen(g,BST[:,::-1],(body[0],body[1]-30),300*s_,200*s_,0.8*b)
        g=screen(g,CHG,tuple(so),240*s_,240*s_,b*(1-ez((f-76)/8)))
    d=ImageDraw.Draw(g); d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
    cc=np.array([150,48]); nn=np.array([-dv[1],dv[0]]); a_=cc-dv*40; b_=cc+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
    d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+nn*14),tuple(b_-dv*6-nn*14)],fill=(140,200,255,255))
    return g
LAYH={dn:lay(dn) for dn in 'nesw'}
def frame(n):
    G=Image.new('RGBA',(1920,1080))
    for q,dn in enumerate('nesw'): G.alpha_composite(vcell(dn,n%LOOP,LAYH[dn]),((q%2)*960,(q//2)*540))
    return G.convert('RGB')
if __name__=='__main__':
    os.makedirs('_fh',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a,b): frame(i).save(f'_fh/{i:05d}.png',compress_level=1)
