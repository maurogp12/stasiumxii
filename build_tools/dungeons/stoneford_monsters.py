"""Stoneford world monsters (package Z1): Bristleback Boar, Mandrake Rootling,
Thistle Puffball, Flour Moth, and the world bosses Grimhoot (owl), Old Gulp
(toad) and the Thresher Stag.

Painted-part rigs (mrig.py) on the approved single-creature paintings in
stoneford_src/<id>_{S,E}.jpg, with natural motion (stoneford_motion.py):
eased keys with anticipation and settle, follow-through springs on ears,
leaves, wings and fur, asymmetric idles (two variants), and walk cycles whose
planted feet stay still in world space at the cycle's ground speed.

Rule (Mauro): these are never dungeon monsters; nothing here reads a dungeon
painting or sheet.

Cells: 512x360, pivot (256,329); the bosses 768x540, pivot (384,494). 17.144 fps.
  python3 stoneford_monsters.py [id ...] [--check] [--facing S]
"""
from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import mrig  # noqa: E402
from mrig import Part  # noqa: E402

import monster_kit  # noqa: E402
from monster_kit import CELL, CELL_BIG, FPS, PIV, PIV_BIG  # noqa: E402
import stoneford_motion as mo  # noqa: E402
from stoneford_motion import wave, keyed, fwd, ease  # noqa: E402

gkit.use_world("stoneford")
monster_kit.LOOPS.update({"idle2": True, "enter": False})

_RIGS = {}


def _rig(key, make):
    if key not in _RIGS:
        _RIGS[key] = make()
    return _RIGS[key]


def has_src(name):
    return os.path.exists(os.path.join(gkit.SRC, name))


# ------------------------------------------------------------------ Bristleback Boar

def boar_facing(f):
    if f == "S":
        parts = [
            Part("tail", [(250, 390), (335, 370), (340, 520), (262, 545)], (325, 445), "body", True, -3),
            Part("hind_far", [(478, 600), (602, 606), (612, 700), (648, 782), (602, 798), (528, 792), (498, 700)], (540, 616), "body", True, -2),
            Part("front_far", [(948, 700), (1062, 700), (1082, 800), (1128, 880), (1112, 918), (978, 912), (958, 820)], (1000, 712), "body", True, -1),
            Part("hind_near", [(268, 560), (402, 560), (392, 700), (388, 836), (278, 838), (272, 700)], (332, 576), "body", True, 1),
            Part("bristles", [(380, 250), (450, 130), (560, 55), (700, 25), (860, 55), (1000, 175), (1012, 300), (900, 292), (800, 282), (650, 302), (500, 322), (400, 332)], (700, 300), "body", True, 2),
            Part("front_near", [(688, 598), (822, 598), (834, 760), (884, 958), (864, 998), (718, 998), (698, 880), (678, 700)], (758, 618), "body", True, 3),
            Part("ear", [(828, 290), (930, 300), (930, 470), (850, 470)], (900, 455), "head", False, 4),
            Part("head", [(830, 300), (1172, 288), (1205, 600), (1162, 742), (1000, 752), (898, 692), (840, 562), (818, 420)], (900, 520), "body", True, 5),
        ]
        fc = mrig.Facing("boar_S.jpg", parts, ground=(700, 930), hip=(700, 600), scale=0.18, cell=CELL, cell_pivot=PIV)
        fc.feet = {"front_near": (790, 990), "front_far": (1050, 908), "hind_near": (330, 830), "hind_far": (580, 790)}
        return fc
    parts = [
        Part("front_far", [(770, 620), (862, 620), (882, 732), (790, 732)], (812, 632), "body", True, -2),
        Part("tail", [(370, 470), (472, 450), (482, 600), (400, 652)], (452, 482), "body", True, -1),
        Part("hind_far", [(540, 690), (692, 690), (702, 850), (746, 988), (608, 988), (558, 850)], (612, 702), "body", True, 1),
        Part("front_near", [(900, 620), (1022, 620), (1062, 760), (1092, 812), (990, 818), (940, 722)], (952, 642), "body", True, 1),
        Part("hind_near", [(368, 640), (512, 640), (502, 800), (502, 948), (378, 948), (388, 800)], (442, 662), "body", True, 2),
        Part("bristles", [(430, 400), (520, 250), (650, 108), (800, 28), (900, 38), (1000, 118), (980, 262), (860, 332), (700, 402), (560, 472)], (750, 382), "body", True, 2),
        Part("ear", [(1030, 108), (1122, 98), (1112, 262), (1040, 252)], (1052, 242), "head", False, 4),
        Part("head", [(940, 98), (1122, 98), (1202, 280), (1192, 402), (1100, 422), (1010, 442), (960, 300)], (1002, 382), "body", True, 3),
    ]
    fc = mrig.Facing("boar_E.jpg", parts, ground=(650, 930), hip=(700, 600), scale=0.18, cell=CELL, cell_pivot=PIV)
    fc.feet = {"front_near": (1040, 812), "front_far": (830, 728), "hind_near": (440, 944), "hind_far": (680, 984)}
    return fc


