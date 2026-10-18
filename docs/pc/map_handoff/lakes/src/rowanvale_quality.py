exec(open('/workspace/stasium-pc-look/ship/lakes_v1/src/q_common.py').read())
d,tx,ty=dist('lake_spots_rowanvale.png',(842.5,258.5),25,5.6,4.5,3.2,1.3,20,30,2,9)
v1=Image.open(R+'mock_rowanvale_lake_v1_1280.png').convert('RGB'); a=np.array(v1).astype(float); H,W=a.shape[:2]
def tex(n,s):
    t=Image.open(PC+n).convert('RGB'); t=np.array(t.resize((int(t.width*s),int(t.height*s)),Image.LANCZOS)).astype(float)
    g=t[np.arange(H)[:,None]%t.shape[0],np.arange(W)[None,:]%t.shape[1]]; m=g.mean(2,keepdims=True); return (m+(g-m)*.9)*np.array([.88,1.0,.9])
sh,md,dp=tex('ground_water_shallow.png',.45),tex('ground_water_mid.png',.45),tex('ground_water_deep.png',.45)
k=np.clip(d/1.0,0,1)[...,None]; k2=np.clip((d-1.0)/1.1,0,1)[...,None]
wt=sh*(1-k)+md*k; wt=wt*(1-k2)+dp*k2*np.array([.7,.82,.9])
r,g,b=a[...,0],a[...,1],a[...,2]
wm=(d>0.03)&(b>r+12)&(g>r); wm=ndimage.binary_opening(wm,iterations=1)
al=ndimage.gaussian_filter(wm.astype(float),.6)[...,None]*.9; a=a*(1-al)+wt*al
n=nz(H,W,1.1,3); foam=(np.exp(-((d-.14)/.08)**2)*(n>.42))[...,None]*wm[...,None]; a=a*(1-foam*.75)+np.array([236,244,236])*foam*.75
gl=(np.exp(-((d-.55)/.05)**2)*(nz(H,W,2,5)>.6))[...,None]*wm[...,None]; a=a+gl*np.array([60,70,60])   # sun glints
lip=((d>-.18)&(d<.05))[...,None]; a=np.where(lip,a*.72,a)
ao=np.exp(-((d+.45)/.25)**2)[...,None]*(d<-.2)[...,None]; a=a*(1-.16*ao)
a=crisp(a,d)
out=Image.fromarray(np.clip(a,0,255).astype(np.uint8)); out.save(R+'mock_rowanvale_lake_1280.png')
sbs(v1,out,(680,240,1080,460),R+'rowanvale_v1_vs_final.png','FINAL: same v1 shape + position, quality pass above docks bar')
out.crop((680,240,1080,460)).resize((800,440)).save('/tmp/v/rq.png')
