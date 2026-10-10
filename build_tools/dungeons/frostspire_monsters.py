"""Frostspire Archive monsters: Ice Construct, Book Wraith, The Pale Archivist (+ star-5 forms).

Rigs are part cuts on the chosen paintings in frostspire_src/<id>_{S,E}.jpg (flat magenta);
the actions are posed here and rendered by the shared monster_kit / mrig.
S = front, facing screen down-right; E = back, facing screen up-right. W and N are game-side
mirrors of E and S.

Cells: 512x360, pivot (256,329) for the construct and the wraith (as the heroes); the
Archivist is 1.5x the hero height in a 768x540 cell, pivot (384,494). 17.144 fps.

Angle sign used below: + = clockwise on screen. For an arm hanging on the image-left side,
+ swings the fist out and up to the left; on the image-right side, - does.

  python3 frostspire_monsters.py [monster ...] [--check]
"""
from __future__ import annotations

import math
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gkit  # noqa: E402
import mrig  # noqa: E402
from mrig import Part, keys  # noqa: E402
import monster_kit  # noqa: E402
from monster_kit import CELL, CELL_BIG, PIV, PIV_BIG, cyc, fwd  # noqa: E402

gkit.use("frostspire_archive")
ICE_GLOW = (0.38, 0.8, 1.0)


# ------------------------------------------------------------------ rigs

def construct_facing(f, src="construct"):
    if f == "S":
        parts = [
            Part("leg_l", [(390, 500), (530, 510), (540, 600), (510, 760), (470, 875), (460, 998), (250, 998), (248, 890), (330, 872), (420, 850), (400, 700), (385, 580)], (460, 530), "root", True, -2),
            Part("leg_r", [(532, 515), (700, 520), (742, 640), (742, 760), (762, 845), (805, 885), (805, 948), (600, 955), (515, 945), (515, 850), (558, 700), (560, 600)], (610, 540), "root", True, -2),
            Part("arm_l_up", [(195, 225), (335, 235), (395, 330), (402, 480), (388, 600), (300, 640), (210, 640), (150, 560), (148, 450), (190, 330)], (300, 330), "body", True, 2),
            Part("arm_l_lo", [(150, 600), (300, 610), (395, 620), (432, 720), (432, 862), (330, 878), (200, 866), (150, 720)], (290, 630), "arm_l_up", False, 2),
            Part("arm_r_up", [(690, 238), (800, 248), (815, 330), (810, 440), (850, 560), (760, 590), (705, 520), (682, 420), (688, 330)], (735, 300), "body", True, 2),
            Part("arm_r_lo", [(745, 555), (860, 545), (912, 640), (908, 825), (800, 835), (768, 700), (742, 610)], (800, 565), "arm_r_up", False, 2),
            Part("head", [(395, 15), (705, 80), (712, 200), (560, 232), (420, 205), (378, 120)], (550, 232), "body", True, 1),
        ]
        return mrig.Facing(src + "_S.jpg", parts, ground=(530, 975), hip=(530, 560), scale=0.28, cell=CELL, cell_pivot=PIV, despill=True)
    parts = [
        Part("leg_l", [(355, 468), (482, 478), (492, 600), (472, 760), (474, 855), (296, 856), (296, 750), (330, 640), (340, 540)], (420, 490), "root", True, -2),
        Part("leg_r", [(484, 470), (602, 478), (652, 600), (652, 750), (672, 900), (642, 1004), (448, 1004), (448, 900), (488, 780), (500, 650), (490, 560)], (550, 490), "root", True, -1),
        Part("arm_l_up", [(232, 232), (362, 248), (372, 400), (334, 520), (322, 620), (292, 725), (198, 732), (152, 600), (158, 460), (208, 380)], (300, 320), "body", True, -3),
        Part("arm_r_up", [(638, 228), (765, 258), (772, 380), (762, 480), (790, 560), (700, 590), (640, 520), (606, 440), (618, 330)], (690, 320), "body", True, 2),
        Part("arm_r_lo", [(700, 540), (800, 520), (850, 600), (868, 800), (802, 902), (718, 882), (690, 760), (650, 640), (660, 570)], (740, 560), "arm_r_up", False, 2),
        Part("head", [(398, 55), (645, 85), (645, 205), (520, 240), (398, 200)], (520, 240), "body", True, 1),
    ]
    return mrig.Facing(src + "_E.jpg", parts, ground=(480, 935), hip=(500, 500), scale=0.28, cell=CELL, cell_pivot=PIV, despill=True)


