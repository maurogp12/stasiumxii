#!/bin/bash
# build_all.sh TAG(or "ship") [roles...]
TAG=$1; shift
ROLES=${@:-farmer woodcutter fisher smith hermit coil_engineer warden guide herald banker elder trader door_keeper archivist forge_master ferry_captain fen_guide last_watcher shard_seer}
cd /workspace/stasium-pc-look/tools/npc
P=/workspace/scratch/npc_sprites/.venv/bin/python
mkdir -p /workspace/scratch/ta_fix/logs
for r in $ROLES; do
  if [ "$TAG" = ship ]; then echo "$P build_npc.py --role $r > /workspace/scratch/ta_fix/logs/${r}_ship.log 2>&1 || echo BUILD_FAIL $r";
  else echo "$P build_npc.py --role $r --tag $TAG > /workspace/scratch/ta_fix/logs/${r}_$TAG.log 2>&1 || echo BUILD_FAIL $r"; fi
done | xargs -P ${JOBS:-6} -I{} bash -c "{}"
echo ALLDONE
