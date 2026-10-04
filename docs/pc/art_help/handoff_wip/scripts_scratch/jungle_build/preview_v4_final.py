from preview_v4 import *
import json
PVJ = '/workspace/stasium-pc-look/previews/crosshaven_jungle/'
V1 = '/workspace/stasium-pc-look/ship_archive/crosshaven_jungle_v1/'
old = {'back_mid@2x.png': ARCH3 + 'back_mid@2x.png', 'front_leaves_bottom@2x.png': V1 + 'front_leaves_bottom@2x.png'}
res = {}
for tag, ov in (('ship', {}), ('old', old)):
    for p in PANS:
        fr, cov, gm = compose4(SHIP, p, ov); res['%s %s' % (tag, p)] = dict(cov=cov, ground=gm)
        print(tag, p, 'front any %.2f%% a>0.5 %.2f%%' % (cov['any'], cov['a50']), {k: round(v, 2) for k, v in cov['per'].items()}, {k: round(v, 1) for k, v in gm.items()}, flush=True)
        if tag == 'ship' and p == (0, 0): main = fr; mg = gm; mc = cov
        if tag == 'ship' and p == (0, 220): pany = fr; pg = gm; pc = cov
        if tag == 'old' and p == (0, 0): oldf = fr; og = gm
json.dump(res, open('/workspace/scratch/v4/coverage_final.json', 'w'), indent=1)
label(main, ['Default camera - back_mid v4 + front_leaves_bottom v2 (top v3, sides v2)',
             'front leaves over board %.2f%% | ground in 30 px band under lower edges %.0f%% | hole below corner line %.1f%%' % (mc['any'], mg['band_ground'], mg['below_line_hole'])], (20, PH - 2 * 36 - 20))
main.convert('RGB').save(PVJ + '_preview_composite.png', optimize=True)
label(pany, ['Pan y +220 (camera down) - shipped package',
             'front leaves over board %.2f%% | ground band %.0f%% | hole below corner line %.1f%%' % (pc['any'], pg['band_ground'], pg['below_line_hole'])], (20, PH - 2 * 36 - 20))
pany.convert('RGB').save(PVJ + '_preview_pan_y220.png', optimize=True)
label(oldf, ['OLD: back_mid v3 + front_leaves_bottom v1', 'ground band %.0f%% | hole below corner line %.1f%%' % (og['band_ground'], og['below_line_hole'])], (20, 20))
nm = main.copy(); label(nm, ['NEW: back_mid v4 + front_leaves_bottom v2'], (20, 20))
comp = Image.new('RGB', (PW * 2 + 20, PH), (255, 255, 255)); comp.paste(oldf.convert('RGB'), (0, 0)); comp.paste(nm.convert('RGB'), (PW + 20, 0))
comp.save(PVJ + '_preview_back_mid_v3_vs_v4.png', optimize=True)
print('written')
