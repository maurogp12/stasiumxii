# Kestrel actions v1: idle, attack, skill, hit and death

> **LOCKED, 4 Oct 2026, at `d0224452`.** Mauro: "lock both of them as of right now, keep everything documented for a future modification." These frames ship to the game as they are. To change them later, read **Known issues for a future pass** below and the scripts in `scripts/`, then re-run the same pipeline. Don't hand-edit frames.

## Known issues for a future pass (recorded at lock)
- **Front attack and skill, f03–f09:** the draw fist is the reused bow-hand fist and covers part of her right jaw. Fix: a painted fist with fingers hooked on the string.
- **Back attack and skill, f02–f09:** the draw fist reads as a small dark shape beside the hood. Same fix.
- **Key swap frames** (attack and skill f01/f11, front hit f01, death f02–f04): the sleeve texture changes in a single frame. Raised upper arms are straight tubes with no taper.
- **Front shooting:** a soft blended patch near the right shoulder when she raises the bow arm.
- **Front death:** the cloak is still a fold, not a drape (only the back death was redone).
- **Back death, f06–f12:** you see her back lying down.
- **Hit:** no step back; the pelvis moves only 0.03 H, as in the blockout.
- **Arm stretch:** back hit f05 and back and front death f12 sit right at the 15% limit.
- **Blockout aim:** the blockout aim was rotated 40° in our own `act_blockout.py` (aimfix), and the back death falls to the side. The approved blockout files were not changed.
