import numpy as np, json
from PIL import Image, ImageDraw, ImageFont
R='/workspace/crosshaven_paint/work/tilekit/'
PR=['grass','dirt','cobble','plaza','water']
AT={t:Image.open(R+f'ground/{t}_atlas_CONCEPTO.png') for t in PR}
VAR={t:Image.open(R+f'ground/{t}_full_variants_CONCEPTO.png') for t in PR[:4]}
def T(t,m): a=AT[t]; return a.crop(((m%4)*128,(m//4)*64,(m%4)*128+128,(m//4)*64+64))
def ground(V,ox,oy,W,H,seed=0):
    rng=np.random.default_rng(seed); img=Image.new('RGBA',(W,H),(150,190,70,255))
    n=V.shape[0]-1
    for p,t in enumerate(PR):
        for i in range(n):
            for j in range(V.shape[1]-1):
                c=[V[i,j],V[i+1,j],V[i+1,j+1],V[i,j+1]]
                m=sum(((c[k]>=p)<<k) for k in range(4))
                if m==0: continue
                x=(i-j)*64+ox; y=(i+j)*32+oy
                if x<-128 or y<-64 or x>W or y>H: continue
                tl=T(t,m)
                if m==15 and t in VAR:
                    vi=rng.integers(0,3); tl=VAR[t].crop((vi*128,0,vi*128+128,64))
                img.alpha_composite(tl,(int(x),int(y)))
    return img
HERO=None
def hero():
    global HERO
    if HERO is None:
        HERO=Image.open(R+'raw/hero_scale_CONCEPTO.png')
        HERO=HERO.resize((round(HERO.width*156/HERO.height),156),Image.LANCZOS)
    return HERO
def piece(name,sub='walls'):
    im=Image.open(R+f'{sub}/{name}_CONCEPTO.png'); m=json.load(open(R+f'{sub}/{name}_CONCEPTO.json')); return im,m
def put(img,name,fx,fy,sub='walls'):
    im,m=piece(name,sub); img.alpha_composite(im,(int(fx-m['foot'][0]),int(fy-m['foot'][1]))); return m
def put_hero(img,x,y):
    h=hero(); sh=Image.new('RGBA',img.size); d=ImageDraw.Draw(sh); d.ellipse((x-34+6,y-10,x+34+6,y+8),fill=(0,0,0,70)); img.alpha_composite(sh)
    img.alpha_composite(h,(int(x-h.width/2),int(y-h.height)))
def font(s):
    try: return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',s)
    except: return ImageFont.load_default()
HDR='IMAGEN / CONCEPTO, TODAVÍA HAY QUE CONSTRUIRLO'
