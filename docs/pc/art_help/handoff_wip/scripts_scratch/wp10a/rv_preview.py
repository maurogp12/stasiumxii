"""Previews for a WP10a region kit: prop contact sheets (grey + grass), tile sheet, mock board view, sails GIF."""
from __future__ import annotations
import json, sys, hashlib
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, str(Path(__file__).parent))

SHIP = Path('/workspace/stasium-pc-look/ship'); PREV = Path('/workspace/stasium-pc-look/previews')
try:
    FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 13)
except Exception:
    FONT = ImageFont.load_default()


def L(p):
    return Image.open(p).convert('RGBA')


def hpick(x, y, k, salt=0):
    return (((x * 73856093) ^ (y * 19349663) ^ (x * y * 83492791) ^ salt) & 0x7fffffff) % k


class Kit:
    def __init__(self, region):
        self.region = region; self.root = SHIP / f'wp10a_{region}'
        self.atlas = json.loads((self.root / 'atlas_meta.json').read_text()) if (self.root / 'atlas_meta.json').exists() else None

    def tile(self, tid, x2=True):
        return L(self.root / ('tiles/_2x' if x2 else 'tiles') / f'{tid}.png')

    def prop(self, pid, x2=True):
        return L(self.root / ('props/_2x' if x2 else 'props') / f'{pid}.png')

    def shadow0(self, pid, x2=True):
        p = self.root / ('animated/shadows/_2x' if x2 else 'animated/shadows') / f'{pid}_shadow_sway.png'
        if not p.exists(): return None
        im = L(p); n = 16; fw = im.size[0] // n
        return im.crop((0, 0, fw, im.size[1]))

    def sway_pad(self, pid, x2=True):
        p = self.root / ('animated/_2x' if x2 else 'animated') / f'{pid}_sway.png'
        if not p.exists(): return None
        im = Image.open(p); fw = im.size[0] // 16
        return (fw - self.prop(pid, x2).size[0]) // 2


