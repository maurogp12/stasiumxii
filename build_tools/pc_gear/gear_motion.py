#!/usr/bin/env python3
"""Visible gear (paper doll): motion measures for the rig, and the motion pass.

measure(R)  poses every frame of every kind through the rig (no drawing) and
            returns the tracks and numbers the review and the tests use:
            planted-foot slide in world px at zoom 1 against the walker's
            ground speed, the body bob as a share of the standing height, the
            arm-to-leg phase, the axe (forearm) lag behind the upper arm, and
            the loop seam (last frame to first, against the frame-to-frame
            steps).

usage: gear_motion.py --work DIR [--out motion.json]
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

# Cell (512 rig px) -> world px at zoom 1: the locked sheet scale times the
# world draw scale (units/pc_gear_specs.gd WORLD.ironjaw.draw_scale).
SHEET_K = 0.5547
# Screen direction of travel per art facing: S is the walker's e (down-right),
# E its n (up-right), both 2:1 iso.
MOVE = {"S": np.array([2.0, 1.0]) / math.sqrt(5.0), "E": np.array([2.0, -1.0]) / math.sqrt(5.0)}
LOOPS = ("walk", "run", "idle")


def _ang(v):
    return math.atan2(v[1], v[0])


def _wrap(a):
    return (a + math.pi) % (2 * math.pi) - math.pi


def pose_points(R, F, act, i):
    """Rig points of one frame (512 px cell space)."""
    Mt, _ = R.torso_M(F, act, i)
    pj = R.PJ[F]
    out = {"pelvis": R.apm(Mt, pj["pelvis"]).tolist(), "neck": R.apm(Mt, pj["neck"]).tolist()}
    for sd in "RL":
        L = R.leg_pose(F, act, i, sd, Mt)
        a = R.arm_pose(F, act, i, sd, Mt)
        out[sd] = {"hip": list(map(float, L["hip"])), "knee": list(map(float, L["knee"])), "ankle": list(map(float, L["ankle"])),
                   "heel": list(map(float, L["heel"])), "toe": list(map(float, L["toe"])),
                   "sh": a["sh"].tolist(), "elbow": a["elbow"].tolist(), "grip": a["grip"].tolist()}
    return out


def planted_flags(R, F, act, sd, n, step):
    """the frames a foot is planted: from the motion pass, or (the TA walk) where it does not move."""
    pl = getattr(R, "PLANTED", {}).get((F, act))
    if pl is not None:
        return list(pl[sd])
    return [bool(s < 0.75) for s in step]


def harmonic(x, k=1):
    """phase (rad) and amplitude of the k-th harmonic of one loop."""
    x = np.asarray(x, float)
    n = len(x)
    t = np.arange(n) / n * 2 * math.pi * k
    c, s = (x * np.cos(t)).sum() * 2 / n, (x * np.sin(t)).sum() * 2 / n
    return math.atan2(s, c), math.hypot(c, s)


def measure(R, acts, world):
    """world: {"draw_scale", "height", "walk"/"run": {"shown_stride"}} (pc_gear_specs WORLD)."""
    k = SHEET_K * float(world["draw_scale"])
    out = {"cell_to_world": k, "kinds": {}}
    for act in acts:
        n = R.ACTS[act]
        for F in "SE":
            P = [pose_points(R, F, act, i) for i in range(n)]
            rec = {"frames": P}
            pel = np.array([p["pelvis"] for p in P])
            # standing height: helm top row to the sole line of idle f00 (rig px)
            H = float(R.PIV[1] - R.IDLE_TOP) if hasattr(R, "PIV") else 265.0
            rec["height_px"] = H
            rec["bob_pct"] = round(float((pel[:, 1].max() - pel[:, 1].min()) / H * 100), 3)
            rec["sway_px"] = round(float(pel[:, 0].max() - pel[:, 0].min()), 2)
            if act in ("walk", "run") and act in world:
                adv = float(world[act]["shown_stride"]) / n / k        # cell px the root moves per frame
                ax = MOVE[F]
                slide = {}
                for sd in "RL":
                    foot = np.array([(np.array(p[sd]["heel"]) + np.array(p[sd]["toe"])) / 2 for p in P])
                    wpos = foot + np.arange(n)[:, None] * adv * ax       # the foot on the ground, cell px
                    step = np.linalg.norm(np.roll(wpos, -1, 0) - wpos, axis=1)
                    step[-1] = np.linalg.norm(wpos[0] + n * adv * ax - wpos[-1])
                    pl = planted_flags(R, F, act, sd, n, step)
                    # drift of the planted foot from where it touched down, over each planted span
                    drift = 0.0
                    for j in range(n):
                        if pl[j] and not pl[(j - 1) % n]:
                            j0 = j
                            q = j
                            while pl[q % n] and q < j + n:
                                w = wpos[q % n] + (q // n) * n * adv * ax
                                drift = max(drift, float(np.linalg.norm(w - wpos[j0])))
                                q += 1
                    frame_step = float(world[act]["shown_stride"]) / n          # world px the root moves while a cell is held
                    slide[sd] = {"planted_frames": [int(j) for j in range(n) if pl[j]],
                                 "planted_share": round(sum(pl) / n, 3),
                                 "rig_drift_world_px": round(drift * k, 3),
                                 "frame_step_world_px": round(frame_step, 3),
                                 "max_stance_slide_world_px": round(drift * k + frame_step, 3)}
                rec["slide"] = slide
            # arm swing vs legs: arm = shoulder->grip angle, leg = ankle along the move axis from the hip
            if act in LOOPS:
                ph = {}
                for sd in "RL":
                    arm = np.unwrap([_ang(np.subtract(p[sd]["grip"], p[sd]["sh"])) for p in P])
                    up = np.unwrap([_ang(np.subtract(p[sd]["elbow"], p[sd]["sh"])) for p in P])
                    fo = np.unwrap([_ang(np.subtract(p[sd]["grip"], p[sd]["elbow"])) for p in P])
                    leg = np.array([np.dot(np.subtract(p[sd]["ankle"], p[sd]["hip"]), MOVE[F]) for p in P])
                    # forward = the hand moving along the travel direction
                    fwd = np.array([np.dot(np.subtract(p[sd]["grip"], p[sd]["sh"]), MOVE[F]) for p in P])
                    pa, aa = harmonic(fwd)
                    pl, al = harmonic(leg)
                    pu, au_ = harmonic(up)
                    pf, af = harmonic(fo)
                    ph[sd] = {"arm_fwd_amp_px": round(aa, 2), "leg_fwd_amp_px": round(al, 2),
                              "arm_leg_phase_deg": round(math.degrees(_wrap(pa - pl)), 1),
                              "upper_amp_deg": round(math.degrees(au_), 2), "fore_amp_deg": round(math.degrees(af), 2),
                              # + = the forearm (and the axe in the fist) reaches its swing later than the upper arm
                              "axe_lag_frames": round(_wrap(pf - pu) / (2 * math.pi) * n, 2) if au_ > 1e-3 and af > 1e-3 else 0.0,
                              "arm_range_deg": round(math.degrees(float(arm.max() - arm.min())), 2)}
                rec["arms"] = ph
                # loop seam: the step from the last frame back to the first, against the largest frame-to-frame step
                def flat(p):
                    v = list(p["pelvis"]) + list(p["neck"])
                    for sd in "RL":
                        for kk in ("knee", "ankle", "elbow", "grip"):
                            v += p[sd][kk]
                    return np.array(v)
                V = np.array([flat(p) for p in P])
                if act in ("walk", "run"):
                    V0 = V
                else:
                    V0 = V
                steps = [float(np.abs(V0[j + 1] - V0[j]).max()) for j in range(n - 1)]
                rec["seam"] = {"last_to_first_px": round(float(np.abs(V0[0] - V0[-1]).max()), 2), "max_step_px": round(max(steps), 2),
                               "mean_step_px": round(float(np.mean(steps)), 2)}
            out["kinds"].setdefault(act, {})[F] = rec
    return out


def summary(m):
    rows = []
    for act, fs in m["kinds"].items():
        for F, r in fs.items():
            s = f"{act:6s} {F} bob {r['bob_pct']:5.2f}% sway {r['sway_px']:5.1f}px"
            if "slide" in r:
                s += " slide R %.2f L %.2f wpx (rig %.2f, frame %.2f, planted %.0f%%)" % (r["slide"]["R"]["max_stance_slide_world_px"], r["slide"]["L"]["max_stance_slide_world_px"], max(r["slide"][x]["rig_drift_world_px"] for x in "RL"), r["slide"]["R"]["frame_step_world_px"], 100 * r["slide"]["R"]["planted_share"])
            if "arms" in r:
                for sd in "RL":
                    a = r["arms"][sd]
                    s += f" | {sd} arm/leg {a['arm_leg_phase_deg']:6.1f}deg amp {a['arm_fwd_amp_px']:4.1f}/{a['leg_fwd_amp_px']:4.1f} axe lag {a['axe_lag_frames']:5.2f}f"
                s += " | seam %.1f/%.1f" % (r["seam"]["last_to_first_px"], r["seam"]["max_step_px"])
            rows.append(s)
    return "\n".join(rows)



# ---------------------------------------------------------------------------- the motion pass
# Frame counts of the loops the pass builds (the 17.144 fps authoring rate; the
# walker plays them by distance). More cells per cycle make the planted foot's
# in-frame drift (one frame of ground travel) small: the world walk moves 40.9
# px per cycle, so 24 cells drift 1.7 px at zoom 1; the run cycle is 1.3x
# longer and gets 28 cells (1.9 px).
LOOP_FRAMES = {"walk": 24, "run": 28, "idle": 24}
RUN_STRIDE = 1.30         # run stride over the walk stride
RUN_STANCE = 0.32         # share of the run cycle a foot is planted (walk: 0.5)
BOB = {"walk": 3.0, "run": 4.6}          # vertical bob, peak to peak, % of the standing height
CROUCH = {"walk": 0.0, "run": 2.2}       # constant pelvis drop, % of height (a runner runs lower)
LEAN = {"walk": 5.0, "run": 10.0}         # forward lean, deg
ARM_GAIN = {"walk": 1.0, "run": 1.30}    # arm swing over the TA walk's
LEG_LEN = {"S": 1.06, "E": 1.16}   # thigh and shin over the TA walk medians (the boot ankle point sits lower than the TA ankle)
KNEE_MAX_FOLD = 128.0   # deg, the most a swinging knee folds
KNEE_MIN_BEND = 0.991   # d / (thigh + shin) where the knee stops straightening (about 15 deg of bend)
AXE_LAG = 2.0                            # frames the forearm (fist and axe) trails the upper arm
UPPER = ("pelvis", "neck", "head_top") + tuple(f"{sd}_{k}" for sd in "RL" for k in ("shoulder", "elbow", "hand", "hip"))
TORSO = ("neck", "head_top") + tuple(f"{sd}_{k}" for sd in "RL" for k in ("shoulder", "elbow", "hand"))


def _per(n, a, j):
    return a[j % n]


def _catmull(P, t):
    """periodic Catmull-Rom of the rows of P (n x d) at fractional index t."""
    n = len(P)
    i = int(math.floor(t))
    u = t - i
    p0, p1, p2, p3 = (P[(i + k) % n] for k in (-1, 0, 1, 2))
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3)


def _hermite(a, b, ta, tb, u):
    h00, h10, h01, h11 = 2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u, -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2
    return h00 * a + h10 * ta + h01 * b + h11 * tb


def _rot(v, a):
    c, s = math.cos(a), math.sin(a)
    return np.array([c * v[0] - s * v[1], s * v[0] + c * v[1]])


def _frames_of(R, key):
    fr = R.JF[key]
    n = len(fr)
    return [fr[f"f{i:02d}"] for i in range(n)]


def _set_frames(R, key, frames):
    R.JF[key] = {f"f{i:02d}": f for i, f in enumerate(frames)}


def _foot_world(R, F, frames, sd, adv):
    ax = MOVE[F]
    n = len(frames)
    out = {}
    for k in ("heel", "toe", "ankle"):
        out[k] = np.array([np.array(frames[i]["joints"][f"{sd}_{k}"], float) + i * adv * ax for i in range(n)])
    return out


def _stance_adv(R, F, frames):
    """cell px the ground moves under a planted foot per frame (the TA walk is planted)."""
    ax = MOVE[F]
    steps = []
    for sd in "RL":
        h = np.array([frames[i]["joints"][f"{sd}_heel"] for i in range(len(frames))], float)
        d = -(np.roll(h, -1, 0) - h) @ ax
        steps += list(np.sort(d)[-4:])
    return float(np.median(steps))


def _resample_loop(frames, T, adv, F, planted):
    """12 TA frames -> T frames: the body by periodic Catmull-Rom, the feet in the world (the
    ground under them), planted spans held exactly and every lift-off / touch-down eased."""
    n = len(frames)
    names = list(frames[0]["joints"].keys())
    ax = MOVE[F]
    J = {k: np.array([fr["joints"][k] for fr in frames], float) for k in names}
    out = []
    for j in range(T):
        t = j * n / T
        jj = {}
        for k in names:
            if k.endswith(("_heel", "_toe", "_ankle")):
                continue
            jj[k] = _catmull(J[k], t).tolist()
        out.append({"joints": jj})
    for sd in "RL":
        for k in ("heel", "toe", "ankle"):
            W = J[f"{sd}_{k}"] + np.arange(n)[:, None] * adv * ax
            # st[i]: this point does not move in the world from TA frame i to i+1 (heel and toe plant apart)
            stp = np.linalg.norm(np.roll(W, -1, 0) - W, axis=1)
            stp[-1] = np.linalg.norm(W[0] + n * adv * ax - W[-1])
            st = stp < 0.75
            def Wp(i):
                return W[i % n] + (i // n) * n * adv * ax
            for j in range(T):
                t = j * n / T
                i = int(math.floor(t))
                u = t - i
                a, b = Wp(i), Wp(i + 1)
                if st[i % n]:
                    w = a
                else:
                    ta = np.zeros(2) if st[(i - 1) % n] else (Wp(i + 1) - Wp(i - 1)) / 2
                    tb = np.zeros(2) if st[(i + 1) % n] else (Wp(i + 2) - Wp(i)) / 2
                    w = _hermite(a, b, ta, tb, u)
                out[j]["joints"][f"{sd}_{k}"] = (w - t * adv * ax).tolist()
    return out


def _bob_track(P, H, pp_pct):
    y = P - P.mean()
    rng = y.max() - y.min()
    return y * (pp_pct / 100.0 * H / max(rng, 1e-6))


def _shift(frames, j, keys, d):
    for k in keys:
        if k in frames[j]["joints"]:
            frames[j]["joints"][k] = (np.array(frames[j]["joints"][k]) + d).tolist()


def _lean(frames, j, deg, keys=TORSO):
    J = frames[j]["joints"]
    pv = np.array(J["pelvis"], float)
    a = math.radians(deg)
    for k in keys:
        if k in J:
            J[k] = (pv + _rot(np.array(J[k], float) - pv, a)).tolist()


def _arms(frames, gain, lag, F):
    """arm swing about its mean times `gain`; the forearm (fist and axe) trails the upper arm by `lag` frames."""
    T = len(frames)
    ax = MOVE[F]
    for sd in "RL":
        # counter-swing: the arm reaches forward half a cycle from its own leg (with the other leg)
        S = np.array([fr["joints"][f"{sd}_shoulder"] for fr in frames], float)
        Hd = np.array([fr["joints"][f"{sd}_hand"] for fr in frames], float)
        legf = np.array([np.dot(np.subtract(fr["joints"][f"{sd}_ankle"], fr["joints"][f"{sd}_hip"]), ax) for fr in frames])
        pl, _ = harmonic(legf)
        pa, _ = harmonic((Hd - S) @ ax)
        delta = _wrap(pl + math.pi - pa) / (2 * math.pi) * T
        if abs(delta) > 0.05:
            vE = np.array([np.subtract(fr["joints"][f"{sd}_elbow"], fr["joints"][f"{sd}_shoulder"]) for fr in frames], float)
            vH = Hd - S
            for j in range(T):
                frames[j]["joints"][f"{sd}_elbow"] = (S[j] + _catmull(vE, (j - delta) % T)).tolist()
                frames[j]["joints"][f"{sd}_hand"] = (S[j] + _catmull(vH, (j - delta) % T)).tolist()
    for sd in "RL":
        S = np.array([fr["joints"][f"{sd}_shoulder"] for fr in frames], float)
        E = np.array([fr["joints"][f"{sd}_elbow"] for fr in frames], float)
        Hd = np.array([fr["joints"][f"{sd}_hand"] for fr in frames], float)
        au = np.unwrap(np.arctan2(*(E - S).T[::-1]))
        af = np.unwrap(np.arctan2(*(Hd - E).T[::-1]))
        lu = np.linalg.norm(E - S, axis=1)
        lf = np.linalg.norm(Hd - E, axis=1)
        mu = au.mean()
        au2 = mu + (au - mu) * gain
        rel = af - au                       # the elbow bend of the TA walk
        relm = rel.mean()
        # the forearm's swing is the upper arm's, `lag` frames late (it is dragged), plus the TA bend
        late = np.array([_catmull(au2[:, None], (j - lag) % T)[0] for j in range(T)])
        af2 = late + relm
        for j in range(T):
            e = S[j] + lu[j] * np.array([math.cos(au2[j]), math.sin(au2[j])])
            h = e + lf[j] * np.array([math.cos(af2[j]), math.sin(af2[j])])
            frames[j]["joints"][f"{sd}_elbow"] = e.tolist()
            frames[j]["joints"][f"{sd}_hand"] = h.tolist()


def _finish(frames, base_frame):
    for fr in frames:
        fr["key"] = base_frame["key"]
        fr["depth"] = dict(base_frame["depth"])


def build_walk_run(R, ta, H):
    """walk (24) and run (28) in the blockout format, from the TA walk joints (add_walk)."""
    out = {}
    for F in "SE":
        src = _frames_of(R, f"walk_{F}")
        n = len(src)
        adv = _stance_adv(R, F, src)
        planted = {}
        for sd in "RL":
            Wh = np.array([src[i]["joints"][f"{sd}_heel"] for i in range(n)], float) + np.arange(n)[:, None] * adv * MOVE[F]
            step = np.linalg.norm(np.roll(Wh, -1, 0) - Wh, axis=1)
            step[-1] = np.linalg.norm(Wh[0] + n * adv * MOVE[F] - Wh[-1])
            Wt_ = np.array([src[i]["joints"][f"{sd}_toe"] for i in range(n)], float) + np.arange(n)[:, None] * adv * MOVE[F]
            stept = np.linalg.norm(np.roll(Wt_, -1, 0) - Wt_, axis=1)
            stept[-1] = np.linalg.norm(Wt_[0] + n * adv * MOVE[F] - Wt_[-1])
            planted[sd] = step < 0.75
            if not hasattr(R, "_FLAT"):
                R._FLAT = {}
            R._FLAT[(F, sd)] = (step < 0.75) & (stept < 0.75)
        for act in ("walk", "run"):
            T = LOOP_FRAMES[act]
            if act == "walk":
                fr = _resample_loop(src, T, adv * n / T, F, planted)
                adv_t = adv * n / T
            else:
                fr, adv_t = _run_feet(src, T, adv, F, planted)
            # body bob and crouch (the TA walk pumps 8-10 % of his height)
            pel = np.array([f["joints"]["pelvis"][1] for f in fr])
            if act == "walk":
                b = _bob_track(pel, H, BOB[act])
            else:
                # run: lowest at mid-stance, highest in the flight before each touch-down
                st = RUN_STANCE * T
                tt = np.arange(T)
                b = np.cos(2 * math.pi * 2 * (tt - 0.35 * st) / T)
                b = b * (BOB[act] / 100.0 * H / 2)
            for j in range(T):
                d = np.array([0.0, (b[j] - (pel[j] - pel.mean())) + CROUCH[act] / 100.0 * H])
                _shift(fr, j, UPPER, d)
            _finish(fr, src[0])
            _reach_fix(R, F, act, fr)
            for j in range(T):
                _lean(fr, j, LEAN[act])
            _arms(fr, ARM_GAIN[act], AXE_LAG, F)
            _finish(fr, src[0])
            # the depth order of the shins: from the nearest TA frame
            for j in range(T):
                sf = src[int(round(j * n / T)) % n]
                for sd in "RL":
                    for kk in (f"{sd}_shin", f"{sd}_boot"):
                        fr[j]["depth"][kk] = sf["depth"].get(kk, 0.0)
            _set_frames(R, f"{act}_{F}", fr)
            out[(F, act)] = adv_t
            if not hasattr(R, "PLANTED"):
                R.PLANTED = {}
            if act == "walk":
                # heel and toe both down from this cell to the next
                R.PLANTED[(F, act)] = {sd: [bool(R._FLAT[(F, sd)][int(math.floor(j * n / T)) % n]) for j in range(T)] for sd in "RL"}
            else:
                ls = int(round(RUN_STANCE * T))
                R.PLANTED[(F, act)] = {}
                for sd in "RL":
                    c0 = next(i for i in range(n) if planted[sd][i] and not planted[sd][(i - 1) % n])
                    cr = int(round(c0 * T / n))
                    R.PLANTED[(F, act)][sd] = [bool(((j - cr) % T) < ls) for j in range(T)]
    for act in ("walk", "run"):
        R.ACTS[act] = LOOP_FRAMES[act]
        R.LOOP.add(act)
    return out


def _reach_fix(R, F, act, fr, reach=1.05):
    """lower the body where a planted leg could reach its boot only over-stretched (more than `reach`
    x thigh + shin), smoothed around the loop, so the legs never stretch or pop straight."""
    T = len(fr)
    _set_frames(R, f"{act}_{F}", fr)
    drop = np.zeros(T)
    for j in range(T):
        J = fr[j]["joints"]
        for sd in "RL":
            L1, L2, _ = R.LEG_CHAIN[(F, sd)]
            hip = np.array(J[f"{sd}_hip"], float) + R.LEG_HOFF[(F, sd)]
            Mb, _ = R.foot_pose(F, act, j, sd)
            an = R.apm(Mb, R.pt(F, sd, "boot", "J"))
            L = reach * (L1 + L2)
            dx, dy = an - hip
            if math.hypot(dx, dy) > L:
                need = dy - math.sqrt(max(L * L - dx * dx, 0.0)) if L > abs(dx) else dy
                drop[j] = max(drop[j], need)
    drop = np.maximum.reduce([np.roll(drop, s) for s in (-1, 0, 1)])
    for _ in range(2):
        drop = 0.25 * np.roll(drop, 1) + 0.5 * drop + 0.25 * np.roll(drop, -1)
    for j in range(T):
        _shift(fr, j, UPPER, np.array([0.0, drop[j]]))
    return drop


def _run_feet(src, T, adv12, F, planted):
    """run feet in the world: each foot planted RUN_STANCE of the cycle, a RUN_STRIDE longer stride,
    the TA swing arc 1.5x higher, every plant and lift-off eased; the body is the walk's at the
    same point of the cycle."""
    n = len(src)
    ax = MOVE[F]
    stride = n * adv12 * RUN_STRIDE
    adv = stride / T
    body = _resample_loop(src, T, adv12 * n / T, F, planted)
    ls = int(round(RUN_STANCE * T))
    for sd in "RL":
        st = planted[sd]
        c0 = next(i for i in range(n) if st[i] and not st[(i - 1) % n])          # TA touch-down
        sw0 = next(i for i in range(c0, c0 + n) if not st[i % n])               # TA lift-off
        ls_ta = sw0 - c0
        ns = n - ls_ta
        J = {k: np.array([src[i]["joints"][f"{sd}_{k}"] for i in range(n)], float) for k in ("heel", "toe", "ankle")}
        Wt = {k: J[k] + np.arange(n)[:, None] * adv12 * ax for k in J}

        def Wp(k, x):
            i = int(math.floor(x))
            f = x - i
            def at(q):
                return Wt[k][q % n] + (q // n) * n * adv12 * ax
            return at(i) * (1 - f) + at(i + 1) * f
        cr = int(round(c0 * T / n))
        for j in range(T):
            tau = j - cr
            m = math.floor(tau / T)
            tj = tau - m * T
            plant = m * stride * ax
            for k in ("heel", "toe", "ankle"):
                if tj < ls:
                    q = c0 + (tj / ls) * ls_ta
                    w = plant + (Wp(k, q) - Wp("heel", c0))
                else:
                    u = (tj - ls) / (T - ls)
                    x = sw0 + u * ns
                    lin = Wp(k, sw0) + (Wp(k, sw0 + ns) - Wp(k, sw0)) * u
                    arc = (Wp(k, x) - lin) * 1.25
                    s = u * u * (3 - 2 * u)
                    a0 = plant + (Wp(k, sw0) - Wp("heel", c0))
                    a1 = plant + stride * ax + (Wp(k, c0 + n) - Wp("heel", c0 + n))
                    w = a0 * (1 - s) + a1 * s + arc
                body[j]["joints"][f"{sd}_{k}"] = (w - j * adv * ax).tolist()
        # put the planted span under the hip where the TA walk has it (mid-stance below the hip)
        mid_ta = np.mean([np.dot(np.array(src[i]["joints"][f"{sd}_heel"]) - np.array(src[i]["joints"][f"{sd}_hip"]), ax) for i in range(n) if st[i]])
        mid_run = np.mean([np.dot(np.array(body[(cr + q) % T]["joints"][f"{sd}_heel"]) - np.array(body[(cr + q) % T]["joints"][f"{sd}_hip"]), ax) for q in range(ls)])
        perp_ta = np.mean([np.array(src[i]["joints"][f"{sd}_heel"]) - np.array(src[i]["joints"][f"{sd}_hip"]) for i in range(n) if st[i]], axis=0)
        perp_run = np.mean([np.array(body[(cr + q) % T]["joints"][f"{sd}_heel"]) - np.array(body[(cr + q) % T]["joints"][f"{sd}_hip"]) for q in range(ls)], axis=0)
        d = perp_ta - perp_run
        for j in range(T):
            for k in ("heel", "toe", "ankle"):
                body[j]["joints"][f"{sd}_{k}"] = (np.array(body[j]["joints"][f"{sd}_{k}"]) + d).tolist()
    return body, adv


def build_idle(R, H):
    """24-frame idle on the blockout idle: two breaths of different depth, one weight shift onto
    the right foot and back, a re-grip of the right axe, a glance; no two halves alike."""
    for F in "SE":
        src = _frames_of(R, f"idle_{F}")
        n = len(src)
        T = LOOP_FRAMES["idle"]
        names = list(src[0]["joints"].keys())
        J = {k: np.array([fr["joints"][k] for fr in src], float) for k in names}
        base = {k: J[k][0] for k in names}
        fr = []
        for j in range(T):
            # breath 1 (frames 0-11) deep, breath 2 (12-23) shallower
            depth_ = 1.0 if j < 12 else 0.7
            t = (j % 12) * n / 12
            jj = {k: (base[k] + (_catmull(J[k], t) - base[k]) * depth_).tolist() for k in names}
            fr.append({"joints": jj, "key": src[0]["key"], "depth": dict(src[0]["depth"])})
        tt = np.arange(T)
        ss = lambda x: np.clip(x, 0, 1) ** 2 * (3 - 2 * np.clip(x, 0, 1))
        # weight shift: onto the right foot over 3-9, held, back over 13-19 (pelvis toward that foot, a little lower)
        w = ss((tt - 3) / 6) - ss((tt - 13) / 6)
        footR = np.array(src[0]["joints"]["R_heel"], float)
        pv = np.array(src[0]["joints"]["pelvis"], float)
        toward = footR - pv
        toward = np.array([toward[0], 0.0])
        toward = toward / max(np.linalg.norm(toward), 1e-6)
        for j in range(T):
            d = toward * (0.016 * H) * w[j] + np.array([0.0, 0.006 * H * w[j]])
            _shift(fr, j, ("pelvis", "R_hip", "L_hip"), d)
            _shift(fr, j, TORSO, d * 0.7)
            # the shoulders counter-tilt
            _lean(fr, j, -1.6 * w[j] * (1 if toward[0] > 0 else -1))
        # re-grip: the right forearm and axe turn up 9 deg about the elbow over 15-17, back by 21
        g = ss((tt - 14) / 3) - ss((tt - 18) / 3)
        gl = ss((tt - 15) / 3) - ss((tt - 19) / 3)
        for j in range(T):
            for sd, amt in (("R", g[j]), ("L", 0.35 * gl[j])):
                Jx = fr[j]["joints"]
                e = np.array(Jx[f"{sd}_elbow"], float)
                h = np.array(Jx[f"{sd}_hand"], float)
                sgn = -1.0 if (h[0] - e[0]) * (1 if sd == "R" else 1) >= 0 else 1.0
                Jx[f"{sd}_hand"] = (e + _rot(h - e, math.radians(9.0) * amt * sgn)).tolist()
        # a glance: the helm turns a touch toward the travel side over 6-10 and back by 20
        gz = ss((tt - 6) / 4) - ss((tt - 17) / 4)
        for j in range(T):
            Jx = fr[j]["joints"]
            nk = np.array(Jx["neck"], float)
            Jx["head_top"] = (nk + _rot(np.array(Jx["head_top"], float) - nk, math.radians(4.0) * gz[j])).tolist()
        _set_frames(R, f"idle_{F}", fr)
    R.ACTS["idle"] = LOOP_FRAMES["idle"]


# source-frame maps: output frame -> fractional blockout frame (anticipation holds, a fast hit,
# follow-through, a settle), and an extra lean in degrees (+ = forward) on top
RETIME = {
    "attack": ([0.0, 0.7, 1.9, 3.2, 3.9, 4.25, 6.0, 7.2, 8.0, 8.9, 10.2, 11.3],
               [0, 0, -1.0, -2.0, -3.0, -3.5, 4.0, 3.0, 1.5, 0.0, -1.2, -0.5]),
    "skill": ([0.0, 0.9, 2.1, 2.9, 3.3, 5.0, 6.0, 7.0, 8.0, 9.1, 10.3, 11.4],
              [0, -0.5, -1.5, -2.5, -3.0, 2.0, 4.0, 3.0, 1.5, 0.0, -1.2, -0.4]),
    "hit": ([0.0, 1.6, 2.0, 2.6, 3.7, 5.0, 6.4, 7.4],
            [0, -2.0, -1.0, 0.0, 1.0, 3.5, 4.5, 1.5]),
}


def _lerp_frame(src, t):
    n = len(src)
    i = int(math.floor(t))
    u = t - i
    a, b = src[min(i, n - 1)], src[min(i + 1, n - 1)] if i + 1 < n else src[0]
    jj = {k: (np.array(a["joints"][k], float) * (1 - u) + np.array(b["joints"][k], float) * u).tolist() for k in a["joints"]}
    key = json.loads(json.dumps(a["key"]))
    for sd in "RL":
        key["arms"][sd] = [x * (1 - u) + y * u for x, y in zip(a["key"]["arms"][sd], b["key"]["arms"][sd])]
    out = {"joints": jj, "key": key, "depth": dict((a if u < 0.5 else b)["depth"])}
    for extra in ("draw_order",):
        if extra in a:
            out[extra] = (a if u < 0.5 else b)[extra]
    return out


def retime_actions(R):
    for act, (tmap, lean) in RETIME.items():
        for F in "SE":
            src = _frames_of(R, f"{act}_{F}")
            fr = [_lerp_frame(src, t) for t in tmap]
            for j, d in enumerate(lean):
                if d:
                    _lean(fr, j, d)
            _set_frames(R, f"{act}_{F}", fr)


def patch_legs(R, tree):
    """walk and run legs: the hip from the motion pass, the boot on its heel and toe, the knee by
    two-bone IK at one thigh and shin length per leg (the TA walk medians) on a fixed side."""
    ta = json.load(open(os.path.join(tree, _walk_dir(), "joints_512.json")))["facings"]
    locked = R.leg_pose
    chain = {}
    hoff = {}
    for F in "SE":
        ti = ta[f"idle_{F}"]["joints"] if "joints" in ta[f"idle_{F}"] else ta[f"idle_{F}"]["f00"]["joints"]
        bo0 = R.JF[f"idle_{F}"]["f00"]["joints"]
        for sd in "RL":
            hoff[(F, sd)] = np.array(ti[f"{sd}_hip"], float) - np.array(bo0[f"{sd}_hip"], float)
            l1, l2, side = [], [], []
            for i in range(12):
                tj = ta[f"walk_{F}"][f"f{i:02d}"]["joints"]
                h, kk, a = (np.array(tj[f"{sd}_{x}"], float) for x in ("hip", "knee", "ankle"))
                l1.append(float(np.hypot(*(kk - h))))
                l2.append(float(np.hypot(*(a - kk))))
                u = R.unit(a - h)
                side.append(float(np.dot(kk - h, np.array([-u[1], u[0]]))))
            chain[(F, sd)] = (LEG_LEN[F] * float(np.median(l1)), LEG_LEN[F] * float(np.median(l2)), 1.0 if float(np.median(side)) >= 0 else -1.0)
    R.LEG_CHAIN = chain
    R.LEG_HOFF = hoff

    side0 = {}

    def idle_leg(F, i, sd, Mt):
        c = R.CFG[F]
        s = c["s"]
        hip = R.apm(Mt, R.hip_t(F, sd))
        Mb, finfo = R.foot_pose(F, "idle", i, sd)
        an = R.apm(Mb, R.pt(F, sd, "boot", "J"))
        L1, L2 = R.leg_lengths(F, sd)
        d = math.dist(hip, an)
        k = float(np.clip(d / ((L1 + L2) * 0.999), 1.0, c["leg_smax"]))
        if (F, sd) not in side0:
            hb, kb, ab = (R.jt(F, "idle", 0, f"{sd}_{x}") for x in ("hip", "knee", "ankle"))
            u = R.unit(ab - hb)
            side0[(F, sd)] = 1.0 if np.dot(kb - hb, np.array([-u[1], u[0]])) >= 0 else -1.0
        kn = R.ik_knee(hip, an, L1 * k, L2 * k, side0[(F, sd)])
        th0, th1 = R.pt(F, sd, "thigh", "P0"), R.pt(F, sd, "thigh", "P1")
        sh0, sh1 = R.pt(F, sd, "shin", "P0"), R.pt(F, sd, "shin", "P1")
        return dict(Mth=R.sim(th0, th1, hip, kn, s), Msh=R.sim(sh0, sh1, kn, an, s), Mb=Mb, hip=hip.tolist(), knee=kn.tolist(),
                    ankle=an.tolist(), k=k, k_eff=max(1.0, d / (L1 + L2)), short=max(0.0, d - (L1 + L2) * k), heel=finfo["heel"], toe=finfo["toe"])

    swing_fix = {}

    def raw_leg(F, act, i, sd, Mt):
        hip = np.array(R.jt(F, act, i, f"{sd}_hip"), float) + hoff[(F, sd)]
        Mb, finfo = R.foot_pose(F, act, i, sd)
        an = R.apm(Mb, R.pt(F, sd, "boot", "J"))
        return hip, Mb, finfo, an

    def knee_angle(L1, L2, d):
        c = (d * d - L1 * L1 - L2 * L2) / (2 * L1 * L2)
        return math.acos(float(np.clip(c, -1.0, 1.0)))       # 0 = straight

    def fix_for(F, act, sd):
        """swing feet only: the knee angle over the cycle low-passed so it never snaps from straight
        to bent between two frames; the swinging boot moves along the leg to match. Planted frames
        keep their foot exactly."""
        key = (F, act, sd, id(R.PJ[F]))
        if key in swing_fix:
            return swing_fix[key]
        n = R.ACTS[act]
        L1, L2, _ = chain[(F, sd)]
        pl = getattr(R, "PLANTED", {}).get((F, act), {}).get(sd, [False] * n)
        th, dirs, ds = [], [], []
        for i in range(n):
            Mt, _ = R.torso_M(F, act, i)
            hip, Mb, finfo, an = raw_leg(F, act, i, sd, Mt)
            d = float(np.hypot(*(an - hip)))
            dirs.append(R.unit(an - hip))
            ds.append(d)
            th.append(knee_angle(L1, L2, min(d / KNEE_MIN_BEND, L1 + L2)))
        th = np.array(th)
        # a swinging foot never folds the knee past KNEE_MAX_FOLD (the boot moves out along the leg)
        sm = np.where(pl, th, np.minimum(th, math.radians(KNEE_MAX_FOLD)))
        for _ in range(3):
            sm = 0.25 * np.roll(sm, 1) + 0.5 * sm + 0.25 * np.roll(sm, -1)
            sm = np.where(pl, th, np.minimum(sm, math.radians(KNEE_MAX_FOLD)))
        push = []
        for i in range(n):
            if pl[i] or abs(sm[i] - th[i]) < 1e-4:
                push.append(np.zeros(2))
                continue
            dn = math.sqrt(max(L1 * L1 + L2 * L2 + 2 * L1 * L2 * math.cos(sm[i]), 1e-6)) * KNEE_MIN_BEND
            push.append(dirs[i] * (dn - ds[i]))
        swing_fix[key] = push
        return push

    def leg_pose(F, act, i, sd, Mt):
        if act == "idle":
            # the idle shifts his weight: the knee keeps the side it has at rest (it never flips)
            return idle_leg(F, i, sd, Mt)
        if act not in ("walk", "run"):
            return locked(F, act, i, sd, Mt)
        c = R.CFG[F]
        s = c["s"]
        hip, Mb, finfo, an = raw_leg(F, act, i, sd, Mt)
        L1, L2, sg = chain[(F, sd)]
        push = fix_for(F, act, sd)[i]
        if push.any():
            Mb = Mb.copy()
            Mb[:, 2] += push
            an = an + push
            finfo = dict(finfo, heel=(np.array(finfo["heel"]) + push).tolist(), toe=(np.array(finfo["toe"]) + push).tolist())
        d = float(np.hypot(*(an - hip)))
        k = float(np.clip(d / ((L1 + L2) * KNEE_MIN_BEND), 1.0, 1.12))
        kn = R.ik_knee(hip, an, L1 * k, L2 * k, sg)
        th0, th1 = R.pt(F, sd, "thigh", "P0"), R.pt(F, sd, "thigh", "P1")
        sh0, sh1 = R.pt(F, sd, "shin", "P0"), R.pt(F, sd, "shin", "P1")
        Mth = R.sim(th0, th1, hip, kn, s)
        Msh = R.sim(sh0, sh1, kn, an, s)
        return dict(Mth=Mth, Msh=Msh, Mb=Mb, hip=hip.tolist(), knee=kn.tolist(), ankle=an.tolist(), k=k, k_eff=k,
                    short=0.0, heel=finfo["heel"], toe=finfo["toe"])
    R.leg_pose = leg_pose


def _walk_dir():
    import gear_cut as GC
    return GC.WALK_DIR


def apply(R, tree):
    """the motion pass on the rig's joints (after add_walk). Returns {(F, gait): cell px of ground per frame}."""
    H = float(R.PIV[1] - R.IDLE_TOP)
    patch_legs(R, tree)       # reads the blockout idle f00 before the idle is rebuilt (f00 is kept)
    ta = json.load(open(os.path.join(tree, _walk_dir(), "joints_512.json")))["facings"]
    adv = build_walk_run(R, ta, H)
    build_idle(R, H)
    retime_actions(R)
    R.CAPE.clear()
    R.GROUND_ADV = adv
    return adv


