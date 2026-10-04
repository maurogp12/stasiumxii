"""WP10a region delivery driver (Rowanvale / Windmere): uses wp10a_props / wp10a_tiles / wp10a_sails / wp10a_atlas,
plus rv_fix per-asset clean-ups. Kit root = ship/wp10a_<region>/ in the Crosshaven layout (tiles|props|animated + _2x/).

Usage: rv_run.py REGION [--only tiles,props,sails,atlas] [--ids a,b]
"""
from __future__ import annotations
import argparse, json, sys, shutil
from pathlib import Path
import numpy as np, cv2
from PIL import Image
sys.path.insert(0, str(Path(__file__).parent))
from wp10a_common import load_manifest, find_raw, load_rgb, load_raw, save_rgba, load_rgba, over
import wp10a_props as P, wp10a_tiles as T, wp10a_sails as S, wp10a_atlas as A
import rv_fix as F
import rv_overrides as OVR

SHIP = Path('/workspace/stasium-pc-look/ship')
WORK = Path('/workspace/scratch/wp10a/rv')
CHECKER = '/workspace/stasium-pc-look/tools/check_assets.py'


# ------------------------------------------------------------------ per-asset config
def post_chain(*steps):
    def f(cut, rgb):
        rep = post_chain.rep
        for st in steps:
            cut = st(cut, rgb, rep)
        return cut
    return f
post_chain.rep = {}


def shadow(lower=0.5, **kw):
    return lambda cut, rgb, rep: F.remove_painted_shadow(cut, rgb, lower, report=rep, **kw)


def pal(region, keys=None, strength=0.3):
    def f(cut, rgb, rep):
        p = REGPAL[region]
        hexes = [v for k, v in p.items() if k not in ('status', 'outline') and (keys is None or k in keys)]
        return F.palette_match(cut, hexes, strength=strength, report=rep)
    return f


def flat_top(cut, rgb, rep):
    return F.repair_flat_top(cut, rgb, rep)


def plate(frac):
    return lambda cut, rgb, rep: F.remove_base_plate(cut, rgb, rep, frac)


def plate_poly(edge, legs):
    return lambda cut, rgb, rep: F.remove_base_plate_poly(cut, rgb, rep, edge, legs)


def recl(cut, rgb, rep):
    return P.clean_components(cut, {})


def foliage(target=72.0, seeds=None):
    """canopy hue shift to the plain apple's green; outlined fruit (pears) masked out by seed flood fills"""
    def f(cut, rgb, rep):
        prot = F.fruit_mask_seeds(rgb, seeds) if seeds else None
        return F.shift_foliage_hue(cut, target, protect=prot, report=rep)
    return f


def hedge_col(cut, rgb, rep):
    return F.hedge_recolour(cut, 70.0, 0.86, report=rep)


# pear centres on raw/wp10a_rowanvale/pear_tree.png, as fractions of the 4096 px raw (read on a 1024 px grid)
PEAR_SEEDS = [(x / 1024, y / 1024) for x, y in ((331, 250), (306, 394), (106, 412), (731, 212), (887, 427), (694, 481),
                                                (137, 700), (931, 650), (765, 731))]


REGPAL = {}
RV_LEAF = ['leaf', 'leaf_lo', 'leaf_hi', 'grass', 'grass_lo', 'grass_dk', 'grass_hi', 'wood', 'wood_lo', 'wood_hi', 'wood_dk',
           'timber', 'root', 'earth', 'earth_lo', 'apple', 'pear', 'wheat', 'wheat_lo', 'wheat_hi', 'flower_w', 'flower_p']
RV_ALL = None


