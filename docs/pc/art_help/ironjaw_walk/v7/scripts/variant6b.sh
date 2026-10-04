#!/bin/bash
# variant6.sh <name> '<python dict update for CFG[E]>'   -> builds E only, scores vs the NEW E target
N=$1; F=${F:-E}; UPD=$2; D=/workspace/scratch/ij_walk/v7/var/$N; mkdir -p $D
PY=/workspace/scratch/npc_sprites/.venv/bin/python
$PY -c "
import json; C=json.load(open('/workspace/scratch/ij_walk/v7/cfg6.json')); C['$F'].update($UPD); json.dump(C, open('$D/cfg.json','w'), indent=1)"
CFG4C=$D/cfg.json V4ROOT=$D/out PK=$D/data.pkl $PY /workspace/scratch/ij_walk/v7/build6.py $F > $D/build.log 2>&1 || { echo $N BUILD FAIL; tail -5 $D/build.log; exit 1; }
FACS=$F /workspace/scratch/ij_walk/v7/score6.sh $D/out/walk $N $D /workspace/scratch/ij_walk/repaint_E2/rp_E_stride_t2.jpg /workspace/scratch/ij_walk/repaint_E2/rp_S_turn_t1.jpg | sed "s/^/$(grep -o 'raise [0-9]*' $D/build.log | head -1) /"
$PY - $D/build.log <<'PY'
import re,sys; t=open(sys.argv[1]).read()
h=[int(x) for x in re.findall(r"'cape_hem': (-?\d+)",t)]; ax=[int(x) for x in re.findall(r"'(?:left|right)': (-?\d+)",t)]
k=re.findall(r"k \[(.*)\]",t)
print('   hem min', min(h) if h else None, 'axe min', min(ax) if ax else None, '| k2', k[0][:200] if k else '')
PY
