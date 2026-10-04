"""Windmill sails for rv_run: measure the hub on the painted body, build the 12-frame strip sized so the static
old_windmill (body + frame 0 on the body canvas) is not clipped, bake the static."""
import json, sys
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).parent))
from wp10a_common import find_raw
import wp10a_sails as S
import rv_overrides as OVR

WORK = Path('/workspace/scratch/wp10a/rv')
# axle tip of the hub stub on the cap's upper-left face, measured on raw old_windmill_body.png (1280x720, x4 zoom crop)
HUB_RAW = {'rowanvale': (533.3, 252.5)}


def run(region, reg, kit):
    out = {}
    reps = {r['id']: r for r in json.loads((WORK / f'props_report_{region}.json').read_text())}
    for asset in reg['assets']:
        s = asset.get('strip')
        if not s:
            continue
        body = reps[asset['id']]; t = body['raw_to_2x']
        hx, hy = HUB_RAW[region]
        x2 = (hx - t['x0']) * t['sx'] + t['tx']; y2 = (hy - t['y0']) * t['sy'] + t['ty']
        W2, H2 = asset['size_2x']
        hub2_exact = [x2 - W2 / 2, y2 - H2]
        hub1 = [int(round(hub2_exact[0] / 2)), int(round(hub2_exact[1] / 2))]
        W1, H1 = asset['size']
        # largest sail radius (1x) that keeps every tip inside the body canvas and the 160 px frame
        lim = [W1 / 2 + hub1[0], W1 / 2 - hub1[0], (H1 + hub1[1]) / s['squash_y'], s['frame_size'][0] / 2 - 2]
        R = float(min(np.floor(min(lim) - 2), OVR.SAIL_RADIUS_TARGET_1X.get(s['id'], 1e9)))
        srp = find_raw(Path(reg['raw_dir']), s['raw'], s.get('raw_aliases', ()))
        r = S.build(srp, kit, s['id'], s['frames'], s['frame_size'][0], None, 'white' if region == 'rowanvale' else 'black',
                    True, 'key', s['squash_y'], radius_1x=R)
        clip = S.bake_static(kit, asset['id'], s['id'], hub1, s['static_combined']['id'])
        out[s['id']] = dict(r, hub_raw_body=[hx, hy], hub_from_anchor_2x_exact=[round(v, 1) for v in hub2_exact],
                            hub_from_anchor_1x=hub1, hub_from_anchor_2x=[2 * hub1[0], 2 * hub1[1]],
                            manifest_proposed_hub_1x=s['hub_from_anchor_1x'], sail_radius_limits_1x=[round(v, 1) for v in lim],
                            static_clipped=clip)
        print(f"  sails {s['id']}: hub {hub1} (1x) from anchor (exact 2x {hub2_exact}), radius {R} px 1x, clipped {clip}")
    return out