def rv_cfg():
    r = 'rowanvale'
    return {
        'tree_apple_orchard': dict(post=post_chain(shadow(0.35), pal(r, RV_LEAF), recl), opts=dict(nudge_2x=(-3, 4))),
        'tree_apple_orchard_fruiting': dict(post=post_chain(flat_top, shadow(0.35), pal(r, RV_LEAF), foliage(72.0), recl), opts=dict(nudge_2x=(-5, 4))),
        'tree_pear': dict(post=post_chain(shadow(0.35), pal(r, RV_LEAF), foliage(72.0, PEAR_SEEDS), recl), opts=dict(nudge_2x=(-10, 4))),   # canopy leans right: trunk 5 px (1x) left of the cell centre, still on the footprint
        'tree_stump_old': dict(post=post_chain(shadow(0.6), pal(r), recl)),
        # keeper fence: tree canopy intrudes from the top -> whiten everything above the fence before keying
        'fence_orchard_nwse': dict(pre=lambda rgb: F.whiten(rgb, [(0, 0, 1, 0.415), (0.585, 0, 1, 0.62), (0.13, 0.78, 0.40, 0.90)]),
                                   post=post_chain(shadow(0.75, chroma_max=45, thin_open=11), pal(r), recl)),
        'fence_orchard_nesw': dict(post=post_chain(shadow(0.7), pal(r), recl)),
        'hay_bale_round': dict(post=post_chain(shadow(0.5), pal(r), recl)),
        'scarecrow_field': dict(post=post_chain(shadow(0.35), pal(r), recl), opts=dict(nudge_2x=(0, 6))),
        # pass-2 paint stands on a paving/grass plate with a cast shadow: keep the hive above its bottom-frame outline
        # plus the three visible legs (traced on the 2048 px working copy of the raw)
        'beehive_box': dict(post=post_chain(plate_poly([(0, 1263), (672, 1263), (1037, 1453), (1407, 1225), (2048, 1225)],
                                                       [[(704, 1280), (812, 1280), (810, 1416), (758, 1430), (720, 1420)],
                                                        [(982, 1430), (1094, 1430), (1088, 1560), (1040, 1574), (992, 1562)],
                                                        [(1266, 1280), (1364, 1280), (1364, 1408), (1320, 1430), (1276, 1418)]]),
                                            shadow(0.6, chroma_max=14), pal(r), recl), opts=dict(post_render=F.beehive_white_boxes())),
        'stone_wall_field_nwse': dict(post=post_chain(shadow(0.6), pal(r), recl)),
        'stone_wall_field_nesw': dict(post=post_chain(shadow(0.6), pal(r), recl)),
        'bush_flower_meadow': dict(post=post_chain(shadow(0.45), pal(r), recl)),
        'border_orchard_hedge_nwse': dict(post=post_chain(shadow(0.6), pal(r), hedge_col, recl), opts=dict(art_h_2x=96, post_render=F.trim_run_ends('nwse', 8.0))),   # manifest height wins over the 112 px target width
        'border_orchard_hedge_nesw': dict(post=post_chain(shadow(0.6), pal(r), hedge_col, recl), opts=dict(art_h_2x=96, post_render=F.trim_run_ends('nesw', 8.0))),
        'old_windmill_body': dict(post=post_chain(shadow(0.4), pal(r), recl), opts=dict(nudge_2x=(0, -12))),   # base inside the 2x2 diamond
    }


def wm_cfg():
    r = 'windmere'
    base = dict(post=post_chain(pal(r), recl))
    c = {a: dict(base) for a in ('tree_pine_snowy_a', 'tree_pine_snowy_b', 'tree_pine_frozen_blue', 'ice_boulder', 'snow_drift',
                                 'pillar_ruin_white', 'ice_crystal_cluster', 'lantern_post_warm', 'shrub_frozen', 'frost_spire')}
    # world kit: no combat-prop width caps; pine walls fill the manifest 96x128 canvas (16 px@1x neighbour overlap)
    for v in ('border_snowy_pine_wall', 'border_snowy_pine_wall_b', 'border_snowy_pine_wall_c'):
        c[v] = dict(post=post_chain(pal(r), recl), opts=dict(fit_half_w_2x=WALL_HALF_W_2X))
    for v in ('tree_pine_snowy_a', 'tree_pine_snowy_b', 'tree_pine_frozen_blue'):
        c[v] = dict(base, opts=dict(nudge_2x=(0, 4)))
    c['lantern_post_warm'] = dict(base, opts=dict(nudge_2x=(0, 6)))
    return c


