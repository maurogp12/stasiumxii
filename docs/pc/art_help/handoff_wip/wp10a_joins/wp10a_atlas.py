"""Draft atlas_meta.json (+ animated/anim_meta.json) for art/world/<region>/, Crosshaven schema (stasium.art_atlas v1).

Driven by raw/wp10a/manifest.json; every entry is checked against the files present in the kit folder (sizes read from the
PNGs, art extents from the prop report). Missing files are listed under wp10a.missing and the atlas status says DRAFT.
grid / files / anchors / fence_axis are copied verbatim from the Crosshaven atlas so both kits share one placement rule.

Usage: wp10a_atlas.py --region rowanvale [--kit DIR] [--report JSON] [--out DIR]
"""
from __future__ import annotations
import argparse, json, sys, datetime
from pathlib import Path
from PIL import Image
sys.path.insert(0, str(Path(__file__).parent))
from wp10a_common import CROSSHAVEN, load_manifest

KIND_MAP = [('tree_', 'tree'), ('fence_', 'fence'), ('stone_wall_', 'wall'), ('hay_', 'hay'), ('bush_', 'bush'),
            ('shrub_', 'bush'), ('tree_stump', 'stump'), ('border_', 'border'), ('lantern_', 'lamp'), ('beehive', 'farm'),
            ('scarecrow', 'farm'), ('ice_boulder', 'rock'), ('ice_crystal', 'rock'), ('pillar_', 'ruin'), ('snow_drift', 'decor')]
BASE_ID = {'tree': 'tree', 'fence': 'fence'}


def atlas_kind(a):
    if a['kind'] == 'hero':
        return 'landmark'
    hit = [k for p, k in KIND_MAP if a['id'].startswith(p)]
    return hit[-1] if hit else 'decor'


def png_size(p):
    try:
        with Image.open(p) as im:
            return list(im.size)
    except Exception:
        return None


