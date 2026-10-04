"""Write raw/wp10a/manifest.json + MANIFEST.md: every WP10a pair-1 asset (Rowanvale + Windmere).

Source of truth for ids, canvases, anchors, footprints, sway/emit/strip flags and processing hints.
Spec: docs/pc/ZONES_BUILD_SPEC.md @ a4f667e, section WP10a (+ WP10 style rules). Sizes: Stasium Bot.
"""
from __future__ import annotations
import json
from pathlib import Path

OUT = Path('/workspace/stasium-pc-look/raw/wp10a')

# size classes: (1x w,h), (2x w,h)
SIZE = {
    'tile':   ((64, 32), (128, 64)),
    'small':  ((64, 64), (128, 128)),
    'tree':   ((64, 112), (128, 224)),
    # Stasium Bot gives 96x80 / 192x160 for 2x1, but a 2x1 footprint spans -64..+32 px (1x) around its south tip,
    # so a bottom-centred 96 px canvas cannot hold it. Default here: 128x80 (bottom-centre rule kept). See conflicts.
    'wide':   ((128, 80), (256, 160)),
    'landmark': ((128, 192), (256, 384)),
    'hero':   ((192, 256), (384, 512)),
    # border sizes are NOT in the Stasium Bot list: proposed (1x1 footprint, art overlaps neighbours like border_forest_*)
    'border_low':  ((96, 80), (192, 160)),
    'border_tall': ((96, 128), (192, 256)),
}
SWAY_PAD_1X = {'tree': 10, 'bush': 6, 'hedge': 8, 'pine_wall': 8}


def footprint(fx, fy):
    cells = [[x, y] for y in range(fy) for x in range(fx)]
    ac = [fx - 1, fy - 1]
    bc = [((fx - 1) - (fy - 1)) * 32, ((fx - 1) + (fy - 1)) * 16 + 16]
    # footprint centre relative to the south tip (1x): where a free-standing object's ground contact goes
    centre = [(-fx / 2 + fy / 2) * 32, (-fx / 2 - fy / 2) * 16]
    span = [-fy * 32, fx * 32]  # x extent of the footprint diamond around the south tip (1x)
    return dict(footprint_size=[fx, fy], footprint_from_nw=cells, anchor_cell_from_nw=ac,
                bottom_centre_from_nw_centre_1x=bc, footprint_centre_from_anchor_1x=centre,
                footprint_x_span_from_anchor_1x=span)


ALIASES = {
    'tree_apple_orchard': ('apple_tree_a.png', 'apple_tree.png'),
    'tree_apple_orchard_fruiting': ('apple_tree_fruit.png', 'apple_tree_fruiting.png', 'apple_tree_b.png'),
    'tree_pear': ('pear_tree.png',),
    'tree_stump_old': ('stump.png',),
    'fence_orchard_nwse': ('fence_nwse.png', 'wooden_fence_nwse.png'),
    'fence_orchard_nesw': ('fence_nesw.png', 'wooden_fence_nesw.png'),
    'hay_bale_round': ('hay_bale.png',),
    'scarecrow_field': ('scarecrow.png',),
    'bush_flower_meadow': ('flower_bush.png',),
    'old_windmill_body': ('windmill_body.png',),
    'tree_pine_snowy_a': ('snowy_pine_a.png', 'snowy_pine.png'),
    'tree_pine_snowy_b': ('snowy_pine_b.png',),
    'tree_pine_frozen_blue': ('frozen_blue_pine.png', 'frozen_pine.png'),
    'snow_drift': ('snowdrift.png',),
    'pillar_ruin_white': ('white_pillar_ruin.png', 'pillar_ruin.png'),
    'ice_crystal_cluster': ('ice_crystals.png',),
    'lantern_post_warm': ('warm_lantern_post.png', 'lantern_post.png'),
    'shrub_frozen': ('frozen_shrub.png',),
    'border_snowy_pine_wall': ('snowy_pine_wall.png', 'pine_wall.png'),
    'frost_spire': ('frostspire.png',),
}


