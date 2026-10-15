import numpy as np, cv2, json, os, sys
from PIL import Image, ImageDraw
from scipy import ndimage as nd
sys.path.insert(0,'/workspace/foe_walks/fly_back'); import dspk
import legs as LG
OD='/workspace/foe_walks/cb3_out/captain_brineclaw_v3'; NM='captain_brineclaw'
Y,X=np.mgrid[0:336,0:288].astype(float)
A=12.0; LIFT=12.0; U=[0.894,0.447]; ROOT=14
def rig(img,**kw):
    img=LG.deshadow(img); R=LG.analyse(img,**kw); seg=R['seg']; n=R['n']
    seg=seg.copy(); seg[(Y<R['zs']+ROOT)&(seg>0)]=0   # leg roots stay with the body, under the skirt
    body=img.copy(); body[seg>0]=0
    parts=[]
    for k in range(1,n+1):
        m=seg==k; ys_,xs_=np.nonzero(m); rows=range(ys_.min(),ys_.max()+1); span={}
        for y in rows:
            xx=np.nonzero(m[y])[0]
            if len(xx): span[y]=(xx.min(),xx.max())
        ky=sorted(span); full=m.copy()
        for y in rows:
            if y in span: x0,x1=span[y]
            else:
                lo=max([q for q in ky if q<y]); hi=min([q for q in ky if q>y]); t_=(y-lo)/(hi-lo)
                x0=span[lo][0]*(1-t_)+span[hi][0]*t_; x1=span[lo][1]*(1-t_)+span[hi][1]*t_
            full[y,int(x0):int(x1)+1]=True
        y0=ky[0]; seg_top=R['zs']
        if y0-seg_top>4:
            cs=[(span[q][0]+span[q][1])/2 for q in ky[:15]]; sl=np.polyfit(ky[:15],cs,1)[0] if len(ky)>=15 else 0
            wd=np.mean([span[q][1]-span[q][0] for q in ky[:8]])/2
            for y in range(seg_top,y0):
                c_=(span[y0][0]+span[y0][1])/2+sl*(y-y0); full[y,max(0,int(c_-wd)):int(c_+wd)+1]=True
        full=nd.binary_closing(full,iterations=2)|m
        full&=nd.binary_fill_holes(img[...,3]>0)|m
        miss=(full&~m).astype(np.uint8)*255
        rgb=np.ascontiguousarray(img[...,:3]); fill=cv2.inpaint(rgb,miss,3,cv2.INPAINT_TELEA) if miss.any() else rgb
        p=np.zeros_like(img); p[full,:3]=fill[full]; p[full,3]=255; p[m]=img[m]
        ys,xs=np.nonzero(full); parts.append(dict(img=p,top=ys.min(),foot=ys.max(),fx=xs[np.argmax(ys)],k=k))
    # body holes left by removed legs (inside silhouette above the hem) -> inpaint from body
    a=body[...,3]>0; hole=nd.binary_fill_holes(a)&~a
    if hole.any():
        f=cv2.inpaint(np.ascontiguousarray(body[...,:3]),hole.astype(np.uint8)*255,3,cv2.INPAINT_TELEA); body[hole,:3]=f[hole]; body[hole,3]=255
    return body,parts,n
def warp(img,dx,dy):
    sx=np.round(X-dx).astype(int); sy=np.round(Y-dy).astype(int); ok=(sx>=0)&(sx<288)&(sy>=0)&(sy<336)
    o=np.zeros_like(img); o[ok]=img[sy[ok],sx[ok]]; return o
def frame(body,parts,f,n):
    p=2*np.pi*f/8; b=3.5*(0.5+0.5*np.cos(2*p)); rot=1.4*np.sin(p)
    a=body[...,3]>0; ys,xs=np.nonzero(a); cx=(xs.min()+xs.max())/2; hw=(xs.max()-xs.min())/2; bot=ys.max()
    t=np.radians(rot); px=X-cx; py=Y-bot
    sway=2.5*np.sin(p+0.6)*np.clip(np.abs(px)/hw,0,1)**2*np.clip((bot-60-Y)/100,0,1)
    qx=np.cos(t)*px+np.sin(t)*py+cx-sway; qy=-np.sin(t)*px+np.cos(t)*py+bot-b
    sx=np.round(qx).astype(int); sy=np.round(qy).astype(int); ok=(sx>=0)&(sx<288)&(sy>=0)&(sy<336)
    B=np.zeros_like(body); B[ok]=body[sy[ok],sx[ok]]
    out=np.zeros_like(body); info=[]
    for P in sorted(parts,key=lambda q:q['foot']):
        g=(P['k']-1)%2; ph=(f/8.0+0.5*g)%1.0   # 0..0.5 swing, 0.5..1 stance
        if ph<0.5: u=ph/0.5; xo=-A+2*A*u; lift=LIFT*np.sin(np.pi*u)
        else: u=(ph-0.5)/0.5; xo=A-2*A*u; lift=0.0
        w=np.clip((Y-P['top'])/(P['foot']-P['top']),0,1)
        top_dx=np.sin(t)*(P['top']-bot)  # follow body tilt at hip
        dxm=xo*U[0]*w+top_dx*(1-w); dym=b*(1-w)-lift*w+xo*U[1]*w
        o=warp(P['img'],dxm,dym); m=o[...,3]>0; out[m]=o[m]
        info.append(dict(leg=P['k'],phase='swing' if ph<0.5 else 'stance',foot_x_cell=round(P['fx']+xo*U[0],2),foot_y_cell=round(P['foot']+xo*U[1]-lift,2),lift=round(lift,1)))
    m=B[...,3]>0; out[m]=B[m]
    c=out[...,:3].astype(float); sat=(c.max(-1)-c.min(-1))/np.maximum(c.max(-1),1); L=c@[.299,.587,.114]
    out[(out[...,3]>0)&(sat<0.2)&(L>100)]=0
    return dspk.clean(out),info
