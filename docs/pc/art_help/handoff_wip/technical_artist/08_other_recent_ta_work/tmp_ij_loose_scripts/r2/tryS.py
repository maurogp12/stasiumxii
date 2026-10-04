from opt import *
import sys
F='S'
def run(gx,gy,gz,hf,yw,pole,lh=28.0, show=True):
    rig.ARM[('S','R')]=dict(grip=(gx,gy,gz),haft=hf,yaw=yw,pole=pole)
    rig.ARM[('S','L')]=dict(fist_x=92.0,reach=52.0,bend=100.0,haft=lh,yaw=0.0,pole=(0.5,-1.0,-0.1))
    J,M=joints(F,None,True)
    sh=M['upperarm_R'].translation; el=M['forearm_R'].translation; wr=M['forearm_R']@Vector((0,0,-rig.FORE))
    bend=180-math.degrees((sh-el).angle(wr-el))
    print('grip3',[round(v) for v in M['axe_R'].translation],'sh3',[round(v) for v in sh],'el3',[round(v) for v in el],'bend %.0f'%bend,'upper arm down-angle %.0f'%math.degrees(math.asin((sh.z-el.z)/rig.UPPER)))
    if show: report('S')
args=[float(a) for a in sys.argv[1:6]]; pole=tuple(float(v) for v in sys.argv[6].split(',')); lh=float(sys.argv[7]) if len(sys.argv)>7 else 28.0
run(*args,pole,lh)
