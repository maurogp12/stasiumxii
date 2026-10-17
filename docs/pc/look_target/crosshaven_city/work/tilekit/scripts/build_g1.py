import numpy as np, json, os
from PIL import Image, ImageFilter, ImageDraw, ImageFont
R='/workspace/crosshaven_paint/work/tilekit/'; RAW=R+'raw/'
rng=np.random.default_rng(7)
def key(path):
    a=np.asarray(Image.open(path).convert('RGB')).astype(float)
    g=a[...,1]-np.maximum(a[...,0],a[...,2])
    al=np.clip((90-g)/50,0,1)
    # despill
    mx=np.maximum(a[...,0],a[...,2]); a[...,1]=np.minimum(a[...,1],mx+10)
    im=Image.fromarray(np.dstack([a,al*255]).astype(np.uint8),'RGBA')
    return im.crop(im.getbbox())
def scale_h(im,h): return im.resize((max(1,round(im.width*h/im.height)),h),Image.LANCZOS)
def shadowed(im,pad=50,dx=18,band=40,op=0.38,blur=14):
    W,H=im.size; c=Image.new('RGBA',(W+pad*2,H+pad),(0,0,0,0))
    a=np.asarray(im)[...,3].astype(float)/255
    s=np.zeros((H+pad,W+pad*2))
    # bottom band of silhouette
    bot=np.zeros_like(a)
    for x in range(W):
        ys=np.where(a[:,x]>0.5)[0]
        if len(ys): y1=ys.max(); bot[max(0,y1-band):y1+1,x]=1
    s[pad//3:pad//3+H, pad+dx:pad+dx+W]=bot
    sh=Image.fromarray((s*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
    sa=(np.asarray(sh).astype(float)*op).astype(np.uint8)
    S=Image.fromarray(np.dstack([np.full_like(sa,20),np.full_like(sa,25),np.full_like(sa,15),sa]),'RGBA')
    c.alpha_composite(S); c.alpha_composite(im,(pad,0))
    return c,(pad,0)
def foot_of(im,off,origW):
    # bottom-centre of opaque art
    a=np.asarray(im)[...,3]; ys,xs=np.where(a>128)
    return [int(off[0]+origW//2), int(ys.max())]
def save(sub,name,im,meta):
    p=R+sub+'/'+name+'_CONCEPTO'; im.save(p+'.png'); json.dump(meta,open(p+'.json','w'),indent=1)
def shear(im,k):  # y += k*x  (k>0 down-right)
    W,H=im.size; dy=int(abs(k)*W)
    out=im.transform((W,H+dy),Image.AFFINE,(1,0,0,-k,1,(dy if k<0 else 0)) if False else (1,0,0,-k,1,0 if k>0 else -dy),Image.BICUBIC)
    return out
def shear2(im,k):
    W,H=im.size; dy=int(round(abs(k)*W)); out=Image.new('RGBA',(W,H+dy))
    # inverse map: src_y = y - k*x - off
    off=0 if k>0 else dy
    return im.transform((W,H+dy),Image.AFFINE,(1,0,0,-k,1,-off),Image.BICUBIC)
pieces={}
# ---------- TOWER ----------
tw=scale_h(key(RAW+'tower_raw.jpg'),990)
tws,off=shadowed(tw,pad=60,band=60,blur=18)
f=foot_of(tws,off,tw.width)
save('walls','tower_round',tws,{"foot":f,"footprint":[3,3],"blocks":True,"height_px":990,"note":"plinth hides wall ends; wall foot meets plinth centre ~%dpx above foot"%60})
pieces['tower_round']=(tws,f)
# ---------- GATE ----------
g=key(RAW+'gate_raw.jpg'); ga=np.asarray(g).copy()
# column align bottoms (remove raw perspective)
al=ga[...,3]; H,W=al.shape; bots=np.array([ (np.where(al[:,x]>128)[0].max() if (al[:,x]>128).any() else H-1) for x in range(W)])
# jamb columns only (arch hole columns have bottom too). use smooth linear fit
xs=np.arange(W); p=np.polyfit(xs,bots,1); 
out=np.zeros((H+int(abs(p[0])*W)+10,W,4),np.uint8)
for x in range(W):
    sh=int(round(np.polyval(p,W-1)-np.polyval(p,x)))+0
    sh=int(round(max(np.polyval(p,0),np.polyval(p,W-1))-np.polyval(p,x)))
    out[sh:sh+H,x]=ga[:,x]
gi=Image.fromarray(out,'RGBA'); gi=gi.crop(gi.getbbox()); gi=scale_h(gi,550)
# hole: transparent pixels connected to bottom middle, inside bbox
A=np.asarray(gi)[...,3]<60; Hh,Wg=A.shape
from scipy import ndimage
op=~A; top=np.where(op.any(0),op.argmax(0),Hh)
below=np.arange(Hh)[:,None]>top[None,:]
M=A&below; M[Hh-15:]=False
lab,_=ndimage.label(M); cx=Wg//2; hl=lab[Hh-20,cx]; hole=lab==hl
cols=np.where(hole.any(0))[0]; hole[Hh-15:,cols.min():cols.max()+1]=A[Hh-15:,cols.min():cols.max()+1]
ys,xs=np.where(hole); hb=[int(xs.min()),int(ys.min()),int(xs.max()),Hh]
# ---------- WALL (cut from the gate curtain so merlons/colour/foot match exactly) ----------
ga2=np.asarray(gi); top=ga2[...,3][:60].astype(float)
prof=(ga2[...,3][5:40]>128).mean(0)
xs_=np.arange(40,hb[0]-20); pr=prof[xs_]-prof[xs_].mean()
ac=[np.dot(pr[:-l],pr[l:]) for l in range(40,200)]; per=40+int(np.argmax(ac))
x0=60; nper=max(1,(hb[0]-40-x0)//per); SW=nper*per
seg=gi.crop((x0,0,x0+SW,gi.height))
sa=np.asarray(seg).astype(float); r=np.roll(sa,per*(nper//2) if nper>1 else 0,1); tt=np.linspace(0,1,SW); m=np.clip(np.minimum(tt,1-tt)*2*4,0,1)[None,:,None]
if nper>1: sa=sa*m+r*(1-m)
sa[...,3]=np.where(np.asarray(seg)[...,3]>0, sa[...,3], 0)
wall_seg=Image.fromarray(sa.clip(0,255).astype(np.uint8),'RGBA')
h=key(RAW+'hero_scale_raw.jpg'); h=h.resize((round(h.width*156/h.height),156),Image.LANCZOS); h.save(R+'raw/hero_scale_CONCEPTO.png')
def wallpiece(name,im,fp,extra={}):
    s,off=shadowed(im)
    meta={"foot":[off[0]+im.width//2, off[1]+im.height],"footprint":fp,"blocks":True,"height_px":550}; meta.update(extra)
    save('walls',name,s,meta); pieces[name]=(s,meta['foot'])
wallpiece('wall_h',wall_seg,[3,1],{"orient":"screen-horizontal (runs along grid diagonal)","tile_step_px":[SW,0],"merlon_period_px":per})
for nm,k in [('wall_diag_se',0.5),('wall_diag_ne',-0.5)]:
    sh=shear2(wall_seg,k); s,off=shadowed(sh)
    fx=off[0]+sh.width//2; fy=off[1]+550+(sh.height-550)//2
    meta={"foot":[fx,fy],"footprint":[max(1,SW//64),1],"blocks":True,"height_px":550,"orient":nm.split('_')[-1]+" iso axis, 2:1 slope; mirror pair","tile_step_px":[SW,SW//2 if k>0 else -SW//2]}
    save('walls',nm,s,meta); pieces[nm]=(s,[fx,fy])
print('wall seg',SW,'per',per)
# leaves
leaf=key(RAW+'doorleaf_raw.jpg'); hw=(hb[2]-hb[0]+1); hh=hb[3]-hb[1]
leaf=leaf.resize((hw,hh),Image.LANCZOS); L=leaf.crop((0,0,hw//2,hh)); Rr=leaf.crop((hw//2,0,hw,hh))
holemask=Image.fromarray((hole[hb[1]:hb[3],hb[0]:hb[2]+1]*255).astype(np.uint8))
import math
def warp_leaf(lf,theta,left):
    w,h=lf.size; nw=max(2,int(round(w*math.cos(theta)))); dh=int(h*0.10*math.sin(theta))
    # quad: hinge edge full height, free edge shrinks (going inward/away)
    if left: quad=(0,0, 0,h, w,h-dh, w,dh)  # src coords for dst corners (ul,ll,lr,ur)
    else: quad=(0,dh, 0,h-dh, w,h, w,0)
    # build dst of size nw x h mapping from lf via QUAD (inverse: dst->src) -> make via perspective approx
    tmp=lf.resize((nw,h),Image.LANCZOS)
    d=np.asarray(tmp).copy().astype(float)
    for x in range(nw):
        fr=x/nw if left else 1-x/nw; s=1-0.10*math.sin(theta)*fr*2
        col=Image.fromarray(d[:,x:x+1].astype(np.uint8),'RGBA').resize((1,max(1,int(h*s))),Image.BILINEAR)
        c=np.zeros((h,1,4)); o=(h-col.height)//2; c[o:o+col.height]=np.asarray(col); d[:,x:x+1]=c
    d[...,:3]*= (1-0.45*math.sin(theta))
    return Image.fromarray(d.clip(0,255).astype(np.uint8),'RGBA')
frames=[]
for k in range(8):
    th=math.radians(88*k/7)
    fr=Image.new('RGBA',(hw,hh),(0,0,0,0))
    l=warp_leaf(L,th,True); r=warp_leaf(Rr,th,False)
    fr.alpha_composite(l,(0,0)); fr.alpha_composite(r,(hw-r.width,0))
    a=np.asarray(fr).copy(); a[...,3]=(a[...,3].astype(float)*np.asarray(holemask)/255).astype(np.uint8)
    frames.append(Image.fromarray(a,'RGBA'))
gs,off=shadowed(gi)
gfoot=[off[0]+gi.width//2, off[1]+gi.height]
door_xy=[off[0]+hb[0],off[1]+hb[1]]
meta={"foot":gfoot,"footprint":[8,1],"blocks":True,"height_px":550,"orient":"screen-horizontal",
 "passage":{"rect":[door_xy[0],door_xy[1],hw,hh],"walkable":True,"see_through":True,"rim":"stone voussoir rim kept, arch interior alpha 0"},
 "door":{"file":"gate_door_h_CONCEPTO.png","frames":8,"fps":12,"frame_w":hw,"frame_h":hh,"offset":door_xy,"open_inward":True,
  "hinge_left":{"top":[door_xy[0],door_xy[1]],"bottom":[door_xy[0],door_xy[1]+hh]},"hinge_right":{"top":[door_xy[0]+hw,door_xy[1]],"bottom":[door_xy[0]+hw,door_xy[1]+hh]}},
 "layer_order":"ground < door < gate curtain (rim/jambs) < actors in front","no_portcullis":True,"no_dust":True}
save('walls','gate_h',gs,meta); pieces['gate_h']=(gs,gfoot)
strip=Image.new('RGBA',(hw*8,hh))
for i,f_ in enumerate(frames): strip.alpha_composite(f_,(i*hw,0))
strip.save(R+'walls/gate_door_h_CONCEPTO.png')
json.dump({"foot":[hw//2,hh],"footprint":[0,0],"blocks":False,"height_px":hh,"frames":8,"fps":12,"frame_w":hw,"frame_h":hh,"parent":"gate_h_CONCEPTO","f00":"closed","f07":"open"},open(R+'walls/gate_door_h_CONCEPTO.json','w'),indent=1)
# diagonal gate + doors
for nm,k in [('se',0.5),('ne',-0.5)]:
    gsh=shear2(gi,k); s,off=shadowed(gsh)
    dy0=0 if k>0 else int(round(abs(k)*gi.width))
    dx,dyy=hb[0], hb[1]+dy0+int(round(k*hb[0]))
    stripd=Image.new('RGBA',(hw*8,hh+int(abs(k)*hw)))
    fw=None
    for i,f_ in enumerate(frames):
        fs=shear2(f_,k); fw=fs.size; stripd.alpha_composite(fs,(i*hw,0))
    stripd.save(R+f'walls/gate_door_diag_{nm}_CONCEPTO.png')
    fy=off[1]+550+(gsh.height-550)//2
    m={"foot":[off[0]+gsh.width//2,fy],"footprint":[16,1],"blocks":True,"height_px":550,"orient":nm+" iso axis",
       "passage":{"walkable":True,"see_through":True},
       "door":{"file":f"gate_door_diag_{nm}_CONCEPTO.png","frames":8,"fps":12,"frame_w":fw[0],"frame_h":fw[1],"offset":[off[0]+dx,off[1]+min(dyy, dyy)-(0 if k>0 else int(abs(k)*hw))],"open_inward":True},
       "layer_order":"ground < door < gate curtain < actors","no_portcullis":True,"no_dust":True}
    save('walls',f'gate_diag_{nm}',s,m); pieces[f'gate_diag_{nm}']=(s,m['foot'])
    json.dump({"frames":8,"fps":12,"frame_w":fw[0],"frame_h":fw[1],"parent":f"gate_diag_{nm}_CONCEPTO","foot":[fw[0]//2,fw[1]],"footprint":[0,0],"blocks":False,"height_px":fw[1]},open(R+f'walls/gate_door_diag_{nm}_CONCEPTO.json','w'),indent=1)
# ---------- WATER TUNNEL ----------
t=key(RAW+'tunnel_raw.jpg'); ts=scale_h(t,550); fac=per/187.0
# arch+grate block from tunnel raw (lower centre), rescaled so stone size matches the curtain
ac_=ts.crop((int(ts.width*0.33),int(ts.height*0.32),int(ts.width*0.53),ts.height)); ac_=ac_.resize((int(ac_.width*fac*1.6),int(ac_.height*fac*1.6)),Image.LANCZOS)
tc=Image.new('RGBA',(SW*3,550)); [tc.alpha_composite(wall_seg,(i*SW,0)) for i in range(3)]
tc.alpha_composite(ac_,((tc.width-ac_.width)//2,550-ac_.height))
s,off=shadowed(tc); m={"foot":[off[0]+tc.width//2,off[1]+550],"footprint":[6,1],"blocks":True,"height_px":550,"orient":"screen-horizontal","grate":True,"water_passes":True}
save('walls','water_tunnel_h',s,m); pieces['water_tunnel_h']=(s,m['foot'])
for nm,k in [('se',0.5),('ne',-0.5)]:
    sh=shear2(tc,k); s,off=shadowed(sh); m={"foot":[off[0]+sh.width//2,off[1]+550+(sh.height-550)//2],"footprint":[8,1],"blocks":True,"height_px":550,"orient":nm,"grate":True}
    save('walls',f'water_tunnel_diag_{nm}',s,m)
# ---------- BRIDGES ----------
for nm,h,fp in [('bridge_stone',300,[2,5]),('bridge_wood',260,[2,5])]:
    b=key(RAW+nm+'_raw.jpg'); b=b.resize((int(b.width*(640/b.width)),int(b.height*(640/b.width))),Image.LANCZOS)
    s,off=shadowed(b,band=20,op=0.3)
    m={"foot":[off[0]+b.width//2,off[1]+b.height],"footprint":fp,"blocks":False,"walkable":True,"height_px":b.height,"layer":"over water, under props/actors","orient":"ne axis; flip_h for se"}
    save('ground',nm,s,m)
print('gate hole',hb,'tower',tw.size)
