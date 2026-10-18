import sys; sys.path.insert(0,'/workspace/stasium-pc-look/ship/lakes_v1/src'); from clean import *
from PIL import ImageFilter, ImageEnhance, ImageDraw
from scipy import ndimage
import random, math
R='/workspace/stasium-pc-look/ship/lakes_v1/'; PC='/workspace/stasium-pc-look/ship/map_polish_2/gamescale/pieces/'
def dist(cap,O,cx,cy,rx,ry,seed,x0,x1,y0,y1):
    img,cl,tx,ty,rect=clean(cap,np.array(O),x0,x1,y0,y1)
    ang=np.arctan2((ty-cy)/ry,(tx-cx)/rx); rr=np.sqrt(((tx-cx)/rx)**2+((ty-cy)/ry)**2)
    return ((1+.07*np.sin(3*ang+seed)+.05*np.sin(5*ang+2*seed))-rr)*min(rx,ry),tx,ty
def nz(H,W,s,seed):
    n=ndimage.gaussian_filter(np.random.default_rng(seed).random((H,W)),s); return (n-n.min())/(n.max()-n.min())
def crisp(a,d,reach=7):
    im=Image.fromarray(np.clip(a,0,255).astype(np.uint8))
    s=im.filter(ImageFilter.UnsharpMask(1.0,90,2)).filter(ImageFilter.UnsharpMask(0.6,60,1)); s=ImageEnhance.Color(s).enhance(1.18); s=ImageEnhance.Contrast(s).enhance(1.08)
    w=np.clip((d+reach)/2,0,1)[...,None]; return a*(1-w)+np.array(s).astype(float)*w
def sbs(v1,out,box,path,label):
    W,H=v1.size; c=Image.new('RGB',(W*2+8,H+380),(16,16,20)); c.paste(v1,(0,0)); c.paste(out,(W+8,0))
    bw=box[2]-box[0]; bh=box[3]-box[1]
    for i,im in enumerate((v1,out)): c.paste(im.crop(box).resize((W,int(W*bh/bw))).crop((0,0,W,380)),(i*(W+8),H))
    dr=ImageDraw.Draw(c); dr.text((12,12),'BEFORE',fill='white'); dr.text((W+20,12),label,fill='white'); c.save(path); return c
