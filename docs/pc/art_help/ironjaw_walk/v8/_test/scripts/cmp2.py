import sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
# cmp2.py out F idxs x0 y0 x1 y1 sc rootA labelA rootB labelB [...]
out,F,idx,x0,y0,x1,y1,sc=sys.argv[1:9]; x0,y0,x1,y1,sc=map(int,(x0,y0,x1,y1,sc)); roots=sys.argv[9:]
FN=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',13)
rows=[]
for r in range(0,len(roots),2):
    root,lab=roots[r],roots[r+1]; tiles=[]
    for i in map(int,idx.split(',')):
        a=Image.open(f'{root}/ironjaw_walk_{F}_f{i:02d}.png').convert('RGBA').crop((x0,y0,x1,y1))
        bg=Image.new('RGBA',a.size,(107,104,96,255)); bg.alpha_composite(a); b=bg.resize(((x1-x0)*sc,(y1-y0)*sc),Image.NEAREST)
        d=ImageDraw.Draw(b); d.rectangle([0,0,170,18],fill=(0,0,0)); d.text((4,2),f'{lab} {F} f{i:02d}',fill=(255,255,0),font=FN); tiles.append(b)
    row=Image.new('RGB',(sum(t.width+4 for t in tiles),tiles[0].height),(0,0,0)); x=0
    for t in tiles: row.paste(t,(x,0)); x+=t.width+4
    rows.append(row)
c=Image.new('RGB',(rows[0].width,sum(r.height+4 for r in rows)),(0,0,0)); y=0
for r in rows: c.paste(r,(0,y)); y+=r.height+4
c.save(out)
