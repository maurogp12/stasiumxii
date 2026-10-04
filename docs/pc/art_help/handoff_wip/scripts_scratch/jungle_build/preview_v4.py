from preview_v3 import *
import preview_v3 as P3
ARCH3 = '/workspace/stasium-pc-look/ship_archive/crosshaven_jungle_v3/'
def compose4(folder, pan=(0, 0), ov=None):
    """like preview_v3.compose but any layer can be overridden: ov = {'back_mid@2x.png': path, ...}"""
    ov = ov or {}
    g = lambda n: ov.get(n, folder + n)
    frame = Image.new('RGBA', (PW, PH), (0, 0, 0, 255))
    frame.alpha_composite(placed(L(g('back_far@2x.png')), 1.06 * Z * S, PW / 2 - pan[0] * 0.12 * Z * S, PH / 2 - pan[1] * 0.12 * Z * S))
    bm = placed(L(g('back_mid@2x.png')), 0.5 * Z * S, PW / 2 - pan[0] * 0.40 * Z * S, PH / 2 - pan[1] * 0.40 * Z * S)
    frame.alpha_composite(bm)
    bma = np.asarray(bm)[..., 3].astype(np.float32) / 255
    sc = 0.5 * Z * S
    bl = placed(BOARD, sc, board_cx - pan[0] * Z * S, board_cy - pan[1] * Z * S)
    t = L(g('leaf_shadow@2x.png')).resize((round(1024 * sc), round(1024 * sc)), Image.LANCZOS); tw = t.width
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
        im = L(g(n + '@2x.png')); w, h = round(im.width * 0.5 * S), round(im.height * 0.5 * S)
        x = {'left': 0, 'right': PW - w}.get(pos, (PW - w) // 2); y = {'top': 0, 'bottom': PH - h}.get(pos, (PH - h) // 2)
        layer = Image.new('RGBA', (PW, PH), (0, 0, 0, 0)); layer.paste(im.resize((w, h), Image.LANCZOS), (x, y))
        frame.alpha_composite(layer)
        a = np.asarray(layer)[..., 3].astype(np.float32) / 255
        per[pos] = float((a[board_mask] > 0).mean() * 100)
        fa = 1 - (1 - fa) * (1 - a)
    cov = dict(any=float((fa[board_mask] > 0).mean() * 100), a50=float((fa[board_mask] > 0.5).mean() * 100), per=per)
    # ground metrics (back_mid alpha, before the board/front layers)
    cx, cy = board_cx - pan[0] * Z * S, board_cy - pan[1] * Z * S - (BOARD.height * sc) / 2 + 480 * sc
    hw, hh = 960 * sc, 480 * sc
    yy, xx = np.indices((PH, PW)).astype(np.float32)
    d = np.abs(xx - cx) / hw + np.abs(yy - cy) / hh
    band = (d > 1) & (d <= 1 + 30 / hh) & (yy >= cy)               # 30 screen px under the lower edges, incl. round the side corners
    below = (yy > cy) & (np.abs(xx - cx) <= hw + 60) & (yy < PH)     # everything under the corner line, corners +60 px
    gm = dict(band_ground=float((bma[band] >= 0.5).mean() * 100), below_line_hole=float((bma[below] < 0.5).mean() * 100),
              lower_half_behind=float((bma[(d <= 1) & (yy >= cy)] >= 0.5).mean() * 100))
    return frame, cov, gm
