# STASIUM XII — Character blueprint pack (PC) — INDEX

Built 2026-10-03 (ET) for the PC game coding team, from files under `/workspace/art/**` and `/workspace/**` specs, the
STASIUM XII art guide and the art-bot skill, plus the rules Mauro gave for this pack (marked **[Mauro rule]** in the class files).
Nothing here is invented: any value not found in a file is written as **MISSING / not yet made**. Art folders were only read.

| class | locked walk | path | frame size | walk S | walk W / N / E (march) | attack | hit | death | cast | run |
|---|---|---|---|---|---|---|---|---|---|---|
| [Ironjaw](BLUEPRINT_Ironjaw.md) | **v7** | `/workspace/art/ironjaw_march/proof_S_v7/` | 161×155 | **locked** (12 f × 58.33 ms = 0.70 s) | MISSING | painted, approved Oct 2 (`hero_anims_painted/ironjaw`, 6 f @ 12 fps, impact f4) | painted, approved (4 f @ 12 fps) | painted, approved (6 f @ 10 fps) | none by design | PC world 8 f @ 15 fps (old art) |
| [Gloam](BLUEPRINT_Gloam.md) | **v8c** | `/workspace/art/gloam_march/proof_S_v8c/` | 135×160 | **locked** | MISSING | painted MISSING; old mobile 5 f @ 12 fps | painted MISSING; old mobile 4 f | painted MISSING; old mobile 6 f | painted MISSING; old mobile 4 f @ 10 fps | PC world 8 f @ 16 fps (old art) |
| [Kestrel](BLUEPRINT_Kestrel.md) | **v6** | `/workspace/art/kestrel_march/proof_S_v6/` | 116×160 | **locked** | MISSING | painted MISSING; old mobile 6 f @ 12 fps | painted MISSING; old mobile 4 f | painted MISSING; old mobile 6 f | painted MISSING; old mobile cast 6 f @ 10 fps + cast_mark 6 f @ 12 fps | PC world 8 f @ 16 fps (old art) |
| [Bastion](BLUEPRINT_Bastion.md) | **v18c** | `/workspace/art/bastion_march/proof_S_v18c/` | 132×151 | **locked** | MISSING | painted, IN PROGRESS (6 f @ 12 fps, impact f4, 4 true facings) | painted, in progress (4 f) | painted, in progress (6 f @ 10 fps) | MISSING | PC world 8 f @ 12 fps (old art) |
| [Mender](BLUEPRINT_Mender.md) | **v9** | `/workspace/art/mender_march/proof_S_v9/` | 90×179 | **locked** | MISSING | none by design (kit has no weapon attack) | painted MISSING; old mobile chibi 4 f | MISSING | MISSING | PC world 8 f @ 15 fps (old art) |

All five locked walks: 12 frames × 58.33 ms = 0.70 s, S facing only, copies in `/workspace/art/march_all/locked_S_walks/<class>/`
(see `locked_S_walks/MANIFEST.md`; foot-contact anchor "not provided in metrics.json" for every class → MISSING).

## Cross-class caveats (from the files)

- **Every existing action set is built on the older rig/art, not on the march paintings.** None of the painted or old
  attack/hit/death/cast/run sets matches the locked march walks; treat them as placeholders.
- **Old facing letters.** Older files (mobile strips, PC world runs, handoff walks, spec) use the old letters. Mapping to the
  locked rule: old **e → S**, old **s → W**, old **n → E**, old **w → N**. The locked rule is S = front, down-right; W = mirror of S
  (front, down-left); N = back, up-left; E = back, up-right.
- **Hard alpha:** NOT MET for Ironjaw v7 (19,786 semi-transparent px), Gloam v8c (38,778) and Kestrel v6 (40,801); MET (0) for
  Bastion v18c and Mender v9 (measured over the 12 locked frames for this pack).
- **Ironjaw v7 weight knee:** f1–f3 = 50.9 / 61.9 / 52.1° — NOT MET against the ≈15° rule (v7 is the original reference method).
- **Hook frames:** Kestrel v6 (and Mender v9, which uses Kestrel's legs) have the swing shin at −50° (f6) / −36° (f7); the v8 Mender
  target was "f6 shin ≥ −30°".
- **Bastion v18c:** METRICS rows for chest pivot / pelvis root, figure height and highest/lowest frames are NOT MET in the file,
  and the strict light check is 24–45 px per frame (NOT MET). **W-mirror conflict:** the painted Bastion action set says true W and
  N facings (no mirrors), while Mauro's rule for this pack says W = mirror of S; no file reconciles the two (BLUEPRINT_Bastion.md §3).
- **Stale spec descriptions** (`/workspace/art/ANIMATION_FRAMES_SPEC.md`): Ironjaw "hammer" (current: two axes), Bastion "sword"
  (current: mace + shield), Kestrel male with a left-hand bow (current: a woman, bow in her right hand), Mender lantern staff
  (current: staff with a gem on top).
- **Still socket** material/placement: MISSING for every class. **Palette hex of the locked march paintings:** MISSING for every
  class. Only older mobile-era hex values exist (`tools/gender_color/palettes.json`: Ironjaw, Kestrel) plus one measured Bastion gold
  (#998365); Gloam and Mender have none.
- **No PC Godot SpriteFrames `.tres`** exists for any class; animation names in the old spec follow `<anim>_<e|s|n|w>` (old letters).

## Reference PNGs in `ref/`

- `ref/bastion_attack_s_painted_preview.png` (864×176)
- `ref/bastion_death_s_painted_preview.png` (864×176)
- `ref/bastion_hit_s_painted_preview.png` (576×176)
- `ref/bastion_locked_walk_S_contact_strip.png` (1628×151)
- `ref/bastion_mace_master_key_9c1b40a5_thumb_480.png` (480×270)
- `ref/bastion_source_painting_thumb_480.png` (480×270)
- `ref/gloam_locked_walk_S_contact_strip.png` (1664×160)
- `ref/gloam_source_painting_thumb_480.png` (480×270)
- `ref/ironjaw_attack_s_painted_preview.png` (864×176)
- `ref/ironjaw_death_s_painted_preview.png` (864×176)
- `ref/ironjaw_hit_s_painted_preview.png` (576×176)
- `ref/ironjaw_locked_walk_S_contact_strip.png` (1976×155)
- `ref/ironjaw_source_painting_thumb_480.png` (480×270)
- `ref/kestrel_locked_walk_S_contact_strip.png` (1436×160)
- `ref/kestrel_source_painting_thumb_480.png` (480×270)
- `ref/mender_locked_walk_S_contact_strip.png` (1124×179)
- `ref/mender_source_painting_thumb_480.png` (480×270)
