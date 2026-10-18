import numpy as np, json, os, math, random
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
R='/workspace/stasium-pc-look/ship/lakes_v1'; P='/workspace/stasium-pc-look/ship/map_polish_2/gamescale/'
MP='/workspace/stasium-pc-look/ship/map_polish/props/'
CAP='/workspace/cloud-agent-artifacts/bc-1acb5d36-2a38-561a-924e-370f130cb048/blightwood_v2/'
rng=np.random.default_rng(7); random.seed(7)
man=[]
def save(img2x, rel, pivot2x, use):
    """img2x master; writes 1x + _2x. pivot bottom-centre."""
    d=os.path.join(R,os.path.dirname(rel)); os.makedirs(os.path.join(d,'_2x'),exist_ok=True)
    w,h=img2x.size
    if w%2: img2x=img2x.crop((0,0,w+1,h)); w+=1
    if h%2: img2x=img2x.crop((0,-1,w,h)); h+=1
    img2x.save(os.path.join(d,'_2x',os.path.basename(rel)))
    img2x.resize((w//2,h//2),Image.LANCZOS).save(os.path.join(R,rel))
    man.append((rel,f'{w//2}x{h//2}',f'{w}x{h}',f'({pivot2x[0]//2},{pivot2x[1]//2}) 1x',use))
def tex(name): return np.array(Image.open(P+'pieces/'+name).convert('RGB')).astype(float)
def tiled(t,W,H,ox=0,oy=0):
    th,tw=t.shape[:2]; yy=(np.arange(H)[:,None]+oy)%th; xx=(np.arange(W)[None,:]+ox)%tw
    return t[yy,xx]
def noise(W,H,s,seed):
    r=np.random.default_rng(seed); n=np.zeros((H,W))
    for k,amp in [(s,1),(s/2,.5),(s/4,.25)]:
        g=r.random((int(H/k)+2,int(W/k)+2)); n+=amp*np.array(Image.fromarray((g*255).astype(np.uint8)).resize((W,H),Image.BICUBIC))/255
    return n/1.75
def diamond_mask(W=128,H=64):
    y,x=np.mgrid[0:H,0:W]; return (np.abs(x-(W-1)/2)/(W/2)+np.abs(y-(H-1)/2)/(H/2)<=1.0)
DM=diamond_mask()
def tile_from(rgb, rel, use):
    a=np.dstack([np.clip(rgb,0,255),DM*255]).astype(np.uint8)
    save(Image.fromarray(a,'RGBA'),rel,(64,64),use)
# ---------- palettes
WD=tex('ground_water_deep.png'); WS=tex('ground_water_shallow.png'); WM=tex('ground_water_mid.png'); GR=tex('ground_grass.png')
def lakeify(t,sat=.85): # pull salt-sea teal towards greener lake
    g=t.mean(2,keepdims=True); t=g+(t-g)*sat; t=t*np.array([.92,1.0,.9]); return t
WD,WS,WM=lakeify(WD),lakeify(WS),lakeify(WM)
def ice(t,seed):
    g=t.mean(2,keepdims=True); t=g+(t-g)*.35  # desaturate (no neon)
    t=t*.45+np.array([168,190,200])*.55
    n=noise(t.shape[1],t.shape[0],24,seed)[...,None]; return t*(.9+.2*n)
SNOW=np.array([226,232,238.])
# ---------- generic field renderer in tile space (used for tiles AND mocks)
def field_rgb(kind, d, W,H, ox,oy, seed):
    """d = signed distance into lake (tiles, >0 inside). returns rgb, alpha-ish"""
    n=noise(W,H,18,seed)
    if kind=='row':
        g=tiled(GR,W,H,ox,oy); s=tiled(WS,W,H,ox,oy); m=tiled(WM,W,H,ox,oy); dp=tiled(WD,W,H,ox,oy)
        dd=d+(n-.5)*.5
        w_m=np.clip((dd-1.0)/1.2,0,1)[...,None]; w_d=np.clip((dd-2.2)/1.2,0,1)[...,None]
        water=s*(1-w_m)+m*w_m; water=water*(1-w_d)+dp*w_d*np.array([.85,.9,.95])
        mud=g*.55+np.array([92,74,48])*.45
        wet=np.clip((dd+.35)/.35,0,1)[...,None]; inw=np.clip(dd/.25,0,1)[...,None]
        shore=g*(1-wet)+mud*wet
        out=shore*(1-inw)+water*inw
        foam=np.exp(-((dd-.12)/.07)**2)[...,None]*(n[...,None]>.45)
        out=out*(1-foam*.35)+np.array([210,220,200])*foam*.35
        return out
    else:
        g=np.ones((H,W,3))*SNOW*(.9+.12*n[...,None]); g-= (noise(W,H,6,seed+1)[...,None]>.62)*np.array([18,14,8])
        i1=ice(tiled(WS,W,H,ox,oy),seed); i2=ice(tiled(WD,W,H,ox,oy),seed+3)*.92
        dd=d+(n-.5)*.4
        w=np.clip((dd-1.2)/1.5,0,1)[...,None]; icec=i1*(1-w)+i2*w
        rim=np.clip((dd+.25)/.3,0,1)[...,None]; inw=np.clip(dd/.2,0,1)[...,None]
        bank=g*(1-rim)+(g*.8+np.array([150,160,170])*.2)*rim
        out=bank*(1-inw)+icec*inw
        return out
def cracks(img, seed, n=6, col=(236,244,248), dark=(96,118,132), sc=None):
    r=random.Random(seed); d=ImageDraw.Draw(img)
    W,H=img.size
    for _ in range(n):
        x,y=r.uniform(0,W),r.uniform(0,H); pts=[(x,y)]
        a=r.uniform(0,6.28)
        for _ in range(r.randint(3,6)):
            a+=r.uniform(-.9,.9); L=r.uniform(4,14)*(sc if sc else W/128); x+=math.cos(a)*L; y+=math.sin(a)*L*.5; pts.append((x,y))
        d.line([(p[0]+1,p[1]+1) for p in pts],fill=dark,width=1); d.line(pts,fill=col,width=1)
    return img
# ---------- 1. TILES
# rowanvale water
for nm,dist,use in [('lake_water_shallow',1.0,'shallow lake water, inner ring'),('lake_water_mid',1.8,'mid lake water'),('lake_water_deep',4,'deep lake water, centre')]:
    for v in 'ab':
        tile_from(field_rgb('row',np.full((64,128),dist),128,64,rng.integers(256),rng.integers(256),hash(nm+v)%999),f'rowanvale/tiles/{nm}_{v}.png',use)
# shore edges: water on side X. distance computed from tile-local coords
y,x=np.mgrid[0:64,0:128]; u=(x/64+y/32)/2; vv=(y/32-x/64)/2+1  # u: 0 at NW edge ->1 SE ; vv: 0 at NE edge ->1 SW (tile space)
EDGE={'n':-(vv+u)+1.0, # unused
}
sides={'ne':(1-vv)*1.4-0.7,'sw':vv*1.4-0.7,'nw':(1-u)*1.4-0.7,'se':u*1.4-0.7}
def shore_set(kind,folder,label):
    for k,d in sides.items():
        tile_from(field_rgb(kind,d*1.6,128,64,rng.integers(256),rng.integers(256),hash(k)%99),f'{folder}/{label}_edge_{k}.png',f'{label}: water/ice on the {k.upper()} side of the cell')
    for a,b in [('ne','nw'),('ne','se'),('sw','se'),('sw','nw')]:
        d=np.maximum(sides[a],sides[b]); tile_from(field_rgb(kind,d*1.6,128,64,0,0,3),f'{folder}/{label}_outer_{a[0]+b[1]}.png'.replace('outer_nw','outer_n').replace('outer_ne','outer_e').replace('outer_sw','outer_w').replace('outer_se','outer_s'),f'{label}: outer corner, water on {a.upper()}+{b.upper()}')
        d=np.minimum(sides[a],sides[b])+.25; tile_from(field_rgb(kind,d*1.6,128,64,0,0,4),f'{folder}/{label}_inner_{a}_{b}.png',f'{label}: inner corner (land only in the {a.upper()}/{b.upper()} wedge opposite), concave bank')
shore_set('row','rowanvale/tiles','shore_grass_water')
# windmere ice
for nm,dist,nc,use in [('ice_plain_a',1.5,0,'plain ice'),('ice_plain_b',3,0,'plain ice, darker deep'),('ice_cracked_a',1.5,5,'cracked ice'),('ice_cracked_b',3,8,'cracked ice, heavy')]:
    rgb=field_rgb('win',np.full((64,128),dist),128,64,rng.integers(256),rng.integers(256),hash(nm)%999)
    im=Image.fromarray(np.clip(rgb,0,255).astype(np.uint8)); im=cracks(im,hash(nm)%77,nc) if nc else im
    tile_from(np.array(im).astype(float),f'windmere/tiles/{nm}.png',use)
shore_set('win','windmere/tiles','shore_snow_ice')
# ---------- 2. PROPS
def fit(img,h=None,w=None):
    img=img.crop(img.getbbox())
    s=(h/img.height) if h else (w/img.width); return img.resize((max(2,round(img.width*s)),max(2,round(img.height*s))),Image.LANCZOS)
def piece(n): return Image.open(P+'pieces/'+n).convert('RGBA')
for src,dst,h,w,use in [('water_reeds.png','reeds_a',76,None,'reed clump at the bank (place on shore_edge cells)'),
    ('lily_pads_a.png','lily_pads_a',None,72,'lily pads, floor-layer decal on shallow water'),('lily_pads_b.png','lily_pads_b',None,60,'lily pads decal'),('lily_pads_c.png','lily_pads_c',None,74,'lily pads decal'),
    ('rowboat.png','rowboat',None,150,'moored rowboat on water next to jetty'),('fishing_stake.png','fishing_stake',84,None,'fishing-spot marker post at bank'),('lake_spot.png','lake_spot_ring',None,120,'lake fishing-spot ripple decal (under lake_jump anim)')]:
    im=fit(piece(src),h=h,w=w); save(im,f'rowanvale/props/{dst}.png',(im.width//2,im.height),use)
im=fit(piece('water_reeds.png'),h=58).transpose(Image.FLIP_LEFT_RIGHT); save(im,'rowanvale/props/reeds_b.png',(im.width//2,im.height),'smaller mirrored reed clump')
# jetty (2x master) - iso planks running NW->SE over 3 cells
def jetty():
    W,H=300,190; im=Image.new('RGBA',(W,H)); d=ImageDraw.Draw(im)
    ux,uy=64,32  # 2x cell step along +x (SE)
    ox,oy=60,40
    r=random.Random(3)
    # posts
    for i in range(4):
        for side in (0,1):
            px=ox+i*ux*0.9+side*-36; py=oy+i*uy*0.9+side*18+28
            d.rectangle([px-5,py-6,px+5,py+38],fill=(70,48,30)); d.rectangle([px-5,py-6,px-1,py+38],fill=(98,70,44))
    for k in range(13):
        t=k/12*3*0.9; cx=ox+t*ux; cy=oy+t*uy+20
        base=r.choice([(140,100,62),(128,90,55),(150,110,70),(120,86,52)])
        poly=[(cx,cy),(cx+12,cy+6),(cx-30,cy+27),(cx-42,cy+21)]
        d.polygon(poly,fill=base); d.line([poly[1],poly[2]],fill=(78,54,34),width=2); d.line([poly[0],poly[3]],fill=tuple(min(255,c+30) for c in base),width=1)
        # side face
        d.polygon([poly[2],poly[1],(poly[1][0],poly[1][1]+7),(poly[2][0],poly[2][1]+7)],fill=(86,60,38))
    # rope coil + small bollard
    d.ellipse([ox+150,oy+70,ox+170,oy+80],outline=(196,170,120),width=3)
    return im.crop(im.getbbox())
im=jetty(); save(im,'rowanvale/props/jetty.png',(im.width//2,im.height),'small wooden jetty, 3 cells long running +x (SE); anchor = south tip of its last cell')
# ---------- windmere props
def hole(r2x=24, dark=True):
    W=int(r2x*2.8); H=int(r2x*1.6); im=Image.new('RGBA',(W,H)); d=ImageDraw.Draw(im)
    cx,cy=W/2,H/2
    d.ellipse([cx-r2x*1.3,cy-r2x*.72,cx+r2x*1.3,cy+r2x*.72],fill=(232,238,242,255))
    d.ellipse([cx-r2x*1.15,cy-r2x*.6,cx+r2x*1.15,cy+r2x*.62],fill=(176,198,210,255))
    d.ellipse([cx-r2x,cy-r2x*.5,cx+r2x,cy+r2x*.5],fill=(24,44,58,255))
    d.ellipse([cx-r2x*.8,cy-r2x*.3,cx+r2x*.9,cy+r2x*.45],fill=(36,64,80,255))
    d.arc([cx-r2x*.6,cy-r2x*.1,cx+r2x*.5,cy+r2x*.3],200,330,fill=(120,150,160,255),width=2)
    for k in range(7): # ice chunks
        a=k/7*6.28+.3; px=cx+math.cos(a)*r2x*1.22; py=cy+math.sin(a)*r2x*.66
        d.polygon([(px-5,py),(px,py-4),(px+6,py+1),(px,py+4)],fill=(244,248,250,255))
    return im.filter(ImageFilter.SMOOTH)
im=hole(); save(im,'windmere/props/ice_hole.png',(im.width//2,im.height),'ice-fishing hole decal (floor layer), centre it on the cell centre; anchor bottom-centre at cell centre y+8 (1x)')
im=hole(16); save(im,'windmere/props/ice_hole_small.png',(im.width//2,im.height),'small ice hole variant')
def sled():
    im=Image.new('RGBA',(150,90)); d=ImageDraw.Draw(im)
    def iso(x,y): return (40+x*1.0-y*1.0, 30+x*.5+y*.5)
    # runners
    for off in (0,22):
        pts=[iso(0,off),iso(80,off)]; d.line([(p[0],p[1]+18) for p in pts],fill=(60,40,26),width=4)
        d.arc([iso(80,off)[0]-6,iso(80,off)[1]+4,iso(80,off)[0]+10,iso(80,off)[1]+20],270,90,fill=(60,40,26),width=4)
    for k in range(5):
        a=iso(k*16,0); b=iso(k*16+13,0); c=iso(k*16+13,24); e=iso(k*16,24)
        d.polygon([a,b,c,e],fill=[(140,96,58),(126,86,52)][k%2]); d.line([b,c],fill=(84,56,34),width=1)
    # load: logs + sack
    d.ellipse([iso(20,6)[0]-14,iso(20,6)[1]-18,iso(20,6)[0]+14,iso(20,6)[1]+2],fill=(156,138,110)); d.line([iso(20,6)[0],iso(20,6)[1]-18,iso(20,6)[0],iso(20,6)[1]-12],fill=(96,80,60),width=2)
    for j in range(3):
        p=iso(48+j*4,4+j*7); d.ellipse([p[0]-14,p[1]-12,p[0]+14,p[1]-2],fill=(110,74,44)); d.ellipse([p[0]+8,p[1]-12,p[0]+16,p[1]-2],fill=(196,160,116))
    # snow dusting
    for k in range(25):
        p=iso(random.uniform(0,80),random.uniform(0,24)); d.ellipse([p[0]-2,p[1]-3,p[0]+2,p[1]-1],fill=(236,240,244))
    return im.crop(im.getbbox())
im=sled(); save(im,'windmere/props/sled.png',(im.width//2,im.height),'wooden sled with sack + logs (1 cell)')
def hut():
    W,H=300,300; im=Image.new('RGBA',(W,H)); d=ImageDraw.Draw(im)
    def iso(x,y,z=0): return (150+x-y, 200+(x+y)*.5-z)
    A,B=100,80; Hh=70
    wood=[(118,82,52),(104,72,46),(132,92,58)]
    # left wall (y face, x=0.. ) : face along x at y=B
    for side,(p0,p1,base) in enumerate([((0,B),(A,B),.85),((A,0),(A,B),1.0)]):
        for k in range(7):
            z0=k*Hh/7; z1=(k+1)*Hh/7
            q=[iso(*p0,z0),iso(*p1,z0),iso(*p1,z1),iso(*p0,z1)]
            c=tuple(int(v*base) for v in wood[k%3]); d.polygon(q,fill=c); d.line([q[0],q[1]],fill=(62,42,28),width=2)
    # door on x-face
    q=[iso(30,B,0),iso(60,B,0),iso(60,B,48),iso(30,B,48)]; d.polygon(q,fill=(64,42,26)); d.line([iso(56,B,24),iso(57,B,24)],fill=(200,170,90),width=3)
    # window warm (painted, low glow)
    q=[iso(A,20,30),iso(A,45,30),iso(A,45,50),iso(A,20,50)]; d.polygon(q,fill=(226,170,92)); d.line([iso(A,32,30),iso(A,32,50)],fill=(70,48,30),width=2)
    # roof
    ridge0,ridge1=iso(-8,B/2,Hh+46),iso(A+8,B/2,Hh+46)
    d.polygon([iso(-8,B+12,Hh-4),iso(A+8,B+12,Hh-4),ridge1,ridge0],fill=(92,70,58))
    d.polygon([iso(A+8,-12,Hh-4),iso(A+8,B+12,Hh-4),ridge1],fill=(78,60,50))
    # snow on roof
    d.polygon([iso(-6,B+6,Hh+2),iso(A+6,B+6,Hh+2),iso(A+8,B/2,Hh+46),iso(-8,B/2,Hh+46)],fill=(232,238,244))
    d.polygon([iso(A+6,-6,Hh+2),iso(A+6,B+6,Hh+2),iso(A+8,B/2,Hh+46)],fill=(206,216,226))
    for k in range(9):
        p=iso(-6+k*14,B+8,Hh); d.ellipse([p[0]-5,p[1]-3,p[0]+5,p[1]+7],fill=(232,238,244))
    # chimney + stack of wood
    c=iso(70,B/2-10,Hh+40); d.rectangle([c[0]-8,c[1]-26,c[0]+8,c[1]+6],fill=(110,104,100)); d.rectangle([c[0]-9,c[1]-30,c[0]+9,c[1]-24],fill=(232,238,244))
    for j in range(4):
        p=iso(A+14,60+j*8,8); d.ellipse([p[0]-8,p[1]-8,p[0]+8,p[1]+4],fill=(120,80,48)); d.ellipse([p[0]+2,p[1]-7,p[0]+9,p[1]+3],fill=(200,164,118))
    # snow at base
    for k in range(16):
        p=iso(k*7,B+2,0) if k<14 else iso(A+2,(k-14)*30,0); d.ellipse([p[0]-8,p[1]-5,p[0]+8,p[1]+4],fill=(228,234,240))
    return im.crop(im.getbbox())
im=hut(); save(im,'windmere/props/fishing_hut.png',(im.width//2,im.height),'ice-fishing hut, 2x2 cells footprint; anchor = south tip of its SE cell; window has a warm painted light (no emissive needed)')
for n in ['snow_rocks_a','snow_rocks_b']:
    im=Image.open(MP+'_2x/'+n+'.png').convert('RGBA'); save(im,f'windmere/props/{n}.png',(im.width//2,im.height),'reused from map_polish (snow-capped rocks, shore scatter)')
def big_rock(seed):
    r=random.Random(seed); im=Image.new('RGBA',(120,90)); d=ImageDraw.Draw(im)
    for k in range(3):
        cx=30+k*28+r.uniform(-6,6); cy=62-r.uniform(0,10); s=r.uniform(18,28)
        pts=[(cx+math.cos(a)*s*r.uniform(.8,1.1),cy+math.sin(a)*s*.7*r.uniform(.8,1.1)) for a in np.linspace(0,6.28,9)[:-1]]
        d.polygon(pts,fill=(98,108,118)); d.polygon([(x,y) for x,y in pts if y<cy+2]+[(cx+s*.6,cy)],fill=(128,138,148))
        d.polygon([(cx-s*.8,cy-s*.3),(cx,cy-s*.75),(cx+s*.8,cy-s*.35),(cx,cy-s*.5)],fill=(234,240,246))
    return im.crop(im.getbbox()).filter(ImageFilter.SMOOTH)
for i in range(2):
    im=big_rock(i+5); save(im,f'windmere/props/shore_boulder_{"ab"[i]}.png',(im.width//2,im.height),'snowy boulder cluster for the lake bank (1 cell)')
# ---------- 3. ANIM: bobbing line (12 frames)
def bob_frames(scale=2):
    fr=[]
    for i in range(12):
        t=i/12*6.28; im=Image.new('RGBA',(48*scale//2*2,80*scale//2*2)); d=ImageDraw.Draw(im); s=scale
        # stick planted in snow at left, bending
        d.line([(6*s,72*s),(10*s,40*s)],fill=(92,62,38),width=2*s); d.ellipse([3*s,68*s,12*s,76*s],fill=(232,238,242))
        bend=math.sin(t)*1.5*s
        tip=(30*s+bend,14*s+abs(math.sin(t))*2*s)
        d.line([(10*s,40*s),(20*s,22*s),tip],fill=(110,78,48),width=max(1,s))
        by=60*s+math.sin(t)*2.2*s; bx=32*s
        d.line([tip,(bx,by)],fill=(220,224,228),width=1)
        d.ellipse([bx-3*s,by-3*s,bx+3*s,by+1*s],fill=(196,64,44)); d.ellipse([bx-3*s,by-1*s,bx+3*s,by+3*s],fill=(236,236,230))
        if math.sin(t)>.6: d.arc([bx-8*s,by,bx+8*s,by+6*s],0,180,fill=(150,176,186),width=1)
        fr.append(im)
    return fr
os.makedirs(R+'/windmere/anim',exist_ok=True)
f2=bob_frames(2); W,H=f2[0].size
st=Image.new('RGBA',(W*12,H)); [st.paste(f,(i*W,0)) for i,f in enumerate(f2)]; st.save(R+'/windmere/anim/ice_bob_strip_2x.png')
st.resize((st.width//2,H//2),Image.LANCZOS).save(R+'/windmere/anim/ice_bob_strip.png')
f1=[f.resize((W//2,H//2),Image.LANCZOS) for f in f2]
bg=[Image.alpha_composite(Image.new('RGBA',f.size,(200,214,222,255)),f).resize((W,H),Image.NEAREST) for f in f1]
bg[0].save(R+'/windmere/anim/ice_bob_preview.gif',save_all=True,append_images=bg[1:],duration=100,loop=0)
meta={'ice_bob':{'frames':12,'fps':10,'1x':{'frame_w':W//2,'frame_h':H//2,'pivot':[16,30]},'_2x':{'frame_w':W,'frame_h':H,'pivot':[32,60]},'note':'pivot = bobber rest point; put it at the ice_hole centre. Stick stands on the snow/ice to the left.'}}
json.dump(meta,open(R+'/windmere/anim/anim_meta.json','w'),indent=1)
os.makedirs(R+'/rowanvale/anim',exist_ok=True)
import shutil
for f in ['lake_jump_strip.png','lake_jump_strip_2x.png','lake_jump_preview.gif']: shutil.copy(P+'anim/'+f,R+'/rowanvale/anim/'+f)
LJ=json.load(open(P+'anim/anim_meta.json'))['lake_jump']; json.dump({'lake_jump':LJ,'note':'copied unchanged from map_polish_2/gamescale/anim'},open(R+'/rowanvale/anim/anim_meta.json','w'),indent=1)
json.dump(man,open(R+'/src/manifest.json','w'))
print(len(man))
