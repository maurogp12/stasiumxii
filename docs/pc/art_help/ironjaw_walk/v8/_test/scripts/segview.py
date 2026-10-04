import sys, json, numpy as np, cv2
from PIL import Image
root,F,idx,x0,y0,x1,y1,sc,out=sys.argv[1:10]; x0,y0,x1,y1,sc=map(int,(x0,y0,x1,y1,sc))
d=json.load(open(f'{root}/_dbg/clips_{F}.json')); tiles=[]
for i in map(int,idx.split(',')):
    fr=np.asarray(Image.open(f'{root}/walk/ironjaw_walk_{F}_f{i:02d}.png').convert('RGBA')).astype(np.float32)
    a=fr[...,3:4]/255; im=(fr[...,:3]*a+np.array([107,104,96])*(1-a)).astype(np.uint8)[y0:y1,x0:x1]
    im=cv2.resize(im,None,fx=sc,fy=sc,interpolation=cv2.INTER_NEAREST)
    for s in d[str(i)]:
        a0,b0,a1,b1=s['seg']; cv2.line(im,(sc*(a0-x0)+sc//2,sc*(b0-y0)+sc//2),(sc*(a1-x0)+sc//2,sc*(b1-y0)+sc//2),(0,255,255),1)
        cv2.putText(im,s['layer'],(sc*(a0-x0)+3,sc*(b0-y0)),0,0.35,(0,255,255),1)
    cv2.putText(im,f'{F} f{i:02d}',(4,14),0,0.5,(255,255,0),1); tiles.append(im)
Image.fromarray(np.concatenate(tiles,1)).save(out)
