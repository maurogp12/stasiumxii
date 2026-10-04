import sys
sys.path.insert(0, '/workspace/scratch/wp10a')
import rv_preview as V
kit = V.Kit('windmere'); out = V.PREV / 'wp10a_windmere'; out.mkdir(parents=True, exist_ok=True)
V.contact_sheets(kit, ['snow_grass_a', 'snow_grass_b', 'snow_grass_c'], out)
V.tile_sheet(kit, out)
n = 15
def ground(x, y):
    if 6 <= x <= 8 and 2 <= y <= 14: return 'white_flagstone'          # flagstone avenue along +y
    if 5 <= x <= 10 and 9 <= y <= 12: return 'white_flagstone'         # plaza in front of the spire
    if 10 <= x <= 13 and 2 <= y <= 6: return 'glossy_ice'              # frozen pond
    return 'snow_grass'
walls = ['border_snowy_pine_wall', 'border_snowy_pine_wall_b', 'border_snowy_pine_wall_c']
props = [(walls[V.hpick(x, 0, 3)], (x, 0)) for x in range(0, n)] + [(walls[V.hpick(0, y, 3, 9)], (0, y)) for y in range(1, n)]
props += [('frost_spire', (8, 6))]
props += [('lantern_post_warm', (5, y)) for y in (8, 13)] + [('lantern_post_warm', (9, y)) for y in (13,)]
props += [('pillar_ruin_white', (5, 3)), ('pillar_ruin_white', (9, 8)), ('pillar_ruin_white', (11, 12))]
props += [('tree_pine_snowy_a', (2, 3)), ('tree_pine_snowy_b', (3, 5)), ('tree_pine_frozen_blue', (2, 7)), ('tree_pine_snowy_a', (3, 10)),
          ('tree_pine_snowy_b', (13, 9)), ('tree_pine_snowy_a', (14, 12)), ('tree_pine_frozen_blue', (12, 14)), ('tree_pine_snowy_b', (14, 2))]
props += [('ice_crystal_cluster', (12, 7)), ('ice_crystal_cluster', (9, 2)), ('ice_boulder', (13, 1)), ('ice_boulder', (2, 12)),
          ('shrub_frozen', (4, 2)), ('shrub_frozen', (11, 9)), ('shrub_frozen', (1, 14)), ('snow_drift', (3, 8)), ('snow_drift', (12, 11)), ('snow_drift', (10, 14))]
lay = dict(n=n, ground=ground, base='snow_grass', props=props, void=(30, 38, 52),
           variants=dict(snow_grass=['snow_grass_a', 'snow_grass_b', 'snow_grass_c'], white_flagstone=['white_flagstone_a', 'white_flagstone_b'],
                         glossy_ice=['glossy_ice_a', 'glossy_ice_b']))
V.mock_board(kit, lay, out, 'mock_windmere_board_view_2x')
print(sorted(x.name for x in out.iterdir()))
