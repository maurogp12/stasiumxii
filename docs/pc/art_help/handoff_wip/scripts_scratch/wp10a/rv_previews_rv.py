import sys, json
from pathlib import Path
sys.path.insert(0, '/workspace/scratch/wp10a')
import rv_preview as V
region = 'rowanvale'
kit = V.Kit(region); out = V.PREV / 'wp10a_rowanvale'; out.mkdir(parents=True, exist_ok=True)
V.contact_sheets(kit, ['meadow_a', 'meadow_b', 'meadow_c'], out)
V.tile_sheet(kit, out)
n = 15
def ground(x, y):
    if 1 <= x <= 6 and 2 <= y <= 7: return 'orchard_soil'
    if 9 <= x <= 13 and 2 <= y <= 7: return 'tilled_rows'
    return 'meadow'
props = []
# border band: hedges along the two back edges
props += [('border_orchard_hedge_nwse', (x, 0)) for x in range(0, n)]
props += [('border_orchard_hedge_nesw', (0, y)) for y in range(1, n)]
# orchard on soil
orch = {(2, 3): 'tree_apple_orchard', (4, 3): 'tree_apple_orchard_fruiting', (6, 3): 'tree_pear',
        (2, 5): 'tree_pear', (4, 5): 'tree_apple_orchard', (6, 5): 'tree_apple_orchard_fruiting',
        (2, 7): 'tree_apple_orchard_fruiting', (4, 7): 'tree_stump_old', (6, 7): 'tree_apple_orchard'}
props += [(v, k) for k, v in orch.items()]
# tilled field: fence runs on its west (nesw) and south (nwse) sides, scarecrow inside
props += [('fence_orchard_nesw', (8, y)) for y in range(2, 8)]
props += [('fence_orchard_nwse', (x, 8)) for x in range(9, 14)]
props += [('scarecrow_field', (11, 4))]
# stone field wall along +y, then turning along +x
props += [('stone_wall_field_nesw', (7, y)) for y in range(10, 14)]
props += [('stone_wall_field_nwse', (x, 14)) for x in range(7, 10)]
# windmill 2x2 (south cell)
props += [('old_windmill', (12, 12))]
props += [('beehive_box', (2, 10)), ('beehive_box', (3, 11)), ('beehive_box', (2, 12)),
          ('hay_bale_round', (10, 10)), ('hay_bale_round', (9, 12)), ('hay_bale_round', (14, 9)),
          ('bush_flower_meadow', (5, 10)), ('bush_flower_meadow', (4, 13)), ('bush_flower_meadow', (8, 1)),
          ('bush_flower_meadow', (14, 14)), ('tree_apple_orchard', (13, 1)), ('tree_pear', (5, 12))]
lay = dict(n=n, ground=ground, base='meadow', props=props, void=(46, 62, 34),
           variants=dict(meadow=['meadow_a', 'meadow_b', 'meadow_c'], orchard_soil=['orchard_soil_a', 'orchard_soil_b'],
                         tilled_rows=['tilled_rows_a', 'tilled_rows_b']))
V.mock_board(kit, lay, out, 'mock_rowanvale_board_view_2x')
at = kit.atlas
p = next(p for p in at['props'] if p['id'] == 'old_windmill_body')
V.sails_gif(kit, 'old_windmill_body', 'old_windmill', 'old_windmill_sails', p['sail_hub_from_anchor_2x'], 10.8, out)
print(sorted(x.name for x in out.iterdir()))