WALL_HALF_W_2X = 94
CFG = {'rowanvale': rv_cfg, 'windmere': wm_cfg}

# tiles: family -> (crop size px of the raw swatch, crop origin (x, y) or None = centre, rot, fix_seams, period crop)
TILES = {
    'rowanvale': dict(
        meadow=dict(size=560, rot=0, fix=True),
        orchard_soil=dict(size=560, rot=0, fix=True),
        tilled_rows=dict(period=102.887, periods=4, rot=2, fix=True, directional='u'),
    ),
    'windmere': dict(
        snow_grass=dict(size=560, rot=0, fix=True),
        # joints repeat every 635.5 x 407.75 px: crop exactly one period, phase picked for the lowest wrap seam
        white_flagstone=dict(period_xy=(635.5, 407.75), origin_f=(618.0, 86.0), rot=0, fix=False, directional='tint'),
        glossy_ice=dict(size=560, rot=0, fix=True),
    ),
}
BASE = {'rowanvale': 'meadow', 'windmere': 'snow_grass'}


def prep_square(raw, cfg, out_png):
    img = load_rgb(raw); h, w = img.shape[:2]
    if cfg.get('period_xy'):
        px, py = cfg['period_xy']; x0, y0 = cfg['origin_f']; n = 1024
        M = np.float32([[n / px, 0, -x0 * n / px], [0, n / py, -y0 * n / py]])
        sq = cv2.warpAffine(img, M, (n, n), flags=cv2.INTER_AREA, borderMode=cv2.BORDER_REFLECT)
    elif cfg.get('period'):
        side = cfg['period'] * cfg['periods']               # whole number of furrow periods, sub-pixel exact
        y0 = cfg.get('y0', (h - side) / 2); x0 = cfg.get('x0', (w - side) / 2)
        n = 1024; k = n / side
        M = np.float32([[k, 0, -x0 * k], [0, k, -y0 * k]])
        sq = cv2.warpAffine(img, M, (n, n), flags=cv2.INTER_AREA if k < 1 else cv2.INTER_CUBIC, borderMode=cv2.BORDER_REFLECT)
    else:
        s = cfg['size']; ox, oy = cfg.get('origin') or ((w - s) // 2, (h - s) // 2)
        sq = img[oy:oy + s, ox:ox + s]
    sq = np.rot90(sq, cfg.get('rot', 0)).copy()
    Image.fromarray(np.round(np.clip(sq, 0, 1) * 255).astype(np.uint8)).save(out_png)
    return out_png


def build_tiles(region, reg, kit, log):
    raw = Path(reg['raw_dir']); fams = {}
    for t in reg['assets']:
        if t['kind'] == 'tile':
            fams.setdefault(t['base_terrain'], dict(raw=t['raw'], variants=[]))['variants'].append(t['id'].rsplit('_', 1)[1])
    pre = WORK / f'swatch_{region}'; pre.mkdir(parents=True, exist_ok=True)
    prepped = {}
    for fam, d in fams.items():
        sw = raw / d['raw']
        if not sw.exists():
            log.setdefault('missing_raw', []).append(d['raw']); continue
        prepped[fam] = prep_square(sw, TILES[region][fam], pre / f'{fam}_square.png')
    base = prepped.get(BASE[region])
    for fam, d in fams.items():
        if fam not in prepped: continue
        c = TILES[region][fam]
        edges = None if fam == BASE[region] or base is None else str(base)
        bc = TILES[region][BASE[region]]
        files, sc = T.build(str(prepped[fam]), fam, d['variants'], kit, c.get('directional'), 0, c.get('fix', False), edges,
                            base_fix=bc.get('fix', False))
        tex, sc0 = T.prep_swatch(str(prepped[fam]), 0, False)
        texf, _ = T.prep_swatch(str(prepped[fam]), 0, c.get('fix', False))
        sc_after = T.seam_score(texf)
        t2 = [load_rgba(kit / 'tiles/_2x' / f'{fam}_{v}.png') for v in d['variants']]
        met = T.seam_metric(t2, texf)
        log[fam] = dict(files=files, crop=c, seam_score_raw_cols_rows=[round(v, 2) for v in sc0],
                        seam_score_after_cols_rows=[round(v, 2) for v in sc_after], board_seam=met)
        print(f'  tiles {fam}: {len(files)} files; seam {sc0[0]:.2f}/{sc0[1]:.2f} -> {sc_after[0]:.2f}/{sc_after[1]:.2f}; board {met}')


def build_props(region, reg, kit, log, ids=None):
    raw = Path(reg['raw_dir']); cfg = CFG[region]()
    stage = WORK / f'stage_{region}'
    reps = []
    for asset in reg['assets']:
        if asset['kind'] == 'tile' or (ids and asset['id'] not in ids):
            continue
        for var_asset, rp in variants_for(asset, raw):
            if rp is None:
                log.setdefault('missing_raw', []).append(var_asset['id']); print('  MISSING raw for', var_asset['id']); continue
            c = cfg.get(var_asset['id'], cfg.get(asset['id'], {}))
            post_chain.rep = {}
            opts = dict(matte='key', outline=False, shadow_cut=True, contact_shadow=False, pre=c.get('pre'), post=c.get('post'))
            opts.update(c.get('opts', {}))
            r = P.process(var_asset, rp, kit, stage, opts)
            r.update(post_chain.rep)
            reps.append(r)
            print(f"  prop {var_asset['id']:28s} art_x {r.get('art_x_from_anchor_2x')} h {r.get('art_height_2x')} "
                  f"{ {k: r[k] for k in ('painted_shadow_removed_px', 'palette_drift_dE', 'flat_top_repaired', 'base_plate_removed_px') if k in r} } {r.get('warnings', '')}")
    rp_path = WORK / f'props_report_{region}.json'
    old = {x['id']: x for x in json.loads(rp_path.read_text())} if (ids and rp_path.exists()) else {}
    for x in reps: old[x['id']] = x
    reps = list(old.values()) if ids else reps
    rp_path.write_text(json.dumps(reps, indent=1, default=float))
    return reps


def variants_for(asset, raw):
    """Manifest asset -> [(asset, raw path)]; extra painted variants (<raw>_b.png ...) become <id>_b ... entries."""
    rp = find_raw(raw, asset)
    if rp is not None:
        return [(asset, rp)]
    stem = Path(asset['raw']).stem
    vs = sorted(raw.glob(f'{stem}_[a-z].png'))
    if not vs:
        return [(asset, None)]
    out = []
    for i, v in enumerate(vs):
        a2 = json.loads(json.dumps(asset))
        if i > 0:
            suf = v.stem.rsplit('_', 1)[1]
            a2['id'] = f"{asset['id']}_{suf}"
            a2['file'] = f"props/{a2['id']}.png"; a2['file_2x'] = f"props/_2x/{a2['id']}.png"
            a2['variant_of'] = asset['id']
        out.append((a2, v))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('region'); ap.add_argument('--only', default='tiles,props,sails,atlas'); ap.add_argument('--ids')
    a = ap.parse_args()
    steps = set(a.only.split(','))
    m = load_manifest(); reg = next(r for r in m['regions'] if r['id'] == a.region)
    REGPAL[a.region] = reg['palette']
    OVR.apply(reg)
    kit = SHIP / f'wp10a_{a.region}'; kit.mkdir(parents=True, exist_ok=True)
    logp = WORK / f'build_log_{a.region}.json'
    log = json.loads(logp.read_text()) if logp.exists() else {}
    if 'tiles' in steps:
        tl = {}; build_tiles(a.region, reg, kit, tl); log['tiles'] = tl
    if 'props' in steps:
        build_props(a.region, reg, kit, log, set(a.ids.split(',')) if a.ids else None)
    if 'sails' in steps:
        import rv_sails; log['sails'] = rv_sails.run(a.region, reg, kit)
    logp.write_text(json.dumps(log, indent=1, default=float))


if __name__ == '__main__':
    main()
