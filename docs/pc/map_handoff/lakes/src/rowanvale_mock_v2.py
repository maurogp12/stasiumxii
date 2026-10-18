exec(open('/workspace/stasium-pc-look/ship/lakes_v1/src/common.py').read())
import json, random
from PIL import ImageDraw
from scipy import ndimage
O=np.array([842.5,258.5]); X0,Y0=20,2
img,cl,tx,ty,rect=clean('lake_spots_rowanvale.png',O,20,30,2,9)
r_,g_,b_=[cl[...,i] for i in range(3)]
plot=(r_>g_+15)&(r_<200)&(b_<110)
plot=ndimage.binary_opening(plot,iterations=1)   # plot pixels (dark furrowed soil), kept untouched
plot=ndimage.binary_dilation(plot,iterations=1)
_cm=json.load(open(R+'/rowanvale/cellmap_v2.json'))['cells'] if 'cells' in json.load(open(R+'/rowanvale/cellmap_v2.json')) else {}
CELLS=[tuple(map(int,k.split(','))) for k,v in _cm.items() if v['water']>=0.2]
cx=np.floor(tx).astype(int); cy=np.floor(ty).astype(int)
inc=np.zeros(cl.shape[:2],bool)
for c in CELLS: inc|=(cx==c[0])&(cy==c[1])
lake=inc&~ndimage.binary_dilation(plot,iterations=2)
lake=ndimage.binary_opening(lake,iterations=3); lake=ndimage.binary_closing(lake,iterations=3)
lab,n=ndimage.label(lake); sz=ndimage.sum(lake,lab,range(1,n+1)); lake=np.isin(lab,[i+1 for i,z in enumerate(sz) if z>250])
lake=ndimage.gaussian_filter(lake.astype(float),2.5)>.5
yy_,xx_=np.mgrid[0:lake.shape[0],0:lake.shape[1]]; lake&=~((((xx_-836)/22.)**2+((yy_-352)/11.)**2)<1)   # Ironjaw stands on a dry grass point
din=ndimage.distance_transform_edt(lake); dout=ndimage.distance_transform_edt(~lake)
d=(din-dout)/23.0      # tiles
H,W=d.shape
g=globals()
for nm in ['WD','WS','WM','GR']:
    t=g[nm]; g[nm]=np.array(Image.fromarray(np.clip(t,0,255).astype(np.uint8)).resize((92,92),Image.LANCZOS)).astype(float)
