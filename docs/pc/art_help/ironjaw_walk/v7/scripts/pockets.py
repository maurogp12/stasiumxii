import sys, numpy as np, cv2
from scipy import ndimage as ndi
sys.path.insert(0, '/workspace/handoff/ironjaw_walk_claude/claude_reply/scripts')
from cut import cut_target
from PIL import Image
def find_pockets(rgb, al, bg, tol=14, min_px=25, max_std=2.5, grow_tol=24):
    """enclosed backdrop pockets the border flood-fill could not reach (e.g. inside an axe crescent closed off by a cape strand)"""
    d = np.abs(rgb.astype(int) - np.asarray(bg, int)).max(2)
    L = rgb.astype(np.float32).mean(-1); sd = np.sqrt(np.maximum(cv2.blur(L * L, (5, 5)) - cv2.blur(L, (5, 5)) ** 2, 0))
    ch = rgb.max(2).astype(int) - rgb.min(2).astype(int)
    seed = (d <= tol) & (ch <= 6) & (sd < max_std) & al
    lab, n = ndi.label(seed); sz = np.bincount(lab.ravel()); sz[0] = 0
    out = np.isin(lab, np.nonzero(sz >= min_px)[0]) & seed
    info = []
    l2, n2 = ndi.label(out)
    for k in range(1, n2 + 1):
        ys, xs = np.nonzero(l2 == k); info.append((len(ys), int(xs.mean()), int(ys.mean())))
    grow = (d <= grow_tol) & al
    for _ in range(4): out = out | (ndi.binary_dilation(out) & grow)
    return out, info

if __name__ == '__main__':
    for F in 'SE':
        rgb, al, bg = cut_target(f'/workspace/scratch/ij_walk/repaint/rp_{F}_f00_t1.jpg')
        p, info = find_pockets(rgb, al, bg); print(F, bg, sorted(info, reverse=True)[:12])
        v = rgb.copy(); v[p] = (255, 0, 255); v[~al] = (v[~al] * 0.4).astype(np.uint8)
        Image.fromarray(v[:, 250:1030]).resize((390, 360)).save(f'pockets_{F}.png')
