"""Old Granary Cellar monsters: Granary Rat, Scarecrow Drudge, the Ratking.

Rigs (part cuts on the approved turnarounds in granary_src/<id>_{S,E}.jpg) and
the actions. S = front, facing screen down-right; E = back, facing screen
up-right. W and N are game-side mirrors of E and S.

Cells: 512x360, pivot (256,329) for the rat and the scarecrow (as the heroes);
the Ratking is 1.5x the hero height and uses a 768x540 cell, pivot (384,494)
(the hero cell scaled 1.5x). 17.144 fps.

  python3 granary_monsters.py [monster ...] [--check]
"""
from __future__ import annotations

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import mrig  # noqa: E402
from mrig import Part, keys  # noqa: E402

FPS = 17.144
OUT = os.path.join(gkit.OUT, "monsters")
CELL = (512, 360)
PIV = (256, 329)
CELL_BIG = (768, 540)
PIV_BIG = (384, 494)

FWD = {"S": (math.cos(math.atan2(0.5, 1)), math.sin(math.atan2(0.5, 1))),
       "E": (math.cos(math.atan2(-0.5, 1)), math.sin(math.atan2(-0.5, 1)))}


def fwd(f, d):
    return {"dx": FWD[f][0] * d, "dy": FWD[f][1] * d}


# ------------------------------------------------------------------ rigs

def rat_facing(f):
    if f == "S":
        parts = [
            Part("tail2", [(0, 25), (215, 25), (215, 150), (195, 250), (0, 250)], (185, 200), "tail1", False, -3),
            Part("tail1", [(195, 140), (260, 160), (300, 185), (312, 240), (292, 285), (195, 285)], (300, 228), "body", True, -2),
            Part("hind_a", [(250, 345), (330, 330), (350, 420), (345, 525), (225, 525), (240, 420)], (292, 350), "body", True, -1),
            Part("hind_b", [(420, 385), (485, 378), (548, 468), (548, 505), (428, 505), (412, 430)], (450, 390), "body", True, -1),
            Part("front_far", [(745, 492), (805, 488), (862, 555), (862, 598), (742, 598)], (775, 495), "body", True, 1),
            Part("head", [(612, 232), (700, 212), (875, 228), (900, 320), (872, 420), (832, 495), (760, 500), (700, 470), (640, 400), (605, 300)], (645, 375), "body", True, 2),
            Part("front_near", [(588, 438), (662, 436), (705, 555), (765, 598), (765, 655), (625, 655), (605, 560)], (628, 448), "body", True, 3),
        ]
        return mrig.Facing("rat_S.jpg", parts, ground=(560, 565), hip=(450, 330), scale=0.22, cell=CELL, cell_pivot=PIV)
    parts = [
        Part("tail2", [(20, 560), (120, 560), (300, 545), (330, 600), (200, 630), (90, 615), (50, 672), (15, 660)], (305, 575), "tail1", False, -3),
        Part("tail1", [(380, 345), (465, 345), (455, 425), (395, 520), (330, 600), (285, 560), (345, 480)], (425, 360), "body", True, 4),
        Part("hind_far", [(408, 435), (470, 430), (495, 505), (420, 510)], (450, 440), "body", True, -1),
        Part("front_far", [(648, 378), (720, 375), (740, 445), (655, 445)], (680, 385), "body", True, -1),
        Part("hind_near", [(495, 460), (610, 465), (630, 625), (500, 625)], (560, 470), "body", True, 2),
        Part("front_near", [(785, 300), (840, 300), (895, 365), (890, 400), (790, 400)], (805, 310), "body", True, 2),
        Part("head", [(665, 18), (895, 55), (885, 150), (835, 195), (720, 150), (655, 90)], (760, 165), "body", True, 3),
    ]
    return mrig.Facing("rat_E.jpg", parts, ground=(630, 480), hip=(560, 300), scale=0.22, cell=CELL, cell_pivot=PIV)


