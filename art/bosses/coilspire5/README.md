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

## Attack: pincer strike (`attack_v2/`)

Approved by Mauro on 2026-10-15. Preview only; not wired into the game.

A wind-up with the pincers opening (capped at 18° front and 16° back so the claws don't tear), the tail cocked and the orb charging. A 40 px two-beat lunge step to melee range with the feet planted. A 2-frame snap to -22° and a tail flick that fires a short zap into Ironjaw. A burst with a 10% hit tint. Then the step back and a settle to walk frame 0.

It is 80 frames on one fixed camera, 1920x1080 at 24 fps (`coilspire5_attack_4dir.mp4`).

The earlier tail-sting attempt failed because the painted tail can't reach forward (`tail_swing_test_W.png`). The heavy orb beam (`attack_v1` stills) is being reused in the ★5 spell.

Scripts: `pincer.py` and `sting.py`.

## Spell: Tormenta de Crías (`spell_v1/`)

Approved by Mauro on 2026-10-15 (v6). Preview only; not wired into the game.

Final videos: `coilspire5_spell_4dir_v6.mp4` (2x2 N/E/S/W, 1920x1080, 24 fps, H.264 High, yuv420p, crf16, faststart, 10.9 s loop) and `coilspire5_spell_E_v6.mp4` (E cell close-up).

Gameplay rules:

- The boss casts (tail up, orb charges) and summons 4 scorplings on the tiles 1 tile around himself (never on his legs).
- Each scorpling: 20 HP, 5 MP (bars shown above each).
- They walk (jointed leg rig, alternating tripods, planted feet, ~2 steps/s) to their targets and detonate in an area explosion on arrival (chain).
- If killed early, a scorpling detonates where it dies (area burst, pushed away from the heroes).
- The orb reforms after the blasts.

Facing: scorplings face their travel direction. W/S use the front plate (flipped by travel side); N uses the back plate as painted (head left), E uses it mirrored (head right).

Sources: `svid5v6.py` (render), `rig/scorp_rig.py` + `rig/scorpling_front_matte.png`, `rig/scorp_rig_back.py` + `rig/scorpling_back_matte.png`. Rig scripts read the original plates from `/workspace/c5_fw.png` / `/workspace/c5_bv.png` (copies included in `rig/plates/`).
