import json,sys
from PIL import Image,ImageDraw
Image.MAX_IMAGE_PIXELS=None
P=Image.open('crosshaven_built_plate.jpg');I=json.load(open('build_info.json'));F=5;tag=sys.argv[1]
W=[(40,240),(290,38),(700,38),(990,235),(985,275),(800,462),(530,540),(330,440),(132,352)]
pts=[('bridge%d'%i,b['q']) for i,b in enumerate(I['bridge_info'])]+[('watergate%d'%i,q) for i,q in enumerate(I['watergates'])]+[('gate',I['gates'][0])]+[('corner%d'%i,q) for i,q in enumerate(W)]
tiles=[]
for n,(x,y) in pts:
  c=P.crop((int(x*F-300),int(y*F-230),int(x*F+300),int(y*F+170)));c.save(f'crops/{tag}_{n}.jpg',quality=90)
  ImageDraw.Draw(c).text((8,8),n,fill=(255,255,0));tiles.append(c)
S=Image.new('RGB',(600*4,400*((len(tiles)+3)//4)))
for i,c in enumerate(tiles):S.paste(c,((i%4)*600,(i//4)*400))
S.resize((S.width//2,S.height//2)).save(f'crops/{tag}_sheet.jpg',quality=85)
