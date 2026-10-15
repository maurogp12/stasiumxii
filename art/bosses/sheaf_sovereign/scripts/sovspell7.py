# Sheaf Sovereign spell 'hands' v2 stills W/E, from the approved painted plate spell_concepts/sov_hands_v2_plate.jpg (cuts: cut3.py/cut4.py)
import sys; sys.path.insert(0,'/workspace/foe_walks/harvest_spell_v1')
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import sheet as SH
from sovatk import PP, boss, sickle_img, BS, BSMK
from crows4 import sc, alpha, addglow
D='/workspace/foe_walks/harvest_v2/spell_concepts/hands_v2/'
L=lambda n: Image.open(D+n).convert('RGBA')
HANDS=[L(f'hand{i}.png') for i in range(4)]; SQZ=[L(f'squeeze{i}.png') for i in range(2)]; GOPEN=L('grip_open.png'); GFIST=L('grip_fist.png');
def _curl(im):   # +1 if the fist's fingers/knuckles sit right of its wrist (curls rightward)
    a=np.array(im)[...,3].astype(float); H_=a.shape[0]; X=np.arange(a.shape[1])
    top=a[:int(H_*0.35)].sum(0); wr=a[int(H_*0.7):].sum(0)
    return np.sign((top*X).sum()/top.sum()-(wr*X).sum()/wr.sum())
# per side: hand on the hero's LEFT must curl RIGHT (+1), hand on the RIGHT must curl LEFT (-1); mirror sprites to satisfy
FIST={}
for sd,want in ((-1,1),(1,-1)):
    src=SQZ[0] if sd<0 else SQZ[1]
    FIST[sd]=src if _curl(src)==want else src.transpose(Image.FLIP_LEFT_RIGHT)
    assert _curl(FIST[sd])==want
print('curl check: sprite0',_curl(SQZ[0]),'sprite1',_curl(SQZ[1]),'left-side',_curl(FIST[-1]),'right-side',_curl(FIST[1]))
CURL=1
SPRAY=L('spray.png'); BURST=L('burst.png'); RINGTD=L('rune_circle_topdown.png')
EMB=Image.open('/workspace/foe_walks/harvest_v2/spell_concepts/assets/embers.png').convert('RGBA')
def iso_ring(w):
    return RINGTD.resize((int(w),int(w*0.42)),Image.LANCZOS)
PH={'cast':   dict(pend=-125,tilt=-4,lift=8,gk=1.0,orb=1.3,spin=1,ring=0.25,crack=0,rise=0,lift_h=0,grab=0),
    'crack':  dict(pend=-125,tilt=-3,lift=8,gk=1.0,orb=1.3,spin=1,ring=1.0,crack=1,rise=0,lift_h=0,grab=0),
    'burst':  dict(pend=-125,tilt=-2,lift=7,gk=0.95,orb=1.3,spin=1,ring=1.0,crack=0.8,rise=0.6,lift_h=4,grab=0,whole=1),
    'grab':   dict(pend=-125,tilt=-2,lift=6,gk=1.0,orb=1.3,spin=1,ring=1.0,crack=0.6,rise=1.0,lift_h=14,grab=1,set='fist_open',tint=0.07,squash=0,hw=0.8,whole=1),
    'squeeze':dict(pend=-125,tilt=-2,lift=6,gk=1.0,orb=1.3,spin=1,ring=1.0,crack=0.6,rise=1.0,lift_h=18,grab=1,set='fist',tint=0.11,squash=0.06,hw=0.66,whole=1),
    'release':dict(pend=-40,tilt=1,lift=2,gk=0.5,orb=1.05,spin=0.3,ring=0.35,crack=0,rise=0.45,lift_h=0,grab=0,whole=1)}
def screen(g,im,x,y,k): return SH.screen(g,alpha(im,k),(int(x-im.width/2),int(y-im.height/2)),1.0)
def emerge(im,rise):
    a=np.array(im); vis=int(a.shape[0]*rise); out=np.zeros_like(a); out[a.shape[0]-vis:]=a[:vis] if False else 0
    out[:vis]=a[:vis]; return Image.fromarray(out),vis
