# Caster stand-ins (Mauro 29 Sep 2026: "Recolor the existing biome melee
# trash as caster stand-ins … Real caster art is OPEN"). Each Room 1 caster is
# a door melee painting recoloured toward the door's bolt colour, with a soft
# glow rim and a bright spark at the raised side so it reads as a spellcaster.
# Output: art/stasis/foes/caster_<id>.png (same 288x320 frame as the source).
# Run: python3 build_tools/art/foes_hd/make_casters.py
import os
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FOES = os.path.join(ROOT, "art", "stasis", "foes")
# door bolt colours (Caster Bolt VFX sheet): cream-gold, teal, amber, pale ice, gold lightning
TINT = {
    "crosshaven": (242, 214, 140),
    "brinewake": (70, 214, 205),
    "slagcrown": (255, 150, 60),
    "windmere": (200, 232, 255),
    "stormspire": (255, 214, 90),
}
CASTERS = [
    ("scribe_bolt", "scarecrow_drudge", "crosshaven"),
    ("bell_chanter", "threshling", "crosshaven"),
    ("gullkin_hex", "brine_gullkin", "brinewake"),
    ("tide_adept", "silt_raider", "brinewake"),
    ("ember_cantor", "cinder_imp", "slagcrown"),
    ("kiln_voice", "slag_mite", "slagcrown"),
    ("white_adept", "gustling", "windmere"),
    ("gale_chanter", "frost_wisp", "windmere"),
    ("arc_adept", "volt_mote", "stormspire"),
    ("high_cantor", "sparkin", "stormspire"),
]


def make(out_id, src, door):
    im = Image.open(os.path.join(FOES, src + ".png")).convert("RGBA")
    a = np.asarray(im).astype(np.float32)
    rgb, alpha = a[..., :3], a[..., 3:4]
    tint = np.array(TINT[door], np.float32)
    lum = rgb.mean(axis=2, keepdims=True) / 255.0
    # Keep the painted shading, pull the hue toward the door colour.
    toned = np.clip(tint * (0.25 + lum * 1.1), 0, 255)
    mixed = rgb * 0.35 + toned * 0.65
    base = Image.fromarray(np.dstack([mixed, alpha]).astype(np.uint8), "RGBA")
    # Glow rim behind the body.
    mask = base.getchannel("A").filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(6))
    glow = Image.new("RGBA", base.size, tuple(int(c) for c in tint) + (0,))
    glow.putalpha(mask.point(lambda v: int(v * 0.55)))
    out = Image.alpha_composite(glow, base)
    # A spell spark at the upper side of the silhouette (the casting hand).
    arr = np.asarray(base.getchannel("A"))
    ys, xs = np.nonzero(arr > 128)
    if len(ys):
        top = ys.min() + (ys.max() - ys.min()) * 0.28
        row = xs[np.abs(ys - top) < 3]
        cx = int(row.max()) if len(row) else int(xs.max())
        cy = int(top)
        spark = Image.new("RGBA", base.size, (0, 0, 0, 0))
        sp = np.zeros((base.size[1], base.size[0], 4), np.float32)
        yy, xx = np.mgrid[0:base.size[1], 0:base.size[0]]
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        core = np.clip(1.0 - d / 10.0, 0, 1)
        halo = np.clip(1.0 - d / 26.0, 0, 1) ** 2
        col = tint * 0.5 + 127
        sp[..., :3] = col
        sp[..., 3] = np.clip(core * 255 + halo * 140, 0, 255)
        spark = Image.fromarray(sp.astype(np.uint8), "RGBA")
        out = Image.alpha_composite(out, spark)
    out.save(os.path.join(FOES, f"caster_{out_id}.png"), optimize=True)


if __name__ == "__main__":
    for out_id, src, door in CASTERS:
        make(out_id, src, door)
        print("caster", out_id)