def asset(region, aid, kind, size, fp=(1, 1), *, blocks=True, walkable=False, layer='props', sway=None, emit=None,
          strip=None, standin=None, brief='', art_h_2x=None, base_fill=0.2, contact=True, raw=None, base_terrain=None,
          variant=None, extra=None, flags=(), aliases=()):
    (w1, h1), (w2, h2) = SIZE[size]
    d = dict(id=aid, region=region, kind=kind, size_class=size, size=[w1, h1], size_2x=[w2, h2])
    if kind == 'tile':
        d.update(file=f'tiles/{aid}.png', file_2x=f'tiles/_2x/{aid}.png', base_terrain=base_terrain, variant=variant,
                 walkable=walkable, blocks=blocks, layer='ground',
                 anchor='image bottom-centre (32,32) = diamond south tip; diamond centre = (32,16)',
                 anchor_px=[w1 / 2, h1], anchor_px_2x=[w2 / 2, h2], raw=raw, raw_bg='swatch (seamless square, top-down)',
                 alpha='Crosshaven floor alpha: 64x32 diamond with 0.5 px alpha bleed on the diagonal edges')
    else:
        d.update(file=f'props/{aid}.png', file_2x=f'props/_2x/{aid}.png', walkable=walkable, blocks=blocks, layer=layer,
                 anchor=f'image bottom-centre = south tip of cell origin+{list(footprint(*fp)["anchor_cell_from_nw"])}',
                 anchor_px=[w1 / 2, h1], anchor_px_2x=[w2 / 2, h2],
                 y_sort_origin_from_bottom_1x=[0, -16], raw=raw or f'{aid}.png',
                 raw_bg='flat white #FFFFFF' if region == 'rowanvale' else 'flat black #000000',
                 raw_aliases=list(aliases) or list(ALIASES.get(aid, ())),
                 process=dict(art_h_2x=art_h_2x, base_fill=base_fill, contact_shadow=contact, contact='axis' if aid.startswith(('fence_', 'stone_wall_')) or aid.endswith(('_nwse', '_nesw')) else 'base'))
        d.update(footprint(*fp))
    d['sway'] = sway
    d['emit'] = emit
    d['strip'] = strip
    d['standin_crosshaven'] = standin
    d['brief'] = brief
    if extra:
        d.update(extra)
    d['flags'] = list(flags)
    return d


def sway(kind, amp_1x, pin):
    pad = SWAY_PAD_1X[kind]
    return dict(mask=f'animated/sway_masks/<id>_swaymask.png (+ _2x/)', strip='animated/<id>_sway.png (+ _2x/)',
                shadow_strip='animated/shadows/<id>_shadow_sway.png (+ _2x/)', frames=16, fps=8,
                pad_1x=pad, amp_1x=amp_1x, pin_frac=pin,
                note='Crosshaven convention: 16 frames @ 8 fps, frame = static canvas + pad each side, same bottom-centre anchor')


def emit_spec(rule, strength, covers):
    return dict(file='props/emit/<id>_emit.png (1x size = half the 2x master; + _2x/)', rule=rule, roi_2x=None,
                glow_pass_raw='<id>_glow.png (optional, recommended): same framing as the main paint, black except the glow',
                strength_default=strength, covers=covers,
                note='8-bit greyscale data texture (linear), rgb += albedo * emit * strength; glow fades in at night like lamp_glow')


R, W = 'rowanvale', 'windmere'

