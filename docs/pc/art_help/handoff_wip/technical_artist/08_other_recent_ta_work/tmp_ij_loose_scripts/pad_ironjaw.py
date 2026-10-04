from pathlib import Path
from PIL import Image
import hashlib, json
base=Path('/workspace/art_src/blockout/ironjaw_walk')
src=base/'renders'; dst=base/'renders_512'
for pas in ('clay','sides','sil','grid'):
    out=dst/pas; out.mkdir(parents=True,exist_ok=True)
    for p in sorted((src/pas).glob('*.png')):
        if '_strip' in p.name: continue
        # only the 26 walk frames + 2 idle files per facing
        F='S' if '_S_' in p.name or p.name.endswith('_S.png') else 'E'
        y=15 if F=='S' else 31
        im=Image.open(p).convert('RGBA')
        if im.size != (460,360): raise ValueError((p,im.size))
        cell=Image.new('RGBA',(512,360),(0,0,0,0))
        cell.alpha_composite(im,(26,y))
        # no y crop is intended; source y shift fits only if transparent at bottom
        cell.save(out/p.name,optimize=True)
sha={}
for p in sorted(dst.glob('*/*.png')):
    h=hashlib.sha256(p.read_bytes()).hexdigest()
    sha[str(p.relative_to(dst))]=h
man={
 'cell':[512,360],
 'pivot':[256,329],
 'offset_from_460_render':{'x':26,'y_S':15,'y_E':31},
 'note':'Pivot = idle soles per facing, to match the HD paintings (idle soles on row 329). Walk contact soles land up to ~15 px (S) / ~20 px (E) below the pivot in a true 2:1 view; that is correct, keep it.',
 'sha256':sha,
}
(dst/'manifest_512.json').write_text(json.dumps(man,indent=1)+'\n')
print('padded',len(sha),'files; manifest',dst/'manifest_512.json')
