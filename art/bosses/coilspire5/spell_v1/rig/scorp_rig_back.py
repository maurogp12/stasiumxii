import numpy as np, cv2, scipy.ndimage as nd
from PIL import Image, ImageDraw, ImageFilter
_im=Image.open('/workspace/c5_bv.png').convert('RGB').crop((312,50,925,645)); RGB=np.array(_im).astype(np.uint8)
_d=np.abs(RGB.astype(int)-RGB[5,5].astype(int)).max(-1); _sat=RGB.max(-1)-RGB.min(-1); M=(_d>16)|(_sat>25)
M=nd.binary_opening(M,iterations=1); _lb,_n=nd.label(M); _s=nd.sum(M,_lb,range(1,_n+1)); M=_lb==(np.argmax(_s)+1)
_h=nd.binary_fill_holes(M)&~M; _hl,_hn=nd.label(_h)
for i in range(_hn):
    if (_hl==i+1).sum()<30: M|=(_hl==i+1)
H_,W_=M.shape
# legs: polygon, hip, front (drawn over body), tripod group 0/1
_c=lambda pts:[(round(x*1.25-312),round(y*1.25-50)) for x,y in pts]
LEGS=[dict(p=_c([(420,316),(452,335),(412,372),(368,418),(332,444),(286,430),(298,402),(355,354)]),hip=_c([(430,335)])[0],front=True,g=0),
      dict(p=_c([(445,340),(485,345),(462,420),(442,497),(418,492),(430,400)]),hip=_c([(465,350)])[0],front=True,g=1),
      dict(p=_c([(490,350),(530,352),(562,450),(557,514),(533,514),(500,400)]),hip=_c([(508,357)])[0],front=True,g=0),
      dict(p=_c([(640,325),(675,330),(714,400),(698,412),(660,372)]),hip=_c([(655,337)])[0],front=True,g=1),
      dict(p=_c([(512,203),(562,203),(566,250),(514,250)]),hip=_c([(545,250)])[0],front=False,g=1),
      dict(p=_c([(552,230),(612,230),(626,287),(560,287)]),hip=_c([(568,262)])[0],front=False,g=0)]
legall=np.zeros_like(M)
for L in LEGS:
    pm=Image.new('L',(W_,H_)); ImageDraw.Draw(pm).polygon(L['p'],fill=255); L['m']=np.array(pm)>0
    # only keep pixels that are either on the matte OR immediately next to a hip stub (fill the hip joint)
    L['m']&=(M|nd.binary_dilation(M,iterations=1)); legall|=L['m']
    yy,xx=np.nonzero(L['m']); dd=(xx-L['hip'][0])**2+(yy-L['hip'][1])**2
    L['tip']=(int(xx[dd.argmax()]),int(yy[dd.argmax()])); L['len']=float(np.sqrt(dd.max()))
# body: remove legs; inpaint where core was covered by a leg so rotated legs never leave a hole
core=cv2.morphologyEx((M&~legall).astype(np.uint8),cv2.MORPH_CLOSE,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(9,9)))>0
fill=(legall&core)|((~M)&core)   # wherever a body-like area loses a leg
BODY_RGB=cv2.inpaint(RGB,(legall&core).astype(np.uint8)*255,6,cv2.INPAINT_TELEA)
BODY_A=(M&~legall)|core
# keep a hip stub so the joint stays closed
for L in LEGS:
    yy,xx=np.mgrid[0:H_,0:W_]; BODY_A|=(((xx-L['hip'][0])**2+(yy-L['hip'][1])**2)<64)&M
