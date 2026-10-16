import json,sys,shutil,cv2,numpy as np
from PIL import Image
Image.MAX_IMAGE_PIXELS=None
SKIP={'z','centreline_z','z_from','z_to','stair_top_z','pause','facing','loop','id','layer','hop_px'}
def sc(o,k=None):
    if k in SKIP:return o
    if isinstance(o,bool):return o
    if isinstance(o,(int,float)):return round(o*0.5,2)
    if isinstance(o,list):return [sc(v,k) for v in o]
    if isinstance(o,dict):return {kk:sc(v,kk) for kk,v in o.items()}
    return o
if __name__=='__main__':
    src,dst=sys.argv[1],sys.argv[2]
    U={'zones.json':'web plate px (2560x1440 = full x0.5); z values stay full-scale','routes.json':'web plate px (x0.5); speeds scaled too'}
    for f in ['zones.json','routes.json']:
        d=sc(json.load(open(f'{src}/{f}')));d['units']=U[f];json.dump(d,open(f'{dst}/{f}','w'),indent=1)
    for f in ['plate.jpg','ground.jpg']:Image.open(f'{src}/{f}').resize((2560,1440),Image.LANCZOS).save(f'{dst}/{f}',quality=90)
    for f in ['walkmask.png','river.png']:
        m=cv2.imread(f'{src}/{f}',0);cv2.imwrite(f'{dst}/{f}',((cv2.resize(m,(2560,1440),interpolation=cv2.INTER_AREA)>127)*255).astype('uint8'))
    cv2.imwrite(f'{dst}/heightmap.png',cv2.resize(cv2.imread(f'{src}/heightmap.png',0),(2560,1440),interpolation=cv2.INTER_NEAREST))
