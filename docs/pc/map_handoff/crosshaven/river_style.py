"""Crosshaven river restyle: painted teal water matching the water-gate arch water.
Static base (depth, banks, riverbed stones) + seamless animated ripple tile + foam spots (piers, gates, bends)."""
import numpy as np,cv2,math
TS=256
FLOW=np.array([-0.86,0.51])           # mean downstream direction on screen (NE -> SW)
def _pnoise(n,seed,scale,aniso=(1,1)):
    r=np.random.default_rng(seed);f=np.fft.fft2(r.standard_normal((n,n)))
    ky=np.fft.fftfreq(n)[:,None]*aniso[1];kx=np.fft.fftfreq(n)[None,:]*aniso[0]
    k=np.sqrt(kx**2+ky**2);f*=np.exp(-(k*scale)**2);f[0,0]=0
    o=np.real(np.fft.ifft2(f));return (o-o.mean())/(o.std()+1e-9)   # periodic -> tiles seamlessly
def ripple_tile():
    """RGBA seamless tile: light ripple strokes + sparkles over transparent."""
    a=_pnoise(TS,7,6,(3.2,0.55));b=_pnoise(TS,11,3,(3.8,0.6))
    s=np.clip((a*0.5+b*0.6-0.75)*1.5,0,1)            # thin bright crests
    d=np.clip((-a*0.6-b*0.4-1.0)*1.2,0,1)            # darker troughs
    t=np.zeros((TS,TS,4),np.float32)
    t[...,:3]=np.where((s>d)[...,None],[150,205,208],[22,70,80])
    t[...,3]=np.maximum(s*150,d*70)
    sp=_pnoise(TS,23,1.2)>2.6;t[sp,:3]=[235,248,246];t[sp,3]=200
    return t
def _tile_at(tile,H,W,ox,oy):
    ys=(np.arange(H)[:,None]+int(oy))%TS;xs=(np.arange(W)[None,:]+int(ox))%TS
    return tile[ys,xs]
class River:
    def __init__(s,riverM,foam_pts):
        s.M=riverM.astype(np.uint8);H,W=riverM.shape;s.H,s.W=H,W
        dist=cv2.distanceTransform(s.M,cv2.DIST_L2,5);s.d=np.clip(dist/45.0,0,1)
        sm=s.d*s.d*(3-2*s.d)
        edge=np.array([24,58,62],np.float32);mid=np.array([54,136,144],np.float32);deep=np.array([44,118,132],np.float32)
        base=edge[None,None]*(1-sm[...,None])+mid[None,None]*sm[...,None]
        dd=np.clip((dist-30)/40,0,1)[...,None];base=base*(1-dd)+deep*dd
        # subtle riverbed stones (static), most visible in the shallows
        r=np.random.default_rng(5);st=np.zeros((H,W),np.float32)
        ys,xs=np.where(s.M>0);idx=r.choice(len(ys),size=min(len(ys)//500,16000),replace=False)
        for i in idx:
            y,x=ys[i],xs[i];a_=r.integers(5,13);cv2.ellipse(st,(int(x),int(y)),(int(a_),int(a_*0.55)),0,0,360,float(r.uniform(0.4,1)),-1)
        st=cv2.GaussianBlur(st,(0,0),1.6);shallow=(1-0.65*sm)
        base=base*(1-0.30*st[...,None]*shallow[...,None])+np.array([92,120,104])*(0.22*st*shallow)[...,None]
        rim=(dist<4)[...,None];base=np.where(rim,base*0.72,base)
        s.base=base;s.tile=ripple_tile()
        fm=np.zeros((H,W),np.float32)
        for (x,y,rad) in foam_pts:cv2.circle(fm,(int(x),int(y)),int(rad),1.0,-1)
        s.foamzone=cv2.GaussianBlur(fm,(0,0),14)*(s.M>0)
        s.ftile=_pnoise(TS,31,4,(3.0,0.6))
    def frame(s,t=0.0,box=None):
        """RGB (float) water for time t seconds; box=(x0,y0,x1,y1) to render a crop."""
        x0,y0,x1,y1=box or (0,0,s.W,s.H);h,w=y1-y0,x1-x0
        base=s.base[y0:y1,x0:x1].copy()
        sp=24.0;ox=x0-FLOW[0]*sp*t;oy=y0-FLOW[1]*sp*t
        r1=_tile_at(s.tile,h,w,ox,oy);r2=_tile_at(s.tile[::-1,::-1],h,w,ox*0.7+97,oy*0.7+41)
        for r_,k in ((r1,1.0),(r2,0.55)):
            al=(r_[...,3:4]/255.0)*k*(0.45+0.55*s.d[y0:y1,x0:x1,None]);base=base*(1-al)+r_[...,:3]*al
        fz=s.foamzone[y0:y1,x0:x1]
        fn=_tile_at(s.ftile[...,None],h,w,ox*1.3,oy*1.3)[...,0]
        fa=cv2.GaussianBlur((np.clip((fn+1.2*fz-0.9)*1.4,0,1)*np.clip(fz*1.8,0,1)).astype(np.float32),(0,0),0.8)*0.8
        base=base*(1-fa[...,None]*0.85)+np.array([228,240,238])*(fa[...,None]*0.85)
        return np.clip(base,0,255)
