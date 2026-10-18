import numpy as np, json
from PIL import Image, ImageFilter
R='/workspace/crosshaven_paint/work/tilekit/'; RAW=R+'raw/'
N=256; ZOOM={'cobble':0.45,'plaza':0.55,'grass':0.6,'dirt':0.6,'water':0.6}; SS=2; TW,TH=128,64
def seamless(path,crop=None,seed=0):
    im=Image.open(path).convert('RGB'); w,h=im.size; c=min(w,h)
    c=int(c*ZOOM.get(path.split('tex_')[1][:-4],1)); x0=(w-c)//2+seed*37%max(1,(w-c)); im=im.crop((x0,0,x0+c,c)).resize((N,N),Image.LANCZOS)
    a=np.asarray(im).astype(float); r=np.roll(np.roll(a,N//2,0),N//2,1)
    t=np.linspace(0,1,N); d=np.minimum(t,1-t)*2; m=np.clip(np.minimum.outer(d,d)*3,0,1)[...,None]
    return a*m+r*(1-m)
def pnoise(seed,cells=4):
    g=np.random.default_rng(seed).random((cells,cells))
    big=np.asarray(Image.fromarray((np.tile(g,(3,3))*255).astype(np.uint8)).resize((N*3,N*3),Image.BICUBIC)).astype(float)/255
    return big[N:2*N,N:2*N]
noise=(pnoise(1,3)-0.5)*0.45+(pnoise(2,6)-0.5)*0.22+(pnoise(5,12)-0.5)*0.08
def uvgrid():
    py,px=np.mgrid[0:TH*SS,0:TW*SS]/SS+0.5/SS
    u=(py/32+(px-64)/64)/2; v=(py/32-(px-64)/64)/2
    inside=(u>=0)&(u<=1)&(v>=0)&(v<=1)
    return u,v,inside
U,V,INS=uvgrid()
def samp(T,u,v):
    iu=(np.mod(u,1)*N).astype(int)%N; iv=(np.mod(v,1)*N).astype(int)%N
    return T[iv,iu] if T.ndim==2 else T[iv,iu]
def tile(T,mask,bank=None,extra=None):
    cN,cE,cS,cW=[(mask>>i)&1 for i in range(4)]
    w=cN*(1-U)*(1-V)+cE*U*(1-V)+cW*(1-U)*V+cS*U*V
    if 0<mask<15: w=w+samp(noise,U,V)*np.minimum(1, 4*np.minimum(np.minimum(U,1-U),np.minimum(V,1-V))+0.6)
    col=samp(T,U,V).copy()
    if extra is not None: col=extra(col)
    al=np.clip((w-0.47)/0.06,0,1)
    if bank is not None:
        bw=np.clip((w-0.62)/0.04,0,1)[...,None]; col=bank*(1-bw)+col*bw
        # inner rim shade
    al=al*INS
    rgba=np.dstack([col.clip(0,255),al*255]).astype(np.uint8)
    return Image.fromarray(rgba,'RGBA').resize((TW,TH),Image.LANCZOS)
def atlas(T,bank=None,extra=None):
    A=Image.new('RGBA',(TW*4,TH*4))
    for m in range(16): A.alpha_composite(tile(T,m,bank,extra),((m%4)*TW,(m//4)*TH))
    return A
terr={}
for nm in ['grass','dirt','cobble','plaza','water']:
    terr[nm]=seamless(RAW+f'tex_{nm}.jpg')
# a shade gradient for depth on grass/dirt? keep flat.
meta={"tile":[TW,TH],"layout":"4x4, index=mask, N=1 E=2 S=4 W=8, set corner = this terrain, unset = transparent","draw_priority":["grass","dirt","cobble","plaza","water"]}
for nm in ['grass','dirt','cobble','plaza']:
    T=terr[nm]; atlas(T).save(R+f'ground/{nm}_atlas_CONCEPTO.png')
    # variants of full tile: blend alternate seamless crop in interior only
    T2=seamless(RAW+f'tex_{nm}.jpg',seed=3); T2=np.roll(T2,(91,57),(0,1))
    vs=Image.new('RGBA',(TW*3,TH))
    for i in range(3):
        if i==0: Ti=T
        else:
            Tb=np.roll(T2,(i*61,i*29),(0,1))
            yy,xx=np.mgrid[0:N,0:N]/N; d=np.minimum(np.minimum(xx,1-xx),np.minimum(yy,1-yy))
            m=np.clip((d-0.12)/0.15,0,1)[...,None]; Ti=T*(1-m)+Tb*m
        vs.alpha_composite(tile(Ti,15),(i*TW,0))
    vs.save(R+f'ground/{nm}_full_variants_CONCEPTO.png')
    json.dump(dict(meta,terrain=nm,variants_file=f"{nm}_full_variants_CONCEPTO.png",variants=3),open(R+f'ground/{nm}_atlas_CONCEPTO.json','w'),indent=1)
# water: animated, with stone bank
bankT=terr['plaza']*0.82
W0=terr['water']; FR=6
frames=[]
for k in range(FR):
    def ex(col,k=k):
        a=samp(W0,U+k/FR,V); b=samp(W0,U-k/FR*1.0+0.37,V+0.21)
        return a*0.6+b*0.4
    frames.append(atlas(W0,bank=samp(bankT,U,V),extra=ex))
frames[0].save(R+'ground/water_atlas_CONCEPTO.png')
st=Image.new('RGBA',(TW*4*FR,TH*4))
for i,f in enumerate(frames): st.alpha_composite(f,(i*TW*4,0))
st.save(R+'ground/water_atlas_anim_CONCEPTO.png')
json.dump(dict(meta,terrain="water",bank="stone bank band built into the edge tiles (outer ~15% of the water area)",anim_file="water_atlas_anim_CONCEPTO.png",frames=FR,fps=8,anim_layout="6 full atlases side by side, 512x256 each"),open(R+'ground/water_atlas_CONCEPTO.json','w'),indent=1)
print('ok')