def wraith_facing(f, src="wraith"):
    if f == "S":
        parts = [
            Part("tail", [(300, 1000), (820, 1000), (860, 1200), (790, 1470), (500, 1490), (320, 1360), (250, 1200)], (560, 1000), "body", True, -1),
            Part("arm_claw", [(680, 600), (820, 635), (905, 695), (995, 780), (985, 945), (850, 955), (800, 855), (740, 805), (690, 765)], (700, 640), "body", True, 2),
            Part("arm_cast", [(175, 165), (365, 185), (372, 330), (402, 430), (402, 560), (382, 700), (300, 765), (215, 705), (198, 560), (218, 450), (228, 380), (186, 330)], (380, 455), "body", True, 3),
            Part("head", [(488, 105), (785, 155), (795, 300), (742, 405), (618, 405), (508, 335), (486, 200)], (620, 400), "body", True, 4),
        ]
        fc = mrig.Facing(src + "_S.jpg", parts, ground=(560, 1530), hip=(560, 800), scale=0.177, cell=CELL, cell_pivot=PIV, despill=True)
        fc.pocket = ("arm_cast", (270, 265))
        return fc
    parts = [
        Part("tail", [(140, 1000), (760, 1000), (712, 1250), (570, 1495), (290, 1490), (120, 1250)], (480, 1000), "body", True, -1),
        Part("arm_claw", [(55, 555), (200, 495), (300, 475), (382, 465), (392, 560), (332, 622), (252, 642), (202, 702), (162, 775), (55, 765)], (370, 520), "body", True, 2),
        Part("arm_cast", [(818, 128), (978, 148), (962, 332), (912, 402), (952, 560), (952, 702), (878, 702), (778, 560), (698, 482), (688, 390), (778, 350), (838, 300)], (700, 420), "body", True, 3),
        Part("head", [(418, 85), (685, 98), (685, 332), (618, 342), (448, 282), (418, 200)], (550, 320), "body", True, 4),
    ]
    fc = mrig.Facing(src + "_E.jpg", parts, ground=(500, 1530), hip=(500, 800), scale=0.177, cell=CELL, cell_pivot=PIV, despill=True)
    fc.pocket = ("arm_cast", (890, 235))
    return fc


def archivist_facing(f, src="archivist"):
    if f == "S":
        parts = [
            Part("hem", [(130, 1150), (980, 1150), (990, 1400), (800, 1500), (300, 1500), (130, 1400)], (560, 1150), "body", True, -1),
            Part("claw", [(150, 495), (245, 485), (335, 495), (355, 560), (332, 652), (302, 782), (292, 935), (228, 935), (198, 802), (155, 700)], (345, 540), "body", True, 2),
            Part("tome", [(585, 365), (842, 335), (932, 395), (932, 655), (882, 705), (802, 715), (690, 722), (598, 702), (585, 560)], (700, 650), "body", True, 3),
            Part("head", [(405, 15), (625, 15), (625, 120), (602, 200), (592, 262), (562, 302), (480, 302), (448, 242), (428, 162), (405, 100)], (520, 300), "body", True, 4),
        ]
        fc = mrig.Facing(src + "_S.jpg", parts, ground=(560, 1480), hip=(560, 1050), scale=0.262, cell=CELL_BIG, cell_pivot=PIV_BIG, despill=True)
        fc.tome_rune = ("tome", (790, 545))
        return fc
    parts = [
        Part("hem", [(30, 1150), (910, 1150), (910, 1400), (700, 1500), (200, 1500), (30, 1400)], (480, 1150), "body", True, -1),
        Part("claw", [(695, 495), (828, 415), (935, 415), (925, 562), (852, 602), (832, 752), (802, 885), (748, 885), (718, 762), (688, 600)], (690, 540), "body", True, 2),
        Part("tome", [(195, 275), (422, 265), (452, 300), (452, 562), (332, 605), (238, 605), (190, 562), (195, 400)], (420, 560), "body", True, 3),
        Part("head", [(475, 35), (655, 45), (655, 200), (622, 242), (518, 242), (468, 200), (458, 120)], (560, 250), "body", True, 4),
    ]
    fc = mrig.Facing(src + "_E.jpg", parts, ground=(480, 1480), hip=(480, 1050), scale=0.262, cell=CELL_BIG, cell_pivot=PIV_BIG, despill=True)
    fc.tome_rune = ("tome", (360, 420))
    return fc


