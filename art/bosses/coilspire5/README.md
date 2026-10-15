# Coilspire ★5 - demon scorpion, design C

Approved by Mauro on 2026-10-15. Preview art only; not yet wired into the game.
Boss rules are the same as `art/bosses/coilspire/README.md`.

## Walk (`walk_v1/`)

### Keys

Front 3/4 down-left and back 3/4 up-right. Both are painted and matted from grey. The back key is scaled 0.8 so the body matches the front.

This pack's `keys/` holds the back key: `raw_back.png` and `seg_back.png`. `mk_keys.py` writes both sides from the painted sources.

### Direction map

- W = front
- S = front mirrored
- E = back
- N = back mirrored

### Legs and pincers

4 legs in the front key and 5 in the back key, exactly as painted. Mauro accepted that count. 2 pincers are rigged separately.

### Gait

Alternating on a 1 s cycle. No planted-foot slip. 14 px lift. 2.5 px bob. The tail and orb sway, with a flickering glow.

### Video and scripts

- Video: `coilspire5_walk_4dir.mp4`, 2x2 at 1920x1080, 24 fps.
- Scripts: `mk_keys.py`, `anim5.py`, `vid.py`, and `check.py`.
