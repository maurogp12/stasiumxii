import json,os,sys,urllib.request
K=os.environ['MESHY_API_KEY'];B='https://api.meshy.ai/openapi/'
def req(p,body=None):
  r=urllib.request.Request(B+p,json.dumps(body).encode() if body else None,{'Authorization':'Bearer '+K,'Content-Type':'application/json'})
  return json.loads(urllib.request.urlopen(r).read())
def log(job,tid,cr,note=''):
  open('credits_log.csv','a').write(f"{__import__('datetime').datetime.now():%Y-%m-%d %H:%M ET},{job},{tid},{cr},{note}\n")
