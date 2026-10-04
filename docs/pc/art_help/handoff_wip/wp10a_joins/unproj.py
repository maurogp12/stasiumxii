"""Unproject a seamless Crosshaven 2x floor tile (128x64 diamond) back into a cell-periodic square texture."""
import numpy as np, cv2
from scipy.ndimage import map_coordinates
from wp10a_common import load_rgba

def unproject(path, n=1024, inset=0.75):
    t = load_rgba(path)
    uu, vv = np.meshgrid((np.arange(n) + 0.5) / n, (np.arange(n) + 0.5) / n)   # u = x world (cols), v = y world (rows)
    X = 64 + 64 * (uu - vv); Y = 32 * (uu + vv)
    # pull points inward so every tap lies on fully opaque pixels (tile is seamless, so the rim is redundant)
    cx, cy = 64.0, 32.0
    d = np.abs(X - cx) / 64 + np.abs(Y - cy) / 32           # 1 on the diamond edge
    lim = 1 - inset * 2 / 64                                 # ~inset px (2x) inside the edge
    s = np.where(d > lim, lim / np.maximum(d, 1e-6), 1.0)
    X = cx + (X - cx) * s; Y = cy + (Y - cy) * s
    out = np.stack([map_coordinates(t[..., c], [Y - 0.5, X - 0.5], order=3, mode='nearest') for c in range(3)], -1)
    return np.clip(out, 0, 1).astype(np.float32)
