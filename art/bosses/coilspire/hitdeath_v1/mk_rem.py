from cutfn import *
im=Image.open('/cursor/stores/store-c01dd204-c037-4a89-b6fe-7a06d7c1b2f9/grok-bot/agents/10888a55-2177-4c78-97bf-f62165f60d9b/attachments/2e26f4225a3396cc75f7da3073d5d9f4be7b74feae49e8a628d345b7361c6951.jpg').convert('RGB')
print(im.size); c=cut(im); c.save('remains_plate.png'); print(c.size)
b=Image.new('RGBA',c.size,(255,0,255,255)); b.alpha_composite(c); b.save('/tmp/coil_rp_m2.png'); im.save('/tmp/coil_rp_src1.png')
