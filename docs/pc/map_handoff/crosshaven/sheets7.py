from PIL import Image,ImageDraw
import json,numpy as np,cv2
Image.MAX_IMAGE_PIXELS=None
I=json.load(open('build_info.json'));F=5
P=Image.open('crosshaven_built_plate.jpg');M=cv2.imread('walkmask.png',0)
def ov(box):
  a=P.crop(box);m=M[box[1]:box[3],box[0]:box[2]];o=np.array(a).copy();o[m<128]=(o[m<128]*0.5+np.array([200,30,30])*0.5).astype('uint8');return a,Image.fromarray(o)
S=Image.new('RGB',(1800,800))
for j,B in enumerate(I['bridge_info']):
  x0,y0,x1,y1=B['bbox'];cx,cy=(x0+x1)//2,(y0+y1)//2;a,o=ov((cx-300,cy-200,cx+300,cy+200));S.paste(a,(j*600,0));S.paste(o,(j*600,400))
S.save('crops/v7_bridges_sheet.jpg',quality=85)
# walls: gate with both sides + 2 corners + both water gates
gx,gy=I['gates'][0];W_=I.get('wall',None)
boxes=[('main gate, wall both sides',(int(gx*F-450),int(gy*F-300),int(gx*F+450),int(gy*F+150)))]
for n,(x,y) in [('corner W',(132,352)),('corner N',(290,38))]:boxes.append((n,(int(x*F-300),int(y*F-200),int(x*F+300),int(y*F+200))))
for i,(x,y) in enumerate(I['watergates']):boxes.append((f'water gate {i}',(int(x*F-300),int(y*F-230),int(x*F+300),int(y*F+170))))
S=Image.new('RGB',(1800,1000));d=ImageDraw.Draw(S)
S.paste(P.crop(boxes[0][1]).resize((1200,600)),(0,0));d.text((8,8),boxes[0][0],fill=(255,255,0))
for k,(n,b) in enumerate(boxes[1:]):
  x_,y_=[(1200,0),(1200,300),(0,600),(600,600)][k];im=P.crop(b).resize((600,300) if k<2 else (600,400))
  S.paste(im,(x_,y_));d.text((x_+8,y_+8),n,fill=(255,255,0))
S.paste(Image.new('RGB',(600,400)),(1200,600))
S.save('crops/v7_walls_sheet.jpg',quality=85)
