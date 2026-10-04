import sys; sys.argv=['x']
exec(open('optE.py').read().split("x0=[")[0])
from prev import *
import json
x=json.load(open(sys.argv_file if False else 'bestE.json')); sp=unpack(x); PP,_=build('E',sp); setE(PP['R'],PP['L'])
setS(dict(grip=(101,15,-49),haft=5.0,yaw=30.0,pole=(0.7,-0.5,-1.0),wf=0.2),dict(fist_x=92.0,reach=52.0,bend=100.0,haft=34.0,yaw=0.0,pole=(0.5,-1.0,-0.1),wf=-0.2))
rows('prev_S.png',facings='S'); rows('prev_E.png',facings='E')
big('big_E.png','E',[None,1,7]); big('big_S.png','S',[None,0,6])
