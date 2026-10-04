"""WP10a one-shot region build, for when the Scenario raws land in raw/wp10a_<region>/.

  tiles  : <family>_swatch.png -> manifest variants (wp10a_tiles.py); non-base families also get autotile edges/corners
           against the region base ground (meadow / snow_grass) unless --no-edges
  props  : every prop/border/hero raw (wp10a_props.py), sway strips/masks, emit masks
  sails  : old_windmill_sails.png -> 12-frame strip + flat frame (wp10a_sails.py)
  atlas  : atlas_meta.json + animated/anim_meta.json (wp10a_atlas.py)
  check  : check_assets.py --package props on the flat staging folder (writes its report next to that folder)

Output: ship/wp10a_<region>/art/world/<region>/ (repo layout), ship/wp10a_<region>_props_check/ (flat, for the checker),
        ship/wp10a_<region>/_reports/. Nothing is written to the repo.
Usage: wp10a_build.py --region rowanvale [--raw DIR] [--ship-root DIR] [--matte key|hybrid] [--shadow-cut] [--no-edges] [--only tiles,props,sails,atlas,check]
"""
from __future__ import annotations
import argparse, json, subprocess, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from wp10a_common import load_manifest, find_raw
import wp10a_tiles as T, wp10a_props as P, wp10a_sails as S, wp10a_atlas as A

BASE = {'rowanvale': 'meadow', 'windmere': 'snow_grass'}
DIRECTIONAL = {'tilled_rows': 'u'}
CHECKER = '/workspace/stasium-pc-look/tools/check_assets.py'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--region', required=True); ap.add_argument('--matte', default='key')
    ap.add_argument('--shadow-cut', action='store_true'); ap.add_argument('--outline', action='store_true')
    ap.add_argument('--no-edges', action='store_true'); ap.add_argument('--only', default='tiles,props,sails,atlas,check')
    ap.add_argument('--fix-seams', action='store_true')
    ap.add_argument('--raw', help='raw folder (default: manifest raw_dir)')
    ap.add_argument('--ship-root', default='/workspace/stasium-pc-look/ship', help='output root (use a scratch dir for dry runs)')
    a = ap.parse_args()
    steps = set(a.only.split(','))
    m = load_manifest(); reg = next(r for r in m['regions'] if r['id'] == a.region)
    raw = Path(a.raw or reg['raw_dir']); ship = Path(a.ship_root) / f'wp10a_{a.region}'
    kit = ship / 'art/world' / a.region; stage = Path(a.ship_root) / f'wp10a_{a.region}_props_check'
    rdir = ship / '_reports'; rdir.mkdir(parents=True, exist_ok=True)
    log = {}
    if 'tiles' in steps:
        fams = {}
        for t in reg['assets']:
            if t['kind'] == 'tile':
                fams.setdefault(t['base_terrain'], dict(raw=t['raw'], variants=[]))['variants'].append(t['id'].rsplit('_', 1)[1])
        base_raw = raw / fams[BASE[a.region]]['raw']
        for fam, d in fams.items():
            sw = raw / d['raw']
            if not sw.exists():
                print(f'  missing swatch {sw}'); continue
            edges = None if (a.no_edges or fam == BASE[a.region] or not base_raw.exists()) else str(base_raw)
            files, sc = T.build(str(sw), fam, d['variants'], kit, DIRECTIONAL.get(fam), 0, a.fix_seams, edges, base_fix=a.fix_seams)
            log[fam] = dict(files=len(files), seam_score=sc)
            print(f'  tiles {fam}: {len(files)} files, swatch seam score {sc[0]:.2f}/{sc[1]:.2f}')
    if 'props' in steps:
        reps, pj = [], []
        for asset in reg['assets']:
            if asset['kind'] == 'tile':
                continue
            rp = find_raw(raw, asset)
            if rp is None:
                print(f"  missing raw {asset['raw']} (or {', '.join(asset.get('raw_aliases') or [])})"); continue
            r = P.process(asset, rp, kit, stage, dict(matte=a.matte, outline=a.outline, shadow_cut=a.shadow_cut))
            reps.append(r); pj.append(P.props_json_entry(asset, r))
            print(f"  prop {asset['id']}: art_x {r.get('art_x_from_anchor_2x')} h {r.get('art_height_2x')} {r.get('warnings', '')}")
        stage.mkdir(parents=True, exist_ok=True)
        (stage / 'props.json').write_text(json.dumps(dict(package=f'wp10a_{a.region}', version=1, props=pj), indent=1, default=float))
        (rdir / 'props_report.json').write_text(json.dumps(reps, indent=1, default=float))
    if 'sails' in steps:
        for asset in reg['assets']:
            s = asset.get('strip')
            srp = find_raw(raw, s['raw'], s.get('raw_aliases', ('windmill_sails.png', 'sails.png'))) if s else None
            if s and srp:
                r = S.build(srp, kit, s['id'], s['frames'], s['frame_size'][0], None,
                            'white' if a.region == 'rowanvale' else 'black', True, a.matte, s['squash_y'])
                (rdir / f"{s['id']}_report.json").write_text(json.dumps(r, indent=1, default=float))
                print(f"  strip {s['id']}: {r['frames']} frames, {r['deg_per_frame']} deg/frame")
                sc = s.get('static_combined')
                if sc and (kit / 'props/_2x' / f"{asset['id']}.png").exists():
                    cl = S.bake_static(kit, asset['id'], s['id'], s['hub_from_anchor_1x'], sc['id'])
                    print(f"  static {sc['id']}: body + sails frame 0 {'(SAILS CLIPPED by the canvas: move the hub or shrink the frame)' if any(cl.values()) else ''}")
            elif s:
                print(f"  missing raw {s['raw']}")
    if 'atlas' in steps:
        at = A.build(a.region, kit, rdir / 'props_report.json')
        print(f"  atlas: {len(at['tiles'])} tiles, {len(at['props'])} props, status {at['wp10a']['status']}, missing {len(at['wp10a']['missing'])}")
    if 'check' in steps and (stage / 'props.json').exists():
        r = subprocess.run([sys.executable, CHECKER, str(stage), '--package', 'props'], capture_output=True, text=True)
        print(r.stdout[-4000:]); (rdir / 'check_props.txt').write_text(r.stdout + r.stderr)


if __name__ == '__main__':
    main()
