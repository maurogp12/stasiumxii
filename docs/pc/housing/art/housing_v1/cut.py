import cv2, numpy as np, glob
from PIL import Image, ImageDraw, ImageFilter
A='/home/box/agent-data/agents/ce4006dd-4e98-48dd-b991-fa7565b86bf2/assets/'
O='/workspace/stasium-pc-look/ship/housing_v1/'
def load(p): return np.array(Image.open(glob.glob(A+p+'*.jpg')[0]).convert('RGB'))
def bgmask(a):
    f=a.astype(int); d=np.abs(f-199).max(2); s=f.max(2)-f.min(2)
    bg=((d<22)&(s<12)).astype(np.uint8)
    # flood from border: background = connected-to-border bg
    n,lab=cv2.connectedComponents(bg)
    border=set(np.unique(np.r_[lab[0],lab[-1],lab[:,0],lab[:,-1]]))-{0}
    m=np.isin(lab,list(border))
    st=np.bincount(lab.ravel())
    big=[i for i in range(1,n) if st[i]>250]
    m|=np.isin(lab,big)
    fg=(~m).astype(np.uint8)*255
    fg=cv2.morphologyEx(fg,cv2.MORPH_OPEN,np.ones((3,3),np.uint8))
    # keep components > 200px
    n,lab,st,_=cv2.connectedComponentsWithStats(fg)
    keep=np.zeros_like(fg)
    for i in range(1,n):
        if st[i,4]>200: keep[lab==i]=255
    return keep
def feather(alpha,r=1.2):
    a=cv2.erode(alpha,np.ones((2,2),np.uint8))
    return cv2.GaussianBlur(a,(0,0),r)
def decontam(rgb,alpha):
    # remove grey fringe: unpremultiply against bg 199
    f=rgb.astype(float); al=np.clip(alpha/255.0,0.05,1)[...,None]
    out=(f-199*(1-al))/al
    edge=(alpha<250)[...,None]
    return np.where(edge,np.clip(out,0,255),f).astype(np.uint8)
def rgba(rgb,alpha):
    return Image.fromarray(np.dstack([decontam(rgb,alpha),alpha]))
def trim(im):
    a=np.array(im.getchannel('A')); n,lab,st,_=cv2.connectedComponentsWithStats((a>8).astype(np.uint8))
    if n>2:
        big=1+np.argmax(st[1:,4]); keep=np.isin(lab,[i for i in range(1,n) if st[i,4]>0.05*st[big,4]])
        a=np.where(keep,a,0).astype(np.uint8); im=im.copy(); im.putalpha(Image.fromarray(a))
    return im.crop(im.getchannel('A').point(lambda v:255 if v>8 else 0).getbbox())
