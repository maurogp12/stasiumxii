import sys, os, json, math
sys.path.insert(0,'/workspace/scratch/l9_build')
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi
import cv2
import common as L9
from common import (smooth_noise, bilinear, tile_uv, diamond_alpha, down, make_periodic, sample_uv,
                    to_rgba8, grade, resize_f, rng, hexc, KEY, SHADE, SS)
RAW='/workspace/stasium-pc-look/raw/outskirts_themes/northgate/'
SHIP='/workspace/stasium-pc-look/ship/outskirts_themes/northgate/'
PREV='/workspace/stasium-pc-look/previews/outskirts_themes/northgate/'
REPO='/workspace/scratch/ng_build/repo/'
B='/workspace/scratch/ng_build/'
R=256
def load(f):
    return np.asarray(Image.open(RAW+f).convert('RGB'),dtype=np.float32)/255.0
def loadrgba(p):
    return np.asarray(Image.open(p).convert('RGBA'),dtype=np.float32)/255.0
def smoothstep(a,b,x):
    t=np.clip((x-a)/(b-a),0,1); return t*t*(3-2*t)
def lum(c): return (c*np.array([0.2126,0.7152,0.0722])).sum(-1)

def half_rgba(arr8):
    """premultiplied LANCZOS half (L9 save_pair); exact (w+1)//2"""
    h,w=arr8.shape[:2]
    f=arr8.astype(np.float32)/255
    pm=f.copy(); pm[...,:3]*=pm[...,3:4]
    W2,H2=(w+1)//2,(h+1)//2
    im=[Image.fromarray(pm[...,i]).resize((W2,H2),Image.LANCZOS) for i in range(4)]
    s=np.clip(np.stack([np.asarray(x) for x in im],-1),0,1)
    a=s[...,3:4]
    rgb=np.where(a>1e-4, s[...,:3]/np.maximum(a,1e-4),0)
    return to_rgba8(rgb,a[...,0])

def save_world(arr8, kind, iid):
    """world-kit layout: <kind>/_2x/<id>.png (2x master) + <kind>/<id>.png (exact half)"""
    assert arr8.shape[0]%2==0 and arr8.shape[1]%2==0, (iid, arr8.shape)
    d2=SHIP+kind+'/_2x/'; d1=SHIP+kind+'/'
    os.makedirs(d2,exist_ok=True)
    Image.fromarray(arr8,'RGBA').save(d2+iid+'.png',optimize=True)
    h1=half_rgba(arr8)
    Image.fromarray(h1,'RGBA').save(d1+iid+'.png',optimize=True)
    return arr8

def over(dst_rgb,dst_a,src_rgb,src_a):
    A=src_a+dst_a*(1-src_a)
    C=np.where(A[...,None]>1e-6,(src_rgb*src_a[...,None]+dst_rgb*(dst_a*(1-src_a))[...,None])/np.maximum(A,1e-6)[...,None],0)
    return C,A

# ---------- chroma key ----------
def key_green(img, protect_interior=False, lo=0.10, hi=0.55, edge_despill_px=3, full_despill=False, key_rows=None):
    """soft matte on a chroma-green sheet. key colour from the border median.
    alpha from distance to key along the key direction + green excess; decontaminate; despill"""
    border=np.concatenate([img[:6].reshape(-1,3),img[-6:].reshape(-1,3),img[:,:6].reshape(-1,3),img[:,-6:].reshape(-1,3)])
    K=np.median(border,0) if key_rows is None else np.median(img[key_rows].reshape(-1,3),0)
    ge=img[...,1]-np.maximum(img[...,0],img[...,2])
    kge=K[1]-max(K[0],K[2])
    t=ge/kge   # 1 = pure key, <=0 = no green excess
    a=1-smoothstep(lo,hi,t)
    # also colour distance (catches dark/olive objects that still have some excess)
    d=np.linalg.norm(img-K,axis=-1)/np.linalg.norm(K)
    a=np.maximum(a,smoothstep(0.55,0.95,d)*(t<0.75))
    if protect_interior:
        bg=a<0.5
        lab,_=ndi.label(bg)
        border_l=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
        if key_rows is not None: border_l=set(np.unique(lab[key_rows]))-{0}
        isbg=np.isin(lab,list(border_l))
        # pixels not connected to the outer key area are object (pines etc.)
        near=ndi.binary_dilation(isbg,iterations=4)
        a=np.where(near,a,1.0)
    a=np.clip(a,0,1)
    # decontaminate: F=(I-(1-a)K)/a
    aa=np.maximum(a,0.05)[...,None]
    F=np.clip((img-(1-a[...,None])*K)/aa,0,1)
    F=np.where(a[...,None]>0.02,F,0)
    # despill
    lim=np.maximum(F[...,0],F[...,2])
    if full_despill:
        F[...,1]=np.minimum(F[...,1],lim+0.01)
    else:
        solid=a>0.98
        dist=ndi.distance_transform_edt(solid)
        zone=(dist<=edge_despill_px)
        F[...,1]=np.where(zone,np.minimum(F[...,1],lim+0.01),F[...,1])
    return F,a,K

