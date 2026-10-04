from ngc import *
s=load('snow_swatch.jpg')
L=lum(s)
w=np.maximum(s[...,0],s[...,1])-s[...,2]
loc=ndi.uniform_filter(L,41)
m=((w>0.0)&(L<0.91))|((loc-L)>0.16)
m=ndi.binary_opening(m,iterations=1)
lab,n=ndi.label(ndi.binary_dilation(m,iterations=2))
sz=ndi.sum(m,lab,range(1,n+1))
keep=[i+1 for i,v in enumerate(sz) if v>12]
M=np.isin(lab,keep)
M=ndi.binary_dilation(M,iterations=2)
print('items',len(keep), M.mean())
out=(s*255).astype(np.uint8).copy(); out[M]=[255,0,0]
Image.fromarray(out[:400,:700]).save('tmp/snow_mask.png')
np.save('tmp/snow_items_mask.npy',M)