def icon(im,s):
    pad=int(s*0.1); w,h=im.size; k=(s-2*pad)/max(w,h)
    r=im.resize((max(1,round(w*k)),max(1,round(h*k))),Image.LANCZOS)
    c=Image.new('RGBA',(s,s),(0,0,0,0)); c.paste(r,((s-r.width)//2,(s-r.height)//2),r); return c
def world(im,name):
    im=trim(im); w,h=im.size; W=w+(w%2)+8; c=Image.new('RGBA',(W,h+4),(0,0,0,0))
    c.paste(im,((W-w)//2,0),im); c.save(O+f'resources/res_{name}_world.png'); return c
src=load('589bcb72'); full_bg=bgmask(src)
items={}
boxes={'stone':(300,85,475,235),'bricks':(530,60,720,220),'thatch':(785,65,960,245),
       'rope':(180,255,340,395),'nails':(960,240,1120,365)}
for n,(x0,y0,x1,y1) in boxes.items():
    a=feather(full_bg[y0:y1,x0:x1]); items[n]=trim(rgba(src[y0:y1,x0:x1],a))
def polycut(ox,oy,pts,name):
    P=[(ox+x/3,oy+y/3) for x,y in pts]
    m=Image.new('L',(1280,720),0); ImageDraw.Draw(m).polygon(P,fill=255)
    a=feather(np.array(m),1.0)
    return trim(rgba(src,a))
items['planks']=polycut(300,380,[(78,92),(120,58),(160,38),(250,95),(420,215),(440,240),(345,285),(250,245),(150,195),(110,165),(80,120)],'planks')
items['log']=polycut(580,470,[(58,200),(80,180),(440,35),(480,33),(500,55),(507,115),(470,142),(140,300),(100,306),(66,282),(55,240)],'log')
for n,im in items.items():
    icon(im,64).save(O+f'resources/res_{n}_icon_64.png'); icon(im,128).save(O+f'resources/res_{n}_icon_128.png'); world(im,n)
# stages
def blank_sign(a,quad,mode):
    if mode=='inpaint':
        m=Image.new('L',(1280,720),0); ImageDraw.Draw(m).polygon(quad,fill=255)
        q=np.array(m)>0; lum=a.mean(2); t=((lum>150)&q).astype(np.uint8)*255
        t=cv2.dilate(t,np.ones((5,5),np.uint8))
        return cv2.inpaint(a,t,6,cv2.INPAINT_TELEA)
    else:
        m=Image.new('L',(1280,720),0); ImageDraw.Draw(m).polygon(quad,fill=255)
        q=np.array(m)>0
        (x0,y0),(x1,y1)=quad[0],quad[1]; ang=(y1-y0)/(x1-x0)
        Y,X=np.mgrid[0:720,0:1280]; v=Y-ang*X
        rng=np.random.default_rng(3)
        grain=np.sin(v*0.9)*6+np.sin(v*0.23+np.sin(X*0.05)*1.5)*10+rng.normal(0,4,v.shape)
        base=np.array([128,84,48],float)
        wood=np.clip(base[None,None,:]*(1+grain[...,None]/120),0,255)
        out=a.copy().astype(float); out[q]=wood[q]
        mm=cv2.GaussianBlur(q.astype(np.uint8)*255,(0,0),1.0)/255.0
        return (a*(1-mm[...,None])+out*mm[...,None]).astype(np.uint8)
stg={'stage2_foundation':('1a4765fc',None),
     'stage3_frame':('a5dd093e',([(480+95/3,260+90/3),(480+455/3,260+205/3),(480+452/3,260+300/3),(480+92/3,260+185/3)],'inpaint')),
     'stage4_house':('33e5ae17',([(490+76/3,320+80/3),(490+464/3,320+238/3),(490+458/3,320+326/3),(490+70/3,320+168/3)],'wood'))}
for n,(p,s) in stg.items():
    a=load(p); al=feather(bgmask(a))
    if s: a=blank_sign(a,s[0],s[1])
    im=trim(rgba(a,al)); w,h=im.size; W=w+(w%2)
    c=Image.new('RGBA',(W,h),(0,0,0,0)); c.paste(im,(0,0),im); c.save(O+f'stages/{n}.png')
    c.resize((W//2,h//2),Image.LANCZOS).save(O+f'stages/{n}_half.png')
# preview
pv=Image.new('RGBA',(1280,720),(46,40,34,255)); d=ImageDraw.Draw(pv)
d.text((24,16),'STASIUM XII - Player housing v1 (PROPOSED)',fill=(240,225,190))
names=['log','planks','stone','bricks','thatch','rope','nails']
for i,n in enumerate(names):
    x=40+i*170; d.rounded_rectangle((x,44,x+140,184),12,fill=(70,60,50),outline=(140,115,80))
    ic=Image.open(O+f'resources/res_{n}_icon_128.png'); pv.paste(ic,(x+6,50),ic); d.text((x+50,170),n,fill=(240,225,190))
xs=[30,450,870]
for i,n in enumerate(stg):
    im=Image.open(O+f'stages/{n}.png'); k=min(380/im.width,480/im.height); im=im.resize((int(im.width*k),int(im.height*k)),Image.LANCZOS)
    pv.paste(im,(xs[i]+(380-im.width)//2,210+(480-im.height)//2),im); d.text((xs[i]+150,700),n,fill=(240,225,190))
for ax in (415,835):
    d.polygon([(ax,440),(ax+24,440),(ax+24,428),(ax+36,450),(ax+24,472),(ax+24,460),(ax,460)],fill=(230,190,90))
pv.convert('RGB').save(O+'preview_1280x720.png')
