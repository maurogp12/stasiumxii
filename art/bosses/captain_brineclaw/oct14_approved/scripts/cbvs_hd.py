import os, subprocess, shutil, numpy as np, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
sys.path.insert(0,'/workspace/foe_walks/vs'); import seavfx as vfx
O='/workspace/foe_walks/cb3_out'; D=f'{O}/captain_brineclaw_v3'; NM='captain_brineclaw'
FPS=24; AD=0.05833; WN,HN=640,360; TW,TH=76,38; OX,OY=320,92; S=0.44; HS=0.65; Z=3
def tpos(i,j): return np.array([OX+(i-j)*TW/2, OY+(i+j)*TH/2],float)
def board():
    im=Image.new('RGBA',(WN*Z,HN*Z),(34,46,30,255)); d=ImageDraw.Draw(im); zz=lambda pts:[(x*Z,y*Z) for x,y in pts]
    for i in range(7):
        for j in range(7):
            c=tpos(i,j); d.polygon(zz([(c[0],c[1]-TH/2),(c[0]+TW/2,c[1]),(c[0],c[1]+TH/2),(c[0]-TW/2,c[1])]),fill=(74,124,52,255) if (i+j)%2 else (82,134,58,255),outline=(60,100,42,255))
    for k in range(6):
        l=tpos(0,6)+[-TW/2,0]; b=tpos(6,6)+[0,TH/2]; r=tpos(6,0)+[TW/2,0]
        d.line(zz([(l[0],l[1]+k),(b[0],b[1]+k),(r[0],r[1]+k)]),width=Z,fill=(58,44,30,255))
    return im