def scarecrow_facing(f):
    if f == "S":
        parts = [
            Part("leg_l", [(590, 900), (780, 900), (812, 1050), (812, 1200), (802, 1250), (892, 1360), (885, 1415), (695, 1415), (688, 1260), (678, 1150), (638, 1050), (598, 960)], (690, 925), "root", True, -2),
            Part("leg_r", [(330, 940), (470, 918), (562, 960), (532, 1150), (522, 1300), (542, 1462), (470, 1515), (238, 1505), (298, 1400), (358, 1290), (368, 1150), (318, 1050)], (462, 942), "root", True, -1),
            Part("arm_l_up", [(722, 350), (802, 358), (862, 560), (912, 580), (902, 700), (822, 702), (782, 562), (720, 470)], (760, 395), "body", True, 1),
            Part("arm_l_lo", [(808, 640), (922, 618), (965, 780), (955, 1065), (828, 1065), (818, 800)], (860, 678), "arm_l_up", False, 1),
            Part("head", [(288, 240), (418, 108), (438, 38), (602, 28), (652, 118), (782, 138), (702, 200), (662, 330), (642, 382), (562, 392), (478, 372), (418, 332), (328, 262)], (560, 378), "body", True, 2),
            Part("arm_r_up", [(418, 478), (472, 498), (462, 560), (422, 650), (385, 722), (328, 722), (318, 640), (348, 560)], (445, 510), "body", True, 3),
            Part("arm_r_lo", [(298, 688), (392, 688), (398, 862), (300, 872), (172, 1045), (45, 1045), (52, 698), (198, 688)], (345, 702), "arm_r_up", False, 3),
        ]
        return mrig.Facing("scarecrow_S.jpg", parts, ground=(560, 1455), hip=(560, 860), scale=0.173, cell=CELL, cell_pivot=PIV)
    parts = [
        Part("arm_l_up", [(218, 318), (312, 298), (322, 420), (272, 562), (242, 642), (158, 642), (168, 520), (198, 420)], (288, 340), "body", True, -2),
        Part("arm_l_lo", [(105, 618), (252, 618), (262, 762), (232, 912), (115, 915), (98, 762)], (200, 640), "arm_l_up", False, -2),
        Part("leg_l", [(198, 990), (330, 990), (332, 1100), (302, 1180), (352, 1290), (322, 1392), (148, 1385), (178, 1250), (188, 1120), (178, 1030)], (268, 1000), "root", True, -1),
        Part("leg_r", [(500, 980), (622, 960), (692, 1050), (692, 1200), (662, 1250), (802, 1380), (802, 1455), (558, 1465), (558, 1350), (568, 1240), (558, 1100), (500, 1040)], (585, 990), "root", True, -1),
        Part("head", [(328, 140), (418, 38), (562, 52), (622, 88), (642, 200), (762, 250), (692, 322), (622, 342), (520, 322), (420, 262), (358, 222)], (500, 300), "body", False, 2),
        Part("arm_r_up", [(560, 338), (642, 378), (672, 500), (722, 620), (722, 702), (652, 722), (612, 620), (560, 460)], (582, 370), "body", True, 3),
        Part("arm_r_lo", [(638, 678), (742, 698), (762, 760), (802, 658), (922, 648), (1002, 760), (992, 902), (922, 932), (802, 882), (650, 882), (628, 800)], (680, 692), "arm_r_up", False, 3),
    ]
    return mrig.Facing("scarecrow_E.jpg", parts, ground=(455, 1405), hip=(450, 900), scale=0.18, cell=CELL, cell_pivot=PIV)