def boar_actions(f, rig):
    A = {}
    sg = 1 if f == "S" else -1
    # Idle: slow heavy breathing with a weight shift onto the front, snout
    # twitching on its own rhythm, the tail flicking late.
    def idle(t, v):
        br = wave(t, (1.0, 1, 0.0), (0.25, 2, 0.9))
        return {"body_sy": 1 + 0.012 * br, "body": 0.8 * wave(t, (1.0, 1, 0.4)) + (0.5 * wave(t, (1, 1, 2.2)) if v else 0),
                "head": sg * (2.2 * wave(t, (1.0, 1, 1.2), (0.6, 3, 0.2)) + (6 * mo.ease(abs(math.sin(math.pi * t))) if v else 0)),
                "dy": -0.8 * br, "bristles": 1.2 * wave(t, (1, 1, -0.6)), "ear": 3 * wave(t, (1, 2, 0.5), (1.5, 3, 1.1)),
                "tail": 8 * wave(t, (1, 1, -1.2), (0.4, 3, 0.3))}
    A["idle"] = mo.follow([idle(i / 12.0, False) for i in range(12)], lambda p: p.get("body", 0), [("bristles", 0.6)], loop=True)
    A["idle2"] = [idle(i / 12.0, True) for i in range(12)]
    # Walk: a heavy trot, diagonal pairs, head leading with a nod on each
    # footfall, body bob twice a cycle, ears and bristles lagging.
    legs = {"front_near": 0.0, "hind_far": 0.02, "front_far": 0.5, "hind_near": 0.52}
    poses, speed, stance = mo.gait(f, 12, legs, stride=26.0, lift=9.0, duty=0.55, bob=3.0, bob_phase=0.1, sway=0.6)
    for i, p in enumerate(poses):
        t = i / 12.0
        p["head"] = sg * (3.5 * math.sin(mo.TAU * (2 * t + 0.35)) - 2.0)
        p["body"] = 1.2 * math.sin(mo.TAU * (2 * t + 0.2))
        p["tail"] = 10 * math.sin(mo.TAU * (t - 0.2))
    mo.follow(poses, lambda p: p.get("dy", 0) * 2 + p.get("body", 0), [("ear", 1.6), ("bristles", 0.9)], loop=True)
    rig.gait_tracks = mo.plant(rig, poses, f, rig.feet, stance, speed)
    rig.gait_speed = speed
    rig.gait_stance = stance
    A["walk"] = poses
    # Attack: crouch back (anticipation), lunge with the tusks up through an
    # arc, hold a beat, settle with a little overshoot.
    att = keyed(12, [
        (0, {}),
        (3, dict(fwd(f, -9), body=-5, head=sg * 8, front_near=-6 * sg, front_far=-6 * sg, hind_near=8 * sg, hind_far=8 * sg, body_sy=0.97, tail=-14)),
        (5, dict(fwd(f, 22), dy=-6, body=6, head=-sg * 18, front_near=12 * sg, front_far=10 * sg, hind_near=-10 * sg, hind_far=-8 * sg, tail=12)),
        (6, dict(fwd(f, 24), dy=-3, body=4, head=-sg * 12, front_near=8 * sg, tail=16)),
        (9, dict(fwd(f, 4), body=-1, head=sg * 3, tail=-4)),
        (11, {}),
    ])
    A["attack"] = mo.follow(att, lambda p: p.get("dx", 0) + p.get("body", 0), [("ear", 1.4), ("bristles", 0.8)])
    hit = keyed(8, [
        (0, {}),
        (2, dict(fwd(f, -11), dy=-3, body=-8, head=sg * 14, tail=-18, front_near=6 * sg, front_far=6 * sg)),
        (4, dict(fwd(f, -6), body=-3, head=sg * 5)),
        (7, {}),
    ])
    A["hit"] = mo.follow(hit, lambda p: p.get("dx", 0) + p.get("body", 0), [("ear", 2.0), ("bristles", 1.0)])
    fall = -1 if f == "S" else 1
    A["death"] = keyed(13, [
        (0, {}),
        (2, dict(fwd(f, -6), body=-6, head=sg * 16, dy=-4)),
        (6, dict(rot=18 * fall, dy=10, body=6 * fall, head=-sg * 6, front_near=20, front_far=16, hind_near=-12, hind_far=-12, tail=10)),
        (9, dict(rot=62 * fall, dy=34, sy=0.94, body=6 * fall, head=-sg * 10, front_near=28, front_far=24, hind_near=-20, hind_far=-18, tail=14)),
        (11, dict(rot=70 * fall, dy=38, sy=0.92, body=5 * fall, head=-sg * 12, front_near=30, front_far=26, hind_near=-22, hind_far=-20, tail=16)),
        (12, dict(rot=69 * fall, dy=38, sy=0.92, body=5 * fall, head=-sg * 12, front_near=29, front_far=25, hind_near=-21, hind_far=-19, tail=15)),
    ])
    return A


# ------------------------------------------------------------------ Mandrake Rootling

def mandrake_facing(f):
    if f == "S":
        parts = [
            Part("arm_r", [(700, 760), (800, 800), (905, 870), (1005, 1000), (965, 1152), (815, 1152), (780, 950), (700, 860)], (722, 792), "body", True, -1),
            Part("leg_l", [(378, 1000), (522, 958), (522, 1100), (502, 1300), (482, 1372), (248, 1362), (258, 1250), (358, 1150)], (452, 1002), "root", True, -2),
            Part("leg_r", [(600, 948), (762, 978), (762, 1200), (922, 1482), (678, 1482), (548, 1382), (600, 1200)], (680, 982), "root", True, -2),
            Part("arm_l", [(198, 618), (382, 598), (432, 680), (332, 760), (302, 900), (382, 1100), (302, 1202), (78, 1182), (48, 960), (148, 800)], (392, 662), "body", True, 2),
            Part("head", [(438, 438), (652, 428), (762, 498), (782, 620), (742, 800), (662, 822), (558, 762), (468, 700), (428, 560)], (580, 820), "body", True, 3),
            Part("leaves", [(28, 280), (200, 98), (350, 58), (600, 48), (762, 248), (982, 378), (992, 652), (882, 602), (762, 482), (652, 462), (560, 472), (452, 482), (332, 562), (220, 612), (58, 562)], (580, 472), "head", False, 4),
        ]
        fc = mrig.Facing("mandrake_S.jpg", parts, ground=(600, 1370), hip=(580, 960), scale=0.142, cell=CELL, cell_pivot=PIV, despill=True)
        fc.feet = {"leg_l": (370, 1365), "leg_r": (760, 1470)}
        return fc
    parts = [
        Part("leg_l", [(300, 680), (462, 700), (432, 800), (432, 942), (330, 952), (200, 932), (240, 820)], (402, 702), "root", True, -2),
        Part("leg_r", [(500, 700), (642, 700), (622, 800), (762, 952), (722, 1022), (480, 1012), (540, 880)], (562, 712), "root", True, -2),
        Part("arm_l", [(108, 520), (262, 470), (402, 470), (412, 560), (302, 622), (262, 702), (222, 772), (108, 762), (98, 652)], (392, 502), "body", True, 1),
        Part("arm_r", [(580, 520), (702, 560), (802, 620), (902, 722), (882, 862), (762, 862), (702, 722), (600, 600)], (602, 542), "body", True, 1),
        Part("head", [(388, 328), (622, 328), (662, 452), (602, 522), (420, 522), (378, 432)], (502, 522), "body", True, 3),
        Part("leaves", [(78, 300), (150, 198), (330, 88), (450, 38), (702, 48), (882, 178), (952, 400), (942, 562), (862, 562), (702, 472), (600, 382), (520, 362), (420, 382), (320, 422), (160, 442)], (502, 362), "head", False, 4),
    ]
    fc = mrig.Facing("mandrake_E.jpg", parts, ground=(480, 985), hip=(500, 650), scale=0.205, cell=CELL, cell_pivot=PIV)
    fc.feet = {"leg_l": (330, 942), "leg_r": (620, 1002)}
    return fc


