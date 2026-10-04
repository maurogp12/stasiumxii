"""mock_northgate: ~14x10 iso patch: golden_plains -> frost_grass -> frost_snowy (frost grass + snow_patch, the common ground),
   full snow only on/around the crag high ground, snowy crag 2-3 steps, frozen pond,
   drifts along a fence and at tree bases, 2 cottages with masked roof snow, crag props. Rendered at 2x and 1x."""
from ngengine import *
from roofsnow import snow_roof
from PIL import ImageDraw, ImageFont
os.makedirs(PREV,exist_ok=True); os.makedirs(B+'tmp/mock/_2x',exist_ok=True)
NX,NY=14,10
def nz(x,y): return ((x*7919+y*104729)%13)/13.0
cells={}
for x in range(NX):
    for y in range(NY):
        u=x-y+(nz(x,y)-0.5)*1.6
        t='golden_plains' if u<-3.2 else ('frost_grass' if u<-1.2 else 'frost_snowy')
        cells[(x,y)]=dict(t=t,h=0)
# snowy crag: plateau h2 with an h3 shoulder at the back right
for (x,y) in [(9,0),(10,0),(11,0),(12,0),(13,0),(9,1),(10,1),(11,1),(12,1),(13,1),(10,2),(11,2),(12,2),(13,2),(12,3),(13,3)]:
    cells[(x,y)]=dict(t='crag',h=2)
for (x,y) in [(11,0),(12,0),(13,0),(12,1),(13,1)]:
    cells[(x,y)]['h']=3
cells[(13,4)]=dict(t='crag',h=1); cells[(11,3)]=dict(t='crag',h=1)
# frozen pond
for (x,y) in [(4,0),(5,0),(6,0),(4,1),(5,1),(6,1),(7,1),(5,2),(6,2)]:
    cells[(x,y)]=dict(t='water',h=0)
# direction update: full snow only on and around the crag high ground (the cells touching it)
CR=[k for k,c in cells.items() if c['t']=='crag']
for (x,y),c in cells.items():
    if c['t'] in ('frost_grass','frost_snowy') and any(abs(x-a)+abs(y-b)<=1 for a,b in CR): c['t']='snow'
# a little frost overlay on golden cells touching frost (shows frost_overlay_a/b on repo grass)
for (x,y),c in (cells.items() if False else []):
    if c['t']=='golden_plains':
        if any(cells.get((x+dx,y+dy),{}).get('t')=='frost_grass' for dx,dy in ((1,0),(0,-1),(-1,0),(0,1))):
            c['deco']=[T('frost_overlay_'+'ab'[(x+y)%2])]
# snowy cottages (README roof recipe applied to the real repo sprites)
def bake(png,cap,side,name,sh):
    arr=snow_roof(REPO+'props/_2x/'+png+'.png',cap,side,shade=sh)
    p2=B+f'tmp/mock/_2x/{name}.png'; Image.fromarray(arr).save(p2)
    Image.fromarray(half_rgba(arr)).save(B+f'tmp/mock/{name}.png'); return p2
# direction update: light caps (patchy / dust, broken band in the top third) are the default
cotA=bake('cottage_slate','roof_snow_patchy_a','left','cottage_slate_snow',1.0)
cotB=bake('cottage_slate_b','roof_snow_dust_a','right','cottage_slate_b_snow',0.95)
P=lambda i: SHIP+'props/_2x/'+i+'.png'
RP=lambda i: REPO+'props/_2x/'+i+'.png'
props=[]
def add(f,x,y,decal=False): props.append(dict(file=f,x=x,y=y,decal=decal))
# cottages: 2x2, anchor = nw+(1,1)
add(cotA,2,4); add(cotB,8,6)
# fence line along +x at y=8 with drifts at its base (2-cell wall drifts + 1-cell fence drift)
for x in range(3,10): add(RP('fence'),x,8)
add(P('drift_wall_long_a'),4,8,True); add(P('drift_wall_long_c'),6,8,True); add(P('drift_fence_a'),7,8,True); add(P('drift_wall_long_b'),9,8,True)
# pines with ring drifts
for (x,y,r) in [(10,5,'a'),(12,7,'b'),(7,4,'a'),(1,1,'b'),(13,9,'a')]:
    add(P('drift_tree_ring_'+r),x,y,True); add(RP('tree_pine'),x,y)
# loose drifts
add(P('drift_patch_a'),10,9,True); add(P('drift_patch_b'),5,5,True); add(P('drift_patch_a'),2,8,True)
# crag props
add(P('crag_spire_a'),13,3)          # 2x2 on the plateau (12..13, 2..3)
add(P('crag_outcrop_b'),12,1)        # 2x2 on the h3 shoulder (11..12, 0..1)
add(P('crag_boulders_a'),9,3); add(P('crag_boulders_c'),11,6); add(P('crag_outcrop_c'),12,5)
add(P('crag_cairn_flag'),8,3); add(P('crag_split_shrub'),4,4); add(P('crag_boulders_d'),3,2)
add(P('crag_boulders_b'),10,1)
for sc,name in ((2,'mock_northgate.png'),(1,'mock_northgate_1x.png')):
    can,_=render(cells,props,scale=sc,faces='hN',pad=(int(150*sc/2),int(30*sc/2),int(30*sc/2),int(30*sc/2)),bg=(128,126,118,255))
    can.convert('RGB').save(PREV+name)
    print(name,can.size)
json.dump(dict(cells=[dict(x=x,y=y,**{k:v for k,v in c.items() if k!='deco'}) for (x,y),c in sorted(cells.items())],
               props=[dict(file=os.path.relpath(p['file'],'/workspace'),x=p['x'],y=p['y'],layer='ground_overlay' if p['decal'] else 'prop') for p in props]),
          open(PREV+'mock_northgate_layout.json','w'),indent=0)