f=field_rgb('row',d*6.0,W,H,0,0,11)
al=np.clip((d+.2)/.2,0,1)
lipm=((d>-.08)&(d<.02))[...,None]; nn=noise(W,H,4,9)[...,None]
f=np.where(lipm,np.array([96,72,44.])*(.8+.4*nn),f); al=np.where(lipm[...,0],1.0,al); al=np.where(d<-.08,0,al)
dk=np.clip(d/.6,0,1)[...,None]*(d>0)[...,None]; f=f*(1-.28*dk)*np.where(d[...,None]>0,np.array([.86,.92,.94]),1)
wt=(np.clip(d*3.5,0,1)*.6+.15)[...,None]*(d>.02)[...,None]
f=f*(1-wt)+np.array([34,84,92.])*wt
res=cl*(1-al[...,None])+f*al[...,None]
res[plot]=cl[plot]
im=Image.fromarray(np.clip(res,0,255).astype(np.uint8)).convert('RGBA')
# pebbles on the bank (only on grass, never on plot pixels)
rr=random.Random(4); dr=ImageDraw.Draw(im)
ys_,xs_=np.nonzero((d>-.22)&(d<-.1)&~ndimage.binary_dilation(plot,iterations=4))
for k in range(0,len(xs_),max(1,len(xs_)//45)):
    x_,y_=xs_[k],ys_[k]; s_=rr.uniform(2,4)
    dr.ellipse([x_-s_,y_-s_*.6,x_+s_,y_+s_*.6],fill=(118,116,108)); dr.ellipse([x_-s_*.7,y_-s_*.75,x_+s_*.5,y_],fill=(150,146,136))
def at(tx_,ty_,dy=0): p=O+(tx_+.5-X0)*EX+(ty_+.5-Y0)*EY; return p[0],p[1]+dy
P2=R+'/rowanvale/props/_2x/'
LJ=json.load(open(R+'/rowanvale/anim/anim_meta.json'))['lake_jump']['_2x']; fr=Image.open(R+'/rowanvale/anim/lake_jump_strip_2x.png')
fish=fr.crop((7*LJ['frame_w'],0,8*LJ['frame_w'],LJ['frame_h']))
def okspot(x,y): return not plot[int(y)-2:int(y)+2,int(x)-6:int(x)+6].any()
floor=[]; up=[]
for c in [(21.8,6.5),(24.1,6.1)]:
    x,y=at(*c,4); floor.append((P2+'lake_spot_ring.png',x,y,.55))
x,y=at(21.8,6.5,4); up.append((fish,x,y+(LJ['frame_h']-LJ['pivot'][1])*K*.6,.6))
for (x_,y_,n) in [(22.4,6.3,'lily_pads_a'),(23.4,5.5,'lily_pads_b'),(25.4,7.3,'lily_pads_c'),(21.4,8.2,'lily_pads_b')]:
    x,y=at(x_,y_,3)
    if d[int(y),int(x)]>.25: floor.append((P2+n+'.png',x,y,.9))
cand=[(20.9,6.0,'reeds_a'),(23.0,4.9,'reeds_b'),(25.9,5.9,'reeds_a'),(26.0,7.4,'reeds_b'),(21.0,7.4,'reeds_b'),(22.3,9.0,'reeds_a'),(24.6,8.0,'reeds_b'),(24.0,6.9,'reeds_a')]
for (x_,y_,n) in cand:
    x,y=at(x_,y_,0)
    if -0.35<d[int(y),int(x)]<0.15 and okspot(x,y): up.append((P2+n+'.png',x,y,1))
x,y=at(25.0,6.9,6)
if d[int(y)-4,int(x)]>.1: up.append((P2+'rowboat.png',x,y,.8))
x,y=at(24.2,6.5,0)
if okspot(x,y+3): up.append((P2+'fishing_stake.png',x+12,y+4,1))
for (s,x,y,sc) in floor: put(im,Image.open(s) if isinstance(s,str) else s,x,y,sc)
ij=Image.open('/workspace/scratch/ij_walk/v8/te0/walk/ironjaw_walk_S_f00.png').convert('RGBA'); ij=ij.crop(ij.getbbox())
sc=46/ij.height; ij=ij.resize((round(ij.width*sc),46),Image.LANCZOS)
up.append((('IJ',ij),836,354,1))
for (s,x,y,sc) in sorted(up,key=lambda q:q[2]):
    if isinstance(s,tuple): im.alpha_composite(s[1],(int(x-s[1].width/2),int(y-s[1].height)))
    else: put(im,Image.open(s) if isinstance(s,str) else s,x,y,sc)
im.convert('RGB').save(R+'/mock_rowanvale_lake_1280.png')
# check: plot pixels left untouched (except under the hero sprite / small props that were already decor-free spots)
fin=np.array(Image.open(R+'/mock_rowanvale_lake_1280.png')).astype(float)
pm=plot&(np.abs(tx-25)<8)&(np.abs(ty-6)<6)
chg=(np.abs(fin-cl).sum(2)>30)&pm
print('plot px in area',int(pm.sum()),'changed',int(chg.sum()))
yy2,xx2=np.mgrid[0:H,0:W]; heroz=(np.abs(xx2-836)<26)&(yy2>300)&(yy2<360)
print('plot px changed outside hero sprite',int((chg&~heroz).sum()),'plot px under water',int((plot&(al>0.05)).sum()))
chk=np.array(Image.open(R+'/mock_rowanvale_lake_1280.png')).astype(float); chk[plot]=chk[plot]*.35+np.array([255,0,255])*.65
Image.fromarray(chk.astype(np.uint8)).save(R+'/rowanvale_plots_check_1280.png')
cm={}
for a_ in range(18,29):
  for b_ in range(1,11):
    m_=(cx==a_)&(cy==b_)
    if m_.sum()>200:
      wf=float((d[m_]>0).mean())
      if wf>0: cm[f'{a_},{b_}']={'water':round(wf,2),'plot':round(float(plot[m_].mean()),2)}
json.dump({'spots':[[21.8,6.5],[24.1,6.1]],'cells':cm},open(R+'/rowanvale/cellmap_v2.json','w'),indent=0)
water_cells=sorted({(int(a),int(b)) for a,b in zip(cx[d>.15],cy[d>.15])})
print('water cells',water_cells)
json.dump({'cells_with_water':water_cells},open(R+'/rowanvale/lake_cells_v2.json','w'))
