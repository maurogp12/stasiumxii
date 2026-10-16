from PIL import Image,ImageDraw
import json,sys
Image.MAX_IMAGE_PIXELS=None
I=json.load(open('build_info.json'));P=Image.open('crosshaven_built_plate.jpg');J=json.load(open('bridge_joins.json'))
S=Image.new('RGB',(1500,960));d=ImageDraw.Draw(S);k=0
for bi,B in enumerate(I['bridge_info']):
  for e in('nw','se'):
    E=B['end_pts'][e]['E'];O=B['end_pts'][e]['O'];cx,cy=(E[0]+O[0])/2,(E[1]+O[1])/2
    c=P.crop((int(cx-250),int(cy-170),int(cx+250),int(cy+170)))
    S.paste(c,((k%3)*500,(k//3)*480));j=[q for q in J if q['bridge']==bi and q['end']==e][0]
    d.text(((k%3)*500+6,(k//3)*480+344),f"bridge {bi} {e} end: centre offset {j['road_center_vs_deck_center_px']} px, road {j['road_width_px']} / deck {j['deck_width_px']} px\nside steps {j['side_steps_px']}  straight run {round(((O[0]-E[0])**2+(O[1]-E[1])**2)**.5)} px",fill=(255,255,0));k+=1
S.save(sys.argv[1],quality=88)