def mandrake_actions(f, rig):
    A = {}
    sg = 1 if f == "S" else -1
    # Idle: never quite still - quick jittery breaths, a twitch every so often,
    # arms flexing out of step, the leaf crown lagging every jolt.
    def idle(t, v):
        j = wave(t, (1.0, 1, 0.0), (0.45, 3, 0.7), (0.25, 5, 1.9))
        p = {"body_sy": 1 + 0.016 * j, "body": 1.4 * wave(t, (1, 1, 0.3), (0.5, 2, 1.0)), "dy": -1.0 * j,
             "head": sg * 3 * wave(t, (1, 2, 0.4), (0.7, 3, 2.0)), "arm_l": -sg * 5 * wave(t, (1, 1, 0.9), (0.6, 3, 0.1)),
             "arm_r": sg * 6 * wave(t, (1, 1, 2.1), (0.5, 4, 0.6))}
        if v:
            # look-around: a quick head turn and back
            p["head"] += sg * 10 * math.sin(math.pi * min(t * 2.0, 1.0)) if t < 0.5 else 0.0
        return p
    A["idle"] = mo.follow([idle(i / 12.0, False) for i in range(12)], lambda p: p.get("head", 0) + p.get("body", 0), [("leaves", 0.9)], loop=True)
    A["idle2"] = mo.follow([idle(i / 12.0, True) for i in range(12)], lambda p: p.get("head", 0) + p.get("body", 0), [("leaves", 0.9)], loop=True)
    # Walk: a fast skittering scuttle on two root legs, short steps, a
    # jittery body, arms swinging opposite.
    poses, speed, stance = mo.gait(f, 12, {"leg_l": 0.0, "leg_r": 0.5}, stride=20.0, lift=10.0, duty=0.5, bob=3.5, bob_phase=0.05, sway=1.0)
    for i, p in enumerate(poses):
        t = i / 12.0
        p["body"] = 3.0 * math.sin(mo.TAU * t) + 1.2 * math.sin(mo.TAU * 3 * t + 0.5)
        p["head"] = sg * (2.5 * math.sin(mo.TAU * 2 * t + 1.0))
        p["arm_l"] = -sg * 14 * math.sin(mo.TAU * t + 0.4)
        p["arm_r"] = sg * 14 * math.sin(mo.TAU * t + 0.4)
    mo.follow(poses, lambda p: p.get("body", 0) + p.get("dy", 0), [("leaves", 1.3)], loop=True)
    rig.gait_tracks = mo.plant(rig, poses, f, rig.feet, stance, speed)
    rig.gait_speed = speed
    rig.gait_stance = stance
    A["walk"] = poses
    att = keyed(12, [
        (0, {}),
        (3, dict(fwd(f, -6), body=-7, arm_l=sg * 30, arm_r=-sg * 26, head=-sg * 6, body_sy=0.96)),
        (5, dict(fwd(f, 16), dy=-5, body=8, arm_l=-sg * 48, arm_r=sg * 40, head=sg * 10)),
        (6, dict(fwd(f, 18), body=7, arm_l=-sg * 52, arm_r=sg * 44, head=sg * 8)),
        (9, dict(fwd(f, 3), body=-1, arm_l=sg * 6, arm_r=-sg * 4)),
        (11, {}),
    ])
    A["attack"] = mo.follow(att, lambda p: p.get("body", 0) + p.get("dx", 0) * 0.5, [("leaves", 1.4)])
    hit = keyed(8, [(0, {}), (2, dict(fwd(f, -10), dy=-4, body=-12, head=-sg * 14, arm_l=sg * 20, arm_r=-sg * 20)), (4, dict(fwd(f, -6), body=-4)), (7, {})])
    A["hit"] = mo.follow(hit, lambda p: p.get("body", 0) + p.get("dx", 0) * 0.5, [("leaves", 1.8)])
    fall = -1 if f == "S" else 1
    A["death"] = mo.follow(keyed(13, [
        (0, {}),
        (2, dict(body=-8 * fall, head=-sg * 18, dy=-5, arm_l=30 * fall, arm_r=-30 * fall)),
        (6, dict(rot=30 * fall, dy=14, body=10 * fall, leg_l=14, leg_r=-14, arm_l=50 * fall, arm_r=-40 * fall)),
        (9, dict(rot=78 * fall, dy=40, sy=0.92, body=8 * fall, leg_l=22, leg_r=-20, arm_l=70 * fall, arm_r=-55 * fall, head=12 * fall)),
        (12, dict(rot=84 * fall, dy=44, sy=0.9, body=8 * fall, leg_l=24, leg_r=-22, arm_l=74 * fall, arm_r=-58 * fall, head=14 * fall)),
    ]), lambda p: p.get("rot", 0), [("leaves", 0.6)])
    return A


# ------------------------------------------------------------------ Thistle Puffball

def puffball_facing(f):
    if f == "S":
        parts = [
            Part("foot_l", [(228, 800), (402, 780), (462, 900), (402, 1012), (228, 962)], (362, 802), "root", True, -2),
            Part("foot_r", [(600, 828), (782, 790), (872, 900), (842, 972), (612, 922)], (702, 822), "root", True, -2),
            Part("leaf_l", [(140, 540), (322, 520), (332, 620), (262, 700), (222, 782), (150, 700)], (312, 600), "body", False, -1),
            Part("leaf_r", [(800, 580), (902, 640), (902, 762), (832, 862), (762, 722)], (802, 622), "body", False, -1),
            Part("head", [(150, 420), (220, 150), (400, 30), (700, 40), (900, 180), (992, 380), (942, 580), (822, 690), (600, 700), (400, 690), (250, 600)], (552, 700), "body", True, 3),
        ]
        fc = mrig.Facing("puffball_S.jpg", parts, ground=(540, 955), hip=(540, 780), scale=0.172, cell=CELL, cell_pivot=PIV)
        fc.feet = {"foot_l": (330, 990), "foot_r": (740, 955)}
        return fc
    parts = [
        Part("foot_l", [(268, 800), (452, 800), (502, 942), (402, 982), (268, 962)], (392, 812), "root", True, -2),
        Part("foot_r", [(600, 800), (782, 800), (842, 922), (782, 1002), (600, 962)], (692, 812), "root", True, -2),
        Part("leaf_l", [(178, 600), (332, 590), (382, 700), (302, 862), (198, 802)], (342, 642), "body", False, -1),
        Part("leaf_r", [(730, 600), (902, 690), (892, 882), (802, 862), (722, 722)], (742, 642), "body", False, -1),
        Part("head", [(138, 450), (200, 250), (300, 128), (430, 38), (662, 38), (782, 148), (902, 300), (962, 560), (862, 642), (702, 662), (500, 662), (330, 642), (200, 562)], (552, 662), "body", True, 3),
    ]
    fc = mrig.Facing("puffball_E.jpg", parts, ground=(550, 955), hip=(550, 780), scale=0.172, cell=CELL, cell_pivot=PIV)
    fc.feet = {"foot_l": (330, 970), "foot_r": (720, 990)}
    return fc