def ratking_facing(f):
    if f == "S":
        parts = [
            Part("foot_l", [(55, 1335), (272, 1312), (285, 1405), (172, 1445), (55, 1435)], (200, 1342), "root", False, 3),
            Part("foot_r", [(618, 1345), (802, 1332), (870, 1485), (760, 1515), (638, 1485)], (700, 1352), "root", False, 3),
            Part("claw", [(195, 598), (332, 598), (422, 698), (445, 792), (412, 845), (330, 845), (280, 762), (198, 702)], (232, 632), "body", True, 4),
            Part("head", [(438, 138), (558, 28), (642, 28), (762, 58), (782, 198), (802, 340), (762, 402), (702, 442), (622, 452), (562, 422), (462, 332), (428, 222)], (582, 440), "body", True, 5),
            Part("crook", [(798, 58), (992, 68), (992, 232), (942, 332), (962, 472), (945, 545), (950, 690), (915, 705), (912, 940), (985, 1080), (985, 1420), (822, 1425), (828, 1000), (840, 708), (790, 700), (758, 600), (770, 548), (842, 520), (842, 332), (808, 200)], (770, 560), "body", True, 6),
        ]
        return mrig.Facing("ratking_S.jpg", parts, ground=(470, 1440), hip=(470, 1000), scale=0.26, cell=CELL_BIG, cell_pivot=PIV_BIG)
    parts = [
        Part("tail2", [(28, 1225), (122, 1262), (112, 1382), (202, 1442), (332, 1462), (422, 1482), (422, 1512), (300, 1505), (150, 1475), (58, 1405), (25, 1300)], (92, 1268), "tail1", False, -3),
        Part("tail1", [(255, 1065), (345, 1050), (332, 1102), (202, 1202), (112, 1302), (58, 1302), (78, 1222), (178, 1132), (240, 1085)], (300, 1068), "body", False, -2),
        Part("foot_l", [(198, 1290), (312, 1268), (482, 1318), (502, 1395), (330, 1405), (208, 1395)], (330, 1300), "root", False, 3),
        Part("foot_r", [(618, 1328), (802, 1338), (912, 1398), (902, 1445), (760, 1445), (618, 1425)], (700, 1350), "root", False, 3),
        Part("head", [(488, 128), (558, 38), (752, 58), (792, 198), (772, 302), (702, 332), (562, 282), (498, 222)], (640, 300), "body", False, 4),
        Part("crook", [(818, 58), (992, 88), (992, 222), (942, 252), (972, 320), (972, 470), (935, 495), (952, 560), (918, 630), (915, 1362), (862, 1362), (868, 650), (812, 640), (790, 560), (842, 500), (868, 252), (818, 152)], (800, 560), "body", True, 5),
    ]
    return mrig.Facing("ratking_E.jpg", parts, ground=(555, 1410), hip=(555, 1000), scale=0.264, cell=CELL_BIG, cell_pivot=PIV_BIG)


# --------------------------------------------------------------- actions

def cyc(n, fn):
    return [fn(i / float(n)) for i in range(n)]


def rat_actions(f):
    s = math.sin
    tau = 2 * math.pi
    A = {}
    A["idle"] = cyc(12, lambda t: {"sy": 1 + 0.018 * s(tau * t), "body": 1.0 * s(tau * t), "head": 3 * s(tau * t + 1.0),
                                   "tail1": 4 * s(tau * t), "tail2": 7 * s(tau * t - 0.8), "dy": -0.6 * s(tau * t)})
    legs = ["front_near", "hind_a", "front_far", "hind_b"] if f == "S" else ["front_near", "hind_far", "front_far", "hind_near"]
    def walk(t):
        p = {"dy": -2.5 * abs(s(tau * t)), "body": 2.0 * s(tau * t), "head": 4 * s(tau * t * 2 + 0.5),
             "tail1": 6 * s(tau * t), "tail2": 10 * s(tau * t - 1.0)}
        sw = 22
        p[legs[0]] = -sw * s(tau * t)
        p[legs[1]] = -sw * s(tau * t)
        p[legs[2]] = sw * s(tau * t)
        p[legs[3]] = sw * s(tau * t)
        return p
    A["walk"] = cyc(12, walk)
    hb = -1 if f == "S" else 1
    A["attack"] = keys(12, [
        (0, {}),
        (3, dict(fwd(f, -7), body=-6, head=-14 * hb, front_near=12, front_far=12, tail1=-8, sy=0.96)),
        (5, dict(fwd(f, 20), body=7, head=16 * hb, front_near=-24, front_far=-20, hind_a=10, hind_b=10, hind_far=10, hind_near=10, tail1=10, tail2=12)),
        (7, dict(fwd(f, 18), body=5, head=10 * hb, front_near=-18, front_far=-14, tail1=6)),
        (11, {}),
    ])
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -12), body=-9, head=-16 * hb, dy=-3, tail1=-14, tail2=-16, front_near=14, front_far=14)),
        (4, dict(fwd(f, -9), body=-4, head=-6 * hb, tail1=-6)),
        (7, {}),
    ])
    # Death: squeal and rear back, roll over onto the back (legs up), twitch, lie still.
    cx, cy = (560, 380) if f == "S" else (630, 300)
    d = keys(13, [
        (0, {}),
        (2, dict(fwd(f, -8), body=-10, head=-20 * hb, dy=-6, tail1=-16)),
        (4, dict(fwd(f, -10), rot=-60, dy=-16, head=-10 * hb)),
        (6, dict(fwd(f, -12), rot=-150, dy=-6, sy=0.9)),
        (7, dict(fwd(f, -12), rot=-180, dy=10, sy=0.82, front_near=-25, front_far=25, tail1=20, tail2=25)),
        (9, dict(fwd(f, -12), rot=-180, dy=12, sy=0.8, front_near=-10, front_far=12, tail1=26, tail2=30, head=6)),
        (12, dict(fwd(f, -12), rot=-180, dy=12, sy=0.8, front_near=-14, front_far=16, tail1=28, tail2=32, head=8)),
    ])
    for p in d:
        p["rot_c"] = (cx, cy)
    A["death"] = d
    return A


