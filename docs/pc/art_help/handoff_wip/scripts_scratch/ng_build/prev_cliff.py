from ngengine import *
import sys
mode=sys.argv[1] if len(sys.argv)>1 else 'strips'
cells={}
for x in range(8):
    for y in range(8):
        cells[(x,y)]=dict(t='snow',h=0)
for x in range(1,5):
    for y in range(1,4):
        cells[(x,y)]=dict(t='crag',h=3 if x<3 else 2)
cells[(5,2)]=dict(t='crag',h=1)
can,_=render(cells,[],faces=mode,pad=(40,20,20,20),bg=(110,110,110,255))
can.save('tmp/p_cliff.png')
w,hh=can.size
can.crop((150,0,750,380)).resize((1200,760),Image.LANCZOS).save('tmp/p_cliff_zoom.png')