def _layer(rgb,a): return np.dstack([rgb,(a.astype(np.uint8)*255)])
BODY=_layer(np.where(fill[...,None],BODY_RGB,RGB),BODY_A)
for L in LEGS: L['img']=_layer(RGB,L['m'])
def _rot(img,c,ang,dy=0):
    Mx=cv2.getRotationMatrix2D((float(c[0]),float(c[1])),float(ang),1.0); Mx[1,2]+=dy
    return cv2.warpAffine(img,Mx,(W_,H_),flags=cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
TH=22.0
def set_th(th):
  global TH,STRIDE
  TH=th
  for L in LEGS:
    t=np.array(L['tip'],float)-L['hip']
    # +ang (CCW in cv2) moves tip; we want stance +TH -> -TH to drag tip toward +x (body forward = -x)
    def tipx(a,t=t): r=np.deg2rad(a); return t[0]*np.cos(r)+t[1]*np.sin(r)
    # choose sign so tipx(+s*TH) > tipx(-s*TH)  (tip moves +x as angle goes +TH -> -TH? Wait: stance goes +1->-1 so ang = s*TH goes +TH->-TH; tip should move +x)
    # tipx(+TH)-tipx(-TH) = 2*t[1]*sin(TH); if t[1]>0 (tip below hip) tipx(+TH)>tipx(-TH), so +ang moves tip +x. Stance wants tip +x over time as ang goes +TH->-TH, so tip moves -x with +ang? 
    # stance: start ang=+TH (tip forward = more -x), end ang=-TH (tip back = more +x). tipx should INCREASE during stance.
    # tipx(+TH) ? tipx(-TH): if tip below (t[1]>0), tipx(+TH) = t0*c + t1*s > tipx(-TH)=t0*c - t1*s, so tipx bigger at +TH. That's WRONG for our need.
    # So we need ang = -TH * s  (start -TH, end +TH) when tip is below.
    L['sg']= -1.0 if t[1]>=0 else 1.0
    L['stride']=abs(tipx(L['sg']*TH)-tipx(-L['sg']*TH))
  STRIDE=float(np.mean([L['stride'] for L in LEGS if L['front']]))
set_th(22.0)
def angle(u):
    if u<0.5: return 1-4*u,0.0
    w=(u-0.5)/0.5; return -np.cos(np.pi*w),np.sin(np.pi*w)
def pose(ph):
    out=np.zeros((H_,W_,4),np.float32)
    def over(o,l):
        a=l[...,3:4].astype(np.float32)/255; o[...,:3]=l[...,:3]*a+o[...,:3]*(1-a); o[...,3:4]=255*a+o[...,3:4]*(1-a); return o
    lays=[]
    for L in LEGS:
        u=(ph+0.5*L['g'])%1.0; s,lift=angle(u)
        ang=L['sg']*TH*s
        lays.append((L['front'],_rot(L['img'],L['hip'],ang,-5*lift)))
    sw=2.0*np.sin(4*np.pi*ph); bob=3.0*np.sin(4*np.pi*ph+1.0)
    body=_rot(BODY,(int(W_*0.5),int(H_*0.75)),sw)
    yy,xx=np.mgrid[0:H_,0:W_].astype(np.float32)
    wgt=np.clip((xx-330)/60,0,1)*np.clip((260-yy)/80,0,1)
    body=cv2.remap(body,xx,(yy-float(bob)*wgt).astype(np.float32),cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
    for f,l in lays:
        if not f: out=over(out,l)
    out=over(out,body)
    for f,l in lays:
        if f: out=over(out,l)
    o=np.clip(out,0,255).astype(np.uint8); o[...,3]=np.where(o[...,3]<10,0,o[...,3])
    m_=o[...,3]>0; lb_,n_=nd.label(m_); 
    if n_>1:
        ss=nd.sum(m_,lb_,range(1,n_+1)); o[np.isin(lb_,[i+1 for i,v in enumerate(ss) if v<25])]=0
    return Image.fromarray(o)
# visual check of masks
if __name__=='__main__':
    cols=[(255,60,60),(60,255,60),(60,60,255),(255,255,60),(255,60,255),(60,255,255)]
    Msh=Image.new('RGBA',(W_*3,H_*2),(25,25,25,255))
    for i,L in enumerate(LEGS):
        a=np.zeros((H_,W_,4),np.uint8); a[L['m']]=(*cols[i],255); a[L['hip'][1]-2:L['hip'][1]+3,L['hip'][0]-2:L['hip'][0]+3]=(255,255,255,255)
        Msh.alpha_composite(Image.fromarray(a),((i%3)*W_,(i//3)*H_))
    Msh.save('legsB.png')
    S=Image.new('RGBA',(W_*6,H_*2),(50,110,50,255))
    for i in range(12): S.alpha_composite(pose(i/12.),((i%6)*W_,(i//6)*H_))
    S.save('pose_sheetB.png'); print('STRIDE',STRIDE,[round(L['stride'],1) for L in LEGS])
