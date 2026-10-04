"""mini renderer for the Northgate theme kit (world-kit placement rules, 2x or 1x)"""
from ngc import *
_cache={}
def img(path, scale=2):
    key=(path,scale)
    if key not in _cache:
        if scale==2: p=path
        else: p=path.replace('/_2x/','/')
        _cache[key]=Image.open(p).convert('RGBA')
    return _cache[key]
def T(i): return SHIP+'tiles/_2x/'+i+'.png'
def RT(i): return REPO+'tiles/_2x/'+i+'.png'
def h(x,y,k): return (((x*73856093)^(y*19349663)^(x*y*83492791))&0x7fffffff)%k
SIDES=['nw','ne','se','sw']; SIDE_DIR={'nw':(-1,0),'ne':(0,-1),'se':(1,0),'sw':(0,1)}
CORNERS={'n':((-1,-1),'nw','ne'),'e':((1,-1),'ne','se'),'s':((1,1),'se','sw'),'w':((-1,1),'sw','nw')}
INTERIOR={'golden_plains':[RT('golden_plains_'+k) for k in 'abcd']+[RT('golden_plains_golden_a'),RT('golden_plains_flowers_a')],
          'frost_grass':[T('frost_grass_'+k) for k in 'abcd']+[T('snow_patch_a'),T('snow_patch_b'),T('frost_grass_a'),T('snow_patch_d')],
          # the common snowy ground (direction update): frost grass + snow patches; uses the frost_grass edges
          'frost_snowy':[T('snow_patch_'+k) for k in 'abcd']+[T('snow_patch_a'),T('snow_patch_b'),T('frost_grass_a'),T('frost_grass_b'),T('snow_patch_d')],
          'snow':[T('snow_a'),T('snow_b'),T('snow_a'),T('snow_b'),T('snow_c'),T('snow_a'),T('snow_b'),T('snow_d'),T('snow_a'),T('snow_b')],
          'crag':[T('crag_a'),T('snow_a'),T('crag_b'),T('snow_b'),T('crag_c'),T('snow_a'),T('snow_rock_b'),T('snow_b')],
          'water':[RT('water_'+k) for k in 'abcd']}
JOINS={'frost_grass':{'frost_grass','frost_snowy','snow','crag','water'},'frost_snowy':{'frost_grass','frost_snowy','snow','crag','water'},'snow':{'snow','crag','water'},'crag':{'crag'},'water':{'water'}}
PREFIX={'frost_grass':'frost_grass','frost_snowy':'frost_grass','snow':'snow','crag':'crag'}
def pick(cells,x,y):
    c=cells[(x,y)]; t=c['t']
    pieces=INTERIOR[t]; floor=pieces[h(x,y,len(pieces))]
    decals=[]
    if t=='golden_plains': return floor,decals
    def joins(nx,ny):
        n=cells.get((nx,ny))
        if n is None: return True
        if t=='crag': return n['t']=='crag'
        return n['t'] in JOINS[t]
    g=[s for s in SIDES if not joins(x+SIDE_DIR[s][0],y+SIDE_DIR[s][1])]
    if t=='water':
        for s in g: decals.append(T('water_ice_edge_'+s))
        for cn,(off,s1,s2) in CORNERS.items():
            if s1 in g or s2 in g: continue
            if not joins(x+off[0],y+off[1]): decals.append(T('water_ice_corner_'+cn))
        if h(x,y,3)==0: decals.append(T('water_ice_'+'ab'[h(y,x,2)]))
        return floor,decals
    if g: floor=T(PREFIX[t]+'_edge_'+'_'.join(g))
    for cn,(off,s1,s2) in CORNERS.items():
        if s1 in g or s2 in g: continue
        if not joins(x+off[0],y+off[1]): decals.append(T(PREFIX[t]+'_corner_'+cn))
    return floor,decals