def label_sheet(items, bg, cols, pad=10, title=None, scale=1):
    """items: [(name, RGBA image)] -> sheet with each image on its own background cell, bottom aligned."""
    cw = max(170, max(i.size[0] for _, i in items) * scale) + pad; ch = max(i.size[1] for _, i in items) * scale + pad + 18
    rows = (len(items) + cols - 1) // cols
    top = 26 if title else 0
    sheet = Image.new('RGBA', (cols * cw + pad, rows * ch + pad + top), (24, 24, 28, 255))
    d = ImageDraw.Draw(sheet)
    if title: d.text((pad, 6), title, fill=(235, 235, 235, 255), font=FONT)
    for k, (name, im) in enumerate(items):
        if scale != 1: im = im.resize((im.size[0] * scale, im.size[1] * scale), Image.NEAREST)
        x = pad + (k % cols) * cw; y = top + pad + (k // cols) * ch
        cell = bg(cw - pad, ch - pad - 18) if callable(bg) else Image.new('RGBA', (cw - pad, ch - pad - 18), bg)
        cell.alpha_composite(im, ((cell.size[0] - im.size[0]) // 2, cell.size[1] - im.size[1] - 4))
        sheet.alpha_composite(cell, (x, y))
        d.text((x, y + ch - pad - 16), name, fill=(220, 220, 220, 255), font=FONT)
    return sheet


def ground_bg(kit, base_ids):
    tiles = [kit.tile(t) for t in base_ids]
    def f(w, h):
        # simple iso fill: draw rows of diamonds
        img = Image.new('RGBA', (w, h), (0, 0, 0, 255))
        for r in range(-2, h // 32 + 3):
            for c in range(-2, w // 128 + 3):
                x = c * 128 + (64 if r % 2 else 0); y = r * 32 - 32
                img.alpha_composite(tiles[hpick(c, r, len(tiles))], (x - 64, y)) if x - 64 > -128 and x - 64 < w and y < h and y > -64 else None
        return img
    return f


def safe_composite(dst, src, xy):
    x, y = int(round(xy[0])), int(round(xy[1]))
    W, H = dst.size; w, h = src.size
    sx0, sy0 = max(0, -x), max(0, -y); sx1, sy1 = min(w, W - x), min(h, H - y)
    if sx1 <= sx0 or sy1 <= sy0: return
    dst.alpha_composite(src.crop((sx0, sy0, sx1, sy1)), (x + sx0, y + sy0))


def contact_sheets(kit, base_ids, out):
    ids = [p['id'] for p in kit.atlas['props']]
    items = [(i, kit.prop(i)) for i in ids]
    big = [it for it in items if it[1].size[0] > 200]; small = [it for it in items if it[1].size[0] <= 200]
    g = label_sheet(small, (128, 128, 128, 255), 6, title=f'{kit.region}: props at 2x on mid-grey')
    gb = label_sheet(big, (128, 128, 128, 255), len(big)) if big else None
    gr = label_sheet(small, ground_bg(kit, base_ids), 6, title=f'{kit.region}: props at 2x on {base_ids[0].rsplit("_", 1)[0]}')
    grb = label_sheet(big, ground_bg(kit, base_ids), len(big)) if big else None
    for name, a, b in (('props_2x_grey', g, gb), ('props_2x_grass', gr, grb)):
        if b:
            W = a.size[0] + b.size[0]; H = max(a.size[1], b.size[1])
            s = Image.new('RGBA', (W, H), (24, 24, 28, 255)); s.alpha_composite(a, (0, 0)); s.alpha_composite(b, (a.size[0], 0))
        else:
            s = a
        s.convert('RGB').save(out / f'{name}.png')


def tile_sheet(kit, out):
    tids = [t['id'] for t in kit.atlas['tiles']]
    fams = {}
    for t in kit.atlas['tiles']:
        fams.setdefault(t['base_terrain'], []).append(t['id'])
    items = [(t, kit.tile(t).resize((256, 128), Image.NEAREST)) for t in tids if '_edge_' not in t and '_corner_' not in t]
    s1 = label_sheet(items, (60, 60, 64, 255), 7, title=f'{kit.region}: ground variants (2x master, shown x2 nearest)')
    # seam boards: each family 6x6 using the hash picker over its variants
    boards = []
    for fam, ids in fams.items():
        var = [i for i in ids if '_edge_' not in i and '_corner_' not in i]
        tl = [kit.tile(i) for i in var]; n = 6
        img = Image.new('RGBA', (n * 128 + 8, n * 64 + 8), (12, 12, 14, 255))
        for s in range(2 * n - 1):
            for x in range(n):
                y = s - x
                if 0 <= y < n:
                    img.alpha_composite(tl[hpick(x, y, len(tl))], (4 + n * 64 + (x - y) * 64 - 64, 4 + (x + y) * 32))
        boards.append((f'{fam} 6x6 hash-picked', img))
    s2 = label_sheet(boards, (12, 12, 14, 255), len(boards), title='seam test boards (2x)')
    edge = [(t, kit.tile(t)) for t in tids if '_edge_' in t or '_corner_' in t]
    s3 = label_sheet(edge, (60, 60, 64, 255), 10, title='autotile edges / corners vs base ground (2x)') if edge else None
    parts = [s1, s2] + ([s3] if s3 else [])
    W = max(p.size[0] for p in parts); H = sum(p.size[1] for p in parts)
    sh = Image.new('RGBA', (W, H), (24, 24, 28, 255)); y = 0
    for p in parts: sh.alpha_composite(p, (0, y)); y += p.size[1]
    sh.convert('RGB').save(out / 'tiles_sheet.png')


NB = {'nw': (-1, 0), 'ne': (0, -1), 'se': (1, 0), 'sw': (0, 1)}
CO = {'n': ((-1, -1), ('nw', 'ne')), 'e': ((1, -1), ('ne', 'se')), 's': ((1, 1), ('se', 'sw')), 'w': ((-1, 1), ('nw', 'sw'))}


def mock_board(kit, layout, out, name='mock_board_view_2x', size=(1920, 1080), shadows=True):
    """layout: dict(n, ground: f(x,y)->family, base, variants{fam:[ids]}, props: [(id, (x,y) south cell)], statics: {..})"""
    n = layout['n']; base = layout['base']; var = layout['variants']
    T = {}
    def tile(t):
        if t not in T: T[t] = kit.tile(t)
        return T[t]
    W = n * 128 + 256; H = n * 64 + 600
    ox, oy = W // 2, 520
    img = Image.new('RGBA', (W, H), tuple(layout.get('void', (34, 44, 30))) + (255,))
    fam = {(x, y): layout['ground'](x, y) for x in range(n) for y in range(n)}
    edge_ids = {t['id'] for t in kit.atlas['tiles']}
    for s in range(2 * n - 1):
        for x in range(n):
            y = s - x
            if not 0 <= y < n: continue
            f = fam[(x, y)]
            px, py = ox + (x - y) * 64 - 64, oy + (x + y) * 32
            if f != base:
                sides = [sd for sd, (dx, dy) in NB.items() if fam.get((x + dx, y + dy), f) == base]
                order = [sd for sd in ('nw', 'ne', 'se', 'sw') if sd in sides]
                tid = f"{f}_edge_{'_'.join(order)}" if order else var[f][hpick(x, y, len(var[f]))]
                if tid not in edge_ids: tid = var[f][hpick(x, y, len(var[f]))]
                img.alpha_composite(tile(tid), (px, py))
                for c, ((dx, dy), (a, b)) in CO.items():
                    if a not in sides and b not in sides and fam.get((x + dx, y + dy), f) == base and f'{f}_corner_{c}' in edge_ids:
                        img.alpha_composite(tile(f'{f}_corner_{c}'), (px, py))
            else:
                img.alpha_composite(tile(var[base][hpick(x, y, len(var[base]), 5)]), (px, py))
    props = sorted(layout['props'], key=lambda p: (p[1][0] + p[1][1], p[1][0]))
    if shadows:
        for pid, (x, y) in props:
            sh = kit.shadow0(pid)
            if sh is None: continue
            pad = kit.sway_pad(pid); pim = kit.prop(pid)
            tipx, tipy = ox + (x - y) * 64, oy + (x + y) * 32 + 64
            safe_composite(img, sh, (tipx - pim.size[0] / 2 - pad, tipy - pim.size[1]))
    for pid, (x, y) in props:
        pim = kit.prop(pid)
        tipx, tipy = ox + (x - y) * 64, oy + (x + y) * 32 + 64
        safe_composite(img, pim, (tipx - pim.size[0] / 2, tipy - pim.size[1]))
    full = img
    # crop like the Crossroads mock: a 1920x1080 2x view centred on the patch
    cx, cy = ox, oy + n * 32 - 40
    view = full.crop((cx - size[0] // 2, cy - size[1] // 2, cx + size[0] // 2, cy + size[1] // 2))
    view.convert('RGB').save(out / f'{name}.png')
    full.convert('RGB').resize((full.size[0] // 2, full.size[1] // 2), Image.LANCZOS).save(out / f'{name}_full_half.png')
    return view


def sails_gif(kit, body_id, static_id, sid, hub2, fps, out):
    body = kit.prop(body_id); strip = L(kit.root / 'animated/_2x' / f'{sid}.png')
    fh = strip.size[1]; nf = strip.size[0] // fh
    frames = []
    for i in range(nf):
        bg = Image.new('RGBA', body.size, (128, 150, 90, 255)); bg.alpha_composite(body)
        fr = strip.crop((i * fh, 0, (i + 1) * fh, fh))
        cx = body.size[0] / 2 + hub2[0]; cy = body.size[1] + hub2[1]
        safe_composite(bg, fr, (cx - fh / 2, cy - fh / 2))
        frames.append(bg.convert('RGB').convert('P', palette=Image.ADAPTIVE, colors=255))
    frames[0].save(out / f'{sid}_on_body_2x.gif', save_all=True, append_images=frames[1:], duration=int(round(1000 / fps)), loop=0, disposal=1)
    # frame sheet (strip on grey + checker)
    sheet = Image.new('RGBA', (strip.size[0], fh * 2 + 20), (128, 128, 128, 255))
    sheet.alpha_composite(strip, (0, 0))
    yy, xx = np.indices((fh, strip.size[0]))
    chk = np.where(((yy // 16 + xx // 16) % 2) == 0, 90, 150).astype(np.uint8)
    cb = Image.fromarray(np.dstack([chk, chk, chk, np.full_like(chk, 255)]), 'RGBA'); cb.alpha_composite(strip)
    sheet.alpha_composite(cb, (0, fh + 20))
    d = ImageDraw.Draw(sheet)
    for i in range(nf):
        d.text((i * fh + 4, fh + 3), f'f{i} {i * 90 / nf:.1f} deg', fill=(255, 255, 255, 255), font=FONT)
    sheet.convert('RGB').save(out / f'{sid}_frames_2x.png')
