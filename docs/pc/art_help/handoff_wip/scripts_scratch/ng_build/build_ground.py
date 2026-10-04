from ngc import *
import pickle
from build_tiles_helpers import *
OUTK='tiles'
# ================= SNOW =================
clean=np.load('tmp/snow_clean.npy')
stamps=pickle.load(open('tmp/snow_stamps.pkl','rb'))
K_S=2.9
def snow_grade(rgb):
    # keep it light and clean: lift mids a touch, deepen the lavender shadow hue slightly (no grey)
    l=lum(rgb)[...,None]
    out=l+(rgb-l)*1.6
    out=np.clip(0.93+(out-0.93)*1.35,0,1)
    out=np.clip(out*1.015,0,1)**0.96
    return np.clip(np.minimum(out,0.985),0,1)
MINT_S=smoothstep(0.035,0.13,DE)
def snow_tex(org,k,flip=False,rot=0.0):
    T=make_periodic(src_sampler(clean,org,k,flip=flip,rot=rot),R)
    T=flatten(T,28,0.62)
    m1=ndi.gaussian_filter(T,(2.5,2.5,0),mode='wrap'); m2=ndi.gaussian_filter(T,(9,9,0),mode='wrap')
    # damp the mid band (the raw's regular bump grid) and keep the fine painted grain
    return np.clip(m2+(m1-m2)*0.6+(T-m1)*1.8,0,1)
def match(T,ref):
    m0,s0=ref.reshape(-1,3).mean(0),ref.reshape(-1,3).std(0); m1,s1=T.reshape(-1,3).mean(0),T.reshape(-1,3).std(0)
    return np.clip(m0+(T-m1)*(s0/np.maximum(s1,1e-4)),0,1)
base_s=snow_tex((330,330),K_S)
def stamp(S, st, cu, cv, scale, seed):
    """transfer an item delta (orig-clean) into uv texture S at uv centre (cu,cv); screen-space scale"""
    d=st['d']; h,w=d.shape[:2]
    # target screen size
    tw=max(2,int(round(w/scale*SSu))); th=max(2,int(round(h/scale*SSu)))
    dd=resize_f(np.clip(d+0.5,0,1),tw,th)-0.5
    # place in screen space of a 'virtual' uv texture: map uv grid to screen coords
    X=(UU-VV)*64.0; Y=(UU+VV)*32.0
    cx=(cu-cv)*64.0; cy=(cu+cv)*32.0
    px=(X-cx)*SSu+tw/2; py=(Y-cy)*SSu+th/2
    inside=(px>=0)&(px<tw-1)&(py>=0)&(py<th-1)
    val=bilinear(dd,np.clip(px,0,tw-1.001),np.clip(py,0,th-1.001))
    return np.clip(S+val*inside[...,None],0,1)
SSu=R/90.0   # uv texture px per screen px (R=256 over ~90 px of cell edge)
SNOW={}
tufts=[t for t in stamps if t['kind']=='tuft']; pebs=[t for t in stamps if t['kind']=='pebble']
print('tufts',len(tufts),'pebbles',len(pebs))
specs={'a':(11,(420,250),False,[]),'b':(22,(900,420),True,[]),
       'c':(33,(250,520),False,[('t',2)]),'d':(44,(1000,300),True,[('p',4)])}
for k,(seed,org,flip,items) in specs.items():
    r=rng(seed)
    var=match(snow_tex(org,K_S*r.uniform(0.95,1.05),flip,r.uniform(-0.10,0.10)),base_s)
    S=var_blend(base_s,var,MINT_S)
    S=snow_grade(S)
    for j,(kind,idx) in enumerate(items):
        st=(pebs if kind=='p' else tufts)[idx%len(pebs if kind=='p' else tufts)]
        cu,cv=r.uniform(0.34,0.66,2)
        S=stamp(S,st,cu,cv,K_S*(1.25 if kind=='t' else 1.4),seed+j)
    SNOW[k]=S
    finish(render_uv(SNOW[k]),OUTK,'snow_'+k)
base_s_g=snow_grade(base_s)

