import numpy as np, json
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from scipy.spatial import ConvexHull
S='/workspace/scratch/l9_v1_decor_check/cap/'
out={}
for proj in ['proj_wired','proj_patch']:
    for w,h in [(1280,720),(1920,1080)]:
        info=json.load(open(f'{S}{proj}/info_{w}.json'))
        for cam in ['zoom1','fit']:
            cells=info['cams'][cam]['cells']
            m=Image.new('L',(w,h),0); dr=ImageDraw.Draw(m)
            for c in cells:
                pts=np.array(c['pts']); hull=pts[ConvexHull(pts).vertices]
                dr.polygon([tuple(p) for p in hull],fill=255)
            cellm=np.asarray(m)>0
            hud=np.zeros((h,w),bool); hud[int(round(545/720*h)):,:]=True
            dist=ndi.distance_transform_edt(~cellm)
            for s in ['s0','s1']:
                on=np.asarray(Image.open(f'{S}{proj}/leaves_{cam}_{s}_k_{w}.png').convert('RGB')).astype(int)
                wt=np.asarray(Image.open(f'{S}{proj}/leaves_{cam}_{s}_w_{w}.png').convert('RGB')).astype(int)
                off=np.asarray(Image.open(f'{S}{proj}/leaves_{cam}_{s}_off_{w}.png').convert('RGB')).astype(int)
                # leaf coverage from black/white solve (alpha >= 1/255 counts)
                a=1-(wt-on).mean(-1)/255
                leaf=a>0.01
                # leaves-off frame must be the clear colour (proves isolation)
                r={'leaf_px':int(leaf.sum()),'over_cells_px':int((leaf&cellm).sum()),'over_hud_px':int((leaf&hud).sum()),
                   'min_gap_to_cells_px':round(float(dist[leaf].min()),1) if leaf.any() else None,
                   'leaf_bottom_y':int(np.where(leaf.any(1))[0].max()) if leaf.any() else None,
                   'off_frame_nonuniform_px':int((np.abs(off-off[0,0]).sum(-1)>6).sum())}
                out[f'{proj} {w} {cam} {s}']=r
                print(proj,w,cam,s,r)
json.dump(out,open(S+'overlay_verify.json','w'),indent=1)
