import sys; sys.path.insert(0,'/workspace/foe_walks/coilspire_v2/spell_v1')
from sheet import *
NF=132
REST=(0,0,0,0); WIND=(7,170,-15,0.8); SLAM=(-7,0,25,1.0); HOLD=(-6,0,25,0.9)
KEYS=[(0,REST),(8,REST),(26,WIND),(30,SLAM),(64,HOLD),(98,REST),(132,REST)]
ez=lambda x:float(np.clip(x,0,1))**2*(3-2*float(np.clip(x,0,1)))
def params(f):
    for (a,pa),(b,pb) in zip(KEYS[:-1],KEYS[1:]):
        if a<=f<=b: e=ez((f-a)/(b-a)); return tuple(x+(y-x)*e for x,y in zip(pa,pb))
def fxs(f):
    fx={}
    if 8<=f<31: fx['chg']=ez((f-8)/18)*(1 if f<29 else 0.5)
    if f>=28:
        grow=ez((f-28)/22); fade=1-ez((f-70)/30)
        if fade>0.01: fx['web']=0.15+0.85*grow; fx['webk']=min(1,grow*1.5)*fade
    if 44<=f<72: fx['sn']=ez((f-44)/14); fx['snk']=1-ez((f-64)/8)
    if 46<=f<66: fx['hit']=1
    if 64<=f<84: u=(f-64)/20; fx['bst']=0.6*(1-ez((u-0.3)/0.7)); fx['bsz']=0.8+0.35*u
    return fx
def frame(n):
    G=Image.new('RGBA',(1920,1080))
    for q,dn in enumerate('nesw'):
        g=sc(dn,('',)+params(n)+(fxs(n),),crop=False,label=False)
        dv=np.array(DV[dn],float); dv/=np.linalg.norm(dv); d=ImageDraw.Draw(g)
        d.text((24,14),dn.upper(),font=fnt,fill=(220,235,255,255),stroke_width=4,stroke_fill=(0,0,0,255))
        cc=np.array([150,48]); nn=np.array([-dv[1],dv[0]]); a_=cc-dv*40; b_=cc+dv*40; d.line([tuple(a_),tuple(b_)],fill=(140,200,255,255),width=8)
        d.polygon([tuple(b_+dv*16),tuple(b_-dv*6+nn*14),tuple(b_-dv*6-nn*14)],fill=(140,200,255,255))
        G.alpha_composite(g,((q%2)*960,(q//2)*540))
    return G.convert('RGB')
if __name__=='__main__':
    os.makedirs('_f',exist_ok=True); a,b=int(sys.argv[1]),int(sys.argv[2])
    for i in range(a,b): frame(i).save(f'_f/{i:05d}.png',compress_level=1)
