from ngengine import *
cells={}
N=9
for x in range(N):
    for y in range(N):
        d=x-y+ (1 if (x*7+y*3)%5==0 else 0)
        t='golden_plains' if x+y<5 else ('frost_grass' if x+y<9 else 'snow')
        if (x,y) in [(6,1),(1,6),(7,2)]: t='frost_grass'
        if (x,y) in [(2,1)]: t='frost_grass'
        if (x,y) in [(5,6),(6,6),(6,5)]: t='frost_grass'
        cells[(x,y)]=dict(t=t,h=0)
can,_=render(cells,[],lips=False,pad=(20,20,20,20),bg=(110,110,110,255))
can.save('tmp/p_trans.png')
w,hh=can.size
can.crop((w//2-300,hh//2-200,w//2+300,hh//2+150)).resize((1200,700),Image.LANCZOS).save('tmp/p_trans_zoom.png')