# --------------------------------------------------------------- actions

S_ = math.sin
TAU = 2 * math.pi


def construct_actions(f):
    A = {}
    A["idle"] = cyc(12, lambda t: {"sy": 1 + 0.012 * S_(TAU * t), "body": 1.0 * S_(TAU * t), "head": 2.0 * S_(TAU * t + 0.9),
                                   "arm_l_up": 2.0 * S_(TAU * t + 0.5), "arm_r_up": -2.0 * S_(TAU * t + 0.9),
                                   "arm_l_lo": 1.5 * S_(TAU * t + 1.2), "arm_r_lo": -1.5 * S_(TAU * t + 1.6), "dy": -0.6 * S_(TAU * t)})

    def walk(t):
        w = S_(TAU * t)
        return {"leg_l": 12 * w, "leg_r": -12 * w, "body": 2.0 * w, "rot": 1.5 * w, "dy": -5 * abs(w) + 1.5,
                "head": -2 * S_(TAU * t + 0.6), "arm_l_up": -8 * w, "arm_r_up": 8 * w,
                "arm_l_lo": -4 * S_(TAU * t - 0.5), "arm_r_lo": 4 * S_(TAU * t - 0.5)}
    A["walk"] = cyc(12, walk)
    # Ground pound: both fists heave up and out (forearms bent in), then slam down in front.
    wind = dict(fwd(f, -4), arm_l_up=36, arm_l_lo=30, arm_r_up=-36, arm_r_lo=-30, body=-7, head=-7, sy=1.03, dy=-5, leg_l=3, leg_r=-3)
    wind2 = dict(fwd(f, -5), arm_l_up=40, arm_l_lo=34, arm_r_up=-40, arm_r_lo=-34, body=-8, head=-8, sy=1.035, dy=-6, leg_l=3, leg_r=-3)
    slam = dict(fwd(f, 14), arm_l_up=-14, arm_l_lo=-10, arm_r_up=14, arm_r_lo=10, body=11, head=9, sy=0.94, dy=8, leg_l=-4, leg_r=4)
    follow = dict(fwd(f, 12), arm_l_up=-10, arm_l_lo=-6, arm_r_up=10, arm_r_lo=6, body=8, head=6, sy=0.97, dy=5)
    A["attack"] = keys(12, [(0, {}), (3, wind), (4, wind2), (6, slam), (8, follow), (11, {})])
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -10), body=-8, head=-10, arm_l_up=12, arm_r_up=-12, arm_l_lo=8, arm_r_lo=-8, dy=-2)),
        (4, dict(fwd(f, -6), body=-3, head=-4)),
        (7, {}),
    ])
    # Death: the rune gives out, the knees buckle, the body topples and lies on its side.
    fall = -1 if f == "S" else 1
    A["death"] = keys(13, [
        (0, {}),
        (2, dict(body=-5, head=-10, dy=-3, arm_l_up=15, arm_r_up=-15)),
        (5, dict(dy=22, sy=0.93, body=8 * -fall, rot=10 * fall, leg_l=12, leg_r=-12, arm_l_up=-12, arm_r_up=12, head=12)),
        (8, dict(rot=58 * fall, dy=46, sy=0.9, body=8 * -fall, leg_l=16, leg_r=-16, arm_l_up=-20 * -fall, arm_r_up=20 * -fall, head=18)),
        (10, dict(rot=80 * fall, dy=56, sy=0.88, body=6 * -fall, leg_l=18, leg_r=-18, arm_l_up=-24 * -fall, arm_r_up=24 * -fall, head=20)),
        (12, dict(rot=82 * fall, dy=57, sy=0.88, body=6 * -fall, leg_l=18, leg_r=-18, arm_l_up=-25 * -fall, arm_r_up=25 * -fall, head=21)),
    ])
    return A


