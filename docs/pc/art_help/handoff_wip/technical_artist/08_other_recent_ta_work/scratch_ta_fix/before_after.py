import sys
from PIL import Image, ImageDraw, ImageFont
OLD = '/workspace/scratch/npc_ship_pre_ta_fix'; NEW = '/workspace/stasium-pc-look/ship/npc_sprites'
OUT = '/workspace/stasium-pc-look/previews/npc_sprites'
try:
    F = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 13); FB = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 15)
except Exception:
    F = FB = ImageFont.load_default()
BG = (150, 160, 140)

def frame(root, role, strip, k, box=(0, 0, 256, 256), sc=1, guides=True):
    im = Image.open(f'{root}/{role}/_2x/{strip}.png').convert('RGBA')
    fr = im.crop((k * 256, 0, k * 256 + 256, 256))
    bg = Image.new('RGBA', (256, 256), BG + (255,)); bg.alpha_composite(fr); bg = bg.convert('RGB')
    if guides:
        d = ImageDraw.Draw(bg); d.line([(128, 0), (128, 255)], fill=(40, 60, 220)); d.line([(0, 240), (255, 240)], fill=(220, 30, 30))
    c = bg.crop(box)
    return c.resize((c.width * sc, c.height * sc), Image.NEAREST)

def sheet(rows, title, path, note=None):
    # rows: list of (label, [images]) ; images same height per row
    pad = 8; lw = 190
    W = lw + max(sum(i.width + pad for i in ims) for _, ims in rows) + pad
    H = 34 + sum(max(i.height for i in ims) + 22 for _, ims in rows) + (16 * len(note.split(chr(10))) + 10 if note else 0)
    S = Image.new('RGB', (W, H), (24, 24, 30)); d = ImageDraw.Draw(S)
    d.text((pad, 8), title, fill=(240, 230, 205), font=FB)
    y = 34
    for lab, ims in rows:
        for li, line in enumerate(lab.split('\n')):
            d.text((pad, y + 20 + li * 16), line, fill=(235, 225, 200), font=F)
        x = lw
        for im in ims:
            S.paste(im, (x, y)); x += im.width + pad
        y += max(i.height for i in ims) + 22
    if note:
        for li, line in enumerate(note.split('\n')):
            d.text((pad, y + li * 16), line, fill=(200, 200, 210), font=F)
    S.save(path); print(path, S.size)

def ta():
    b = (40, 60, 216, 252)
    rows = []
    for st in ('idle_s', 'idle_n'):
        rows.append((f'herald {st} f0\nBEFORE', [frame(OLD, 'herald', st, k, b) for k in (0, 5)]))
        rows.append((f'herald {st} f0\nAFTER (centred)', [frame(NEW, 'herald', st, k, b) for k in (0, 5)]))
    # merge herald S/N side by side: simpler: one row per state with S f0, N f0
    rows = [('herald idle S | N (f0, f5)\nBEFORE', [frame(OLD, 'herald', s, k, b) for s in ('idle_s', 'idle_n') for k in (0, 5)]),
            ('herald idle S | N (f0, f5)\nAFTER: stance centred\non x=128 (blue)', [frame(NEW, 'herald', s, k, b) for s in ('idle_s', 'idle_n') for k in (0, 5)])]
    fb = (60, 120, 200, 252)
    rows += [('farmer walk_s f0-7\nBEFORE: f2/3/6/7 hop,\nper-sole AO blob', [frame(OLD, 'farmer', 'walk_s', k, fb) for k in range(8)]),
             ('farmer walk_s f0-7\nAFTER: support foot on\nrow 240, shared AO', [frame(NEW, 'farmer', 'walk_s', k, fb) for k in range(8)])]
    sheet(rows, 'TA fixes - before / after (blue = pivot x 128, red = ground row 240; 2x frames on grey)',
          f'{OUT}/ta_fixes_before_after.png')

def fix2():
    hb = (96, 96, 160, 150)
    rows = []
    for st in ('idle_n', 'walk_n', 'talk_n', 'work_n'):
        rows.append((f'last_watcher {st}\nBEFORE | AFTER\n(head, 4x, f0 f3)', [frame(OLD, 'last_watcher', st, k, hb, 4, False) for k in (0, 3)] +
                     [Image.new('RGB', (12, 216), (24, 24, 30))] + [frame(NEW, 'last_watcher', st, k, hb, 4, False) for k in (0, 3)]))
    fb = (24, 30, 232, 252)
    rows.append(('forge_master work_s\nf0 f3 f4 f6 (current)\nUNCHANGED', [frame(NEW, 'forge_master', 'work_s', k, fb) for k in (0, 3, 4, 6)]))
    rows.append(('forge_master work_n\nf0 f3 f4 f6 (current)\nUNCHANGED', [frame(NEW, 'forge_master', 'work_n', k, fb) for k in (0, 3, 4, 6)]))
    sheet(rows, 'fix 2 - last_watcher back view (no face / eye from behind) | forge_master overhead swing',
          f'{OUT}/fix2_forge_lastwatcher.png',
          note='last_watcher: old talk_n was talk_s flipped (face + eye on the back view) -> now built from back_stand; the dark hood-opening\n'
               'shadow (face profile / eye) on back_stand is trimmed + repainted with hood cloth for every N strip (roles/last_watcher.json "retouch").\n'
               'forge_master: NOT changed - a clean overhead swing cannot be warped out of the hands-on-pommel key without broken arms;\n'
               'needs painted overhead keys (front + back). Current swing = hammer windmills at chest height (shown above).')

ta(); fix2()
