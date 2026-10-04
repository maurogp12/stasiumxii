import sys, json, numpy as np
sys.path.insert(0,'tools')
from halo_solve import solve, L
S='/workspace/scratch/l9_v1_decor_check/cap/'
res={}
for tag,kp in [('patch 1280 fit','proj_patch/leaves_fit_s0_k_1280.png'),('patch 1920 fit','proj_patch/leaves_fit_s0_k_1920.png'),
               ('wired 1280 zoom1','proj_wired/leaves_zoom1_s0_k_1280.png'),('wired 1920 zoom1','proj_wired/leaves_zoom1_s0_k_1920.png'),
               ('clearing 1280 zoom1','clearing/clearing_over_k_zoom1_1280.png')]:
    _, (a,c,ref,edge,dl) = solve(S+kp, S+kp.replace('_k_','_w_'))
    ae=a[edge]; row={}
    for lo,hi in [(0.06,0.2),(0.2,0.5),(0.5,0.94)]:
        m=(ae>=lo)&(ae<hi); row[f'a{lo}-{hi}']=(round(float(dl[m].mean()),1), round(float(np.median(dl[m])),1), int(m.sum()))
    res[tag]=row; print(tag,row)
json.dump(res,open(S+'halo_alpha_bins.json','w'),indent=1)
