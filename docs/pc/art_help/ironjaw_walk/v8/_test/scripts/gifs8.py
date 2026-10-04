import numpy as np
from PIL import Image, ImageDraw, ImageFont
ROOT='/workspace/art/ironjaw_full/v4_hd/_v8'; V7='/workspace/art/ironjaw_full/v4_hd/_v7'
DUR=[60,60,60,60,60,50,60,60,60,60,60,50]; BG=(0x6b,0x68,0x60)
def on(im): c=Image.new('RGBA',im.size,BG+(255,)); c.alpha_composite(im); return c.convert('RGB')
for F in 'SE':
    ims=[on(Image.open(f'{ROOT}/frames/ironjaw_walk_{F}_f{i:02d}.png').convert('RGBA')) for i in range(12)]
    pal=ims[0].quantize(colors=255, method=Image.MEDIANCUT, kmeans=1)
    q=[im.quantize(palette=pal, dither=Image.FLOYDSTEINBERG) for im in ims]
    q[0].save(f'{ROOT}/walk_{F}.gif', save_all=True, append_images=q[1:], duration=DUR, loop=0, disposal=1, optimize=False)
# legs v7 vs v8, S f00 f03 f06 f09, 3x
FB=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',18); FS=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',15)
x0,y0,x1,y1,sc=180,185,360,345,3; W,H=(x1-x0)*sc,(y1-y0)*sc; G=8; LW=70; TH=34
can=Image.new('RGB',(LW+4*(W+G),TH+2*(H+G)+28),(24,24,24)); d=ImageDraw.Draw(can)
d.text((LW,6),'Ironjaw walk S - legs, v7 vs v8 (3x nearest, crop x180-360 y185-345)',fill=(235,235,235),font=FB)
for c,i in enumerate([0,3,6,9]):
    for r,(root,lab) in enumerate([(f'{V7}/walk','v7'),(f'{ROOT}/frames','v8')]):
        im=on(Image.open(f'{root}/ironjaw_walk_S_f{i:02d}.png').convert('RGBA')).crop((x0,y0,x1,y1)).resize((W,H),Image.NEAREST)
        X=LW+c*(W+G); Y=TH+r*(H+G); can.paste(im,(X,Y))
        dd=ImageDraw.Draw(can); dd.rectangle([X,Y,X+92,Y+24],fill=(0,0,0)); dd.text((X+5,Y+3),f'{lab}  f{i:02d}',fill=(255,230,0),font=FB)
    d.text((8,TH+H//2),'v7',fill=(235,235,235),font=FB); d.text((8,TH+H+G+H//2),'v8',fill=(235,235,235),font=FB)
d.text((LW,TH+2*(H+G)+4),'v8: box clips -> part-alpha snap / soft capsule caps; S thighs = painted keys (short-fwd / medium-down / long-back), stretch 0.9-1.1; leg paint graded to v7.',fill=(200,200,200),font=FS)
can.save(f'{ROOT}/legs_v7_vs_v8_S.png'); print(can.size)