# ================= FROST GRASS =================
fg=load('frost_grass_swatch.jpg')
K_F=2.7
def frost_grade(rgb):
    # still reads as grass: a little more green saturation, frost whites capped so they do not glare
    l=lum(rgb)[...,None]
    out=l+(rgb-l)*1.22
    out=np.clip(out*0.98,0,1)**1.03
    # look target (Crosshaven plate): grass leans yellow-green / hay, frost is neutral-cool white, not mint/cyan
    g=smoothstep(0.02,0.10,out[...,1]-out[...,2])[...,None]
    out=out*(1+g*np.array([0.10,0.02,-0.20]))
    l2=lum(out)[...,None]; sat=(out.max(-1)-out.min(-1))[...,None]
    wh=smoothstep(0.66,0.82,l2)*smoothstep(0.16,0.06,sat)
    out=out*(1-wh*0.6)+(l2*np.array([0.975,0.99,1.0]))*wh*0.6
    # blue-dominant frost tufts -> neutral cool grey (plate: no cyan/turquoise accents in the grass)
    bl=smoothstep(0.0,0.08,out[...,2]-out[...,1])[...,None]
    l3=lum(out)[...,None]
    out=out*(1-bl*0.92)+(l3*np.array([1.0,0.995,0.99]))*bl*0.92
    # cyan-grey frost tufts (g~b>r) read as blue dots next to hay grass -> pale straw-white frost
    cy=smoothstep(0.0,0.05,np.minimum(out[...,1],out[...,2])-out[...,0])[...,None]
    l4=lum(out)[...,None]
    out=out*(1-cy*0.9)+(l4*np.array([1.02,1.0,0.94]))*cy*0.9
    return np.clip(np.minimum(out,0.95),0,1)
base_f=flatten(make_periodic(src_sampler(fg,(640,360),K_F),R),30,0.55)
FROST={}
fspecs={'a':(101,(300,220),False,0.6),'b':(202,(900,480),True,1.0),'c':(303,(520,560),False,-0.8),'d':(404,(1050,200),True,0.3)}
for k,(seed,org,flip,tone) in fspecs.items():
    r=rng(seed)
    var=flatten(make_periodic(src_sampler(fg,org,K_F*r.uniform(0.94,1.06),flip=flip,rot=r.uniform(-0.12,0.12)),R),30,0.55)
    S=var_blend(base_f,var,MINT)
    n=smooth_noise((R,R),18,seed+7)
    S=S*(1+tone*0.06*n[...,None]*MINT[...,None])
    FROST[k]=frost_grade(S)
    finish(render_uv(FROST[k]),OUTK,'frost_grass_'+k)
base_f_g=frost_grade(base_f)

# ================= SNOW PATCH v2 (painted raw v2/snow_patch_swatch.jpg) =================
# the common snowy tile: frost grass with soft painted snow patches (~25-40%). The swatch is made seamless (offset + heal
# with a min-error seam cut in x and y), four different diamond crops are graded (grass hue between frost_grass and
# golden_plains, snow neutral-cool), and the border band is the shared frost_grass band so snow_patch_* mixes freely
# with frost_grass_* and uses the frost_grass edges / corners.
import colorsys
SW=np.asarray(Image.open(RAW+'v2/snow_patch_swatch.jpg').convert('RGB'),dtype=np.float32)/255.0
def seamless(img,ov=96):
    h,w,_=img.shape
    a=periodic_strip(img,0,w-ov,ov)                       # tiles in x
    b=periodic_strip(np.ascontiguousarray(a.transpose(1,0,2)),0,h-ov,ov).transpose(1,0,2)   # and in y
    return np.ascontiguousarray(b)
SWS=seamless(SW)
Image.fromarray((SWS*255).astype(np.uint8)).save(B+'tmp/v2/snow_patch_swatch_seamless.png')
def sp_grade(rgb):
    L=lum(rgb); sat=rgb.max(-1)-rgb.min(-1)
    snow=smoothstep(0.70,0.84,L)*smoothstep(0.16,0.07,sat)
    hsv=cv2.cvtColor(rgb.astype(np.float32),cv2.COLOR_RGB2HSV)       # H in degrees
    # grass: hay-gold (h~43deg) -> between frost_grass (67deg) and golden_plains (70deg), keeping some hay warmth
    hsv[...,0]=hsv[...,0]+(60.0-43.0)*(1-snow)
    hsv[...,1]=hsv[...,1]*(0.92-0.25*snow)
    g=cv2.cvtColor(hsv,cv2.COLOR_HSV2RGB)
    l2=lum(g)[...,None]
    sn=np.clip(l2+(g-l2)*0.35,0,1)*np.array([0.985,0.992,1.0])     # snow: neutral-cool, not cream
    out=g*(1-snow[...,None])+sn*snow[...,None]
    return np.clip(out,0,0.975),snow
SWG,SNOWM=sp_grade(SWS)
# match the swatch grass to the frost_grass band (mean/std per channel on grass pixels) so the shared band does not
# read as a lattice; hue lands between frost_grass and golden_plains
_gw=(1-SNOWM)>0.9
_fm=base_f_g.reshape(-1,3); _fs=_fm.std(0); _fmu=_fm.mean(0)
_sm=SWG[_gw]; _smu=_sm.mean(0); _ss=_sm.std(0)
_matched=np.clip(_fmu+(SWG-_smu)*(_fs/np.maximum(_ss,1e-4))*0.9,0,1)
_w=(1-SNOWM)[...,None]
SWG=np.clip(SWG*(1-_w*0.75)+_matched*_w*0.75,0,0.975)
Kp=6.4
hS,wS=SWS.shape[:2]
def crop_uv(org):
    f=src_sampler(np.concatenate([SWG,SNOWM[...,None]],2),org,Kp)
    u=(np.arange(R)+0.5)/R; Uu,Vv=np.meshgrid(u,u)
    x,y=uv_to_screen(Uu,Vv)
    sx=np.mod(org[0]+x*Kp,wS-1); sy=np.mod(org[1]+y*Kp,hS-1)
    return bilinear(np.concatenate([SWG,SNOWM[...,None]],2),sx,sy,wrap=True)
