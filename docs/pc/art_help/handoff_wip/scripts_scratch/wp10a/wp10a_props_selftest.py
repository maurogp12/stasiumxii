"""Prototype the prop + sail pipeline on stand-in raws (Crosshaven sprites blown up onto drifting flat backgrounds,
plus a real Scenario raw on black from Thunderwell). Writes to scratch + previews only, never to ship/."""
import json, sys
from pathlib import Path
import numpy as np, cv2
from PIL import Image
sys.path.insert(0, str(Path(__file__).parent))
from wp10a_common import ROOT, CROSSHAVEN, load_rgba, save_rgba, over, checker, premul, resize_pm, load_manifest
import wp10a_props as P, wp10a_sails as S, wp10a_tiles as T

RAW = ROOT / 'proto_raw'; OUT = ROOT / 'proto_out'; PREV = Path('/workspace/stasium-pc-look/previews/wp10a')
M = load_manifest()


def fake_raw(src, dst, bg, size=2048, scale=None, vignette=0.06, shadow=True, text=True, seed=0):
    rng = np.random.default_rng(seed)
    spr = load_rgba(src)
    sc = scale or (size * 0.62) / max(spr.shape[:2])
    spr = resize_pm(spr, (int(spr.shape[1] * sc), int(spr.shape[0] * sc)), cv2.INTER_CUBIC)
    base = np.ones((size, size, 3), np.float32) * (0.985 if bg == 'white' else 0.012)
    yy, xx = np.indices((size, size), np.float32)
    r = np.hypot(xx - size / 2, yy - size / 2) / (size / 2)
    base += ((-vignette if bg == 'white' else vignette * 0.5) * r ** 2)[..., None] * np.array([1, 0.98, 0.9], np.float32)
    img = np.dstack([base, np.ones((size, size), np.float32)])
    h, w = spr.shape[:2]; y0 = int(size * 0.84) - h; x0 = (size - w) // 2
    if shadow:   # a painted ground shadow, the kind Scenario adds
        ell = np.zeros((size, size), np.float32)
        cv2.ellipse(ell, (size // 2 + w // 6, int(size * 0.84) - 10), (int(w * 0.45), int(w * 0.13)), 0, 0, 360, 1, -1)
        ell = cv2.GaussianBlur(ell, (0, 0), 18) * (0.35 if bg == 'white' else 0.5)
        img[..., :3] = img[..., :3] * (1 - ell[..., None]) + (np.array([0.45, 0.45, 0.5]) if bg == 'white' else np.array([0.1, 0.1, 0.12])) * ell[..., None]
    layer = np.zeros_like(img); layer[y0:y0 + h, x0:x0 + w] = spr
    img = over(layer, img)
    rgb = img[..., :3] + rng.normal(0, 0.006, img[..., :3].shape).astype(np.float32)
    rgb8 = (np.clip(rgb, 0, 1) * 255).astype(np.uint8)
    if text:
        cv2.putText(rgb8, 'Scenario #1400', (60, size - 60), cv2.FONT_HERSHEY_SIMPLEX, 2.0, (40, 40, 40) if bg == 'white' else (200, 200, 200), 4)
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgb8).save(dst)


def fake_sails(dst, size=2048):
    img = np.full((size, size, 3), 250, np.uint8)
    c = size // 2
    for k in range(4):
        ang = np.deg2rad(90 * k + 8)
        d = np.array([np.cos(ang), -np.sin(ang)]); n = np.array([-d[1], d[0]])
        p0 = np.array([c, c]) + d * 70; p1 = np.array([c, c]) + d * 900
        cv2.line(img, tuple(p0.astype(int)), tuple(p1.astype(int)), (86, 54, 26), 26, cv2.LINE_AA)
        quad = np.array([p0 + d * 120 + n * 18, p1 + n * 18, p1 + n * 210, p0 + d * 160 + n * 170], np.int32)
        cv2.fillConvexPoly(img, quad, (232, 220, 190), cv2.LINE_AA)
        for t in np.linspace(0.18, 0.98, 9):
            a = p0 + d * (120 + t * 760); cv2.line(img, tuple((a + n * 18).astype(int)), tuple((a + n * 205).astype(int)), (120, 84, 46), 7, cv2.LINE_AA)
        cv2.polylines(img, [quad], True, (42, 28, 18), 8, cv2.LINE_AA)
    cv2.circle(img, (c, c), 64, (70, 46, 24), -1, cv2.LINE_AA); cv2.circle(img, (c, c), 64, (42, 28, 18), 8, cv2.LINE_AA)
    Image.fromarray(img).save(dst)


CASES = {
    'rowanvale': [('tree_apple_orchard', 'props/_2x/tree_apple.png'), ('fence_orchard_nwse', 'props/_2x/fence_wood_nwse.png'),
                  ('stone_wall_field_nwse', 'props/_2x/market_stall.png'), ('bush_flower_meadow', 'props/_2x/bush_flower.png'),
                  ('old_windmill_body', 'props/_2x/windmill_2x2_body.png'), ('border_orchard_hedge', 'props/_2x/border_forest_a.png')],
    'windmere': [('tree_pine_snowy_a', 'props/_2x/tree_pine.png'), ('lantern_post_warm', 'props/_2x/lamp_post.png'),
                 ('frost_spire', 'props/_2x/northgate_spire.png'), ('ice_crystal_cluster', None)],
}


def sheet(region, reps):
    tiles = []
    for r in reps:
        aid = r['id']
        t2 = load_rgba(OUT / region / 'props/_2x' / f'{aid}.png'); t1 = load_rgba(OUT / region / 'props' / f'{aid}.png')
        asset = next(a for a in next(g for g in M['regions'] if g['id'] == region)['assets'] if a['id'] == aid)
        H, W = t2.shape[:2]
        bg = checker(H, W, 8, 0.82, 0.9) if region == 'windmere' else checker(H, W, 8, 0.2, 0.28)
        fp = P.footprint_mask((H, W), (W / 2, H), asset['footprint_size'], 2)
        edge = (cv2.dilate(fp, np.ones((3, 3))) - fp)
        bg[..., :3] = bg[..., :3] * (1 - edge[..., None]) + np.array([1, 0.3, 0.2]) * edge[..., None]
        comp = over(t2, bg)
        comp[-3:, W // 2 - 2:W // 2 + 2, :3] = [1, 0, 1]                    # anchor (south tip)
        g = r['contact_2x']; comp[int(g[1]) - 2:int(g[1]) + 2, int(g[0]) - 2:int(g[0]) + 2, :3] = [0, 1, 1]
        col = [comp]
        c1 = over(t1, checker(*t1.shape[:2], 4, *((0.82, 0.9) if region == 'windmere' else (0.2, 0.28))))
        col.append(np.pad(c1, ((0, H - c1.shape[0]), (0, 0), (0, 0)), constant_values=1))
        sw = OUT / region / 'animated/_2x' / f'{aid}_sway.png'
        if sw.exists():
            strip = load_rgba(sw); fw = strip.shape[1] // 16
            for i in (0, 4, 8, 12):
                f = strip[:, i * fw:(i + 1) * fw]
                col.append(over(f, checker(*f.shape[:2], 8, 0.2, 0.28)))
            shs = load_rgba(OUT / region / 'animated/shadows/_2x' / f'{aid}_shadow_sway.png'); sfw = shs.shape[1] // 16
            s0 = shs[:, :sfw]; f0 = np.pad(strip[:, :fw], ((0, s0.shape[0] - strip.shape[0]), (0, s0.shape[1] - fw), (0, 0)))
            ground = np.ones(s0.shape, np.float32); ground[..., :3] = [0.66, 0.74, 0.3]
            col.append(over(f0, over(s0, ground)))
            mk = np.asarray(Image.open(OUT / region / 'animated/sway_masks/_2x' / f'{aid}_swaymask.png'), np.float32) / 255
            col.append(np.dstack([mk, mk, mk, np.ones_like(mk)]))
        em = OUT / region / 'props/emit/_2x' / f'{aid}_emit.png'
        if em.exists():
            e = np.asarray(Image.open(em), np.float32) / 255; col.append(np.dstack([e, e * 0.9, e * 0.6, np.ones_like(e)]))
        hmax = max(c.shape[0] for c in col)
        col = [np.pad(c, ((0, hmax - c.shape[0]), (0, 6), (0, 0)), constant_values=1) for c in col]
        tiles.append(np.concatenate(col, 1))
    wmax = max(t.shape[1] for t in tiles)
    img = np.concatenate([np.pad(t, ((0, 8), (0, wmax - t.shape[1]), (0, 0)), constant_values=1) for t in tiles], 0)
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)[..., :3]).save(PREV / f'props_proto_sheet_{region}.png')


