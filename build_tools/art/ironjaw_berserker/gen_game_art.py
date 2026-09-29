# Step 2: game art from out/: static facings, walk / attack / hit / death strips,
# idle plants, packed walk bytes (walk_src/*.pngbin) and the select plate.
# Keeps the strip contracts: feet on row 150, west walk = mirror of east.
# Ironjaw in-game art from Mauro's "Berserker A" sheet (see make.py for the cut + chibi pass).
import numpy as np, sys
from PIL import Image, ImageOps, ImageEnhance, ImageFilter
from scipy import ndimage as ndi
import os
HERE=os.path.dirname(os.path.abspath(__file__))
IJ=os.path.join(HERE,'out')+'/'
R=os.path.abspath(os.path.join(HERE,'..','..','..'))+'/'
CW,CH=144,160
pose={d:Image.open(IJ+f'ironjaw_{d}.png').convert('RGBA') for d in 'senw'}
# facing direction on screen for lunges / knockback
DIR={'e':(1,0),'w':(-1,0),'s':(0,1),'n':(0,-1)}

FOOT=150  # shared plant row (tests: 148..151)

def place(img,dx=0,dy=0,rot=0.0,scale=(1.0,1.0),tint=None,alpha=1.0):
    im=img
    if scale!=(1.0,1.0):
        sx,sy=scale
        nw,nh=int(round(CW*sx)),int(round(CH*sy))
        big=im.resize((nw,nh),Image.LANCZOS)
        im=Image.new('RGBA',(CW,CH),(0,0,0,0))
        # anchored at the feet (centre x, FOOT row)
        im.paste(big,(int(round(CW/2-CW/2*sx)),int(round(FOOT-FOOT*sy))),big)
    if rot:
        im=im.rotate(rot,resample=Image.BICUBIC,center=(CW//2,FOOT))
    if tint is not None:
        col,amt=tint
        arr=np.asarray(im).astype(np.float32)
        arr[...,:3]=arr[...,:3]*(1-amt)+np.array(col)*amt
        im=Image.fromarray(arr.clip(0,255).astype(np.uint8),'RGBA')
    if alpha<1.0:
        a=np.asarray(im).copy(); a[...,3]=(a[...,3]*alpha).astype(np.uint8); im=Image.fromarray(a,'RGBA')
    out=Image.new('RGBA',(CW,CH),(0,0,0,0))
    out.paste(im,(int(dx),int(dy)),im)
    return out

def strip(frames):
    s=Image.new('RGBA',(CW*len(frames),CH),(0,0,0,0))
    for i,f in enumerate(frames): s.alpha_composite(f,(i*CW,0))
    return s

def walk(d):
    p=pose[d]; out=[]
    for sq,sway in [(1.0,0),(0.985,1),(0.97,1),(0.99,0),(0.978,-1),(0.966,-1)]:
        out.append(place(p,dx=sway,scale=(1.0+(1-sq)*0.6,sq)))
    return strip(out)

def attack(d):
    p=pose[d]; fx,fy=DIR[d]; out=[]
    # rest, lean back, wind-up, lunge (impact), hold, recover
    seq=[(0,0),(-3,-4),(-5,-7),(12,9),(8,5),(2,1)]
    for k,(push,rot) in enumerate(seq):
        r=-rot*fx if fx else 0
        sc=(1.0,1.0)
        if fy:  # facing toward / away from the camera: lunge reads as a size pop
            sc=(1.0+0.004*push,1.0+0.004*push)
        out.append(place(p,dx=push*fx,dy=push*fy*0.5,rot=r,scale=sc))
    return strip(out)

def hit(d):
    p=pose[d]; fx,fy=DIR[d]
    return strip([
        place(p,tint=((255,255,255),0.7),alpha=0.65),
        place(p,dx=-6*fx if fx else -4,tint=((200,40,30),0.25)),
        place(p,dx=-3*fx if fx else -2),
        place(p),
    ])

def refit(im, dx=0):
    # a fallen body can leave the cell: centre its box, feet line at 156, shrink to fit
    bb=im.getbbox()
    if bb is None: return im
    body=im.crop(bb)
    if body.width>CW-4:
        s=(CW-4)/body.width; body=body.resize((int(body.width*s),max(1,int(body.height*s))),Image.LANCZOS)
    out=Image.new('RGBA',(CW,CH),(0,0,0,0))
    out.alpha_composite(body,(int((CW-body.width)//2+dx),FOOT+4-body.height))
    return out

def death(d):
    p=pose[d]; fx,fy=DIR[d]
    back=fx if fx else 1   # topples away from where he faces; front/back views fall sideways
    out=[]
    for k,(ang,a) in enumerate([(0,1),(6,1),(22,1),(50,0.97),(78,0.93),(86,0.9)]):
        big=Image.new('RGBA',(CW*3,CH*3),(0,0,0,0)); big.alpha_composite(p,(CW,CH))
        big=big.rotate(ang*back,resample=Image.BICUBIC,center=(CW+CW//2,CH+FOOT))
        if a<1.0:
            arr=np.asarray(big).copy(); arr[...,3]=(arr[...,3]*a).astype(np.uint8); big=Image.fromarray(arr,'RGBA')
        out.append(p.copy() if ang==0 else refit(big,dx=-6*back*min(1,ang/50)))
    return strip(out)

A=R+'art/export_2x/characters/ironjaw/anims/'
for d in 'senw':
    wk=walk('e') if d=='w' else walk(d)
    if d=='w':
        cells=[ImageOps.mirror(wk.crop((i*CW,0,i*CW+CW,CH))) for i in range(6)]
        wk=strip(cells)
    wk.save(A+f'ironjaw_walk_{d}.png')
    wk.save(R+f'art/export_2x/walk_src/ironjaw_walk_{d}.pngbin', format='PNG')
    attack(d).save(A+f'ironjaw_attack_{d}.png')
    hit(d).save(A+f'ironjaw_hit_{d}.png')
    death(d).save(A+f'ironjaw_death_{d}.png')
    pose[d].save(R+f'art/characters/ironjaw/ironjaw_{d}.png')
    place(pose[d],scale=(1.01,0.985)).save(R+f'art/export_2x/characters/ironjaw/idle/ironjaw_idle_plant_{d}_v1.png')

# Select plate: the sheet's front view at full proportions, same finish, 512×768.
big=Image.open(IJ+'cut_front.png').convert('RGBA')
a=big.getchannel('A')
rgb=big.convert('RGB').filter(ImageFilter.MedianFilter(3))
arr=np.power(np.asarray(rgb).astype(np.float32)/255,0.72)
img=Image.fromarray((arr*255).astype(np.uint8))
img=ImageEnhance.Contrast(img).enhance(1.2); img=ImageEnhance.Color(img).enhance(1.12)
img.putalpha(a)
w,h=img.size; s=min(460/w,720/h)
img=img.resize((int(w*s),int(h*s)),Image.LANCZOS)
plate=Image.new('RGBA',(512,768),(0,0,0,0))
plate.alpha_composite(img,((512-img.width)//2,744-img.height))
plate.save(R+'art/ui/select/ironjaw_select.png')
print('done')
