from roofsnow import *
from PIL import ImageDraw, ImageFont
os.makedirs(PREV,exist_ok=True)
try: font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16); fs=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',13)
except Exception: font=fs=ImageFont.load_default()
cases=[(REPO+'props/_2x/cottage_slate.png','roof_snow_patchy_a','left',1.0,'DEFAULT  cottage_slate  +  roof_snow_patchy_a  (left slope, shear +0.5, broken band in the top third, no eave lip)'),
       (REPO+'props/_2x/cottage_slate_b.png','roof_snow_dust_a','right',0.95,'DEFAULT  cottage_slate_b  +  roof_snow_dust_a  (right slope, shear -0.5)'),
       (REPO+'props/_2x/cottage_slate.png','roof_snow_full_a','left',1.0,'OPTION (deep winter)  cottage_slate  +  roof_snow_full_a'),
       (REPO+'props/_2x/cottage_slate_b.png','roof_snow_full_b','right',0.95,'OPTION (deep winter)  cottage_slate_b  +  roof_snow_full_b')]
BG=(128,128,132,255)
tiles=[]
for png,cap,side,sh,label in cases:
    res,dbg=snow_roof(png,cap,side,shade=sh,return_debug=True)
    print(label,'k',round(dbg['k'],3),'depth',round(dbg['depth'],1),'sy',round(dbg['sy'],2),'eave cols',dbg['eave'][2])
    tiles.append((Image.open(png).convert('RGBA'),Image.fromarray(res),Image.fromarray((dbg['M']*255).astype(np.uint8)),label))
    if 'DEFAULT' in label:
        os.makedirs(PREV+'roof_masks',exist_ok=True)
        Image.fromarray((dbg['M']*255).astype(np.uint8)).save(PREV+'roof_masks/'+os.path.basename(png).replace('.png','_roof_mask@2x.png'))
S=2  # show at 2x zoom of the 2x art (nearest) so edges can be inspected
cw,ch=292*S,224*S
W=3*cw+80; Hh=len(tiles)*(ch+40)+60
can=Image.new('RGBA',(W,Hh),BG); d=ImageDraw.Draw(can)
d.text((20,12),'NORTHGATE roof snow demo - real repo cottages (art/world/crosshaven/props cottage_slate skin), 2x art shown at 200%. left: original | middle: masked snow cap | right: derived roof alpha',fill=(20,20,24),font=fs)
y=40
for orig,res,mask,label in tiles:
    d.text((20,y),label,fill=(15,15,20),font=font); y+=22
    for j,imx in enumerate((orig,res,mask.convert('RGBA'))):
        z=imx.resize((imx.width*S,imx.height*S),Image.NEAREST)
        can.alpha_composite(z,(20+j*(cw+20),y))
    y+=ch+18
can.convert('RGB').save(PREV+'roof_snow_demo.png')
print('saved',can.size)
