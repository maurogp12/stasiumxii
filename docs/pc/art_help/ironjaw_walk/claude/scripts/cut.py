import numpy as np, cv2
from PIL import Image
def cut_target(path, tol=10):
    """Alpha-cut a repaint target from its flat grey background (flood fill from the border)."""
    rgb = np.array(Image.open(path).convert('RGB'))
    bg = np.median(np.concatenate([rgb[:8].reshape(-1,3), rgb[-8:].reshape(-1,3), rgb[:, :8].reshape(-1,3), rgb[:, -8:].reshape(-1,3)]), 0)
    d = np.abs(rgb.astype(int) - bg).max(2)
    near = (d <= tol).astype(np.uint8)
    n, lab = cv2.connectedComponents(near, connectivity=4)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bgm = np.isin(lab, list(border)) & (near > 0)
    a = (~bgm).astype(np.uint8)
    a = cv2.morphologyEx(a, cv2.MORPH_OPEN, np.ones((3,3), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(a, connectivity=8)
    keep = [i for i in range(1, n) if st[i, cv2.CC_STAT_AREA] > 400]
    a = np.isin(lab, keep)
    return rgb, a, bg
if __name__ == '__main__':
    import sys
    for f in 'SE':
        rgb, a, bg = cut_target(f'docs/pc/art_help/ironjaw_walk/repaint_targets/rp_{f}_f00_t1.jpg')
        ys, xs = np.nonzero(a); print(f, bg, xs.min(), xs.max(), ys.min(), ys.max(), a.mean())
        out = rgb.copy(); out[~a] = (255, 0, 255)
        Image.fromarray(out).resize((640, 360)).save(f'out/cut_{f}.png')