def puffball_actions(f, rig):
    A = {}
    sg = 1 if f == "S" else -1
    # Idle: rooted, swaying like a plant in a breeze; the heavy head lags the
    # stalk and the spines breathe (a slow swell of the head).
    def idle(t, v):
        g = wave(t, (1.0, 1, 0.0), (0.35, 2, 1.3)) + (0.6 * wave(t, (1, 3, 0.4)) if v else 0)
        return {"body": 2.5 * g, "rot": 0.8 * g, "head_sx": 0, "leaf_l": -5 * wave(t, (1, 1, 0.9), (0.4, 3, 0.2)), "leaf_r": 5 * wave(t, (1, 1, 1.6)),
                "body_sy": 1 + 0.01 * wave(t, (1, 1, 2.0))}
    for name, v in (("idle", False), ("idle2", True)):
        poses = [idle(i / 12.0, v) for i in range(12)]
        for p in poses:
            p.pop("head_sx")
        A[name] = mo.follow(poses, lambda p: p.get("body", 0), [("head", 1.2), ("leaf_l", 0.8), ("leaf_r", 0.8)], loop=True)
    # Walk: a planted creature shuffles - short root steps, a big sway.
    poses, speed, stance = mo.gait(f, 12, {"foot_l": 0.0, "foot_r": 0.5}, stride=12.0, lift=6.0, duty=0.62, bob=2.0, sway=1.2)
    for i, p in enumerate(poses):
        t = i / 12.0
        p["body"] = 4.0 * math.sin(mo.TAU * t + 0.3)
    mo.follow(poses, lambda p: p.get("body", 0), [("head", 1.3), ("leaf_l", 1.0), ("leaf_r", 1.0)], loop=True)
    rig.gait_tracks = mo.plant(rig, poses, f, rig.feet, stance, speed)
    rig.gait_speed = speed
    rig.gait_stance = stance
    A["walk"] = poses
    # Attack (Seed Volley): the spines pulse - the head swells twice, then
    # snaps forward and the seeds fly (release on frame 7), then settles.
    att = keyed(12, [
        (0, {}),
        (2, dict(body=-4, rot=-1.5, body_sy=1.05, body_sx=1.04)),
        (3, dict(body=-3, body_sy=0.98, body_sx=0.99)),
        (5, dict(body=-6, rot=-2.5, body_sy=1.08, body_sx=1.06)),
        (7, dict(fwd(f, 6), body=8, rot=2.5, body_sy=0.94, body_sx=0.96)),
        (9, dict(body=-2, body_sy=1.02)),
        (11, {}),
    ])
    A["attack"] = mo.follow(att, lambda p: p.get("body", 0), [("head", 1.0), ("leaf_l", 1.2), ("leaf_r", 1.2)])
    hit = keyed(8, [(0, {}), (2, dict(fwd(f, -6), body=-10, rot=-3, body_sy=0.95)), (4, dict(body=-3)), (7, {})])
    A["hit"] = mo.follow(hit, lambda p: p.get("body", 0), [("head", 1.4), ("leaf_l", 1.4), ("leaf_r", 1.4)])
    fall = -1 if f == "S" else 1
    A["death"] = keyed(13, [
        (0, {}),
        (3, dict(body=-6 * fall, body_sy=1.04)),
        (7, dict(rot=40 * fall, dy=16, body=8 * fall, sy=0.95, leaf_l=-20, leaf_r=20)),
        (10, dict(rot=82 * fall, dy=40, sy=0.9, body=10 * fall, leaf_l=-30, leaf_r=30, head=6 * fall)),
        (12, dict(rot=86 * fall, dy=42, sy=0.9, body=10 * fall, leaf_l=-32, leaf_r=32, head=7 * fall)),
    ])
    return A


# ------------------------------------------------------------------ Flour Moth

def moth_facing(f):
    if f == "S":
        parts = [
            Part("wing_r", [(948, 380), (1200, 168), (1442, 158), (1442, 232), (1300, 420), (1100, 560), (1030, 562), (978, 470)], (990, 500), "body", False, -2),
            Part("abdomen", [(538, 640), (722, 618), (762, 700), (702, 800), (622, 952), (538, 922)], (702, 660), "body", True, -1),
            Part("legs", [(680, 690), (1000, 700), (1000, 850), (880, 982), (700, 962)], (850, 702), "body", True, 1),
            Part("wing_l", [(88, 58), (300, 38), (562, 168), (802, 500), (792, 562), (700, 622), (562, 702), (400, 732), (158, 602), (150, 548), (200, 450), (148, 178)], (792, 540), "body", False, 2),
            Part("head", [(800, 328), (1002, 378), (1100, 440), (1205, 470), (1205, 600), (1072, 652), (1002, 702), (900, 702), (850, 600), (830, 480)], (902, 622), "body", True, 3),
        ]
        return mrig.Facing("moth_S.jpg", parts, ground=(860, 1020), hip=(880, 600), scale=0.215, cell=CELL, cell_pivot=PIV)
    parts = [
        Part("wing_l", [(28, 88), (120, 42), (332, 98), (482, 278), (562, 398), (502, 482), (422, 562), (282, 642), (138, 522), (150, 420), (98, 330)], (532, 422), "body", False, -1),
        Part("wing_r", [(640, 428), (802, 388), (962, 408), (1022, 520), (982, 702), (862, 702), (802, 882), (700, 862), (660, 702), (650, 560)], (662, 462), "body", False, -1),
        Part("legs", [(338, 580), (672, 600), (672, 800), (540, 872), (338, 782)], (562, 602), "body", True, 1),
        Part("head", [(538, 138), (862, 208), (762, 362), (622, 382), (558, 332)], (652, 382), "body", True, 3),
    ]
    return mrig.Facing("moth_E.jpg", parts, ground=(560, 930), hip=(600, 450), scale=0.25, cell=CELL, cell_pivot=PIV)


HOVER = -24.0


