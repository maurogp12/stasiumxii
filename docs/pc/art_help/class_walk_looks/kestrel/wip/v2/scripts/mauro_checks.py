"""Mauro's Bastion v2 feedback, checked on Kestrel (all measured on the rig render, i.e. what is saved to frames/):
 1 uniform leg scale: shin (boot shaft) width / shoulder width vs the target's (<= 8 %); along-bone stretch <= 1.10, across = s_up
 2 legs under the body: hip midpoint vs the target belt centre (+ pelvis delta) at f00 and f06 (<= 4 px)
 3 low swing-foot peak: swing foot lift above its ground track, cand vs blockout clay
 + knee visibility in the stride frames, head direction vs blockout chest yaw (de-isometrized)
usage: mauro_checks.py [out.json] [frames_dir]"""
import sys, os, json, math, numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kbuild as KB
from kcommon import *
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'mauro_checks.json')
FRAMES = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, '..', 'frames')   # saved frames (toe-off sole check)
# outer shoulder edges in target px (S: cape-over-shoulder left edge .. left pauldron; E: back, under the quiver .. right pauldron)
SHOULDER = {'S': ((538, 165), (722, 150)), 'E': ((560, 170), (698, 175))}
STRIDE = [11, 0, 1, 5, 6, 7]

def run_width(alpha, c, u, step=0.25, rmax=60):
    """width of the alpha>0.5 run through c along direction u (bilinear-free nearest sampling)."""
    H, W = alpha.shape; w = 0.0
    for sg in (1, -1):
        t = 0.0
        while t < rmax:
            p = c + sg * t * u; x, y = int(round(p[0])), int(round(p[1]))
            if not (0 <= x < W and 0 <= y < H) or alpha[y, x] <= 0.5: break
            t += step
        w += t
    return w

def lift_series(pairs, F, full):
    """foot lift per frame = the lower of (heel contact above the heel's ground track, toe contact above the toe's track);
    a track = the line along the ground motion EXP through that point in the full-plant frames."""
    e = EXP[F]; sl = e[1] / e[0]; out = None
    for k in (0, 1):
        c = np.array([p[k][1] - sl * p[k][0] for p in pairs]); g = float(np.median(c[full]))
        h = g - c; out = h if out is None else np.minimum(out, h)
    return [float(v) for v in out]

