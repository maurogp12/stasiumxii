from PIL import Image
import numpy as np, scipy.ndimage as ndi
from rembg import remove, new_session
s=new_session('isnet-general-use')
def trim(im,pad=2):
    a=np.array(im)[...,3]; ys,xs=np.where(a>20); return im.crop((xs.min()-pad,ys.min()-pad,xs.max()+1+pad,ys.max()+1+pad))
# menu icons: alpha from luminance, 3x3 cells
M=Image.open('assets/menu_icons_raw.jpg').convert('RGB'); W,H=M.size
names=['character','inventory','spells','quests','map','dungeons','koliseo','shop','settings']
a=np.asarray(M).astype('float32')
for i,n in enumerate(names):
    r,c=divmod(i,3); cell=a[r*H//3:(r+1)*H//3,c*W//3:(c+1)*W//3]
    lum=cell.max(-1); al=np.clip((lum-18)/60,0,1)
    rgba=np.dstack([np.full(cell.shape[:2]+(3,),[241,236,226]),al*255]).astype('uint8')
    # keep inner shading: multiply colour by luminance
    shade=np.clip(lum/ max(lum.max(),1)*1.12,0.55,1)[...,None]
    rgba[...,:3]=np.clip(np.array([241,236,226])*shade,0,255)
    im=trim(Image.fromarray(rgba)); im.save(f'assets/icons/{n}.png'); print(n,im.size)
# items: rembg + components
I=Image.open('assets/item_icons_raw.jpg').convert('RGB'); r=np.array(remove(I,session=s)); al=r[...,3]>100
al=ndi.binary_closing(al,iterations=4); lab,n=ndi.label(al); objs=ndi.find_objects(lab)
items=[(sl,lab[sl]==k+1) for k,sl in enumerate(objs) if (lab[sl]==k+1).sum()>3000]
items.sort(key=lambda t:(t[0][0].start//250,t[0][1].start))
inames=['potion_red','potion_blue','bread','herbs','rope','scroll','pickaxe','bandage']
for (sl,m),nm in zip(items,inames):
    rgb=np.array(I)[sl]; al2=(m*255).astype('uint8')
    im=trim(Image.fromarray(np.dstack([rgb,al2]))); im.save(f'assets/items/{nm}.png'); print(nm,im.size)
C=Image.open('assets/crest_raw.jpg').convert('RGB'); r=remove(C,session=s); im=trim(r); im.save('assets/crest_ironjaw.png'); print('crest',im.size)