def build(region, kit, report=None, out=None):
    m = load_manifest(); reg = next(r for r in m['regions'] if r['id'] == region)
    kit = Path(kit); out = Path(out or kit)
    ch = json.loads((CROSSHAVEN / 'atlas_meta.json').read_text())
    reps = {r['id']: r for r in json.loads(Path(report).read_text())} if report and Path(report).exists() else {}
    missing, tiles, props, anims = [], [], [], {}

    def check(entry):
        for key, skey in (('file', 'size'), ('file_2x', 'size_2x')):
            got = png_size(kit / entry[key])
            if got is None:
                missing.append(entry[key])
            elif got != entry[skey]:
                entry.setdefault('size_mismatch', {})[key] = got

    # ---- tiles: manifest variants + any generated autotile pieces of the same families
    fams = {}
    for a in reg['assets']:
        if a['kind'] != 'tile':
            continue
        e = dict(id=a['id'], base_terrain=a['base_terrain'], kind='floor', walkable=a['walkable'], blocks=a['blocks'],
                 in_zone_data=False, file=a['file'], file_2x=a['file_2x'], size=a['size'], size_2x=a['size_2x'],
                 anchor=a['anchor'], variant=a['variant'], raw=a['raw'], note=a['brief'], wp10a=True)
        if a.get('row_axis'): e['row_axis'] = a['row_axis']
        check(e); tiles.append(e)
        fams.setdefault(a['base_terrain'], []).append(a['id'])
    for fam in fams:
        for p in sorted((kit / 'tiles').glob(f'{fam}_edge_*.png')) + sorted((kit / 'tiles').glob(f'{fam}_corner_*.png')):
            tid = p.stem
            if 'edge' in tid:
                e = dict(id=tid, base_terrain=fam, kind='floor', walkable=True, blocks=False, in_zone_data=False,
                         sides=tid.split('_edge_')[1].split('_'), note='autotile edge: the listed sides touch the region base ground')
            else:
                c = tid.rsplit('_', 1)[1]
                e = dict(id=tid, base_terrain=fam, kind='decal', walkable=True, in_zone_data=False, corner=c,
                         note=f'draw over a {fam} tile whose diagonal corner {c} touches base ground while both side neighbours are {fam}')
            e.update(file=f'tiles/{tid}.png', file_2x=f'tiles/_2x/{tid}.png', size=[64, 32], size_2x=[128, 64],
                     anchor='image bottom-centre (32,32) = diamond south tip; diamond centre = (32,16)', generated_by='wp10a_tiles.py --edges')
            check(e); tiles.append(e)

    # ---- props
    zprops = {}
    for a in reg['assets']:
        if a['kind'] == 'tile':
            continue
        k = atlas_kind(a)
        e = dict(id=a['id'], base_id=BASE_ID.get(k), in_zone_data=False, kind=k, layer=a['layer'], walkable=a['walkable'],
                 blocks=a['blocks'], file=a['file'], file_2x=a['file_2x'], size=a['size'], size_2x=a['size_2x'],
                 footprint_size=a['footprint_size'], footprint_from_nw=a['footprint_from_nw'],
                 anchor_cell_from_nw=a['anchor_cell_from_nw'], anchor=a['anchor'],
                 bottom_centre_from_nw_centre_1x=a['bottom_centre_from_nw_centre_1x'],
                 y_sort_origin_from_bottom_1x=a['y_sort_origin_from_bottom_1x'], standin_crosshaven=a['standin_crosshaven'],
                 note=a['brief'], raw=a['raw'], wp10a=True, design_status='PROPOSED (WP10a)')
        if a.get('axis'): e['axis'] = a['axis']
        if a['blocks']:
            e['note_zone'] = 'blocking art: the placer must mark every footprint cell blocked'
        r = reps.get(a['id'])
        if r:
            e['art_x_from_anchor_2x'] = r.get('art_x_from_anchor_2x'); e['art_height_2x'] = r.get('art_height_2x')
        check(e)
        if a['sway']:
            sw = a['sway']; fw = a['size'][0] + 2 * sw['pad_1x']
            e['animated'] = [f"animated/{a['id']}_sway.png"]
            e['sway_mask'] = f"animated/sway_masks/{a['id']}_swaymask.png"
            anims[f"{a['id']}_sway"] = dict(file=f"animated/{a['id']}_sway.png", file_2x=f"animated/_2x/{a['id']}_sway.png",
                frame_size=[fw, a['size'][1]], frame_size_2x=[2 * fw, a['size_2x'][1]], frames=sw['frames'], fps=sw['fps'], loop=True,
                duration_s=sw['frames'] / sw['fps'], pairs_with=a['id'], blend='mix',
                anchor=f"bottom-centre (same anchor as props/{a['id']}.png; frame is {sw['pad_1x']}px (1x) wider on each side so the canopy never clips)",
                note=f"sway {sw['frames']} f @ {sw['fps']} fps, ~{sw['amp_1x']} px canopy bend at 1x, base pinned below {int(sw['pin_frac'] * 100)}% height; randomise start frame + speed_scale (0.85-1.15)",
                sway_mask=f"animated/sway_masks/{a['id']}_swaymask.png", status='PROPOSED')
            rs = (r or {}).get('sway', {})
            anims[f"{a['id']}_shadow_sway"] = dict(file=f"animated/shadows/{a['id']}_shadow_sway.png",
                file_2x=f"animated/shadows/_2x/{a['id']}_shadow_sway.png", frame_size=rs.get('shadow_frame'), frame_size_2x=rs.get('shadow_frame_2x'),
                frames=sw['frames'], fps=sw['fps'], loop=True, duration_s=sw['frames'] / sw['fps'], pairs_with=f"{a['id']}_sway",
                blend='mix (alpha = shadow strength, colour #1a223c)',
                anchor=f"frame top-left = top-left of the matching {a['id']}_sway frame; draw on the ground layer under all props",
                note='cast shadow that moves with the canopy: frame i is the projection of sway frame i (light from the top-left, shear 0.62, squash 0.30, soft 2.2 px)', status='PROPOSED')
            for key in ('file', 'file_2x'):
                for an in (anims[f"{a['id']}_sway"], anims[f"{a['id']}_shadow_sway"]):
                    if not (kit / an[key]).exists(): missing.append(an[key])
        if a['emit']:
            em = a['emit']
            e['emit'] = dict(file=f"props/emit/{a['id']}_emit.png", file_2x=f"props/emit/_2x/{a['id']}_emit.png",
                             strength_default=em['strength_default'], covers=em['covers'], note=em['note'])
            for key in ('file', 'file_2x'):
                if not (kit / e['emit'][key]).exists(): missing.append(e['emit'][key])
        if a['strip']:
            s = a['strip']
            e['animated'] = [f"animated/{s['id']}.png", f"animated/{s['id']}_flat.png"]
            anims[s['id']] = dict(file=f"animated/{s['id']}.png", file_2x=f"animated/_2x/{s['id']}.png", frame_size=s['frame_size'],
                frame_size_2x=s['frame_size_2x'], frames=s['frames'], fps=s['fps'], loop=True, duration_s=round(s['frames'] / s['fps'], 3),
                anchor=f"frame centre = sail hub; place the frame centre at {tuple(s['hub_from_anchor_1x'])} px (1x) from the {a['id']} bottom-centre anchor ({tuple(s['hub_from_anchor_2x'])} at 2x), draw above the body",
                pairs_with=a['id'], blend='mix', note=f"{s['rotation']}; {s['frames']} f @ {s['fps']} fps", status='PROPOSED')
            anims[s['id'] + '_flat'] = dict(file=f"animated/{s['id']}_flat.png", file_2x=f"animated/_2x/{s['id']}_flat.png",
                frame_size=s['frame_size'], frame_size_2x=s['frame_size_2x'], frames=1, fps=0, loop=True,
                anchor='frame centre = sail hub (same placement as the strip)', pairs_with=a['id'], blend='mix',
                note=f"un-squashed sails at 0 deg for a rotation shader: rotate uv about the centre, then divide y by {s['squash_y']}", status='PROPOSED')
            for an in (anims[s['id']], anims[s['id'] + '_flat']):
                for key in ('file', 'file_2x'):
                    if not (kit / an[key]).exists(): missing.append(an[key])
        props.append(e)
        if a['strip'] and a['strip'].get('static_combined'):
            sc = a['strip']['static_combined']
            e2 = dict(e, id=sc['id'], file=f"props/{sc['id']}.png", file_2x=f"props/_2x/{sc['id']}.png", raw=None,
                      note=f"static fallback: {a['id']} + {a['strip']['id']} frame 0 baked (same canvas/anchor; Crosshaven windmill_2x2 vs windmill_2x2_body). Use {a['id']} + the strip when animating.",
                      derived_from=[a['id'], a['strip']['id']])
            e2.pop('animated', None); e2.pop('size_mismatch', None)
            check(e2); props.append(e2)
        if e['base_id']:
            zprops.setdefault(e['base_id'], []).append(a['id'])

    zim = dict(terrain={fam: dict(file=f'tiles/{ids[0]}.png', default_variant=ids[0], pieces=ids + [t['id'] for t in tiles if t['base_terrain'] == fam and t['id'] not in ids])
                        for fam, ids in fams.items()},
               props={b: dict(file=f'props/{ids[0]}.png', variants=ids[1:]) for b, ids in zprops.items()},
               standin_terrain=reg['zone_id_map']['standin_terrain'],
               note='zone data keeps its ids; the placer / dressing.json picks these pieces per cell (Crosshaven hash picker)')
    groups = {'sway': sorted(k for k in anims if k.endswith('_sway')), 'overlays': sorted(k for k in anims if not k.endswith('_sway'))}
    atlas = dict(format='stasium.art_atlas', format_version=1, region=region, root=f'res://art/world/{region}/',
                 zone_data_ref=dict(spec='docs/pc/ZONES_BUILD_SPEC.md WP10a @ a4f667e', region_index=f'data/world/{region}/index.json',
                                    note='region chunks currently use Crosshaven stand-in ids; see zone_id_map.standin_terrain and props[].standin_crosshaven'),
                 grid=ch['grid'], files=ch['files'], anchors=ch['anchors'], zone_id_map=zim, fence_axis=ch['fence_axis'],
                 tiles=tiles, props=props, palette={k: v for k, v in reg['palette'].items() if k != 'status'},
                 lighting=ch['v7_art_pass']['light'] if isinstance(ch['v7_art_pass'].get('light'), str) else ch['lighting'],
                 animated=dict(meta='animated/anim_meta.json', status='PROPOSED', count=len(anims), groups=groups),
                 wp10a=dict(package='WP10a pair 1', manifest='raw/wp10a/manifest.json', generated=datetime.date.today().isoformat(),
                            status='DRAFT' if missing else 'COMPLETE', missing=sorted(set(missing)), grade=reg['grade'],
                            palette_status=reg['palette']['status']))
    out.mkdir(parents=True, exist_ok=True)
    (out / 'atlas_meta.json').write_text(json.dumps(atlas, indent=1))
    (out / 'animated').mkdir(parents=True, exist_ok=True)
    (out / 'animated' / 'anim_meta.json').write_text(json.dumps(dict(format=f'{region}_animated_v1', status='PROPOSED',
        scale_note='1x files here, 2x masters in _2x/ (exactly 2x)', sheet_layout='horizontal strip, frames left->right, frame_size each',
        animations=anims), indent=1))
    return atlas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--region', required=True); ap.add_argument('--kit'); ap.add_argument('--report'); ap.add_argument('--out')
    a = ap.parse_args()
    kit = a.kit or f'/workspace/stasium-pc-look/ship/wp10a_{a.region}/art/world/{a.region}'
    rep = a.report or f'/workspace/stasium-pc-look/ship/wp10a_{a.region}/_reports/props_report.json'
    at = build(a.region, kit, rep, a.out)
    print(f"{a.region}: {len(at['tiles'])} tiles, {len(at['props'])} props, {at['animated']['count']} animations; "
          f"status {at['wp10a']['status']}, missing {len(at['wp10a']['missing'])} files -> {(Path(a.out or kit) / 'atlas_meta.json')}")


if __name__ == '__main__':
    main()
