import sys; sys.path.insert(0,'/workspace/crosshaven_paint/work/tilekit/scripts')
from render import *
# ---- ground check ----
n=40; V=np.zeros((n+1,n+1),int)
for i in range(n+1):
    for j in range(n+1):
        if abs(i-j)<=1: V[i,j]=2            # cobble street (screen vertical)
        if 3<=i<=8 and 12<=j<=17: V[i,j]=3  # plaza
        if abs((i+j)-30)<=1 and i>12: V[i,j]=4   # river
        if abs(j-6)<=0 and i>8: V[i,j]=1    # dirt path
        if abs(i-j)<=1 and abs((i+j)-30)<=1: V[i,j]=4
W,H=1920,1200; g=ground(V,W//2-64,-200,W,H,1)
# bridge over river where street crosses
bs,bm=piece('bridge_stone','ground')
put(g,'bridge_stone',W//2+40,15*64-200+40+150,'ground')
put_hero(g,W//2,520); put_hero(g,W//2-500,760)
d=ImageDraw.Draw(g); d.rectangle((0,0,W,60),fill=(255,255,255,230)); d.text((20,12),HDR+'  |  tilekit ground check (dual-grid atlases, hero 156px)',fill='black',font=font(28))
g.convert('RGB').save(R+'check_ground_CONCEPTO.jpg',quality=90)
# atlas sheet
S=Image.new('RGBA',(5*560,330),(200,200,200,255)); d=ImageDraw.Draw(S)
for k,t in enumerate(PR): S.alpha_composite(AT[t],(k*560+20,50)); d.text((k*560+20,10),t,fill='black',font=font(26))
S.convert('RGB').save(R+'check_atlases_CONCEPTO.jpg',quality=92)
# ---- walls check ----
n=70; V=np.zeros((n+1,n+1),int); W,H=5200,1500
g=ground(V,W//2,-2000,W,H,2)
y=1300; x=120
items=[('wall_h',0),('tower_round',0),('gate_h',0),('wall_diag_se',0),('wall_diag_ne',0),('water_tunnel_h',0),('gate_diag_se',0),('water_tunnel_diag_se',0)]
for nm,_ in items:
    im,m=piece(nm); fx=x+m['foot'][0]; 
    if nm.startswith('gate'):
        dm=m['door']; st=Image.open(R+'walls/'+dm['file']); fwid=dm['frame_w']; fr=st.crop((0,0,fwid,dm['frame_h'])) # closed
        ox=fx-m['foot'][0]; oy=y-m['foot'][1]; g.alpha_composite(fr,(int(ox+dm['offset'][0]),int(oy+dm['offset'][1])))
    put(g,nm,fx,y); x+=im.width-20
    if x>W-500: break
put_hero(g,60+40,y)
d=ImageDraw.Draw(g); d.rectangle((0,0,W,60),fill=(255,255,255,230)); d.text((20,12),HDR+'  |  tilekit walls check (hero 156, wall 550, tower 990)',fill='black',font=font(30))
g.convert('RGB').save(R+'check_walls_CONCEPTO.jpg',quality=88)
# door strip preview
st=Image.open(R+'walls/gate_door_h_CONCEPTO.png'); bg=Image.new('RGBA',st.size,(40,60,40,255)); bg.alpha_composite(st); bg.convert('RGB').save(R+'check_doors_CONCEPTO.jpg')
# ---- mock ----
n=60; V=np.zeros((n+1,n+1),int)
for i in range(n+1):
    for j in range(n+1):
        if abs(i-j)<=1: V[i,j]=2
W,H=2400,1350; g=ground(V,W//2-64,-1600,W,H,3)
fy=900; cx=W//2
gm=json.load(open(R+'walls/gate_h_CONCEPTO.json')); gi=Image.open(R+'walls/gate_h_CONCEPTO.png')
gw=gi.width-100
# door open frame 7 then gate
dm=gm['door']; st=Image.open(R+'walls/'+dm['file']); fr=st.crop((7*dm['frame_w'],0,8*dm['frame_w'],dm['frame_h']))
ox=cx-gm['foot'][0]; oy=fy-gm['foot'][1]
wm=json.load(open(R+'walls/wall_h_CONCEPTO.json')); wi=Image.open(R+'walls/wall_h_CONCEPTO.png'); ww=wi.width-100
tm=json.load(open(R+'walls/tower_round_CONCEPTO.json'))
# walls left and right
for k in range(1,6):
    put(g,'wall_h',cx-gw//2-ww*(k-0.5),fy); put(g,'wall_h',cx+gw//2+ww*(k-0.5),fy)
g.alpha_composite(fr,(int(ox+dm['offset'][0]),int(oy+dm['offset'][1])))
put(g,'gate_h',cx,fy)
for sx in (-1,1): put(g,'tower_round',cx+sx*(gw//2),fy+50)
put_hero(g,cx+30,fy+260)
d=ImageDraw.Draw(g); d.rectangle((0,0,W,60),fill=(255,255,255,230)); d.text((20,12),HDR+'  |  mock: wall - tower - gate (open) - tower - wall',fill='black',font=font(30))
g.convert('RGB').save(R+'mock_gate_run_CONCEPTO.jpg',quality=90)
print('done')