rowanvale = [
    # ---- ground (one swatch per material -> diamond variants) ----
    *[asset(R, f'meadow_{v}', 'tile', 'tile', base_terrain='meadow', variant=i, walkable=True, blocks=False, raw='meadow_swatch.png',
            standin='golden_plains', brief='sunny meadow grass, short clumps, clover, tiny wildflowers') for i, v in enumerate('abc')],
    *[asset(R, f'orchard_soil_{v}', 'tile', 'tile', base_terrain='orchard_soil', variant=i, walkable=True, blocks=False,
            raw='orchard_soil_swatch.png', standin='farm_soil', brief='packed orchard earth with leaf litter, a few fallen leaves, sparse grass') for i, v in enumerate('ab')],
    *[asset(R, f'tilled_rows_{v}', 'tile', 'tile', base_terrain='tilled_rows', variant=i, walkable=True, blocks=False,
            raw='tilled_rows_swatch.png', standin='farm_plowed', brief='ploughed furrows running exactly parallel to the swatch edge, whole number of rows per swatch',
            extra=dict(row_axis='rows along +x (nwse) after projection; a nesw set can be derived by rotating the swatch 90 deg (light shifts, see notes)')) for i, v in enumerate('ab')],
    # ---- props ----
    asset(R, 'tree_apple_orchard', 'prop', 'tree', sway=sway('tree', 4.0, 0.42), standin='tree_apple', art_h_2x=200, base_fill=0.15,
          brief='orchard apple tree, round leafy canopy, short sturdy trunk, no fruit'),
    asset(R, 'tree_apple_orchard_fruiting', 'prop', 'tree', sway=sway('tree', 4.0, 0.42), standin='tree_apple', art_h_2x=200, base_fill=0.15,
          brief='same species, canopy dotted with red apples, 2-3 apples in the grass at the foot'),
    asset(R, 'tree_pear', 'prop', 'tree', sway=sway('tree', 4.0, 0.40), standin='tree_poplar', art_h_2x=212, base_fill=0.15,
          brief='pear tree, taller oval canopy, a few yellow-green pears'),
    asset(R, 'tree_stump_old', 'prop', 'small', standin='tree_apple_stump', art_h_2x=52, base_fill=0.35,
          brief='old cut stump with rings, moss and a small root flare'),
    asset(R, 'fence_orchard_nwse', 'prop', 'small', standin='fence_wood_nwse', art_h_2x=74, base_fill=0.0,
          extra=dict(axis='rail runs along +x: screen up-left to down-right; ends on the NW and SE side midpoints so cells chain',
                     process_target_w_2x=92), brief='rustic split-rail wooden fence segment, two posts'),
    asset(R, 'fence_orchard_nesw', 'prop', 'small', standin='fence_wood_nesw', art_h_2x=74, base_fill=0.0,
          extra=dict(axis='rail runs along +y: screen up-right to down-left', process_target_w_2x=92),
          brief='same fence, the other axis (paint it, do not mirror: the lit face changes)'),
    asset(R, 'hay_bale_round', 'prop', 'small', standin='hay_bale', art_h_2x=70, base_fill=0.55,
          brief='round golden hay bale, loose straws'),
    asset(R, 'scarecrow_field', 'prop', 'tree', standin='scarecrow', art_h_2x=150, base_fill=0.1,
          sway=None, brief='patched scarecrow on a pole, straw hat, rag sleeves (optional low-amp sway mask if wanted)',
          flags=['optional sway: spec says "trees, reeds and banners" get sway; rags are banner-like']),
    asset(R, 'beehive_box', 'prop', 'small', standin='crate', art_h_2x=78, base_fill=0.45,
          brief='white-and-honey wooden beehive box on short legs, a couple of bees'),
    asset(R, 'stone_wall_field_nwse', 'prop', 'small', standin='stone_wall_low_nwse', art_h_2x=60, base_fill=0.0,
          aliases=('stone_wall_low.png', 'stone_wall_low_nwse.png', 'stone_wall_nwse.png'),
          extra=dict(axis='wall runs along +x: screen up-left to down-right; ends on the NW and SE side midpoints so cells chain',
                     process_target_w_2x=96),
          brief='low dry-stone field wall, one cell long, along +x, rounded grey-tan stones, a little moss'),
    asset(R, 'stone_wall_field_nesw', 'prop', 'small', standin='stone_wall_low_nesw', art_h_2x=60, base_fill=0.0,
          aliases=('stone_wall_low_nesw.png', 'stone_wall_nesw.png'),
          extra=dict(axis='wall runs along +y: screen up-right to down-left', process_target_w_2x=96),
          brief='same wall along +y (paint it, do not mirror: the lit face changes)',
          flags=['extra: the spec lists one "low stone wall"; Crosshaven ships stone_wall_low_nwse + _nesw and wall runs need both axes to turn']),
    asset(R, 'bush_flower_meadow', 'prop', 'small', sway=sway('bush', 2.0, 0.15), standin='bush_flower', art_h_2x=80, base_fill=0.4,
          brief='round flowering bush, pink and white blossoms'),
    # ---- border band ----
    asset(R, 'border_orchard_hedge_nwse', 'border', 'small', layer='border', sway=sway('hedge', 1.5, 0.25), standin='hedgerow_nwse',
          art_h_2x=96, base_fill=0.0, aliases=('orchard_hedge.png', 'orchard_hedge_nwse.png', 'hedge_nwse.png'),
          extra=dict(axis='hedge runs along +x: screen up-left to down-right; ends on the NW and SE side midpoints so cells chain',
                     process_target_w_2x=112,
                     note='border band: one segment per band cell along the region edge; segments overlap their neighbours a few px so runs read continuous'),
          brief='dense trimmed orchard hedge segment, chest-high, one cell long along +x, a few small white flowers',
          flags=['spec names one "orchard hedge"; the 1-2 cell border band follows region edges on both iso axes, so both axes are needed (Crosshaven hedgerow_nwse/_nesw)']),
    asset(R, 'border_orchard_hedge_nesw', 'border', 'small', layer='border', sway=sway('hedge', 1.5, 0.25), standin='hedgerow_nesw',
          art_h_2x=96, base_fill=0.0, aliases=('orchard_hedge_nesw.png', 'hedge_nesw.png'),
          extra=dict(axis='hedge runs along +y: screen up-right to down-left', process_target_w_2x=112),
          brief='same hedge along +y (paint it, do not mirror)', flags=['extra: second axis']),
    # ---- hero ----
    asset(R, 'old_windmill_body', 'hero', 'hero', fp=(2, 2), layer='hero', standin='tavern_3x2', art_h_2x=440, base_fill=0.9,
          strip=dict(id='old_windmill_sails', file='animated/old_windmill_sails.png (+ _2x/)', raw='old_windmill_sails.png',
                     frames=12, fps=10.8, frame_size=[160, 160], frame_size_2x=[320, 320],
                     rotation='90 deg per loop (4 symmetric sails), 7.5 deg per frame; one full turn every 4.44 s',
                     hub_from_anchor_1x=[0, -170], hub_from_anchor_2x=[0, -340],
                     flat='animated/old_windmill_sails_flat.png (+ _2x/): 1 frame at 0 deg for a rotation shader',
                     squash_y=0.9, draw='child AnimatedSprite2D above the body, frame centre on the hub',
                     static_combined=dict(id='old_windmill', file='props/old_windmill.png (+ _2x/)',
                                          note='derived, not painted: body + sails frame 0 baked on the same canvas/anchor (Crosshaven windmill_2x2 vs windmill_2x2_body)'),
                     convention='Crosshaven windmill_2x2_body + animated/windmill_sails (.png, _2x/, _flat): frame centre = hub, 90 deg per loop, one turn per ~4.44 s'),
          brief='old stone-and-timber windmill tower, thatched cap, painted WITHOUT sails (sails are a separate paint)',
          flags=['hub offset proposed; re-measured from the painted body', 'stand-in tavern is 3x2; hero is 2x2']),
]

