import json, collections
from PIL import Image
SRC='/workspace/scratch/l9_src/'
TILED=SRC+'art/maps/arena_colosseum_v2/tiled/'
OUT='/workspace/stasium-pc-look/previews/l9_outdoor_board/'
d=json.load(open(TILED+'crosshaven_15x15_tags.json'))
N=d['size'][0]
PROPS={"ruins":"prop_ruins.png","well":"prop_well.png","hay":"prop_hay.png","fence":"prop_fence.png","rubble":"prop_rubble.png","rock_pillar":"prop_rock_pillar.png","floor_seal":"prop_floor_seal.png"}
LOOKS={"ruins":"round stone watchtower with conical brown roof (the 'tower')","fence":"wooden post-and-rail fence section","hay":"stacked gold discs on a gold base (the 'coin stack')","rubble":"grey stone blocks (the 'crate'/rock pile)","rock_pillar":"tall thin grey stone obelisk/pillar","floor_seal":"flat gold compass/sigil ring on the ground","well":"stone well with wooden roof frame"}
cells=[]; elev={}; terr={}
for c in d['cells']:
    cells.append({"x":c['x'],"y":c['y'],"terrain":c['terrain'],"height":c['elevation']})
    elev[(c['x'],c['y'])]=c['elevation']; terr[(c['x'],c['y'])]=c['terrain']
props=[]
for c in d['cells']:
    for i,p in enumerate(c.get('paint_only',[])):
        im=Image.open(TILED+'tiles/'+PROPS[p])
        bb=im.convert('RGBA').getchannel('A').getbbox()
        props.append({"kind":p,"cells":[[c['x'],c['y']]],"footprint":[1,1],"stack_index":i,
            "cell_terrain":c['terrain'],"cell_height":c['elevation'],
            "texture":"res://art/maps/arena_colosseum_v2/tiled/tiles/"+PROPS[p],
            "texture_px":list(im.size),"alpha_bbox":list(bb),
            "anchor":"image bottom-centre on the cell's south tip (tile local (0,+16)); draw at tile_local(-w/2, 16-h), lifted with the tile by height*10",
            "blocks_move":False,"blocks_los":False,"cover":False,"snap_wall":False,
            "looks_like":LOOKS[p]})
# exposed faces (screen-visible: left face under sw edge -> neighbour (x,y+1); right face under se edge -> neighbour (x+1,y))
faces=[]
for (x,y),e in elev.items():
    if e==0: continue
    for side,(nx,ny) in (("left_sw",(x,y+1)),("right_se",(x+1,y))):
        ne=elev.get((nx,ny),0)
        if e>ne: faces.append({"cell":[x,y],"side":side,"steps":e-ne,"neighbour":[nx,ny],"neighbour_terrain":terr.get((nx,ny),"off_board")})
out={"map_id":"crosshaven_15","source":"art/maps/arena_colosseum_v2/tiled/crosshaven_15x15_tags.json @ origin/pc/combat-look 7997915",
 "size":[N,N],"coords":"x right-down (screen E), y left-down (screen S); cell_to_local=((x-y)*32,(x+y)*16-height*10) at 1x; screen N=up-right",
 "terrain_types_supported":{"ground":{"mp":1,"walkable":True},"mud":{"mp":2,"walkable":True},"water":{"mp":2,"walkable":True},"lava":{"mp":0,"walkable":False}},
 "terrain_counts":dict(collections.Counter(c['terrain'] for c in cells)),
 "height_counts":{str(k):v for k,v in sorted(collections.Counter(c['height'] for c in cells).items())},
 "terrain_height_counts":{f"{t}@{h}":v for (t,h),v in sorted(collections.Counter((c['terrain'],c['height']) for c in cells).items())},
 "cells":cells,"props":props,"visible_cliff_faces":faces}
json.dump(out,open(OUT+'layout.json','w'),indent=1)
print(out['terrain_counts'],out['height_counts'],len(props))
print(collections.Counter(f['steps'] for f in faces), len(faces))
for f in faces:
    if f['steps']>1 or f['neighbour_terrain']!='ground': print(f)
# adjacency of raised cells
for (x,y),e in sorted(elev.items(), key=lambda k:(k[0][1],k[0][0])):
    if e>0:
        nb=[elev.get((x+dx,y+dy),None) for dx,dy in ((-1,0),(0,-1),(1,0),(0,1))]
        print((x,y),e,'nbrs nw,ne,se,sw',nb,[terr.get((x+dx,y+dy)) for dx,dy in ((-1,0),(0,-1),(1,0),(0,1))])
