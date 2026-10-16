exec(open('/workspace/stasium-pc-look/ship/lakes_v1/src/common.py').read())
import json
O=np.array([842.5,268.5]); X0,Y0=20,2
img,cl,tx,ty,rect=clean('lake_spots_windmere.png',O,20,30,2,8)
hero=hero_mask(cl,(840,300,900,365))
def blobf(cx,cy,rx,ry,seed):
    def f(tx,ty):
        ang=np.arctan2((ty-cy)/ry,(tx-cx)/rx); r=np.sqrt(((tx-cx)/rx)**2+((ty-cy)/ry)**2)
        return (1+.07*np.sin(3*ang+seed)+.05*np.sin(5*ang+2*seed)-r)*min(rx,ry)
    return f
sh=blobf(24.8,4.9,4.4,2.75,.4)
ICE={(x,y) for x in range(20,30) for y in range(2,8) if sh(x+.5,y+.5)>.25}
for c in [(22,3),(25,4),(27,6)]: ICE.add(c)
T=R+'/windmere/tiles/_2x/'
def tile_for(x,y):
    if (x,y) in ICE:
        h=(x*7+y*13)%9
        nm='ice_plain_b' if sh(x+.5,y+.5)>1.6 else 'ice_plain_a'
        if h in (0,4,7) and (x,y) not in [(22,3),(25,4),(27,6)]: nm=nm.replace('plain','cracked')
        return nm
    ne,sw,nw,se=(x,y-1) in ICE,(x,y+1) in ICE,(x-1,y) in ICE,(x+1,y) in ICE
    s=[k for k,v in zip(['ne','sw','nw','se'],[ne,sw,nw,se]) if v]
    if len(s)==1: return 'shore_snow_ice_edge_'+s[0]
    if len(s)==2 and tuple(s) in [('ne','nw'),('ne','se'),('sw','se'),('sw','nw')]:
        return 'shore_snow_ice_outer_'+{('ne','nw'):'n',('ne','se'):'e',('sw','se'):'s',('sw','nw'):'w'}[tuple(s)]
    if len(s)>=2: return 'ICE'
    for (dx,dy),nm in [((-1,-1),'ne_nw'),((1,-1),'ne_se'),((1,1),'sw_se'),((-1,1),'sw_nw')]:
        if (x+dx,y+dy) in ICE: return 'shore_snow_ice_inner_'+nm
    return None
for _ in range(3):
    add=[(x,y) for x in range(19,31) for y in range(1,9) if (x,y) not in ICE and tile_for(x,y)=='ICE']
    ICE|=set(add)
MAP={}
for x in range(19,31):
    for y in range(1,9):
        t=tile_for(x,y)
        if t: MAP[(x,y)]=t
im=Image.fromarray(cl.astype(np.uint8)).convert('RGBA')
# floor layer composed at kit (_2x) scale, then scaled once -> no per-tile seams
F=128/46; bx0,by0=600,150; CW,CH=int(600*F),int(330*F)
can=Image.new('RGBA',(CW,CH))
for (x,y) in sorted(MAP,key=lambda c:(c[0]+c[1],c[0])):
    p=(cell_top(O,X0,Y0,x,y)-np.array([bx0,by0]))*F; t=Image.open(T+MAP[(x,y)]+'.png')
    can.alpha_composite(t.resize((132,66),Image.LANCZOS),(int(round(p[0]-66)),int(round(p[1]-1))))
for (x,y) in sorted(MAP,key=lambda c:(c[0]+c[1],c[0])):
    p=(cell_top(O,X0,Y0,x,y)-np.array([bx0,by0]))*F; t=Image.open(T+MAP[(x,y)]+'.png')
    can.alpha_composite(t,(int(round(p[0]-64)),int(round(p[1]))))