WRAITH_RELEASE = 7


def wraith_actions(f):
    A = {}
    A["idle"] = cyc(12, lambda t: {"dy": -5 * S_(TAU * t) - 2, "body": 2 * S_(TAU * t), "head": 3 * S_(TAU * t + 0.8),
                                   "arm_cast": 4 * S_(TAU * t + 0.4), "arm_claw": -4 * S_(TAU * t + 1.0),
                                   "tail": 5 * S_(TAU * t - 0.9)})

    def glide(t):
        w = S_(TAU * t)
        return {"dy": -4 * S_(TAU * t * 2) - 3, "body": 5 + 2 * w, "rot": 2 * w, "head": -3 + 2 * S_(TAU * t + 0.7),
                "tail": 8 + 6 * S_(TAU * t - 1.0), "arm_cast": -6 + 5 * w, "arm_claw": 6 - 5 * w}
    A["walk"] = cyc(12, glide)
    # Cast: draw the frost back (f01-f06, trembling), hurl it on f07 (release), recover.
    arm = [0, -10, -22, -30, -32, -33, -31, 42, 46, 30, 12, 0]
    body = [0, -2, -4, -6, -6, -6, -5, 8, 7, 4, 1, 0]
    shake = [0, 0, 0, 0, 1, -1, 1, 0, 0, 0, 0, 0]
    att = []
    for i in range(12):
        p = {"arm_cast": float(arm[i] + 1.5 * shake[i]), "body": float(body[i]), "head": -0.5 * body[i] + 1.5 * shake[i],
             "tail": -1.2 * body[i], "arm_claw": -0.8 * arm[i] * 0.4, "dy": -2.0}
        p.update(fwd(f, 0.6 * body[i]))
        att.append(p)
    A["attack"] = att
    A["hit"] = keys(8, [
        (0, {"dy": -2}),
        (2, dict(fwd(f, -12), body=-10, head=-12, arm_cast=-12, arm_claw=12, tail=10, dy=-6)),
        (4, dict(fwd(f, -6), body=-4, head=-4, dy=-3)),
        (7, {"dy": -2}),
    ])
    # Death: the shroud loses its hold, sinks and collapses on its side into a heap of pages.
    fall = -1 if f == "S" else 1
    A["death"] = keys(13, [
        (0, {"dy": -2}),
        (2, dict(body=-8, head=-16, dy=-10, arm_cast=-20, arm_claw=20, tail=8)),
        (5, dict(dy=18, sy=0.88, body=10 * -fall, rot=14 * fall, head=10, arm_cast=20, arm_claw=-15, tail=-10)),
        (8, dict(rot=62 * fall, dy=48, sy=0.78, body=10 * -fall, head=18, arm_cast=30, arm_claw=-25, tail=-16)),
        (10, dict(rot=80 * fall, dy=56, sy=0.72, body=8 * -fall, head=22, arm_cast=34, arm_claw=-28, tail=-20)),
        (12, dict(rot=82 * fall, dy=57, sy=0.7, body=8 * -fall, head=23, arm_cast=35, arm_claw=-29, tail=-21)),
    ])
    return A


SUMMON_SPAWN = 9


