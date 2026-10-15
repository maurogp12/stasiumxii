# Sheaf Sovereign 'hands' spell, 4 directions, 3.5 s, built on sovspell7.cellQ (v6/v7 approved stills design)
import sys, os, subprocess; sys.path.insert(0,'/workspace/foe_walks/harvest_spell_v1')
import numpy as np
from PIL import Image, ImageDraw
import sheet as SH, rig2
import sovspell8 as S7
T=3.7; NF=89; DX=288
def floor960():
    im=Image.new('RGBA',(960,540),(16,18,24,255)); d=ImageDraw.Draw(im); TW,TH=96,48
    for i in range(-14,15):
        for j in range(-14,15):
            x=192+DX+(i-j)*TW/2; y=270+(i+j)*TH/2
            if -60<x<1020 and -40<y<580: d.polygon([(x,y-TH/2),(x+TW/2,y),(x,y+TH/2),(x-TW/2,y)],fill=(38,42,54,255) if (i+j)%2 else (30,34,44,255),outline=(48,54,68,255))
    return im
FL=floor960()
def E(x): x=np.clip(x,0,1); return x*x*(3-2*x)
def win(t,a,b): return E((t-a)/(b-a))
def Qt(t):
    cast=win(t,0.3,0.8)*(1-win(t,2.75,3.35))
    pend=-125*cast
    ring=win(t,0.6,1.1)*(1-win(t,2.9,3.4)); crack=win(t,0.8,1.1)*(1-0.3*win(t,1.3,1.6))*(1-win(t,2.7,3.1))
    rise=win(t,1.1,1.5)*(1-win(t,2.95,3.35))
    grab=1 if 1.6<=t<2.75 else 0
    # hand states, each change cross-dissolved over ~0.15 s (3-4 frames)
    def xf(a): return np.clip((t-a)/0.15,0,1)
    if t<1.6: hs=[('open',1)]
    elif t<1.8: u=xf(1.62); hs=[('open',1-u),('mid',u)]
    elif t<2.05: u=xf(1.82); hs=[('mid',1-u),('grip',u)]
    elif t<2.7: u=xf(2.05); hs=[('grip',1-u),('fist',u)]
    elif t<2.88: u=xf(2.7); hs=[('fist',1-u),('mid',u)]
    else: u=xf(2.88); hs=[('mid',1-u),('open',u)]
    fistw=dict(hs).get('fist',0)
    sqz=2.15<=t<2.7
    p=np.sin(np.pi*np.clip((t-2.15)/0.27,0,2))**2 if sqz else 0.0     # 2-beat pulse
    lift_h=(4*win(t,1.3,1.6)+10*win(t,1.65,1.95)+4*win(t,2.1,2.2))*(1-win(t,2.72,2.92))
    q=dict(pend=pend,tilt=-4*cast*(1-win(t,1.2,1.6))-2*cast*win(t,1.2,1.6),lift=8*cast,gk=0.35+0.65*cast,
           orb=1.0+0.3*cast,spin=cast,ring=ring,crack=crack,rise=rise,lift_h=lift_h,grab=grab,whole=1,hst=hs,
           set=('fist' if fistw>0.5 else None),tint=(0.07+0.04*p) if sqz else 0.07,squash=0.06*p,spark=p*fistw,
           hf=int((t*12)%4),spray=max(0,np.sin(np.pi*np.clip((t-1.15)/0.7,0,1)))*0.9+0.3*crack*(t<1.2))
    return q
# sickle orbit phase: base 1 rev / 4 s plus spin-up, scaled so the loop ends on the start pose (multiple of 1/6 rev)
ts=np.linspace(0,T,2001); sp=np.array([Qt(t)['spin'] for t in ts]); acc=np.concatenate([[0],np.cumsum((1+2.5*sp[1:])*np.diff(ts))])*2*np.pi/4
k6=2*np.pi/6; KS=np.round(acc[-1]/k6)*k6/acc[-1]
def sph(t): return np.interp(t,ts,acc)*KS
def tile(base,t):
    q=Qt(t); q['sph']=sph(t); return S7.cellQ(base,q,'',DX=DX,FLR=FL,WB=960)
def frame(t):
    S=Image.new('RGB',(1920,1080)); cache={}
    for k,dn in enumerate('nesw'):
        base='w' if dn in 'ws' else 'e'
        if base not in cache: cache[base]=tile(base,t)
        g=cache[base]
        if dn in 'sn': g=g.transpose(Image.FLIP_LEFT_RIGHT)
        g=g.copy(); ImageDraw.Draw(g).text((16,10),dn.upper(),font=rig2.fnt,fill=(255,236,170,255),stroke_width=4,stroke_fill=(0,0,0,255))
        S.paste(g.convert('RGB'),((k%2)*960,(k//2)*540))
    return S
if __name__=='__main__':
    if len(sys.argv)>1:
        for t in [float(x) for x in sys.argv[1].split(',')]: frame(t).save(f'/tmp/sp5_{t}.png')
        sys.exit()
    d='/tmp/_sp5'; os.makedirs(d,exist_ok=True)
    for i in range(NF): frame(i/24).save(f'{d}/{i:04d}.png')
    subprocess.run(f'ffmpeg -y -loglevel error -framerate 24 -i {d}/%04d.png -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 16 -movflags +faststart /workspace/foe_walks/harvest_v2/sov_spell_hands_4dir_v2.mp4',shell=True,check=True)