def scene(region, reps):
    """1x mini board: test meadow tiles + processed props placed with the kit anchor rule (draw at tip - (w/2, h))."""
    n = 7
    m1 = [load_rgba(ROOT / 'proto_tiles/tiles' / f'meadow_test_{v}.png') for v in 'abc']
    board = T.render_board(lambda x, y: [m1[T.hpick(x, y, 3)]], n, scale2x=False)
    pad = 140
    board = np.pad(board, ((pad, 10), (10, 10), (0, 0)), mode='edge')
    ox = board.shape[1] // 2; oy = 2 + pad
    spots = {'rowanvale': [(1, 1), (3, 0), (1, 3), (0, 5), (4, 4), (6, 2)], 'windmere': [(1, 1), (3, 1), (4, 4), (1, 4)]}[region]
    items = []
    for (x, y), r in zip(spots, reps):
        asset = next(a for a in next(g for g in M['regions'] if g['id'] == region)['assets'] if a['id'] == r['id'])
        fx, fy = asset['footprint_size']; sx_, sy_ = x + fx - 1, y + fy - 1
        items.append((sx_ + sy_, sx_, sy_, r['id']))
    for _, sx_, sy_, aid in sorted(items):
        t1 = load_rgba(OUT / region / 'props' / f'{aid}.png')
        tipx = ox + (sx_ - sy_) * 32; tipy = oy + (sx_ + sy_) * 16 + 32
        h, w = t1.shape[:2]; x0, y0 = tipx - w // 2, tipy - h
        board[y0:y0 + h, x0:x0 + w] = over(t1, board[y0:y0 + h, x0:x0 + w])
    big = cv2.resize(board, None, fx=2, fy=2, interpolation=cv2.INTER_NEAREST)
    Image.fromarray((np.clip(big, 0, 1) * 255).astype(np.uint8)[..., :3]).save(PREV / f'props_proto_scene_{region}_1x_at200.png')


