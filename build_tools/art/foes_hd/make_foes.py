# Stasis foes, HD pass (Mauro 29 Sep 2026: "Monster and boss looking lame").
# Bosses: cut the full painted boss from the hub RAID tile art (the same boss
# the door shows, much higher detail than the old 144x160 package crops) with
# the BiRefNet matting model (rembg), then fitted to a 288x320 canvas, feet on
# the shared row. The board draws foes at the same world size, so the extra
# pixels are detail, not size.
# Trash: the old crops re-matted at 4x with BiRefNet for clean edges, then a
# light sharpen + saturation lift, on the same 288x320 canvas.
# Captain Brineclaw's tile needs the HRSOD model (the general one drops the
# ship). Slagheart's tile painting fills the whole card (no figure to cut), so
# he keeps his package crop, cleaned like the trash. Thin wispy foes (Frost
# Wisp, Gale Skitter, Volt Mote) lose strands in matting: they are only
# upscaled and lifted. Boss cuts fade out near the tile's crop edges so a
# cropped cape or spire never ends in a hard straight line.
# Run: python3 build_tools/art/foes_hd/make_foes.py   (downloads the model once)
import os
from PIL import Image, ImageEnhance, ImageFilter
from rembg import remove, new_session
import numpy as np
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src")
OUT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "art", "stasis", "foes"))
W, H = 288, 320
FOOT = 300  # foot row on the 320 canvas (= 150 on the old 160 cell)
# Boss art box inside each 292x410 tile (the painted card, no frame).
BOSSES = {
    "warden_of_the_sheaves": ("raid_crosshaven.png", (55, 115, 240, 330)),
    "captain_brineclaw": ("raid_brinewake.png", (53, 115, 233, 330)),
    "serra_the_gale_sentinel": ("raid_windmere.png", (59, 125, 234, 330)),
    "tyrant_coilspire": ("raid_stormspire.png", (72, 125, 222, 305)),
}


def clean_alpha(im):
    a = np.asarray(im.getchannel("A")).astype(np.float32)
    solid = a > 128
    lab, n = ndi.label(solid)
    if n > 1:
        sizes = ndi.sum(solid, lab, range(1, n + 1))
        keep = [i + 1 for i, v in enumerate(sizes) if v >= 0.04 * sizes.max()]
        solid = np.isin(lab, keep)
    a = np.where(ndi.binary_dilation(solid, iterations=1), a, 0)
    arr = np.asarray(im).copy()
    arr[..., 3] = a.clip(0, 255).astype(np.uint8)
    out = Image.fromarray(arr, "RGBA")
    return out.crop(out.getbbox())


def place(fig, max_w, max_h):
    s = min(max_w / fig.width, max_h / fig.height)
    fig = fig.resize((max(1, int(fig.width * s)), max(1, int(fig.height * s))), Image.LANCZOS)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(fig, ((W - fig.width) // 2, FOOT - fig.height))
    return canvas


def lift(im, sat=1.12, contrast=1.08, sharp=60):
    a = im.getchannel("A")
    rgb = im.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(sat)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    rgb = rgb.filter(ImageFilter.UnsharpMask(radius=1.4, percent=sharp, threshold=2))
    rgb.putalpha(a)
    return rgb


MODEL = {"captain_brineclaw": "birefnet-hrsod"}
KEEP_OLD = {"frost_wisp", "gale_skitter", "volt_mote"}


def fade_edges(im, frac=0.08):
    arr = np.asarray(im).astype(np.float32)
    h, w = arr.shape[:2]
    ramp_x = np.clip(np.minimum(np.arange(w), w - 1 - np.arange(w)) / (w * frac), 0, 1)
    ramp_y = np.clip(np.arange(h) / (h * frac), 0, 1)  # top only; feet stay
    arr[..., 3] *= ramp_x[None, :] * ramp_y[:, None]
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")


def main(only=None):
    s = None
    for name, (tile, box) in BOSSES.items():
        if only and name != only:
            continue
        im = Image.open(os.path.join(SRC, tile)).convert("RGB").crop(box)
        im = im.resize((im.width * 3, im.height * 3), Image.LANCZOS)
        s = new_session(MODEL.get(name, "birefnet-general"))
        fig = clean_alpha(fade_edges(remove(im, session=s)))
        place(lift(fig), W - 8, FOOT - 6).save(os.path.join(OUT, name + ".png"), optimize=True)
        print("boss", name)
    for f in sorted(os.listdir(SRC)):
        if not f.startswith("old_"):
            continue
        name = f[4:-4]
        if name in BOSSES or (only and name != only):
            continue
        old = Image.open(os.path.join(SRC, f)).convert("RGBA")
        if name in KEEP_OLD:
            big = old.resize((W, H), Image.LANCZOS)
            lift(big, sat=1.15, contrast=1.1, sharp=80).save(os.path.join(OUT, name + ".png"), optimize=True)
            print("kept", name)
            continue
        if s is None:
            s = new_session("birefnet-general")
        bb = old.getbbox()
        body = old.crop(bb)
        flat = Image.new("RGB", body.size, (0, 0, 0))
        flat.paste(body, mask=body.getchannel("A"))
        big = flat.resize((body.width * 4, body.height * 4), Image.LANCZOS)
        fig = clean_alpha(remove(big, session=s))
        # Keep the old on-board size: old height in the 160 cell x2.
        h = (bb[3] - bb[1]) * 2
        w = (bb[2] - bb[0]) * 2
        fig = fig.resize((w, h), Image.LANCZOS)
        canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        canvas.alpha_composite(fig, (bb[0] * 2, bb[1] * 2))
        lift(canvas, sat=1.15, contrast=1.1, sharp=80).save(os.path.join(OUT, name + ".png"), optimize=True)
        print("trash", name)


if __name__ == "__main__":
    # One foe per process keeps memory low: python3 make_foes.py [name]
    import sys
    if len(sys.argv) > 1:
        main(sys.argv[1])
    else:
        import subprocess
        names = list(BOSSES) + sorted(f[4:-4] for f in os.listdir(SRC) if f.startswith("old_") and f[4:-4] not in BOSSES)
        names = [n for n in names if len(sys.argv) < 2 or n in sys.argv[1:]]
        for n in names:
            subprocess.run([sys.executable, __file__, n], check=True)
