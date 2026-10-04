"""WP10a world-kit canvas overrides (TA follow-up 3 Oct): applied to the manifest region copy before processing and
before the atlas build, so props, sway strips, sails and atlas_meta all agree.

- trees + Rowanvale hedges: the 1x1 'tree'/'small' canvases (128 px wide at 2x) were what capped them below the
  manifest art height; they move to the 96x128 (1x) canvas (the manifest's border_tall size, accepted by
  check_assets --package world for 1x1 footprints) so canopies/hedge ends can overhang the neighbour cells.
- old_windmill_body (+ static old_windmill): hero canvas widened to 288x256 (1x) for the larger sails; anchor unchanged
  (bottom-centre = footprint south tip).
- old_windmill_sails: frame 200 px (1x) for the larger sail radius.
- tree_pine_frozen_blue: gets the same sway as the other pines (checker: trees need sway masks).
"""
import copy

WIDE_1X = [96, 128]
CONIFER_1X = [96, 128]      # TA 3 Oct: tree_conifer class (192x256 at 2x)
BROAD_TREE_1X = [112, 128]   # TA 3 Oct: broad single-cell tree class (224x256 at 2x)
SIZE_1X = {
    'rowanvale': {'tree_apple_orchard': BROAD_TREE_1X, 'tree_apple_orchard_fruiting': BROAD_TREE_1X, 'tree_pear': BROAD_TREE_1X,
                  'border_orchard_hedge_nwse': WIDE_1X, 'border_orchard_hedge_nesw': WIDE_1X,
                  'old_windmill_body': [288, 256]},
    'windmere': {'tree_pine_snowy_a': CONIFER_1X, 'tree_pine_snowy_b': CONIFER_1X, 'tree_pine_frozen_blue': CONIFER_1X},   # tree_conifer (TA 3 Oct): art spans <= +-79 px at 2x, fits +-96 unclipped
}
STRIP_FRAME_1X = {'old_windmill_sails': 200}
SAIL_RADIUS_TARGET_1X = {'old_windmill_sails': 96}   # ~0.43 x body height (Crosshaven windmill: 120/267 = 0.45)


def apply(reg):
    sz = SIZE_1X.get(reg['id'], {})
    by_id = {a['id']: a for a in reg['assets']}
    for a in reg['assets']:
        if a['id'] in sz:
            a['size_original_1x'] = list(a['size'])
            a['size'] = list(sz[a['id']]); a['size_2x'] = [2 * v for v in sz[a['id']]]
        s = a.get('strip')
        if s and s['id'] in STRIP_FRAME_1X:
            f = STRIP_FRAME_1X[s['id']]
            s['frame_size'] = [f, f]; s['frame_size_2x'] = [2 * f, 2 * f]
    if reg['id'] == 'windmere' and not by_id['tree_pine_frozen_blue'].get('sway'):
        by_id['tree_pine_frozen_blue']['sway'] = copy.deepcopy(by_id['tree_pine_snowy_a']['sway'])
    return reg
