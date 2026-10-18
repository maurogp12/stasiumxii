from PIL import Image,ImageDraw;import json,sys
shots=['rest','idle','chop','spin'];H=75;S=240
out=Image.new('RGB',(130+S*8,S*2+20),(150,150,150));d=ImageDraw.Draw(out)
for r,v in enumerate(['before','after']):
  C=json.load(open(f'r_{v}/crops.json'));d.text((6,20+r*S+S//2),v.upper(),fill=(0,0,0))
  for i,s in enumerate(shots):
    im=Image.open(f'r_{v}/{s}.png').convert('RGB');W=im.width
    for j,h in enumerate(['RightHand','LeftHand']):
      x,y=C[s][h];x*=W;y*=W
      out.paste(im.crop((int(x-H),int(y-H),int(x+H),int(y+H))).resize((S,S)),(130+(i*2+j)*S,20+r*S))
      if r==0:d.text((130+(i*2+j)*S+4,4),f'{s} {h}',fill=(0,0,0))
d.text((4,4),'CONCEPTO',fill=(120,0,0))
out.save(sys.argv[1],quality=85)
