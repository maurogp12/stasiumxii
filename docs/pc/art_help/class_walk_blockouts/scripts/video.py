"""Showcase video per class: turntable, idle, walk S/E over a scrolling grid, attack S/E, skill, hit, death."""
import sys, math, json, subprocess, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont
W, H, PIV, PX = 1024, 720, (512, 590), 2 * 512 / (494.6236559139785 * 1.2)
def gp(x, y):
    r = np.array([1, 1]) / math.sqrt(2); fw = np.array([-1, 1]) / math.sqrt(2); p = np.array([x, y])
    return PIV[0] + p @ r * PX, PIV[1] - p @ fw * 0.5 * PX
def grid(scroll=(0, 0)):
    im = Image.new('RGB', (W, H), (232, 230, 222)); d = ImageDraw.Draw(im)
    for k in range(-14, 15):
        for a, b in (((k * 64, -900), (k * 64, 900)), ((-900, k * 64), (900, k * 64))):
            p, q = gp(*a), gp(*b); d.line([(p[0] + scroll[0], p[1] + scroll[1]), (q[0] + scroll[0], q[1] + scroll[1])], fill=(150, 170, 215), width=1)
    return im
try: FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 26)
except Exception: FONT = ImageFont.load_default()
def main():
    cls, out, label = sys.argv[1], sys.argv[2], sys.argv[3]
    J = json.load(open(f'{out}/joints_512.json'))['facings']
    seq = []
    def add(name, n, text, loops=1, scroll_F=None):
        acc = np.zeros(2)
        for _ in range(loops):
            for i in range(n):
                bg = grid(tuple(acc))
                seq.append((bg, f'{out}/show/{name}_f{i:02d}.png', text))
                if scroll_F:
                    j0 = J[f'walk_{scroll_F}'][f'f{i:02d}']['joints']; j1 = J[f'walk_{scroll_F}'][f'f{(i + 1) % 12:02d}']['joints']
                    sup = 'R' if j0['R_heel'][1] + j0['R_toe'][1] >= j0['L_heel'][1] + j0['L_toe'][1] else 'L'
                    stance = abs(j1[f'{sup}_heel'][1] - j0[f'{sup}_heel'][1]) < 6
                    acc += (2 / 1.2) * (np.array(j1[f'{sup}_heel']) - np.array(j0[f'{sup}_heel'])) if stance else (2 / 1.2) * np.array([-6.8, -3.4 if scroll_F == 'S' else 3.4])
    add('turn', 36, f'{label}: 3D blockout, turntable')
    add('idle_S', 12, 'Idle', loops=2)
    add('walk_S', 12, 'Walk, front (S)', loops=3, scroll_F='S')
    add('walk_E', 12, 'Walk, back (E)', loops=3, scroll_F='E')
    add('attack_S', 12, 'Attack, front', loops=2)
    add('attack_E', 12, 'Attack, back', loops=1)
    add('cast_S', 12, 'Skill', loops=2)
    add('hit_S', 8, 'Hit', loops=2)
    add('death_S', 13, 'Death')
    for _ in range(10): seq.append(seq[-1])
    os.makedirs(f'{out}/video_frames', exist_ok=True)
    for k, (bg, path, text) in enumerate(seq):
        im = Image.open(path).convert('RGBA'); fr = bg.copy(); fr.paste(im, (0, 0), im)
        d = ImageDraw.Draw(fr); d.rectangle([0, 0, W, 44], fill=(30, 30, 34)); d.text((16, 8), text, fill=(240, 220, 150), font=FONT)
        fr.save(f'{out}/video_frames/{k:04d}.png')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-framerate', '17.144', '-i', f'{out}/video_frames/%04d.png', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', f'{out}/{cls}_actions.mp4'], check=True)
    print('video', len(seq), 'frames')
if __name__ == '__main__': main()
