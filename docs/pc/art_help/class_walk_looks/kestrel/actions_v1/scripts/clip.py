"""Kestrel actions v1 - review clip: the five actions in all four facings (W = mirror of S, N = mirror of E), one facing at a
time at 1.2x on the iso ground (as the walk clip), then each action in all four facings side by side. 17.144 fps.
usage: clip.py OUT.mp4 [work_dir]"""
import os, sys, shutil, subprocess, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps
HERE = os.path.dirname(os.path.abspath(__file__)); FR = os.path.join(HERE, '..', 'frames')
OUT = sys.argv[1]; WK = sys.argv[2] if len(sys.argv) > 2 else OUT + '_frames'
W, H = 1280, 720; FPS = 17.144
ACTS = [('idle', 12, 'Idle'), ('attack', 12, 'Attack: draw and loose'), ('skill', 12, 'Skill: Mark Shot (aims high)'),
        ('hit', 8, 'Hit'), ('death', 13, 'Death')]
FAC = [('S', 'front, down-right (S)'), ('E', 'back, up-right (E)'), ('W', 'front, down-left (W, mirror of S)'), ('N', 'back, up-left (N, mirror of E)')]
FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 30)
F2 = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 20)
_C = {}
def get(act, d, i):
    k = (act, d, i)
    if k not in _C:
        src = {'S': 'S', 'W': 'S', 'E': 'E', 'N': 'E'}[d]; im = Image.open(f'{FR}/{act}_{src}_f{i:02d}.png').convert('RGBA')
        _C[k] = ImageOps.mirror(im) if d in 'WN' else im
    return _C[k]
def ground(S):
    im = Image.new('RGB', (W, H), (210, 214, 200)); d = ImageDraw.Draw(im); g = 64 * S / 2
    for k in range(-40, 40):
        x0 = k * g * 2
        d.line([(x0 - 2000, -1000), (x0 + 2000, 1000)], fill=(170, 180, 160)); d.line([(x0 - 2000, 1000), (x0 + 2000, -1000)], fill=(170, 180, 160))
    return im
def title(im, t, sub='Kestrel actions v1 · 17 fps'):
    dr = ImageDraw.Draw(im); dr.rectangle([0, 0, W, 50], fill=(25, 30, 28)); dr.text((16, 9), t, fill=(240, 220, 150), font=FONT)
    dr.text((W - 330, 15), sub, fill=(200, 200, 200), font=F2)
frames = []
def seq(act, n):
    idx = list(range(n)) * (2 if act in ('hit',) else 1) if act != 'death' else list(range(n)) + [n - 1] * 14
    if act in ('idle',): idx = list(range(n)) * 2
    return idx
G1, G4 = ground(1.2), ground(0.62)
for act, n, name in ACTS:
    for d, dn in FAC:
        for i in seq(act, n):
            bg = G1.copy(); spr = get(act, d, i); spr = spr.resize((int(512 * 1.2), int(360 * 1.2)), Image.LANCZOS)
            bg.paste(spr, (int(W / 2 - 256 * 1.2), int(H - 90 - 329 * 1.2)), spr); title(bg, f'{name}, {dn}'); frames.append(bg)
for act, n, name in ACTS:
    for i in seq(act, n):
        bg = G4.copy()
        for k, (d, dn) in enumerate(FAC):
            spr = get(act, d, i).resize((int(512 * 0.62), int(360 * 0.62)), Image.LANCZOS)
            cx = 160 + k * 320; bg.paste(spr, (int(cx - 256 * 0.62), int(H - 170 - 329 * 0.62)), spr)
            ImageDraw.Draw(bg).text((cx - 12, H - 150), d, fill=(40, 40, 40), font=FONT)
        title(bg, f'{name}: S, E, W, N'); frames.append(bg)
if os.path.isdir(WK): shutil.rmtree(WK)
os.makedirs(WK)
for k, im in enumerate(frames): im.save(f'{WK}/{k:04d}.png')
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-framerate', str(FPS), '-i', f'{WK}/%04d.png', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', OUT], check=True)
shutil.rmtree(WK); print(OUT, len(frames), 'frames')