def scarecrow_actions(f):
    s = math.sin
    tau = 2 * math.pi
    A = {}
    lean = 1 if f == "S" else 1
    A["idle"] = cyc(12, lambda t: {"body": 1.5 * s(tau * t), "head": -2.5 * s(tau * t + 0.6), "sy": 1 + 0.012 * s(tau * t),
                                   "arm_r_up": 3 * s(tau * t + 0.4), "arm_r_lo": 3 * s(tau * t + 1.0),
                                   "arm_l_up": -3 * s(tau * t + 0.9), "arm_l_lo": -4 * s(tau * t + 1.5)})
    def walk(t):
        w = s(tau * t)
        return {"leg_r": -17 * w, "leg_l": 17 * w, "body": 3 * w, "rot": 1.5 * w, "dy": -4 * abs(w),
                "head": -4 * s(tau * t + 0.7), "arm_r_up": 12 * w, "arm_r_lo": 6 * s(tau * t - 0.6),
                "arm_l_up": -12 * w, "arm_l_lo": -8 * s(tau * t - 0.6)}
    A["walk"] = cyc(12, walk)
    if f == "S":
        wind = dict(arm_r_up=95, arm_r_lo=-10, body=-8, head=-6, arm_l_up=-15, leg_r=4, leg_l=-4)
        slash = dict(fwd(f, 14), arm_r_up=-52, arm_r_lo=-12, body=12, head=6, arm_l_up=18, leg_r=-10, leg_l=6)
        follow = dict(fwd(f, 12), arm_r_up=-58, arm_r_lo=-16, body=10, head=5, arm_l_up=14, leg_r=-8, leg_l=5)
    else:
        wind = dict(arm_r_up=-125, arm_r_lo=-35, body=-8, head=-6, arm_l_up=15, leg_r=-4, leg_l=4)
        slash = dict(fwd(f, 14), arm_r_up=-62, arm_r_lo=-18, body=12, head=6, arm_l_up=-18, leg_r=10, leg_l=-6)
        follow = dict(fwd(f, 12), arm_r_up=-48, arm_r_lo=-12, body=10, head=5, arm_l_up=-14, leg_r=8, leg_l=-5)
    A["attack"] = keys(12, [(0, {}), (3, wind), (4, wind), (6, slash), (8, follow), (11, {})])
    hs = -1
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -10), body=-13, head=-14, arm_r_up=18 * (1 if f == "S" else -1), arm_l_up=-18 * (1 if f == "S" else -1),
                 arm_r_lo=12 * (1 if f == "S" else -1), arm_l_lo=-12 * (1 if f == "S" else -1), leg_r=6, leg_l=-6)),
        (4, dict(fwd(f, -6), body=-6, head=-4)),
        (7, {}),
    ])
    # Death: the straw gives out, knees splay, the body folds back and falls, the head rolls.
    fall = -1 if f == "S" else 1
    A["death"] = keys(13, [
        (0, {}),
        (2, dict(body=-8 * fall, head=-12, dy=-4, arm_r_up=20 * fall, arm_l_up=-20 * fall)),
        (5, dict(body=30 * fall, rot=8 * fall, dy=40, leg_r=20, leg_l=-20, head=20 * fall, arm_r_up=40 * fall, arm_l_up=-35 * fall, arm_r_lo=20 * fall, arm_l_lo=-25 * fall)),
        (8, dict(body=72 * fall, rot=14 * fall, dy=95, sy=0.92, leg_r=34, leg_l=-30, head=55 * fall, **{"head.dy": 10}, arm_r_up=70 * fall, arm_l_up=-60 * fall, arm_r_lo=35 * fall, arm_l_lo=-45 * fall)),
        (10, dict(body=84 * fall, rot=16 * fall, dy=104, sy=0.9, leg_r=38, leg_l=-34, head=78 * fall, **{"head.dy": 14}, arm_r_up=82 * fall, arm_l_up=-70 * fall, arm_r_lo=40 * fall, arm_l_lo=-50 * fall)),
        (12, dict(body=84 * fall, rot=16 * fall, dy=106, sy=0.9, leg_r=38, leg_l=-34, head=80 * fall, **{"head.dy": 15}, arm_r_up=82 * fall, arm_l_up=-70 * fall, arm_r_lo=40 * fall, arm_l_lo=-50 * fall)),
    ])
    return A