windmere = [
    *[asset(W, f'snow_grass_{v}', 'tile', 'tile', base_terrain='snow_grass', variant=i, walkable=True, blocks=False, raw='snow_grass_swatch.png',
            standin='golden_plains', brief='thin snow over frosted grass, grass tips poking through') for i, v in enumerate('abc')],
    *[asset(W, f'white_flagstone_{v}', 'tile', 'tile', base_terrain='white_flagstone', variant=i, walkable=True, blocks=False,
            raw='white_flagstone_swatch.png', standin='dirt_road', brief='white limestone flagstones, frost in the joints; joints must meet the swatch edges cleanly') for i, v in enumerate('ab')],
    *[asset(W, f'glossy_ice_{v}', 'tile', 'tile', base_terrain='glossy_ice', variant=i, walkable=True, blocks=False,
            raw='glossy_ice_swatch.png', standin='water', brief='glossy pale-blue ice, cracks and trapped bubbles, soft painted sheen (no mirror reflection)') for i, v in enumerate('ab')],
    asset(W, 'tree_pine_snowy_a', 'prop', 'tree', sway=sway('tree', 2.5, 0.30), standin='tree_pine', art_h_2x=214, base_fill=0.15,
          brief='tall snow-laden pine, layered boughs with snow caps'),
    asset(W, 'tree_pine_snowy_b', 'prop', 'tree', sway=sway('tree', 2.5, 0.30), standin='tree_pine', art_h_2x=200, base_fill=0.15,
          brief='second snowy pine, slightly lopsided, different snow pattern'),
    asset(W, 'tree_pine_frozen_blue', 'prop', 'tree', sway=None, standin='tree_pine', art_h_2x=206, base_fill=0.15,
          brief='frozen blue-glazed pine, icicles, rime', flags=['no sway proposed (frozen solid reads better still); say if you want one']),
    asset(W, 'ice_boulder', 'prop', 'small', standin='rock_large', art_h_2x=84, base_fill=0.6,
          brief='rounded boulder half-encased in clear blue ice'),
    asset(W, 'snow_drift', 'prop', 'small', blocks=False, walkable=True, layer='decor', standin='rock_small_a', art_h_2x=40, base_fill=0.7,
          contact=False, brief='low wind-sculpted snow drift (walkable decor)', flags=['proposed walkable decor (goes in "decor")']),
    asset(W, 'pillar_ruin_white', 'prop', 'tree', standin='wall_tower', art_h_2x=176, base_fill=0.3,
          brief='broken white marble column on a square plinth, snow on the break'),
    asset(W, 'ice_crystal_cluster', 'prop', 'small', standin='rock_medium', art_h_2x=104, base_fill=0.5,
          emit=emit_spec('ice', 0.25, 'crystal cores (faint)'), brief='cluster of pale ice crystals growing from snow',
          flags=['emit optional (faint), proposed']),
    asset(W, 'lantern_post_warm', 'prop', 'tree', standin='lamp_post', art_h_2x=196, base_fill=0.1,
          emit=emit_spec('warm', 0.6, 'lantern glass + flame'), brief='wrought-iron lantern post with a warm amber lantern, snow on the cap'),
    asset(W, 'shrub_frozen', 'prop', 'small', standin='bush_small_a', art_h_2x=72, base_fill=0.45,
          brief='small frost-rimed shrub, white-tipped twigs'),
    asset(W, 'border_snowy_pine_wall', 'border', 'border_tall', layer='border', sway=sway('pine_wall', 2.0, 0.30), standin='border_forest_c',
          art_h_2x=240, base_fill=0.8, brief='dense wall of 2-3 snowy pines, orientation-free mass',
          extra=dict(note='placed on every cell of the 1-2 cell border band; art overlaps each neighbour by 16 px (1x)'),
          flags=['size proposed (not in Stasium Bot list)', 'recommend 2-3 variants']),
    asset(W, 'frost_spire', 'hero', 'hero', fp=(2, 2), layer='hero', standin='tavern_3x2', art_h_2x=500, base_fill=0.9,
          emit=emit_spec('ice', 0.35, 'ice veins, crystal crown, window glow (faint)'),
          brief='tall white-stone spire wrapped in ice, crystal crown, faint inner ice glow; the Frostspire Archive above ground',
          flags=['stand-in tavern is 3x2; hero is 2x2 tall']),
]

