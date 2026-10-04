from jlib import *
import shutil
D = '/workspace/scratch/v3/bm/'
m = np.asarray(Image.open(D + 'back_mid_v3@2x.png')); assert m.shape == (2560, 4096, 4)
rgb = m[..., :3].astype(np.float32) / 255; a = m[..., 3].astype(np.float32) / 255
ah = np.clip(resize(a, (2048, 1280), cv2.INTER_LANCZOS4), 0, 1)
ch = resize(rgb * a[..., None], (2048, 1280), cv2.INTER_LANCZOS4) / np.maximum(ah, 1e-3)[..., None]
ch = np.where((ah > 0.02)[..., None], ch, resize(rgb, (2048, 1280), cv2.INTER_AREA))
ah[ah < 1.5 / 255] = 0; ah[(ah < 64 / 255) & ~cv_dilate(ah >= 0.5, 2)] = 0
ah[ah > 254.5 / 255] = 1
half = (np.dstack([np.clip(ch, 0, 1), ah]) * 255 + .5).astype(np.uint8)
shutil.copyfile(D + 'back_mid_v3@2x.png', SHIP + 'back_mid@2x.png')
save_rgba(half, SHIP + 'back_mid.png')
sw = Image.open(D + 'back_mid_v3_sway.png'); assert sw.size == (2048, 1280) and sw.mode == 'L'
shutil.copyfile(D + 'back_mid_v3_sway.png', SHIP + 'back_mid_sway.png')
for n in ('back_mid@2x.png', 'back_mid.png'):
    x = np.asarray(Image.open(SHIP + n)); al = x[..., 3]; H, W = al.shape; cb = al[H // 4:3 * H // 4, W // 4:3 * W // 4]
    e = (al > 0) & (al < 255); r, g, b = [x[..., k][e].astype(int) for k in range(3)]
    print(n, x.shape, 'centre<32 %.1f%%' % ((cb < 32).mean() * 100), 'edges opaque', [(al[0] == 255).all(), (al[-1] == 255).all(), (al[:, 0] == 255).all(), (al[:, -1] == 255).all()],
          'min side solid px L/R', int(np.argmax(al < 255, 1)[(al < 255).any(1)].min()), int((W - 1 - np.argmax(al[:, ::-1] < 255, 1))[(al < 255).any(1)].max()), 'pink edge px', int(((r > g + 40) & (b > g + 40)).sum()))
