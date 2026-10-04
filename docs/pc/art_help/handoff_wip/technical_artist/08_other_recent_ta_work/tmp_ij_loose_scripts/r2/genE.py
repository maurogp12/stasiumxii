from lev import *
def build(F, spec):
    """spec[side] = dict(el=(lat,fwd,down_len_dir...), fa=(lat,fwd,up), haft, yaw, wf). lat is + outward."""
    M=rig.pose(None,idle=True,cheat=rig.CHEAT[F],facing=F)
    shR=M['upperarm_R'].translation.copy(); shL=M['upperarm_L'].translation.copy()
    e1=Vector((shR.x-shL.x,shR.y-shL.y,0)).normalized(); e3=Vector((0,0,1)); e2=e3.cross(e1)
    out={}
    for n,s in (('R',1),('L',-1)):
        p=spec[n]; sh=shR if n=='R' else shL
        if 'direct' in p:
            out[n]={k:(tuple(float(t) for t in v) if isinstance(v,tuple) else float(v)) for k,v in p['direct'].items()}; continue
        def w(v): return s*v[0]*e1+v[1]*e2+v[2]*e3
        ed=w(p['el']).normalized()*rig.UPPER; fd=w(p['fa']).normalized()*rig.FORE
        el=sh+ed; wr=el+fd
        Rax=Matrix.Rotation(0,4,'X')@Matrix.Rotation(math.radians(-s*p['yaw']),4,'Z')@Matrix.Rotation(math.radians(-p['haft']),4,'X')
        wl=Rax.to_3x3()@Vector(rig.WRIST_IN_FIST); g=wr-wl
        out[n]=dict(grip=(round(s*g.x,2),round(g.y-sh.y,2),round(g.z-sh.z,2)),haft=float(p['haft']),yaw=float(p['yaw']),
                    pole=tuple(round(v,3) for v in (s*ed.x,ed.y,ed.z)),wf=float(p.get('wf',0.4)))
    return out, (e1,e2)
