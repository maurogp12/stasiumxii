exec(open('/workspace/stasium-pc-look/ship/lakes_v1/src/common.py').read())
import json, random, math
from PIL import ImageDraw
man=[]
GR8=np.array([.86,.9,.96])
def render_win(d,seed,nc=0):
    H,W=d.shape
    n1=noise(W,H,28,seed); n2=noise(W,H,90,seed+1); n3=noise(W,H,8,seed+2)
    icec=np.array([100,126,150.])*(.92+.12*n1[...,None])
    frost=np.clip((n2-.62)/.1,0,1)[...,None]; icec=icec*(1-frost*.4)+np.array([180,196,208.])*frost*.4
    icec=icec*(1-.1*np.clip(d/2.2,0,1)[...,None])
    icec=np.where(((d>0)&(d<.12))[...,None],icec*.58,icec)          # hard dark lip
    icec=np.where(((d>=.12)&(d<.16))[...,None],icec*1.18,icec)      # bright ice rim line
    snow=np.array([214,222,230.])*(.9+.12*n1[...,None]); snow-= (n3[...,None]>.62)*np.array([16,12,6])
    snow=np.where(((d>-.14)&(d<=0))[...,None],snow*.78,snow)          # packed-snow bank
    out=np.where((d>0)[...,None],icec,snow)*GR8
    im=Image.fromarray(np.clip(out,0,255).astype(np.uint8)).convert('RGBA')
    if nc: 
        ice=Image.fromarray(((d>.2)*255).astype(np.uint8))
        c=im.copy(); dr_=ImageDraw.Draw(c); r_=random.Random(seed)
        for _ in range(nc):
            x_,y_=r_.uniform(10,118),r_.uniform(8,56); pts=[(x_,y_)]; a_=r_.uniform(0,6.28)
            for _ in range(r_.randint(4,7)):
                a_+=r_.uniform(-.8,.8); L_=r_.uniform(8,18); x_+=math.cos(a_)*L_; y_+=math.sin(a_)*L_*.5; pts.append((x_,y_))
            dr_.line([(q[0]+1.5,q[1]+1.5) for q in pts],fill=(34,48,64),width=3); dr_.line(pts,fill=(222,234,242),width=2)
        im=Image.composite(c,im,ice)
    # bank stones along the hard edge (painted into the tile, inside the diamond)
    r=random.Random(seed); dr=ImageDraw.Draw(im)
    ys,xs=np.nonzero((d>-.3)&(d<-.16)&DM)
    for k in range(0,len(xs),max(1,len(xs)//10)) if len(xs) else []:
        x,y=xs[k],ys[k]; s=r.uniform(6,10)
        if abs(x-63.5)/64+abs(y-31.5)/32>.82: continue
        dr.ellipse([x-s,y-s*.6,x+s,y+s*.6],fill=(92,100,112)); dr.ellipse([x-s*.7,y-s*.75,x+s*.5,y],fill=(226,232,238))
    return np.array(im)[...,:3].astype(float)
def save_tile(rgb,rel,use):
    a=np.dstack([np.clip(rgb,0,255),DM*255]).astype(np.uint8); save(Image.fromarray(a,'RGBA'),rel,(64,64),use)
for nm,dist,nc,use in [('ice_plain_a',1.5,2,'plain ice (crisp v2)'),('ice_plain_b',3,2,'plain ice, darker deep (crisp v2)'),('ice_cracked_a',1.5,6,'cracked ice (crisp v2)'),('ice_cracked_b',3,10,'cracked ice, heavy (crisp v2)')]:
    save_tile(render_win(np.full((64,128),dist),sum(map(ord,nm)),nc),f'windmere/tiles/{nm}.png',use)
y,x=np.mgrid[0:64,0:128]; u=(x/64+y/32)/2-.5; vv=(y/32-x/64)/2+.5  # fixed: v1 offsets put the bank off-tile
sides={'ne':(1-vv)*1.4-0.7,'sw':vv*1.4-0.7,'nw':(1-u)*1.4-0.7,'se':u*1.4-0.7}
L='shore_snow_ice'
for k,d in sides.items(): save_tile(render_win(d,sum(map(ord,k))),f'windmere/tiles/{L}_edge_{k}.png',f'{L}: ice on the {k.upper()} side, hard bank (crisp v2)')
ON={('ne','nw'):'n',('ne','se'):'e',('sw','se'):'s',('sw','nw'):'w'}
for (a,b),o in ON.items():
    save_tile(render_win(np.maximum(sides[a],sides[b]),3),f'windmere/tiles/{L}_outer_{o}.png',f'{L}: outer corner, ice on {a.upper()}+{b.upper()}, hard bank (crisp v2)')
    save_tile(render_win(np.minimum(sides[a],sides[b])+.25,4),f'windmere/tiles/{L}_inner_{a}_{b}.png',f'{L}: inner corner (ice only in the {a.upper()}/{b.upper()} wedge), hard bank (crisp v2)')
def hole(r2x):
    W=int(r2x*2.8); H=int(r2x*1.6); im=Image.new('RGBA',(W,H)); d=ImageDraw.Draw(im); cx,cy=W/2,H/2
    d.ellipse([cx-r2x*1.32,cy-r2x*.74,cx+r2x*1.32,cy+r2x*.74],fill=(236,242,246,255))
    d.ellipse([cx-r2x*1.15,cy-r2x*.6,cx+r2x*1.15,cy+r2x*.62],fill=(150,176,192,255))
    d.ellipse([cx-r2x,cy-r2x*.5,cx+r2x,cy+r2x*.5],fill=(18,34,48,255))
    d.ellipse([cx-r2x*.8,cy-r2x*.28,cx+r2x*.9,cy+r2x*.46],fill=(30,58,76,255))
    d.arc([cx-r2x*.6,cy-r2x*.1,cx+r2x*.5,cy+r2x*.3],200,330,fill=(120,150,160,255),width=3)
    d.arc([cx-r2x,cy-r2x*.5,cx+r2x,cy+r2x*.5],180,360,fill=(10,20,30,255),width=3)
    rr=random.Random(r2x)
    for k in range(10):
        a=k/10*6.28+.3; px=cx+math.cos(a)*r2x*1.24; py=cy+math.sin(a)*r2x*.68; s=rr.uniform(5,9)
        d.polygon([(px-s,py),(px,py-s*.7),(px+s*1.1,py+1),(px,py+s*.7)],fill=(248,250,252,255)); d.line([(px-s,py),(px,py+s*.7),(px+s*1.1,py+1)],fill=(150,170,184,255),width=2)
    return im.crop(im.getbbox())
im=hole(56); save(im,'windmere/props/ice_hole.png',(im.width//2,im.height),'ice-fishing hole decal v2 (bigger, about 1.2 cells wide), floor layer; anchor bottom-centre at cell centre y+12 (1x)')
im=hole(34); save(im,'windmere/props/ice_hole_small.png',(im.width//2,im.height),'small ice hole variant v2')
# manifest merge
M=json.load(open(R+'/src/manifest.json')); new={m[0]:m for m in man}
M=[list(new.pop(m[0])) if m[0] in new else m for m in M]+[list(v) for v in new.values()]
json.dump(M,open(R+'/src/manifest.json','w')); print('tiles',len(man))
