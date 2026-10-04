from h import *
def heads(F):
    out=[]
    for f in [None]+list(range(12)):
        J,_=joints(F,None if f is None else (f+PH[F])%12, f is None)
        out.append((J['R_head'][1],J['L_head'][1],J['R_head'][0],J['L_head'][0],J['R_grip'],J['L_grip']))
    return out
def dys(F):
    h=heads(F); return [round(a[0]-a[1],1) for a in h], h
def setS(R,L):
    rig.ARM[('S','R')]=R; rig.ARM[('S','L')]=L
def setE(R,L):
    rig.ARM[('E','R')]=R; rig.ARM[('E','L')]=L
