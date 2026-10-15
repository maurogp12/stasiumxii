# Sheaf Sovereign: approved animation set

## Design
Spectral harvest king. He wears a crown of upward wheat-sickle spikes, a robe of golden-black straw, and carries a long scythe.
Six small golden sickles orbit him at all times.
He never walks. He floats with a slow bob, and his shadow stays under him.

## Direction map
W = front key (keys/sov_front.png) · S = front key mirrored · E = back key (keys/sov_back.png) · N = back key mirrored.
He faces the direction of travel or his target. The blade is never upside down, and there is no moonwalk.

## Clips (video/, 1920x1080 2x2 N/E/S/W grid, 24 fps, H.264 High, yuv420p, crf 16, +faststart)
- sheaf_sovereign_walk_4dir_v4.mp4: float walk loop (sov4.py).
- sov_attack_4dir.mp4: 3 s melee strike at 1 tile (sovatk4.py).
  Idle → overhead windup, with the sickles gathering into a ring → strike with a black smoke wave and the sickles strung out along the blade path → impact on Ironjaw → recover.
- sov_spell_hands_4dir_v2.mp4: 3.7 s (sovspell_anim2.py + sovspell8.py).
  He casts, a rune circle and cracks open, and ONE giant hand per hero rises from the circle.
  The hand comes out OPEN, fingers spread. It closes open → mid-close → grip as it grabs; the hero lifts.
  It squeezes into a fist with 2 pulses, opens back fist → mid-close → open, and the open hand sinks whole into the ground.
  The states cross-dissolve over about 3–4 frames. All hand states share the same wrist anchor and scale.
- sov_hit_death_4dir.mp4: 6 s (sovhd4.py).
  Hit at 0.5 s: a small recoil away from the attacker, a subtle warm tint, a flash and a smoke puff, and the sickles jolt. Then a pause.
  1.9 s: he shudders and the inner glow flares.
  2.45 s: he dissolves into black smoke and wisps, with NO fall. The 6 sickles are flung out, then drop.
  2.7 s: the crown falls.
  From about 3.2 s: the remains (crown + 6 sickles on a small black ash/wheat-chaff heap) fade in on his tile and hold to the end.

## Rules (Mauro)
- Exactly 6 sickles. The mirrored 6th sickle is used on the back key.
- Painted VFX only, cut from the plates. No holes, no doubles.
- The blade always faces travel/target and is never flipped upside down.
- The shadow stays under the unit. Hit tints are subtle.
- Hands spell: one giant hand per hero (not many small hands). Fists curl in toward the hero.
  The hand rises OPEN and closes only when it grabs. No hard pops between hand states.
- Death: no falling. He bursts into smoke and leaves remains.
  In W the remains sit nudged within his tile so the heroes don't cover them.

## Layout
- scripts/: the rigs and renderers. scripts/cuts/ holds the plate keying (cut3 for the rune circle, spray and burst; cut7 for the grip/fist hands; cut8 for the open/mid-close hands).
- keys/: the boss keys.
- plates/: the painted sources.
- sprites/hands/: the keyed hand, ring and VFX sprites.
- assets/: smoke, embers and crows (shared with the Warden).
- stills/: the approved still sheets.

## Rebuild
Paths inside the scripts point at /workspace/foe_walks/harvest_v2 (sprites expected in spell_concepts/hands_v2, assets in spell_concepts/assets) and at harvest_spell_v1/sheet.py; adjust them as needed.
Hero sprites (Ironjaw, Kestrel) come from /workspace/art and are not included.
