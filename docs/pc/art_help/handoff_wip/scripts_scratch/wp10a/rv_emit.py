"""Hand-tuned emit masks for Windmere (the generic colour rule lit every icicle and the snow): writes props/emit/(_2x/)<id>_emit.png."""
import sys, json
from pathlib import Path
import numpy as np, cv2
sys.path.insert(0, str(Path(__file__).parent))
from wp10a_common import load_rgba, save_l, smoothstep
import wp10a_props as P

KIT = Path('/workspace/stasium-pc-look/ship/wp10a_windmere')


def hsv(t):
    return P.hsv(t[..., :3])


def crystal_cores(t):
    h, s, v = hsv(t); a = t[..., 3]
    crystal = (smoothstep(180, 192, h) * (1 - smoothstep(222, 235, h)) * smoothstep(0.08, 0.16, s) * (a > 0.6)).astype(np.float32)
    inner = cv2.erode((crystal > 0.5).astype(np.uint8), np.ones((5, 5), np.uint8)).astype(np.float32)
    core = crystal * inner * smoothstep(0.78, 0.97, v)
    core = cv2.GaussianBlur(core, (0, 0), 1.6)
    return core / max(np.percentile(core[core > 0.05], 98) if (core > 0.05).sum() > 20 else 1, 1e-3)


def spire(t):
    h, s, v = hsv(t); a = t[..., 3]
    win = smoothstep(192, 200, h) * (1 - smoothstep(228, 238, h)) * smoothstep(0.42, 0.55, s) * smoothstep(0.45, 0.6, v) * (a > 0.6)
    # windows: roi_2x boxes around the six painted window panes (measured on props/_2x/frost_spire.png)
    roi = np.zeros_like(a)
    for x0, y0, x1, y1 in SPIRE_WINDOWS_2X: roi[y0:y1, x0:x1] = 1
    win = win * roi
    win = cv2.GaussianBlur(win.astype(np.float32), (0, 0), 0.9)
    ys = np.nonzero((a > 0.5).any(1))[0]; top, bot = ys.min(), ys.max()
    crown_rows = (1 - smoothstep(top + 0.13 * (bot - top), top + 0.19 * (bot - top), np.arange(t.shape[0]).astype(np.float32)))[:, None]
    crown = P.emit_mask(t, 'ice') * crown_rows * 0.85
    e = np.maximum(np.clip(win / max(np.percentile(win[win > 0.1], 97) if (win > 0.1).sum() > 20 else 1, 1e-3), 0, 1), crown)
    return e


# re-measured for the unrefitted spire (scale x1.0395 about the base contact vs the earlier +-132 px fit)
SPIRE_WINDOWS_2X = [(154, 129, 176, 171), (199, 127, 224, 174), (151, 212, 173, 257), (201, 212, 227, 260), (142, 321, 165, 371), (212, 323, 237, 373)]
RULES = {'ice_crystal_cluster': crystal_cores, 'frost_spire': spire}


def run():
    out = {}
    for pid, fn in RULES.items():
        t2 = load_rgba(KIT / 'props/_2x' / f'{pid}.png')
        e2 = np.clip(fn(t2), 0, 1) * smoothstep(0.02, 0.4, t2[..., 3])
        e1 = cv2.resize(e2, (t2.shape[1] // 2, t2.shape[0] // 2), interpolation=cv2.INTER_AREA)
        save_l(KIT / 'props/emit/_2x' / f'{pid}_emit.png', e2); save_l(KIT / 'props/emit' / f'{pid}_emit.png', e1)
        out[pid] = dict(coverage_gt_0_2=round(float((e2 > 0.2).mean()), 4), rule=fn.__doc__ or fn.__name__)
        print(pid, out[pid])
    return out


if __name__ == '__main__':
    run()
