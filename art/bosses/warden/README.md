# Warden of the Sheaves (★1–4 redesign): approved animation set

## Design
Spectral harvest reaper. A hooded wooden mask, a robe of black straw with chains, gold ribs glowing in the chest, and a long scythe held in his right hand.
He never walks. He hovers 15–20 px with a slow 2 s bob, and his shadow shrinks and fades as he rises.
The hem streams back against the direction of travel and fades into smoke. Dark smoke wisps with gold ember tints trail behind him.
The scythe swings as a ±9° pendulum around the hand, lagging behind the bob, with a small blade bob.

## Direction map
W = front key (keys/war_front_v5.png) · S = front key mirrored · E = back key (keys/war_back.png) · N = back key mirrored.
He faces the direction of travel or his target. The blade always points toward travel/target and is never flipped upside down.

## Clips (video/, 1920x1080 2x2 N/E/S/W grid, 24 fps, H.264 High, yuv420p, crf 16, +faststart, fixed framing)
- warden_walk_4dir_v6.mp4: 8 s seamless float loop. The camera follows (the floor scrolls 1 tile step per 1 s).
- warden_spell_crows_4dir.mp4: 3.25 s, shown with Ironjaw and Kestrel.
  0.15–0.9 s: he rises and the robe flares. Around 0.62 s: a gold flare at the chest.
  From 0.5 s: 7 smoke crows with gold ember eyes burst from the chest and dive at the heroes.
  About 1.4–2.45 s: they peck, the heroes play their hit frames with a subtle tint, and feathers and smoke fly.
  2.3–2.8 s: the crows unravel into smoke. He returns to idle float by 3.25 s.
- warden_hit_death_4dir_v2.mp4: 6.5 s.
  Ironjaw's first hit lands at 1.15 s: recoil, stagger, warm tint, a chest flash and a smoke puff, then he recovers by 2.5 s.
  The second hit lands at 3.35 s: a sideways shake with motion blur, then the ribs flare from 3.4 to 4.2 s.
  4.0–5.6 s: a black smoke burst, with 7 painted crows flapping out on curved paths and falling feathers.
  From 4.45 s: the painted remains plate fades in on the unit's spot and holds to 6.5 s.

## Rules
- Exact limb and prop counts; palette kept from the keys.
- No falling on death; he dissolves into smoke and leaves remains.
- Subtle hit tints only; the shadow stays under the unit.
- Painted VFX only: smoke, crows, embers and the remains are cut from painted plates (plates/, assets/crows/).
- No holes or doubles. The scythe is cut cleanly; the strip of robe behind it is filled from robe texture.

## Rebuild
Run from scripts/ with keys/ and plates/ copied alongside:
- python3 rig4.py: walk.
- python3 crows4.py: spell.
- python3 hd4.py: hit/death.

Paths inside the scripts point at /workspace/foe_walks/harvest_v2 and need adjusting.
Hero sprites (Ironjaw, Kestrel) come from /workspace/art and are not included.
The attack is NOT approved and is excluded.
