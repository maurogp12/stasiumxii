from h import *
from PIL import Image, ImageDraw
import colorsys
CAM=None
BV=Vector(json.load(open(B+'/camera.json'))['toward_camera_world'])
def dv(F): return BV
def draw(F, ph, idle, img, ox, oy, sc=1.0, ref=None):
    root=Matrix.Rotation(math.radians(FY[F]),4,'Z'); M=rig.pose(ph,idle=idle,cheat=rig.CHEAT[F],facing=F)
    D=dv(F); tris=[]
    for i,k in enumerate(sorted(P)):
        vs=[root@(M[k]@v) for v in P[k][0]]
        h=(hash(k.rstrip('_RL'))%360)/360.0
        light=0.75 if k.endswith('_L') else 1.0
        if k.startswith('axe'): col=(200,60,60) if k.endswith('_R') else (120,40,40)
        elif k.startswith(('forearm','upperarm','hand')): col=(60,120,220) if k.endswith('_R') else (40,70,140)
        elif k.startswith(('thigh','shin','boot')): col=(90,170,90) if k.endswith('_R') else (60,110,60)
        else: col=(170,170,170)
        cd=sum((p for p in vs),Vector())/len(vs); dp=cd.dot(D)
        for f in P[k][1]:
            pts=[vs[j] for j in f]; d=dp*1000+sum(p.dot(D) for p in pts)/len(pts)
            tris.append((d,[(ox+(pj(p,F)[0])*sc, oy+(pj(p,F)[1])*sc) for p in pts],col))
    tris.sort(key=lambda t:t[0])
    dr=ImageDraw.Draw(img)
    for d,pp,c in tris: dr.polygon(pp,fill=c)
    J,_=joints(F,ph,idle)
    for n,c in (('R',(255,255,0)),('L',(255,160,0))):
        for jn in ('_sh','_el','_grip','_head'):
            x,y=J[n+jn]; dr.ellipse([ox+x*sc-3,oy+y*sc-3,ox+x*sc+3,oy+y*sc+3],outline=c,width=2)
    x,y=J['chest']; dr.rectangle([ox+x*sc-3,oy+y*sc-3,ox+x*sc+3,oy+y*sc+3],outline=(255,0,255),width=2)
def sheet(path, frames={'S':[None,0,3,6,9],'E':[None,1,4,7,10]}):
    W,H=512,360; img=Image.new('RGB',(W*5,H*2),(30,30,40))
    for r,F in enumerate('SE'):
        for c,ph in enumerate(frames[F]):
            draw(F,ph,ph is None,img,c*W,r*H)
    img.save(path)
def rows(path, frames={'S':[None,0,3,6,9],'E':[None,1,4,7,10]}, facings='SE'):
    W,H=300,290; img=Image.new('RGB',(W*5,H*len(facings)),(30,30,40))
    for r,F in enumerate(facings):
        for c,ph in enumerate(frames[F]):
            tmp=Image.new('RGB',(512,360),(30,30,40)); draw(F,ph,ph is None,tmp,0,0)
            img.paste(tmp.crop((110,70,410,360)),(c*W,r*H))
    img.save(path)
def big(path, F, phs):
    W,H=340,260; img=Image.new('RGB',(W*len(phs),H),(30,30,40))
    for c,ph in enumerate(phs):
        tmp=Image.new('RGB',(512,360),(30,30,40)); draw(F,ph,ph is None,tmp,0,0,sc=1.0)
        img.paste(tmp.crop((110,90,450,350)),(c*W,0))
    img.save(path)
