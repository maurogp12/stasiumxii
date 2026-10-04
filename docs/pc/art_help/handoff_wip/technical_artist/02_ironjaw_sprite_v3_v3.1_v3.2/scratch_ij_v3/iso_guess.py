import json,numpy as np,itertools
from PIL import Image
pf=json.load(open('qa.json'))['per_frame']
names=list(pf)
def path(n):
    st=n.split('_')[1]; return f'{st}/{n}'
arrs={n:np.array(Image.open(path(n)).convert('RGBA')).astype(float) for n in names}
target=np.array([pf[n]['isolated_light'] for n in names])
def count(a,lum_t,diff_t,mode,neigh):
    L=0.299*a[...,0]+0.587*a[...,1]+0.114*a[...,2]; op=a[...,3]>127
    P=np.pad(L,1,constant_values=np.nan); O=np.pad(op,1)
    nb=[];no=[]
    for dy,dx in itertools.product((-1,0,1),repeat=2):
        if dy==dx==0: continue
        if neigh==4 and dy and dx: continue
        nb.append(P[1+dy:1+dy+L.shape[0],1+dx:1+dx+L.shape[1]]); no.append(O[1+dy:1+dy+L.shape[0],1+dx:1+dx+L.shape[1]])
    nb=np.array(nb); no=np.array(no)
    nbz=np.where(no,nb,np.nan)
    with np.errstate(all='ignore'):
        ref=np.nanmax(nbz,0) if mode=='max' else np.nanmean(nbz,0)
    c=op&(L>lum_t)&(L-ref>diff_t)
    return int(np.nansum(c))
best=[]
for lum_t in [80,100,120,140,160,180,200]:
  for diff_t in [20,30,40,50,60,80]:
    for mode in ['max','mean']:
      for neigh in [8,4]:
        got=np.array([count(arrs[n],lum_t,diff_t,mode,neigh) for n in names])
        err=np.abs(got-target).sum()
        best.append((err,got.sum(),lum_t,diff_t,mode,neigh))
best.sort(); print(best[:8], target.sum())
