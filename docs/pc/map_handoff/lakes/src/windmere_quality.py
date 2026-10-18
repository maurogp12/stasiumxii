exec(open('/workspace/stasium-pc-look/ship/lakes_v1/src/q_common.py').read())
d,tx,ty=dist('lake_spots_windmere.png',(842.5,268.5),24.8,4.9,4.4,2.75,.4,20,30,2,8)
v1=Image.open(R+'_archive_v1/mock_windmere_lake_1280.png').convert('RGB'); a=np.array(v1).astype(float); H,W=a.shape[:2]
r,g,b=a[...,0],a[...,1],a[...,2]; L=a.mean(2)
ice=(d>.06)&(L>70)&(L<200)&(b>r+10); ice=ndimage.binary_opening(ice,iterations=1)
n1,n2,n3=nz(H,W,1.0,1),nz(H,W,4,2),nz(H,W,12,3)
base=np.array([88,118,146.])*(.8+.4*n2[...,None])
deep=np.clip(d/2,0,1)[...,None]; base=base*(1-.3*deep)+np.array([0,6,14])*deep
frost=np.clip((n3-.5)/.15,0,1)[...,None]*np.clip(1.4-d,0,1)[...,None]; base=base*(1-.55*frost)+np.array([200,214,224])*.55*frost
streak=np.clip(np.sin((tx*1.7+ty*3.1)*6+n2*9)-.86,0,1)[...,None]*6; base=base+0*streak
speck=(n1>.82)[...,None]*np.clip(1.6-d,0,1)[...,None]; base=base*(1-speck*.5)+np.array([230,238,244])*speck*.5
al=ndimage.gaussian_filter(ice.astype(float),.6)[...,None]; a=a*(1-al)+base*al
im=Image.fromarray(np.clip(a,0,255).astype(np.uint8)); dr=ImageDraw.Draw(im); rr=random.Random(9)
ys,xs=np.nonzero(ice&(d>.35))
for _ in range(34):                      # crisp painted cracks
    i=rr.randrange(len(xs)); x,y=float(xs[i]),float(ys[i]); A=rr.uniform(0,6.28); pts=[(x,y)]
    for _ in range(rr.randint(3,7)):
        A+=rr.uniform(-.8,.8); Ln=rr.uniform(5,13); x+=math.cos(A)*Ln; y+=math.sin(A)*Ln*.5
        if not (0<=int(y)<H and 0<=int(x)<W and ice[int(y),int(x)]): break
        pts.append((x,y))
        if rr.random()<.3: dr.line([(x,y),(x+math.cos(A+1.2)*6,y+math.sin(A+1.2)*3)],fill=(214,228,238),width=1)
    if len(pts)>1: dr.line([(p[0]+1,p[1]+1) for p in pts],fill=(28,44,60),width=2); dr.line(pts,fill=(222,234,242),width=1)
a=np.array(im).astype(float)
# snow drifts at the bank: lumpy bright bands with blue shadow side
drift=(d>-.5)&(d<.06); lump=np.clip(.12+.18*nz(H,W,3,7)-np.abs(d+.2),0,1)
dm=drift&(lump>0.02)&~((L<60))
sn=np.array([236,242,248.])*(.92+.1*n2[...,None]); shade=(ndimage.sobel(lump,0)>0)[...,None]
sn=np.where(shade,sn*np.array([.78,.84,.94]),sn)
dal=ndimage.gaussian_filter(dm.astype(float),.5)[...,None]*.9; a=a*(1-dal)+sn*dal
lip=((d>.02)&(d<.1))[...,None]&ice[...,None]; a=np.where(lip,a*.55,a)
# fishing holes: deep dark water + clean rims
O=np.array([842.5,268.5])
for (cx,cy) in [(22,3),(25,4),(27,6)]:
    p=O+(cx+.5-20)*EX+(cy+.5-2)*EY; p[1]+=2
    yy,xx=np.mgrid[0:H,0:W]; e=((xx-p[0])/15)**2+((yy-p[1])/7.5)**2
    a=np.where((e<1)[...,None]&(a.mean(2)<110)[...,None],a*.45+np.array([4,14,26]),a)
    rim=(e>=1)&(e<1.55); a=np.where(rim[...,None],a*.25+np.array([236,242,246])*.75,a)
    ring=(e>=1.55)&(e<1.85); a=np.where(ring[...,None],a*.7,a)
a=crisp(a,d,reach=9)   # cabin, pines and props get the strong crisp pass too
out=Image.fromarray(np.clip(a,0,255).astype(np.uint8)).convert('RGBA')
ij=Image.open('/workspace/scratch/ij_walk/v8/te0/walk/ironjaw_walk_S_f00.png').convert('RGBA'); ij=ij.crop(ij.getbbox())
q=np.array(ij).astype(float); q[...,:3]*=np.array([.8,.88,.98]); ij=Image.fromarray(np.clip(q,0,255).astype(np.uint8)); ij=ij.resize((round(ij.width*46/ij.height),46),Image.LANCZOS)
pp=O+(23.3+.5-20)*EX+(6.6+.5-2)*EY; out.alpha_composite(ij,(int(pp[0]-ij.width/2),int(pp[1]-44))); out=out.convert('RGB')
out.save(R+'mock_windmere_lake_1280.png')
sbs(v1,out,(700,190,1060,400),R+'windmere_before_vs_final.png','FINAL: same shape + position, painted ice quality pass')
out.crop((700,190,1060,400)).resize((720,420)).save('/tmp/v/wq.png')
