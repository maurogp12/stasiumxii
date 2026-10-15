from PIL import Image, ImageDraw
src=open('../matte.py').read(); exec(src[:src.index('tiles=[]')])
im=Image.open('/cursor/stores/store-c01dd204-c037-4a89-b6fe-7a06d7c1b2f9/grok-bot/agents/10888a55-2177-4c78-97bf-f62165f60d9b/attachments/01e60239fa7a5fcfdf9892cced307c2a36c5d180e3453bdf4c4e8daabb0eed22.jpg'); W,H=im.size
ch=Image.new('RGBA',(2*576,672),(40,42,50,255)); d=ImageDraw.Draw(ch)
for n,(side,box) in enumerate((('front',(0,0,W//2,H)),('back',(W//2,0,W,H)))):
    c=fit(cut(im.crop(box))); c.save(f'keys/s5_{side}.png')
    g=c.copy(); dg=ImageDraw.Draw(g)
    for x in range(0,288,20): dg.line([(x,0),(x,336)],fill=(255,255,0,90) if x%100 else (255,255,0,220))
    for y in range(0,336,20): dg.line([(0,y),(288,y)],fill=(255,255,0,90) if y%100 else (255,255,0,220))
    ch.alpha_composite(g.resize((576,672),Image.NEAREST),(n*576,0))
ch.save('keys/keys_check.png')
