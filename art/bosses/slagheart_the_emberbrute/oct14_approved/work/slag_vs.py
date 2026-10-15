import os, subprocess, shutil, numpy as np, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
sys.path.insert(0,'/workspace/foe_walks/vs'); import seavfx as vfx
O='/workspace/foe_walks/slag_out'; D=f'{O}/strips'; NM='slagheart'
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
A='/workspace/art'
IJ={(a,k):strip(f'{A}/ironjaw_full/v2/{a}/ironjaw_{a}_{k}_strip.png',161,HS) for a in ('idle','attack','hit') for k in 'NESW'}
KE={(a,k):strip(f'{A}/kestrel_full/v3/{a}/kestrel_{a}_{k}_strip.png',116,HS) for a in ('idle','attack','hit') for k in 'NESW'}
HP={'ij':((80,133),IJ),'ke':((68,141),KE)}
CL=vfx.claw(); BU=vfx.splash(); WH=vfx.geyser(); BU2=vfx.splash(seed=9,spd=0.7)
def tint(im,t):
    a=np.array(im); m=a[...,3]>0; f=a[...,:3].astype(float); f=f*(1-t)+np.array([255,130,50])*t
    a[...,:3][m]=np.clip(f[m],0,235).astype(np.uint8); return Image.fromarray(a)
