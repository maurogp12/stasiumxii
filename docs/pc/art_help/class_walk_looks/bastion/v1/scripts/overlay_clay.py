"""cand frame with the clay outline + joints, 2x: overlay_clay.py DIR F i out.png"""
import sys, json, numpy as np, cv2
from PIL import Image
D, F, i, OUT = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
B = '/workspace/handoff/class_walk_blockouts/bastion/'
im = np.asarray(Image.open(f'{D}/bastion_walk_{F}_f{i:02d}.png').convert('RGBA')).astype(float)
cl = np.asarray(Image.open(f'{B}clay/bastion_walk_{F}_f{i:02d}.png').convert('RGBA'))
a = im[..., 3:] / 255.; comp = np.ascontiguousarray((im[..., :3] * a + 128 * (1 - a)).astype(np.uint8))
comp = cv2.resize(comp, None, fx=2, fy=2, interpolation=cv2.INTER_NEAREST)
cs, _ = cv2.findContours(cv2.resize((cl[..., 3] > 127).astype(np.uint8), None, fx=2, fy=2, interpolation=cv2.INTER_NEAREST), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
cv2.drawContours(comp, cs, -1, (255, 255, 0), 1)
j = json.load(open(B + 'joints_512.json'))['facings'][f'walk_{F}'][f'f{i:02d}']['joints']
for k, v in j.items():
    p = (int(v[0] * 2), int(v[1] * 2)); cv2.circle(comp, p, 3, (255, 0, 0) if k.startswith('R_') else (0, 160, 255) if k.startswith('L_') else (0, 255, 0), -1)
Image.fromarray(comp).crop((240, 80, 800, 720)).save(OUT)