def ratking_actions(f):
    s = math.sin
    tau = 2 * math.pi
    A = {}
    A["idle"] = cyc(12, lambda t: {"sy": 1 + 0.014 * s(tau * t), "body": 1.2 * s(tau * t), "head": 2.5 * s(tau * t + 0.9),
                                   "crook": 1.2 * s(tau * t + 0.3), "claw": 4 * s(tau * t + 1.3),
                                   "tail1": 3 * s(tau * t), "tail2": 6 * s(tau * t - 0.8)})
    def walk(t):
        w = s(tau * t)
        return {"rot": 3.0 * w, "body": 1.5 * w, "dy": -4 * abs(w), "head": -2.5 * s(tau * t + 0.6),
                "foot_l.dy": -10 * max(0.0, w), "foot_r.dy": -10 * max(0.0, -w),
                "foot_l.dx": 6 * w, "foot_r.dx": -6 * w,
                "crook": -3 * w, "crook.dy": -6 * max(0.0, -w), "claw": 6 * w,
                "tail1": 6 * w, "tail2": 10 * s(tau * t - 0.9)}
    A["walk"] = cyc(12, walk)
    if f == "S":
        wind = dict(crook=-28, **{"crook.dy": -30}, body=-6, head=-8, claw=-35)
        smash = dict(fwd(f, 18), crook=34, **{"crook.dy": 6}, body=9, head=8, claw=40)
        follow = dict(fwd(f, 16), crook=30, **{"crook.dy": 4}, body=7, head=6, claw=34)
    else:
        wind = dict(crook=-30, **{"crook.dy": -30}, body=-6, head=-8)
        smash = dict(fwd(f, 18), crook=30, **{"crook.dy": 4}, body=9, head=8)
        follow = dict(fwd(f, 16), crook=26, **{"crook.dy": 2}, body=7, head=6)
    A["attack"] = keys(12, [(0, {}), (3, wind), (4, wind), (6, smash), (8, follow), (11, {})])
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -12), body=-9, head=-14, crook=-8, claw=-20, dy=-2, tail1=-8)),
        (4, dict(fwd(f, -8), body=-4, head=-5, crook=-3)),
        (7, {}),
    ])
    fall = -1
    A["death"] = keys(13, [
        (0, {}),
        (2, dict(body=-7, head=-18, crook=-10, claw=-25, dy=-4)),
        (5, dict(rot=22 * fall, body=6 * fall, dy=10, head=-10, crook=12, **{"crook.dy": 10}, claw=20)),
        (8, dict(rot=62 * fall, body=10 * fall, dy=40, head=6, crook=4, **{"crook.dy": 18}, claw=40, sy=0.95)),
        (10, dict(rot=82 * fall, body=8 * fall, dy=52, head=12, crook=-2, **{"crook.dy": 22}, claw=50, sy=0.9)),
        (12, dict(rot=84 * fall, body=8 * fall, dy=54, head=14, crook=-3, **{"crook.dy": 22}, claw=52, sy=0.9)),
    ])
    # Signature: raise the crook high and squeal (summons rats), then slam it down.
    shake = [0, 0, 0, 0, 1, -1, 1, -1, 1, -1, 0, 0, 0, 0]
    sm = keys(14, [
        (0, {}),
        (3, dict(crook=-10, **{"crook.dy": -95}, body=-7, head=-22, claw=-60, sy=1.02)),
        (9, dict(crook=-12, **{"crook.dy": -100}, body=-8, head=-26, claw=-65, sy=1.03)),
        (10, dict(crook=4, **{"crook.dy": 8}, body=4, head=-6, claw=-10)),
        (11, dict(crook=3, **{"crook.dy": 6}, body=3, head=-3, claw=-6)),
        (13, {}),
    ])
    for i, p in enumerate(sm):
        p["head"] = p.get("head", 0.0) + 3.0 * shake[i]
        p["body"] = p.get("body", 0.0) + 0.8 * shake[i]
    A["summon"] = sm
    return A