def eshadow(w):
    sh=Image.new('RGBA',(w,w//3)); ImageDraw.Draw(sh).ellipse([0,0,w-1,w//3-1],fill=(0,0,0,90)); return sh.filter(ImageFilter.GaussianBlur(1.5))

W={(a,k):strip(f'{D}/{NM}_{a}_{k}.png',288,S) for a in ('idle','walk','slam','stomp','hit','cast','death') for k in 'ewns'}
def kdir(v): return ('s' if v[0]>=0 else 'w') if v[1]>=0 else ('e' if v[0]>=0 else 'n')
P0,PA,PB,PC=tpos(1.4,2.0),tpos(3.1,2.4),tpos(3.5,0.0),tpos(1.6,0.8)
H1,H2=tpos(4.7,2.7),tpos(4.6,-0.4)
WFPS=11.0; STEP=21.92*S
wdur=lambda a,b: float(np.linalg.norm(b-a)/(STEP*WFPS))
def _soft(n,W_,fn,seed):
    rr=np.random.default_rng(seed); out=[]
    P=[(rr.uniform(0,2*np.pi),rr.uniform(0.5,1.0),rr.uniform(2,6)) for _ in range(46)]
    for i in range(n):
        im=Image.new('RGBA',(W_,W_)); out.append(fn(im,i/(n-1),P,rr)); 
    return out
def _lava(im,u,P,rr):
    W_=im.width; c=W_/2; d=ImageDraw.Draw(im)
    if u<0.35: 
        r=W_*0.08+W_*0.25*u; d.ellipse([c-r,c-r*0.8,c+r,c+r*0.8],fill=(255,140,40,int(90*(1-u/0.35))))
    for a,sp,sz in P:   # magma splash droplets on ballistic arcs + embers
        dist=W_*0.42*sp*u; x=c+np.cos(a)*dist; y=c+np.sin(a)*dist*0.6-W_*0.25*sp*np.sin(np.pi*min(1,u*1.3))+W_*0.25*u*u
        al=int(255*max(0,1-u)**0.8); r=sz*0.7*(1-0.5*u)*W_/160
        d.ellipse([x-r,y-r,x+r,y+r],fill=(255,int(90+80*(1-u)),30,al))
    return im.filter(ImageFilter.GaussianBlur(1.6))
LV=_soft(12,200,_lava,5); LV2=_soft(10,150,_lava,9)
def burn(al):
    im=Image.new('RGBA',(150,60)); d=ImageDraw.Draw(im); d.ellipse([5,8,145,52],fill=(20,12,8,int(170*al))); d.ellipse([45,20,105,40],fill=(255,90,30,int(120*al*al)))
    return im.filter(ImageFilter.GaussianBlur(4))
def blob():
    im=Image.new('RGBA',(70,70)); d=ImageDraw.Draw(im); d.ellipse([15,15,55,55],fill=(255,120,30,230)); d.ellipse([26,24,46,44],fill=(255,170,70,230)); return im.filter(ImageFilter.GaussianBlur(3))
BALL=[blob()]*4
EV=[]; T=0.0
def ev(d,**k):
    global T; EV.append(dict(t0=T,t1=T+d,**k)); T+=d
ev(1.4,w=('idle',kdir(PA-P0),P0,P0),cap='Slagheart the Emberbrute stirs')
ev(wdur(P0,PA),w=('walk',kdir(PA-P0),P0,PA),cap='He lumbers toward Ironjaw')
ev(14*AD+0.8,w=('slam','s',PA,PA),hit=[('ij',8*AD,'284',False,'lava')],cap='Two-fisted slam on Ironjaw')
ev(wdur(PA,PB),w=('walk',kdir(PB-PA),PA,PB),cap='He turns on Kestrel')
ev(10*AD+0.8,w=('stomp',kdir(H2-PB),PB,PB),hit=[('ke',5*AD,'CRIT 402',True,'lava')],cap='Magma stomp next to Kestrel')
ev(wdur(PB,PC),w=('walk',kdir(PC-PB),PB,PC),cap='He backs off to cast')
ev(10*AD+1.0,w=('cast',kdir(H1-PC),PC,PC),ball=[(H1+[30,-260],H1+[0,30],5*AD,0.32),(H2+[30,-260],H2+[0,30],5*AD,0.32)],
   hit=[('ij',5*AD+0.32,'150',False,'lava'),('ke',5*AD+0.32,'158',False,'lava')],cap='Slag Rain on both heroes')
for n in range(2): ev(1.0,w=('idle',kdir(H1-PC),PC,PC),whit=0.25,dmg=['198','176'][n],cap='The heroes strike back')
ev(16*AD+2.4,w=('death',kdir(H1-PC),PC,PC),cap='Slagheart bursts into embers - a smouldering slag heap remains')
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

def put(g,im,c): g.alpha_composite(im,(int(c[0]-im.width/2),int(c[1]-im.height/2)))
def sc(im,s): return im.resize((max(1,round(im.width*s)),max(1,round(im.height*s))),Image.LANCZOS)
# timeline with hit-stop + shake (precomputed so chunks are deterministic)
TL=[]; gt=0.0; freeze=0; shake=0; done=set()
while gt<T-1e-6:
    if freeze==0:
        for h in HITS:
            if h not in done and gt>=h: done.add(h); freeze=3; shake=5
    TL.append((gt,shake))
    if shake: shake-=1
    if freeze: freeze-=1
    else: gt+=1/FPS
def render(fi_):
    t,shk=TL[fi_]; e=[x for x in EV if x['t0']<=t<x['t1']][0]; lt=t-e['t0']; u=lt/(e['t1']-e['t0'])
    a,k,p0,p1=e['w']; wp=p0+(p1-p0)*u
    L=W[(a,k)]
    if a=='walk': fi=int(np.linalg.norm(wp-p0)/STEP)%8
    elif a=='idle': fi=int(t/0.12)%len(L)
    else: fi=min(int(lt/AD),len(L)-1)
    wim=L[fi]; hl=None
    if 'whit' in e:
        hl=lt-e['whit']
        if 0<=hl and int(hl/AD)<6: wim=W[('hit',k)][int(hl/AD)]
    g=B.copy(); top=[]
    if not (a=='death' and fi>=6): put(g,eshadow(96*Z),(wp+[0,1])*Z)
    face={'ij':'N','ke':'W' if t>=EV[4]['t0'] else 'N'}
    sprites=[(wp[1]-1,wim,(round((wp[0]-144*S)*Z),round((wp[1]-300*S)*Z)))]
    for hid,hp in (('ij',H1),('ke',H2)):
        (px,py),SET=HP[hid]; st=('idle',int(t*4)%4); push=np.zeros(2); fl=0
        mid=(hp+[0,-42])*Z
        for hh in e.get('hit',[]):
            if hh[0]==hid and lt>=hh[1]:
                ag=lt-hh[1]; hf=int(ag*12); away=(hp-wp)/np.linalg.norm(hp-wp)
                if hf<4: st=('hit',hf); push=away*[7,5,3,1][hf]; fl=[0.5,0.3,0.12,0][hf]
                fr_=int(ag/AD)
                if ag<2.0: g.alpha_composite(sc(burn(max(0,1-ag/2.0)),Z/1.5*(1.3 if hh[3] else 1.0)),tuple(int(x) for x in (hp*Z-[sc(burn(1),Z/1.5).width/2,sc(burn(1),Z/1.5).height/2-6])))
                if fr_<len(LV): top.append((sc(LV[fr_],(1.8 if hh[3] else 1.4)),(hp+[0,-36])*Z))
                if False:
                    if fr_<12: top.append((sc(EXP[fr_],(2.2 if hh[3] else 1.7)),(hp+([-24,-58] if hid=='ke' else [10,-50]))*Z))
                if ag<1.1: cc_=(hp+push)*Z+[0,-185-ag*70]; cc_[1]=max(cc_[1],120); top.append((dmgimg(hh[2],hh[3],ag),cc_))
        if 'whit' in e and hl is not None and lt<0.55: st=('attack',min(5,int(lt*12)))
        fc=face[hid]; im=SET[(st[0],fc)][st[1]%len(SET[(st[0],fc)])]
        if fl: im=tint(im,fl)
        q=hp+push; put(g,eshadow(44*Z),(q+[0,1])*Z)
        sprites.append((q[1],im,(round((q[0]-px*HS)*Z),round((q[1]-py*HS)*Z))))
    for _,im_,xy in sorted(sprites,key=lambda s:s[0]): g.alpha_composite(im_,xy)
    if False:   # existing explosion strip reused as muzzle flash/smoke (cell is too narrow to hold it)
        mz=wp+cellpt(k,MUZ['e' if k in 'ew' else 'n']); dvx=1 if k in 'es' else -1
        top.append((sc(EXP[[1,2,3,6,8,10][fi-3]],[0.8,1.0,1.1,1.1,1.2,1.3][fi-3]),(mz+[dvx*10,-4])*Z))
    for (b0,b1,ts,dur) in e.get('ball',[]):
        if ts<=lt<ts+dur:
            v=(lt-ts)/dur; p=b0+(b1+[0,-30]-b0)*v+[0,-28*np.sin(np.pi*v)]
            bi=BALL[int(lt/0.05)%4]
            if b1[0]<b0[0]: bi=bi.transpose(Image.FLIP_LEFT_RIGHT)
            top.append((sc(bi,1.3*Z/1.5),p*Z))
    if hl is not None and 0<=hl<0.5:
        top.append((sc(LV2[min(9,int(hl/AD))],1.6),(wp+[0,-60])*Z))
        top.append((dmgimg(e['dmg'],False,hl),wp*Z+[0,-300-hl*70]))
    for im_,c in top: put(g,im_,c)
    G=g
    if shk:
        amp=[0,4,7,10,12,13][shk]; ox_=int(amp*(1 if shk%2 else -1)); oy_=int(amp*0.6*(1 if shk%3 else -1))
        G2=Image.new('RGBA',G.size,(34,46,30,255)); G2.alpha_composite(G,(ox_,oy_)); G=G2
    dr=ImageDraw.Draw(G); dr.rectangle([0,0,1920,78],fill=(20,24,20,255)); dr.text((960,39),e['cap'],font=fnt,fill=(255,236,190),anchor='mm')
    return G.convert('RGB')
if __name__=='__main__':
    d='/workspace/foe_walks/slag_out/_frames'; os.makedirs(d,exist_ok=True)
    if sys.argv[1]=='n': print(len(TL)); sys.exit()
    a_,b_=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a_,min(b_,len(TL))): render(i).save(f'{d}/{i:05d}.png',compress_level=1)
