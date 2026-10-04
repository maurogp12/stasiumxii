from jlib import *
import shutil
D = '/workspace/scratch/v3/'
m = np.asarray(Image.open(D + 'front_leaves_top_v3@2x.png'))
assert m.shape == (480, 2560, 4)
rgb = m[..., :3].astype(np.float32) / 255; a = m[..., 3].astype(np.float32) / 255
# half-size fallback: alpha-weighted Lanczos on colour (straight alpha out), Lanczos on alpha
ah = np.clip(resize(a, (1280, 240), cv2.INTER_LANCZOS4), 0, 1)
ch = resize(rgb * a[..., None], (1280, 240), cv2.INTER_LANCZOS4) / np.maximum(ah, 1e-3)[..., None]
fill = resize(rgb, (1280, 240), cv2.INTER_AREA)
ch = np.where((ah > 0.02)[..., None], ch, fill)
ah[ah < 1.5 / 255] = 0
ah[(ah < 64 / 255) & ~cv_dilate(ah >= 0.5, 2)] = 0     # Lanczos ringing specks
half = (np.dstack([np.clip(ch, 0, 1), ah]) * 255 + .5).astype(np.uint8)
shutil.copyfile(D + 'front_leaves_top_v3@2x.png', SHIP + 'front_leaves_top@2x.png')
save_rgba(half, SHIP + 'front_leaves_top.png')
sw = Image.open(D + 'front_leaves_top_v3_sway.png'); assert sw.size == (1280, 240) and sw.mode == 'L'
shutil.copyfile(D + 'front_leaves_top_v3_sway.png', SHIP + 'front_leaves_top_sway.png')
for n in ('front_leaves_top@2x.png', 'front_leaves_top.png', 'front_leaves_top_sway.png'):
    im = Image.open(SHIP + n); x = np.asarray(im)
    info = ''
    if im.mode == 'RGBA':
        al = x[..., 3]; info = 'opaque %.3f semi %.4f faint(1-63) %d top-row-opaque %.3f bottom-row-max %d' % ((al == 255).mean(), ((al > 0) & (al < 255)).mean(), int(((al > 0) & (al < 64)).sum()), (al[0] == 255).mean(), al[-1].max())
        # pink fringe check on visible edge px
        e = (al > 0) & (al < 255); r, g, b = [x[..., k][e].astype(int) for k in range(3)]
        info += ' pink-edge-px %d' % int(((r > g + 40) & (b > g + 40)).sum())
    else: info = 'min %d max %d top-row-max %d' % (x.min(), x.max(), x[0].max())
    print(n, im.size, im.mode, info)
