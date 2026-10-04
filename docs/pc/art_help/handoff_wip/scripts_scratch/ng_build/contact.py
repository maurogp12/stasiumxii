"""contact_sheet.png: every piece at 2x on neutral grey, labelled, 1-cell grid, fighter-height bar (124 px @2x)"""
from ngc import *
from PIL import ImageDraw, ImageFont
F=lambda n: ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',n)
fl,fs,ft=F(11),F(13),F(20)
BG=(128,128,128,255); GRID=(150,150,150,255); INK=(22,22,26); FIGH=124
KIT=json.load(open(SHIP+'kit.json'))['ids']
byid={k['id']:k for k in KIT}
def im2(i): return Image.open(SHIP+byid[i]['file_2x']).convert('RGBA')
def diamond(d,cx,cy,w=128,h=64,col=GRID,width=1):
    d.line([(cx,cy-h/2),(cx+w/2,cy),(cx,cy+h/2),(cx-w/2,cy),(cx,cy-h/2)],fill=col,width=width)
def fp_poly(d,ax,ay,fx,fy,col=(170,170,170,255)):
    for i in range(fx):
        for j in range(fy):
            cx=ax+(-i+j)*64; cy=ay-32+(-i-j)*32; diamond(d,cx,cy,col=col)
blocks=[]   # (title, list of (label, draw_fn(can,d,x,y), w, h))
def tile_items(ids, under=None):
    out=[]
    for i in ids:
        def fn(can,d,x,y,i=i):
            if under: can.alpha_composite(Image.open(under).convert('RGBA'),(x+11,y+8))
            can.alpha_composite(im2(i),(x+11,y+8)); diamond(d,x+11+64,y+8+32)
        out.append((i,fn,150,84))
    return out
W=1700
ids=[k['id'] for k in KIT]
ground=[i for i in ids if byid[i]['kind']=='tile']
blocks.append(('A  Ground tiles (128x64 @2x): frost_grass = main ground, snow_patch = common snowy tile, snow_* = crag tops / high ground only',tile_items(ground)))
for fam,nb in (('frost_grass','golden_plains'),('snow','frost_grass'),('crag','snow / cliff drop')):
    e=[i for i in ids if byid[i]['kind'] in ('edge','corner') and byid[i]['family']==fam]
    under=SHIP+'tiles/_2x/'+{'frost_grass':'frost_grass_a','snow':'snow_a','crag':'snow_b'}[fam]+'.png'
    items=[]
    for i in e:
        u=under if byid[i]['kind']=='corner' else None
        items+=tile_items([i],u)
    blocks.append((f'B/C  {fam} edges + corners (meets {nb}; corners shown over the {fam} floor)',items))
ice=[i for i in ids if byid[i]['family']=='water_ice']
blocks.append(('E  Ice overlays (shown over repo water_a)',tile_items(ice,REPO+'tiles/_2x/water_a.png')))
fo=['frost_overlay_a','frost_overlay_b']
blocks.append(('D  Frost overlays: diamond decals bare, then over repo golden_plains_a',tile_items(fo)+[(i+' / golden_plains_a',f,w,h) for (i,f,w,h) in tile_items(fo,REPO+'tiles/_2x/golden_plains_a.png')]))
# cliffs
cl=[]
for i in [i for i in ids if byid[i]['kind']=='cliff_face' or byid[i].get('role') in ('cliff_lip','cliff_lip_corner')]:
    k=byid[i]; im=im2(i); off=k.get('offset_2x') or [0,0]
    def fn(can,d,x,y,i=i,im=im,off=off):
        # lifted cell centre at (x+90, y+40); piece drawn at centre + offset
        cx,cy=x+90,y+44
        diamond(d,cx,cy)
        can.alpha_composite(im,(int(cx+off[0]),int(cy+off[1])))
    cl.append((i,fn,180,150))
blocks.append(('C  Crag cliff faces (h1..h3), loader side strips, cornice lips + lip corners (drawn at their offset from the lifted cell, outlined)',cl))
# props
pr=[]
for i in [i for i in ids if byid[i]['kind']=='prop']:
    k=byid[i]; im=im2(i); fx,fy=k['footprint']; w,h=im.size
    def fn(can,d,x,y,i=i,im=im,fx=fx,fy=fy,w=w,h=h,k=k):
        ax=x+max(w,192)//2+6; ay=y+394
        fp_poly(d,ax,ay,fx,fy)
        can.alpha_composite(im,(ax-w//2,ay-h))
        d.ellipse([ax-2,ay-2,ax+2,ay+2],fill=(200,40,40,255))
        d.text((x+4,ay+4),f"fp {fx}x{fy}  h {k['height_px_2x']}px",fill=INK,font=fl)
    pr.append((i,fn,max(w,192)+16,420))
blocks.append(('F/H  Props: crag rocks + snow drifts (footprint outlined, red dot = anchor / south tip)',pr))
rc=[]
for i in [i for i in ids if byid[i]['kind']=='roof_cap']:
    im=im2(i)
    def fn(can,d,x,y,i=i,im=im):
        d.rectangle([x+6,y+6,x+6+im.width,y+6+im.height],outline=(150,150,150,255))
        can.alpha_composite(im,(x+6,y+6))
    rc.append((i,fn,im.width+20,im.height+24))
sw=Image.open(SHIP+'overlays/_2x/frost_tint_swatch.png').convert('RGBA')
def fsw(can,d,x,y):
    g=Image.open(REPO+'tiles/_2x/golden_plains_a.png').convert('RGBA')
    can.alpha_composite(sw,(x+6,y+6))
rc.append(('frost_tint_swatch (512x512 tileable, alpha)',fsw,530,530))
blocks.append(('G/D  Roof snow caps: patchy_a / dust_a = DEFAULT (top-third band), full_* + pre-sheared left/right = deep-winter option; frost tint swatch',rc))
# ---- layout ----
def layout(blocks):
    y=70; pos=[]
    for title,items in blocks:
        pos.append(('T',title,20,y)); y+=30
        x=20+30; rowh=0
        for lab,fn,w,h in items:
            if x+w>W-20: x=50; y+=rowh+18; rowh=0
            pos.append(('I',(lab,fn,w,h),x,y)); x+=w+8; rowh=max(rowh,h)
        y+=rowh+34
    return pos,y
pos,Ht=layout(blocks)
can=Image.new('RGBA',(W,Ht+20),BG); d=ImageDraw.Draw(can)
d.text((20,16),'NORTHGATE theme kit (snow + crags) - contact sheet, all pieces at 2x on neutral grey; grey diamonds = 1 cell (128x64 @2x); bar = fighter height 124 px @2x',fill=INK,font=fs)
d.text((20,38),'layout: world kit  <kind>/<id>.png (1x) + <kind>/_2x/<id>.png (2x)   |   ship/outskirts_themes/northgate/',fill=INK,font=fl)
for kind,data,x,y in pos:
    if kind=='T':
        d.text((x,y),data,fill=INK,font=fs)
        # fighter bar at the start of each block
        d.rectangle([x+4,y+26,x+14,y+26+FIGH],fill=(60,60,70,255)); d.text((x+16,y+26+FIGH-12),'',fill=INK,font=fl)
    else:
        lab,fn,w,h=data
        fn(can,d,x,y)
        d.text((x+4,y+h+1),lab,fill=INK,font=fl)
can.convert('RGB').save(PREV+'contact_sheet.png')
print(can.size)