def moth_actions(f, rig):
    A = {}
    sg = 1 if f == "S" else -1
    # Flutter: the wing beat (about 2.3 beats a loop, not locked to the body)
    # drives the wings; the body drifts softly up and down on its own slower
    # rhythm, the legs and abdomen trail behind.
    def fly(t, beats, drift, v):
        b = math.sin(mo.TAU * beats * t)
        down = 0.5 + 0.5 * b
        d = drift * wave(t, (1.0, 1, 0.2), (0.3, 2, 1.1)) + (2.0 * wave(t, (1, 3, 0.5)) if v else 0)
        return {"dy": HOVER + d - 3.0 * down, "rot": 1.2 * wave(t, (1, 1, 1.4)),
                "wing_l": sg * (-26 * b - 6), "wing_r": sg * (22 * b + 4), "body": 1.5 * wave(t, (1, 1, 0.9)),
                "head": sg * 2 * wave(t, (1, 2, 0.1))}
    for name, v in (("idle", False), ("idle2", True)):
        poses = [fly(i / 12.0, 2.0, 5.0, v) for i in range(12)]
        A[name] = mo.follow(poses, lambda p: p.get("dy", 0), [("legs", 1.2), ("abdomen", 0.8)], loop=True)
    poses = [fly(i / 12.0, 3.0, 3.0, False) for i in range(12)]
    for i, p in enumerate(poses):
        p.update({k: p.get(k, 0) + v for k, v in fwd(f, 3 * math.sin(mo.TAU * i / 12.0)).items()})
        p["body"] = p.get("body", 0) + 4
    A["walk"] = mo.follow(poses, lambda p: p.get("dy", 0) + p.get("dx", 0), [("legs", 1.4), ("abdomen", 1.0)], loop=True)
    rig.gait_speed = None
    att = keyed(12, [
        (0, dict(dy=HOVER)),
        (3, dict(fwd(f, -8), dy=HOVER - 10, body=-8, wing_l=-sg * 40, wing_r=sg * 34)),
        (5, dict(fwd(f, -6), dy=HOVER - 12, body=-10, wing_l=-sg * 48, wing_r=sg * 40)),
        (7, dict(fwd(f, 12), dy=HOVER + 2, body=10, wing_l=sg * 24, wing_r=-sg * 20)),
        (9, dict(fwd(f, 4), dy=HOVER - 2, body=2, wing_l=-sg * 8, wing_r=sg * 6)),
        (11, dict(dy=HOVER)),
    ])
    A["attack"] = mo.follow(att, lambda p: p.get("dy", 0) + p.get("dx", 0), [("legs", 1.3), ("abdomen", 0.9)])
    hit = keyed(8, [(0, dict(dy=HOVER)), (2, dict(fwd(f, -12), dy=HOVER - 8, body=-12, rot=-6, wing_l=-sg * 30, wing_r=sg * 30)), (4, dict(fwd(f, -6), dy=HOVER - 3, body=-4)), (7, dict(dy=HOVER))])
    A["hit"] = mo.follow(hit, lambda p: p.get("dy", 0) + p.get("dx", 0), [("legs", 1.6), ("abdomen", 1.0)])
    fall = -1 if f == "S" else 1
    A["death"] = keyed(13, [
        (0, dict(dy=HOVER)),
        (2, dict(dy=HOVER - 8, wing_l=-sg * 40, wing_r=sg * 36, body=-8)),
        (6, dict(dy=-6, rot=25 * fall, wing_l=sg * 20, wing_r=-sg * 18, body=8 * fall)),
        (9, dict(dy=14, rot=60 * fall, sy=0.94, wing_l=sg * 34, wing_r=-sg * 30, body=10 * fall)),
        (12, dict(dy=18, rot=66 * fall, sy=0.92, wing_l=sg * 38, wing_r=-sg * 34, body=10 * fall)),
    ])
    return A


# ------------------------------------------------------------------ Grimhoot (owl boss)

def owl_facing(f):
    if f == "S":
        parts = [
            Part("wing_r", [(800, 420), (902, 400), (992, 600), (1002, 900), (952, 1200), (842, 1422), (780, 1300), (760, 1000), (780, 700), (800, 550)], (842, 452), "body", False, -1),
            Part("wing_l", [(28, 500), (130, 330), (300, 228), (412, 240), (422, 420), (352, 560), (302, 800), (262, 1000), (222, 1300), (232, 1422), (130, 1482), (58, 1330), (38, 1000)], (382, 332), "body", False, 2),
            Part("head", [(470, 20), (585, 20), (620, 150), (760, 190), (812, 100), (905, 110), (900, 240), (840, 390), (812, 480), (722, 566), (600, 566), (536, 470), (512, 300), (480, 150)], (660, 562), "body", True, 4),
        ]
        return mrig.Facing("owl_S.jpg", parts, ground=(560, 1330), hip=(580, 820), scale=0.262, cell=CELL_BIG, cell_pivot=PIV_BIG)
    parts = [
        Part("wing_l", [(88, 520), (180, 198), (300, 148), (432, 168), (442, 330), (382, 500), (342, 700), (302, 900), (198, 882), (128, 700)], (422, 262), "body", False, 2),
        Part("wing_r", [(700, 320), (782, 208), (862, 218), (962, 450), (982, 600), (902, 852), (822, 882), (762, 700), (700, 500)], (742, 302), "body", False, 2),
        Part("head", [(398, 18), (472, 78), (560, 118), (652, 38), (732, 58), (722, 200), (662, 302), (500, 302), (440, 200)], (562, 302), "body", True, 3),
    ]
    return mrig.Facing("owl_E.jpg", parts, ground=(560, 965), hip=(560, 500), scale=0.31, cell=CELL_BIG, cell_pivot=PIV_BIG)


def owl_actions(f, rig):
    A = {}
    sg = 1 if f == "S" else -1
    # Heavy, deliberate: a slow breath that lifts the shoulders, the head
    # swivelling in owl steps (move, hold, move), wings settling late.
    def idle(t, v):
        br = wave(t, (1.0, 1, 0.0), (0.2, 2, 0.8))
        hd = sg * (6 * (ease((t * 3) % 1.0) if v else 0.5) * (1 if v else 0) + 2 * wave(t, (1, 1, 1.1)))
        return {"body_sy": 1 + 0.01 * br, "dy": -1.2 * br, "body": 0.6 * wave(t, (1, 1, 0.5)), "head": hd,
                "wing_l": -sg * 2.5 * wave(t, (1, 1, 0.9)), "wing_r": sg * 2.0 * wave(t, (1, 1, 1.4))}
    for name, v in (("idle", False), ("idle2", True)):
        A[name] = mo.follow([idle(i / 12.0, v) for i in range(12)], lambda p: p.get("dy", 0) + p.get("body", 0), [("wing_l", 0.5), ("wing_r", 0.5)], loop=True)
    # Walk: a heavy wing-assisted hop - crouch, push, half-open wings, land, settle.
    poses = keyed(12, [
        (0, {}), (2, dict(dy=6, body_sy=0.95, wing_l=-sg * 6, wing_r=sg * 6)),
        (5, dict(fwd(f, 8), dy=-16, body_sy=1.03, wing_l=-sg * 26, wing_r=sg * 24, body=3)),
        (8, dict(fwd(f, 14), dy=3, body_sy=0.96, wing_l=-sg * 10, wing_r=sg * 8)),
        (11, dict(fwd(f, 16), dy=0)),
    ])
    for p in poses:
        p["dx"] = p.get("dx", 0) - mo.FWD[f][0] * 8
        p["dy"] = p.get("dy", 0) - mo.FWD[f][1] * 8
    A["walk"] = mo.follow(poses, lambda p: p.get("dy", 0), [("head", 0.4)], loop=True)
    rig.gait_speed = None
    att = keyed(12, [
        (0, {}), (3, dict(fwd(f, -10), dy=-6, body=-6, head=-sg * 8, wing_l=-sg * 34, wing_r=sg * 30, body_sy=1.03)),
        (6, dict(fwd(f, 26), dy=4, body=9, head=sg * 6, wing_l=sg * 10, wing_r=-sg * 8, body_sy=0.96)),
        (8, dict(fwd(f, 22), dy=2, body=6, wing_l=sg * 6)), (11, {}),
    ])
    A["attack"] = mo.follow(att, lambda p: p.get("dx", 0) + p.get("body", 0), [("head", 0.5)])
    A["hit"] = keyed(8, [(0, {}), (2, dict(fwd(f, -10), body=-7, head=sg * 10, wing_l=-sg * 18, wing_r=sg * 16)), (4, dict(fwd(f, -5), body=-3)), (7, {})])
    fall = -1 if f == "S" else 1
    A["death"] = keyed(13, [
        (0, {}), (3, dict(dy=-10, wing_l=-sg * 40, wing_r=sg * 36, head=-sg * 10)),
        (7, dict(rot=30 * fall, dy=20, wing_l=sg * 10, wing_r=-sg * 10, body=6 * fall)),
        (10, dict(rot=76 * fall, dy=60, sy=0.93, wing_l=sg * 30, wing_r=-sg * 26, body=8 * fall, head=10 * fall)),
        (12, dict(rot=80 * fall, dy=64, sy=0.92, wing_l=sg * 32, wing_r=-sg * 28, body=8 * fall, head=11 * fall)),
    ])
    # Signature (Silent Swoop): rise, wings wide, glide forward, land.
    A["summon"] = keyed(14, [
        (0, {}), (3, dict(dy=-24, wing_l=-sg * 50, wing_r=sg * 46, body=-4)),
        (7, dict(fwd(f, 20), dy=-30, wing_l=-sg * 56, wing_r=sg * 50, body=6)),
        (10, dict(fwd(f, 12), dy=-6, wing_l=-sg * 20, wing_r=sg * 18)), (13, {}),
    ])
    # Entrance: drops in from above with wings spread, lands heavy, settles.
    A["enter"] = keyed(16, [
        (0, dict(dy=-120, wing_l=-sg * 56, wing_r=sg * 52, sy=1.0)), (6, dict(dy=-40, wing_l=-sg * 44, wing_r=sg * 40)),
        (9, dict(dy=6, body_sy=0.92, wing_l=-sg * 20, wing_r=sg * 18)), (12, dict(dy=-2, body_sy=1.02)), (15, {}),
    ])
    return A