# border band: frost grass (shared). irregular, noisy transition so it is not a clean diamond
nb=smooth_noise((R,R),14,77)
MB=smoothstep(0.03,0.14,DE+0.03*nb)
# choose four crops: final cover 25-40%, little snow cut by the band
cands=[]
r0=rng(5150)
for k in range(700):
    org=(float(r0.uniform(0,wS)),float(r0.uniform(0,hS)))
    C=crop_uv(org); sm=C[...,3]
    cov_in=float((sm*MB).mean()/MB.mean()); cut=float((sm*(1-MB)).mean()/(1-MB).mean())
    final=float(down(render_uv(np.repeat((sm*MB)[...,None],3,2)))[...,0][MASK].mean()) if False else None
    cands.append((org,cov_in,cut))
def final_cov(org):
    C=crop_uv(org); fin=render_uv(np.repeat((C[...,3]*MB)[...,None],3,2))[...,0]
    return float((fin[MASK]>0.5).mean())
good=[c for c in cands if 0.26<=c[1]<=0.48]
def nblobs(org):
    C=crop_uv(org); m=(render_uv(np.repeat((C[...,3]*MB)[...,None],3,2))[...,0]>0.5)&MASK
    lab,n=ndi.label(m); sz=ndi.sum(m,lab,range(1,n+1)); return int((np.array(sz)>40).sum()) if n else 0
good=[(c[0],c[1],c[2],nblobs(c[0])) for c in good]
good=[c for c in good if 1<=c[3]<=6]
good.sort(key=lambda c:(-min(c[3],3),abs(c[1]-0.40)))
chosen=[]
for c in good:
    if all(math.hypot(c[0][0]-o[0][0],c[0][1]-o[0][1])>150 for o in chosen):
        fc=final_cov(c[0])
        if 0.25<=fc<=0.40: chosen.append((c[0],fc))
    if len(chosen)==4: break
print('snow_patch v2 crops',[(tuple(round(v) for v in o),round(fc,3)) for o,fc in chosen])
PATCH_COV={}
for k,(org,fc) in zip('abcd',chosen):
    C=crop_uv(org)
    S=base_f_g*(1-MB[...,None])+C[...,:3]*MB[...,None]
    rgb=render_uv(S)
    PATCH_COV[k]=fc
    finish(rgb,OUTK,'snow_patch_'+k)
json.dump(dict(cov=PATCH_COV,crops={k:list(o) for k,(o,_) in zip('abcd',chosen)},K=Kp),open('tmp/patch_cov.json','w'))
print('snow_patch coverage',PATCH_COV)

# ================= SNOW ROCK + CRAG TOPS (granite poking through snow) =================
from rocks import paint_rocks
Ui,Vi=U,V
# keep rocks well inside the cell so the shared snow border band stays identical (seamless)
yy,xx=np.mgrid[0:64*SS,0:128*SS].astype(np.float32)
dd=(1-(np.abs((xx+0.5)/SS-64)/64+np.abs((yy+0.5)/SS-32)/32))*32   # px to the diamond edge (2x)
INSIDE=smoothstep(5.0,9.0,dd)
def snow_ss(S): return sample_uv(S,np.mod(U,1),np.mod(V,1))
rock_specs={'snow_rock_a':(501,SNOW['a'],[(52,30,15,8),(80,40,9,5)],0.55),
            'snow_rock_b':(502,SNOW['c'],[(70,26,17,9),(46,40,8,4.5),(88,44,6,3.5)],0.5),
            'crag_a':(503,SNOW['b'],[(44,30,12,6.5),(56,38,6,3.2)],0.45),
            'crag_b':(504,SNOW['a'],[(76,24,11,6),(62,40,7,3.8)],0.45),
            'crag_c':(505,SNOW['b'],[(82,34,17,8.5)],0.42)}
ROCKM={}
for nm,(seed,S,rk,cap) in rock_specs.items():
    rgb_ss,m=paint_rocks(snow_ss(S),rk,seed,ss=SS,snow_cap=cap-0.25,keep_inside=INSIDE)
    finish(down(rgb_ss),OUTK,nm)
    ROCKM[nm]=float(down(m[...,None])[...,0].mean()/ALPHA.mean())
print('rock cover', ROCKM)
np.savez('tmp/tex.npz',snow_base=base_s_g,frost_base=base_f_g,**{'snow_'+k:v for k,v in SNOW.items()},**{'frost_'+k:v for k,v in FROST.items()})
print('ground done')