def count_legs(o,band=32):
    a=o[...,3]>0; ys=np.nonzero(a.any(1))[0]; bot=ys.max(); tb=a.copy(); tb[:bot-band]=0
    lab,n=nd.label(tb); sz=nd.sum(tb,lab,range(1,n+1)); return int((sz>=10).sum())
if __name__=='__main__':
    qa={}; checkimgs=[]
    for d,nm,kw in (('s','key_f_rest',dict(band=32)),('e','key_b_rest',dict(band=32,ero=2,minsz=4,split=True))):
        U=[0.894,0.447] if d=='s' else [0.894,-0.447]
        img=np.array(Image.open(nm+'.png')); body,parts,n=rig(img,**kw)
        frs=[];infos=[]
        for f in range(8): o,inf=frame(body,parts,f,n); frs.append(o); infos.append(inf)
        idle=[]
        for f in range(6):
            p=2*np.pi*f/6; o=warp(np.where((np.arange(336)<parts[0]['top']-0)[:,None,None],LG.deshadow(img),LG.deshadow(img)),0,0); idle.append(LG.deshadow(img) if False else None)
        # idle: body bob 1.5px with legs pinned (reuse frame() with A=0)
        A0,L0=A,LIFT; globals()['A']=0.0; globals()['LIFT']=0.0
        idle=[frame(body,parts,f*8/6,n)[0] for f in range(6)]; globals()['A']=A0; globals()['LIFT']=L0
        # slide check: stance foot world x = cell x + body travel (A/2 per frame, since stance moves 2A over 4 frames)
        slide=[]
        for k in range(1,n+1):
            pts=[]
            for f in range(8):
                q=[x for x in infos[f] if x['leg']==k][0]
                if q['phase']=='stance': pts.append((q['foot_x_cell']+f*A/2*U[0],q['foot_y_cell']+f*A/2*U[1]))
            pts=np.array(pts); slide.append(dict(x=round(float(np.ptp(pts[:,0])),2),y=round(float(np.ptp(pts[:,1])),2)) if len(pts) else None)
        qa[d]=dict(legs_in_rig=n,leg_parts_drawn_per_frame=[len(i) for i in infos],
                   stance_foot_world_slide_px=slide,body_travel_cell_px_per_frame_along_dir=A/2,travel_dir_cell=U,lift_px=LIFT,bob_px=3.5,legs=infos)
        for d2,mir in ((d,False),({'s':'w','e':'n'}[d],True)):
            for act,fr in (('walk',frs),('idle',idle)):
                ff=[x[:,::-1].copy() for x in fr] if mir else fr
                dd=f'{OD}/{act}_frames_{d2}'; os.makedirs(dd,exist_ok=True); [os.remove(f'{dd}/{x}') for x in os.listdir(dd)]
                for i,a in enumerate(ff): Image.fromarray(a).save(f'{dd}/{i:02d}.png')
                Image.fromarray(np.concatenate(ff,1)).save(f'{OD}/{NM}_{act}_{d2}.png')
        if d=='s':
            # numbered check: label each leg part at its foot per frame
            sheet=Image.new('RGB',(576*4,672*2),(128,128,128))
            for f in range(8):
                b_=Image.new('RGBA',(288,336),(128,128,128,255)); b_.alpha_composite(Image.fromarray(frs[f])); b_=b_.resize((576,672),Image.NEAREST); dr=ImageDraw.Draw(b_)
                p=2*np.pi*f/8; bb=3.5*(0.5+0.5*np.cos(2*p))
                for q,P in zip(infos[f],sorted(parts,key=lambda q:q['foot'])):
                    x=q['foot_x_cell']*2; y=(P['foot']-q['lift'])*2+14
                    dr.ellipse([x-11,y-11,x+11,y+11],fill=(255,230,60,255)); dr.text((x,y),str(q['leg']),fill=(0,0,0,255),anchor='mm')
                dr.text((20,20),f'frame {f}  legs {len(infos[f])}',fill=(255,255,255,255))
                sheet.paste(b_.convert('RGB'),((f%4)*576,(f//4)*672))
            sheet.save('/workspace/foe_walks/cb3_out/brineclaw_walk_check.png')
    json.dump(qa,open(f'{OD}/walk_qa.json','w'),indent=1)
    print({d:{k:v for k,v in q.items() if k!='legs'} for d,q in qa.items()})
