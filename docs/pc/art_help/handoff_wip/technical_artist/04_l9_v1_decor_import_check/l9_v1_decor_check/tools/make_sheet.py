from PIL import Image, ImageDraw, ImageFont
import json, numpy as np
C='cap/'
F=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',15)
FB=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',16)
W=1300
def lab(im,text,font=F):
    d=ImageDraw.Draw(im); tw=d.textlength(text,font=font)
    d.rectangle((0,0,tw+12,22),fill=(0,0,0)); d.text((6,2),text,fill=(255,255,255),font=font); return im
def crop(path,cx,cy,w,h,scale):
    im=Image.open(path).convert('RGB'); return im.crop((cx-w//2,cy-h//2,cx+w//2,cy+h//2)).resize((w*scale,h*scale),Image.NEAREST)
rows=[]
# row 1: before / after full frames
a=lab(Image.open(C+'proj_base/full_zoom1_1280.png').convert('RGB').resize((640,360),Image.LANCZOS),'in game now (branch af040d7, no kit) 1280 zoom1')
b=lab(Image.open(C+'proj_patch/full_zoom1_1280.png').convert('RGB').resize((640,360),Image.LANCZOS),'new kit + leaf_fit_crop.patch, 1280 zoom1 (BC7 imports)')
r1=Image.new('RGB',(W,360),(30,30,30)); r1.paste(a,(0,0)); r1.paste(b,(660,0)); rows.append(r1)
# row 2: fit 1920 new kit + rim occlusion with props_live
c=lab(Image.open(C+'proj_patch/full_fit_1920.png').convert('RGB').resize((640,360),Image.LANCZOS),'new kit + patch, 1920 fit 0.64')
info=json.load(open(C+'proj_props/info_1280.json'))['cams']['zoom1']['cells']; cells={tuple(x['cell']):x for x in info}
pr=Image.open(C+'proj_props/full_zoom1_1280.png').convert('RGB'); d=ImageDraw.Draw(pr)
for k in [(3,14),(4,14),(14,12),(14,14),(14,6),(14,7)]: d.polygon([tuple(p) for p in cells[k]['pts'][:4]],outline=(255,0,255))
x,y=np.array(cells[(4,14)]['pts'][:4]).mean(0); x2,y2=np.array(cells[(14,12)]['pts'][:4]).mean(0)
o1=pr.crop((int(x-80),int(y-45),int(x+80),int(y+75))).resize((320,240),Image.NEAREST)
o2=pr.crop((int(x2-80),int(y2-45),int(x2+80),int(y2+75))).resize((320,240),Image.NEAREST)
occ=Image.new('RGB',(640,360),(30,30,30)); occ.paste(o1,(0,60)); occ.paste(o2,(320,60))
dd=ImageDraw.Draw(occ); dd.text((6,28),'props_live: front-rim boulders over edge cells (magenta)',fill=(255,255,255),font=F)
dd.text((6,306),'(3,14) 42%  (4,14) 16%     (14,12) 44%  (14,6) 41% of top diamond',fill=(255,200,255),font=F)
dd.text((6,328),'(14,14) 20% under the (14,15) stone',fill=(255,200,255),font=F)
lab(occ,'FIX 3: rim props hide south/east cells (props_live only)')
r2=Image.new('RGB',(W,360),(30,30,30)); r2.paste(c,(0,0)); r2.paste(occ,(660,0)); rows.append(r2)
# row 3: halo crops + parallax
h1=lab(crop(C+'proj_patch/full_zoom1_1280.png',94,165,80,64,3),'leaf edge 1280 z1 x3')
h2=lab(crop(C+'proj_patch/full_fit_1920.png',574,120,120,96,2),'leaf edge 1920 fit x2')
h3=lab(crop(C+'proj_wired/pan_p0_1280.png',300,120,80,64,3),'clearing frame/sky 1280 x3')
p0=Image.open(C+'proj_wired/pan_p0_1280.png').convert('RGB').crop((280,20,1000,380)).resize((360,180),Image.LANCZOS)
p1=Image.open(C+'proj_wired/pan_px_1280.png').convert('RGB').crop((280,20,1000,380)).resize((360,180),Image.LANCZOS)
par=Image.new('RGB',(372,240),(30,30,30)); pa=p0.crop((0,0,360,105)); pb=p1.crop((0,0,360,105))
par.paste(pa,(6,24)); par.paste(pb,(6,132))
dd=ImageDraw.Draw(par)
for xx in (120,250): dd.line((6+xx,24,6+xx,237),fill=(255,0,0),width=1)
dd.rectangle((6,108,60,128),fill=(0,0,0)); dd.text((10,110),'pan 0',fill=(255,255,255),font=F); dd.rectangle((6,216,250,236),fill=(0,0,0)); dd.text((10,218),'pan +150 world px (0.40 both)',fill=(255,255,255),font=F)
lab(par,'FIX 2: sky slides -60px = clearing -60px')
r3=Image.new('RGB',(W,240),(30,30,30)); x=0
for im in [h1,h2,h3,par]:
    r3.paste(im,(x,0)); x+=im.width+12
rows.append(r3)
title=Image.new('RGB',(W,30),(0,0,0)); ImageDraw.Draw(title).text((8,6),'L9 mock-v1 decor check (TA, 2026-10-04): 1 FIX imports | 2 PASS alpha | 3 FIX sky merged into clearing (0.4, not 0.08) | 4 PASS* | 5 PASS',fill=(255,230,120),font=FB)
H=30+sum(r.height for r in rows)+10*len(rows)
out=Image.new('RGB',(W,H),(20,20,20)); y=0; out.paste(title,(0,0)); y=34
for r in rows: out.paste(r,(0,y)); y+=r.height+10
for q in [85,80,75,70,65,60]:
    out.save('/workspace/luca_pics/l9_v1_decor_check.jpg',quality=q,optimize=True)
    import os; s=os.path.getsize('/workspace/luca_pics/l9_v1_decor_check.jpg')
    if s<290000: break
print(out.size,q,s)
