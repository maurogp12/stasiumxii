import sys; sys.path.insert(0, '/workspace/scratch/ij_walk/rig')
from build import *
from PIL import ImageDraw
prepare()
row = []
for fac in 'SE':
    idle = J['idle_' + fac]
    fix = near_axe_fix(fac) if CFG['near_axe_fix'][fac] else (0.0, {})
    print(fac, 'fix', fix)
    for fd in (0.0, fix[0]):
        rgb, al, layers, owner, Ms, meta, order = render(fac, idle, idle, fd)
        cell = compose_cell(rgb, al)
        ys, xs = np.nonzero(al); print(fac, fd, 'bbox', xs.min(), xs.max(), ys.min(), ys.max(), 'h', ys.max() - ys.min() + 1, 'meta', meta)
        c = Image.new('RGBA', (CW, CH), (200, 200, 200, 255)); c.alpha_composite(Image.fromarray(cell)); dr = ImageDraw.Draw(c)
        for n, p in idle['joints'].items(): dr.ellipse([p[0] - 1.5, p[1] - 1.5, p[0] + 1.5, p[1] + 1.5], fill=(0, 255, 0))
        dr.line([(0, 329), (512, 329)], fill=(255, 0, 0))
        row.append(c)
    ref = Image.new('RGBA', (CW, CH), (200, 200, 200, 255)); ref.alpha_composite(Image.open(f'/workspace/art/ironjaw_full/v4_hd/_norim/idle/ironjaw_idle_{fac}_f00.png').convert('RGBA'))
    ImageDraw.Draw(ref).line([(0, 329), (512, 329)], fill=(255, 0, 0)); row.append(ref)
    a = np.asarray(Image.open(f'/workspace/art/ironjaw_full/v4_hd/_norim/idle/ironjaw_idle_{fac}_f00.png'))[..., 3] > 0
    ys, xs = np.nonzero(a); print(fac, 'painted bbox', xs.min(), xs.max(), ys.min(), ys.max())
M = Image.new('RGB', (CW * 3, CH * 2))
for i, c in enumerate(row): M.paste(c.convert('RGB'), ((i % 3) * CW, (i // 3) * CH))
M.save('test_idle.png')
json.dump(INFO, open('info_tmp.json', 'w'), indent=1, default=lambda o: o.tolist() if hasattr(o, 'tolist') else str(o))