def main():
    for region, cases in CASES.items():
        bg = 'white' if region == 'rowanvale' else 'black'
        for aid, src in cases:
            dst = RAW / region / f'{aid}.png'
            if src:
                fake_raw(CROSSHAVEN / src, dst, bg, seed=hash(aid) % 1000)
            else:
                im = Image.open('/workspace/stasium-pc-look/raw/thunderwell_props_v1/capacitor_crystal.png'); im.save(dst)
        reg = next(g for g in M['regions'] if g['id'] == region)
        reps = []
        for aid, _ in cases:
            asset = next(a for a in reg['assets'] if a['id'] == aid)
            r = P.process(asset, RAW / region / f'{aid}.png', OUT / region, OUT / f'{region}_props_check', dict(shadow_cut=True))
            reps.append(r)
            print(region, aid, 'art_x', r.get('art_x_from_anchor_2x'), 'h', r.get('art_height_2x'), 'bg', r['bg_border_median'],
                  'range', r['bg_field_range_dE'], 'dropped', r.get('dropped_stray_px'), r.get('warnings', ''))
        (OUT / f'{region}_props_check' / 'props.json').write_text(json.dumps(dict(package=f'wp10a_{region}', version=1,
            props=[P.props_json_entry(next(a for a in reg['assets'] if a['id'] == r['id']), r) for r in reps]), indent=1, default=float))
        (OUT / f'{region}_props_report.json').write_text(json.dumps(reps, indent=1, default=float))
        sheet(region, reps); scene(region, reps)
    fake_sails(RAW / 'rowanvale/old_windmill_sails.png')
    rep = S.build(RAW / 'rowanvale/old_windmill_sails.png', OUT / 'rowanvale')
    print('sails', json.dumps(rep, default=float))
    # body + sails frame 0 at the manifest hub
    body = load_rgba(OUT / 'rowanvale/props/_2x/old_windmill_body.png')
    st = load_rgba(OUT / 'rowanvale/animated/_2x/old_windmill_sails.png'); fw = st.shape[0]
    hub = next(a for a in M['regions'][0]['assets'] if a['id'] == 'old_windmill_body')['strip']['hub_from_anchor_2x']
    frames = []
    for i in (0, 3, 6, 9):
        canvas = np.zeros((body.shape[0] + 40, body.shape[1] + 80, 4), np.float32)
        canvas[40:, 40:40 + body.shape[1]] = body
        cx = 40 + body.shape[1] // 2 + hub[0]; cy = 40 + body.shape[0] + hub[1]
        fr = st[:, i * fw:(i + 1) * fw]
        y0, x0 = cy - fw // 2, cx - fw // 2
        yy0, xx0 = max(0, y0), max(0, x0)
        sub = fr[yy0 - y0:, xx0 - x0:][:canvas.shape[0] - yy0, :canvas.shape[1] - xx0]
        canvas[yy0:yy0 + sub.shape[0], xx0:xx0 + sub.shape[1]] = over(sub, canvas[yy0:yy0 + sub.shape[0], xx0:xx0 + sub.shape[1]])
        frames.append(over(canvas, checker(*canvas.shape[:2], 8, 0.2, 0.28)))
    Image.fromarray((np.clip(np.concatenate(frames, 1), 0, 1) * 255).astype(np.uint8)[..., :3]).save(PREV / 'props_proto_windmill_sails_2x.png')


if __name__ == '__main__' and len(sys.argv) == 1:
    main()
    atlas_drafts_pending = True


def atlas_drafts():
    import wp10a_atlas as A
    for region in ('rowanvale', 'windmere'):
        at = A.build(region, OUT / region, OUT / f'{region}_props_report.json')
        print(region, 'atlas', len(at['tiles']), 'tiles', len(at['props']), 'props', at['animated']['count'], 'anims',
              at['wp10a']['status'], 'missing', len(at['wp10a']['missing']))


if __name__ == '__main__':
    atlas_drafts()
