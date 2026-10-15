import numpy as np, sys
from PIL import Image, ImageDraw, ImageFont
src=open('/workspace/foe_walks/slag_out/work/poses.py').read(); exec(src[:src.index('OUT={}')])
RIG={'e':dict(LA=[(18,112),(80,100),(104,124),(96,200),(72,228),(62,276),(18,276)],RA=[(184,104),(232,108),(272,130),(272,276),(214,276),(212,232),(222,200),(198,170)],
              LL=[(50,206),(143,206),(143,306),(48,306)],RL=[(143,206),(214,206),(224,306),(143,306)],ls=(84,118),rs=(190,118),lh=(100,210),rh=(180,210)),
     'n':dict(LA=[(24,112),(82,104),(104,124),(98,200),(86,232),(86,284),(24,284)],RA=[(186,104),(236,108),(262,130),(262,284),(214,284),(210,232),(214,200),(196,170)],
              LL=[(68,200),(146,200),(146,306),(64,306)],RL=[(146,200),(216,200),(222,306),(146,306)],ls=(80,118),rs=(194,118),lh=(108,206),rh=(182,206))}
ELB={'e':((48,182),(234,178)),'n':((54,182),(222,182))}
ERU=[np.array(Image.open('/workspace/art/bosses/slagheart_caldera_crown_5star/slagheart_caldera_crown_fx_eruption.png').convert('RGBA').crop((i*192,0,i*192+192,160))) for i in range(10)]
def eru(o,i,ax,ay,s=1.0):  # existing eruption fx, anchor (96,112) = impact point on floor
    im=Image.fromarray(o); f=Image.fromarray(ERU[i]); f=f.resize((round(192*s),round(160*s)),Image.LANCZOS)
    L=Image.new('RGBA',(288,336)); L.alpha_composite(f,(int(ax-96*s),int(ay-112*s))) if 0<=int(ax-96*s) and int(ax-96*s)+f.width<=288 else L.paste(f,(int(ax-96*s),int(ay-112*s)),f)
    im.alpha_composite(L); return np.array(im)
def shards(rng,n,cx,cy,sx,sy):
    pts=[(cx+rng.normal(0,sx),cy+rng.normal(0,sy),rng.uniform(2,4),(28,24,30)) for _ in range(n)]; return fxlib.soft_dots(pts,1.3,1.0)
OUT={}
for d in 'en':
    img,Pt,tor=build(d); R=RIG[d]
    rest=compose(d,Pt,tor)
    contact=compose(d,Pt,tor,ll=-26,rl=26,la=3,ra=3,bob=5)
    passing=compose(d,Pt,tor,ll=6,rl=-14,rly=24,la=-3,ra=-3,bob=-1)
    wind=fillgaps(ikpose(d,Pt,tor,(122,40),(166,40),1,-1,ly=-8),tor)
    strike=fillgaps(ikpose(d,Pt,tor,(120,236),(170,238),1,-1,ly=14),tor)
    sraise=compose(d,Pt,tor,rly=32,rl=-8,lx=-4,ly=-3,la=-3,ra=4); sdown=compose(d,Pt,tor,rl=4,ly=7,bob=3,la=6,ra=-4)
    cast=compose(d,Pt,tor,la=-4,ra=4,ly=-5,arm_dy=-3)
    hit=clamp(rimc(apply(lean(rest,-12,-2),M_rot(4,(144,300))),0.15))
    # crown: the spiked head/crown region from rest
    a=rest[...,3]>0; ys=np.nonzero(a.any(1))[0]; top=ys.min()
    cm=a&(Y<top+44)&(X>92)&(X<196); crown=np.where(cm[...,None],rest,0).astype(np.uint8)
    cy0,cx0=np.nonzero(cm); crown=shift(crown,0,(254-cy0.max()))
    heap=heapimg(tor,Pt) if 'heapimg' in dir() else None
    exec(open('/workspace/foe_walks/slag_out/work/sanim.py').read().split('def glow')[0].split('def heapimg')[1].join(['def heapimg','']) if False else '')
    out_={}
    rgx=np.random.default_rng(3)
    L=[('rest',solid(rest),None),('walk contact',solid(contact),None),('walk passing',solid(passing),None),('slam wind-up (rig)',solid(wind),None),
       ('slam strike (rig) + eruption',solid(strike),('eru',2,145,282,1.15)),('stomp raise',solid(sraise),None),('stomp impact + eruption',solid(sdown),('eru',1,186,296,0.9)),
       ('cast: eruption',solid(cast),('eru',4,144,300,1.3)),('hit',hit,('emb',)),('death burst',None,None),('death end: molten heap + crown',None,None)]
    OUT[d]=L; OUT[d+'_parts']=(Pt,tor,rest,crown)
# heap + death using slag heap builder
src2=open('/workspace/foe_walks/slag_out/work/sanim.py').read(); exec(src2[src2.index('def heapimg'):src2.index('def crack')])
for d in 'en':
    Pt,tor,rest,crown=OUT[d+'_parts']; rg=np.random.default_rng(9)
    heap=heapimg(tor,Pt,seed=13)
    # molten glow on the heap: brighten saturated crack pixels
    hm=heap[...,3]>0; c=heap[...,:3].astype(float); s_=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1); m=hm&(s_>0.45); c[m]=np.minimum(255,c[m]*1.35); heap[...,:3]=c.astype(np.uint8)
    end=paste(heap,crown)
    b=rest.copy(); b[N2<0.4]=0; hp=heap.copy(); hp[N2>0.45]=0; burst=paste(b,hp)
    bfx=[embers(rg,60,144,170,70,70,40),shards(rg,40,144,170,80,70),glow([60,120,230,300],26,(255,100,40),0.25)]
    efx=[stroke(lambda dr,i=i:dr.ellipse([110+i*14,190-i*16,140+i*14,222-i*16],fill=255),9,(120,108,98),0.3) for i in range(4)]+[embers(rg,12,144,280,50,8,8)]
    L=OUT[d]; new=[]
    for n,o,f in L:
        if n.startswith('death burst'): o=fx(solid(burst),bfx)
        elif n.startswith('death end'): o=fx(solid(end),efx)
        elif f and f[0]=='eru': o=eru(o,f[1],f[2],f[3],f[4])
        elif f and f[0]=='emb': o=fx(o,[embers(rg,12,170,140,26,30)])
        new.append((n,o))
    OUT[d]=new
    for i,(n,o) in enumerate(new): Image.fromarray(o).save(f'still_{d}_{i:02d}.png')
f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',24)
nc=len(OUT['e']); S=Image.new('RGB',(576*nc,(672+40)*2),(26,22,22)); dr=ImageDraw.Draw(S)
for r,(d,lab) in enumerate((('e','FRONT'),('n','BACK'))):
    for i,(n,o) in enumerate(OUT[d]):
        im=Image.fromarray(o).resize((576,672),Image.NEAREST); S.paste(im,(i*576,r*712+40),im); dr.text((i*576+10,r*712+8),f'{lab}  {n}',font=f,fill=(240,215,180))
S.save('/workspace/foe_walks/caldera_out/caldera_poses_contact.png'); print(S.size)
