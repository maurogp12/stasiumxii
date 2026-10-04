import sys, json, numpy as np
from PIL import Image
from skimage import color as LB
pal=np.array([[60,60,60],[255,0,0],[0,255,0],[0,0,255],[255,255,0],[255,0,255],[0,255,255],[255,128,0],[128,0,255],[0,128,0],[128,128,255],[255,128,128],[128,255,128],[200,200,200],[90,40,0],[0,90,90],[150,0,60],[60,150,0]])
def st(root,F,parts):
    acc=[]
    for i in range(12):
        o=np.array(Image.open(f'{root}/_dbg/owner_{F}_{i:02d}.png')).astype(int); s=json.load(open(f'{root}/_dbg/stack_{F}_{i:02d}.json'))
        im=np.array(Image.open(f'{root}/walk/ironjaw_walk_{F}_f{i:02d}.png').convert('RGBA'))
        for p in parts:
            if p not in s: continue
            m=(o==pal[s.index(p)]).all(-1)&(im[...,3]==255)
            from scipy import ndimage as ndi; m=ndi.binary_erosion(m,iterations=1)
            acc.append(LB.rgb2lab(im[...,:3][m][None]/255.)[0])
    a=np.concatenate(acc); return a.mean(0).round(2), a.std(0).round(2), np.percentile(a[:,0],[50,95]).round(1), len(a)
for root in sys.argv[2:]:
    print(root,'thigh',st(root,sys.argv[1],['R_thigh','L_thigh']))
    print(root,'shin',st(root,sys.argv[1],['R_shin','L_shin']))
