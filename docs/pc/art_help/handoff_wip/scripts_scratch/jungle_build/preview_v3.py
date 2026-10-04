from jlib import *
from PIL import ImageDraw, ImageFont
import json, sys
PV = '/workspace/stasium-pc-look/previews/crosshaven_jungle/'
S = 1.5; Z = 0.64; PW, PH = 1920, 1080
board_cx, board_cy = PW / 2, 300 * S
try: FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 26)
except Exception: FONT = ImageFont.load_default()
def placed(im, scale, cx, cy):
    w, h = round(im.width * scale), round(im.height * scale)
    layer = Image.new('RGBA', (PW, PH), (0, 0, 0, 0)); layer.paste(im.resize((w, h), Image.LANCZOS), (round(cx - w / 2), round(cy - h / 2)))
    return layer
TILE = Image.open('/workspace/stasium-pc-look/refs/crosshaven_v7/tiles_2x_golden_plains_a.png').convert('RGBA')
N = 15
BOARD = Image.new('RGBA', (N * 128, N * 64 + 8), (0, 0, 0, 0))
for i in range(N):
    for j in range(N):
        BOARD.alpha_composite(TILE, ((i - j) * 64 + (N - 1) * 64, (i + j) * 32))
_cache = {}
def L(path):
    if path not in _cache: _cache[path] = Image.open(path).convert('RGBA') if not path.endswith('leaf_shadow@2x.png') else Image.open(path)
    return _cache[path]
def compose(folder, pan=(0, 0), top=None):
    frame = Image.new('RGBA', (PW, PH), (0, 0, 0, 255))
    frame.alpha_composite(placed(L(folder + 'back_far@2x.png'), 1.06 * Z * S, PW / 2 - pan[0] * 0.12 * Z * S, PH / 2 - pan[1] * 0.12 * Z * S))
    frame.alpha_composite(placed(L(folder + 'back_mid@2x.png'), 0.5 * Z * S, PW / 2 - pan[0] * 0.40 * Z * S, PH / 2 - pan[1] * 0.40 * Z * S))
    sc = 0.5 * Z * S
    bl = placed(BOARD, sc, board_cx - pan[0] * Z * S, board_cy - pan[1] * Z * S)
    t = L(folder + 'leaf_shadow@2x.png').resize((round(1024 * sc), round(1024 * sc)), Image.LANCZOS); tw = t.width
    sh = Image.new('L', (PW + 2 * tw, PH + 2 * tw), 255)
    for y in range(0, sh.height, tw):
        for x in range(0, sh.width, tw): sh.paste(t, (x, y))
    ox = int(-pan[0] * Z * S) % tw; oy = int(-pan[1] * Z * S) % tw
    sh = np.asarray(sh.crop((tw - ox, tw - oy, tw - ox + PW, tw - oy + PH))).astype(np.float32) / 255
    b = np.asarray(bl).astype(np.float32) / 255
    b[..., :3] *= (1 - 0.5 * (1 - sh))[..., None]
    frame.alpha_composite(Image.fromarray((b * 255 + .5).astype(np.uint8), 'RGBA'))
    board_mask = b[..., 3] > 0.5
    fa = np.zeros((PH, PW), np.float32); per = {}
    for n, pos in (('front_leaves_top', 'top'), ('front_leaves_bottom', 'bottom'), ('front_leaves_left', 'left'), ('front_leaves_right', 'right')):
        p = top if (pos == 'top' and top) else folder + n + '@2x.png'
        im = L(p); w, h = round(im.width * 0.5 * S), round(im.height * 0.5 * S)
        x = {'left': 0, 'right': PW - w}.get(pos, (PW - w) // 2); y = {'top': 0, 'bottom': PH - h}.get(pos, (PH - h) // 2)
        layer = Image.new('RGBA', (PW, PH), (0, 0, 0, 0)); layer.paste(im.resize((w, h), Image.LANCZOS), (x, y))
        frame.alpha_composite(layer)
        a = np.asarray(layer)[..., 3].astype(np.float32) / 255
        per[pos] = float((a[board_mask] > 0).mean() * 100)
        fa = 1 - (1 - fa) * (1 - a)
    cov = dict(any=float((fa[board_mask] > 0).mean() * 100), a50=float((fa[board_mask] > 0.5).mean() * 100), per=per)
    return frame, cov
def label(frame, lines, xy):
    d = ImageDraw.Draw(frame); x, y = xy
    for ln in lines:
        d.text((x + 2, y + 2), ln, fill=(0, 0, 0, 255), font=FONT); d.text((x, y), ln, fill=(255, 255, 255, 255), font=FONT); y += 36
    return frame
PANS = [(0, 0), (220, 0), (-220, 0), (0, 220), (0, -220)]
if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'test':      # compare v1 top vs v3 candidate (nothing written to ship/previews)
        out = {}
        for tag, top in (('v1top', None), ('v3top', '/workspace/scratch/v3/front_leaves_top_v3@2x.png')):
            out[tag] = {}
            for p in PANS:
                fr, cov = compose(SHIP, p, top); out[tag][str(p)] = cov
                if p == (0, 0): fr.convert('RGB').save('/workspace/scratch/v3/test_%s.png' % tag)
                print(tag, p, 'any %.2f%% a>0.5 %.2f%%' % (cov['any'], cov['a50']), {k: round(v, 2) for k, v in cov['per'].items()}, flush=True)
        json.dump(out, open('/workspace/scratch/v3/coverage_test.json', 'w'), indent=1)
    else:                   # final: previews from the ship folder
        res = {}
        for p in PANS:
            fr, cov = compose(SHIP, p); res[str(p)] = cov
            print('ship', p, 'any %.2f%% a>0.5 %.2f%%' % (cov['any'], cov['a50']), {k: round(v, 2) for k, v in cov['per'].items()}, flush=True)
            if p == (0, 0): main = fr
        json.dump(res, open('/workspace/scratch/v3/coverage_final.json', 'w'), indent=1)
        g = lambda p: res[str(p)]['any']
        tag = sys.argv[2] if len(sys.argv) > 2 else ''
        label(main, ['Front leaves over board (any alpha): default camera %.2f%%' % g((0, 0)),
                     'pan x +220 %.2f%% | x -220 %.2f%% | y -220 %.2f%% | y +220 %.2f%%' % (g((220, 0)), g((-220, 0)), g((0, -220)), g((0, 220))),
                     tag], (20, PH - 3 * 36 - 20))
        main.convert('RGB').save(PV + '_preview_composite.png', optimize=True)
        tiles = []
        for p in [(-220, 0), (220, 0), (0, -220), (0, 220)]:
            fr, cov = compose(SHIP, p)
            fr = label(fr, ['pan %s: covered %.2f%%' % (str(p), cov['any'])], (20, 20))
            tiles.append(fr.convert('RGB').resize((960, 540), Image.LANCZOS))
        grid = Image.new('RGB', (1920, 1080))
        for i, t in enumerate(tiles): grid.paste(t, ((i % 2) * 960, (i // 2) * 540))
        grid.save(PV + '_preview_pan220.png', optimize=True)
        print('previews written', flush=True)
