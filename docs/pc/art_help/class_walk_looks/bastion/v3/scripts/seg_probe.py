import numpy as np, cv2, sys
from PIL import Image
from scipy import ndimage as ndi
P='/workspace/handoff/class_walk_blockouts/bastion/parts_src/'
for sh in ['legs_S','arms_S','body_S','helms_S_E','body_legs_E','arms_E']:
    rgb=np.asarray(Image.open(P+sh+'.jpg').convert('RGB')).astype(int)
    b=np.concatenate([rgb[:6].reshape(-1,3),rgb[-6:].reshape(-1,3),rgb[:,:6].reshape(-1,3),rgb[:,-6:].reshape(-1,3)])
    bg=np.median(b,0)
    d=np.abs(rgb-bg).max(2)
    print(sh,'bg',bg, 'border p5/p95 dev', np.percentile(np.abs(b-bg).max(1),[50,95,99]))
    for tol in (10,):
        near=(d<=tol).astype(np.uint8)
        n,lab=cv2.connectedComponents(near,connectivity=4)
        border=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
        fg=~(np.isin(lab,list(border))&(near>0))
        fg=ndi.binary_opening(fg,iterations=1)
        fl,fn=ndi.label(fg,np.ones((3,3)))
        for i,s in enumerate(ndi.find_objects(fl),1):
            area=(fl[s]==i).sum()
            if area>300: print('  comp',i,'x',s[1].start,s[1].stop,'y',s[0].start,s[0].stop,'area',area)
