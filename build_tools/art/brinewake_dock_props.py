#!/usr/bin/env python3
"""Brinewake dock pieces cut by hand from Mauro's dock picture (5 Oct 2026).

Mauro: "I really like the rocks that looks like coral and the plants ... the
ship in the middle just without the flags and a little bit less obstacles".
The automatic cut-out (arena_props.py, rembg) loses these dark objects in the
dark dock floor, so each piece is cut with a traced outline instead.
Writes art/maps/arena_look/brinewake/prop_<name>.png:
  wreck       the shipwreck, drawn as the centrepiece on (7, 7)
  wreck_side  clear 1x1: the wreck's flank cells (they block, the art is the centrepiece)
  coral_rock  barnacled coral rock (obstacle)
  crate       braced cargo crate (obstacle)
  chest       iron-banded cargo chest (obstacle)
  coral       purple coral plant (decoration, grows on water tiles)
Run after arena_props.py (that script clears the folder first):
  python3 build_tools/art/brinewake_dock_props.py
"""
import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

REF = "art/maps/arena_look/refs/brinewake_look.jpg"
OUT = "art/maps/arena_look/brinewake/"
MAX_H = 92
# Brightness lift (see cut).
LIFT = 1.9

# name -> (outline polygons in picture px, sprite width in board px, max height)
PIECES = {
    "wreck": ([[(1270, 470), (1318, 418), (1338, 368), (1356, 418), (1400, 468), (1480, 498), (1540, 470),
                (1582, 500), (1622, 560), (1700, 608), (1750, 640), (1768, 700), (1700, 730), (1600, 722),
                (1500, 702), (1452, 682), (1402, 742), (1350, 742), (1300, 692), (1260, 622), (1245, 560)]], 150, 140),
    "coral_rock": ([[(1800, 470), (1835, 468), (1845, 490), (1825, 520), (1830, 560), (1860, 580), (1880, 610),
                     (1870, 640), (1820, 650), (1760, 648), (1720, 640), (1708, 610), (1715, 570), (1740, 545),
                     (1760, 520), (1770, 495), (1785, 480)]], 46, MAX_H),
    "crate": ([[(1522, 312), (1620, 278), (1703, 315), (1703, 423), (1605, 460), (1523, 418)]], 46, MAX_H),
    "chest": ([[(583, 550), (670, 512), (753, 543), (753, 618), (650, 650), (583, 623)]], 46, MAX_H),
    "coral": ([[(1100, 425), (1120, 400), (1150, 398), (1170, 405), (1190, 430), (1185, 470), (1170, 495),
                (1130, 500), (1100, 490), (1080, 470), (1075, 445)]], 34, MAX_H),
}


def cut(img, polys, width, max_h):
    mask = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(mask)
    for p in polys:
        d.polygon(p, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(1.2))
    piece = img.copy()
    piece.putalpha(mask)
    piece = piece.crop(mask.getbbox())
    h = max(1, round(piece.height * width / piece.width))
    if h > max_h:
        width = max(1, round(width * max_h / h))
        h = max_h
    piece = piece.resize((width, h), Image.LANCZOS)
    # The picture is a dark night scene; the board is lit warmer and brighter.
    # Lift the piece so it reads on the board, keeping its alpha.
    alpha = piece.getchannel("A")
    rgb = piece.convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(LIFT)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.15)
    rgb = ImageEnhance.Color(rgb).enhance(1.25)
    rgb.putalpha(alpha)
    return rgb


def main():
    img = Image.open(REF).convert("RGBA")
    os.makedirs(OUT, exist_ok=True)
    for name, (polys, width, max_h) in PIECES.items():
        sprite = cut(img, polys, width, max_h)
        sprite.save(os.path.join(OUT, "prop_%s.png" % name), optimize=True)
        print(name, sprite.size)
    Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(os.path.join(OUT, "prop_wreck_side.png"))
    print("wreck_side hidden")


if __name__ == "__main__":
    main()
