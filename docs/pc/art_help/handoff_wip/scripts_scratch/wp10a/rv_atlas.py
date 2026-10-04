"""atlas_meta.json + anim_meta.json + props.json (checker) for a WP10a region kit, via wp10a_atlas.build with the
measured windmill hub and the per-asset processing notes patched in."""
import json, sys, copy, datetime
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import wp10a_common as C
import wp10a_atlas as A
import rv_overrides as OVR
from PIL import Image

WORK = Path('/workspace/scratch/wp10a/rv'); SHIP = Path('/workspace/stasium-pc-look/ship')


def run(region, extra_notes=None):
    kit = SHIP / f'wp10a_{region}'
    m = C.load_manifest(); log = json.loads((WORK / f'build_log_{region}.json').read_text())
    reps = json.loads((WORK / f'props_report_{region}.json').read_text())
    sails = log.get('sails', {})
    m2 = copy.deepcopy(m)
    reg = next(r for r in m2['regions'] if r['id'] == region)
    OVR.apply(reg)
    for a in reg['assets']:
        s = a.get('strip')
        if s and s['id'] in sails:
            s['hub_from_anchor_1x'] = sails[s['id']]['hub_from_anchor_1x']; s['hub_from_anchor_2x'] = sails[s['id']]['hub_from_anchor_2x']
    # painted extra variants (e.g. border_snowy_pine_wall_b/_c) become their own atlas entries
    ids = {a['id'] for a in reg['assets']}
    for r in reps:
        if r['id'] not in ids:
            base = next(a for a in reg['assets'] if r['id'].startswith(a['id'] + '_'))
            a2 = copy.deepcopy(base); a2['id'] = r['id']; a2['file'] = f"props/{r['id']}.png"; a2['file_2x'] = f"props/_2x/{r['id']}.png"
            a2['raw'] = Path(r['raw']).name; a2['brief'] = base['brief'] + f" (painted variant {r['id'][-1]})"
            reg['assets'].insert(reg['assets'].index(base) + 1 + sum(1 for x in reg['assets'] if x['id'].startswith(base['id'] + '_')), a2)
    rp = WORK / f'atlas_report_{region}.json'; rp.write_text(json.dumps(reps, default=float))
    orig = A.load_manifest; A.load_manifest = lambda *a, **k: m2
    try:
        at = A.build(region, kit, rp, kit)
    finally:
        A.load_manifest = orig
    R = {r['id']: r for r in reps}
    for p in at['props']:
        r = R.get(p['id'])
        if r:
            p['raw'] = Path(r['raw']).name
            proc = {k: r[k] for k in ('painted_shadow_removed_px', 'palette_drift_dE', 'flat_top_repaired', 'base_plate_removed_px', 'scale_raw_to_2x') if k in r}
            if proc: p['processing'] = proc
            if r.get('warnings'): p['processing_warnings'] = r['warnings']
        if p['id'] in sails or any(p['id'] == a['id'] and a.get('strip') for a in reg['assets']):
            pass
    for a in reg['assets']:
        s = a.get('strip')
        if s and s['id'] in sails:
            sv = sails[s['id']]
            for p in at['props']:
                if p['id'] == a['id']:
                    p['sail_hub_from_anchor_1x'] = sv['hub_from_anchor_1x']; p['sail_hub_from_anchor_2x'] = sv['hub_from_anchor_2x']
                    p['sail_hub_note'] = (f"measured on the painted body (axle tip of the hub stub on the cap's upper-left face): "
                                          f"exact {sv['hub_from_anchor_2x_exact']} px at 2x, rounded to whole 1x px; manifest proposal was {sv['manifest_proposed_hub_1x']}")
                if p['id'] == s['static_combined']['id']:
                    p['note'] = p['note'] + f" Sails radius {sv['sail_radius_1x']} px (1x) (~0.43 x body height, Crosshaven windmill ratio 0.45); hero canvas widened to 288x256 (1x) so every tip stays inside it."
    import numpy as _np
    for p in at['props']:            # derived statics (body + sails frame 0): measure their own art extents
        if p.get('derived_from'):
            _a = _np.asarray(Image.open(kit / p['file_2x']).getchannel('A')); _ys, _xs = _np.nonzero(_a > 128)
            p['art_x_from_anchor_2x'] = [int(_xs.min() - _a.shape[1] / 2), int(_xs.max() - _a.shape[1] / 2)]
            p['art_height_2x'] = int(_a.shape[0] - _ys.min())
    for p in at['props']:
        em = log.get('emit', {}).get(p['id'])
        if em and p.get('emit'):
            p['emit']['processing'] = em
    # size class exactly as tools/check_assets.py --package world names it
    sys.path.insert(0, '/workspace/stasium-pc-look/tools')
    import check_assets as _CK
    for p in at['props']:
        cls, _ = _CK._world_size_class(tuple(p['size']), tuple(p['footprint_size']), p.get('kind', ''))
        p['size_class'] = cls
    at['lighting'] = ('top-left warm key #fff0c8, cool shade #5a6fa0 (SW faces lit, SE faces in shade); NO baked cast or contact '
                      'shadows in the sprites (painted ground shadows removed from the raws); moving cast shadows live only in '
                      'animated/shadows/*_shadow_sway (ground layer, #1a223c)')
    at['wp10a']['processing'] = dict(
        pipeline='scratch/wp10a: wp10a_props.py (key + decontaminate on the flat bg, 8x supersampled place, area downsample to 2x and 1x), '
                 'rv_fix.py (painted-shadow removal behind the dark outline, palette nudge 30% capped at 7 dE, per-asset retouch), '
                 'wp10a_tiles.py (--fix-seams, --edges), wp10a_sails.py, wp10a_atlas.py; driver rv_run.py',
        tiles=log.get('tiles'), sails=sails, notes=extra_notes or [])
    at['wp10a']['generated'] = datetime.date.today().isoformat()
    (kit / 'atlas_meta.json').write_text(json.dumps(at, indent=1, default=float))
    # props.json for check_assets --package props (paths relative to the kit root)
    pj = []
    for p in at['props']:
        r = R.get(p['id'], {})
        pj.append(dict(id=p['id'], file_2x=p['file_2x'], file_1x=p['file'], footprint_cells=p['footprint_size'],
                       anchor_px_2x=[p['size_2x'][0] / 2, p['size_2x'][1]], anchor_px_1x=[p['size'][0] / 2, p['size'][1]],
                       size_2x=p['size_2x'], size_1x=p['size'], size_class=p.get('size_class'), emissive='yes' if p.get('emit') else 'no',
                       art_x_from_anchor_2x=r.get('art_x_from_anchor_2x'), height_px_2x=r.get('art_height_2x')))
    (kit / 'props.json').write_text(json.dumps(dict(package=f'wp10a_{region}', version=1, note='checker index (check_assets.py --package props); paths relative to this folder', props=pj), indent=1))
    print(f"{region}: {len(at['tiles'])} tiles, {len(at['props'])} props, {at['animated']['count']} anims, status {at['wp10a']['status']}, missing {at['wp10a']['missing']}")
    return at


if __name__ == '__main__':
    run(sys.argv[1])
