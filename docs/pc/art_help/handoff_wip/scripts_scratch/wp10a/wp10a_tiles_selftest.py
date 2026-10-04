"""Prototype run of wp10a_tiles.py on existing / synthetic textures + seam metrics + previews (not shipped)."""
import json, sys
from pathlib import Path
import numpy as np, cv2
from PIL import Image
sys.path.insert(0, str(Path(__file__).parent))
from wp10a_common import hex2rgb, save_rgba, load_rgba, ROOT
import wp10a_tiles as T

OUT = ROOT / 'proto_tiles'
PREV = Path('/workspace/stasium-pc-look/previews/wp10a'); PREV.mkdir(parents=True, exist_ok=True)
SW = OUT / 'swatches'; SW.mkdir(parents=True, exist_ok=True)


def periodic_noise(n, seed, beta=2.2):
    rng = np.random.default_rng(seed)
    f = np.fft.fftfreq(n)[:, None] ** 2 + np.fft.fftfreq(n)[None, :] ** 2
    amp = 1 / np.maximum(f, 1 / n ** 2) ** (beta / 2)
    z = np.fft.ifft2(amp * np.exp(2j * np.pi * rng.random((n, n)))).real
    return ((z - z.min()) / np.ptp(z)).astype(np.float32)


def ramp(t, cols):
    cols = [hex2rgb(c) for c in cols]
    t = np.clip(t, 0, 1) * (len(cols) - 1)
    i = np.minimum(t.astype(int), len(cols) - 2); f = (t - i)[..., None]
    c0 = np.stack(cols)[i]; c1 = np.stack(cols)[i + 1]
    return c0 * (1 - f) + c1 * f


def make_swatches():
    n = 1024
    leaf = np.asarray(Image.open('/workspace/stasium-pc-look/raw/crosshaven_jungle/leaf_shadow_raw.png').convert('L').resize((n, n), Image.LANCZOS), np.float32) / 255
    g = 0.65 * leaf + 0.35 * periodic_noise(n, 1)
    meadow = ramp(g, ['#4f7a2c', '#7c9a2a', '#a6bd36', '#bdcb44', '#dcd65a'])
    Image.fromarray((meadow * 255).astype(np.uint8)).save(SW / 'meadow_test_swatch.png')
    soil = ramp(0.7 * periodic_noise(n, 2, 1.6) + 0.3 * periodic_noise(n, 3, 2.6), ['#4a3220', '#6c4a2c', '#9a6c44', '#b4844e'])
    Image.fromarray((soil * 255).astype(np.uint8)).save(SW / 'soil_test_swatch.png')
    v = (np.arange(n) + 0.5) / n
    rows = 8
    fur = 0.5 + 0.5 * np.sin(2 * np.pi * rows * v)[:, None] * np.ones((1, n))
    fur = 0.6 * fur + 0.4 * periodic_noise(n, 4, 2.0)
    till = ramp(fur, ['#4a3220', '#6c4a2c', '#9a6c44', '#c59a62'])
    Image.fromarray((till * 255).astype(np.uint8)).save(SW / 'tilled_test_swatch.png')
    # not seamless: a crop of the Crossroads still (grass) to exercise --fix-seams
    cr = Image.open(ROOT / 'refs/crossroads.png').convert('RGB').crop((1180, 820, 1436, 1076)).resize((n, n), Image.LANCZOS)
    cr.save(SW / 'crop_not_seamless_swatch.png')


def board_preview(tiles2, name, n=6, pick=None):
    pick = pick or (lambda x, y: [tiles2[T.hpick(x, y, len(tiles2))]])
    b = T.render_board(pick, n)
    Image.fromarray((np.clip(b, 0, 1) * 255).astype(np.uint8)[..., :3]).save(PREV / name)
    return b


