from jlib import *
import shutil, sys
def half_rgba(src, size):
    m = np.asarray(Image.open(src)); rgb = m[..., :3].astype(np.float32) / 255; a = m[..., 3].astype(np.float32) / 255
    ah = np.clip(resize(a, size, cv2.INTER_LANCZOS4), 0, 1)
    ch = resize(rgb * a[..., None], size, cv2.INTER_LANCZOS4) / np.maximum(ah, 1e-3)[..., None]
    ch = np.where((ah > 0.02)[..., None], ch, resize(rgb, size, cv2.INTER_AREA))
    ah[ah < 1.5 / 255] = 0; ah[(ah < 64 / 255) & ~cv_dilate(ah >= 0.5, 2)] = 0; ah[ah > 254.5 / 255] = 1
    return (np.dstack([np.clip(ch, 0, 1), ah]) * 255 + .5).astype(np.uint8)
jobs = [('/workspace/scratch/v4/bm/back_mid_v4@2x.png', 'back_mid', (2048, 1280), '/workspace/scratch/v4/bm/back_mid_v4_sway.png', (2048, 1280)),
        ('/workspace/scratch/v4/bot/front_leaves_bottom_v2@2x.png', 'front_leaves_bottom', (1280, 240), '/workspace/scratch/v4/bot/front_leaves_bottom_v2_sway.png', (1280, 240))]
only = sys.argv[1:] or ['back_mid', 'front_leaves_bottom']
for src, name, hs, sw, ss in jobs:
    if name not in only: continue
    m = np.asarray(Image.open(src)); assert m.ndim == 3 and m.shape[2] == 4
    shutil.copyfile(src, SHIP + name + '@2x.png')
    save_rgba(half_rgba(src, hs), SHIP + name + '.png')
    s = Image.open(sw); assert s.size == ss and s.mode == 'L'; shutil.copyfile(sw, SHIP + name + '_sway.png')
    for n in (name + '@2x.png', name + '.png', name + '_sway.png'):
        im = Image.open(SHIP + n); x = np.asarray(im)
        if im.mode == 'RGBA':
            al = x[..., 3]; H, W = al.shape; cb = al[H // 4:3 * H // 4, W // 4:3 * W // 4]
            e = (al > 0) & (al < 255); r, g, b = [x[..., k][e].astype(int) for k in range(3)]
            print(n, im.size, 'opaque %.3f semi %.4f faint %d centre<32 %.1f%% edges255 %s pink-edge %d' % ((al == 255).mean(), e.mean(), int(((al > 0) & (al < 64)).sum()), (cb < 32).mean() * 100,
                  [bool((al[0] == 255).all()), bool((al[-1] == 255).all()), bool((al[:, 0] == 255).all()), bool((al[:, -1] == 255).all())], int(((r > g + 40) & (b > g + 40)).sum())))
        else: print(n, im.size, im.mode, 'min %d max %d' % (x.min(), x.max()))