PALETTES = {
    'rowanvale': {
        'status': 'PROPOSED: the spec gives no Rowanvale hexes; these are the Crosshaven kit palette (atlas_meta.json > palette) the farmland already uses',
        'grass': '#a6bd36', 'grass_lo': '#7c9a2a', 'grass_dk': '#4f7a2c', 'grass_hi': '#dcd65a', 'tuft': '#6f8c26',
        'earth': '#9a6c44', 'earth_lo': '#6c4a2c', 'root': '#4a3220', 'road': '#d6a96a',
        'leaf': '#7fae2c', 'leaf_lo': '#55821f', 'leaf_hi': '#b4d24a',
        'wood': '#a9733d', 'wood_lo': '#7b4f27', 'wood_hi': '#cf9a5c', 'wood_dk': '#56361a', 'timber': '#6f4426',
        'wheat': '#e6bf52', 'wheat_lo': '#c59433', 'wheat_hi': '#f7de86',
        'stone': '#a7a6a2', 'stone_lo': '#7f7f80', 'stone_hi': '#cfcdc6', 'plaster': '#f1e2c0',
        'apple': '#c9432e', 'pear': '#d9c84a',
        'flower_w': '#fff6e0', 'flower_y': '#ffd23a', 'flower_r': '#e4553e', 'flower_p': '#ec92c2', 'flower_b': '#7fb0ea',
        'outline': '#2a1c12',
    },
    'windmere': {
        'status': 'PROPOSED: the spec gives no Windmere hexes; snow/ice/stone sampled from art/maps/arena_colosseum_v2/tiled/windmere_15x15_painted_preview.png (pc/world-zones), pine and lantern added',
        'snow_hi': '#eaeff3', 'snow': '#ccd6e3', 'snow_shade': '#a7c0dd', 'ice': '#83a7cd', 'ice_deep': '#5c8ab6', 'ice_dark': '#2c445d',
        'stone_white': '#e3e1da', 'stone': '#afb6bd', 'stone_lo': '#8c98a6', 'stone_dk': '#6d7e8f', 'slate': '#4a657f',
        'pine': '#2f5a4a', 'pine_lo': '#1f4038', 'pine_hi': '#4f7f68', 'pine_frozen': '#5f8fb0', 'pine_frozen_hi': '#8fbcd8',
        'lantern': '#ffc860', 'lantern_lo': '#f29a3a', 'iron': '#3a3f4a',
        'outline': '#2a1c12',
    },
}

LIGHT = {'key': '#fff0c8', 'key_dir': 'top-left (screen)', 'shade': '#5a6fa0', 'shadow_tint': '#3b3a66',
         'faces': 'SW (left) faces lit, SE (right) faces in shade', 'cast_shadows': 'none baked; small soft contact AO only',
         'source': 'ZONES_BUILD_SPEC WP10 style rules / Crosshaven v7_art_pass.light'}

GRADE = {
    'rowanvale': {'source': 'pc/world-zones data/world/rowanvale/stand_in.json', 'warm_mul': [1.06, 1.02, 0.9],
                  'haze_col': [0.62, 0.58, 0.32], 'haze_max': 0.08, 'saturation': 1.08, 'weather': ['clear']},
    'windmere': {'source': 'pc/world-zones data/world/windmere/stand_in.json (WP6 rework, 3 Oct)', 'warm_mul': [0.78, 0.88, 1.22],
                 'haze_col': [0.82, 0.9, 1.0], 'haze_max': 0.3, 'saturation': 0.58, 'tint_col': [0.0, 0.42, 1.0],
                 'tint_amount': 0.55, 'weather': ['light_cloud']},
}

REGIONS = [
    dict(id='rowanvale', name='Rowanvale', levels='10-15', chunks=6, where='West, past Stoneford (farmland)',
         dungeon='Rotting Orchard Barrow', hub='Hamlet hub, farmland middle chunks, door chunk',
         mood='sunny late-summer farmland hamlet: orchards, hayfields, beehives, an old windmill; warm and friendly, '
              'with a faint hint of blight near the barrow (dungeon: barrow under an old orchard, blighted farm beasts)',
         raw_dir='/workspace/stasium-pc-look/raw/wp10a_rowanvale/', raw_bg='#FFFFFF', assets=rowanvale,
         palette=PALETTES['rowanvale'], grade=GRADE['rowanvale'],
         zone_id_map={'terrain': {'meadow': ['meadow_a', 'meadow_b', 'meadow_c'], 'orchard_soil': ['orchard_soil_a', 'orchard_soil_b'],
                                  'tilled_rows': ['tilled_rows_a', 'tilled_rows_b']},
                      'standin_terrain': {'farm_soil': 'meadow', 'golden_plains': 'meadow', 'dirt_road': '(no Rowanvale path tile: keep Crosshaven dirt_road)'}}),
    dict(id='windmere', name='Windmere', levels='15-20', chunks=6, where='North, past Northgate (white city on the cliffs)',
         dungeon='Frostspire Archive', hub='City hub on the cliffs, 4 outer chunks, Frostspire Archive chunk',
         mood='white city on snowy cliffs: crisp, bright, cold; snow, white stone, glossy ice and pale crystals, with warm amber '
              'lantern light as the accent (dungeon: frozen library under the white spire, ice constructs and book wraiths)',
         raw_dir='/workspace/stasium-pc-look/raw/wp10a_windmere/', raw_bg='#000000', assets=windmere,
         palette=PALETTES['windmere'], grade=GRADE['windmere'],
         zone_id_map={'terrain': {'snow_grass': ['snow_grass_a', 'snow_grass_b', 'snow_grass_c'],
                                  'white_flagstone': ['white_flagstone_a', 'white_flagstone_b'], 'glossy_ice': ['glossy_ice_a', 'glossy_ice_b']},
                      'standin_terrain': {'golden_plains': 'snow_grass', 'dirt_road': 'white_flagstone',
                                          'water': '(glossy_ice is walkable; do not map water to it without a walkability decision)'}}),
]

