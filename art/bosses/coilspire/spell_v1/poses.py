import sys; sys.path.insert(0,'/workspace/foe_walks/coilspire_v2/attack_v1')
from stills import *
os.chdir('/workspace/foe_walks/coilspire_v2/spell_v1')
# pose-only sheet (no VFX yet: painted VFX plates pending). rear, lift, lunge, charge
SK=[('1 WIND-UP',10,90,-15,0.8,'none'),('2 CAST (legs slam)',-7,0,25,1.0,'none'),('3 IMPACT hold',-6,0,25,0.9,'none'),('4 RELEASE',0,0,0,0.0,'none')]
Sh=Image.new('RGB',(1920,1080))
for r,dn in enumerate('we'):
    for c,kp in enumerate(SK): Sh.paste(scene(dn,kp).convert('RGB'),(c*480,r*540))
Sh.save('coilspire14_spell_POSES_noVFX_WE.png'); print('ok')
