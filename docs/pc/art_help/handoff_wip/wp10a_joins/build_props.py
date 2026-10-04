import sys, json
from pathlib import Path
sys.path.insert(0, '/workspace/scratch/wp10a_joins')
import numpy as np, cv2
import joins_props as JP
from wp10a_common import load_rgba, save_rgba, resize_pm

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else '/workspace/stasium-pc-look/ship/wp10a_joins')
SRC = Path('/workspace/scratch/wp10a_joins/src')
REV = Path('/workspace/scratch/wp10a_joins/review'); REV.mkdir(exist_ok=True)
rep = {}

# ---------------- stone ford (stoneford_rowanvale): 3 (x, along the road) x 4 (y, road width)
ford = load_rgba(SRC / 'stone_ford_cut.png')
ford_g, grep_ = JP.grade_corridor(ford)
x0, x1, y0, y1 = JP.art_ground_bbox(ford_g)
length, width = x1 - x0, y1 - y0
keep = (3.0 / 4.0) * width / length
ford_s, srep = JP.stitch_shorten(ford_g, keep)
save_rgba(REV / 'ford_stitched_raw.png', ford_s)
(can, nv), s = JP.place_flat(ford_s, 3, 4)
save_rgba(REV / 'ford_full_2x.png', can)
halves = JP.split_halves(can, nv, 3, 4, 'y')
out = OUT / 'stoneford_rowanvale'
ids = []
for i, hv in enumerate(halves):
    pid = f'corridor_stone_ford_{"ab"[i]}'
    s2, s1 = JP.finish_sprite(hv['sprite']); JP.save_prop(out, pid, s2, s1)
    ids.append(dict(id=pid, footprint=hv['footprint'], offset_cells=hv['offset'], clipped_alpha=hv['clipped_alpha'], **JP.measure(s2)))
rep['stone_ford'] = dict(grade=grep_, raw_len_width_ratio=round(length / width, 2), stitch=srep, scale_raw_to_2x=round(float(s), 4), pieces=ids)

# ---------------- cliff-pass steps (northgate_windmere): 4 (x, road width) x 3 (y, along the road, climbing to -y)
st = load_rgba(SRC / 'cliff_pass_steps_cut.png')
st_g, grep2 = JP.grade_corridor(st)
a = st_g[..., 3] > 0.5
ys, xs = np.nonzero(a)
yb = ys.max(); xs_b = xs[ys > yb - 4]; Xs = xs_b.mean()           # south vertex (lowest point)
xl = xs.min(); yl = ys[xs < xl + 4].max()                         # west vertex: lowest point of the leftmost column
xr = xs.max(); yr = ys[xs > xr - 4].max()                         # east vertex
# west->south edge runs along +x (4 cells): dX = 4*64 at 2x ; south->east along -y (3 cells): dX = 3*64
s_x = (4 * 64) / (Xs - xl); s_y = (3 * 64) / (xr - Xs)
s = float(np.sqrt(s_x * s_y))
# origin: raw point that maps to world (0,0) = south vertex minus w2s(4,3) / s
SX, SY = JP.w2s(4, 3)
oX, oY = Xs - SX / s, yb - SY / s
xr0 = oX / 128 + oY / 64; yr0 = oY / 64 - oX / 128
can2, nv2 = JP.place_scaled(st_g, s, (xr0, yr0), 4, 3)
save_rgba(REV / 'steps_full_2x.png', can2)
halves = JP.split_halves(can2, nv2, 4, 3, 'x')
out = OUT / 'northgate_windmere'
ids = []
for i, hv in enumerate(halves):
    pid = f'corridor_cliff_pass_steps_{"ab"[i]}'
    s2, s1 = JP.finish_sprite(hv['sprite']); JP.save_prop(out, pid, s2, s1)
    ids.append(dict(id=pid, footprint=hv['footprint'], offset_cells=hv['offset'], clipped_alpha=hv['clipped_alpha'], **JP.measure(s2)))
# rise: top of the tread region above the N vertex (back edge) -- measured on the centre column of the stairs
rep['cliff_pass_steps'] = dict(grade=grep2, scale_raw_to_2x=round(s, 4), scale_x_vs_y=[round(float(s_x), 4), round(float(s_y), 4)],
                               pieces=ids, nvert_canvas=list(map(int, nv2)))

# ---------------- signs
rep['sign_rowanvale'] = JP.build_sign(SRC / 'sign_rowanvale_cut.png', 'sign_level_rowanvale', OUT / 'stoneford_rowanvale', JP.board_rowanvale)
rep['sign_windmere'] = JP.build_sign(SRC / 'sign_windmere_cut.png', 'sign_level_windmere', OUT / 'northgate_windmere', JP.board_windmere)

# ---------------- end caps from the shipped border art (re-run after the region kits are rebuilt)
R = Path('/workspace/stasium-pc-look/ship/wp10a_rowanvale/props/_2x'); W = Path('/workspace/stasium-pc-look/ship/wp10a_windmere/props/_2x')
caps = {}
for axis in ('nwse', 'nesw'):
    src = load_rgba(R / f'border_orchard_hedge_{axis}.png')
    for side in ('left', 'right'):
        pid = f'border_orchard_hedge_{axis}_end_{side}'
        c2, crep = JP.end_cap_squash(src, side)
        s2, s1 = JP.finish_sprite(c2); JP.save_prop(OUT / 'stoneford_rowanvale', pid, s2, s1)
        caps[pid] = dict(src=f'wp10a_rowanvale/props/_2x/border_orchard_hedge_{axis}.png', **crep, **JP.measure(s2))
for var in ('', '_b', '_c'):
    src = load_rgba(W / f'border_snowy_pine_wall{var}.png')
    for side in ('left', 'right'):
        pid = f'border_snowy_pine_wall{var}_end_{side}'
        c2, crep = JP.end_cap_squash(src, side)
        s2, s1 = JP.finish_sprite(c2); JP.save_prop(OUT / 'northgate_windmere', pid, s2, s1)
        caps[pid] = dict(src=f'wp10a_windmere/props/_2x/border_snowy_pine_wall{var}.png', **crep, **JP.measure(s2))
rep['end_caps'] = caps
Path('/workspace/scratch/wp10a_joins/props_report.json').write_text(json.dumps(rep, indent=1, default=float))
print(json.dumps({k: (v if k != 'end_caps' else {kk: (vv['art_edge_before'], vv['art_edge_after']) for kk, vv in v.items()}) for k, v in rep.items()}, indent=0, default=float)[:5000])