B=board()
def strip(p,cw,sc):
    im=Image.open(p).convert('RGBA'); return [im.crop((x*cw,0,x*cw+cw,im.height)).resize((round(cw*sc*Z),round(im.height*sc*Z)),Image.LANCZOS) for x in range(im.width//cw)]
W={}
for a_,k_ in [('idle','s'),('idle','e'),('walk','s'),('walk','e'),('walk','n'),('attack','s'),('attack','e'),('hit','s'),('cast','s'),('death','s')]:
    W[(a_,k_)]=strip(f'{D}/{NM}_{a_}_{k_}.png',288,S)
A='/workspace/art'
IJ={(a,k):strip(f'{A}/ironjaw_full/v2/{a}/ironjaw_{a}_{k}_strip.png',161,HS) for a in ('idle','attack','hit') for k in 'NESW'}
KE={(a,k):strip(f'{A}/kestrel_full/v3/{a}/kestrel_{a}_{k}_strip.png',116,HS) for a in ('idle','attack','hit') for k in 'NESW'}
HP={'ij':((80,133),IJ),'ke':((68,141),KE)}
CL=vfx.claw(); BU=vfx.splash(); WH=vfx.geyser(); BU2=vfx.splash(seed=9,spd=0.7)
def tint(im,t):
    a=np.array(im); m=a[...,3]>0; f=a[...,:3].astype(float); f=f*(1-t)+np.array([90,215,225])*t
    a[...,:3][m]=np.clip(f[m],0,235).astype(np.uint8); return Image.fromarray(a)
def eshadow(w):
    sh=Image.new('RGBA',(w,w//3)); ImageDraw.Draw(sh).ellipse([0,0,w-1,w//3-1],fill=(0,0,0,90)); return sh.filter(ImageFilter.GaussianBlur(1.5))
P0,PA,PB,PC=tpos(2.0,2.4),tpos(3.3,2.4),tpos(3.3,0.9),tpos(1.8,0.9)
WFPS=11.0; STEP=6.0*S   # board px per walk frame along path
wdur=lambda a,b: float(np.linalg.norm(b-a)/(STEP*WFPS))
H1,H2=tpos(4.7,2.7),tpos(4.6,-0.4)
EV=[]; T=0.0
def ev(d,**k):
    global T; EV.append(dict(t0=T,t1=T+d,**k)); T+=d
ev(1.6,w=('idle','s',P0,P0),cap='Captain Brineclaw (Tidehold) hunts the party')
ev(wdur(P0,PA),w=('walk','s',P0,PA),cap='He scuttles at Ironjaw')
ev(12*AD+0.7,w=('attack','s',PA,PA),hit=[('ij',5*AD,'148',False,'claw')],chg=(0,5*AD,'ij'),cap='Claw crush on Ironjaw')
ev(0.8,w=('idle','s',PA,PA),cap='He turns toward Kestrel')
ev(wdur(PA,PB),w=('walk','e',PA,PB),cap='Creeping behind Kestrel (back view)')
ev(12*AD+0.7,w=('attack','e',PB,PB),hit=[('ke',5*AD,'CRIT 296',True,'claw')],chg=(0,5*AD,'ke'),cap='Critical crush from behind on Kestrel')
ev(wdur(PB,PC),w=('walk','n',PB,PC),cap='He backs off to cast')
ev(0.3,w=('idle','s',PC,PC),cap='Tidal Geyser')
ev(14*AD+1.0,w=('cast','s',PC,PC),hit=[('ij',8*AD,'96',False,'spell'),('ke',8*AD,'102',False,'spell')],chg=(2*AD,8*AD,'cast'),cap='Tidal Geyser hits both heroes')
ev(0.6,w=('idle','s',PC,PC),cap='The heroes strike back')
for n in range(2): ev(1.1,w=('idle','s',PC,PC),whit=0.3,dmg=['210','188'][n],cap='The heroes strike back')
ev(20*AD+2.6,w=('death','s',PC,PC),cap='Captain Brineclaw crumbles')
# hit-stop: freeze 3 frames at each hero impact
HITS=sorted([e['t0']+h[1] for e in EV for h in e.get('hit',[])])
fnt=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',45)
def dmgimg(txt,crit,age):
    sz=int((62 if crit else 44)*(1+0.45*np.exp(-age*14)*np.cos(age*30)))
    f_=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',max(10,sz))
    col=(255,110,70) if crit else (120,230,225)
    lay=Image.new('RGBA',(420,120)); d=ImageDraw.Draw(lay); d.text((210,60),txt,font=f_,fill=col+(255,),anchor='mm',stroke_width=4,stroke_fill=(50,18,6,255))
    al=1-max(0,age-0.75)/0.35
    if al<1: a=np.array(lay); a[...,3]=(a[...,3]*max(0,al)).astype(np.uint8); lay=Image.fromarray(a)
    return lay
def put(g,im,c): g.alpha_composite(im,(int(c[0]-im.width/2),int(c[1]-im.height/2)))
hero_face={'ij':'N','ke':'E'}
d='/workspace/foe_walks/cb3_out/_frames'; shutil.rmtree(d,ignore_errors=True); os.makedirs(d)
gt=0.0; f=0; freeze=0; done_hits=set(); shake=0; NFMAX=int(T*FPS)+40
while gt<T-1e-6:
    t=gt; e=[x for x in EV if x['t0']<=t<x['t1']][0]; lt=t-e['t0']; u=lt/(e['t1']-e['t0'])
    a,k,p0,p1=e['w']; uu=min(1,u*1.05) if a!='walk' else u
    wp=p0+(p1-p0)*uu
    L=W[(a,k)]; fi=(int(np.linalg.norm(wp-p0)/STEP)%8 if a=='walk' else int(t/0.14)%len(L)) if a in('walk','idle') else min(int(lt/AD),len(L)-1)
    wim=L[fi]
    hl=None
    if 'whit' in e:
        hl=lt-e['whit']
        if 0<=hl and int(hl/AD)<6: wim=W[('hit','s')][int(hl/AD)]
    g=B.copy(); top=[]   # top: fx in 1280 coords
    if not (a=='death' and fi>=5): put(g,eshadow(96*Z),(wp+[0,1])*Z)
    if t>=EV[5]['t0']+5*AD: hero_face['ke']='W'
    sprites=[(wp[1]-1,wim,(round((wp[0]-144*S)*Z),round((wp[1]-300*S)*Z)))]
    for hid,hp in (('ij',H1),('ke',H2)):
        (px,py),SET=HP[hid]; face=hero_face[hid]; st=('idle',int(t*4)%4); push=np.zeros(2); fl=0
        mid=(hp+[0,-42])*2
        for hh in e.get('hit',[]):
            if hh[0]==hid and lt>=hh[1]:
                ag=lt-hh[1]; hf=int(ag*12)
                away=(hp-wp)/np.linalg.norm(hp-wp)
                if hf<4: st=('hit',hf); push=away*[7,5,3,1][hf]; fl=[0.5,0.3,0.12,0][hf]
                fr_=int(ag/AD)
                if hh[4]=='claw':
                    if fr_<len(CL): top.append((CL[fr_],mid))
                    if fr_<len(BU): top.append((BU[fr_],mid))
                else:
                    if fr_<len(WH): top.append((WH[fr_],(hp+push)*2+[0,-100]))
                    if fr_<len(BU2): top.append((BU2[fr_],mid))
                if ag<1.1: cc_=(hp+push)*2+[0,-185-ag*70]; cc_[1]=max(cc_[1],120); top.append((dmgimg(hh[2],hh[3],ag),cc_))
        if 'whit' in e and hl is not None:
            if lt<0.55: st=('attack',min(5,int(lt*12)))
            if hid=='ke': face='W'
        im=SET[(st[0],face)][st[1]%len(SET[(st[0],face)])]
        if fl: im=tint(im,fl)
        q=hp+push; put(g,eshadow(44*Z),(q+[0,1])*Z)
        sprites.append((q[1],im,(round((q[0]-px*HS)*Z),round((q[1]-py*HS)*Z))))
    for _,im_,xy in sorted(sprites,key=lambda s:s[0]): g.alpha_composite(im_,xy)
    if 'chg' in e:
        c0,c1,tg=e['chg']
        if c0<=lt<c1:
            kk=(lt-c0)/(c1-c0)
            if tg=='cast': pts=[(wp+[40,-80])*2]
            else:
                hp={'ij':H1,'ke':H2}[tg]; dv=(hp-wp)/np.linalg.norm(hp-wp); pts=[(wp+dv*34+[0,-55])*2]
            for p_ in pts: top.append((vfx.charge(kk),p_))
    if hl is not None and 0<=hl<0.5:
        top.append((BU[min(9,int(hl/AD))],(wp+[0,-60])*2))
        if hl<0.25: top.append((vfx.charge(1-hl/0.25,120),(wp+[0,-60])*2))
        top.append((dmgimg(e['dmg'],False,hl),(wp)*2+[0,-250-hl*70]))
    G=g
    for im_,c in top: put(G,im_.resize((round(im_.width*1.5),round(im_.height*1.5)),Image.LANCZOS),np.array(c)*1.5)
    # hit stop / shake
    if freeze==0:
        for h in HITS:
            if h not in done_hits and gt>=h: done_hits.add(h); freeze=3; shake=5
    if shake:
        amp=[0,4,7,10,12,13][shake]; ox_=int(amp*(1 if shake%2 else -1)); oy_=int(amp*0.6*(1 if shake%3 else -1))
        G2=Image.new('RGBA',G.size,(34,46,30,255)); G2.alpha_composite(G,(ox_,oy_)); G=G2
    dr=ImageDraw.Draw(G); dr.rectangle([0,0,1920,78],fill=(20,24,20,255)); dr.text((960,39),e['cap'],font=fnt,fill=(255,236,190),anchor='mm')
    G.convert('RGB').save(f'{d}/{f:05d}.png'); f+=1
    if shake: shake-=1
    if freeze: freeze-=1
    else: gt+=1/FPS
print('frames',f,'secs',f/FPS)
subprocess.run(f"ffmpeg -y -loglevel error -framerate {FPS} -i {d}/%05d.png -c:v libx264 -profile:v high -pix_fmt yuv420p -vf scale=1920:1080 -crf 16 -movflags +faststart {O}/brineclaw_vs_players.mp4",shell=True,check=True); print('done')