def cell(dn,ph,label): return cellQ(dn,PH[ph],label)
def cellQ(dn,Q,label,DX=0,FLR=None,WB=384):
    W=dn=='w'; side='front' if W else 'back'; lead=1 if W else -1; Ld=SH.LAY[dn]
    sh_=np.array([(0 if W else -40)+DX,0]); BP=np.array(Ld['b'],float)+[DX,0]; IJ=np.array(Ld['ij'],float)+sh_; KE=np.array(Ld['ke'],float)+sh_
    im,(fx,fy),(hx,hy),tipf=boss(side,lead,Q['pend'],Q['tilt'],Q['gk'])
    im=im.resize((int(im.width*BS),int(im.height*BS)),Image.LANCZOS)
    h=17+Q['lift']; ox,oy=BP[0]-fx*BS,BP[1]-fy*BS-h
    P=PP[side]; hb=P['R']['head']; mk=(ox+(500+(hb[0][0]+hb[1][0])/2)*BS, oy+(400+hb[0][1]+105)*BS); chest=(mk[0],mk[1]+45)
    g=(FLR if FLR is not None else SH.FL).copy()
    # rune circle under the heroes
    cx,cy=(IJ[0]+KE[0])/2,(IJ[1]+KE[1])/2+6; RW=280; cx=float(np.clip(cx,DX+RW/2+4,DX+WB-RW/2-4))
    if Q['ring']>0:
        r=iso_ring(RW*(0.8+0.2*Q['ring']))
        dk=np.array(r).astype(float); dk[...,:3]*=0.25; dk[...,3]*=0.6*Q['ring']; g.alpha_composite(Image.fromarray(dk.astype(np.uint8)),(int(cx-r.width/2),int(cy-r.height/2)))
        g=SH.screen(g,SH.glow(alpha(r,Q['ring']),6,1.0),(int(cx-r.width/2),int(cy-r.height/2)),0.7)
        g=SH.screen(g,alpha(r,Q['ring']),(int(cx-r.width/2),int(cy-r.height/2)),1.0)
    if Q['crack']>0:   # light rays from the cracks: the plate's glow fountain stretched upward
        rng=np.random.default_rng(7)
        for px in (IJ[0],KE[0],cx):
            for j in range(4):
                wsh=rng.uniform(5,11); hsh=rng.uniform(90,150); xo=px+rng.normal(0,26)
                sh_im=BURST.resize((int(wsh*3),int(hsh)),Image.LANCZOS); a_=np.array(sh_im).astype(float)
                X_=np.arange(a_.shape[1])[None,:]; Yr=np.arange(a_.shape[0])[:,None]
                prof=np.exp(-((X_-a_.shape[1]/2)/(wsh*0.45))**2); a_[...,3]=255*prof*np.clip(Yr/a_.shape[0],0,1)**1.3*np.clip((a_.shape[0]-Yr)/10,0,1)
                a_[...,:3]=np.clip(a_[...,:3]*0.5+np.array([255,205,110])*0.6,0,255)
                ray=Image.fromarray(a_.astype(np.uint8)).rotate(rng.normal(0,3),expand=True,resample=Image.BICUBIC)
                g=screen(g,ray,xo,cy-hsh/2+rng.uniform(0,14),(0.5+0.4*rng.random())*Q['crack'])
    # shadow under the boss (shrinks as he rises)
    k=1-(h-15)/20*.4; shd=Image.new('RGBA',g.size); sw=50*k
    ImageDraw.Draw(shd).ellipse([BP[0]-sw,BP[1]-sw*.28,BP[0]+sw,BP[1]+sw*.28],fill=(0,0,0,int(115*k))); g.alpha_composite(shd.filter(ImageFilter.GaussianBlur(5)))
    # sickles: WIDE whirling ring with trails
    cx0,cy0=BP[0],BP[1]-h-105; SK=[]
    for i in range(6):
        a=2*np.pi*i/6+0.3+Q.get('sph',0); SK.append((np.sin(a),i,a))
    def spos(a): return cx0+92*Q['orb']*np.cos(a), cy0+32*Q['orb']*np.sin(a)-20*np.cos(a)
    def draw_sick(front):
        for z,i,a in sorted(SK):
            if (z>=0)!=front: continue
            spin=-np.degrees(a)*1.5*Q['spin']
            if Q['spin']>0.5:
                for q,kq in ((1,0.25),(2,0.12),(3,0.05)):
                    xq,yq=spos(a-0.22*q); tq=sickle_img(side,i,spin+28*q,BS*1.05,1.0,kq); g.alpha_composite(tq,(int(xq-tq.width/2),int(yq-tq.height/2)))
            x,y=spos(a); s=sickle_img(side,i,spin,BS*1.05,1.0 if z>=0 else 0.75); g.alpha_composite(s,(int(x-s.width/2),int(y-s.height/2)))
    draw_sick(False)
    g.alpha_composite(im,(int(ox),int(oy)))
    if Q['gk']>0.6:   # mask + ribs blaze: painted embers glow
        bk=min(1,(Q['gk']-0.6)/0.35); g=addglow(g,sc(EMB,0.24),mk[0],mk[1],bk); g=addglow(g,sc(EMB,0.3),chest[0],chest[1],0.7*bk)
    draw_sick(True)
    # heroes held by hands: back hands (h1,h3) flank behind, front claw (h2) grips the legs
    rise=Q['rise']; grab=Q['grab']
    def hand_parts(img,heroh,lean,rise,sink_=0):
        tgt=heroh*1.3; s_=tgt/img.height; im_=img.resize((max(1,int(img.width*s_*Q.get('hw',0.68))),int(img.height*s_)),Image.LANCZOS)
        a=np.array(im_); vis=max(1,int(a.shape[0]*rise)); a=a[:vis].copy(); hh=a.shape[0]
        Y=np.arange(hh)[:,None]; cut=im_.height*0.36
        top=a.copy(); top[...,3]=(top[...,3]*np.clip((cut-Y)/10+0.5,0,1)).astype(np.uint8)
        bot=a.copy(); bot[...,3]=(bot[...,3]*np.clip((Y-cut)/10+0.5,0,1)).astype(np.uint8)
        pad=lambda q: Image.fromarray(q).rotate(lean,expand=True,resample=Image.BICUBIC,center=(q.shape[1]/2,q.shape[0]))
        T_,B_=pad(top),pad(bot); dn_=int(sink_*rise)
        crop=lambda q: q.crop((0,0,q.width,max(1,q.height-dn_)))
        return crop(T_),crop(B_)
    order=sorted((('ij',IJ),('ke',KE)),key=lambda q:q[1][1])
    if not Q.get('whole'):
        for c,pos in order:
            lf=Q['lift_h']
            hm=SH.hero(c,'hit' if grab else 'idle',Ld['hk'],1 if grab else 0)
            if grab: hm=SH.tint(hm,Q.get('tint',0.07))
            if Q.get('squash',0): hm=hm.resize((int(hm.width*(1-Q['squash'])),hm.height),Image.LANCZOS)
            hh_=np.nonzero(np.array(hm)[...,3].max(1)>40)[0]; heroh=hh_.max()-hh_.min()
            parts=[]
            if rise>0:
                st=Q.get('set')
                pairs=((-1,0),(1,1)) if st in ('fist','fist_open') else ((-1,2+(c=='ke')),(1,(c=='ke')*1))
                SRC=SQZ if st else HANDS
                for sd,idx in pairs:      # left side: right-curling hand, right side: left-curling hand
                    lean=(10*sd if grab else 5*sd)
                    top,bot=hand_parts(FIST[sd] if st else SRC[idx],heroh,lean,rise,0.3*heroh if grab else 0.1*heroh)
                    x=pos[0]+sd*((40 if c=="ij" else 33)-(8 if st=='fist' else 2 if st=='fist_open' else 0)); base=pos[1]+8
                    parts.append((top,bot,x,base))
            for top,bot,x,base in parts: g.alpha_composite(bot,(int(x-bot.width/2),int(base-bot.height)))
            sh=Image.new('RGBA',g.size); s_=30*(1-lf/60); ImageDraw.Draw(sh).ellipse([pos[0]-s_,pos[1]-s_*.28,pos[0]+s_,pos[1]+s_*.28],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(4)))
            SH.put(g,hm,pos[0],pos[1]-lf,0)
            if Q.get('set')=='fist':
                for top,bot,x,base in parts:
                    fy=base-top.height+top.height*0.2
                    g=addglow(g,sc(EMB,0.14).rotate(30*(1 if x>pos[0] else -1),expand=True),x+(pos[0]-x)*0.35,fy,1.0)
            for top,bot,x,base in parts:
                if grab or rise<0.5: g.alpha_composite(top,(int(x-top.width/2),int(base-top.height)))
                else: g.alpha_composite(top,(int(x-top.width/2),int(base-top.height)))

    else:
      for c,pos in order:
        st=Q.get('set'); sq=st=='fist'; rel=not grab
        lf=Q['lift_h']
        hm=SH.hero(c,'hit' if grab else 'idle',Ld['hk'],Q.get('hf',1) if grab else 0)
        if grab: hm=SH.tint(hm,Q.get('tint',0.07))
        if Q.get('squash',0): hm=hm.resize((max(1,int(hm.width*(1-Q['squash']))),hm.height),Image.LANCZOS)
        ha=np.array(hm)[...,3]; ys_,xs_=np.nonzero(ha>40); heroh=ys_.max()-ys_.min(); herow=xs_.max()-xs_.min()
        gl=pos[1]+8; top_hero=pos[1]-lf-heroh
        src=GFIST if sq else GOPEN
        # fist ~ torso size: plate fist block is the top ~45% of the sprite and ~0.9 of its width
        torso=heroh*(0.42 if sq else 0.5); s_=torso/(src.width*0.82); im_=src.resize((int(src.width*s_),int(src.height*s_)),Image.LANCZOS)
        fist_h=im_.height*0.42
        if sq: fist_top=top_hero+heroh*(0.30 if c=='ij' else 0.24)        # fist around waist/chest, head + shoulders out the top
        else:  fist_top=top_hero+heroh*(0.42 if c=='ij' else 0.30)        # cupped: head+shoulders above the fingers
        hand_top=fist_top-im_.height*0.04
        if rel: hand_top=gl+(hand_top-gl)*Q['rise']   # rising / sinking whole, straight up/down from the circle
        x=pos[0]+(-3 if c=='ij' else 0)
        def put_hand(mask_rows=None):
            L_=Image.new('RGBA',g.size); L_.alpha_composite(im_,(int(x-im_.width/2),int(hand_top)))
            a=np.array(L_); Yc=np.arange(a.shape[0])[:,None]
            a[...,3]=(a[...,3]*np.clip((gl-Yc)/3,0,1)).astype(np.uint8)    # clean cut at the circle/ground line
            if mask_rows is not None: a[...,3]=(a[...,3]*mask_rows).astype(np.uint8)
            g.alpha_composite(Image.fromarray(a))
        put_hand()                       # whole hand (back of hand / palm) behind the hero
        sh=Image.new('RGBA',g.size); s2=30*(1-lf/60); ImageDraw.Draw(sh).ellipse([pos[0]-s2,pos[1]-s2*.28,pos[0]+s2,pos[1]+s2*.28],fill=(0,0,0,110)); g.alpha_composite(sh.filter(ImageFilter.GaussianBlur(4)))
        SH.put(g,hm,pos[0],pos[1]-lf,0)
        if Q['rise']>0:   # same sprite in front from the fingertip line down: fingers + thumb + wrist wrap the hero
            Yc=np.arange(g.size[1])[:,None].astype(float); line=hand_top+im_.height*(0.10 if sq else 0.16)
            put_hand(np.clip((Yc-line)/6,0,1))
            if sq and Q.get('spark',1)>0.05:
                for dx_,dy_ in ((-0.35,0.15),(0.35,0.1),(0,0.0)):
                    g=addglow(g,sc(EMB,0.13).rotate(dx_*90,expand=True),x+dx_*im_.width,hand_top+fist_h*dy_,Q.get('spark',1))
        if not grab:      # dirt/smoke at the ground line where the hand rises/sinks
            lay=Image.new('RGBA',g.size); rr=np.random.default_rng(int(pos[0]))
            for j in range(7):
                p=sc(BSMK,rr.uniform(0.04,0.08)).rotate(rr.uniform(0,360),expand=True); lay.alpha_composite(alpha(p,0.75*min(1,Q['rise']*3)),(int(x+rr.normal(0,im_.width*0.3)-p.width/2),int(gl-3-p.height/2)))
            g.alpha_composite(lay)
    if Q.get('spray',max(Q['rise'],Q['crack']*0.6))>0.02:   # ember spray + dark dirt/smoke burst
        sp=sc(SPRAY,0.55); kk=0.9*Q.get('spray',max(Q['rise'],Q['crack']*0.6))
        g=screen(g,sp,cx,cy-110,kk)
        lay=Image.new('RGBA',g.size); rr=np.random.default_rng(3)
        for j in range(10):
            p=sc(BSMK,rr.uniform(0.05,0.1)).rotate(rr.uniform(0,360),expand=True)
            lay.alpha_composite(alpha(p,0.55*Q.get('spray',Q['rise'])),(int(cx+rr.normal(0,70)-p.width/2),int(cy-rr.uniform(0,60)-p.height/2)))
        g.alpha_composite(lay)
    if label: ImageDraw.Draw(g).text((10,8),f'{dn.upper()} {label}',font=SH.fnt,fill=(255,236,170,255),stroke_width=3,stroke_fill=(0,0,0,255))
    return g
PHL=[('cast','1 cast'),('crack','2 circle cracks'),('burst','3 hands burst'),('grab','4a grab'),('squeeze','4b squeeze'),('release','5 release')]
if __name__=='__main__':
    rows=[[cell(dn,p,l) for p,l in PHL] for dn in ('w','e')]
    S=Image.new('RGB',(384*6,1080))
    for r,cells in enumerate(rows):
        for i,c in enumerate(cells): S.paste(c.convert('RGB'),(i*384,r*540))
    S.save('/workspace/foe_walks/harvest_v2/sov_spell_hands_stills_WE_v7.png'); print('ok')
