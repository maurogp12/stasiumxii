from h import *
from lev import dys
for F in 'SE':
    report(F)
    d,h=dys(F); print(F,'dy idle',d[0],'walk',d[1:])
