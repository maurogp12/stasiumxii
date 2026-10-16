"""Natural-motion helpers for the Stoneford world monsters (package Z1).

Mauro: "los movimientos fueran mas naturales". On top of the mrig pose
dicts, these give
- eased keys (cosine ease-in/out, anticipation and settle overshoot),
- looping signals with harmonics and offsets (no perfectly symmetric loops),
- a gait solver that keeps every planted foot still in world space while the
  body travels at the cycle's ground speed (the in-place cycle slides the
  stance foot backward at exactly that speed),
- follow-through: secondary parts (ears, leaves, wings, fur) driven by a
  damped spring on the body's motion, so they lag and settle.
"""
from __future__ import annotations

import math

TAU = 2.0 * math.pi
FWD = {"S": (math.cos(math.atan2(0.5, 1)), math.sin(math.atan2(0.5, 1))),
       "E": (math.cos(math.atan2(-0.5, 1)), math.sin(math.atan2(-0.5, 1)))}


def ease(t):
    t = min(max(t, 0.0), 1.0)
    return 0.5 - 0.5 * math.cos(math.pi * t)


def wave(t, *terms):
    """Sum of (amp, harmonic, phase) sines of a 0..1 loop phase."""
    return sum(a * math.sin(TAU * (h * t) + p) for a, h, p in terms)


def keyed(n, keyframes, names=None):
    """Cosine-eased keys: [(frame, {param: value})] -> n pose dicts."""
    ONE = {"sx", "sy", "body_sx", "body_sy"}
    if names is None:
        names = set()
        for _, d in keyframes:
            names |= set(d)
    out = []
    for f in range(n):
        pose = {}
        for k in names:
            pts = [(i, d.get(k, 1.0 if k in ONE else 0.0)) for i, d in keyframes]
            if f <= pts[0][0]:
                v = pts[0][1]
            elif f >= pts[-1][0]:
                v = pts[-1][1]
            else:
                for (i0, v0), (i1, v1) in zip(pts, pts[1:]):
                    if i0 <= f <= i1:
                        v = v0 + (v1 - v0) * ease((f - i0) / float(i1 - i0))
                        break
            pose[k] = v
        out.append(pose)
    return out


def fwd(f, d):
    return {"dx": FWD[f][0] * d, "dy": FWD[f][1] * d}


def follow(poses, driver, targets, loop=False, k=0.35, damp=0.55):
    """Follow-through. `driver(pose) -> float` (e.g. body angle + root dx);
    each target (part, gain) gets a damped spring that chases the driver's
    change, so it lags and overshoots a little. Added onto the poses."""
    n = len(poses)
    vals = [driver(p) for p in poses]
    reps = 3 if loop else 1
    for part, gain in targets:
        x = 0.0
        v = 0.0
        out = [0.0] * n
        prev = vals[0] if not loop else vals[-1]
        for r in range(reps):
            for i in range(n):
                vel = vals[i] - prev
                prev = vals[i]
                # the part is pushed opposite to the driver's motion, then springs back
                v = v * damp - k * x - vel * gain
                x = x + v
                if r == reps - 1:
                    out[i] = x
        for i in range(n):
            poses[i][part] = poses[i].get(part, 0.0) + out[i]
    return poses


def gait(f, n, legs, stride, lift, duty, bob=0.0, bob_phase=0.0, sway=0.0):
    """In-place walk cycle for legs that translate (screen offsets).

    legs: {part: phase 0..1}. stride = stance travel in cell px; the ground
    speed is stride / (duty * n) px per frame. A stance leg slides backward
    along the facing at exactly that speed; a swing leg lifts on an arc and
    eases forward. Returns (poses, speed_px_per_frame, stance{part: [bool]}).
    Root bob is not compensated here: plant() pins the feet afterwards.
    """
    dx, dy = FWD[f]
    speed = stride / (duty * n)
    poses = []
    stance = {p: [] for p in legs}
    for i in range(n):
        t = i / float(n)
        pose = {"dy": -bob * (0.5 - 0.5 * math.cos(TAU * (2 * t + bob_phase))), "rot": sway * math.sin(TAU * (t + 0.15))}
        for part, ph in legs.items():
            u = (t + ph) % 1.0
            if u < duty:
                s = stride * (0.5 - u / duty)
                h = 0.0
                stance[part].append(True)
                tilt = -6.0 * (0.5 - u / duty)
            else:
                w = (u - duty) / (1.0 - duty)
                s = stride * (-0.5 + ease(w))
                h = -lift * math.sin(math.pi * w)
                stance[part].append(False)
                tilt = 10.0 * math.sin(math.pi * w)
            pose[part + ".dx"] = dx * s
            pose[part + ".dy"] = dy * s + h
            pose[part] = tilt * (1 if f == "S" else -1)
        poses.append(pose)
    return poses, speed, stance


def plant(rig, poses, f, feet, stance, speed):
    """Pin every stance foot. For each stance run (cyclic), the anchor is the
    foot's place at the run's first frame with only the leg's own motion (no
    root bob, sway or body turn); each later stance frame wants the anchor
    minus pure ground travel, and the leg offset is corrected to put the foot
    there. Returns per-frame foot tracks {part: [[x, y], ...]} in cell px."""
    dx, dy = FWD[f]
    n = len(poses)
    tracks = {p: [] for p in feet}
    for part, xy in feet.items():
        st = stance[part]
        starts = [i for i in range(n) if st[i] and not st[i - 1]]
        if not starts:
            starts = [0]
        for i0 in starts:
            own = {k: v for k, v in poses[i0].items() if k == part or k.startswith(part + ".")}
            ax, ay = rig.point(own, part, xy)
            i = i0
            steps = 0
            while st[i % n] and steps < n:
                pose = poses[i % n]
                x, y = rig.point(pose, part, xy)
                want = (ax - dx * speed * steps, ay - dy * speed * steps)
                pose[part + ".dx"] = pose.get(part + ".dx", 0.0) + want[0] - x
                pose[part + ".dy"] = pose.get(part + ".dy", 0.0) + want[1] - y
                i += 1
                steps += 1
        for pose in poses:
            tracks[part].append([round(v, 2) for v in rig.point(pose, part, xy)])
    return tracks


def offset_loop(poses, k):
    """The same loop started k frames later (idle variants per pack member)."""
    k %= len(poses)
    return poses[k:] + poses[:k]
