import sys, os, json, runpy
sys.path.insert(0,'/workspace/art_src/blockout/ironjaw_walk/src')
import bpy
import rig
ov=json.loads(os.environ['ARMOV'])
for k,v in ov.items():
    F,s=k.split('_'); d=dict(rig.ARM[(F,s)]); d.update({kk:(tuple(vv) if isinstance(vv,list) else vv) for kk,vv in v.items()}); rig.ARM[(F,s)]=d
sys.argv=['render.py']
runpy.run_path('/workspace/art_src/blockout/ironjaw_walk/src/render.py',run_name='__main__')