CONFLICTS = [
    ('Windmill sail strip frame count', 'WP10a says 12-frame sail strip; WP10 (older asset table) says "sail strip 16 f"; Crosshaven ships 16 f (windmill_sails) and 48 f (windmill_sails_v5). Manifest follows WP10a/your brief: 12 frames.'),
    ('Rowanvale ground counts', 'WP10a: meadow x3, orchard soil x2, tilled rows x2 (matches your list). WP10 table (Proposed counts): meadow x4, orchard_soil x3 + autotile edges and corners; no tilled rows. Manifest follows WP10a.'),
    ('Windmere ground counts', 'WP10a matches your list. WP10 table: white_flagstone x4, snow_grass x3, cliff_white edges; no glossy ice. Manifest follows WP10a.'),
    ('No autotile edges/corners in WP10a', 'Crosshaven blends materials with <family>_edge_<sides> (15) + <family>_corner_<c> (4). WP10a lists none, so orchard soil / tilled rows / flagstone / ice beside meadow or snow grass will meet in hard diamond seams. The tile script can make edge sets from the same swatches (no extra paint): see wp10a_tiles.py --edges.'),
    ('No Rowanvale path tile', 'Stand-in chunks use dirt_road for paths. WP10a gives Rowanvale no road/path material. Proposal: keep Crosshaven dirt_road for Rowanvale paths (farm tracks), or paint one more swatch (rutted farm track). Windmere: white_flagstone works as the path material.'),
    ('2x1 size class unused in this pair', 'The low stone wall is now 1x1 per axis (one cell long, like Crosshaven stone_wall_low_nwse/_nesw and the pass-2 paints), so no Rowanvale/Windmere asset uses the 96x80 2x1 class. For later pairs (mossy log, carts): 96x80 equals the 2x1 footprint width but the bottom-centre anchor on the south tip needs 128x80 (art spans -64..+32 px around the tip, like Crosshaven market_stall 134 px), or keep 96x80 and anchor at x=64 (nwse) / x=32 (nesw).'),
    ('Walls and hedges: one axis in the spec, two needed', 'WP10a names both axes only for the wooden fence (nwse / nesw). The low stone wall and the orchard hedge are listed once. Crosshaven ships stone_wall_low_nwse/_nesw and hedgerow_nwse/_nesw, and wall runs and the 1-2 cell border band follow both iso axes, so the manifest adds stone_wall_field_nesw and border_orchard_hedge_nesw (paint them, do not mirror: mirroring moves the top-left key light to the top-right). Pine walls (Windmere) are orientation-free tree masses and need no second axis.'),
    ('Border sizes', 'Stasium Bot sizes have no border class. Orchard hedge: 1x1 segment per axis on the small canvas (64x64 / 128x128), chained like Crosshaven hedgerow_* (116 px wide at 2x), target width 112 px at 2x. Snowy pine wall: proposed 96x128 / 192x256, 1x1 footprint, overlapping neighbours by 16 px (1x) like border_forest_*.'),
    ('Hero canvas for the windmill', 'WP10a says Old Windmill is 2x2 (not "tall"), the hero row says 3x3 or 2x2 tall at 192x256. Manifest uses the hero canvas (192x256) for both heroes since they are the region hero landmarks.'),
    ('Sway frames 16 vs 12', 'WP10a: "Animated pieces (lava, bubbles, arcs, beacons) use 12-frame strips". Crosshaven sway strips are 16 f @ 8 fps. Manifest keeps 16 f for *_sway (Crosshaven convention), 12 f for the sail strip.'),
    ('Shadow sway vs no cast shadows', 'Spec asks for <prop>_shadow_sway; in Crosshaven these are separate ground-layer cast-shadow strips (#1a223c, projected from the top-left). Nothing is baked into the sprite, so it does not break the no-baked-cast-shadow rule.'),
    ('Ids vs Crosshaven', 'Spec names assets in prose only. Manifest ids are Crosshaven-style snake_case, chosen not to collide with existing Crosshaven ids (tree_apple, hay_bale, fence_wood_*, scarecrow, stone_wall_low_*, bush_flower, lamp_post exist there). Each entry names the Crosshaven stand-in id the placer uses until the art lands.'),
    ('Windmere grade will crush painted art', 'windmere/stand_in.json now has saturation 0.58, blue tint 0.55, haze 0.3 (tuned for golden_plains stand-ins). Painted snow and ice under that grade will turn grey-blue; paint natural colour and have the Technical Artist re-tune the grade when the art lands.'),
    ('Loader is Crosshaven-only', 'scenes/world/crosshaven/{crosshaven_art,crosshaven_ground,crosshaven_prop}.gd hard-code res://art/world/crosshaven/. Region roots need a code change (world agent).'),
    ('Spec branch moved', 'origin/claude/pc-zones-spec is now b7027d0 (two commits after a4f667e: mission XP rules in 4.7/4.8 and the PC set stat budget). WP10/WP10a are unchanged; WP10a sits at lines 1704-1801 in the new file.'),
    ('Raw file names', 'The painter uses short names (apple_tree_a.png, fence_nwse.png, stone_wall_low.png, orchard_hedge.png ...). Each manifest entry lists raw_aliases; the scripts take <id>.png first, then the aliases. raw/wp10a_rowanvale/pass1/ (scenes on grass) is ignored.'),
]


