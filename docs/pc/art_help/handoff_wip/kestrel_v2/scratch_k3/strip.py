"""strip.py F frames x0,y0,x1,y1 out [dir] [zoom] : zoomed crops with the v2 clay outline in red"""
import sys, numpy as np, cv2
from PIL import Image
B='/workspace/handoff/class_walk_blockouts/kestrel/blockout_v3/clay/'
F=sys.argv[1]; fr=[int(x) for x in sys.argv[2].split(',')]; box=[int(v) for v in sys.argv[3].split(',')]; out=sys.argv[4]
D=sys.argv[5] if len(sys.argv)>5 else '/workspace/scratch/k3/try'; z=float(sys.argv[6]) if len(sys.argv)>6 else 2
tiles=[]
for i in fr:
    im=np.asarray(Image.open(f'{D}/kestrel_walk_{F}_f{i:02d}.png').convert('RGBA')).astype(float)
    cl=np.asarray(Image.open(f'{B}kestrel_walk_{F}_f{i:02d}.png').convert('RGBA'))
    bg=np.full(im.shape[:2]+(3,),200.); a=im[...,3:]/255; c=im[...,:3]*a+bg*(1-a)
    m=(cl[...,3]>127).astype(np.uint8); e=m-cv2.erode(m,np.ones((3,3),np.uint8)); c[e>0]=(255,0,0)
    t=c[box[1]:box[3],box[0]:box[2]].astype(np.uint8); t=cv2.resize(t,None,fx=z,fy=z,interpolation=cv2.INTER_NEAREST)
    cv2.putText(t,f'{F} f{i:02d}',(4,16),cv2.FONT_HERSHEY_SIMPLEX,0.5,(0,0,0),1); tiles.append(t)
Image.fromarray(np.hstack(tiles)).save(out)