def green_fringe_stats(arr8):
    """share of edge pixels (semi alpha + opaque px touching alpha<255) with g > max(r,b)+8"""
    a=arr8[...,3].astype(int); rgb=arr8[...,:3].astype(int)
    semi=(a>8)&(a<247)
    tr=a<128
    ring=(a>=247)&ndi.binary_dilation(tr,iterations=1)
    e=semi|ring
    if e.sum()==0: return 0.0,0
    g=rgb[...,1]-np.maximum(rgb[...,0],rgb[...,2])
    return float(np.mean(g[e]>8)),int(e.sum())

def crop_bbox(rgb,a,th=0.03,pad=0):
    ys,xs=np.nonzero(a>th)
    y0,y1,x0,x1=max(ys.min()-pad,0),ys.max()+1+pad,max(xs.min()-pad,0),xs.max()+1+pad
    return rgb[y0:y1,x0:x1],a[y0:y1,x0:x1]

def scale_rgba(rgb,a,s,sy=None):
    sy=s if sy is None else sy
    h,w=a.shape; W=max(1,int(round(w*s))); H=max(1,int(round(h*sy)))
    pm=np.concatenate([rgb*a[...,None],a[...,None]],2)
    out=resize_f(pm,W,H)
    A=out[...,3]; C=np.where(A[...,None]>1e-4,out[...,:3]/np.maximum(A[...,None],1e-4),0)
    return np.clip(C,0,1),np.clip(A,0,1)

def shear_rgba(rgb,a,k):
    """vertical shear y' = y + k*(x - w/2) ; canvas grows"""
    h,w=a.shape
    extra=int(math.ceil(abs(k)*w/2))+2
    H=h+2*extra
    pm=np.concatenate([rgb*a[...,None],a[...,None]],2).astype(np.float32)
    # inverse map: src y = y' - extra - k*(x-w/2)
    M=np.float32([[1,0,0],[k,1,-k*w/2+extra]])
    out=cv2.warpAffine(pm,M,(w,H),flags=cv2.INTER_CUBIC,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
    out=np.clip(out,0,1)
    A=out[...,3]; C=np.where(A[...,None]>1e-4,out[...,:3]/np.maximum(A[...,None],1e-4),0)
    return np.clip(C,0,1),A

def periodic_strip(src, x0, pw, overlap, y0=None, y1=None):
    """make an image strip of width pw that tiles horizontally: min-error vertical seam cut (image quilting)
    between src[:, x0:x0+overlap] and src[:, x0+pw:x0+pw+overlap]. src: HxWxC float."""
    S=src[y0:y1] if y0 is not None else src
    A=S[:,x0:x0+overlap]; Bb=S[:,x0+pw:x0+pw+overlap]
    err=((A-Bb)**2).sum(-1)
    H,W=err.shape
    cost=err.copy(); back=np.zeros((H,W),int)
    for y in range(1,H):
        for dx in (-1,0,1):
            pass
        prev=cost[y-1]
        l=np.r_[np.inf,prev[:-1]]; r=np.r_[prev[1:],np.inf]
        st=np.stack([l,prev,r]); idx=np.argmin(st,0)
        cost[y]+=st[idx,np.arange(W)]; back[y]=np.arange(W)+idx-1
    seam=np.zeros(H,int); seam[-1]=int(np.argmin(cost[-1]))
    for y in range(H-1,0,-1): seam[y-1]=back[y,seam[y]]
    out=S[:,x0:x0+pw].copy()
    # columns [0,overlap): left of seam take B (continuation of the strip end), right of seam take A
    xx=np.arange(overlap)[None,:]
    w=smoothstep(seam[:,None]-1.5,seam[:,None]+1.5,xx)   # 0 left of seam -> B, 1 right -> A
    out[:,:overlap]=Bb*(1-w[...,None])+A*w[...,None]
    return out

# ---------- look-target grade (Crosshaven plate): warm grey / cliff-white stone, cool-not-blue shade ----------
STONE_DARK=np.array([0.36,0.355,0.365])   # cool-neutral shadow, not blue
STONE_MID=np.array([0.63,0.61,0.57])      # warm grey
STONE_LIT=np.array([0.91,0.89,0.83])      # cliff white
SHADE_N=np.array([0.66,0.67,0.72])        # right/SE face multiplier (cool, barely blue)
def stone_map(rgb, amt=0.85):
    """gradient-map rock pixels onto the plate's stone ramp (pale faces, warm light), keep a little original chroma"""
    l=lum(rgb)
    l2=np.clip(0.18+0.86*np.power(np.clip(l,0,1),0.80),0,1)   # paler rock faces
    t=l2[...,None]
    ramp=np.where(t<0.55,STONE_DARK+(STONE_MID-STONE_DARK)*(t/0.55),STONE_MID+(STONE_LIT-STONE_MID)*np.clip((t-0.55)/0.40,0,1))
    ch=(rgb-l[...,None])*0.25
    return np.clip(rgb*(1-amt)+(ramp+ch)*amt,0,1)
def snowlike_mask(rgb):
    L=lum(rgb); sat=rgb.max(-1)-rgb.min(-1)
    return smoothstep(0.66,0.80,L)*smoothstep(0.20,0.10,sat)
def rock_grade(rgb, amt=0.85):
    """stone_map on rock, leave snow alone"""
    sn=snowlike_mask(rgb)[...,None]
    return rgb*sn+stone_map(rgb,amt)*(1-sn)
