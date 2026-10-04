"""Mender S foot-track options sheet (s_track_options.png), in the layout of the Gloam one.
Rows: Kestrel v3.2 (approved, clay), Kestrel v3.1 (rejected, clay), Gloam v1 on v3.1 (approved, shipped frames), then the
Mender options rigged by s_track.py. Columns f00 | f01 | f03 | f06 | f09 | the option's lowest far-boot frame.
usage: s_track_options.py TRK_DIR KREF_DIR out.png   (TRK_DIR holds s_track.py outputs fw<w>.json / fw<w>_fNN.png,
       KREF_DIR holds the Kestrel clay: <commit>_fNN.png for fc3285cc and ec4beff9 at f00/f03/f06/f09)"""
import os, sys, json
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
LOOKS = os.path.abspath(os.path.join(HERE, '../../..'))
TRK, KREF, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
OPTS = ['0.3', '0.65', '0.9', '1.5', '1.8']
FT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15); FB = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 19)
BOX = (176, 172, 336, 360); K = 1.8; TW, TH = int((BOX[2] - BOX[0]) * K), int((BOX[3] - BOX[1]) * K)
def tile(p, lab):
    a = Image.open(p).convert('RGBA'); b = Image.new('RGBA', a.size, (172, 172, 172, 255)); b.alpha_composite(a)
    t = Image.new('RGB', (TW, TH + 20), (255, 255, 255)); t.paste(b.crop(BOX).resize((TW, TH), Image.NEAREST).convert('RGB'), (0, 20))
    ImageDraw.Draw(t).text((2, 1), lab, fill=(0, 0, 0), font=FT); return t
rows = []
rows.append(('Kestrel blockout v3.2 (APPROVED narrow track, foot_w 0.3): feet along the diagonal. Contact angle f00 41 deg, f06 27 deg (diagonal = 27)',
             [tile(f'{KREF}/fc3285cc_f{i:02d}.png', f'f{i:02d}') for i in (0, 3, 6, 9)]))
rows.append(('Kestrel blockout v3.1 (REJECTED wide track, foot_w 1.45): sideways splay. f00 78 deg, f06 9 deg',
             [tile(f'{KREF}/ec4beff9_f{i:02d}.png', f'f{i:02d}') for i in (0, 3, 6, 9)]))
G = os.path.join(LOOKS, 'gloam/v1_claude/frames')
rows.append(('Gloam v1 on blockout v3.1 (APPROVED and locked, foot_w 1.5): no X, far boot min 67%. f00 88 deg, f06 6 deg',
             [tile(f'{G}/gloam_walk_S_f{i:02d}.png', f'f{i:02d}') for i in (0, 3, 6, 9)]))
for w in OPTS:
    r = json.load(open(f'{TRK}/fw{w}.json')); fb = {k: v['far_boot_pct'] for k, v in r['frames'].items()}
    low = [k for k, v in fb.items() if v < 60]
    worst = r['far_boot_min_frame']; a0, a6 = r['contact_angle_f00_f06']
    now = ' (Mender v3 now)' if w == '0.9' else ''
    t = (f"Mender foot_w {w}{now}: shins cross {', '.join(r['cross_frames']) or 'none'}; far boot min {r['far_boot_min']:.0f}% ({worst}), "
         f"below 60% on {', '.join(low) or 'none'}. f00 {a0:.0f} deg, f06 {a6:.0f} deg")
    ts = [tile(f'{TRK}/fw{w}_f{i:02d}.png', f"f{i:02d}  far boot {fb[f'f{i:02d}']:.0f}%") for i in (0, 1, 3, 6, 9)]
    ts.append(tile(f'{TRK}/fw{w}_{worst}.png', f"{worst} (lowest)  far boot {fb[worst]:.0f}%"))
    rows.append((t, ts))
W = 10 + 6 * (TW + 8); H = 70 + sum(28 + TH + 30 for _ in rows)
sheet = Image.new('RGB', (W, H), (255, 255, 255)); d = ImageDraw.Draw(sheet)
d.text((10, 10), 'Mender S foot-track options (rigged painted legs). Angle = front heel - back heel on screen at contact; the travel diagonal is 27 deg.', fill=(0, 0, 0), font=FB)
d.text((10, 36), 'Gate: no shin X below the knee and far boot >= 60% on every frame, with splay no worse than Gloam (88 / 6 deg). f00/f01 and f06/f07 have both feet planted.', fill=(0, 0, 0), font=FB)
y = 70
for t, ts in rows:
    d.text((10, y + 4), t, fill=(0, 0, 0), font=FT); y += 28
    for c, im in enumerate(ts): sheet.paste(im, (10 + c * (TW + 8), y))
    y += TH + 30
sheet.save(OUT); print(OUT, sheet.size)
