import json
from PIL import Image, ImageDraw, ImageFont
OUT='/workspace/stasium-pc-look/previews/l9_outdoor_board/'
L=json.load(open(OUT+'layout.json'))
N=15
elev={(c['x'],c['y']):c['height'] for c in L['cells']}
terr={(c['x'],c['y']):c['terrain'] for c in L['cells']}
props={}
for p in L['props']: props.setdefault(tuple(p['cells'][0]),[]).append(p['kind'])
F='/usr/share/fonts/truetype/dejavu/'
fB=lambda s: ImageFont.truetype(F+'DejaVuSans-Bold.ttf',s)
fR=lambda s: ImageFont.truetype(F+'DejaVuSans.ttf',s)
TOP={'ground':[(214,190,128),(150,190,95),(95,160,70)],'mud':[(132,88,48)],'water':[(70,150,200)]}
SIDE_L=0.72; SIDE_R=0.55
PCOL={'ruins':(200,40,40),'fence':(150,90,30),'hay':(240,190,0),'rubble':(120,120,130),'rock_pillar':(110,40,160),'floor_seal':(0,150,140),'well':(30,90,220)}
PAB={'ruins':'T','fence':'F','hay':'C','rubble':'R','rock_pillar':'P','floor_seal':'S','well':'W'}
PNAME={'ruins':'ruins = tower (64x112)','fence':'fence (64x64)','hay':'hay = coin stack (64x72)','rubble':'rubble = stone/crate pile (64x52)','rock_pillar':'rock_pillar = obelisk (64x100)','floor_seal':'floor_seal = ground sigil (64x48)','well':'well (64x80)'}
def shade(c,k): return tuple(int(v*k) for v in c)
def topcol(c):
    t=terr[c]; e=elev[c]
    return TOP[t][min(e,len(TOP[t])-1)]
# ---------- ISO panel at 2x (cell 128x64, 20 px per height step) ----------
S=2; HW=32*S; HH=16*S; STEP=10*S
OX=HW*N+60; OY=230
W=2*HW*N+120+560; H=OY+2*HH*N+HH+120
im=Image.new('RGB',(W,H),(32,36,40)); d=ImageDraw.Draw(im)
def P(x,y,e): return (OX+(x-y)*HW, OY+(x+y)*HH-e*STEP)
order=sorted(elev, key=lambda c:((c[0]+c[1])*10+elev[c]*8,c[1],c[0]))
for c in order:
    x,y=c; e=elev[c]; cx,cy=P(x,y,e)
    top=(cx,cy-HH); r=(cx+HW,cy); b=(cx,cy+HH); l=(cx-HW,cy)
    col=topcol(c)
    if e>0:
        dz=e*STEP
        d.polygon([l,b,(b[0],b[1]+dz),(l[0],l[1]+dz)],fill=shade(col,SIDE_L),outline=(20,20,20))
        d.polygon([b,r,(r[0],r[1]+dz),(b[0],b[1]+dz)],fill=shade(col,SIDE_R),outline=(20,20,20))
        for k in range(1,e):
            d.line([(l[0],l[1]+k*STEP),(b[0],b[1]+k*STEP),(r[0],r[1]+k*STEP)],fill=(30,30,30),width=1)
    d.polygon([top,r,b,l],fill=col,outline=(25,25,25))
    lab=f"{terr[c][0].upper()}{e}"
    d.text((cx,cy-6),lab,fill=(0,0,0),font=fB(17),anchor='mm')
    d.text((cx,cy+13),f"{x},{y}",fill=(40,40,40),font=fR(11),anchor='mm')
# props on top (footprint outline + letter flag)
for c,ks in props.items():
    x,y=c; e=elev[c]; cx,cy=P(x,y,e)
    pts=[(cx,cy-HH+5),(cx+HW-9,cy),(cx,cy+HH-5),(cx-HW+9,cy)]
    col=PCOL[ks[-1]]
    d.line(pts+[pts[0]],fill=col,width=5)
    for i,k in enumerate(ks):
        bx=cx-18+i*30 if len(ks)>1 else cx-3
        bx=cx+ (i-(len(ks)-1)/2)*30
        by=cy-HH-22
        d.line([(bx,by+10),(bx,cy-HH+4)],fill=PCOL[k],width=3)
        d.ellipse([bx-13,by-13,bx+13,by+13],fill=PCOL[k],outline=(255,255,255),width=2)
        d.text((bx,by),PAB[k],fill=(255,255,255),font=fB(16),anchor='mm')