MONSTERS = {
    "granary_rat": {"name": "Granary Rat", "rig": rat_facing, "actions": rat_actions, "cell": CELL, "pivot": PIV,
                    "base": {"E": {"tail1": 16, "tail2": 8}}},
    "scarecrow_drudge": {"name": "Scarecrow Drudge", "rig": scarecrow_facing, "actions": scarecrow_actions, "cell": CELL, "pivot": PIV},
    "the_ratking": {"name": "The Ratking", "rig": ratking_facing, "actions": ratking_actions, "cell": CELL_BIG, "pivot": PIV_BIG},
}
LOOPS = {"idle": True, "walk": True, "attack": False, "hit": False, "death": False, "summon": False}


def keep_in(rig, poses):
    """Lift/shift a pose sequence smoothly so every frame stays inside the cell.

    Pass 1 measures the per-frame shift the renderer would need; the shift is
    widened (+-2 frames), smoothed, and added to the poses' dx/dy, so the
    correction eases in and out instead of popping.
    """
    need = []
    for p in poses:
        rig.render(p)
        need.append(rig.last_shift)
    if not any(abs(a) > 0.01 or abs(b) > 0.01 for a, b in need):
        return poses
    n = len(poses)
    out = []
    env = []
    for i in range(n):
        w = need[max(0, i - 2):i + 3]
        env.append((max(w, key=lambda t: abs(t[0]))[0], max(w, key=lambda t: abs(t[1]))[1]))
    for i in range(n):
        w = env[max(0, i - 1):i + 2]
        ex = sum(t[0] for t in w) / len(w)
        ey = sum(t[1] for t in w) / len(w)
        q = dict(poses[i])
        q["dx"] = q.get("dx", 0.0) + ex * 1.05
        q["dy"] = q.get("dy", 0.0) + ey * 1.05
        out.append(q)
    return out


def build(mid, check=False):
    spec = MONSTERS[mid]
    mdir = os.path.join(OUT, mid)
    meta = {"id": mid, "name": spec["name"], "cell": list(spec["cell"]), "pivot": list(spec["pivot"]), "fps": FPS,
            "facings": ["S", "E"], "mirror": {"W": "E", "N": "S"}, "actions": {}, "qa": {}}
    for f in ("S", "E"):
        rig = spec["rig"](f)
        acts = spec["actions"](f)
        meta["qa"]["hole_fill_px_" + f] = rig.hole_px
        base = spec.get("base", {}).get(f, {})
        for act, poses in acts.items():
            poses = mrig.add([dict(p) for p in poses], [base] * len(poses))
            if check and act not in ("idle", "attack", "death"):
                continue
            for _ in range(3):
                poses = keep_in(rig, poses)
            lost_max = 0
            shift_max = 0.0
            for i, pose in enumerate(poses):
                im, lost = rig.render(pose)
                lost_max = max(lost_max, lost)
                shift_max = max(shift_max, abs(rig.last_shift[0]), abs(rig.last_shift[1]))
                path = os.path.join(mdir, act, "%s_%s_f%02d.png" % (act, f, i))
                gkit.save_png(path, im)
            a = meta["actions"].setdefault(act, {"frames": len(poses), "loop": LOOPS[act], "files": {}})
            a["files"][f] = "monsters/%s/%s/%s_%s_fNN.png" % (mid, act, act, f)
            meta["qa"]["px_outside_cell_%s_%s" % (act, f)] = lost_max
            meta["qa"]["keep_in_shift_px_%s_%s" % (act, f)] = round(shift_max, 1)
            print(mid, f, act, len(poses), "outside", lost_max, "keep-in shift", round(shift_max, 1), flush=True)
    gkit.write_json(os.path.join(mdir, "meta.json"), meta)
    return meta


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    for mid in (args or list(MONSTERS)):
        build(mid, check="--check" in sys.argv)
