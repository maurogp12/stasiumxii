# Coilspire boss - approved redesign, Oct 14 2026

Mauro rejected the old coil-tower look on Oct 14 2026 and picked the evil redesign.
Preview art only; not yet wired into the game.

**Coilspire ★1-4 is complete** (walk, attack, spell, hit/death). Star 5 is not in this set.

## What's here

- `coilspire_v2/`: ★1-4 walk. Keys, strips, scripts, check frames, and `coilspire14_walk_4dir.mp4`.
- ★1-4 has 6 legs in a tripod gait.
- `attack_v1/`: ★1-4 attack, approved by Mauro on 2026-10-14. See below.
- `spell_v1/`: ★1-4 spell Grave Web, approved by Mauro on 2026-10-14. See below.
- `hitdeath_v1/`: ★1-4 hit and death, approved by Mauro on 2026-10-15. See below.

## Concept art in `coilspire_v2/keys/`

- `defaf65cefb79703648e587e5c55a31c26f3fe2f44d9b39188f80ea9cc7842ba.jpg` (`defaf65c`): ★1-4 skull iron spider (6 legs).
- `c5ef6c37a5b177fd13654b0ca594b01a0e342ac5baaa82b99f5096d9e5d979d8.jpg` (`c5ef6c37`): ★5 demon scorpion.
- `42409d9b3e5385a5db9537d3108191ed214e178c0d509d845858fa898222981a.jpg` (`42409d9b`): approved turned keys.

## ★1-4 attack (`attack_v1/`)

Approved by Mauro on 2026-10-14. Preview only; not wired into the game.

The attack is a rear-back with the hind legs pinned to the ground, a raised front-leg lift, a charge along the spine, then a lunge and a forked lightning bolt that hits both targets (Ironjaw and Kestrel). Sparks stay inside each cell. Framing stays constant.

- 4 directions.
- Video: `coilspire14_attack_4dir.mp4`, 1920x1080 at 24 fps, H.264.
- Scripts: `stills.py` and `avid.py`.
- Stills sheet: `coilspire14_attack_stills_WE.png`.

## ★1-4 spell Grave Web (`spell_v1/`)

Approved by Mauro on 2026-10-14. Preview only; not wired into the game.

The spell charges the orb and spine, slams its front legs, and a painted skull-centered web of violet chain lightning spreads across the floor from its feet under both targets. Lightning pillars then snare Ironjaw and Kestrel (10% hit tint), the web bursts into sparks at 60% opacity, it fades, and Coilspire settles to walk frame 0.

- The 4 painted plates are in `plates/` (`charge.jpg`, `web.jpg`, `snare.jpg`, `burst.jpg`), keyed by luminance with screen blending. No procedural effects.
- Video: `coilspire14_spell_4dir.mp4`, 132 frames at 24 fps, 1920x1080.
- `sheet.py` drives both the stills and the video.

## ★1-4 hit and death (`hitdeath_v1/`)

Approved by Mauro on 2026-10-15. Preview only; not wired into the game. This completes Coilspire ★1-4 (walk, attack, spell, hit/death).

A subtle hit flinch (5% tint on W/S, 3% on E/N). Death with no falling: a violet overload, then a painted burst while the body dissolves. Remains are made from a painted plate (`remains_plate_src.jpg`: a heap of 6 broken legs with the skull on top and the coil spine snapped in two), matted, with a soft shadow, flickering spine sparks and pulsing eyes.

- Video: `coilspire14_hit_death_4dir.mp4`, 5.1 s at 24 fps, 1920x1080.
- Scripts: `remains.py`, `sheet_hd.py`, `mk_rem.py`, `cutfn.py`, `hdvid.py`.

## Mauro's rules (all bosses)

Same rules as `art/bosses/serra/README.md`:

- Latest art only; exact limb/prop counts every frame; same palette across actions.
- Face, chest and body clearly TURN toward travel direction; never slide a frontal key sideways.
- S opposite N, W opposite E, no moonwalk.
- Staff in front views moves only up/down, never a 360 spin.
- Death: no falling - dissolve and leave remains. Hit tints subtle.
- No seams/specks; shadow under the unit. Show stills before animating. Change ONLY what Mauro points out.
