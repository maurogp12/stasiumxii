"""G) roof snow caps: roof_snow_full_a/b, roof_snow_patchy_a, roof_snow_dust_a (640 px wide @2x, horizontally periodic)
   + pre-sheared roof_snow_left_a/b, roof_snow_right_a/b (2:1 iso pitch, 26.57 deg). writes tmp/roof_meta.json"""
from ngc import *
img=load('roof_snow_bands.jpg')
F,A,K=key_green(img,full_despill=True)
runs=[(20,171),(226,367),(419,536),(599,698)]
IDS=['roof_snow_full_a','roof_snow_full_b','roof_snow_patchy_a','roof_snow_dust_a']
EAVE_COV=[0.5,0.5,0.5,0.3]
META={}
WT=640
def even(n): return n+(n%2)
def finish_rgba(rgb,a):
    lim=np.maximum(rgb[...,0],rgb[...,2]); rgb=rgb.copy(); rgb[...,1]=np.minimum(rgb[...,1],lim+0.005)
    return to_rgba8(np.clip(rgb,0,1),np.clip(a,0,1))
def measure(a):
    prof=(a>0.5).mean(1)
    rows=np.nonzero(prof>0.002)[0]
    top=int(rows.min()); bot=int(rows.max())+1
    return prof,top,bot
CAPS={}
for iid,(y0,y1),ec in zip(IDS,runs,EAVE_COV):
    y0-=4; y1+=4
    pm=np.concatenate([F[y0:y1]*A[y0:y1,:,None],A[y0:y1,:,None]],2)
    x0,ov=10,80; pw=1280-x0-ov-10
    P=periodic_strip(pm,x0,pw,ov)
    a=P[...,3]; rgb=np.where(a[...,None]>1e-4,P[...,:3]/np.maximum(a[...,None],1e-4),0)
    s=WT/pw
    rgb,a=scale_rgba(rgb,a,s)
    h=a.shape[0]
    if h%2: rgb=np.concatenate([rgb,np.zeros((1,WT,3))]); a=np.concatenate([a,np.zeros((1,WT))])
    # snow stays light: lift slightly, cap at 0.985, keep the lavender shade
    rgb=np.clip(np.minimum(rgb*1.02,0.985),0,1)
    arr=finish_rgba(rgb,a)
    save_world(arr,'roof',iid)
    prof,top,bot=measure(a)
    # eave line: last row (from the bottom up) whose coverage is >= ec (wavy lip mean)
    cand=np.nonzero(prof>=ec)[0]
    eave=int(cand.max())+1 if len(cand) else bot
    CAPS[iid]=(rgb,a)
    META[iid]=dict(id=iid,file='roof/'+iid+'.png',file_2x='roof/_2x/'+iid+'.png',size=[WT//2,a.shape[0]//2],size_2x=[WT,a.shape[0]],
        kind='roof_cap',family='roof_snow',coverage={'roof_snow_full_a':'full','roof_snow_full_b':'full','roof_snow_patchy_a':'patchy','roof_snow_dust_a':'dust'}[iid],
        tileable_x=True,top_px_2x=top,eave_px_2x=eave,icicle_bottom_px_2x=bot,lip_px_2x=int(bot-eave),
        note='flat (unsheared) cap; horizontally periodic. Row eave_px_2x is the mean eave lip; icicles hang lip_px_2x below it.')
    print(iid,arr.shape,'top',top,'eave',eave,'bot',bot,'lip',bot-eave,'fringe',green_fringe_stats(arr))
# ---- pre-sheared (2:1 iso pitch) ----
K2=0.5
for src,suf in (('roof_snow_full_a','a'),('roof_snow_full_b','b')):
    rgb,a=CAPS[src]
    for side,k in (('left',K2),('right',-K2)):
        r2,a2=shear_rgba(rgb,a,k)
        ys=np.nonzero(a2.max(1)>0.004)[0]; yA=max(ys.min()-2,0); yB=min(ys.max()+3,a2.shape[0])
        r2=r2[yA:yB]; a2=a2[yA:yB]
        if a2.shape[0]%2: r2=np.concatenate([r2,np.zeros((1,WT,3))]); a2=np.concatenate([a2,np.zeros((1,WT))])
        iid=f'roof_snow_{side}_{suf}'
        arr=finish_rgba(r2,a2); save_world(arr,'roof',iid)
        m=META[src]; h=a.shape[0]; extra=int(math.ceil(abs(k)*WT/2))+2
        # flat row y maps to y + extra + k*(x - W/2) - yA
        def mapy(y,x): return round(y+extra+k*(x-WT/2)-yA,1)
        META[iid]=dict(id=iid,file='roof/'+iid+'.png',file_2x='roof/_2x/'+iid+'.png',size=[WT//2,a2.shape[0]//2],size_2x=[WT,a2.shape[0]],
            kind='roof_cap',family='roof_snow',coverage='full',derived_from=src,slope=side,shear_k=k,pitch_deg=26.57,
            eave_line_px_2x=[[0,mapy(m['eave_px_2x'],0)],[WT,mapy(m['eave_px_2x'],WT)]],
            top_line_px_2x=[[0,mapy(m['top_px_2x'],0)],[WT,mapy(m['top_px_2x'],WT)]],lip_px_2x=m['lip_px_2x'],
            note=('left roof slope (faces down-left / SW; ridge and eave descend to the right at 2:1)' if side=='left' else
                  'right roof slope (faces down-right / SE; ridge and eave rise to the right at 2:1)')+'; icicles stay vertical')
        print(iid,arr.shape,META[iid]['eave_line_px_2x'],'fringe',green_fringe_stats(arr))
json.dump(META,open('tmp/roof_meta.json','w'),indent=1)
