import sys
from PIL import Image, ImageDraw
import numpy as np
def zoom(arr, box, z, out, marks=()):
    x0,y0,x1,y1=box
    bg=Image.new('RGBA',(arr.shape[1],arr.shape[0]),(122,104,78,255)); bg.alpha_composite(Image.fromarray(arr))
    c=bg.crop(box).convert('RGB').resize(((x1-x0)*z,(y1-y0)*z),Image.NEAREST)
    pad=28; C=Image.new('RGB',(c.width+pad,c.height+pad),(20,20,20)); C.paste(c,(pad,pad)); d=ImageDraw.Draw(C)
    for x in range(x0,x1):
        if x%5==0:
            d.line([(pad+(x-x0)*z,pad-6),(pad+(x-x0)*z,pad)],fill=(0,255,255))
            if x%10==0: d.text((pad+(x-x0)*z+1,2),str(x),fill=(0,255,255))
    for y in range(y0,y1):
        if y%5==0:
            d.line([(pad-6,pad+(y-y0)*z),(pad,pad+(y-y0)*z)],fill=(255,255,0))
            if y%10==0: d.text((1,pad+(y-y0)*z+1),str(y),fill=(255,255,0))
    for (kind,v,col) in marks:
        if kind=='h': d.line([(pad,pad+(v-y0)*z),(C.width,pad+(v-y0)*z)],fill=col)
        else: d.line([(pad+(v-x0)*z,pad),(pad+(v-x0)*z,C.height)],fill=col)
    C.save(out)
