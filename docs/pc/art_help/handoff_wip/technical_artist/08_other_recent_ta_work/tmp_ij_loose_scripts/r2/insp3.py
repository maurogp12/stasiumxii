import sys; jf=sys.argv[1]; sys.argv=['x','-1','/dev/null']
exec(open('optAll_E.py').read().split("x0=[")[0])
from prev import *
a=json.load(open(jf)); PP,_=build('E',mk(a)); setE(PP['R'],PP['L']); print(json.dumps(PP))
report('E',coll=True)
d,h=dys('E'); print('dy',d); print('Rhead',[round(t[0]) for t in h]); print('Lhead',[round(t[1]) for t in h])
J,M=joints('E',None,True)
for n in 'RL':
    sh=M['upperarm_'+n].translation; el=M['forearm_'+n].translation; wr=M['forearm_'+n]@Vector((0,0,-rig.FORE))
    print(n,'grip',f1(J[n+'_grip']),'head',f1(J[n+'_head']),'el3',[round(v) for v in el],'grip3',[round(v) for v in M['axe_'+n].translation],'bend %.0f'%(180-math.degrees((sh-el).angle(wr-el))))
big('tmpE.png','E',[None,1,4,7,10])
from PIL import Image; im=Image.open('tmpE.png'); im.resize((im.width*3//2,im.height*3//2),Image.NEAREST).save(jf.replace('.json','_v.png'))