def main() -> int:
    import gear_rig as GRig
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default=os.environ.get("GEAR_WORK", "/tmp/ironjaw_gear_work"))
    ap.add_argument("--out", default="")
    ap.add_argument("--world", default="", help="json of WORLD.ironjaw (default: parsed from units/pc_gear_specs.gd)")
    a = ap.parse_args()
    R = GRig.load_rig(a.work)
    for F in "SE":
        R.PJ[F] = json.load(open(os.path.join(a.work, "parts", "base", f"ijoints_{F}.json")))
    R.AP = os.path.join(a.work, "parts", "base")
    world = json.load(open(a.world)) if a.world else world_from_specs()
    acts = [x for x in ("walk", "run", "idle", "attack", "skill", "hit", "death") if x in R.ACTS]
    m = measure(R, acts, world)
    print(summary(m))
    if a.out:
        json.dump(m, open(a.out, "w"))
    return 0


def world_from_specs():
    import re
    t = open(os.path.join(HERE, "..", "..", "units", "pc_gear_specs.gd")).read()
    w = t[t.index("const WORLD"):]
    ds = float(re.search(r'"draw_scale": ([0-9.]+)', w)[1])
    out = {"draw_scale": ds}
    for g in ("walk", "run"):
        mm = re.search(r'"%s": \{[^}]*"shown_stride": ([0-9.]+)' % g, w)
        if mm:
            out[g] = {"shown_stride": float(mm[1])}
    return out


if __name__ == "__main__":
    raise SystemExit(main())
