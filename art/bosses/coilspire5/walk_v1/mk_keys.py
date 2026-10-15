from cutfn import *
a=Image.open('/cursor/stores/store-c01dd204-c037-4a89-b6fe-7a06d7c1b2f9/grok-bot/agents/10888a55-2177-4c78-97bf-f62165f60d9b/attachments/1d3bf58cbfba623a49d1ee12718b5df71f40971946adcf8646d7dd0ae08b276a.jpg').convert('RGB')
b=Image.open('/cursor/stores/store-c01dd204-c037-4a89-b6fe-7a06d7c1b2f9/grok-bot/agents/10888a55-2177-4c78-97bf-f62165f60d9b/attachments/b9cef0d123c881b2cda39240ea28e8b09ad0d3ee8ca7bfc8c4730bc9f3f40b7a.jpg').convert('RGB')
for side,im in (('front',a.crop((0,0,640,720))),('back',b)):
    c=cut(im); c.save(f'keys/raw_{side}.png'); print(side,c.size)
