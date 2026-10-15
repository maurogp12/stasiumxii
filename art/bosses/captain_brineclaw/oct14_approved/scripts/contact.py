from PIL import Image, ImageDraw, ImageFont
D='/workspace/foe_walks/cb3_out/captain_brineclaw_v3'; NM='captain_brineclaw'
rows=[(a,k) for k in 'swen' for a in ('idle','walk','attack','hit','cast','death')]
fnt=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',11); cw,ch=72,84
out=Image.new('RGB',(100+16*cw,len(rows)*ch),(128,128,128)); dr=ImageDraw.Draw(out)
for r,(a,k) in enumerate(rows):
    im=Image.open(f'{D}/{NM}_{a}_{k}.png').convert('RGBA'); dr.text((4,r*ch+36),f'{a} {k}',font=fnt,fill=(255,255,255))
    for i in range(im.width//288):
        c=im.crop((i*288,0,i*288+288,336)).resize((cw,ch),Image.LANCZOS); out.paste(c,(100+i*cw,r*ch),c)
out.save('/workspace/foe_walks/cb3_out/captain_brineclaw_v3_contact.png'); print(out.size)