# ------------------------------------------------------------------ Old Gulp (toad boss)

def toad_facing(f):
    if f == "S":
        parts = [
            Part("hind_l", [(288, 700), (470, 700), (532, 830), (470, 864), (288, 822)], (420, 712), "body", True, 1),
            Part("front_r", [(1000, 640), (1122, 650), (1252, 900), (1152, 960), (980, 902), (1010, 760)], (1062, 662), "body", True, 2),
            Part("back", [(440, 128), (560, 58), (822, 38), (982, 198), (962, 300), (800, 332), (560, 422), (440, 422)], (700, 402), "body", True, 2),
            Part("front_l", [(600, 690), (762, 700), (842, 860), (832, 1000), (600, 1000), (610, 850)], (692, 712), "body", True, 3),
            Part("tongue", [(1040, 438), (1242, 558), (1242, 690), (1150, 690), (1060, 560)], (1062, 472), "head", False, 5),
            Part("head", [(780, 288), (1092, 288), (1112, 452), (1052, 522), (900, 542), (820, 472)], (900, 522), "body", True, 4),
        ]
        fc = mrig.Facing("toad_S.jpg", parts, ground=(760, 885), hip=(760, 600), scale=0.33, cell=CELL_BIG, cell_pivot=PIV_BIG, despill=True)
        fc.feet = {"hind_l": (330, 830), "front_l": (750, 940), "front_r": (1150, 940)}
        return fc
    parts = [
        Part("hind_l", [(58, 1058), (302, 1048), (352, 1250), (250, 1302), (58, 1272)], (250, 1080), "body", True, 1),
        Part("back", [(158, 598), (300, 478), (460, 278), (600, 348), (760, 448), (842, 700), (782, 950), (500, 962), (260, 1002), (158, 1002)], (520, 902), "body", True, 2),
        Part("front_r", [(858, 878), (1032, 878), (1112, 1140), (1102, 1222), (962, 1322), (858, 1252)], (932, 902), "body", True, 2),
        Part("front_l", [(478, 938), (762, 938), (782, 1100), (912, 1350), (902, 1482), (648, 1482), (498, 1300)], (622, 962), "body", True, 3),
        Part("tongue", [(958, 638), (1112, 658), (1112, 762), (978, 722)], (972, 682), "head", False, 5),
        Part("head", [(778, 498), (982, 498), (1002, 622), (962, 822), (838, 822)], (862, 802), "body", True, 4),
    ]
    fc = mrig.Facing("toad_E.jpg", parts, ground=(580, 1300), hip=(580, 1000), scale=0.31, cell=CELL_BIG, cell_pivot=PIV_BIG)
    fc.feet = {"hind_l": (200, 1290), "front_l": (800, 1470), "front_r": (1060, 1200)}
    return fc


