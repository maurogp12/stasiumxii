"""Saltmaw Grotto monsters: Reef Crab, Drowned Sailor, Drowned Harpooner, Old Saltmaw (+ star-5 abyssal forms).

Rigs are part cuts on the chosen paintings in saltmaw_src/<id>_{S,E}.jpg (flat magenta);
the actions are posed here and rendered by the shared monster_kit / mrig.
S = front, facing screen down-right; E = back, facing screen up-right. W and N are game-side
mirrors of E and S.

Cells: 512x360, pivot (256,329) for the crab, the sailor and the harpooner (as the heroes);
Old Saltmaw is 1.5x the hero cell, 768x540, pivot (384,494). 17.144 fps.

Angle sign used below: + = clockwise on screen (y down). A point left of a pivot goes UP
under +, a point right of a pivot goes DOWN, a point above goes RIGHT, a point below goes LEFT.

  python3 saltmaw_monsters.py [monster ...] [--check]
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
import monster_kit  # noqa: E402
from monster_kit import CELL, CELL_BIG, PIV, PIV_BIG, cyc, fwd  # noqa: E402

gkit.use("saltmaw_grotto")
TEAL_GLOW = (0.25, 1.0, 0.8)
CYAN_GLOW = (0.3, 0.9, 1.0)


# ------------------------------------------------------------------ rigs

def crab_facing(f, src="crab"):
    if f == "S":
        parts = [
            Part("claw_l", [(200, 420), (330, 390), (400, 450), (440, 520), (560, 600), (610, 700), (610, 800), (580, 880), (610, 970), (380, 970), (230, 800), (200, 660)], (330, 450), "body", True, 2),
            Part("claw_r", [(710, 430), (800, 420), (880, 460), (950, 560), (975, 700), (935, 790), (800, 820), (770, 700), (740, 580), (705, 520)], (740, 470), "body", True, 2),
            Part("legs_l", [(15, 270), (245, 270), (245, 420), (200, 450), (200, 890), (15, 890)], (235, 420), "root", True, -1),
            Part("legs_r", [(780, 270), (1010, 270), (1010, 830), (955, 830), (955, 560), (880, 450), (800, 420), (780, 400)], (790, 420), "root", True, -1),
        ]
        return mrig.Facing(src + "_S.jpg", parts, ground=(500, 880), hip=(500, 520), scale=0.27, cell=CELL, cell_pivot=PIV, despill=True)
    parts = [
        Part("claw_a", [(430, 170), (560, 105), (760, 110), (760, 250), (640, 325), (560, 335), (470, 295)], (480, 280), "body", True, 2),
        Part("claw_b", [(690, 420), (760, 300), (900, 165), (980, 210), (975, 420), (905, 570), (800, 570), (720, 470)], (720, 450), "body", True, 2),
        Part("legs_l", [(15, 330), (230, 330), (265, 480), (265, 840), (15, 840)], (250, 420), "root", True, -1),
        Part("legs_f", [(430, 615), (650, 605), (700, 545), (920, 545), (920, 870), (600, 950), (430, 950)], (600, 600), "root", True, -1),
    ]
    return mrig.Facing(src + "_E.jpg", parts, ground=(520, 820), hip=(500, 450), scale=0.27, cell=CELL, cell_pivot=PIV, despill=True)


def sailor_facing(f, src="sailor"):
    if f == "S":
        parts = [
            Part("arm_sword", [(45, 135), (135, 155), (250, 560), (330, 480), (395, 520), (360, 600), (310, 660), (300, 720), (265, 925), (195, 925), (175, 700), (115, 600), (55, 400)], (370, 520), "body", True, 2),
            Part("arm_lamp", [(730, 440), (800, 470), (830, 560), (880, 700), (945, 800), (965, 1000), (905, 1245), (800, 1245), (780, 1000), (790, 820), (810, 760), (760, 620), (720, 560)], (740, 470), "body", True, 2),
            Part("leg_l", [(330, 800), (470, 800), (450, 1000), (430, 1250), (390, 1425), (195, 1425), (215, 1300), (280, 1150), (300, 980)], (420, 820), "root", True, -1),
            Part("leg_r", [(560, 800), (720, 800), (745, 1000), (705, 1150), (795, 1305), (620, 1325), (600, 1150), (570, 1000)], (620, 820), "root", True, -1),
            Part("head", [(250, 80), (640, 80), (640, 240), (560, 330), (480, 370), (380, 350), (330, 250), (230, 240)], (460, 360), "body", True, 3),
        ]
        return mrig.Facing(src + "_S.jpg", parts, ground=(490, 1370), hip=(500, 800), scale=0.2, cell=CELL, cell_pivot=PIV, despill=True)
    parts = [
        Part("arm_sword", [(640, 430), (720, 480), (790, 580), (820, 360), (900, 180), (925, 260), (925, 600), (865, 700), (825, 925), (760, 925), (760, 720), (700, 640), (650, 560)], (650, 470), "body", True, 2),
        Part("arm_lamp", [(340, 460), (280, 560), (220, 640), (200, 700), (220, 1000), (150, 1185), (75, 1185), (45, 1000), (55, 800), (120, 690), (170, 580), (240, 480)], (320, 490), "body", True, 2),
        Part("leg_l", [(260, 1000), (420, 1000), (400, 1250), (390, 1410), (235, 1410), (250, 1200)], (350, 1020), "root", True, -1),
        Part("leg_r", [(520, 1000), (660, 1000), (735, 1150), (725, 1245), (555, 1255), (540, 1150)], (580, 1020), "root", True, -1),
        Part("head", [(330, 65), (705, 65), (705, 300), (560, 330), (420, 320), (320, 220)], (500, 320), "body", True, 3),
    ]
    return mrig.Facing(src + "_E.jpg", parts, ground=(460, 1330), hip=(470, 850), scale=0.2, cell=CELL, cell_pivot=PIV, despill=True)


def harpooner_facing(f, src="harpooner"):
    if f == "S":
        parts = [
            Part("harpoon", [(225, 115), (460, 55), (695, 25), (695, 95), (470, 172), (225, 218)], (180, 170), "arm_throw", False, 4),
            Part("harpoon_butt", [(20, 160), (128, 140), (128, 212), (20, 214)], (180, 170), "arm_throw", False, 4),
            Part("arm_throw", [(20, 214), (128, 212), (128, 115), (225, 115), (225, 218), (280, 260), (330, 280), (370, 380), (300, 430), (260, 440), (250, 835), (45, 835), (35, 250)], (330, 370), "body", True, 3),
            Part("arm_free", [(690, 460), (780, 520), (860, 640), (965, 700), (965, 805), (840, 805), (800, 700), (720, 620), (680, 560)], (710, 490), "body", True, 2),
            Part("leg_l", [(300, 1000), (460, 1000), (430, 1150), (410, 1285), (215, 1295), (225, 1230), (300, 1150)], (390, 1010), "root", True, -1),
            Part("leg_r", [(640, 1000), (760, 1000), (760, 1200), (845, 1435), (680, 1445), (670, 1250), (640, 1150)], (690, 1010), "root", True, -1),
            Part("head", [(440, 150), (620, 150), (630, 300), (560, 380), (480, 380), (430, 280)], (530, 380), "body", True, 2),
        ]
        fc = mrig.Facing(src + "_S.jpg", parts, ground=(530, 1400), hip=(520, 850), scale=0.2, cell=CELL, cell_pivot=PIV, despill=True)
        fc.pocket = ("harpoon", (450, 115))
        return fc
    parts = [
        Part("harpoon", [(765, 70), (965, 35), (965, 105), (830, 172), (765, 205)], (720, 170), "arm_throw", False, 4),
        Part("harpoon_butt", [(535, 175), (680, 128), (680, 232), (535, 245)], (720, 170), "arm_throw", False, 4),
        Part("arm_throw", [(610, 330), (670, 240), (680, 120), (765, 105), (790, 220), (945, 230), (955, 835), (780, 835), (780, 520), (720, 420), (640, 420)], (640, 380), "body", True, 3),
        Part("arm_free", [(290, 470), (220, 540), (140, 640), (25, 705), (25, 825), (155, 825), (200, 700), (260, 620), (300, 560)], (290, 500), "body", True, 2),
        Part("leg_l", [(200, 1080), (330, 1080), (300, 1250), (300, 1375), (145, 1375), (170, 1250)], (260, 1090), "root", True, -1),
        Part("leg_r", [(560, 1080), (700, 1080), (720, 1200), (765, 1285), (620, 1315), (590, 1200)], (620, 1090), "root", True, -1),
        Part("head", [(360, 205), (530, 205), (545, 330), (470, 362), (380, 342), (350, 280)], (450, 350), "body", True, 2),
    ]
    fc = mrig.Facing(src + "_E.jpg", parts, ground=(440, 1330), hip=(450, 850), scale=0.2, cell=CELL, cell_pivot=PIV, despill=True)
    fc.pocket = ("harpoon", (860, 110))
    return fc


def saltmaw_facing(f, src="saltmaw"):
    if f == "S":
        parts = [
            Part("lure", [(640, 240), (660, 120), (720, 75), (825, 75), (885, 150), (975, 215), (985, 425), (880, 445), (830, 300), (800, 140), (740, 122), (690, 180), (680, 270)], (660, 270), "body", False, 3),
            Part("jaw", [(520, 470), (640, 520), (800, 470), (825, 560), (785, 665), (680, 695), (570, 655), (520, 560)], (560, 455), "body", True, 2),
            Part("limb_r", [(740, 560), (860, 580), (1005, 760), (1005, 905), (760, 905), (730, 760), (720, 640)], (760, 600), "root", True, 1),
            Part("limb_l", [(380, 560), (520, 600), (560, 700), (725, 880), (725, 965), (365, 965), (355, 820), (330, 700)], (430, 600), "root", True, 1),
            Part("limb_back", [(15, 560), (300, 560), (320, 760), (200, 795), (15, 785)], (250, 580), "root", True, -1),
        ]
        fc = mrig.Facing(src + "_S.jpg", parts, ground=(560, 900), hip=(500, 550), scale=0.44, cell=CELL_BIG, cell_pivot=PIV_BIG, despill=True)
        fc.lure_tip = ("lure", (905, 255))
        return fc
    parts = [
        Part("lure", [(690, 250), (720, 120), (790, 55), (875, 65), (945, 130), (965, 335), (880, 375), (840, 250), (800, 120), (760, 110), (730, 180), (720, 260)], (710, 260), "body", False, 3),
        Part("limb_r", [(680, 560), (800, 600), (965, 760), (985, 885), (740, 885), (700, 720), (660, 620)], (700, 600), "root", True, 1),
        Part("limb_l", [(400, 640), (560, 620), (620, 760), (655, 965), (415, 965), (390, 800)], (480, 640), "root", True, 1),
        Part("limb_back", [(15, 560), (260, 560), (380, 700), (375, 835), (210, 835), (15, 765)], (240, 580), "root", True, -1),
    ]
    fc = mrig.Facing(src + "_E.jpg", parts, ground=(560, 900), hip=(500, 500), scale=0.44, cell=CELL_BIG, cell_pivot=PIV_BIG, despill=True)
    fc.lure_tip = ("lure", (890, 215))
    return fc


# --------------------------------------------------------------- actions

S_ = math.sin
TAU = 2 * math.pi
HIT = 6  # melee contact frame of every attack here


def crab_actions(f):
    A = {}
    if f == "S":
        ca, cb, la, lb = "claw_l", "claw_r", "legs_l", "legs_r"
        up_a, up_b = 1, -1  # S: + raises the image-left claw, - the image-right one
    else:
        ca, cb, la, lb = "claw_a", "claw_b", "legs_l", "legs_f"
        up_a, up_b = -1, -1  # E: both claws point up-right; - lifts them
    A["idle"] = cyc(12, lambda t: {"sy": 1 + 0.015 * S_(TAU * t), "body": 0.8 * S_(TAU * t), "dy": -0.8 * S_(TAU * t),
                                   ca: up_a * 3 * S_(TAU * t + 0.6), cb: up_b * 3 * S_(TAU * t + 1.4),
                                   la: 2 * S_(TAU * t + 0.3), lb: -2 * S_(TAU * t + 0.3)})

    def walk(t):
        w = S_(TAU * t * 2)  # quick scuttle: two leg beats per loop
        return {la: 9 * w, lb: 9 * w, "dy": -3 * abs(w) + 1, "body": 1.5 * S_(TAU * t), "rot": 1.2 * S_(TAU * t),
                ca: up_a * 4 * S_(TAU * t + 0.5), cb: up_b * 4 * S_(TAU * t + 2.0)}
    A["walk"] = cyc(12, walk)
    # Pincer strike: both claws rear up (f02-f04), lunge and snap shut on f06 (hit), recover.
    wind = dict(fwd(f, -6), **{ca: up_a * 26, cb: up_b * 24}, body=-4, sy=1.03, dy=-3, **{la: -4, lb: 4})
    strike = dict(fwd(f, 18), **{ca: -up_a * 16, cb: -up_b * 14}, body=6, sy=0.95, dy=3, **{la: 6, lb: -6})
    follow = dict(fwd(f, 14), **{ca: -up_a * 10, cb: -up_b * 9}, body=4, sy=0.97, dy=2)
    A["attack"] = keys(12, [(0, {}), (3, wind), (4, wind), (HIT, strike), (8, follow), (11, {})])
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -12), body=-6, dy=-3, **{ca: up_a * 14, cb: up_b * 14, la: -6, lb: 6})),
        (4, dict(fwd(f, -7), body=-2, **{ca: up_a * 5, cb: up_b * 5})),
        (7, {}),
    ])
    # Death: rears up, flips onto its back, legs and claws curl and twitch, then still.
    cx, cy = (500, 560) if f == "S" else (500, 470)
    d = keys(13, [
        (0, {}),
        (2, dict(fwd(f, -8), body=-8, dy=-6, **{ca: up_a * 22, cb: up_b * 22})),
        (4, dict(fwd(f, -10), rot=-60, dy=-14)),
        (6, dict(fwd(f, -12), rot=-150, dy=-6, sy=0.9)),
        (7, dict(fwd(f, -12), rot=-180, dy=8, sy=0.85, **{la: 14, lb: -14, ca: -up_a * 12, cb: -up_b * 12})),
        (9, dict(fwd(f, -12), rot=-180, dy=10, sy=0.84, **{la: 4, lb: -4, ca: -up_a * 4, cb: -up_b * 4})),
        (12, dict(fwd(f, -12), rot=-180, dy=10, sy=0.84, **{la: 10, lb: -10, ca: -up_a * 8, cb: -up_b * 8})),
    ])
    for p in d:
        p["rot_c"] = (cx, cy)
    A["death"] = d
    return A


def sailor_actions(f):
    A = {}
    sw = 1 if f == "S" else -1  # + raises the image-left sword arm in S; - raises the image-right one in E
    A["idle"] = cyc(12, lambda t: {"sy": 1 + 0.012 * S_(TAU * t), "body": 1.2 * S_(TAU * t), "head": 2.5 * S_(TAU * t + 0.9),
                                   "arm_sword": sw * 3 * S_(TAU * t + 0.4), "arm_lamp": -sw * 3 * S_(TAU * t + 1.2)})

    def walk(t):
        w = S_(TAU * t)
        return {"leg_l": 15 * w, "leg_r": -15 * w, "body": 2.5 * w, "rot": 1.5 * w, "dy": -4 * abs(w) + 1,
                "head": -3 * S_(TAU * t + 0.7), "arm_sword": sw * 7 * w, "arm_lamp": -sw * 8 * w}
    A["walk"] = cyc(12, walk)
    # Cutlass slash: raise the blade high and back (f03-f04), hack down across on f06 (hit), follow through.
    wind = dict(fwd(f, -5), arm_sword=sw * 38, arm_lamp=-sw * 8, body=-7, head=-6, leg_l=4, leg_r=-4, dy=-2)
    strike = dict(fwd(f, 16), arm_sword=-sw * 46, arm_lamp=sw * 6, body=9, head=6, leg_l=-6, leg_r=6, dy=2)
    follow = dict(fwd(f, 13), arm_sword=-sw * 40, arm_lamp=sw * 4, body=7, head=4)
    A["attack"] = keys(12, [(0, {}), (3, wind), (4, dict(wind, arm_sword=sw * 42)), (HIT, strike), (8, follow), (11, {})])
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -12), body=-9, head=-12, arm_sword=sw * 14, arm_lamp=-sw * 14, dy=-2)),
        (4, dict(fwd(f, -7), body=-4, head=-5)),
        (7, {}),
    ])
    fall = -1 if f == "S" else 1
    A["death"] = keys(13, [
        (0, {}),
        (2, dict(body=-6, head=-16, dy=-3, arm_sword=sw * 20, arm_lamp=-sw * 20)),
        (5, dict(dy=20, sy=0.92, body=8 * -fall, rot=12 * fall, leg_l=14, leg_r=-14, arm_sword=-sw * 10, arm_lamp=sw * 10, head=10)),
        (8, dict(rot=60 * fall, dy=46, sy=0.9, body=8 * -fall, leg_l=16, leg_r=-16, arm_sword=-sw * 18, arm_lamp=sw * 18, head=16)),
        (10, dict(rot=80 * fall, dy=56, sy=0.88, body=6 * -fall, leg_l=18, leg_r=-18, arm_sword=-sw * 22, arm_lamp=sw * 22, head=18)),
        (12, dict(rot=82 * fall, dy=57, sy=0.88, body=6 * -fall, leg_l=18, leg_r=-18, arm_sword=-sw * 23, arm_lamp=sw * 23, head=19)),
    ])
    return A


HARPOON_RELEASE = 7


def harpooner_actions(f):
    A = {}
    fr = -1 if f == "S" else 1  # free arm raise sign (image-right in S, image-left in E)
    A["idle"] = cyc(12, lambda t: {"sy": 1 + 0.012 * S_(TAU * t), "body": 1.2 * S_(TAU * t), "head": 2.5 * S_(TAU * t + 0.9),
                                   "arm_throw": 2.5 * S_(TAU * t + 0.4), "arm_free": fr * 3 * S_(TAU * t + 1.2)})

    def walk(t):
        w = S_(TAU * t)
        return {"leg_l": 14 * w, "leg_r": -14 * w, "body": 2.5 * w, "rot": 1.5 * w, "dy": -4 * abs(w) + 1,
                "head": -3 * S_(TAU * t + 0.7), "arm_throw": 3 * w, "arm_free": fr * 8 * w}
    A["walk"] = cyc(12, walk)
    # Throw: cock the harpoon back, trembling (f01-f06), hurl it on f07 (release: the held harpoon is gone
    # f07-f10 and the projectile takes over), follow through, a fresh harpoon is back in hand on f11.
    if f == "S":
        arm = [0, -6, -14, -20, -24, -26, -25, 58, 66, 44, 18, 0]
    else:
        arm = [0, -6, -14, -20, -24, -26, -25, 50, 58, 38, 15, 0]
    body = [0, -2, -4, -6, -7, -7, -6, 9, 8, 5, 2, 0]
    shake = [0, 0, 0, 0, 1, -1, 1, 0, 0, 0, 0, 0]
    att = []
    for i in range(12):
        p = {"arm_throw": float(arm[i] + 1.5 * shake[i]), "body": float(body[i]), "head": -0.5 * body[i] + 1.5 * shake[i],
             "arm_free": fr * (-0.5 * arm[i] * 0.4), "leg_l": 0.4 * body[i], "leg_r": -0.4 * body[i]}
        p.update(fwd(f, 0.8 * body[i]))
        if HARPOON_RELEASE <= i <= 10:
            p["harpoon.hide"] = True
            p["harpoon_butt.hide"] = True
        att.append(p)
    A["attack"] = att
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -12), body=-9, head=-12, arm_throw=-10, arm_free=fr * 14, dy=-2)),
        (4, dict(fwd(f, -7), body=-4, head=-5)),
        (7, {}),
    ])
    fall = -1 if f == "S" else 1
    A["death"] = keys(13, [
        (0, {}),
        (2, dict(body=-6, head=-16, dy=-3, arm_throw=-12, arm_free=fr * 20)),
        (5, dict(dy=20, sy=0.92, body=8 * -fall, rot=12 * fall, leg_l=14, leg_r=-14, arm_throw=10, arm_free=-fr * 10, head=10)),
        (8, dict(rot=60 * fall, dy=46, sy=0.9, body=8 * -fall, leg_l=16, leg_r=-16, arm_throw=16, arm_free=-fr * 18, head=16)),
        (10, dict(rot=80 * fall, dy=56, sy=0.88, body=6 * -fall, leg_l=18, leg_r=-18, arm_throw=20, arm_free=-fr * 22, head=18)),
        (12, dict(rot=82 * fall, dy=57, sy=0.88, body=6 * -fall, leg_l=18, leg_r=-18, arm_throw=21, arm_free=-fr * 23, head=19)),
    ])
    return A


LURE_FLARE = 7


def saltmaw_actions(f):
    A = {}
    A["idle"] = cyc(12, lambda t: {"sy": 1 + 0.012 * S_(TAU * t), "body": 1.0 * S_(TAU * t), "dy": -1.0 * S_(TAU * t),
                                   "lure": 4 * S_(TAU * t + 0.8), "jaw": 2.0 + 2.0 * S_(TAU * t + 0.3),
                                   "limb_l": 1.2 * S_(TAU * t + 0.5), "limb_r": -1.2 * S_(TAU * t + 0.5), "limb_back": 1.0 * S_(TAU * t)})

    def walk(t):
        w = S_(TAU * t)
        return {"limb_l": 10 * w, "limb_r": -10 * w, "limb_back": -7 * w, "body": 2.0 * w, "rot": 1.5 * w,
                "dy": -5 * abs(w) + 1.5, "lure": -5 * S_(TAU * t + 0.8), "jaw": 3 + 2 * S_(TAU * t * 2)}
    A["walk"] = cyc(12, walk)
    # Bite: rear back with the maw gaping (f03-f04), lunge and snap the jaws shut on f06 (hit), recover.
    wind = dict(fwd(f, -8), body=-7, jaw=16, lure=-8, sy=1.03, dy=-4, limb_l=-4, limb_r=4)
    strike = dict(fwd(f, 22), body=9, jaw=-3, lure=10, sy=0.95, dy=5, limb_l=8, limb_r=-8, limb_back=-5)
    follow = dict(fwd(f, 16), body=6, jaw=2, lure=6, sy=0.97, dy=3)
    A["attack"] = keys(12, [(0, {}), (3, wind), (4, dict(wind, jaw=18)), (HIT, strike), (8, follow), (11, {})])
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -14), body=-8, jaw=10, lure=-14, dy=-3, limb_l=-6, limb_r=6)),
        (4, dict(fwd(f, -8), body=-3, jaw=5, lure=-5)),
        (7, {}),
    ])
    fall = -1 if f == "S" else 1
    A["death"] = keys(13, [
        (0, {}),
        (2, dict(body=-7, jaw=18, lure=-16, dy=-5)),
        (5, dict(rot=20 * fall, body=6 * fall, dy=12, jaw=14, lure=10, limb_l=10, limb_r=-10)),
        (8, dict(rot=60 * fall, body=8 * fall, dy=40, jaw=8, lure=24, limb_l=16, limb_r=-16, sy=0.95)),
        (10, dict(rot=80 * fall, body=6 * fall, dy=50, jaw=6, lure=30, limb_l=18, limb_r=-18, sy=0.9)),
        (12, dict(rot=82 * fall, body=6 * fall, dy=52, jaw=6, lure=31, limb_l=18, limb_r=-18, sy=0.9)),
    ])
    # Signature "Lantern Lure": crouch (f00-f02), lift the lure high (f03-f06), FLARE on f07 (the pull fires;
    # lure_point is the lure tip on f07), hold it blazing while the hero slides in (f07-f10), settle (f10-f13).
    shake = [0, 0, 0, 0, 0, 0, 0, 1, -1, 1, 0, 0, 0, 0]
    sm = keys(14, [
        (0, {}),
        (2, dict(sy=0.93, dy=6, body=4, lure=6, jaw=4, limb_l=4, limb_r=-4)),
        (6, dict(fwd(f, -4), sy=1.04, dy=-6, body=-6, lure=-26, jaw=10, limb_l=-3, limb_r=3)),
        (7, dict(fwd(f, -6), sy=1.05, dy=-8, body=-8, lure=-30, jaw=14, limb_l=-4, limb_r=4)),
        (10, dict(fwd(f, -5), sy=1.03, dy=-6, body=-7, lure=-26, jaw=12, limb_l=-3, limb_r=3)),
        (13, {}),
    ])
    for i, p in enumerate(sm):
        p["lure"] = p.get("lure", 0.0) + 2.0 * shake[i]
        p["body"] = p.get("body", 0.0) + 0.8 * shake[i]
    A["summon"] = sm
    return A


# ----------------------------------------------------------------- glows

def teal_emissive(im):
    """Weight map of the glowing teal paint (the lure, the lantern glass, the eyes) in a frame."""
    a = im[..., 3] > 0
    r, g, b = [im[..., i].astype(np.float32) for i in range(3)]
    em = a & (g > 170) & (b > 130) & (g - r > 90)
    return em.astype(np.float32) * np.clip((g - r - 90) / 80.0, 0.35, 1.0)


# Lure glow for the signature: builds up f03-f06, flares on f07, holds f07-f10, fades by f12.
SUMMON_GLOW = [0.0, 0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.5, 1.2, 1.05, 0.9, 0.45, 0.15, 0.0]


def summon_glow(im, i, big):
    k = SUMMON_GLOW[i]
    em = teal_emissive(im) * k
    out = monster_kit.glow_from_mask(im, em, big, TEAL_GLOW, core=(5, 1.8), halo=(20, 1.5), aura=(16, 0.0))
    if k == 0:
        out[:] = 0
    return out


def abyss_emissive(im):
    """Weight map of the glowing abyssal cyan paint (spots, veins, runes, eyes, lure) in a star-5 frame."""
    a = im[..., 3] > 0
    r, g, b = [im[..., i].astype(np.float32) for i in range(3)]
    em = a & (b > 190) & (g > 170) & (b - r > 90)
    return em.astype(np.float32) * np.clip((b - r - 90) / 90.0, 0.35, 1.0)


def abyss_glow(im, big):
    return monster_kit.glow_from_mask(im, abyss_emissive(im), big, CYAN_GLOW, core=(4, 1.2), halo=(13, 0.8), aura=(16, 0.06))


MONSTERS = {
    "reef_crab": {"name": "Reef Crab", "rig": crab_facing, "actions": crab_actions, "cell": CELL, "pivot": PIV,
                  "role": "room A melee tank, low and wide (pincer snap lands on attack f06)"},
    "drowned_sailor": {"name": "Drowned Sailor", "rig": sailor_facing, "actions": sailor_actions, "cell": CELL, "pivot": PIV,
                       "role": "room A melee: cutlass slash lands on attack f06; carries a teal lantern"},
    "drowned_harpooner": {"name": "Drowned Harpooner", "rig": harpooner_facing, "actions": harpooner_actions, "cell": CELL, "pivot": PIV,
                          "release": HARPOON_RELEASE,
                          "role": "room A ranged: throws a harpoon, released on attack f07 (the held harpoon is hidden f07-f10)"},
    "old_saltmaw": {"name": "Old Saltmaw", "rig": saltmaw_facing, "actions": saltmaw_actions, "cell": CELL_BIG, "pivot": PIV_BIG,
                    "action_glow": {"summon": summon_glow},
                    "points": {"lure_point": ("summon", LURE_FLARE, "lure_tip")},
                    "signature": {"action": "summon", "name": "Lantern Lure", "frames": 14,
                                  "crouch": [0, 2], "lift": [3, 6], "flare": LURE_FLARE, "pull": [7, 10], "settle": [10, 13],
                                  "glow": "summon/summon_{S,E}_fNN_glow.png: additive lure glow, builds f03-f06, flares on f07, holds to f10, fades by f12"}},
}

# Star-5 forms (painted as edits of the base, so they reuse the base part cuts).
MONSTERS["abyssal_saltmaw"] = dict(MONSTERS["old_saltmaw"], name="Abyssal Saltmaw", rig=lambda f: saltmaw_facing(f, "abyssal_saltmaw"),
                                   star5=True, glow=True, glow_fn=abyss_glow, base_of="old_saltmaw")
MONSTERS["abyssal_saltmaw"].pop("action_glow")
MONSTERS["abyssal_reef_crab"] = dict(MONSTERS["reef_crab"], name="Abyssal Reef Crab", rig=lambda f: crab_facing(f, "abyssal_crab"),
                                     star5=True, glow=True, glow_fn=abyss_glow, base_of="reef_crab")
MONSTERS["abyssal_drowned_sailor"] = dict(MONSTERS["drowned_sailor"], name="Abyssal Drowned Sailor", rig=lambda f: sailor_facing(f, "abyssal_sailor"),
                                          star5=True, glow=True, glow_fn=abyss_glow, base_of="drowned_sailor")
MONSTERS["abyssal_drowned_harpooner"] = dict(MONSTERS["drowned_harpooner"], name="Abyssal Drowned Harpooner",
                                             rig=lambda f: harpooner_facing(f, "abyssal_harpooner"),
                                             star5=True, glow=True, glow_fn=abyss_glow, base_of="drowned_harpooner")
BASE = ("reef_crab", "drowned_sailor", "drowned_harpooner", "old_saltmaw")
STAR5 = ("abyssal_saltmaw", "abyssal_reef_crab", "abyssal_drowned_sailor", "abyssal_drowned_harpooner")


def build(mid, check=False):
    gkit.use("saltmaw_grotto")
    return monster_kit.build(mid, MONSTERS[mid], check)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    for mid in (args or list(BASE)):
        build(mid, check="--check" in sys.argv)