def main():
    make_swatches()
    res = {}
    fam = {
        'meadow_test': dict(sw='meadow_test_swatch.png', var='a,b,c', kw=dict(fix=True)),
        'tilled_test': dict(sw='tilled_test_swatch.png', var='a,b', kw=dict(directional='u', edges=str(SW / 'meadow_test_swatch.png'), base_fix=True)),
        'soil_test': dict(sw='soil_test_swatch.png', var='a,b', kw=dict(edges=str(SW / 'meadow_test_swatch.png'), base_fix=True)),
        'crop_test': dict(sw='crop_not_seamless_swatch.png', var='a,b', kw=dict(fix=True)),
    }
    for f, d in fam.items():
        files, sc = T.build(str(SW / d['sw']), f, d['var'].split(','), OUT, **d['kw'])
        tex, _ = T.prep_swatch(str(SW / d['sw']), 0, d['kw'].get('fix', False))
        t2 = [load_rgba(OUT / 'tiles/_2x' / f'{f}_{v}.png') for v in d['var'].split(',')]
        m = T.seam_metric(t2, tex)
        # mixed variants: compare with continuous projection only in the edge band (variants must agree there)
        res[f] = dict(n_files=len(files), swatch_seam_score=sc, variant0_vs_continuous=m)
        # variant-agreement on the 2x edge band
        xw, yw = T.world_grid(T.W2, T.H2)
        band = (np.minimum.reduce([xw, 1 - xw, yw, 1 - yw]) < 0.05) & (t2[0][..., 3] > 0)
        res[f]['edge_band_max_diff_between_variants'] = float(max(np.abs(t[..., :3] - t2[0][..., :3]).max(-1)[band].max() for t in t2[1:]))
        board_preview(t2, f'tiles_{f}_board_2x.png')
        print(f, json.dumps(res[f]))
    # autotile demo: a tilled patch and a soil patch inside meadow, Crosshaven picker (edges + inner corners)
    n = 10
    patch = np.zeros((n, n), int)
    patch[2:6, 2:7] = 1; patch[6:9, 5:9] = 2; patch[4, 7] = 1
    names = {1: 'tilled_test', 2: 'soil_test'}
    meadow = [load_rgba(OUT / 'tiles/_2x' / f'meadow_test_{v}.png') for v in 'abc']
    cache = {}
    def tile(name):
        if name not in cache: cache[name] = load_rgba(OUT / 'tiles/_2x' / f'{name}.png')
        return cache[name]
    def joins(x, y, k):
        return 0 <= x < n and 0 <= y < n and patch[y, x] == k
    def pick(x, y):
        k = patch[y, x]
        if k == 0:
            return [meadow[T.hpick(x, y, 3)]]
        nb = {'nw': (x - 1, y), 'ne': (x, y - 1), 'se': (x + 1, y), 'sw': (x, y + 1)}
        g = [s for s in T.SIDES if not joins(*nb[s], k)]
        out = [tile(f"{names[k]}_edge_{'_'.join(g)}")] if g else [tile(f"{names[k]}_{'ab'[T.hpick(x, y, 2)]}")]
        dg = {'n': (x - 1, y - 1), 'e': (x + 1, y - 1), 's': (x + 1, y + 1), 'w': (x - 1, y + 1)}
        for c, (s1, s2) in T.CORNERS.items():
            if s1 not in g and s2 not in g and not joins(*dg[c], k):
                out.append(tile(f'{names[k]}_corner_{c}'))
        return out
    b = board_preview(None, 'tiles_autotile_demo_2x.png', n, pick)
    crop = b[150:150 + 300, b.shape[1] // 2 - 300: b.shape[1] // 2 + 300]
    Image.fromarray((np.clip(crop, 0, 1) * 255).astype(np.uint8)[..., :3]).resize((1200, 600), Image.NEAREST).save(PREV / 'tiles_autotile_demo_zoom2x.png')
    # 1x board for game-scale look
    m1 = [load_rgba(OUT / 'tiles' / f'meadow_test_{v}.png') for v in 'abc']
    b1 = T.render_board(lambda x, y: [m1[T.hpick(x, y, 3)]], 8, scale2x=False)
    Image.fromarray((np.clip(b1, 0, 1) * 255).astype(np.uint8)[..., :3]).save(PREV / 'tiles_meadow_test_board_1x.png')
    (PREV / 'tiles_selftest_metrics.json').write_text(json.dumps(res, indent=1))


if __name__ == '__main__':
    main()