def archivist_actions(f):
    A = {}
    sg = 1 if f == "S" else -1  # claw raise sign (image-left claw in S, image-right in E)
    A["idle"] = cyc(12, lambda t: {"sy": 1 + 0.01 * S_(TAU * t), "body": 1.0 * S_(TAU * t), "head": 2.0 * S_(TAU * t + 0.9),
                                   "claw": 4 * sg * S_(TAU * t + 1.3), "tome": 1.2 * S_(TAU * t + 0.3), "tome.dy": -2 * S_(TAU * t + 0.3),
                                   "hem": 1.2 * S_(TAU * t - 0.6)})

    def glide(t):
        w = S_(TAU * t)
        return {"rot": 2.0 * w, "body": 1.5 * w + 1.5, "dy": -3 * abs(w), "head": -2 * S_(TAU * t + 0.6),
                "hem": -3.5 * w, "claw": 6 * sg * w, "tome": -2 * w, "tome.dy": -4 * max(0.0, -w)}
    A["walk"] = cyc(12, glide)
    # Frost claw: raise the clawed hand back, rake it down at the target (f06), recover.
    wind = dict(claw=55 * sg, tome=-4, **{"tome.dy": -6}, body=-6, head=-7, hem=2)
    strike = dict(fwd(f, 16), claw=-28 * sg, tome=4, **{"tome.dy": 2}, body=9, head=7, hem=-4)
    follow = dict(fwd(f, 14), claw=-22 * sg, tome=3, body=7, head=5, hem=-3)
    A["attack"] = keys(12, [(0, {}), (3, wind), (4, wind), (6, strike), (8, follow), (11, {})])
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -12), body=-8, head=-12, claw=15 * sg, tome=-6, **{"tome.dy": -6}, hem=4, dy=-2)),
        (4, dict(fwd(f, -8), body=-4, head=-5, tome=-3)),
        (7, {}),
    ])
    fall = -1 if f == "S" else 1
    A["death"] = keys(13, [
        (0, {}),
        (2, dict(body=-7, head=-18, tome=-8, **{"tome.dy": -12}, claw=25 * sg, dy=-4)),
        (5, dict(rot=22 * fall, body=6 * fall, dy=10, head=-10, tome=10, **{"tome.dy": 10}, claw=-20 * sg, hem=4)),
        (8, dict(rot=62 * fall, body=10 * fall, dy=40, head=6, tome=4, **{"tome.dy": 18}, claw=-35 * sg, sy=0.95, hem=6)),
        (10, dict(rot=82 * fall, body=8 * fall, dy=52, head=12, tome=-2, **{"tome.dy": 22}, claw=-45 * sg, sy=0.9, hem=7)),
        (12, dict(rot=84 * fall, body=8 * fall, dy=54, head=14, tome=-3, **{"tome.dy": 22}, claw=-46 * sg, sy=0.9, hem=7)),
    ])
    # Signature "Unbound Pages": lift the chained tome high (f03), hold it glowing and straining
    # (f03-f09), the pages burst out on f09 (spawn the Book Wraiths), then the arms lower (f10-f13).
    shake = [0, 0, 0, 0, 1, -1, 1, -1, 1, 0, 0, 0, 0, 0]
    sm = keys(14, [
        (0, {}),
        (3, dict(tome=-6 * sg, **{"tome.dy": -92, "tome.dx": -10 * sg}, claw=60 * sg, body=-6, head=-14, sy=1.02, hem=2)),
        (8, dict(tome=-8 * sg, **{"tome.dy": -98, "tome.dx": -12 * sg}, claw=66 * sg, body=-7, head=-18, sy=1.03, hem=2)),
        (9, dict(tome=-10 * sg, **{"tome.dy": -108, "tome.dx": -12 * sg}, claw=72 * sg, body=-8, head=-20, sy=1.035, hem=3)),
        (10, dict(tome=-2 * sg, **{"tome.dy": -40, "tome.dx": -4 * sg}, claw=20 * sg, body=-2, head=-6, hem=-2)),
        (11, dict(tome=0, **{"tome.dy": -14}, claw=6 * sg, body=0, head=-2, hem=-1)),
        (13, {}),
    ])
    for i, p in enumerate(sm):
        p["tome.dx"] = p.get("tome.dx", 0.0) + 1.5 * shake[i]
        p["head"] = p.get("head", 0.0) + 1.5 * shake[i]
    A["summon"] = sm
    return A


# ----------------------------------------------------------------- glows

def frost_emissive(im):
    """Weight map of the glowing ice-cyan paint (runes, eyes, crystal cores) in a frame."""
    a = im[..., 3] > 0
    r, g, b = [im[..., i].astype(np.float32) for i in range(3)]
    # Only the saturated, bright cyan (runes, eyes, crystal cores), not the pale ice around it.
    em = a & (b > 215) & (b - r > 100) & (g > 130)
    return em.astype(np.float32) * np.clip((b - r - 100) / 80.0, 0.35, 1.0)


def frost_glow(im, big):
    return monster_kit.glow_from_mask(im, frost_emissive(im), big, ICE_GLOW, core=(4, 1.3), halo=(13, 0.9), aura=(16, 0.07))


