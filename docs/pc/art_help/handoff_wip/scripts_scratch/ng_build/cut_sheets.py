from ngc import *
import pickle
def cut(fname, n, full_despill=True, lo=0.10, hi=0.55, minpx=2000, protect=False):
    img=load(fname)
    F,A,K=key_green(img,protect_interior=protect,lo=lo,hi=hi,full_despill=full_despill,edge_despill_px=3)
    lab,nl=ndi.label(ndi.binary_dilation(A>0.2,iterations=6))
    sizes=ndi.sum(A>0.2,lab,range(1,nl+1))
    idx=np.argsort(-sizes)[:n]
    objs=[]
    for i in idx:
        sl=ndi.find_objects((lab==i+1).astype(int))[0]
        m=(lab[sl]==i+1)
        objs.append(dict(rgb=F[sl].copy(),a=(A[sl]*m).copy(),y=sl[0].start,x=sl[1].start,y1=sl[0].stop,x1=sl[1].stop))
    # reading order: rows by centre y (bucket), then x
    objs.sort(key=lambda o:(round(((o['y']+o['y1'])/2)/180),o['x']))
    print(fname,'key',np.round(K*255),[(o['x'],o['y'],o['x1']-o['x'],o['y1']-o['y']) for o in objs])
    return objs
props=cut('crag_props.jpg',12)
drifts=cut('snow_drifts.jpg',8)
pickle.dump(dict(props=props,drifts=drifts),open('tmp/cuts.pkl','wb'))