def md_table(rows, head):
    out = ['| ' + ' | '.join(head) + ' |', '|' + '---|' * len(head)]
    out += ['| ' + ' | '.join(str(c) for c in r) + ' |' for r in rows]
    return out


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    m = dict(format='stasium.wp10a_manifest', format_version=1, package='WP10a pair 1: Rowanvale + Windmere',
             spec=dict(file='docs/pc/ZONES_BUILD_SPEC.md', branch='claude/pc-zones-spec', commit='a4f667e', sections=['WP10a', 'WP10 style rules']),
             rules=dict(style='painted fantasy 2D (Dofus / Wakfu / Waven), never 3D, nothing copied from another game',
                        grid='2:1 diamond, tile top 64x32 (1x) / 128x64 (2x), height step 10 px',
                        masters='2x masters rendered at 8x supersampling, then downsampled to 2x and 1x (1x is a separate downsample, not 2x->1x)',
                        alpha='straight (not premultiplied); RGB 0 under alpha 0', import_='linear filter, no mipmaps',
                        light=LIGHT, anchors='tiles: bottom-centre on the cell south tip; props: bottom-centre on the south tip of the footprint south-most cell',
                        layout='art/world/<region>/{tiles,props,animated}/<id>.png + _2x/<id>.png, atlas_meta.json (Crosshaven schema)'),
             sizes={k: dict(size=v[0], size_2x=v[1]) for k, v in SIZE.items()},
             regions=REGIONS, conflicts=[dict(topic=t, note=n) for t, n in CONFLICTS])
    (OUT / 'manifest.json').write_text(json.dumps(m, indent=1))

    L = ['# WP10a pair 1: Rowanvale + Windmere asset manifest', '',
         'Prep for the Scenario paint. Machine-readable copy: `manifest.json` (same folder). Generated by `/workspace/scratch/wp10a/wp10a_manifest.py`.', '',
         'Spec: `docs/pc/ZONES_BUILD_SPEC.md` section WP10a at `a4f667e` (branch `claude/pc-zones-spec`), plus the WP10 style rules. Sizes come from Stasium Bot. Schema follows `art/world/crosshaven/atlas_meta.json`.', '',
         '## Kit rules', '',
         '- Painted fantasy 2D, never 3D. 2:1 diamond. 2x masters at 8x supersampling; the 1x is a separate downsample.',
         '- Straight alpha, RGB 0 under alpha 0. Linear filter, no mipmaps.',
         f"- Light: warm key from the top-left `{LIGHT['key']}`, cool shade `{LIGHT['shade']}`, shadow tint `{LIGHT['shadow_tint']}`. SW faces lit, SE faces in shade. No baked cast shadows: small soft contact AO only (the prop script adds it).",
         '- Anchors: tiles bottom-centre on the cell south tip. Props bottom-centre on the south tip of the footprint\'s south-most cell (canvas px below are the anchor point).',
         '- Layout: `art/world/<region>/tiles|props|animated/<id>.png`, 2x masters in `_2x/`, sway masks in `animated/sway_masks/`, cast-shadow strips in `animated/shadows/`, emit masks in `props/emit/`.',
         '- Raw paints: one PNG per asset in `raw/wp10a_<region>/`, named as the **Raw** column. Ground = one seamless square top-down swatch per material.', '',
         '## Size classes (1x / 2x)', '']
    L += md_table([(k, f'{v[0][0]}x{v[0][1]}', f'{v[1][0]}x{v[1][1]}') for k, v in SIZE.items()], ['class', '1x', '2x'])
    L += ['', '`wide` and the two `border_*` classes differ from or extend the Stasium Bot list; see Conflicts.', '']
    for reg in REGIONS:
        L += [f"## {reg['name']} (levels {reg['levels']}, {reg['chunks']} chunks)", '',
              f"{reg['where']}. Hub: {reg['hub']}. Dungeon: {reg['dungeon']}. Raw background: `{reg['raw_bg']}`.", '',
              f"Mood: {reg['mood']}.", '']
        rows = []
        for a in reg['assets']:
            fp = 'cell' if a['kind'] == 'tile' else 'x'.join(map(str, a['footprint_size']))
            sw = 'yes' if a['sway'] else '-'
            em = a['emit']['rule'] if a['emit'] else '-'
            st = f"{a['strip']['id']} ({a['strip']['frames']} f)" if a['strip'] else '-'
            anc = f"({a['anchor_px'][0]:g},{a['anchor_px'][1]:g}) / ({a['anchor_px_2x'][0]:g},{a['anchor_px_2x'][1]:g})"
            blk = 'walk' if a['walkable'] else ('blocks' if a['blocks'] else '-')
            rows.append((f"`{a['id']}`", a['kind'], fp, f"{a['size'][0]}x{a['size'][1]}", f"{a['size_2x'][0]}x{a['size_2x'][1]}",
                         anc, blk, sw, em, st, f"`{a['raw']}`" + (' (or ' + ', '.join(f'`{x}`' for x in a.get('raw_aliases', [])) + ')' if a.get('raw_aliases') else ''), f"`{a['standin_crosshaven']}`"))
        L += md_table(rows, ['id', 'kind', 'footprint', '1x', '2x', 'anchor px 1x / 2x', 'walk', 'sway', 'emit', 'strip', 'raw', 'stand-in'])
        L += ['', 'Notes per asset:', '']
        for a in reg['assets']:
            if a['kind'] == 'tile' and a['variant']:
                continue
            extra = []
            if a.get('axis'): extra.append(a['axis'])
            if a.get('row_axis'): extra.append(a['row_axis'])
            if a.get('note'): extra.append(a['note'])
            if a['sway']: extra.append(f"sway: amp {a['sway']['amp_1x']} px (1x), pin at {int(a['sway']['pin_frac'] * 100)}% height, pad {a['sway']['pad_1x']} px")
            if a['emit']: extra.append(f"emit ({a['emit']['rule']}, strength {a['emit']['strength_default']}): {a['emit']['covers']}")
            if a['strip']:
                s = a['strip']
                extra.append(f"strip `{s['id']}`: {s['frames']} f @ {s['fps']} fps, frame {s['frame_size'][0]}x{s['frame_size'][1]} / {s['frame_size_2x'][0]}x{s['frame_size_2x'][1]}, {s['rotation']}, hub {s['hub_from_anchor_1x']} px (1x) from the body anchor, raw `{s['raw']}`; static fallback `{s['static_combined']['id']}` = body + frame 0 (derived); convention: {s['convention']}")
            extra += a['flags']
            name = a['base_terrain'] + ' (all variants)' if a['kind'] == 'tile' else a['id']
            L.append(f"- `{name}`: {a['brief']}." + (' ' + '; '.join(extra) + '.' if extra else ''))
        L += ['', f"Palette ({reg['palette']['status']}):", '']
        L.append(', '.join(f"{k} `{v}`" for k, v in reg['palette'].items() if k != 'status'))
        g = reg['grade']
        L += ['', f"Current stand-in grade ({g['source']}): " + ', '.join(f'{k} {v}' for k, v in g.items() if k != 'source') + '.', '']
        zm = reg['zone_id_map']
        L += ['Proposed `zone_id_map.terrain`: ' + '; '.join(f"`{k}` -> {', '.join(v)}" for k, v in zm['terrain'].items()) + '.',
              'Stand-in terrain ids in the current chunks: ' + '; '.join(f"`{k}` -> {v}" for k, v in zm['standin_terrain'].items()) + '.', '']
    L += ['## Conflicts and flags', '']
    for t, n in CONFLICTS:
        L.append(f'- **{t}.** {n}')
    L += ['', '## Counts', '']
    for reg in REGIONS:
        k = {}
        for a in reg['assets']:
            k[a['kind']] = k.get(a['kind'], 0) + 1
        L.append(f"- {reg['name']}: " + ', '.join(f'{v} {kk}' for kk, v in k.items()) + f", {sum(1 for a in reg['assets'] if a['sway'])} with sway, "
                 f"{sum(1 for a in reg['assets'] if a['emit'])} with emit, {sum(1 for a in reg['assets'] if a['strip'])} strip. "
                 f"Raw paints: {len({a['raw'] for a in reg['assets']}) + sum(1 for a in reg['assets'] if a['strip'])} PNGs.")
    (OUT / 'MANIFEST.md').write_text('\n'.join(L) + '\n')
    return m


if __name__ == '__main__':
    m = build()
    print('wrote', OUT / 'manifest.json', OUT / 'MANIFEST.md', sum(len(r['assets']) for r in m['regions']), 'assets')
