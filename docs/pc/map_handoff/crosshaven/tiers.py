from PIL import Image;import json,numpy as np,os,glob
HS='/workspace/stasium-pc-look/ship/housing_v1/pieces/';CH='/workspace/stasium-pc-look/ship/crosshaven_housing_v1/pieces/';PC='/workspace/stasium-pc-look/ship/crosshaven_full_v1/pieces/_2x/'
def L(p,w=None,h=None):
  im=Image.open(p).convert('RGBA');im=im.crop(im.getbbox())
  if w:h=int(im.height*w/im.width)
  elif h:w=int(im.width*h/im.height)
  return im.resize((w,h),Image.LANCZOS)
for f in glob.glob('housing_tiers/lot_*.png')+glob.glob('housing_tiers/garden_*.png'):os.remove(f)
def comp(parts,size):
  c=Image.new('RGBA',size,(0,0,0,0))
  for im,(x,y) in parts:c.alpha_composite(im,(int(x-im.width/2),int(y-im.height)))
  return c.crop(c.getbbox())
json.dump({'anchor':'bottom-center of house sprite = plot point (same for all tiers)','plot_clearance_px':{'normal':200,'rare':260,'legendary':350},
 'note':'No lots, fences, dirt or garden beds. Swap house_normal/rare/legendary in place at the plot point; plants are separate props on grass.'},open('housing_tiers/tiers.json','w'),indent=1)
for t,w in [('normal',170),('rare',238),('legendary',330)]:
  if t=='normal':  # housing_v1 normal has a baked dirt/fence yard ring -> Crosshaven cottage on grass
    im=Image.open(PC+'cx_cottage_restyle_a.png').convert('RGBA')
  else:im=Image.open(HS+f'exteriors/house_{t}_ext.png').convert('RGBA')
  im=im.crop(im.getbbox());im.resize((w,int(im.height*w/im.width)),Image.LANCZOS).save(f'housing_tiers/house_{t}.png')
