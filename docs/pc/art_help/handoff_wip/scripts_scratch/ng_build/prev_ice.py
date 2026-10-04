from ngengine import *
cells={(x,y):dict(t='snow',h=0) for x in range(7) for y in range(7)}
for (x,y) in [(2,2),(3,2),(4,2),(2,3),(3,3),(4,3),(3,4),(4,4),(5,3),(2,4)]: cells[(x,y)]=dict(t='water',h=0)
can,_=render(cells,[],pad=(20,20,20,20),bg=(110,110,110,255))
can.save('tmp/p_ice.png')
w,hh=can.size
can.crop((w//2-250,hh//2-160,w//2+250,hh//2+160)).resize((1000,640),Image.LANCZOS).save('tmp/p_ice_zoom.png')
