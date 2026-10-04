"""procedural snowy granite outcrops painted in screen space (tile SS grid), coloured from the crag raws"""
from ngc import *
_c=load('crag_cliff_strip.jpg')[300:700]
_L=lum(_c)
GRAIN=(_L-ndi.gaussian_filter(_L,5))          # granite grain / facet detail from the painted cliff
G_LIT=np.array([226,220,206])/255.
G_MID=np.array([160,154,144])/255.
G_DARK=np.array([92,90,94])/255.
G_SIDE=np.array([112,110,116])/255.
SNOW_HI=np.array([0.985,0.985,0.99]); SNOW_SH=np.array([0.84,0.85,0.93])
LIGHT=np.array([-0.55,-0.62,0.56]); LIGHT/=np.linalg.norm(LIGHT)
def lumps(X,Y,rocks,r):
    field=np.full(X.shape,9.0,np.float32)
    for (cx,cy,rx,ry) in rocks:
        for k in range(r.integers(2,5)):
            ox=r.uniform(-0.45,0.45)*rx; oy=r.uniform(-0.35,0.35)*ry
            sx=rx*r.uniform(0.55,0.9); sy=ry*r.uniform(0.55,0.9)
            field=np.minimum(field,np.sqrt(((X-cx-ox)/sx)**2+((Y-cy-oy)/sy)**2))
    return field
def paint_rocks(rgb_ss, rocks, seed, ss=4, snow_cap=0.30, keep_inside=None, side_px=4.0):
    H,W=rgb_ss.shape[:2]
    r=rng(seed)
    yy,xx=np.mgrid[0:H,0:W].astype(np.float32)
    X=(xx+0.5)/ss; Y=(yy+0.5)/ss
    n1=smooth_noise((H,W),26,seed+1); n2=smooth_noise((H,W),7,seed+2); n3=smooth_noise((H,W),3,seed+3)
    field=lumps(X,Y,rocks,r)+0.12*n1+0.05*n2
    top=smoothstep(1.03,0.97,field)
    # side face: the top shape extruded downward by side_px (rock pokes up out of the snow)
    sh_top=np.zeros_like(top)
    for k in range(1,int(side_px*ss)+1):
        sh_top=np.maximum(sh_top,np.roll(top,k,axis=0))
    side=np.clip(sh_top-top,0,1)
    # snow banked against the base eats the lower part of the side face irregularly
    depth=np.zeros_like(top)
    for k in range(1,int(side_px*ss)+1):
        depth=np.where((np.roll(top,k,axis=0)>0.5)&(depth==0),k/ss,depth)
    bank=smoothstep(0.40,0.80,depth/side_px+0.22*n2+0.12*n1)
    side=side*(1-bank)
    m=np.clip(top+side,0,1)
    if keep_inside is not None:
        top=top*keep_inside; side=side*keep_inside; m=m*keep_inside
    # facets on the top surface
    pts=[]
    for (cx,cy,rx,ry) in rocks:
        for k in range(int(5+rx*0.3)):
            pts.append((cx+r.uniform(-1,1)*rx,cy+r.uniform(-1,1)*ry))
    pts=np.array(pts,np.float32)
    d2=(X[...,None]-pts[:,0])**2+((Y[...,None]-pts[:,1])*1.7)**2
    o=np.argsort(d2,-1)[...,:2]
    f1=np.sqrt(np.take_along_axis(d2,o[...,:1],-1)[...,0]); f2=np.sqrt(np.take_along_axis(d2,o[...,1:2],-1)[...,0])
    idx=o[...,0]
    nrm=np.stack([r.uniform(-0.7,0.7,len(pts)),r.uniform(-0.8,0.4,len(pts)),r.uniform(0.6,1.0,len(pts))],1)
    nrm/=np.linalg.norm(nrm,axis=1,keepdims=True)
    shade=np.clip(nrm@LIGHT,0,1)[idx]
    crack=smoothstep(0.0,1.8,f2-f1)
    gx=bilinear(GRAIN[...,None],np.mod(X*3.0+r.uniform(0,600),GRAIN.shape[1]-2),np.mod(Y*3.0+r.uniform(0,300),GRAIN.shape[0]-2))[...,0]
    t=np.clip(0.25+shade*0.95,0,1)[...,None]
    col=np.where(t>0.5,G_MID+(G_LIT-G_MID)*(t-0.5)*2,G_DARK+(G_MID-G_DARK)*t*2)
    col=col*(1+1.3*gx[...,None])*(0.80+0.20*crack[...,None])
    # top-left lit rim on the top surface
    gyy=np.gradient(field,axis=0)*ss; gxx=np.gradient(field,axis=1)*ss
    lit=np.clip(-(gyy*0.75+gxx*0.55)*3,0,1)*smoothstep(0.75,0.98,field)
    col=np.clip(col+0.18*lit[...,None],0,1)
    # side face: cool shade, darker toward the snow line, light grain
    sidecol=G_SIDE*(1+1.0*gx[...,None])*(1-0.25*np.clip(depth/side_px,0,1))[...,None]
    # snow lying on the top surface (hollows + upper rims), irregular
    cap=smoothstep(0.55,0.75,0.55*n1*0+0.6*n2+0.35*n3+snow_cap+0.35*smoothstep(0.6,1.0,field)*(gyy>0))*top
    snowc=SNOW_SH+(SNOW_HI-SNOW_SH)*np.clip(0.4+0.8*shade,0,1)[...,None]
    col=col*(1-cap[...,None])+snowc*cap[...,None]
    # cool contact shadow on the snow, down-right of the rock
    shd=ndi.gaussian_filter(np.roll(np.roll(m,int(2*ss),0),int(3*ss),1),2.0*ss)
    shd=np.clip(shd*1.3,0,1)*(1-m)
    if keep_inside is not None: shd=shd*keep_inside
    base=rgb_ss*(1-0.16*shd[...,None])
    base=base*(1-0.06*shd[...,None])+np.array([0.60,0.61,0.70])*0.06*shd[...,None]
    out=base*(1-side[...,None])+sidecol*side[...,None]
    out=out*(1-top[...,None])+col*top[...,None]
    return np.clip(out,0,1),m
