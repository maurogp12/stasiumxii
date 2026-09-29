# Ironjaw sprites from Mauro's "Berserker A" concept sheet (29 Sep 2026).
# Step 1: cut the front / back / side views, chibi proportions, finish, fit 144x160.
# Writes out/ironjaw_{s,e,n,w}.png (+ cut_*/big_* intermediates).
# Run: python3 build_tools/art/ironjaw_berserker/make_sprites.py, then gen_game_art.py.
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance, ImageOps
from scipy import ndimage as ndi
import os
HERE=os.path.dirname(os.path.abspath(__file__))
SRC=os.path.join(HERE,'berserker_a_sheet.png')
OUT=os.path.join(HERE,'out')+'/'
os.makedirs(OUT,exist_ok=True)
src=Image.open(SRC).convert('RGB')
A=np.asarray(src).astype(np.float32)
LUM=A.max(axis=2)
VIEWS={'front':(12,52,500,690),'back':(512,50,716,472),'side':(722,50,962,460)}
# head/neck split (fraction of figure height from top) per view, found by eye
NECK={'front':0.17,'back':0.125,'side':0.14}
HEAD_SCALE=2.0
BODY_SCALE=0.62
BODY_WIDEN=1.18

def cut(name):
    x0,y0,x1,y1=VIEWS[name]
    rgb=A[y0:y1,x0:x1].copy(); lum=LUM[y0:y1,x0:x1].copy()
    if name=='front':
        # 'VARIANT: HELM' caption (left of the helm) and its thin rule, which
        # crosses the helm spikes: drop rule pixels with no metal above/below.
        lum[:24,:180]=0
        for c in range(180,254):
            for r in range(8,18):
                if lum[r,c]>5 and lum[max(r-4,0),c]<=20 and lum[min(r+4,lum.shape[0]-1),c]<=20:
                    lum[r,c]=0
    fg=lum>5
    # background = dark pixels connected to the crop border
    bgc=~fg
    lab,n=ndi.label(bgc)
    border=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
    bg=np.isin(lab,list(border))
    mask=~bg
    # keep big components only
    lab2,n2=ndi.label(mask)
    sizes=ndi.sum(mask,lab2,range(1,n2+1))
    keep=[i+1 for i,s in enumerate(sizes) if s>0.02*sizes.max()]
    mask=np.isin(lab2,keep)
    mask=ndi.binary_opening(mask,iterations=1)
    mask=ndi.binary_fill_holes(mask)
    ys,xs=np.where(mask)
    rgb=rgb[ys.min():ys.max()+1, xs.min():xs.max()+1]
    mask=mask[ys.min():ys.max()+1, xs.min():xs.max()+1]
    alpha=(mask*255).astype(np.uint8)
    im=Image.fromarray(np.dstack([rgb.astype(np.uint8),alpha]),'RGBA')
    return im

def chibi(im,name):
    w,h=im.size
    ny=int(h*NECK[name])
    head=im.crop((0,0,w,ny)); body=im.crop((0,ny,w,h))
    # neck centre x from mask row
    a=np.asarray(im)[:,:,3]
    row=np.where(a[ny]>0)[0]
    cx=int(row.mean()) if len(row) else w//2
    hw,hh=int(w*HEAD_SCALE),int(ny*HEAD_SCALE)
    head=head.resize((hw,hh),Image.LANCZOS)
    bh=int((h-ny)*BODY_SCALE)
    bw=int(w*BODY_WIDEN)
    body=body.resize((bw,bh),Image.LANCZOS)
    cx_b=int(cx*BODY_WIDEN)
    W=max(bw,hw)+40; H=hh+bh
    out=Image.new('RGBA',(W,H),(0,0,0,0))
    off=(W-bw)//2
    out.alpha_composite(body,(off,hh-int(hh*0.1)))
    hx=off+cx_b-int(cx*HEAD_SCALE)
    out.alpha_composite(head,(hx,0))
    return out.crop(out.getbbox())

def style(im):
    a=im.getchannel('A')
    rgb=im.convert('RGB').filter(ImageFilter.MedianFilter(3))
    arr=np.asarray(rgb).astype(np.float32)/255
    arr=np.power(arr,0.7)                     # lift the darks
    img=Image.fromarray((arr*255).clip(0,255).astype(np.uint8))
    img=ImageEnhance.Contrast(img).enhance(1.25)
    img=ImageEnhance.Color(img).enhance(1.15)
    arr=np.asarray(img).astype(np.float32)
    r,g,b=arr[...,0],arr[...,1],arr[...,2]
    redish=(r>g*1.15)&(r>b*1.1)
    arr[...,0]=np.where(redish,np.minimum(r*1.05,255),r); arr[...,1]=np.where(redish,g*0.8,g); arr[...,2]=np.where(redish,b*0.8,b)   # cape weathering reads crimson
    # cool steel tint on the neutral greys
    grey=(np.abs(r-g)<12)&(np.abs(g-b)<12)
    arr[...,2]=np.where(grey,np.minimum(b*1.06,255),b)
    img=Image.fromarray(arr.clip(0,255).astype(np.uint8))
    img=img.filter(ImageFilter.UnsharpMask(radius=3,percent=60,threshold=3))
    img.putalpha(a)
    return img

def fit(im, max_h=144, max_w=136):
    w,h=im.size
    s=min(max_h/h,max_w/w)
    im=im.resize((max(1,int(w*s)),max(1,int(h*s))),Image.LANCZOS)
    # clean alpha edge, then ink outline
    a=np.asarray(im.getchannel('A')).astype(np.float32)
    a=np.where(a>110,255,0).astype(np.uint8)
    rgba=np.asarray(im).copy(); rgba[...,3]=a
    im=Image.fromarray(rgba,'RGBA')
    canvas=Image.new('RGBA',(144,160),(0,0,0,0))
    x=(144-im.width)//2; y=150-im.height
    canvas.alpha_composite(im,(x,y))
    al=np.asarray(canvas.getchannel('A'))>0
    ring=ndi.binary_dilation(al,iterations=1)&~al
    c=np.asarray(canvas).copy()
    c[ring]=[22,14,12,255]
    return Image.fromarray(c,'RGBA')

res={}
for name in VIEWS:
    im=cut(name); im.save(OUT+f'cut_{name}.png')
    ch=chibi(im,name)
    st=style(ch)
    res[name]=fit(st)
    st.save(OUT+f'big_{name}.png')
res['front'].save(OUT+'ironjaw_s.png')
res['back'].save(OUT+'ironjaw_n.png')
res['side'].save(OUT+'ironjaw_w.png')
ImageOps.mirror(res['side']).save(OUT+'ironjaw_e.png')
print('ok')