im.alpha_composite(can.resize((600,330),Image.LANCZOS),(bx0,by0))
def at(tx,ty,dy=0): p=O+(tx+.5-X0)*EX+(ty+.5-Y0)*EY; return p[0],p[1]+dy
GRADE=np.array([.66,.74,.84])
def g(path):
    s=Image.open(path).convert('RGBA'); a=np.array(s).astype(float); a[...,:3]*=GRADE; return Image.fromarray(np.clip(a,0,255).astype(np.uint8))
P2=R+'/windmere/props/_2x/'
for c in [(22,3),(25,4),(27,6)]: put(im,Image.open(P2+'ice_hole.png'),*at(*c,12))
bf=Image.open(R+'/windmere/anim/ice_bob_strip_2x.png'); bw=bf.width//12; bob=bf.crop((3*bw,0,4*bw,bf.height))
props=[]
for c in [(22,3),(25,4),(27,6)]:
    x_,y_=at(*c,12); props.append((y_-6,'bob',x_,y_-4+(bf.height-120)*K*.8))
props.append((0,P2+'fishing_hut.png',*at(20.6,7.5,10),1.25))
for (x,y,n) in [(19.4,6.0,'pine_snow_mid_a'),(19.6,8.3,'pine_snow_small'),(23.0,8.6,'pine_snow_sapling'),(20.2,1.6,'pine_snow_mid_b'),(24.0,1.4,'pine_snow_small')]:
    props.append((0,'/workspace/stasium-pc-look/ship/map_polish/props/_2x/'+n+'.png',*at(x,y,8),1))
for (x,y,n) in [(21.6,8.4,'snow_rocks_b'),(19.8,7.0,'shore_boulder_a'),(23.6,1.8,'snow_rocks_a'),(20.5,3.4,'shore_boulder_a'),(23.6,7.4,'shore_boulder_b'),(28.6,3.0,'shore_boulder_b'),(21.9,2.2,'snow_rocks_a'),(26.0,7.6,'snow_rocks_b'),(29.3,5.2,'snow_rocks_a'),(25.2,2.1,'shore_boulder_a')]:
    props.append((0,P2+n+'.png',*at(x,y,6),1))
props.append((0,P2+'sled.png',*at(22.4,7.9,8),1.1))
props=[(p[3] if p[1]!='bob' else p[0],)+p[1:] for p in props]
for p in sorted(props,key=lambda p:p[0]):
    if p[1]=='bob':
        s=Image.fromarray(np.clip(np.array(bob).astype(float)*np.r_[GRADE,1],0,255).astype(np.uint8)); put(im,s,p[2],p[3],.8)
    else: put(im,g(p[1]),p[2],p[3],p[4])
arr=np.array(im)
# original trees along SE edge stay on top (same rule as v1)
r_,g_,b_=cl[...,0],cl[...,1],cl[...,2]; Lm=(r_+g_+b_)/3; H,W=Lm.shape; yy,xx=np.mgrid[0:H,0:W]
trees=((Lm>118)|((g_>b_-5)&(Lm<90)&(g_>70)))&(xx>880)&(yy>300)&(tx>27)&(ty>5.5)&(tx<31)&(ty<9)
trees=cv2.dilate(trees.astype(np.uint8),np.ones((2,2)))>0
arr[trees,:3]=cl[trees]
im=Image.fromarray(arr)
ij=Image.open('/workspace/scratch/ij_walk/v8/te0/walk/ironjaw_walk_S_f00.png').convert('RGBA'); ij=ij.crop(ij.getbbox())
a_=np.array(ij).astype(float); a_[...,:3]*=np.array([.78,.86,.96]); ij=Image.fromarray(np.clip(a_,0,255).astype(np.uint8))
sc=46/ij.height; ij=ij.resize((round(ij.width*sc),46),Image.LANCZOS)
im.alpha_composite(ij,(868-ij.width//2,359-46))
out=im.convert('RGB'); out.save(R+'/mock_windmere_lake_1280.png')
json.dump({f'{k[0]},{k[1]}':v for k,v in sorted(MAP.items())},open(R+'/windmere/cellmap.json','w'),indent=0)
print('hero px',hero.sum(),'cells',len(MAP))
