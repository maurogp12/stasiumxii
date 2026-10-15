import numpy as np, json, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont
K=0.44*3; TWp,THp=228,114; ST=json.load(open('walk_step.json'))
SRC={'s':'e','w':'e','e':'n','n':'n'}; DV={'n':(-2,-1),'e':(2,-1),'s':(2,1),'w':(-2,1)}
FR={d:[Image.open(f'../strips/body_only/caldera_walk_{d}.png').crop((i*288,0,i*288+288,336)) for i in range(8)] for d in 'nesw'}
FR={d:[im.resize((round(288*K),round(336*K)),Image.LANCZOS) for im in v] for d,v in FR.items()}
fnt=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',30)
def grid(w,h,cx,cy):
    im=Image.new('RGBA',(w,h),(34,46,30,255)); d=ImageDraw.Draw(im)
    for i in range(-14,15):
        for j in range(-14,15):
            x=cx+(i-j)*TWp/2; y=cy+(i+j)*THp/2; col=(86,140,60,255) if (i+j)%2 else (74,124,52,255)
            d.polygon([(x,y-THp/2),(x+TWp/2,y),(x,y+THp/2),(x-TWp/2,y)],fill=col)
    d.ellipse([cx-4,cy-4,cx+4,cy+4],fill=(255,255,255,120))   # tile-centre marker
    return im
def shadow(w):
    sh=Image.new('RGBA',(w,w//3)); ImageDraw.Draw(sh).ellipse([0,0,w-1,w//3-1],fill=(0,0,0,90)); return sh.filter(ImageFilter.GaussianBlur(2))
SHJ=json.load(open('shadow.json'))
def shadow2(dn):
    s=SHJ[dn]; w=int(s['w']*K*1.1); h=max(8,w//4); sh=Image.new('RGBA',(w,h)); ImageDraw.Draw(sh).ellipse([0,0,w-1,h-1],fill=(0,0,0,100)); return sh.filter(ImageFilter.GaussianBlur(3))
SHD={d:shadow2(d) for d in 'nesw'}
def putsh(g,dn,bx,by):   # ellipse centre on the planted-foot ground line, under the feet span
    s=SHJ[dn]; S_=SHD[dn]; x=bx+(s['cx']-144)*K; y=by+(s['y']-300)*K; g.alpha_composite(S_,(int(x-S_.width/2),int(y-S_.height/2)))
BIG=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',96)
NAME={'n':'up-left','e':'up-right','s':'down-right','w':'down-left'}
def label(g,dn,x,y,sub):
    d=ImageDraw.Draw(g); d.text((x,y),dn.upper(),font=BIG,fill=(255,236,190,255),stroke_width=5,stroke_fill=(20,10,5,255))
    dv=np.array(DV[dn],float); u=dv/np.linalg.norm(dv); c=np.array([x+170,y+55]); a=c-u*55; b=c+u*55
    d.line([tuple(a),tuple(b)],fill=(255,150,50,255),width=12); n_=np.array([-u[1],u[0]])
    d.polygon([tuple(b+u*22),tuple(b-u*10+n_*20),tuple(b-u*10-n_*20)],fill=(255,150,50,255))
    d.text((x+250,y+30),NAME[dn]+'  '+sub,font=fnt,fill=(255,236,190,255),stroke_width=3,stroke_fill=(20,10,5,255))
def frame(t):
    G=Image.new('RGBA',(1920,1080),(20,24,20,255))
    if t<4.0:
        fi=int(t*11)%8
        for q,dn in enumerate('nesw'):
            qx,qy=(q%2)*960,(q//2)*540; cx,cy=480,420; g=grid(960,540,cx,cy)
            putsh(g,dn,cx,cy); g.alpha_composite(FR[dn][fi],(round(cx-144*K),round(cy-300*K)))
            label(g,dn,20,10,f"in place f{fi}"); G.alpha_composite(g,(qx,qy))
        return G.convert('RGB')
    k=int((t-4.0)//3.0); dn='nesw'[min(k,3)]; tt=(t-4.0)-3.0*min(k,3)
    cx,cy=960,600; g=grid(1920,1080,cx,cy); step=ST[SRC[dn]]*K; fi=int(tt*11)%8
    dx=int(tt*11)*step-1.5*11*step   # body advances one stride step per anim frame, so the planted foot stays put   # starts left of centre, crosses it at mid-segment; foot travel per anim frame == step
    dv=DV[dn]; bx=cx+np.sign(dv[0])*dx; by=cy+np.sign(dv[1])*0.5*dx
    putsh(g,dn,bx,by); g.alpha_composite(FR[dn][fi],(round(bx-144*K),round(by-300*K)))
    label(g,dn,30,20,f"walking f{fi}")
    G.alpha_composite(g); return G.convert('RGB')
if __name__=='__main__':
    od='/workspace/foe_walks/caldera_out/_wprev'; os.makedirs(od,exist_ok=True)
    a,b=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a,b): frame(i/24).save(f'{od}/{i:05d}.png',compress_level=1)
