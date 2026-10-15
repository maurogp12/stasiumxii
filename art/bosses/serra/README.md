# Serra (Frost boss) - approved art & animation, Oct 14 2026
Approved by Mauro. Preview art only; not yet wired into the game.

## Variants
- Stars 1-4: Glacier Empress (evil). Approved: keys_turned, walk_v3, attack_v2, spell_v2 (blizzard + icicle rain), hitdeath_v3 (dissolve, crystal-cluster remains with crown + staff).
- Star 5: Frost Wraith. Approved: s5_walk, s5_attack_v4 (staff blizzard = NORMAL attack, not a spell), s5_spell_v1 (ice prison: staff slam, rune ring, crystal cage grows on targets, shatters; looks per s5_spell_stills_v2), s5_hitdeath_v1 (approved, hit+death video done).

## Method
- Painted, direction-turned keys -> matted -> jointed rig (arm split at elbow) -> glide animation (3 px bob, lean into travel, trailing robe/smoke).
- Direction map: W = front key, S = front mirrored, E = back key, N = back mirrored.
- Videos: 2x2 N/E/S/W grid, 1920x1080, H.264 High yuv420p crf16 +faststart, 24 fps, vs Ironjaw + Kestrel.
- VFX in s5 spell: painted assets keyed by screen/luminance blend.

## Mauro's rules (all bosses)
- Latest art only; exact limb/prop counts every frame; same palette across actions.
- Face, chest and body clearly TURN toward travel direction; never slide a frontal key sideways.
- S opposite N, W opposite E, no moonwalk.
- Staff in front views moves only up/down, never a 360 spin.
- Death: no falling - dissolve and leave remains. Hit tints subtle.
- No seams/specks; shadow under the unit. Show stills before animating. Change ONLY what Mauro points out.
