import sys; sys.path.insert(0, '/workspace/scratch/wp10a_joins')
import numpy as np
from pathlib import Path
from PIL import Image
import placer as PL, wp10a_tiles as T
from wp10a_common import load_rgba
CH = Path('/workspace/stasium-repo/art/world/crosshaven/tiles/_2x')
PC = Path('/workspace/stasium-pc-look/ship')
def finder(out, region):
    dirs = [Path(out) / 'tiles/_2x', PC / f'wp10a_{region}/tiles/_2x', CH]
    cache = {}
    def f(name):
        if name not in cache:
            for d in dirs:
                p = d / f'{name}.png'
                if p.exists(): cache[name] = load_rgba(p); break
            else: raise FileNotFoundError(name)
        return cache[name]
    return f
def board(jid, prefix, region, rtiles, road_set, region_road, W=12, H=12, chw=4, span=(4, 7), roadw=True, out='out'):
    f = finder(Path(out) / jid, region)
    lev = PL.join_level('se', span, lambda x, y: (W - 1 - x), lambda x, y: y)
    road = lambda x, y: roadw and span[0] <= y <= span[1]
    def cell(x, y):
        if x >= W:   # Crosshaven side
            if road(x, y):
                gs = [s for s in ('ne', 'sw') if not road(x + PL.SIDES[s][0], y + PL.SIDES[s][1])]
                return [f('dirt_road_a' if not gs else 'dirt_road_edge_' + '_'.join(gs))]
            return [f('golden_plains_' + 'abcdefgh'[PL.h(x, y, 8)])]
        ids = PL.pick(lev, road, x, y, prefix, rtiles, road_set, region_road)
        return [f(i) for i in ids]
    n = W + chw
    img = T.render_board(lambda x, y: cell(x, y) if y < H else [], n)
    return img
if __name__ == '__main__':
    a = board('stoneford_rowanvale', 'meadow_join', 'rowanvale', ['meadow_a', 'meadow_b', 'meadow_c'], 'dirt_road_meadow', None)
    b = board('northgate_windmere', 'snow_grass_join', 'windmere', ['snow_grass_a', 'snow_grass_b', 'snow_grass_c'], None, 'white_flagstone')
    for nm, im in (('a', a), ('b', b)):
        Image.fromarray((np.clip(im, 0, 1) * 255).astype(np.uint8)).save(f'/workspace/scratch/wp10a_joins/look/test_{nm}.png')