def render(cells, props, scale=2, pad=(300,80,80,80), bg=(0,0,0,0), faces='strips', lips=True, overlays=None, layered=True):
    """cells {(x,y):{t,h}}; props [{file,x,y,(decal)}] anchored bottom-centre on the south tip of (x,y)"""
    s=scale/2.0
    xs=[k[0] for k in cells]; ys=[k[1] for k in cells]
    n=max(xs)+1; m=max(ys)+1
    maxh=max(c['h'] for c in cells.values())
    W=int(((n+m)*64)*s+pad[2]+pad[3]); H=int(((n+m)*32+maxh*20)*s+pad[0]+pad[1])
    ox=int(m*64*s)+pad[2]; oy=pad[0]+int(maxh*20*s)
    can=Image.new('RGBA',(W,H),bg)
    items=[]
    for (x,y),c in cells.items(): items.append(((x+y)*10+c['h']*8,0,y,x,'cell',(x,y)))
    for i,p in enumerate(props):
        c=cells[(p['x'],p['y'])]
        z=(p['x']+p['y'])*10+c['h']*8
        if layered:
            # world rule: ground layer (floors, decals, faces) -> ground overlays (drifts) -> y-sorted props
            z=z+(100000 if p.get('decal') else 200000)
        items.append((z,1 if p.get('decal') else 2,p['y'],p['x'],'prop',p))
    items.sort(key=lambda t:t[:4])
    def put(path,x,y):
        im=img(path,scale); can.alpha_composite(im,(int(round(x)),int(round(y))))
    for z,ph,y,x,kind,data in items:
        if kind=='cell':
            c=cells[data]; hh=c['h']
            cx=ox+(x-y)*64*s; cy=oy+((x+y)*32-hh*20)*s
            st=(cx,cy+32*s)
            for face,(dx,dy) in (('left',(0,1)),('right',(1,0))):
                nb=cells.get((x+dx,y+dy)); nh=nb['h'] if nb else 0
                steps=hh-nh
                if steps<=0: continue
                fam=c.get('face','crag')
                bx=-64*s if face=='left' else 0
                if faces=='strips':
                    for k in range(steps):
                        var='top' if k==0 else ('b' if k%2==0 else 'a')
                        if k==steps-1 and k>0: var='base_ground'
                        put(T(f'{fam}_side_{face}_{var}'),st[0]+bx,st[1]+(-32+20*k)*s)
                else:
                    put(T(f'{fam}_cliff_{face}_h{min(3,steps)}'),st[0]+bx,st[1]-32*s)
            floor,decals=pick(cells,x,y)
            put(floor,cx-64*s,cy-32*s)
            for d in decals: put(d,cx-64*s,cy-32*s)
            for d in c.get('deco',[]): put(d,cx-64*s,cy-32*s)
            if lips and c['t']=='crag':
                for face,(dx,dy) in (('left',(0,1)),('right',(1,0))):
                    nb=cells.get((x+dx,y+dy)); nh=nb['h'] if nb else 0
                    if hh>nh:
                        im=img(T(f'crag_lip_{face}'),scale)
                        put(T(f'crag_lip_{face}'),cx+(-64*s if face=='left' else 0),cy-LIP_UP*s)
                def has_lip(px,py,face):
                    cc=cells.get((px,py))
                    if not cc or cc['t']!='crag': return False
                    dx,dy=(0,1) if face=='left' else (1,0)
                    nb=cells.get((px+dx,py+dy)); return cc['h']>(nb['h'] if nb else 0)
                L=has_lip(x,y,'left'); Rr=has_lip(x,y,'right')
                PIV=(20,12)
                if L and Rr: put(T('crag_lip_corner_front'),cx-PIV[0]*s,cy+(32-PIV[1])*s)
                if L and not (has_lip(x-1,y,'left') and cells[(x-1,y)]['h']==hh): put(T('crag_lip_corner_left'),cx+(-64-PIV[0])*s,cy-PIV[1]*s)
                if Rr and not (has_lip(x,y-1,'right') and cells[(x,y-1)]['h']==hh): put(T('crag_lip_corner_right'),cx+(64-PIV[0])*s,cy-PIV[1]*s)
        else:
            p=data; c=cells[(p['x'],p['y'])]; hh=c['h']
            cx=ox+(p['x']-p['y'])*64*s; cy=oy+((p['x']+p['y'])*32-hh*20)*s
            im=img(p['file'],scale)
            can.alpha_composite(im,(int(round(cx-im.width/2)),int(round(cy+32*s-im.height))))
    return can,(ox,oy)
LIP_UP=8