# axes
d.text(P(-1.3,-1.3,0),"(0,0)",fill=(230,230,230),font=fB(16),anchor='mm')
ax0=P(0,-1.6,0); ax1=P(5,-1.6,0); d.line([ax0,ax1],fill=(255,200,120),width=3); d.text((ax1[0]+10,ax1[1]-12),"+x (screen E / down-right)",fill=(255,200,120),font=fB(16))
ay0=P(-1.6,0,0); ay1=P(-1.6,5,0); d.line([ay0,ay1],fill=(160,220,255),width=3); d.text((ay1[0]-300,ay1[1]-10),"+y (screen S / down-left)",fill=(160,220,255),font=fB(16))
d.text((30,20),"Crosshaven 15x15 (map_id crosshaven_15) - PC combat board, origin/pc/combat-look 7997915",fill=(255,255,255),font=fB(26))
d.text((30,58),"Iso at 2x: each top diamond is exactly 128x64 px, height step = 20 px at 2x (10 px at 1x). Label = terrain letter + height; small = x,y.",fill=(220,220,220),font=fR(19))
d.text((30,84),"G ground (MP1)  M mud (MP2)  W water (MP2)   - no lava on this map.  Ground colour: tan z0, light green z1, green z2.",fill=(220,220,220),font=fR(19))
d.text((30,110),"Props: ALL are paint_only (1 cell, NOT blocking move, LoS or cover; fighters can stand on them). Anchor: image bottom-centre on cell south tip.",fill=(255,210,160),font=fR(19))
d.text((30,136),"Counts: ground 177 (159 z0, 16 z1, 2 z2), mud 30 (z0), water 18 (z0); 33 prop sprites on 30 cells.",fill=(220,220,220),font=fR(19))
# legend
lx=W-540; ly=OY+40
d.text((lx,ly-34),"Prop legend (kind, 1x tex px)",fill=(255,255,255),font=fB(20))
cnt={}
for p in L['props']: cnt[p['kind']]=cnt.get(p['kind'],0)+1
for i,k in enumerate(['ruins','rock_pillar','hay','rubble','fence','floor_seal','well']):
    yy=ly+i*40
    d.ellipse([lx,yy,lx+26,yy+26],fill=PCOL[k],outline=(255,255,255),width=2)
    d.text((lx+13,yy+13),PAB[k],fill=(255,255,255),font=fB(16),anchor='mm')
    d.text((lx+40,yy+3),f"{PNAME[k]}  x{cnt[k]}",fill=(235,235,235),font=fR(18))
yy=ly+7*40+20
for t,cols in (('ground z0',TOP['ground'][0]),('ground z1',TOP['ground'][1]),('ground z2',TOP['ground'][2]),('mud z0',TOP['mud'][0]),('water z0',TOP['water'][0])):
    d.rectangle([lx,yy,lx+26,yy+20],fill=cols,outline=(0,0,0)); d.text((lx+40,yy),t,fill=(235,235,235),font=fR(18)); yy+=30
d.text((lx,yy+10),"Stacked props on one cell (drawn in this order):",fill=(255,210,160),font=fR(16))
d.text((lx,yy+32),"(0,6) fence+hay  (0,14) ruins+fence  (8,14) hay+fence",fill=(255,210,160),font=fR(16))
d.text((lx,yy+54),"(8,14) hay+fence sits on a WATER cell; (12,1) rubble on MUD.",fill=(255,210,160),font=fR(16))
im.save(OUT+'layout_ref.png')
# ---------- top-down panel ----------
C=64; M=70
td=Image.new('RGB',(M+C*N+40+520,M+C*N+60),(32,36,40)); d=ImageDraw.Draw(td)
for (x,y),e in elev.items():
    x0=M+x*C; y0=M+y*C
    d.rectangle([x0,y0,x0+C,y0+C],fill=topcol((x,y)),outline=(20,20,20))
    d.text((x0+6,y0+4),f"{terr[(x,y)][0].upper()}{e}",fill=(0,0,0),font=fB(18))
    if (x,y) in props:
        ks=props[(x,y)]
        for i,k in enumerate(ks):
            cx=x0+C-18-i*26; cy=y0+C-18
            d.ellipse([cx-12,cy-12,cx+12,cy+12],fill=PCOL[k],outline=(255,255,255),width=2)
            d.text((cx,cy),PAB[k],fill=(255,255,255),font=fB(14),anchor='mm')
for i in range(N):
    d.text((M+i*C+C/2,M-20),str(i),fill=(255,200,120),font=fB(16),anchor='mm')
    d.text((M-22,M+i*C+C/2),str(i),fill=(160,220,255),font=fB(16),anchor='mm')
d.text((M,12),"Top-down (x across, y down). Screen: (0,0)=top corner, +x=down-right, +y=down-left.",fill=(255,255,255),font=fB(18))
lx=M+C*N+40; ly=M+10
for i,k in enumerate(['ruins','rock_pillar','hay','rubble','fence','floor_seal','well']):
    yy=ly+i*36
    d.ellipse([lx,yy,lx+24,yy+24],fill=PCOL[k],outline=(255,255,255),width=2)
    d.text((lx+12,yy+12),PAB[k],fill=(255,255,255),font=fB(14),anchor='mm')
    d.text((lx+36,yy+2),PNAME[k],fill=(235,235,235),font=fR(17))
td.save(OUT+'layout_ref_topdown.png')
print(im.size, td.size)
