#!/usr/bin/env python3
"""Place the P4 Ironjaw trial beside the painted reference.

The reference sheets live on the art / look-target branches. This script only
reads them and writes the comparison still used in the docs.
"""

import argparse
import os

from PIL import Image, ImageDraw, ImageFont


ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
RAW = os.path.join(ROOT, "docs", "pc", "media", "charselect", "ironjaw_raw")
OUT = os.path.join(ROOT, "docs", "pc", "media", "charselect", "ironjaw_turnaround.png")


def _on_dark(path):
    im = Image.open(path).convert("RGBA")
    plate = Image.new("RGBA", im.size, (48, 46, 44, 255))
    return Image.alpha_composite(plate, im).convert("RGB")


def _fit(im, h):
    scale = h / float(im.height)
    w = max(1, int(round(im.width * scale)))
    return im.resize((w, h), Image.Resampling.LANCZOS)


def _crop_base(sheet):
    # The approved base figure is the left panel of the look-target sheet.
    w, h = sheet.size
    # Left panel only. The next panel is Cragmaw in armour.
    panel = sheet.crop((0, 0, int(w * 0.18), h))
    return panel


def _label(draw, xy, text, font):
    draw.text(xy, text, fill=(235, 228, 214), font=font)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ref", required=True)
    parser.add_argument("--v7", default="")
    parser.add_argument("--shots", default="")
    parser.add_argument("--front", default="base_front.png")
    parser.add_argument("--three", default="base_three_quarter.png")
    parser.add_argument("--back", default="base_back.png")
    parser.add_argument("--out", default=OUT)
    args = parser.parse_args()

    body_h = 640
    gap = 16
    margin = 24
    header = 78
    shot_dir = args.shots or RAW
    ref = _fit(_crop_base(Image.open(args.ref).convert("RGB")), body_h)
    front = _fit(_on_dark(os.path.join(shot_dir, args.front)), body_h)
    three = _fit(_on_dark(os.path.join(shot_dir, args.three)), body_h)
    back = _fit(_on_dark(os.path.join(shot_dir, args.back)), body_h)
    panels = [
        (ref, "Painted base"),
        (front, "Trial, front"),
        (three, "Trial, three-quarter"),
        (back, "Trial, back"),
    ]
    if args.v7 and os.path.isfile(args.v7):
        v7 = _fit(Image.open(args.v7).convert("RGB"), body_h)
        panels.append((v7, "Walk frame v7"))
    width = margin * 2 + gap * (len(panels) - 1) + sum(p.width for p, _ in panels)
    canvas = Image.new("RGB", (width, header + body_h + 36), (28, 26, 24))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    draw.text((margin, 16), "Ironjaw male, P4 trial  |  painted reference beside the generated model", fill=(235, 228, 214), font=font)
    draw.text((margin, 40), "Does not reach the painted look. Blocky loft, procedural weave, disc face. Cragmaw is a separate slot pass.", fill=(196, 168, 132), font=font)
    x = margin
    for im, title in panels:
        canvas.paste(im, (x, header))
        _label(draw, (x, header + body_h + 8), title, font)
        x += im.width + gap
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    canvas.save(args.out)
    print("WROTE", args.out, canvas.size)


if __name__ == "__main__":
    main()
