"""atlas_meta.json (gate + loader), props.json (root checker index), props/props.json (props package gate), kit.json (all ids)"""
from ngc import *
import glob, re, datetime
T2=SHIP+'tiles/_2x/'
ids=sorted(os.path.basename(p)[:-4] for p in glob.glob(T2+'*.png'))
PM=json.load(open('tmp/props_meta.json')); RM=json.load(open('tmp/roof_meta.json'))
DATE='2026-10-03'
TILE_ANCHOR="image bottom-centre (64,64)@2x / (32,32)@1x = diamond south tip; diamond centre (64,32)@2x"
def size_of(rel):
    im=Image.open(SHIP+rel); return list(im.size)
tiles=[]; terrace=[]; kit=[]
FAM_NB={'frost_grass':'golden_plains','snow':'frost_grass','crag':'snow (cornice / cliff drop)'}
for i in ids:
    f2=f'tiles/_2x/{i}.png'; f1=f'tiles/{i}.png'; sz2=size_of(f2)
    e=None
    m=re.match(r'^(frost_grass|snow|crag)_edge_(.+)$',i)
    mc=re.match(r'^(frost_grass|snow|crag)_corner_([nesw])$',i)
    mi=re.match(r'^(frost_grass|snow|crag|snow_rock|snow_patch)_([a-d])$',i)
    if m:
        fam,sides=m.group(1),m.group(2).split('_')
        e=dict(id=i,base_terrain=fam,kind='floor',sides=sides,neighbour=FAM_NB[fam],
               note=f'{fam} cell whose {"/".join(sides)} neighbour(s) are {FAM_NB[fam]}: painted irregular boundary on those sides; '
                    'band ends are fixed so it joins its neighbours seamlessly')
        kit.append(dict(id=i,kind='edge',family=fam,side=sides,meets=FAM_NB[fam]))
    elif mc:
        fam,c=mc.group(1),mc.group(2)
        e=dict(id=i,base_terrain=fam,kind='decal',corner=c,neighbour=FAM_NB[fam],layer='ground overlay: draw right after the floor tile of the same cell',
               note=f'draw over a {fam} tile whose diagonal corner {c} touches {FAM_NB[fam]} while both side neighbours are {fam}')
        kit.append(dict(id=i,kind='corner',family=fam,side=c,meets=FAM_NB[fam]))
    elif mi:
        fam,v=mi.group(1),mi.group(2)
        e=dict(id=i,base_terrain={'snow_rock':'snow','snow_patch':'frost_grass'}.get(fam,fam),kind='floor',variant='abcd'.index(v),
               note={'snow':'FULL snow interior - crag tops / high ground only (Northgate snow is light: the common ground is frost_grass + snow_patch); a/b plain (use most), c one grass tuft, d one pebble (use sparingly)',
                     'snow_patch':'the common snowy tile: frost_grass with 2-4 irregular snow patches (~25-40% cover); border band is plain frost grass, so it mixes freely with frost_grass_* and uses the frost_grass edges/corners',
                     'frost_grass':'frosted grass interior - the main Northgate ground',
                     'snow_rock':'snow with granite slabs poking through (crag ground / snow interior variety)',
                     'crag':'crag-top (cliff plateau) interior: wind-packed snow with low granite; a few rocks, mix with snow_a/b'}[fam])
        kit.append(dict(id=i,kind='tile',family=e['base_terrain'] if fam!='snow_patch' else 'frost_grass/snow_patch',side=None,variant=v))
    elif i.startswith('water_ice_edge_'):
        s=i.split('_')[-1]
        e=dict(id=i,base_terrain='water',kind='decal',sides=[s],layer='water overlay: draw after the water floor tile of the same cell',
               note=f'ice shelf hugging the {s} bank of a water cell (land on {s}); snow rim on the bank side, broken plate edge + foam toward open water; stack one per land side')
        kit.append(dict(id=i,kind='overlay',family='water_ice',side=s,role='edge'))
    elif i.startswith('water_ice_corner_'):
        c=i.split('_')[-1]
        e=dict(id=i,base_terrain='water',kind='decal',corner=c,layer='water overlay: draw after the water floor tile of the same cell',
               note=f'ice quarter-shelf at corner {c}: diagonal neighbour {c} is land while both side neighbours are water')
        kit.append(dict(id=i,kind='overlay',family='water_ice',side=c,role='corner'))
    elif re.match(r'^water_ice_[ab]$',i):
        e=dict(id=i,base_terrain='water',kind='decal',variant='ab'.index(i[-1]),layer='water overlay',
               note='a few floating floes for open (interior) water cells; use on ~1 in 3 cells')
        kit.append(dict(id=i,kind='overlay',family='water_ice',side=None,role='interior'))
    elif re.match(r'^frost_overlay_[ab]$',i):
        e=dict(id=i,base_terrain=None,kind='decal',variant='ab'.index(i[-1]),layer='ground overlay over ANY grass floor tile (e.g. golden_plains_*)',
               note='frost rime diamond (alpha 0.2..0.8) that frosts an existing grass tile; shared border band so neighbours join')
        kit.append(dict(id=i,kind='overlay',family='frost_overlay',side=None,role='interior'))
    if e:
        e.update(file=f1,file_2x=f2,size=[sz2[0]//2,sz2[1]//2],size_2x=sz2,anchor=TILE_ANCHOR)
        assert sz2==[128,64],(i,sz2)
        tiles.append(e); kit[-1].update(file_2x=f2,file_1x=f1,size_2x=sz2,anchor_px_2x=[64,64],footprint=[1,1]); continue
    # ---- terrace / cliff pieces ----
    mf=re.match(r'^crag_cliff_(left|right)_h([123])$',i)
    ms=re.match(r'^crag_side_(left|right)_(top|a|b|base_ground)$',i)
    ml=re.match(r'^crag_lip_(left|right)$',i)
    mlc=re.match(r'^crag_lip_corner_(front|left|right)$',i)
    if mf:
        side,n=mf.group(1),int(mf.group(2)); edge='SW' if side=='left' else 'SE'
        e=dict(id=i,kind='face',edge=edge,height_steps=n,step_px_2x=20,offset_2x=[-64,0] if edge=='SW' else [0,0],
               tile_axis='x' if edge=='SW' else 'y',foot='snow',draw='before_top',
               note=f'one-piece granite face for a {n}-step drop on the cell\'s {edge} ({side}) edge: snow cap along the top lip, snow banked at the foot. '
                    'offset from the LIFTED cell centre (2x)')
        kit.append(dict(id=i,kind='cliff_face',family='crag',side=side,height_steps=n))
    elif ms:
        side,v=ms.groups(); edge='SW' if side=='left' else 'SE'
        e=dict(id=i,kind='face',edge=edge,height_steps=1,step_px_2x=20,offset_2x=[-64,0] if edge=='SW' else [0,0],step_offset_2x=[0,20],
               tile_axis='x' if edge=='SW' else 'y',foot='snow' if v=='base_ground' else None,draw='before_top',
               strip=v,note='crosshaven_art.gd side-strip slot (<terrain>_side_<face>_<top|a|b|base_ground>): strip k is drawn at offset_2x + k*step_offset_2x; '
                            'k=0 top, odd k a, even k b, last k (>0) base_ground. Snow ledge on each strip top hides the stacking joint')
        kit.append(dict(id=i,kind='cliff_face',family='crag',side=side,height_steps=1,strip=v))
    elif ml:
        side=ml.group(1); edge='SW' if side=='left' else 'SE'
        e=dict(id=i,kind='overhang',edge=edge,height_steps=None,offset_2x=[-64,-8] if edge=='SW' else [0,-8],tile_axis='x' if edge=='SW' else 'y',
               draw='after_top',note='snow cornice hanging over the cliff edge: one size for every height; the cell front edge runs through canvas y 8..40; '
                                     'draw after the top tile on every crag cell edge that has a face below')
        kit.append(dict(id=i,kind='overlay',family='crag',side=side,role='cliff_lip'))
    elif mlc:
        v=mlc.group(1); vert={'front':'S','left':'W','right':'E'}[v]
        off={'S':[-20,20],'W':[-84,-12],'E':[44,-12]}[vert]
        e=dict(id=i,kind='corner',vertex=vert,height_steps=None,offset_2x=off,pivot_px_2x=[20,12],draw='after_top',
               note=f'40x40 cornice cap for the {vert} vertex of the lifted cell (pivot canvas (20,12) = that vertex); '
                    + {'S':'use where the left and right lips meet','W':'use where a left lip ends (no face beyond)','E':'use where a right lip ends'}[vert])
        kit.append(dict(id=i,kind='overlay',family='crag',side=v,role='cliff_lip_corner'))
    else:
        raise SystemExit('unclassified '+i)
    e.update(file=f1,file_2x=f2,size_2x=sz2,size=[sz2[0]//2,sz2[1]//2])
    terrace.append(e); kit[-1].update(file_2x=f2,file_1x=f1,size_2x=sz2,anchor_px_2x=None,offset_2x=e['offset_2x'])
# ---- props ----
props=[]; pj=[]; ppj=[]
for pid,m in PM.items():
    m=dict(m); m.pop('blocks',None)
    fp=m['footprint_cells']
    props.append(dict(id=pid,kind=m['kind'],layer=m['layer'],file=m['file'],file_2x=m['file_2x'],size=m['size'],size_2x=m['size_2x'],
        footprint_size=fp,anchor_cell_from_nw=[fp[0]-1,fp[1]-1],anchor=f"image bottom-centre = south tip of the footprint's south-most cell (canvas ({m['anchor_px_2x'][0]},{m['anchor_px_2x'][1]}) at 2x)",
        art_x_from_anchor_2x=m['art_x_from_anchor_2x'],art_height_px_2x=m['art_height_px_2x'],note=m['note'],
        **{k:m[k] for k in ('axis','slope','shear_applied','hole_px_2x','use','height_steps_20px') if k in m}))
    pj.append(dict(id=pid,file_2x=m['file_2x'],file_1x=m['file'],size_2x=m['size_2x'],size_1x=m['size'],footprint_cells=fp,
        anchor_px_2x=m['anchor_px_2x'],anchor_px_1x=m['anchor_px_1x'],emissive='no',art_height_px_2x=m['art_height_px_2x'],
        art_x_from_anchor_2x=m['art_x_from_anchor_2x'],lowest_opaque_gap_px_2x=m['lowest_opaque_gap_px_2x'],kind=m['kind'],layer=m['layer']))
    ppj.append(dict(pj[-1],file_2x='_2x/'+pid+'.png',file_1x=pid+'.png'))
    sub='drift' if m['kind']=='drift' else 'crag_rock'
    kit.append(dict(id=pid,kind='prop',family=sub,side=m.get('axis'),file_2x=m['file_2x'],file_1x=m['file'],size_2x=m['size_2x'],
        anchor_px_2x=m['anchor_px_2x'],footprint=fp,height_px_2x=m['art_height_px_2x'],layer=m['layer']))
# ---- roof caps + swatch (not 128x64: listed here, not gated) ----
roof=[]
for rid,m in RM.items():
    m=dict(m)
    if m.get('coverage') in ('patchy','dust'):
        m['default']=True; m['placement']='DEFAULT light cap: broken band in the TOP THIRD of the slope (fractions 0.03..0.36 of the ridge->eave depth), no eave lip / icicles'
    elif m.get('coverage')=='full':
        m['default']=False; m['placement']='OPTION (deep winter): full slope from ~5% below the ridge to the eave, lip/icicles hang below the eave'
    roof.append(m)
    kit.append(dict(id=rid,kind='roof_cap',family='roof_snow',side=m.get('slope'),file_2x=m['file_2x'],file_1x=m['file'],size_2x=m['size_2x'],
        anchor_px_2x=None,footprint=None,lip_px_2x=m['lip_px_2x']))
sw=dict(id='frost_tint_swatch',kind='overlay',file='overlays/frost_tint_swatch.png',file_2x='overlays/_2x/frost_tint_swatch.png',size=[256,256],size_2x=[512,512],
        tileable=True,note='screen/world-space tileable frost rime (straight alpha, mean 0.37); lay over grass via a shader (sample at world_px/512 @2x) or a modulate pass')
kit.append(dict(id='frost_tint_swatch',kind='overlay',family='frost_overlay',side=None,file_2x=sw['file_2x'],file_1x=sw['file'],size_2x=[512,512],anchor_px_2x=None,footprint=None,role='tileable_swatch'))
atlas=dict(format='stasium.art_atlas',format_version=1,region='northgate',package='outskirts_themes/northgate',date=DATE,
    root='res://art/world/outskirts/northgate/',
    scope='PC-only painted 2D iso theme kit for the Crosshaven open-world outskirts (PR #241): Northgate snow + crags. Same grid, file layout and anchors as art/world/crosshaven (crosshaven_art.gd texture(kind,id)).',
    grid={'tile_w':64,'tile_h':32,'height_step_px':10,'step_px_2x':20,'cell_to_local':'((x-y)*32, (x+y)*16 - elev*10)',
          'sides':{'nw':[-1,0],'ne':[0,-1],'se':[1,0],'sw':[0,1]},'corners':{'n':[-1,-1],'e':[1,-1],'s':[1,1],'w':[-1,1]}},
    files={'primary':'1x PNG at <kind>/<id>.png, drawn at scale 1','masters':'2x PNG at <kind>/_2x/<id>.png, draw at scale 0.5 (identical placement)',
           'kinds':['tiles','props','roof','overlays'],'filter':'linear','mipmaps':False,'premultiplied':False},
    anchors={'tile':TILE_ANCHOR,'terrace':'offset_2x from the LIFTED cell centre (2x); faces drawn before the top tile, lips/corners after',
             'prop':"image bottom-centre on the SOUTH tip of the footprint's south-most cell; 2x1 drifts run back to (x-1,y)"},
    autotile={'grass_side':'golden_plains (repo art/world/crosshaven/tiles) is what frost_grass meets',
              'chain':'golden_plains -> frost_grass_edge_* -> frost_grass / snow_patch (the common ground) -> snow_edge_* -> snow (crag tops / high ground only)',
              'interior_mix':{'frost_grass':'frost_grass_a..d (+ a few snow_patch_*)','frost_snowy (same edges as frost_grass)':'snow_patch_a..d ~70% + frost_grass_a/b ~30%','snow':'snow_a/b common, snow_c/d rare - crag tops / high ground only'},
              'edges':'<family>_edge_<sides in order nw,ne,se,sw> = floor tile used INSTEAD of the interior when those side neighbours are the outer terrain',
              'corners':'<family>_corner_<n|e|s|w> = decal over the floor when only that diagonal neighbour is the outer terrain',
              'joins':{'frost_grass':['frost_grass','snow','crag','water'],'snow_patch':'same as frost_grass (it IS frost_grass for autotiling)','snow':['snow','crag','water'],'crag':['crag']},
              'water':'water cells keep the repo water_a..d floor; add water_ice_edge_<side> per land side, water_ice_corner_<c> per land-only diagonal, water_ice_a/b on ~1/3 of open cells'},
    lighting={'key':'top-left (left/SW faces lit, right/SE faces in cool shade)','shadows':'contact AO only (alpha<=0.3), no cast shadows'},
    tiles=tiles,terrace=terrace,props=props,roof_caps=roof,swatches=[sw],
    not_checked_by_world_gate='roof_caps[] and swatches[] are not 128x64 tiles / props, so the world checker lists their PNGs as unreferenced (WARN, intended)')
json.dump(atlas,open(SHIP+'atlas_meta.json','w'),indent=1)
json.dump(dict(package='outskirts_themes/northgate',version=1,date=DATE,scale='2:1 iso, cell top face 128x64 at 2x (Crosshaven world scale); fighter ~124 px tall at 2x',
    anchor="canvas px of the footprint south tip (bottom-centre); for 2x1 drifts the anchor cell is the FRONT cell and the footprint runs back to (x-1,y)",
    contact_shadow='baked soft cool ellipse under rock bases (alpha<=0.30, inside the footprint); drifts carry none (they are ground overlays)',
    props=pj),open(SHIP+'props.json','w'),indent=1)
json.dump(dict(package='outskirts_themes/northgate/props',version=1,date=DATE,layout='world kit: <id>.png (1x) + _2x/<id>.png (2x master)',props=ppj),open(SHIP+'props/props.json','w'),indent=1)
json.dump(dict(package='outskirts_themes/northgate',date=DATE,layout='world kit (<kind>/<id>.png 1x + <kind>/_2x/<id>.png 2x); see README',
    kinds='tile|edge|corner|cliff_face|overlay|prop|roof_cap',count=len(kit),ids=kit),open(SHIP+'kit.json','w'),indent=1)
from collections import Counter
print('tiles',len(tiles),'terrace',len(terrace),'props',len(props),'roof',len(roof),'kit',len(kit),Counter(k['kind'] for k in kit))
