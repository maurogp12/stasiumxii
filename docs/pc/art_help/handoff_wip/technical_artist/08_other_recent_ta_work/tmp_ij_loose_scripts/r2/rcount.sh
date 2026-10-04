#!/bin/bash
# usage: rcount.sh name 'json'
D=/workspace/tmp_ij/r2/rt/$1; mkdir -p $D
OUT=$D ARMOV="$2" /workspace/art_src/blockout/ironjaw_walk/.venv/bin/python /workspace/tmp_ij/r2/rtest.py > $D/log.txt 2>&1
python3 - "$D" <<'P'
import sys,glob,os,numpy as np
from PIL import Image
d=sys.argv[1]; r=[]
for p in sorted(glob.glob(d+'/sides/*_E*.png')):
    a=np.array(Image.open(p).convert('RGBA')).astype(int)
    m=(np.abs(a[...,:3]-np.array((220,60,210))).sum(-1)<30)&(a[...,3]>0); r.append(int(m.sum()))
print(os.path.basename(d),'axeL px idle+walk:',r,'max',max(r) if r else None)
P
