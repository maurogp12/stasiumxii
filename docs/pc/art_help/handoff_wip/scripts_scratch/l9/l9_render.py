import json
from PIL import Image, ImageDraw, ImageFont
SRC='/workspace/scratch/l9_src/'
T=SRC+'art/maps/arena_colosseum_v2/tiled/tiles/'
OUT='/workspace/stasium-pc-look/previews/l9_outdoor_board/'
L=json.load(open(OUT+'layout.json'))
N=15
elev={(c['x'],c['y']):c['height'] for c in L['cells']}
terr={(c['x'],c['y']):c['terrain'] for c in L['cells']}
props={}
for p in L['props']:
    props.setdefault(tuple(p['cells'][0]),[]).append(p['kind'])
for k,v in props.items():
    print(k, v, terr[k], elev[k])
def tex_for(t,e):
    z=e
    while z>=0:
        f=f"{t}.png" if z==0 else f"{t}_e{z}.png"
        try: return Image.open(T+f).convert('RGBA'), f
        except FileNotFoundError: z-=1
def placement(im):
    w,h=im.size; half=w//2; cb=-1; right=False
    px=im.load()
    for y in range(h):
        for x in range(half):
            if px[x,y][3]/255>0.03: cb=y;break
        for x in range(half,w):
            if px[x,y][3]/255>0.03: right=True;break
    if right or cb<0: return None
    return (0,0,half,cb+1),(-32,-16,half*2,(cb+1)*2)
PROPF={"ruins":"prop_ruins.png","well":"prop_well.png","hay":"prop_hay.png","fence":"prop_fence.png","rubble":"prop_rubble.png","rock_pillar":"prop_rock_pillar.png","floor_seal":"prop_floor_seal.png"}
TINT=(0.896,0.949,0.912)  # jungle canopy tint on terrain only (jungle_backdrop.gd _apply_canopy_tint)
def mul(im,t):
    r,g,b,a=im.split()
    r=r.point(lambda v:int(v*t[0])); g=g.point(lambda v:int(v*t[1])); b=b.point(lambda v:int(v*t[2]))
    return Image.merge('RGBA',(r,g,b,a))
def render(tint=True, bg=(58,78,46,255), skirt=True):
    OX,OY=520,150; W,H=1040,700
    can=Image.new('RGBA',(W,H),bg)
    if skirt:
        dr=ImageDraw.Draw(can)
        r=2.2*0.72  # solid part of the earth lip
        def iso(fx,fy): return (OX+(fx-fy)*32, OY+(fx+fy)*16)
        lo,hi=-0.5-r,N-0.5+r
        dr.polygon([iso(lo,lo),iso(hi,lo),iso(hi,hi),iso(lo,hi)],fill=(46,38,20,255))
    order=sorted(elev.keys(), key=lambda c:((c[0]+c[1])*10+elev[c]*8, c[1], c[0]))
    for c in order:
        x,y=c; e=elev[c]
        cx=OX+(x-y)*32; cy=OY+(x+y)*16-e*10
        im,f=tex_for(terr[c],e)
        pl=placement(im)
        src,dst=pl
        piece=im.crop(src).resize((dst[2],dst[3]),Image.BILINEAR)
        if tint: piece=mul(piece,TINT)
        can.alpha_composite(piece,(int(cx+dst[0]),int(cy+dst[1])))
        for p in props.get(c,[]):
            pim=Image.open(T+PROPF[p]).convert('RGBA')
            w,h=pim.size
            can.alpha_composite(pim,(int(cx-w/2),int(cy+16-h)))
    return can
can=render()
can.save(OUT+'current_board_render_1x.png')
can.resize((can.width*2,can.height*2),Image.LANCZOS).save(OUT+'current_board_render.png')
print('ok')