# Tome glow for the summon: ramps up f01-f03, holds and pulses to f09 (burst), fades by f12.
SUMMON_GLOW = [0.0, 0.25, 0.6, 0.85, 0.9, 1.0, 0.9, 1.0, 1.1, 1.35, 0.6, 0.25, 0.08, 0.0]


def summon_glow(im, i, big):
    k = SUMMON_GLOW[i]
    em = frost_emissive(im) * k
    out = monster_kit.glow_from_mask(im, em, big, ICE_GLOW, core=(5, 1.8), halo=(18, 1.4), aura=(16, 0.0))
    if k == 0:
        out[:] = 0
    return out


MONSTERS = {
    "ice_construct": {"name": "Ice Construct", "rig": construct_facing, "actions": construct_actions, "cell": CELL, "pivot": PIV,
                      "role": "room A heavy melee tank (double-fist slam lands on attack f06)"},
    "book_wraith": {"name": "Book Wraith", "rig": wraith_facing, "actions": wraith_actions, "cell": CELL, "pivot": PIV,
                    "release": WRAITH_RELEASE, "role": "room A ranged caster: throws a frost bolt, released on attack f07 from its casting hand"},
    "the_pale_archivist": {"name": "The Pale Archivist", "rig": archivist_facing, "actions": archivist_actions, "cell": CELL_BIG, "pivot": PIV_BIG,
                           "action_glow": {"summon": summon_glow},
                           "signature": {"action": "summon", "name": "Unbound Pages", "frames": 14,
                                         "raise_start": 3, "glow_hold": [3, 9], "spawn": SUMMON_SPAWN, "lower": [10, 13],
                                         "glow": "summon/summon_{S,E}_fNN_glow.png: additive tome glow, ramps up f01-f03, peaks at f09, fades by f12"}},
}

# Star-5 forms (painted as edits of the base, so they reuse the base part cuts).
MONSTERS["the_frozen_archivist"] = dict(MONSTERS["the_pale_archivist"], name="The Frozen Archivist", rig=lambda f: archivist_facing(f, "frozen_archivist"),
                                        star5=True, glow=True, glow_fn=frost_glow, base_of="the_pale_archivist")
MONSTERS["the_frozen_archivist"].pop("action_glow")
MONSTERS["frozen_ice_construct"] = dict(MONSTERS["ice_construct"], name="Frozen Ice Construct", rig=lambda f: construct_facing(f, "frozen_construct"),
                                        star5=True, glow=True, glow_fn=frost_glow, base_of="ice_construct")
MONSTERS["frozen_book_wraith"] = dict(MONSTERS["book_wraith"], name="Frozen Book Wraith", rig=lambda f: wraith_facing(f, "frozen_wraith"),
                                      star5=True, glow=True, glow_fn=frost_glow, base_of="book_wraith")
BASE = ("ice_construct", "book_wraith", "the_pale_archivist")


def build(mid, check=False):
    gkit.use("frostspire_archive")
    return monster_kit.build(mid, MONSTERS[mid], check)


def regen_glows(mid):
    """Rewrite only the _glow maps of an already built monster from its frames (no re-render)."""
    from PIL import Image
    spec = MONSTERS[mid]
    root = os.path.join(gkit.OUT, "star5" if spec.get("star5") else "", "monsters", mid)
    big = spec["cell"] == CELL_BIG
    n = 0
    for act in sorted(os.listdir(root)):
        d = os.path.join(root, act)
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if not fn.endswith(".png") or fn.endswith("_glow.png"):
                continue
            im = np.asarray(Image.open(os.path.join(d, fn)).convert("RGBA")).copy()
            if spec.get("glow"):
                g = frost_glow(im, big)
            elif act in spec.get("action_glow", {}):
                g = spec["action_glow"][act](im, int(fn[-6:-4]), big)
            else:
                continue
            gkit.save_png(os.path.join(d, fn[:-4] + "_glow.png"), g)
            n += 1
    print(mid, "glows rewritten:", n)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    for mid in (args or list(BASE)):
        if "--glow-only" in sys.argv:
            regen_glows(mid)
        else:
            build(mid, check="--check" in sys.argv)
