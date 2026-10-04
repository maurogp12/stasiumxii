"""prepare cleaned source textures + stamps -> src.npz"""
from ngc import *
s=load('snow_swatch.jpg')
# the swatch is a 640 px wide painting repeated twice horizontally (autocorrelation peak at dx=640)
L=lum(s)
w=np.maximum(s[...,0],s[...,1])-s[...,2]
loc=ndi.uniform_filter(L,41)
m=((w>0.0)&(L<0.91))|((loc-L)>0.10)|((w>-0.008)&(L<0.86))
m=ndi.binary_opening(m,iterations=1)
lab,n=ndi.label(ndi.binary_dilation(m,iterations=2))
sz=ndi.sum(m,lab,range(1,n+1))
keep=[i+1 for i,v in enumerate(sz) if v>12]
M=np.isin(lab,keep)
M=ndi.binary_dilation(M,iterations=5)
s8=(s*255).astype(np.uint8)
clean=cv2.inpaint(s8,(M*255).astype(np.uint8),9,cv2.INPAINT_TELEA).astype(np.float32)/255
# soften inpaint smears a touch by re-adding the swatch's fine grain statistics (low-amplitude noise)
r=rng(5); grain=ndi.gaussian_filter(r.standard_normal(L.shape),0.8)*0.006
clean=np.clip(clean+grain[...,None]*np.array([1,1,1.1]),0,1)
Image.fromarray((clean*255).astype(np.uint8)).save('tmp/snow_clean.png')
# stamps: delta transfer (orig - clean) inside each item mask, keep per-item boxes
stamps=[]
lab2,n2=ndi.label(M)
for i,sl in enumerate(ndi.find_objects(lab2)):
    y0,y1,x0,x1=sl[0].start,sl[0].stop,sl[1].start,sl[1].stop
    if x0>=640: continue          # second copy of the repeat
    if y0<3 or x0<3 or y1>717 or x1>637: continue
    mm=(lab2[sl]==i+1)
    d=(s[sl]-clean[sl])*mm[...,None]
    soft=ndi.gaussian_filter(mm.astype(np.float32),1.5)
    kind='tuft' if (s[sl][...,1]-s[sl][...,2])[mm].max()>0.04 else 'pebble'
    stamps.append(dict(d=d*soft[...,None],kind=kind,w=x1-x0,h=y1-y0))
print('stamps',len(stamps),sum(1 for t in stamps if t['kind']=='tuft'))
np.save('tmp/snow_clean.npy',clean)
import pickle; pickle.dump(stamps,open('tmp/snow_stamps.pkl','wb'))
