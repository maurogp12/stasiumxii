"""Heart of the Blight monsters: Blight Hound, Blight Horror, The Rotting Elder (+ the star-5 Crystal set).

Rigs are part cuts on the chosen paintings in blight_src/<id>_{S,E}.jpg (flat green; the blight's violet is the
opposite hue, so it keys cleanly); the actions are posed here and rendered by the shared monster_kit / mrig.
S = front, facing screen down-right; E = back, facing screen up-right. W and N are game-side mirrors of E and S.

Cells: 512x360, pivot (256,329) for the Hound and the Horror (as the heroes); the Rotting Elder and the star-5
Crystal Colossus are 1.5x the hero cell, 768x540, pivot (384,494). 17.144 fps (as the Abbey).

Angle sign used below: + = clockwise on screen (y down). A point left of a pivot goes UP under +, a point right
of a pivot goes DOWN, a point above goes RIGHT, a point below goes LEFT.

  python3 blight_monsters.py [monster ...] [--check]
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

gkit.use("heart_of_the_blight")
VIOLET = (0.8, 0.38, 1.0)
S_ = math.sin
TAU = 2 * math.pi
HIT = 6  # melee contact frame (the Hound's bite, the Elder's staff sweep, the Colossus's spear thrust)


# ------------------------------------------------------------------ rigs

def hound_facing(f, src="hound"):
    if f == "S":
        parts = [
            Part("tail", [(50, 220), (300, 170), (335, 200), (330, 330), (250, 400), (60, 455)], (320, 290), "body", True, -2),
            Part("hind_far", [(430, 410), (520, 410), (530, 495), (440, 495)], (470, 415), "body", True, -1),
            Part("front_far", [(740, 440), (800, 440), (895, 560), (880, 595), (800, 590), (760, 520)], (760, 450), "body", True, 1),
            Part("hind_near", [(205, 380), (300, 370), (320, 430), (315, 545), (195, 545), (210, 460)], (265, 380), "body", True, 1),
            Part("head", [(730, 220), (890, 230), (905, 360), (880, 480), (800, 485), (740, 420), (720, 330)], (745, 360), "body", True, 2),
            Part("front_near", [(580, 430), (680, 420), (700, 560), (730, 650), (600, 665), (590, 560)], (620, 430), "body", True, 3),
        ]
        return mrig.Facing(src + "_S.jpg", parts, ground=(540, 600), hip=(470, 300), scale=0.27, cell=CELL, cell_pivot=PIV)
    parts = [
        Part("tail", [(40, 550), (60, 420), (200, 330), (330, 290), (380, 350), (300, 420), (170, 470)], (340, 330), "body", True, -2),
        Part("hind_far", [(235, 420), (320, 410), (345, 570), (235, 570)], (290, 420), "body", True, -1),
        Part("front_far", [(545, 400), (620, 400), (640, 495), (550, 495)], (580, 405), "body", True, -1),
        Part("front_near", [(690, 330), (770, 320), (830, 540), (710, 545)], (730, 340), "body", True, 1),
        Part("hind_near", [(420, 470), (520, 460), (565, 640), (500, 670), (430, 650)], (470, 470), "body", True, 2),
        Part("head", [(660, 20), (830, 25), (830, 190), (740, 230), (650, 170)], (720, 200), "body", True, 2),
    ]
    return mrig.Facing(src + "_E.jpg", parts, ground=(530, 600), hip=(500, 300), scale=0.27, cell=CELL, cell_pivot=PIV)


def horror_facing(f, src="horror"):
    if f == "S":
        parts = [
            Part("leg_l", [(320, 1000), (470, 980), (450, 1150), (430, 1300), (520, 1460), (500, 1530), (160, 1530), (230, 1400), (300, 1250), (300, 1100)], (400, 1000), "root", True, -1),
            Part("leg_r", [(540, 1000), (720, 960), (720, 1080), (680, 1150), (700, 1220), (810, 1300), (800, 1345), (560, 1335), (600, 1200), (560, 1100)], (620, 1000), "root", True, -1),
            Part("arm_l", [(140, 500), (250, 430), (330, 470), (330, 600), (250, 780), (240, 960), (270, 1115), (55, 1115), (55, 800), (130, 620)], (280, 470), "body", True, 2),
            Part("arm_r", [(670, 500), (760, 500), (860, 640), (940, 760), (990, 900), (990, 1115), (800, 1115), (820, 940), (760, 800), (700, 660)], (700, 540), "body", True, 2),
            Part("head", [(300, 15), (700, 15), (690, 180), (620, 330), (520, 345), (430, 320), (390, 200)], (510, 330), "body", True, 3),
        ]
        fc = mrig.Facing(src + "_S.jpg", parts, ground=(500, 1420), hip=(510, 980), scale=0.2, cell=CELL, cell_pivot=PIV)
        fc.pocket = ("head", (525, 255))
        return fc
    parts = [
        Part("leg_l", [(300, 920), (450, 900), (420, 1100), (380, 1250), (440, 1310), (400, 1390), (120, 1390), (220, 1250), (270, 1100)], (380, 930), "root", True, -1),
        Part("leg_r", [(540, 900), (680, 900), (700, 1050), (700, 1250), (830, 1380), (885, 1445), (780, 1515), (510, 1465), (600, 1300), (580, 1150)], (610, 920), "root", True, -1),
        Part("arm_l", [(170, 500), (280, 450), (330, 520), (300, 620), (230, 750), (220, 1000), (55, 1000), (55, 700), (120, 600)], (290, 490), "body", True, 2),
        Part("arm_r", [(700, 480), (760, 500), (830, 600), (955, 800), (960, 1100), (800, 1100), (800, 880), (730, 700), (680, 560)], (700, 500), "body", True, 2),
        Part("head", [(330, 15), (735, 15), (720, 170), (620, 260), (450, 260), (400, 180)], (520, 260), "body", True, 3),
    ]
    fc = mrig.Facing(src + "_E.jpg", parts, ground=(500, 1430), hip=(500, 900), scale=0.2, cell=CELL, cell_pivot=PIV)
    fc.pocket = ("head", (585, 140))
    return fc


def elder_facing(f, src="elder"):
    """The Rotting Elder (1024x1024 paintings): the staff arm holds the staff; the root-claw arm hangs on the other side."""
    if f == "S":
        parts = [
            Part("arm_r", [(700, 380), (840, 340), (950, 360), (950, 470), (840, 500), (740, 520), (700, 480)], (710, 430), "body", True, 3),
            Part("staff", [(800, 15), (995, 15), (995, 340), (965, 500), (975, 965), (760, 965), (820, 700), (830, 500), (830, 340)], (885, 420), "arm_r", False, 2),
            Part("arm_l", [(65, 560), (120, 440), (200, 400), (300, 380), (340, 430), (330, 520), (310, 700), (300, 820), (170, 820), (65, 700)], (300, 420), "body", True, 2),
            Part("head", [(200, 15), (790, 15), (790, 160), (620, 190), (600, 260), (520, 290), (440, 260), (400, 190), (200, 150)], (510, 280), "body", True, 1),
            Part("leg_l", [(90, 830), (300, 740), (470, 710), (500, 800), (540, 1010), (80, 1010)], (370, 730), "root", True, -1),
            Part("leg_r", [(500, 720), (680, 680), (760, 780), (800, 950), (780, 1010), (500, 1010), (520, 850)], (610, 700), "root", True, -1),
        ]
        fc = mrig.Facing(src + "_S.jpg", parts, ground=(500, 975), hip=(500, 650), scale=0.455, cell=CELL_BIG, cell_pivot=PIV_BIG)
        fc.staff_foot = ("staff", (870, 955))
        return fc
    parts = [
        Part("arm_r", [(680, 400), (840, 360), (945, 370), (945, 450), (840, 480), (740, 500), (690, 470)], (700, 430), "body", True, 3),
        Part("staff", [(830, 15), (995, 15), (995, 330), (965, 500), (965, 945), (800, 945), (840, 700), (850, 500), (830, 350)], (890, 400), "arm_r", False, 2),
        Part("arm_l", [(45, 560), (110, 420), (200, 350), (290, 340), (300, 420), (260, 520), (250, 770), (45, 770)], (290, 380), "body", True, 2),
        Part("head", [(240, 15), (800, 15), (800, 150), (600, 200), (560, 260), (470, 260), (420, 200), (240, 150)], (510, 260), "body", True, 1),
        Part("leg_l", [(100, 800), (300, 720), (470, 720), (480, 1005), (100, 1005)], (370, 730), "root", True, -1),
        Part("leg_r", [(490, 720), (700, 700), (780, 800), (865, 985), (490, 1005)], (600, 720), "root", True, -1),
    ]
    fc = mrig.Facing(src + "_E.jpg", parts, ground=(500, 975), hip=(480, 650), scale=0.455, cell=CELL_BIG, cell_pivot=PIV_BIG)
    fc.staff_foot = ("staff", (880, 935))
    return fc


def colossus_facing(f, src="colossus"):
    """The star-5 Crystal Colossus (Mauro's pick B, 1024x683 paintings): its own rig. The spear arm is on the screen-left
    with the long crystal-tipped spear-staff in its fist; the other arm ends in a huge crystal fist."""
    if f == "S":
        parts = [
            Part("arm_l", [(200, 280), (330, 250), (400, 250), (410, 320), (340, 400), (220, 410), (195, 340)], (390, 280), "body", True, 3),
            Part("spear", [(60, 15), (240, 60), (260, 180), (240, 290), (330, 390), (400, 520), (400, 600), (330, 665), (300, 620), (330, 560),
                           (280, 440), (200, 290), (140, 220), (60, 120)], (265, 345), "arm_l", False, 2),
            Part("arm_r", [(720, 240), (820, 250), (910, 330), (915, 525), (800, 528), (760, 420), (700, 330)], (720, 290), "body", True, 2),
            Part("head", [(420, 10), (720, 10), (720, 110), (640, 150), (560, 170), (470, 150), (420, 90)], (560, 160), "body", True, 1),
            Part("leg_l", [(400, 450), (560, 440), (570, 560), (580, 672), (320, 672), (390, 560)], (480, 460), "root", True, -1),
            Part("leg_r", [(600, 440), (740, 430), (780, 520), (835, 610), (780, 645), (590, 645)], (670, 450), "root", True, -1),
        ]
        fc = mrig.Facing(src + "_S.jpg", parts, ground=(590, 650), hip=(570, 430), scale=0.70, cell=CELL_BIG, cell_pivot=PIV_BIG)
        fc.staff_foot = ("spear", (345, 650))
        return fc
    parts = [
        Part("arm_l", [(200, 290), (330, 260), (380, 270), (380, 350), (300, 400), (210, 390)], (370, 290), "body", True, 3),
        Part("spear", [(75, 2), (250, 80), (250, 200), (240, 280), (320, 400), (370, 560), (370, 600), (330, 612), (300, 560), (270, 420),
                       (200, 300), (140, 240), (75, 120)], (245, 340), "arm_l", False, 2),
        Part("arm_r", [(700, 280), (800, 260), (870, 330), (898, 520), (770, 532), (720, 400)], (720, 300), "body", True, 2),
        Part("head", [(440, 2), (700, 2), (700, 100), (620, 140), (540, 140), (450, 100)], (560, 140), "body", True, 1),
        Part("leg_l", [(370, 440), (520, 430), (540, 560), (545, 668), (330, 662), (360, 560)], (450, 450), "root", True, -1),
        Part("leg_r", [(600, 440), (720, 430), (760, 520), (825, 620), (760, 662), (590, 662)], (660, 450), "root", True, -1),
    ]
    fc = mrig.Facing(src + "_E.jpg", parts, ground=(580, 650), hip=(560, 430), scale=0.70, cell=CELL_BIG, cell_pivot=PIV_BIG)
    fc.staff_foot = ("spear", (345, 605))
    return fc


def crystal_rig(base_fn, src):
    """The star-5 crystal pack: edits of the base paintings (same pose and outline), so they reuse the base part cuts."""
    return lambda f: base_fn(f, src)


# --------------------------------------------------------------- actions

def hound_actions(f):
    A = {}
    hb = -1 if f == "S" else 1  # head raise sign (S: the head is right of its pivot, - lifts it)
    A["idle"] = cyc(12, lambda t: {"sy": 1 + 0.02 * S_(TAU * t), "body": 1.2 * S_(TAU * t), "head": 3 * S_(TAU * t + 1.0) * hb,
                                   "tail": 5 * S_(TAU * t - 0.6), "dy": -0.8 * S_(TAU * t)})
    legs = ("front_near", "hind_far", "front_far", "hind_near")

    def walk(t):
        # a fast loping trot: diagonal pairs swing together, the spine bounces twice a loop, the head bobs, the tail streams
        w = S_(TAU * t)
        p = {"dy": -4.0 * abs(w) + 1.0, "body": 2.5 * w, "head": 4 * S_(TAU * t * 2 + 0.5) * hb, "tail": 9 * S_(TAU * t - 1.0),
             "sx": 1 + 0.02 * S_(TAU * t * 2)}
        sw = 26
        p[legs[0]] = -sw * w
        p[legs[1]] = -sw * w
        p[legs[2]] = sw * w
        p[legs[3]] = sw * w
        return p
    A["walk"] = cyc(12, walk)
    # Pounce-bite: crouch and gather (f02-f04), spring forward and bite on f06 (hit), recover.
    gather = dict(fwd(f, -8), body=-6, head=-10 * hb, front_near=14, front_far=14, hind_near=-8, hind_far=-8, tail=-10, sy=0.94, dy=3)
    lunge = dict(fwd(f, 26), body=8, head=18 * hb, front_near=-30, front_far=-26, hind_near=14, hind_far=14, tail=14, sy=1.02, dy=-4)
    A["attack"] = keys(12, [(0, {}), (3, gather), (4, dict(gather, sy=0.92)), (HIT, lunge), (8, dict(fwd(f, 18), body=5, head=10 * hb,
                                                                                                          front_near=-16, front_far=-12, tail=6)), (11, {})])
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -14), body=-9, head=-18 * hb, dy=-3, tail=-16, front_near=16, front_far=16)),
        (4, dict(fwd(f, -9), body=-4, head=-6 * hb, tail=-6)),
        (7, {}),
    ])
    # Death: a yelp and rear back, then the legs give way: it slumps flat onto its belly and side (a squash, not a screen
    # rotation, so it stays a low body on the floor), the legs splay out, the head drops, the tail goes limp.
    d = keys(13, [
        (0, {}),
        (2, dict(fwd(f, -8), body=-10, head=-20 * hb, dy=-6, tail=-16)),
        (5, dict(fwd(f, -10), rot=6, dy=6, sy=0.86, head=6 * hb, front_near=-14, front_far=12, hind_near=-10, hind_far=10)),
        (8, dict(fwd(f, -12), rot=10, dy=14, sy=0.68, sx=1.06, head=16 * hb, front_near=-34, front_far=30, hind_near=-28, hind_far=26, tail=18)),
        (10, dict(fwd(f, -12), rot=12, dy=16, sy=0.6, sx=1.08, head=20 * hb, front_near=-40, front_far=34, hind_near=-32, hind_far=30, tail=22)),
        (12, dict(fwd(f, -12), rot=12, dy=16, sy=0.59, sx=1.08, head=21 * hb, front_near=-41, front_far=35, hind_near=-33, hind_far=31, tail=23)),
    ])
    A["death"] = d
    return A


SPORE_RELEASE = 7


def horror_actions(f):
    A = {}
    # signs: arm_l (hand below-left of the shoulder) + swings it up/out, arm_r (hand below-right) - swings it up/out
    A["idle"] = cyc(12, lambda t: {"sy": 1 + 0.012 * S_(TAU * t), "body": 1.4 * S_(TAU * t), "head": 2.5 * S_(TAU * t + 1.1),
                                   "arm_l": 3.0 * S_(TAU * t + 0.4), "arm_r": -3.0 * S_(TAU * t + 1.4), "dy": -0.8 * S_(TAU * t)})

    def walk(t):
        w = S_(TAU * t)
        # a gaunt stalk: long stiff strides, the body tips over each step, the long arms swing late and loose
        return {"leg_l": 14 * w, "leg_r": -14 * w, "body": 2.5 * w, "rot": 1.5 * w, "dy": -4 * abs(w) + 1,
                "head": -3 * S_(TAU * t + 0.8), "arm_l": 7 * S_(TAU * t + 0.6), "arm_r": 7 * S_(TAU * t + 0.6)}
    A["walk"] = cyc(12, walk)
    # Spore bolt: it rears back, arms spreading wide, the glowing face swelling (f01-f06, trembling), then snaps the head and
    # body forward and spits the spore bolt from its face on f07 (release), follows through, settles.
    rear = [0, -3, -6, -9, -11, -12, -12, 9, 11, 6, 2, 0]
    arms = [0, 6, 12, 18, 22, 24, 24, -10, -12, -6, -2, 0]
    shake = [0, 0, 0, 0, 1, -1, 1, 0, 0, 0, 0, 0]
    att = []
    for i in range(12):
        p = {"body": float(rear[i]), "head": float(1.6 * rear[i] + 2.0 * shake[i]), "arm_l": float(arms[i]), "arm_r": float(-arms[i]),
             "sy": 1 + 0.004 * -rear[i], "leg_l": 0.4 * rear[i], "leg_r": -0.4 * rear[i]}
        p.update(fwd(f, 0.8 * rear[i]))
        att.append(p)
    A["attack"] = att
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -12), body=-8, head=-14, arm_l=12, arm_r=-12, dy=-2)),
        (4, dict(fwd(f, -7), body=-3, head=-5)),
        (7, {}),
    ])
    fall = -1 if f == "S" else 1
    A["death"] = keys(13, [
        (0, {}),
        (2, dict(body=-6, head=-16, dy=-3, arm_l=20, arm_r=-20)),
        (5, dict(dy=20, sy=0.92, body=8 * -fall, rot=12 * fall, leg_l=14, leg_r=-14, arm_l=-8, arm_r=8, head=12)),
        (8, dict(rot=60 * fall, dy=46, sy=0.9, body=8 * -fall, leg_l=16, leg_r=-16, arm_l=-16, arm_r=16, head=18)),
        (10, dict(rot=80 * fall, dy=56, sy=0.88, body=6 * -fall, leg_l=18, leg_r=-18, arm_l=-20, arm_r=20, head=20)),
        (12, dict(rot=82 * fall, dy=57, sy=0.88, body=6 * -fall, leg_l=18, leg_r=-18, arm_l=-21, arm_r=21, head=21)),
    ])
    return A


WALL_FIRE = 7


def elder_actions(f):
    A = {}
    # signs: arm_r (staff hand right of the shoulder) - raises it; arm_l (claw below-left of the shoulder) + swings it up and out
    def idle(t):
        w = S_(TAU * t)
        return {"sy": 1 + 0.01 * w, "body": 1.0 * w, "head": 1.8 * S_(TAU * t + 1.0), "arm_l": 2.5 * S_(TAU * t + 0.5),
                "arm_r": -1.2 * S_(TAU * t + 1.3), "leg_l": 0.8 * S_(TAU * t + 2.0), "leg_r": -0.8 * S_(TAU * t + 2.0), "dy": -1.0 * w}
    A["idle"] = cyc(12, idle)

    def walk(t):
        w = S_(TAU * t)
        # a ponderous lumber: the root legs drag forward in turn, the whole trunk rolls side to side, the staff plants and swings
        return {"leg_l": 7 * w, "leg_r": -7 * w, "body": 2.5 * w, "rot": 1.8 * w, "dy": -3.5 * abs(w) + 1, "sx": 1 + 0.01 * w,
                "head": -2 * S_(TAU * t + 0.7), "arm_l": 5 * S_(TAU * t + 0.6), "arm_r": -3 * S_(TAU * t + 0.2)}
    A["walk"] = cyc(12, walk)
    # Root Claw (range 1): the huge root-claw arm draws up and back (f02-f04), then rakes down and across on f06 (hit).
    wind = dict(fwd(f, -5), arm_l=34, arm_r=-4, body=-5, head=-5, dy=-3, leg_l=-3)
    strike = dict(fwd(f, 16), arm_l=-26, arm_r=6, body=7, head=6, dy=2, leg_l=4)
    A["attack"] = keys(12, [(0, {}), (3, wind), (4, dict(wind, arm_l=38)), (HIT, strike), (8, dict(strike, arm_l=-20, **fwd(f, 12))), (11, {})])
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -10), body=-6, head=-10, arm_l=12, arm_r=-8, dy=-3)),
        (4, dict(fwd(f, -6), body=-3, head=-4)),
        (7, {}),
    ])
    fall = -1 if f == "S" else 1
    A["death"] = keys(13, [
        (0, {}),
        (2, dict(body=-5, head=-10, dy=-4, arm_l=18, arm_r=-14)),
        (5, dict(rot=14 * fall, body=5 * fall, dy=10, sy=0.95, arm_l=-6, arm_r=10, head=8, leg_l=6, leg_r=-6)),
        (8, dict(rot=40 * fall, body=7 * fall, dy=30, sy=0.9, arm_l=-14, arm_r=18, head=14, leg_l=10, leg_r=-10)),
        (10, dict(rot=56 * fall, body=6 * fall, dy=40, sy=0.86, arm_l=-18, arm_r=22, head=16, leg_l=12, leg_r=-12)),
        (12, dict(rot=58 * fall, body=6 * fall, dy=41, sy=0.86, arm_l=-19, arm_r=23, head=16, leg_l=12, leg_r=-12)),
    ])
    # Signature "Root Wall": he lifts the staff (f00-f02) while the crystal heart dims; staff high, the heart flares violet and the
    # roots writhe at his feet (f03-f06); on f07 he drives the staff down into the floor and the wall fires (staff_point = the
    # staff foot on f07, where the root_cracks start); a shockwave ripples through him (f08-f10); he settles (f11-f13).
    shake = [0, 0, 0, 0, 0, 0, 0, 1.5, -1.2, 1.0, -0.5, 0, 0, 0]
    sm = keys(14, [
        (0, {}),
        (2, dict(arm_r=-22, body=-3, head=-4, dy=-2, arm_l=6)),
        (5, dict(arm_r=-34, body=-6, head=-8, dy=-6, arm_l=14, sy=1.02)),
        (6, dict(arm_r=-36, body=-7, head=-9, dy=-7, arm_l=16, sy=1.02)),
        (7, dict(fwd(f, 6), arm_r=10, body=6, head=6, dy=4, arm_l=-8, sy=0.96)),
        (10, dict(fwd(f, 4), arm_r=8, body=4, head=4, dy=2, arm_l=-6, sy=0.98)),
        (13, {}),
    ])
    for i, p in enumerate(sm):
        writhe = 1.0 if 3 <= i <= 9 else 0.0
        p["leg_l"] = p.get("leg_l", 0.0) + writhe * 3.0 * S_(i * 2.1)
        p["leg_r"] = p.get("leg_r", 0.0) - writhe * 3.0 * S_(i * 2.1 + 1.0)
        p["body"] = p.get("body", 0.0) + shake[i]
        p["dy"] = p.get("dy", 0.0) + 1.5 * abs(shake[i])
        if i == WALL_FIRE:
            p["staff.dy"] = 10.0  # the staff is driven into the floor
        elif i in (8, 9):
            p["staff.dy"] = 8.0
        elif i == 10:
            p["staff.dy"] = 4.0
    A["summon"] = sm
    # The staff stays upright in his fist (it is lifted and driven straight down, not swung): counter-rotate it against the arm.
    for poses in A.values():
        for p in poses:
            p["staff"] = p.get("staff", 0.0) - 0.9 * p.get("arm_r", 0.0)
    return A


def colossus_actions(f):
    A = {}
    # signs: arm_l (spear fist left of the shoulder) + raises it; arm_r (crystal fist below-right) - swings it up and out
    def idle(t):
        w = S_(TAU * t)
        return {"sy": 1 + 0.012 * w, "body": 1.2 * w, "head": 2.0 * S_(TAU * t + 1.0), "arm_l": 1.5 * S_(TAU * t + 0.5),
                "arm_r": -2.0 * S_(TAU * t + 1.3), "dy": -1.2 * w}
    A["idle"] = cyc(12, idle)

    def walk(t):
        w = S_(TAU * t)
        # a heavy stomp: each crystal leg lifts and slams, the trunk lurches over the planted leg, the crystal fist swings
        return {"leg_l": 9 * w, "leg_r": -9 * w, "body": 3 * w, "rot": 2.0 * w, "dy": -5 * abs(w) + 1.5,
                "head": -2.5 * S_(TAU * t + 0.7), "arm_l": 3 * S_(TAU * t + 0.3), "arm_r": -6 * S_(TAU * t + 0.6)}
    A["walk"] = cyc(12, walk)
    # Crystal Lance (range 1-2): he draws the spear-staff back and up (f02-f04), then thrusts the crystal blade forward and down
    # at the target with a lunge, connecting on f06 (hit), recovers.
    wind = dict(fwd(f, -8), arm_l=22, spear=-14, arm_r=8, body=-6, head=-5, dy=-4)
    strike = dict(fwd(f, 24), arm_l=-16, spear=26, arm_r=-6, body=9, head=6, dy=3)
    A["attack"] = keys(12, [(0, {}), (3, wind), (4, dict(wind, arm_l=26)), (HIT, strike), (8, dict(strike, arm_l=-10, spear=18, **fwd(f, 16))), (11, {})])
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -12), body=-7, head=-10, arm_l=10, arm_r=10, dy=-4)),
        (4, dict(fwd(f, -7), body=-3, head=-4)),
        (7, {}),
    ])
    # Death: the crystal giant cracks and collapses in place: a short tilt (clockwise, which keeps the long spear inside the
    # cell in both facings), the legs buckle, the body squashes and sinks, the spear-staff sags toward the floor.
    A["death"] = keys(13, [
        (0, {}),
        (2, dict(body=-6, head=-12, dy=-5, arm_l=14, arm_r=14)),
        (5, dict(rot=8, body=4, dy=14, sy=0.9, arm_l=-6, arm_r=-8, head=8, leg_l=8, leg_r=-8, spear=8)),
        (8, dict(rot=16, body=6, dy=34, sy=0.74, sx=1.04, arm_l=-14, arm_r=-14, head=14, leg_l=14, leg_r=-14, spear=18)),
        (10, dict(rot=20, body=6, dy=44, sy=0.66, sx=1.06, arm_l=-18, arm_r=-18, head=16, leg_l=16, leg_r=-16, spear=24)),
        (12, dict(rot=21, body=6, dy=45, sy=0.65, sx=1.06, arm_l=-19, arm_r=-19, head=16, leg_l=16, leg_r=-16, spear=25)),
    ])
    # Root Wall, the base timing: lift the spear-staff (f00-f02), hold it high as the crystals flare (f03-f06), drive its butt
    # into the floor on f07 (the wall fires; staff_point = the spear foot), shockwave f08-f10, settle f11-f13.
    shake = [0, 0, 0, 0, 0, 0, 0, 1.5, -1.2, 1.0, -0.5, 0, 0, 0]
    sm = keys(14, [
        (0, {}),
        (2, dict(arm_l=16, body=-3, head=-4, dy=-3, arm_r=-6)),
        (5, dict(arm_l=26, body=-6, head=-8, dy=-7, arm_r=-14, sy=1.02)),
        (6, dict(arm_l=28, body=-7, head=-9, dy=-8, arm_r=-16, sy=1.02)),
        (7, dict(fwd(f, 6), arm_l=-6, body=6, head=6, dy=4, arm_r=8, sy=0.96)),
        (10, dict(fwd(f, 4), arm_l=-4, body=4, head=4, dy=2, arm_r=6, sy=0.98)),
        (13, {}),
    ])
    for i, p in enumerate(sm):
        stomp = 1.0 if 3 <= i <= 9 else 0.0
        p["leg_l"] = p.get("leg_l", 0.0) + stomp * 2.5 * S_(i * 2.1)
        p["leg_r"] = p.get("leg_r", 0.0) - stomp * 2.5 * S_(i * 2.1 + 1.0)
        p["body"] = p.get("body", 0.0) + shake[i]
        p["dy"] = p.get("dy", 0.0) + 1.5 * abs(shake[i])
        if i == WALL_FIRE:
            p["spear.dy"] = 10.0
        elif i in (8, 9):
            p["spear.dy"] = 8.0
        elif i == 10:
            p["spear.dy"] = 4.0
    A["summon"] = sm
    return A


# ----------------------------------------------------------------- glows

def violet_emissive(im):
    """Weight map of the glowing violet crystal (the heart, the shoulder crystals, the staff head, the cracks) in a frame."""
    a = im[..., 3] > 0
    r, g, b = [im[..., i].astype(np.float32) for i in range(3)]
    vio = a & (np.minimum(r, b) - g > 45) & (np.maximum(r, b) > 140)
    return vio.astype(np.float32) * np.clip((np.maximum(r, b) - 120) / 110.0, 0.3, 1.0)


# The heart's glow over the Root Wall: dims f00-f02, flares f03-f06, bursts on f07, ripples f08-f10, fades by f13.
SUMMON_GLOW = [0.25, 0.12, 0.05, 0.4, 0.75, 1.05, 1.3, 1.7, 1.25, 1.0, 0.75, 0.45, 0.2, 0.05]


def summon_glow(im, i, big):
    k = SUMMON_GLOW[i]
    em = violet_emissive(im) * k
    return monster_kit.glow_from_mask(im, em, big, VIOLET, core=(4, 1.6), halo=(16, 1.3), aura=(16, 0.0))


def crystal_glow(im, big):
    """Star-5 per-frame light: the violet crystal faces bloomed (kept low: much of the body is crystal) plus a faint violet aura."""
    return monster_kit.glow_from_mask(im, violet_emissive(im) * 0.55, big, VIOLET, core=(4, 0.7), halo=(13, 0.45), aura=(16, 0.04))


MONSTERS = {
    "blight_hound": {"name": "Blight Hound", "rig": hound_facing, "actions": hound_actions, "cell": CELL, "pivot": PIV,
                     "role": "room A fast melee: a low, wide blighted wolf of bark, moss and thorns; the pounce-bite lands on attack f06"},
    "blight_horror": {"name": "Blight Horror", "rig": horror_facing, "actions": horror_actions, "cell": CELL, "pivot": PIV,
                      "release": SPORE_RELEASE,
                      "role": "room A ranged: a gaunt root figure with a glowing violet face that spits a spore bolt, released on attack f07"},
    "rotting_elder": {"name": "The Rotting Elder", "rig": elder_facing, "actions": elder_actions, "cell": CELL_BIG, "pivot": PIV_BIG,
                      "action_glow": {"summon": summon_glow},
                      "points": {"staff_point": ("summon", WALL_FIRE, "staff_foot")},
                      "signature": {"action": "summon", "name": "Root Wall", "frames": 14,
                                    "lift": [0, 2], "charge": [3, 6], "fire": WALL_FIRE, "shockwave": [8, 10], "settle": [11, 13],
                                    "glow": ("summon/summon_{S,E}_fNN_glow.png: additive violet heart glow, dims f00-f02, flares f03-f06, "
                                             "bursts on f07, ripples f08-f10, fades by f13")}},
}

# Star-5 set, "the Crystal" theme (Mauro picked B, the Crystal Colossus, 11 Oct 2026). The boss has its own rig (a new
# silhouette); the Crystal Hound and Crystal Horror are edits of the base paintings and reuse the base part cuts.
MONSTERS["crystal_colossus"] = {"name": "The Crystal Colossus", "rig": colossus_facing, "actions": colossus_actions, "cell": CELL_BIG, "pivot": PIV_BIG,
                                "star5": True, "glow": True, "glow_fn": crystal_glow, "base_of": "rotting_elder",
                                "points": {"staff_point": ("summon", WALL_FIRE, "staff_foot")},
                                "role": ("star-5 boss: the Rotting Elder consumed by the blight crystal, a hulking crystal giant with a crystal spear-staff; "
                                         "'Crystal Lance' (range 1-2) connects on attack f06"),
                                "signature": dict(MONSTERS["rotting_elder"]["signature"],
                                                  glow="every frame has an additive _glow (the violet crystal light); no separate signature ramp")}
MONSTERS["crystal_hound"] = dict(MONSTERS["blight_hound"], name="Crystal Hound", rig=crystal_rig(hound_facing, "crystal_hound"),
                                 star5=True, glow=True, glow_fn=crystal_glow, base_of="blight_hound")
MONSTERS["crystal_horror"] = dict(MONSTERS["blight_horror"], name="Crystal Horror", rig=crystal_rig(horror_facing, "crystal_horror"),
                                  star5=True, glow=True, glow_fn=crystal_glow, base_of="blight_horror")
BASE = ("blight_hound", "blight_horror", "rotting_elder")
STAR5 = ("crystal_colossus", "crystal_hound", "crystal_horror")


def build(mid, check=False):
    gkit.use("heart_of_the_blight")
    return monster_kit.build(mid, MONSTERS[mid], check)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    for mid in (args or list(BASE)):
        build(mid, check="--check" in sys.argv)
