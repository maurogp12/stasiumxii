import sys
from PIL import Image
# usage: view.py out scale bg files...
out=sys.argv[1]; sc=int(sys.argv[2]); bg=tuple(int(x) for x in sys.argv[3].split(','))
ims=[Image.open(f).convert('RGBA') for f in sys.argv[4:]]
W=sum(i.width*sc+10 for i in ims)+10; H=max(i.height*sc for i in ims)+20
can=Image.new('RGBA',(W,H),bg+(255,))
x=10
for i in ims:
    j=i.resize((i.width*sc,i.height*sc),Image.NEAREST)
    can.alpha_composite(j,(x,10)); x+=j.width+10
can.save(out)
