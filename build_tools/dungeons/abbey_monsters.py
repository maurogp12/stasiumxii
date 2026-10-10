"""Drowned Abbey monsters: Bog Dead, Mire Leech, The Mire Abbess (+ star-5 Gravebound forms).

Rigs are part cuts on the chosen paintings in abbey_src/<id>_{S,E}.jpg (flat magenta);
the actions are posed here and rendered by the shared monster_kit / mrig.
S = front, facing screen down-right; E = back, facing screen up-right. W and N are game-side
mirrors of E and S.

Cells: 512x360, pivot (256,329) for the Bog Dead and the Mire Leech (as the heroes);
the Mire Abbess is 1.5x the hero cell, 768x540, pivot (384,494). 17.144 fps.

Angle sign used below: + = clockwise on screen (y down). A point left of a pivot goes UP
under +, a point right of a pivot goes DOWN, a point above goes RIGHT, a point below goes LEFT.

  python3 abbey_monsters.py [monster ...] [--check]
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

gkit.use("drowned_abbey")
RITE_GREEN = (0.5, 1.0, 0.35)
JADE_GLOW = (0.55, 1.0, 0.78)


# ------------------------------------------------------------------ rigs

def bog_dead_facing(f, src="bog_dead"):
    if f == "S":
        parts = [
            Part("head", [(470, 70), (720, 30), (800, 190), (770, 330), (650, 385), (520, 350), (470, 250)], (600, 380), "body", True, 3),
            Part("arm_l", [(60, 270), (330, 220), (420, 300), (455, 460), (445, 625), (330, 630), (245, 625), (230, 900), (55, 900)], (390, 330), "body", True, 2),
            Part("arm_r", [(700, 300), (800, 320), (880, 510), (1005, 630), (1005, 960), (860, 960), (775, 800), (735, 640), (700, 520)], (720, 360), "body", True, 2),
            Part("leg_l", [(330, 920), (470, 950), (430, 1150), (330, 1350), (310, 1510), (70, 1510), (80, 1300), (200, 1100), (250, 950)], (380, 960), "root", True, -1),
            Part("leg_r", [(560, 950), (720, 950), (775, 1150), (895, 1270), (895, 1360), (675, 1360), (600, 1200), (540, 1050)], (620, 960), "root", True, -1),
        ]
        return mrig.Facing(src + "_S.jpg", parts, ground=(500, 1420), hip=(520, 900), scale=0.18, cell=CELL, cell_pivot=PIV, despill=True)
    parts = [
        Part("head", [(430, 30), (725, 30), (735, 250), (620, 305), (470, 285), (420, 180)], (580, 300), "body", True, 3),
        Part("arm_l", [(25, 280), (300, 280), (305, 420), (235, 520), (225, 790), (25, 790)], (270, 330), "body", True, 2),
        Part("arm_r", [(700, 290), (800, 280), (1005, 270), (1005, 475), (890, 505), (880, 905), (720, 905), (700, 600)], (710, 340), "body", True, 2),
        Part("leg_l", [(200, 950), (450, 950), (430, 1150), (375, 1300), (375, 1470), (55, 1470), (115, 1250), (180, 1100)], (330, 960), "root", True, -1),
        Part("leg_r", [(560, 950), (700, 950), (765, 1150), (905, 1255), (950, 1360), (615, 1370), (600, 1200)], (620, 960), "root", True, -1),
    ]
    return mrig.Facing(src + "_E.jpg", parts, ground=(500, 1400), hip=(480, 900), scale=0.18, cell=CELL, cell_pivot=PIV, despill=True)


def leech_facing(f, src="leech"):
    if f == "S":
        parts = [
            Part("head", [(140, 50), (965, 50), (985, 720), (860, 790), (700, 720), (560, 470), (250, 470), (140, 350)], (330, 500), "neck", False, 3),
            Part("neck", [(240, 470), (560, 470), (720, 560), (735, 800), (705, 1015), (520, 1045), (440, 945), (330, 785), (240, 620)], (560, 1000), "body", True, 2),
        ]
        fc = mrig.Facing(src + "_S.jpg", parts, ground=(520, 1470), hip=(500, 1250), scale=0.17, cell=CELL, cell_pivot=PIV, despill=True)
        fc.pocket = ("head", (800, 440))
        return fc
    parts = [
        Part("head", [(250, 30), (990, 30), (990, 565), (700, 565), (600, 485), (420, 525), (250, 525)], (400, 540), "neck", False, 3),
        Part("neck", [(250, 525), (420, 525), (600, 485), (705, 565), (765, 800), (765, 1050), (560, 1065), (480, 905), (380, 755), (250, 645)], (620, 1050), "body", True, 2),
    ]
    fc = mrig.Facing(src + "_E.jpg", parts, ground=(520, 1460), hip=(500, 1250), scale=0.17, cell=CELL, cell_pivot=PIV, despill=True)
    fc.pocket = ("head", (905, 215))
    return fc


def abbess_facing(f, src="abbess"):
    if f == "S":
        parts = [
            Part("candle_a", [(95, 195), (210, 195), (210, 585), (95, 585)], (150, 400), "root", False, 5),
            Part("candle_b", [(205, 75), (292, 75), (292, 355), (205, 355)], (250, 220), "root", False, 5),
            Part("candle_c", [(555, 15), (655, 15), (655, 305), (555, 305)], (600, 160), "root", False, 5),
            Part("censer", [(780, 432), (1015, 432), (1015, 955), (780, 955)], (870, 420), "arm_censer", False, 4),
            Part("arm_censer", [(640, 380), (780, 360), (840, 335), (935, 345), (935, 432), (800, 440), (790, 640), (780, 900), (700, 900), (690, 640), (640, 560)], (660, 420), "body", True, 3),
            Part("arm_free", [(330, 515), (405, 515), (485, 555), (485, 655), (420, 675), (355, 645), (325, 600)], (350, 520), "body", True, 2),
            Part("head", [(290, 15), (558, 15), (558, 300), (500, 335), (380, 335), (292, 300)], (430, 320), "body", True, 2),
        ]
        fc = mrig.Facing(src + "_S.jpg", parts, ground=(500, 1460), hip=(480, 700), scale=0.3, cell=CELL_BIG, cell_pivot=PIV_BIG, despill=True)
        fc.rite_mouth = ("censer", (900, 740))
        return fc
    parts = [
        Part("candle_a", [(125, 245), (218, 245), (218, 515), (125, 515)], (170, 380), "root", False, 5),
        Part("candle_b", [(312, 35), (388, 35), (388, 305), (312, 305)], (350, 170), "root", False, 5),
        Part("candle_c", [(612, 25), (698, 25), (698, 305), (612, 305)], (655, 165), "root", False, 5),
        Part("censer", [(800, 345), (1015, 345), (1015, 805), (800, 805)], (870, 340), "arm_censer", False, 4),
        Part("arm_censer", [(650, 380), (760, 368), (830, 318), (905, 318), (905, 345), (800, 345), (780, 560), (720, 560), (680, 500)], (680, 420), "body", True, 3),
        Part("arm_free", [(110, 580), (250, 555), (330, 478), (342, 560), (282, 700), (252, 880), (198, 905), (150, 700), (105, 685)], (320, 500), "body", True, 2),
        Part("head", [(390, 15), (602, 15), (602, 262), (522, 332), (410, 322), (368, 220)], (480, 330), "body", True, 2),
    ]
    fc = mrig.Facing(src + "_E.jpg", parts, ground=(500, 1460), hip=(480, 700), scale=0.3, cell=CELL_BIG, cell_pivot=PIV_BIG, despill=True)
    fc.rite_mouth = ("censer", (900, 680))
    return fc


# --------------------------------------------------------------- actions

S_ = math.sin
TAU = 2 * math.pi
HIT = 6  # melee contact frame (Bog Dead claws, the Abbess's Censer Lash)


def bog_dead_actions(f):
    A = {}
    # raise signs: S arm_l (hand lower-left) +, arm_r (hand lower-right) -; E arm_l +, arm_r (hand right) -
    ul, ur = 1, -1
    A["idle"] = cyc(12, lambda t: {"sy": 1 + 0.014 * S_(TAU * t), "body": 1.6 * S_(TAU * t), "head": 3.0 * S_(TAU * t + 1.1),
                                   "arm_l": ul * 3.5 * S_(TAU * t + 0.4), "arm_r": ur * 3.5 * S_(TAU * t + 1.6), "dy": -0.6 * S_(TAU * t)})

    def walk(t):
        w = S_(TAU * t)
        # a dragging shamble: a lurch to each side, the head lolling behind, the arms swinging loose
        return {"leg_l": 13 * w, "leg_r": -13 * w, "body": 3.5 * w, "rot": 2.0 * w, "dy": -3.5 * abs(w) + 1,
                "head": -4.5 * S_(TAU * t + 0.8), "arm_l": ul * 6 * S_(TAU * t + 0.5), "arm_r": ur * 6 * S_(TAU * t + 0.5 + math.pi)}
    A["walk"] = cyc(12, walk)
    # Double claw rake: both arms rise high (f02-f04), lunge and rake down on f06 (hit), recover.
    wind = dict(fwd(f, -6), arm_l=ul * 30, arm_r=ur * 34, body=-6, head=-8, leg_l=4, leg_r=-4, dy=-3)
    strike = dict(fwd(f, 18), arm_l=-ul * 26, arm_r=-ur * 28, body=9, head=8, leg_l=-6, leg_r=6, dy=2)
    follow = dict(fwd(f, 14), arm_l=-ul * 20, arm_r=-ur * 22, body=7, head=5)
    A["attack"] = keys(12, [(0, {}), (3, wind), (4, dict(wind, arm_l=ul * 34, arm_r=ur * 38)), (HIT, strike), (8, follow), (11, {})])
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -12), body=-9, head=-14, arm_l=ul * 14, arm_r=ur * 14, dy=-2)),
        (4, dict(fwd(f, -7), body=-4, head=-6)),
        (7, {}),
    ])
    fall = -1 if f == "S" else 1
    A["death"] = keys(13, [
        (0, {}),
        (2, dict(body=-6, head=-18, dy=-3, arm_l=ul * 22, arm_r=ur * 22)),
        (5, dict(dy=20, sy=0.92, body=8 * -fall, rot=12 * fall, leg_l=14, leg_r=-14, arm_l=-ul * 10, arm_r=-ur * 10, head=12)),
        (8, dict(rot=60 * fall, dy=46, sy=0.9, body=8 * -fall, leg_l=16, leg_r=-16, arm_l=-ul * 18, arm_r=-ur * 18, head=18)),
        (10, dict(rot=80 * fall, dy=56, sy=0.88, body=6 * -fall, leg_l=18, leg_r=-18, arm_l=-ul * 22, arm_r=-ur * 22, head=20)),
        (12, dict(rot=82 * fall, dy=57, sy=0.88, body=6 * -fall, leg_l=18, leg_r=-18, arm_l=-ul * 23, arm_r=-ur * 23, head=21)),
    ])
    return A


BILE_RELEASE = 7


def leech_actions(f):
    A = {}
    A["idle"] = cyc(12, lambda t: {"sy": 1 + 0.02 * S_(TAU * t), "sx": 1 - 0.01 * S_(TAU * t), "neck": 2.5 * S_(TAU * t),
                                   "head": -3.0 * S_(TAU * t + 0.9), "body": 0.8 * S_(TAU * t + 0.4)})

    def walk(t):
        w = S_(TAU * t)
        # a slither: the coil pulses (stretch / squash twice a loop), the neck sways and the head counter-sways
        p = S_(TAU * t * 2)
        return {"sx": 1 + 0.035 * p, "sy": 1 - 0.03 * p, "neck": 6 * w, "head": -5 * S_(TAU * t + 0.6), "body": 1.5 * w,
                "dy": -1.5 * abs(p) + 0.5}
    A["walk"] = cyc(12, walk)
    # Bile spit: the head rears back and the throat swells (f01-f06, trembling), then snaps forward and spits on
    # f07 (release: the projectile leaves the maw), follow through, settle.
    neck = [0, -4, -8, -12, -15, -16, -16, 14, 16, 9, 3, 0]
    head = [0, -6, -12, -18, -22, -24, -23, 20, 22, 12, 4, 0]
    sy = [1, 1.01, 1.03, 1.05, 1.06, 1.07, 1.07, 0.95, 0.96, 0.98, 1.0, 1]
    shake = [0, 0, 0, 0, 1, -1, 1, 0, 0, 0, 0, 0]
    att = []
    for i in range(12):
        p = {"neck": float(neck[i]), "head": float(head[i] + 1.5 * shake[i]), "sy": sy[i], "sx": 2 - sy[i], "body": 0.3 * neck[i]}
        p.update(fwd(f, 0.5 * neck[i]))
        att.append(p)
    A["attack"] = att
    A["hit"] = keys(8, [
        (0, {}),
        (2, dict(fwd(f, -10), neck=-12, head=-16, sy=1.04, dy=-2)),
        (4, dict(fwd(f, -6), neck=-5, head=-6)),
        (7, {}),
    ])
    fall = 1 if f == "S" else 1
    A["death"] = keys(13, [
        (0, {}),
        (2, dict(neck=-10, head=-24, sy=1.06, dy=-3)),
        (4, dict(neck=-14, head=-30, sy=1.04)),
        (7, dict(neck=40 * fall, head=40, sy=0.92, dy=10)),
        (9, dict(neck=70 * fall, head=55, sy=0.86, dy=18)),
        (11, dict(neck=78 * fall, head=62, sy=0.84, dy=20)),
        (12, dict(neck=80 * fall, head=63, sy=0.84, dy=20)),
    ])
    return A


RITE_BURST = 7
CANDLES = ("candle_a", "candle_b", "candle_c")


def _candles(p, t, amp=3.0, lift=0.0):
    """Bob the three floating candles out of phase (screen-space offsets in cell px)."""
    for k, c in enumerate(CANDLES):
        p[c + ".dy"] = p.get(c + ".dy", 0.0) + amp * S_(TAU * t + 2.1 * k) - lift
    return p


def abbess_actions(f):
    A = {}
    # arm_censer raise sign: - (the hand is right of the shoulder in both facings); censer swing out toward the target: -

    def idle(t):
        p = {"dy": -3.0 * S_(TAU * t), "sy": 1 + 0.008 * S_(TAU * t), "body": 0.8 * S_(TAU * t + 0.5), "head": 1.5 * S_(TAU * t + 1.2),
             "arm_censer": -1.5 * S_(TAU * t), "censer": 4.0 * S_(TAU * t + 0.9), "arm_free": 2.0 * S_(TAU * t + 0.3)}
        return _candles(p, t)
    A["idle"] = cyc(12, idle)

    def walk(t):
        w = S_(TAU * t)
        # a glide: she floats forward with a slow bob, the robe sways and the censer swings like a pendulum behind the beat
        p = {"dy": -4.0 * abs(w) + 1.5, "body": 2.0 * w, "rot": 1.2 * w, "head": -1.5 * S_(TAU * t + 0.6),
             "arm_censer": -3 * w, "censer": 9 * S_(TAU * t + 1.2), "arm_free": 3 * S_(TAU * t + 0.4), "sx": 1 + 0.01 * w}
        return _candles(p, t, 4.0)
    A["walk"] = cyc(12, walk)
    # Censer Lash (range 1-2): she draws the censer back (f02-f04), then whips it out on its chains at the target on f06 (hit).
    wind = dict(fwd(f, -4), arm_censer=-18, censer=26, body=-5, head=-4, arm_free=-6, dy=-4)
    strike = dict(fwd(f, 10), arm_censer=14, censer=-78, body=6, head=4, arm_free=6, dy=-1)
    follow = dict(fwd(f, 8), arm_censer=10, censer=-50, body=4, head=2)
    att = keys(12, [(0, {}), (3, wind), (4, dict(wind, censer=30)), (HIT, strike), (8, follow), (11, {})])
    A["attack"] = [_candles(p, i / 12.0) for i, p in enumerate(att)]
    A["hit"] = [_candles(p, i / 8.0, 2.0) for i, p in enumerate(keys(8, [
        (0, {}),
        (2, dict(fwd(f, -12), body=-7, head=-10, arm_censer=-10, censer=24, dy=-4)),
        (4, dict(fwd(f, -7), body=-3, head=-4, censer=-10)),
        (7, {}),
    ]))]
    fall = -1 if f == "S" else 1
    d = keys(13, [
        (0, {}),
        (2, dict(body=-6, head=-12, dy=-6, arm_censer=-20, censer=30)),
        (5, dict(rot=18 * fall, body=6 * fall, dy=14, sy=0.95, arm_censer=8, censer=-20, head=8)),
        (8, dict(rot=58 * fall, body=8 * fall, dy=44, sy=0.9, arm_censer=16, censer=-40, head=14)),
        (10, dict(rot=78 * fall, body=6 * fall, dy=54, sy=0.88, arm_censer=18, censer=-60, head=16)),
        (12, dict(rot=80 * fall, body=6 * fall, dy=55, sy=0.88, arm_censer=18, censer=-62, head=16)),
    ])
    # the floating candles go out and drop to the floor as she falls
    for i, p in enumerate(d):
        k = max(0.0, (i - 3) / 6.0)
        for j, c in enumerate(CANDLES):
            p[c + ".dy"] = min(1.0, k) ** 2 * (150 + 40 * j)
            p[c] = 40 * min(1.0, k) * (1 if j % 2 else -1)
    A["death"] = d
    # Signature "Rite of Rising": she lowers the censer (f00-f02), swings it high over her head while the floating candles
    # rise and flare (f03-f06); on f07 the green smoke bursts and the rite fires (rite_point = the censer on f07, rite_glow
    # lands on the corpse cell), she holds the censer high (f07-f09) and settles back to idle (f10-f13).
    shake = [0, 0, 0, 0, 0, 0, 0, 1, -1, 1, 0, 0, 0, 0]
    sm = keys(14, [
        (0, {}),
        (2, dict(fwd(f, 2), sy=0.97, dy=4, body=4, head=4, arm_censer=12, censer=14, arm_free=6)),
        (5, dict(sy=1.0, dy=-2, body=-4, head=-6, arm_censer=-22, censer=-75, arm_free=-10)),
        (7, dict(fwd(f, -2), sy=1.01, dy=-3, body=-6, head=-9, arm_censer=-28, censer=-100, arm_free=-14)),
        (9, dict(fwd(f, -2), sy=1.01, dy=-3, body=-5, head=-8, arm_censer=-25, censer=-92, arm_free=-12)),
        (13, {}),
    ])
    lift = [0, 0, 0, 4, 10, 16, 20, 24, 22, 20, 14, 8, 3, 0]
    for i, p in enumerate(sm):
        p["censer"] = p.get("censer", 0.0) + 3.0 * shake[i]
        p["body"] = p.get("body", 0.0) + 0.8 * shake[i]
        _candles(p, i / 14.0, 2.0, lift[i])
    A["summon"] = sm
    return A


# ----------------------------------------------------------------- glows

def rite_emissive(im):
    """Weight map of the glowing green censer smoke and the candle flames in a frame."""
    a = im[..., 3] > 0
    r, g, b = [im[..., i].astype(np.float32) for i in range(3)]
    smoke = a & (g > 150) & (g - r > 25) & (g - b > 45)
    flame = a & (r > 235) & (g > 225) & (b > 170)
    return smoke.astype(np.float32) * np.clip((g - b - 45) / 60.0, 0.4, 1.0) + flame.astype(np.float32) * 0.8


# Rite glow for the signature: builds up f03-f06, bursts on f07, holds f07-f09, fades by f12.
SUMMON_GLOW = [0.0, 0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.5, 1.25, 1.05, 0.8, 0.45, 0.15, 0.0]


def summon_glow(im, i, big):
    k = SUMMON_GLOW[i]
    em = rite_emissive(im) * k
    out = monster_kit.glow_from_mask(im, em, big, RITE_GREEN, core=(5, 1.8), halo=(20, 1.5), aura=(16, 0.0))
    if k == 0:
        out[:] = 0
    return out


def jade_emissive(im):
    """Weight map of the glowing pale-jade soulfire (eyes, mask cracks, halo, runes, candles, censer, pustules) in a star-5 frame."""
    a = im[..., 3] > 0
    r, g, b = [im[..., i].astype(np.float32) for i in range(3)]
    em = a & (g > 170) & (g - r > 45) & (b > 120)
    return em.astype(np.float32) * np.clip((g - r - 45) / 70.0, 0.35, 1.0)


def jade_glow(im, big):
    return monster_kit.glow_from_mask(im, jade_emissive(im), big, JADE_GLOW, core=(4, 1.2), halo=(13, 0.8), aura=(16, 0.05))


MONSTERS = {
    "bog_dead": {"name": "Bog Dead", "rig": bog_dead_facing, "actions": bog_dead_actions, "cell": CELL, "pivot": PIV,
                 "role": "room A melee shambler: a drowned monk; the double claw rake lands on attack f06"},
    "mire_leech": {"name": "Mire Leech", "rig": leech_facing, "actions": leech_actions, "cell": CELL, "pivot": PIV,
                   "release": BILE_RELEASE,
                   "role": "room A ranged: a giant bog worm that spits acid bile from its maw, released on attack f07"},
    "mire_abbess": {"name": "The Mire Abbess", "rig": abbess_facing, "actions": abbess_actions, "cell": CELL_BIG, "pivot": PIV_BIG,
                    "action_glow": {"summon": summon_glow},
                    "points": {"rite_point": ("summon", RITE_BURST, "rite_mouth")},
                    "signature": {"action": "summon", "name": "Rite of Rising", "frames": 14,
                                  "lower": [0, 2], "swing": [3, 6], "burst": RITE_BURST, "hold": [7, 9], "settle": [10, 13],
                                  "glow": "summon/summon_{S,E}_fNN_glow.png: additive green rite glow, builds f03-f06, bursts on f07, holds to f09, fades by f12"}},
}

# Star-5 forms (painted as edits of the base, so they reuse the base part cuts).
MONSTERS["gravebound_abbess"] = dict(MONSTERS["mire_abbess"], name="The Gravebound Abbess", rig=lambda f: abbess_facing(f, "gravebound_abbess"),
                                     star5=True, glow=True, glow_fn=jade_glow, base_of="mire_abbess")
MONSTERS["gravebound_abbess"].pop("action_glow")
MONSTERS["gravebound_bog_dead"] = dict(MONSTERS["bog_dead"], name="Gravebound Bog Dead", rig=lambda f: bog_dead_facing(f, "gravebound_bog_dead"),
                                       star5=True, glow=True, glow_fn=jade_glow, base_of="bog_dead")
MONSTERS["gravebound_mire_leech"] = dict(MONSTERS["mire_leech"], name="Gravebound Mire Leech", rig=lambda f: leech_facing(f, "gravebound_leech"),
                                         star5=True, glow=True, glow_fn=jade_glow, base_of="mire_leech")
BASE = ("bog_dead", "mire_leech", "mire_abbess")
STAR5 = ("gravebound_abbess", "gravebound_bog_dead", "gravebound_mire_leech")


def build(mid, check=False):
    gkit.use("drowned_abbey")
    return monster_kit.build(mid, MONSTERS[mid], check)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    for mid in (args or list(BASE)):
        build(mid, check="--check" in sys.argv)
