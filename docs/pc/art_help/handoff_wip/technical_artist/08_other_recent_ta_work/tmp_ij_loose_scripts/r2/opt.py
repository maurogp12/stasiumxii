import sys, math, json
import numpy as np
sys.path.insert(0,'/workspace/tmp_ij/r2')
from h import *

def nm(f, x0, step, iters=600):
    n=len(x0); pts=[np.array(x0,float)]
    for i in range(n):
        p=np.array(x0,float); p[i]+=step[i]; pts.append(p)
    vals=[f(p) for p in pts]
    for it in range(iters):
        o=np.argsort(vals); pts=[pts[i] for i in o]; vals=[vals[i] for i in o]
        c=np.mean(pts[:-1],axis=0); xr=c+(c-pts[-1]); fr=f(xr)
        if fr<vals[0]:
            xe=c+2*(c-pts[-1]); fe=f(xe)
            if fe<fr: pts[-1],vals[-1]=xe,fe
            else: pts[-1],vals[-1]=xr,fr
        elif fr<vals[-2]: pts[-1],vals[-1]=xr,fr
        else:
            xc=c+0.5*(pts[-1]-c); fc=f(xc)
            if fc<vals[-1]: pts[-1],vals[-1]=xc,fc
            else:
                for i in range(1,len(pts)): pts[i]=pts[0]+0.5*(pts[i]-pts[0]); vals[i]=f(pts[i])
    i=int(np.argmin(vals)); return pts[i], vals[i]
relu=lambda v: max(0.0,v)