res = {}
for F in 'SE':
    KB.load_layers(F); c = KB.KCFG[F]; s = c['s_up']; A = KB.anchors(F); W = frames(F); pl = plants(F)
    Ks, As = np.array(A.get('Ks', A['K']), float), np.array(A.get('As', A['A']), float)
    shin_t = np.asarray(Image.open(f'{PARTS}T{F}_shin.png').convert('RGBA'))[..., 3] / 255.
    ua = unit(As - Ks); n_t = np.array([-ua[1], ua[0]]); mid_t = (Ks + As) / 2
    w_t = run_width(shin_t, mid_t, n_t, rmax=200)
    sh_t = math.dist(*SHOULDER[F]); r_t = w_t / sh_t
    foot_t = math.dist(A['heel'], A['toe'])
    rows = []; lifts = {sd: [] for sd in 'RL'}; clay = {sd: [] for sd in 'RL'}; knee = {}; hipchk = {}; stretch = []
    for i in range(12):
        acc, lay, owner, order, meta = KB.render(F, i); fr = W[i]
        Mt = KB.trunk_M(F, fr, W[0]); Mt0 = KB.trunk_M(F, W[0], W[0]); dp = jnt(fr, 'pelvis') - jnt(W[0], 'pelvis')
        sh_c = math.dist(*[Mt[:, :2] @ np.array(p, float) + Mt[:, 2] for p in SHOULDER[F]])
        for sd in 'RL':
            kn = np.array(meta[sd]['knee']); an = jnt(fr, sd + '_ankle'); u = unit(an - kn); n = np.array([-u[1], u[0]])
            w_c = run_width(lay[sd + '_shin'][..., 3], (kn + an) / 2, n)
            M = KB.foot_M(F, fr, sd, i, pl); fl_c = float(np.hypot(*(M[:, :2] @ (np.subtract(A['toe'], A['heel'])))))
            rows.append(dict(frame=i, leg=sd, shin_w=round(w_c, 2), shoulder_w=round(sh_c, 2), ratio=round(w_c / sh_c, 4),
                             dev_pct=round(100 * (w_c / sh_c / r_t - 1), 2), foot_len_ratio_dev_pct=round(100 * ((fl_c / sh_c) / (foot_t / sh_t) - 1), 2)))
            stretch.append((meta[sd]['ax_thigh'], meta[sd]['ax_shin']))
            cp = KB.contact_pts(F); lifts[sd].append((KB.apm(M, cp['HB']), KB.apm(M, cp['TB'])))     # visible heel / toe contact
            clay[sd].append((jnt(fr, sd + '_heel'), jnt(fr, sd + '_toe')))
            if i in STRIDE:   # knee: the knee point and its 3 px disc owned by this leg's thigh/shin (not body, front, cape, other leg)
                own = {order.index(sd + '_thigh'), order.index(sd + '_shin')} if (sd + '_thigh') in order else set()
                yy, xx = np.mgrid[-3:4, -3:4]; dsk = (yy ** 2 + xx ** 2) <= 9
                cx, cy = int(round(kn[0])), int(round(kn[1])); win = owner[cy - 3:cy + 4, cx - 3:cx + 4]
                knee[f'f{i:02d}_{sd}'] = round(float(np.isin(win[dsk], list(own)).mean()), 2)
        bc = Mt0[:, :2] @ (np.add(*map(np.array, c['belt'])) / 2.0) + Mt0[:, 2] + dp
        hm = (np.array(meta['R']['hip']) + np.array(meta['L']['hip'])) / 2
        hipchk[f'f{i:02d}'] = dict(hip_mid=[round(float(v), 2) for v in hm], belt_centre=[round(float(v), 2) for v in bc], dist_px=round(float(np.hypot(*(hm - bc))), 2))
    devs = [abs(r['dev_pct']) for r in rows]
    tl = (max(np.nonzero(target(F)[1].any(1))[0]) - c['hips'][c['src']][1]) * s     # target hip -> sole, cell px
    fullp = {sd: np.array([pl[sd]['heel'][j] and pl[sd]['toe'][j] for j in range(12)]) for sd in 'RL'}
    lift = {sd: dict(cand=[round(v, 1) for v in lift_series(lifts[sd], F, fullp[sd])], clay=[round(v, 1) for v in lift_series(clay[sd], F, fullp[sd])]) for sd in 'RL'}
    for sd in 'RL':
        sw = [j for j in range(12) if not (pl[sd]['heel'][j] or pl[sd]['toe'][j])]          # swing frames (nothing planted)
        lift[sd]['swing_frames'] = sw
        lift[sd]['cand_peak'] = max(lift[sd]['cand'][j] for j in sw); lift[sd]['clay_peak'] = max(lift[sd]['clay'][j] for j in sw)
        # toe-off: the metric's visible support-sole point (lowest boot pixel, cloak ignored) above its full-plant ground track,
        # cand vs clay (in iso the lowest pixel jumps heel -> toe when the heel lifts, so the clay value is not 0 either)
        import kestrel_metric as MM
        tf = [j for j in range(12) if pl[sd]['toe'][j] and not pl[sd]['heel'][j]]
        j0 = next(j for j in range(12) if fullp[sd][j] and not fullp[sd][(j + 1) % 12])
        e = EXP[F]; sl_ = e[1] / e[0]
        def vsole(D, j):
            jj = W[j]['joints']; xs = [jj[f'{sd}_toe'][0], jj[f'{sd}_heel'][0], jj[f'{sd}_ankle'][0]]
            r_, m_ = MM.load(D, F, j); q = MM.sole(m_ & ~MM.cloth(r_), min(xs) - 12, max(xs) + 12, jj[f'{sd}_ankle'][1] - 4); return q[1] - sl_ * q[0]
        to_ = {}
        for nm, D in (('cand', FRAMES), ('clay', B + 'clay')):
            g = vsole(D, j0); to_[nm] = [round(float(g - vsole(D, j)), 1) for j in tf]
        lift[sd]['toe_off'] = dict(frames=tf, cand=to_['cand'], clay=to_['clay'], max_abs_diff=round(max(abs(a - b) for a, b in zip(to_['cand'], to_['clay'])), 1))
        lift[sd]['cand_peak_pct_leg'] = round(100 * lift[sd]['cand_peak'] / tl, 1)
    # head: the S/E head is the target's painted head, rigid with the chest layer; vs the blockout chest yaw (shoulder line,
    # atan2(2 dy, dx) to undo the 2:1 iso, minus the cycle mean) the head-to-chest offset is minus that yaw
    yaw = []
    for fr in W:
        d = jnt(fr, 'L_shoulder') - jnt(fr, 'R_shoulder'); yaw.append(math.degrees(math.atan2(2 * d[1], d[0])))
    m = float(np.mean(yaw)); yaw = [round(y - m, 1) for y in yaw]
    res[F] = dict(
        target=dict(shin_w=round(w_t, 1), shoulder_w=round(sh_t, 1), ratio=round(r_t, 4), shoulder_pts=SHOULDER[F]),
        width_check=dict(max_abs_dev_pct=round(max(devs), 2), mean_abs_dev_pct=round(float(np.mean(devs)), 2), f00=[r for r in rows if r['frame'] == 0],
                         f06=[r for r in rows if r['frame'] == 6], foot_len_dev_pct_max=round(max(abs(r['foot_len_ratio_dev_pct']) for r in rows), 2),
                         passed=bool(max(devs) <= 8.0)),
        stretch=dict(max_along=round(max(max(a) for a in stretch), 3), min_along=round(min(min(a) for a in stretch), 3), across=1.0,
                     passed=bool(max(max(a) for a in stretch) <= 1.10 + 1e-6)),
        hip_check=dict(f00=hipchk['f00'], f06=hipchk['f06'], max_all_frames=max(v['dist_px'] for v in hipchk.values()),
                       passed=bool(max(hipchk['f00']['dist_px'], hipchk['f06']['dist_px']) <= 4.0)),
        swing_lift=dict(target_leg_len_cell=round(tl, 1), **lift, passed=bool(all(lift[sd]['cand_peak'] <= lift[sd]['clay_peak'] + 2.0 for sd in 'RL')),
                        toe_off_within_2px_of_blockout=bool(all(lift[sd]['toe_off']['max_abs_diff'] <= 2.0 for sd in 'RL'))),
        knee_visible=dict(frac=knee, min=min(knee.values()), passed=bool(min(knee.values()) >= 0.5)),
        head=dict(chest_yaw_dev_deg=yaw, f00_head_minus_chest=-yaw[0], f06_head_minus_chest=-yaw[6], max_abs=max(abs(v) for v in yaw), passed=bool(max(abs(v) for v in yaw) <= 10)),
        rows=rows)
json.dump(res, open(OUT, 'w'), indent=1)
for F in 'SE':
    r = res[F]; print(F, 'width', r['width_check']['max_abs_dev_pct'], 'stretch', r['stretch'], 'hip', r['hip_check']['f00']['dist_px'], r['hip_check']['f06']['dist_px'],
                      'lift', {sd: (r['swing_lift'][sd]['cand_peak'], r['swing_lift'][sd]['clay_peak'], r['swing_lift'][sd]['cand_peak_pct_leg']) for sd in 'RL'},
                      'knee', r['knee_visible']['frac'], 'head', r['head']['max_abs'])
