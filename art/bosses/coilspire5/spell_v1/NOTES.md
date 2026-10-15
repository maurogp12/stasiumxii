# Coilspire ★5 — spell "Tormenta de Crías" (gameplay rules)

- The boss **summons 4 scorplings at a distance**: summon flashes on tiles ~2–3 tiles from the heroes (not fired from the orb).
- Each scorpling: **20 HP, 5 MP**. A small HP bar (and MP bar) is shown above each one.
- Power: it **explodes for big area (AoE) damage** when it reaches its target.
- **Counterplay:** if the player kills it before it arrives, it **detonates where it stands** (the AoE then goes off away from the heroes).
- Video v2 (`coilspire5_spell_4dir_v2.mp4`) shows: cast → 4 remote summons → hop toward heroes → Kestrel kills one early (it bursts in place) → the other 3 chain-explode on the heroes → orb reforms.

## v4 update (spawn rule)
- Scorplings are summoned AROUND the boss: 4 flashes on the tiles ~1 tile out from the boss's leg footprint (fan on the targets' side), never on the boss.
- They then scuttle on the ground to their targets (alternating leg pairs, feet planted, glide matched to step) and detonate in an AoE on arrival; one killed en route detonates where it dies.
- Stats unchanged: 20 HP, 5 MP each; AoE explosion; detonates if killed.

## README — Coilspire ★5 spell "Tormenta de Crías" (APPROVED Oct 15 2026, v6)
Final videos: `coilspire5_spell_4dir_v6.mp4` (2x2 N/E/S/W, 1920x1080, 24fps, H.264 High, yuv420p, crf16, faststart, 10.9 s loop) and `coilspire5_spell_E_v6.mp4` (E cell close-up).
Gameplay rules:
- Boss casts (tail up, orb charges) and summons 4 scorplings on the tiles 1 tile around himself (never on his legs).
- Each scorpling: 20 HP, 5 MP (bars shown above each).
- They walk (jointed leg rig, alternating tripods, planted feet, ~2 steps/s) to their targets and detonate in an area explosion on arrival (chain).
- If killed early, a scorpling detonates where it dies (area burst, pushed away from the heroes).
- Orb reforms after the blasts.
Facing: scorplings face their travel direction. W/S use the front plate (flipped by travel side); N uses the back plate as painted (head left), E uses it mirrored (head right).
Sources: `svid5v6.py` (render), `rig/scorp_rig.py` + `rig/scorpling_front_matte.png`, `rig/scorp_rig_back.py` + `rig/scorpling_back_matte.png`. Rig scripts read the original plates from `/workspace/c5_fw.png` / `/workspace/c5_bv.png` (copies included in `rig/plates/`).

## Changelog
- 2026-10-15 — Coilspire ★5 spell Tormenta de Crías approved (v6): summon 1 tile around the boss; 20 HP / 5 MP; walk to targets; area explosion; detonate if killed early; scorplings face travel (N = back plate as painted, E = mirrored).
