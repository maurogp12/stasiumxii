"""Reference placer for the join pieces (ports 1:1 to GDScript; README documents the same rules).

Level field for one join (region chunk side): virtual core = the `span` cells just across the chunk edge.
  d(cell) = Chebyshev distance to the virtual core = max(depth + 1, e), depth = cells in from the edge (0 = edge cell),
  e = cells outside the span along the edge.  L = min(3, d).  L3 cells with no lower neighbour are plain region tiles.
  Across-edge (off-chunk) neighbours use the same formula with depth = -1, so they are 0 on the span and rise to 3 beyond.
"""
from __future__ import annotations

SIDES = {'nw': (-1, 0), 'ne': (0, -1), 'se': (1, 0), 'sw': (0, 1)}
CORN = {'n': ((-1, -1), 'nw', 'ne'), 'e': ((1, -1), 'ne', 'se'), 's': ((1, 1), 'se', 'sw'), 'w': ((-1, 1), 'nw', 'sw')}
ORDER = ('nw', 'ne', 'se', 'sw')
AXIS_OF_LOW = {'nw': 'x', 'se': 'x', 'ne': 'y', 'sw': 'y'}
ROAD_SIDES = {'x': ('ne', 'sw'), 'y': ('nw', 'se')}


def h(x, y, k):
    return (((x * 73856093) ^ (y * 19349663) ^ (x * y * 83492791)) & 0x7fffffff) % k


def pick(level, road, x, y, prefix, region_tiles, road_set=None, region_road=None):
    """level(x,y) -> int 0..3 (region side incl. virtual across-edge cells); road(x,y) -> bool.
    Returns the list of tile ids to draw at (x,y) (floor first, then decals); None if the cell is not a join/region cell."""
    L = level(x, y)
    if L is None or L == 0:
        return None
    g = [s for s in ORDER if (level(x + SIDES[s][0], y + SIDES[s][1]) or 0) < L]
    if road(x, y):
        if g:
            if len(g) != 1:
                raise ValueError(f'road cell {x},{y} has lower sides {g}; roads must cross the band straight')
            low = g[0]; a, b = ROAD_SIDES[AXIS_OF_LOW[low]]
            gs = [s for s in (a, b) if not road(x + SIDES[s][0], y + SIDES[s][1])]
            part = 'mid' if not gs else 'edge_' + '_'.join(gs)
            return [f'{prefix}_road_l{L}_{low}_{part}']
        # road inside the region (past the band)
        gs = [s for s in ORDER if not road(x + SIDES[s][0], y + SIDES[s][1])]
        if region_road == 'white_flagstone':
            return ['white_flagstone_' + ('ab'[h(x, y, 2)] if not gs else 'edge_' + '_'.join(gs))]
        return [f'{road_set}_' + 'abcd'[h(x, y, 4)]] if not gs else [f'{road_set}_edge_' + '_'.join(gs)]
    out = []
    if not g:
        out.append(region_tiles[h(x, y, len(region_tiles))] if L == 3 else f'{prefix}_l{L}_' + 'abc'[h(x, y, 3)])
    else:
        out.append(f"{prefix}_l{L}_edge_{'_'.join(g)}" + (['', '_b', '_c'][h(x, y, 3)] if len(g) == 1 else ''))
    for c, (d, a, b) in CORN.items():
        if a in g or b in g:
            continue
        if (level(x + d[0], y + d[1]) or 0) < L:
            out.append(f'{prefix}_l{L}_corner_{c}')
    return out


def join_level(edge_side, span, depth_of, along_of):
    """Build level(x,y) for a region chunk whose joining edge is on `edge_side` (the band's lower side).
    depth_of(x,y) -> cells in from the edge (0 = edge cell, -1 = across the edge); along_of(x,y) -> index along the edge."""
    s0, s1 = span
    def level(x, y):
        dep = depth_of(x, y)
        if dep < -1:
            return None
        a = along_of(x, y)
        e = max(0, s0 - a, a - s1)
        return min(3, max(dep + 1, e))
    return level
