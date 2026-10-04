import sys
from PIL import Image, ImageDraw
src,F,pas,out=sys.argv[1:5]
crop=(60,25,440,350) if F=="S" else (60,40,440,340)
cw,ch=crop[2]-crop[0],crop[3]-crop[1]
can=Image.new('RGB',(4*cw,3*ch),(236,234,228)); d=ImageDraw.Draw(can)
for f in range(12):
    im=Image.open('%s/%s/walk_%s_f%02d.png'%(src,pas,F,f)).convert('RGBA').crop(crop)
    x,y=(f%4)*cw,(f//4)*ch; can.paste(im,(x,y),im); d.text((x+4,y+2),'f%02d'%f,fill=(200,0,0))
can.save(out)