def toad_actions(f, rig):
    A = {}
    sg = 1 if f == "S" else -1
    # Heavy: a slow throat pulse, the bulk settling, the tongue curling idly.
    def idle(t, v):
        th = wave(t, (1.0, 1, 0.0), (0.3, 2, 1.2))
        return {"body_sy": 1 + 0.018 * th, "body_sx": 1 - 0.008 * th, "dy": -0.6 * th, "head": sg * (1.5 * wave(t, (1, 1, 0.8)) + (5 * math.sin(math.pi * t) if v else 0)),
                "tongue": sg * 6 * wave(t, (1, 1, 1.6), (0.5, 3, 0.2)), "back": 0.8 * wave(t, (1, 1, -0.7))}
    for name, v in (("idle", False), ("idle2", True)):
        A[name] = mo.follow([idle(i / 12.0, v) for i in range(12)], lambda p: p.get("dy", 0), [("back", 0.6), ("tongue", 1.0)], loop=True)
    # Walk: a heavy, deliberate crawl - one leg at a time, the bulk rolling
    # over the planted feet, the millstone back lagging each heave.
    poses, speed, stance = mo.gait(f, 12, {"front_l": 0.0, "hind_l": 0.33, "front_r": 0.66}, stride=20.0, lift=10.0, duty=0.66, bob=3.0, sway=1.0)
    for i, p in enumerate(poses):
        t = i / 12.0
        p["body"] = 1.6 * math.sin(mo.TAU * 3 * t)
        p["head"] = sg * 2 * math.sin(mo.TAU * 3 * t + 0.6)
        p["tongue"] = sg * 8 * math.sin(mo.TAU * t)
    mo.follow(poses, lambda p: p.get("body", 0) + p.get("dy", 0), [("back", 1.0), ("tongue", 1.4)], loop=True)
    rig.gait_tracks = mo.plant(rig, poses, f, rig.feet, stance, speed)
    rig.gait_speed = speed
    rig.gait_stance = stance
    A["walk"] = poses
    att = keyed(12, [
        (0, {}), (3, dict(fwd(f, -10), dy=4, body=-4, body_sy=0.94, head=-sg * 6)),
        (6, dict(fwd(f, 24), dy=-10, body=5, body_sy=1.05, head=sg * 10, tongue=sg * 20)),
        (8, dict(fwd(f, 18), dy=-2, body=3, head=sg * 5)), (11, {}),
    ])
    A["attack"] = mo.follow(att, lambda p: p.get("dx", 0) + p.get("dy", 0), [("back", 0.9), ("tongue", 1.2)])
    A["hit"] = mo.follow(keyed(8, [(0, {}), (2, dict(fwd(f, -9), body=-5, body_sy=0.95, head=sg * 9)), (4, dict(fwd(f, -4), body=-2)), (7, {})]), lambda p: p.get("dx", 0), [("back", 1.2), ("tongue", 1.5)])
    fall = -1 if f == "S" else 1
    A["death"] = keyed(13, [
        (0, {}), (3, dict(dy=-8, body_sy=1.05, head=-sg * 10)),
        (7, dict(rot=14 * fall, dy=18, body_sy=0.9, head=sg * 6, tongue=sg * 20)),
        (10, dict(rot=34 * fall, dy=40, sy=0.9, body_sy=0.86, head=sg * 10, tongue=sg * 26)),
        (12, dict(rot=36 * fall, dy=42, sy=0.9, body_sy=0.86, head=sg * 10, tongue=sg * 28)),
    ])
    # Tongue Lash (signature): rear back, the tongue whips out, reels in.
    A["summon"] = keyed(14, [
        (0, {}), (3, dict(fwd(f, -8), dy=3, body=-5, head=-sg * 8, body_sy=0.95)),
        (6, dict(fwd(f, 10), dy=-6, body=6, head=sg * 12, tongue=sg * 34, body_sy=1.04)),
        (9, dict(fwd(f, 4), body=2, head=sg * 6, tongue=sg * 12)), (13, {}),
    ])
    # Entrance: rises out of the millpond mud - squat low, heave up, settle.
    A["enter"] = keyed(16, [
        (0, dict(dy=60, sy=0.6, body_sy=0.7)), (6, dict(dy=20, sy=0.85, body_sy=0.85)),
        (10, dict(dy=-10, sy=1.04, body_sy=1.06)), (13, dict(dy=2, body_sy=0.97)), (15, {}),
    ])
    return A


# ------------------------------------------------------------------ the Thresher Stag (boss)

def stag_facing(f):
    if f == "S":
        parts = [
            Part("hind_far", [(378, 1000), (522, 1000), (522, 1342), (418, 1342)], (450, 1012), "body", True, -1),
            Part("hind_near", [(98, 1000), (302, 980), (252, 1250), (232, 1402), (118, 1402)], (222, 1002), "body", True, 1),
            Part("front_near", [(638, 1000), (782, 1000), (762, 1200), (852, 1502), (718, 1502), (658, 1250)], (702, 1012), "body", True, 2),
            Part("head", [(638, 358), (802, 378), (922, 438), (922, 602), (862, 642), (762, 602), (682, 522), (628, 432)], (722, 622), "body", True, 3),
            Part("antlers", [(148, 78), (472, 58), (562, 18), (652, 38), (762, 18), (962, 118), (982, 382), (982, 700), (902, 700), (902, 422), (762, 422), (662, 382), (562, 332), (452, 302), (332, 452), (240, 600), (148, 600)], (762, 422), "head", False, 4),
        ]
        fc = mrig.Facing("stag_S.jpg", parts, ground=(480, 1430), hip=(520, 900), scale=0.27, cell=CELL_BIG, cell_pivot=PIV_BIG)
        fc.feet = {"hind_near": (170, 1395), "hind_far": (470, 1335), "front_near": (790, 1490)}
        return fc
    parts = [
        Part("front_far", [(498, 1000), (622, 1000), (602, 1282), (498, 1282)], (562, 1012), "body", True, -1),
        Part("hind_near", [(88, 1000), (302, 980), (242, 1250), (202, 1402), (98, 1402)], (222, 1002), "body", True, 1),
        Part("front_near", [(638, 1000), (762, 1000), (742, 1200), (772, 1382), (658, 1382), (648, 1200)], (702, 1012), "body", True, 1),
        Part("hind_far", [(268, 1000), (472, 1000), (462, 1300), (502, 1502), (378, 1502), (318, 1250)], (382, 1012), "body", True, 2),
        Part("head", [(498, 328), (762, 338), (742, 452), (600, 472), (508, 422)], (622, 462), "body", True, 3),
        Part("antlers", [(278, 28), (502, 28), (600, 198), (702, 28), (842, 38), (1002, 178), (1002, 702), (898, 702), (838, 422), (760, 382), (500, 382), (402, 642), (328, 642), (288, 300)], (622, 382), "head", False, 4),
    ]
    fc = mrig.Facing("stag_E.jpg", parts, ground=(420, 1440), hip=(450, 900), scale=0.27, cell=CELL_BIG, cell_pivot=PIV_BIG)
    fc.feet = {"hind_near": (150, 1395), "hind_far": (450, 1490), "front_near": (715, 1372), "front_far": (550, 1276)}
    return fc


def stag_actions(f, rig):
    A = {}
    sg = 1 if f == "S" else -1
    # Slow and regal: a long breath, the head lifting and the heavy antlers
    # (and their ribbons) lagging behind every move.
    def idle(t, v):
        br = wave(t, (1.0, 1, 0.0), (0.25, 2, 0.6))
        return {"body_sy": 1 + 0.01 * br, "dy": -1.0 * br, "body": 0.6 * wave(t, (1, 1, 0.9)),
                "head": sg * (2.0 * wave(t, (1, 1, 0.3)) + (7 * math.sin(math.pi * t) if v else 0)), "hind_near": 1.5 * wave(t, (1, 1, 2.0))}
    for name, v in (("idle", False), ("idle2", True)):
        A[name] = mo.follow([idle(i / 12.0, v) for i in range(12)], lambda p: p.get("head", 0) + p.get("dy", 0), [("antlers", 0.7)], loop=True)
    phases = {"hind_near": 0.0, "front_far": 0.02, "hind_far": 0.5, "front_near": 0.52}
    poses, speed, stance = mo.gait(f, 12, {k: phases[k] for k in rig.feet}, stride=28.0, lift=12.0, duty=0.6, bob=3.0, bob_phase=0.1, sway=0.6)
    for i, p in enumerate(poses):
        t = i / 12.0
        p["head"] = sg * (2.5 * math.sin(mo.TAU * (2 * t + 0.4)))
        p["body"] = 0.8 * math.sin(mo.TAU * (2 * t + 0.2))
    mo.follow(poses, lambda p: p.get("head", 0) + p.get("dy", 0), [("antlers", 1.1)], loop=True)
    rig.gait_tracks = mo.plant(rig, poses, f, rig.feet, stance, speed)
    rig.gait_speed = speed
    rig.gait_stance = stance
    A["walk"] = poses
    att = keyed(12, [
        (0, {}), (3, dict(fwd(f, -8), body=-6, head=-sg * 14, hind_near=6 * sg, body_sy=1.02)),
        (6, dict(fwd(f, 22), body=7, head=sg * 22, front_near=-10 * sg)),
        (8, dict(fwd(f, 18), body=5, head=sg * 14)), (11, {}),
    ])
    A["attack"] = mo.follow(att, lambda p: p.get("head", 0) + p.get("dx", 0), [("antlers", 0.9)])
    A["hit"] = mo.follow(keyed(8, [(0, {}), (2, dict(fwd(f, -9), body=-6, head=-sg * 12)), (4, dict(fwd(f, -4), body=-2)), (7, {})]), lambda p: p.get("head", 0), [("antlers", 1.2)])
    fall = -1 if f == "S" else 1
    A["death"] = keyed(13, [
        (0, {}), (3, dict(head=-sg * 18, body=-5, dy=-6)),
        (7, dict(rot=20 * fall, dy=20, head=sg * 6, front_near=18, hind_near=-10)),
        (10, dict(rot=72 * fall, dy=70, sy=0.93, head=sg * 12, front_near=26, hind_near=-16, hind_far=-12)),
        (12, dict(rot=76 * fall, dy=74, sy=0.92, head=sg * 13, front_near=27, hind_near=-17, hind_far=-13)),
    ])
    # Call the Herd: rears up and bellows, antlers high.
    A["summon"] = keyed(14, [
        (0, {}), (4, dict(rot=-8 * sg, dy=-10, head=-sg * 20, front_near=-24 * sg, body=-6)),
        (8, dict(rot=-10 * sg, dy=-14, head=-sg * 26, front_near=-30 * sg, body=-8)),
        (11, dict(dy=2, head=sg * 6, body=2)), (13, {}),
    ])
    A["enter"] = keyed(16, [
        (0, dict(fwd(f, -60), dy=-6)), (8, dict(fwd(f, -12), dy=-2)), (12, dict(head=-sg * 16, body=-4)), (15, {}),
    ])
    return A


MONSTERS = {
    "bristleback_boar": {"name": "Bristleback Boar", "facing": boar_facing, "actions": boar_actions, "cell": CELL, "pivot": PIV, "role": "basic"},
    "mandrake_rootling": {"name": "Mandrake Rootling", "facing": mandrake_facing, "actions": mandrake_actions, "cell": CELL, "pivot": PIV, "role": "basic"},
    "thistle_puffball": {"name": "Thistle Puffball", "facing": puffball_facing, "actions": puffball_actions, "cell": CELL, "pivot": PIV, "role": "ranged", "release": 7},
    "flour_moth": {"name": "Flour Moth", "facing": moth_facing, "actions": moth_actions, "cell": CELL, "pivot": PIV, "role": "ranged", "release": 7, "flies": True},
    "old_gulp_millpond_toad": {"name": "Old Gulp, the Millpond Toad", "facing": toad_facing, "actions": toad_actions, "cell": CELL_BIG, "pivot": PIV_BIG, "role": "boss"},
    "thresher_stag": {"name": "The Thresher Stag", "facing": stag_facing, "actions": stag_actions, "cell": CELL_BIG, "pivot": PIV_BIG, "role": "boss"},
    "grimhoot_orchard_owl": {"name": "Grimhoot, the Orchard Owl", "facing": owl_facing, "actions": owl_actions, "cell": CELL_BIG, "pivot": PIV_BIG, "role": "boss", "flies": True},
}


def build(mid, check=False, only=None):
    import json
    spec = MONSTERS[mid]
    mdir = os.path.join(gkit.OUT, "monsters", mid)
    meta = {"id": mid, "name": spec["name"], "star5": False, "base_of": None, "dir": "monsters/" + mid, "cell": list(spec["cell"]), "pivot": list(spec["pivot"]), "fps": FPS,
            "facings": ["S", "E"], "mirror": {"W": "E", "N": "S"}, "actions": {}, "qa": {}, "role": spec["role"], "gait": {}}
    old_meta = os.path.join(mdir, "meta.json")
    if only and os.path.exists(old_meta):
        # One facing rebuilt: keep the other facing's rows.
        prev = json.load(open(old_meta))
        for k in ("actions", "qa", "gait"):
            meta[k] = prev.get(k, {})
        for a in meta["actions"].values():
            a["files"] = {f: v for f, v in a.get("files", {}).items() if f != only}
        meta["gait"].pop(only, None)
    for f in ("S", "E"):
        if only and f != only:
            continue
        rig = _rig((mid, f), lambda: spec["facing"](f))
        if rig is None:
            print(mid, f, "no painting yet")
            continue
        acts = spec["actions"](f, rig)
        meta["qa"]["hole_fill_px_" + f] = rig.hole_px
        if getattr(rig, "gait_speed", None):
            meta["gait"][f] = {"speed_px_per_frame": round(rig.gait_speed, 4), "dir": list(mo.FWD[f]),
                               "stance": rig.gait_stance, "feet": rig.gait_tracks}
        for act, poses in acts.items():
            if check and act not in ("idle", "walk", "attack"):
                continue
            if act != "walk":
                for _ in range(3):
                    nxt = monster_kit.keep_in(rig, poses)
                    if nxt is poses:
                        break
                    poses = nxt
            lost_max = 0
            shift_max = 0.0
            for i, pose in enumerate(poses):
                im, lost = rig.render(pose)
                lost_max = max(lost_max, lost)
                shift_max = max(shift_max, abs(rig.last_shift[0]), abs(rig.last_shift[1]))
                gkit.save_png(os.path.join(mdir, act, "%s_%s_f%02d.png" % (act, f, i)), im)
            a = meta["actions"].setdefault(act, {"frames": len(poses), "loop": monster_kit.LOOPS.get(act, False), "files": {}})
            a["files"][f] = "monsters/%s/%s/%s_%s_fNN.png" % (mid, act, act, f)
            meta["qa"]["px_outside_cell_%s_%s" % (act, f)] = lost_max
            meta["qa"]["keep_in_shift_px_%s_%s" % (act, f)] = round(shift_max, 1)
            print(mid, f, act, len(poses), "outside", lost_max, "shift", round(shift_max, 1), flush=True)
    if spec.get("release") is not None:
        meta["release"] = {"action": "attack", "frame": spec["release"], "point_px": {}}
    if spec.get("flies"):
        meta["flies"] = True
    os.makedirs(mdir, exist_ok=True)
    with open(os.path.join(mdir, "meta.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    return meta


if __name__ == "__main__":
    ids = [a for a in sys.argv[1:] if not a.startswith("--") and a in MONSTERS] or list(MONSTERS)
    only = sys.argv[sys.argv.index("--facing") + 1] if "--facing" in sys.argv else None
    for mid in ids:
        build(mid, check="--check" in sys.argv, only=only)
