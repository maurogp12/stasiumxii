# Class walk blockouts: Bastion, Kestrel, Gloam, Mender

> **v2 proportions (4 Oct 2026).** Mauro on Bastion v1: "same issue, the legs". Root cause: the v1 blockouts had the hip at about 0.52 of the height, but the approved painted targets have it at 0.57–0.61, so legs painted on v1 joints came out short and stubby under the target's upper body. v2 measures the proportions from the targets:
>
> | Class | Hip height | Stride | Stance |
> |---|---|---|---|
> | Bastion | 0.60 | 0.28 H | wider |
> | Kestrel | 0.62 | 0.32 H | |
> | Gloam | 0.61 | | |
> | Mender | 0.60 | 0.28 H | |
>
> Every folder, `joints_512.json`, clay, ID and action video here is v2. `proportions_v2.png` shows painting | old | new. **Rig all painted parts on these v2 joints.**

These are walk guides in the same format as Technical Artist's Ironjaw guide (`docs/pc/art_help/ironjaw_walk/ta_joints/`). Each class has a clay pass, a part-ID pass and a joints file. They are built from Mauro's new designs in `refs/`, not the current sprites (Mauro, 4 Oct 2026: "Don't use current designs, use these ones").

They are guides for Scenario Art and Technical Artist to paint over or rig from, not game art. Art changes still go through Scenario Art and Technical Artist.

## Format (same as Ironjaw)

- **Cell:** 512×360. The pivot (256, 329) is the ground under the pelvis.
- **Camera:** orthographic, azimuth 45°, 30° below horizontal, `ortho_scale` 494.62.
- **Walk:** 12 frames at 17.144 fps.
- **Facings:** S is the front 3/4 walking down-right; E is the back 3/4 walking up-right. W mirrors S, N mirrors E.
- **Contacts:** S at f00 (right foot forward) and f06; E at f05 and f11, like Ironjaw.
- **Idle:** `idle_S` and `idle_E` f00 are a neutral stance.
- **Feet stay planted:** during stance the planted heel (strike), the flat foot, then the toe (heel-off) move exactly with the ground. Per frame that is (−6.7, −3.3) px on S and (−6.7, +3.3) px on E for Bastion; Kestrel is (−7.6, ∓3.8) and Gloam (−6.9, ∓3.4).
- **Size tiers** come from the L10 character files: Kestrel and Gloam are small (about 224 px tall in the cell), Bastion medium (about 245 px). Ironjaw is big at 265.

Each class folder holds:

| File | What |
|---|---|
| `clay/<class>_{walk,idle}_{S,E}_fNN.png` | Clay pass, RGBA, transparent background |
| `id/<class>_{walk,idle}_{S,E}_fNN.png` | Flat part-ID pass, no anti-aliasing. Right side is oranges, left side blues, right-hand weapon magenta, left-hand weapon or shield green, cape maroon, hood or helm light grey |
| `joints_512.json` | Same schema as the Ironjaw `joints_512.json`. Per facing and frame: `joints` (pelvis, chest, neck, head_top, and R/L shoulder, elbow, wrist, hip, knee, ankle, toe, heel, as cell px), `draw_order` (nearest camera first) and `parts` (`rotation_deg`, where 0 is straight down and positive is clockwise on screen, and `visible_length_scale` against idle) |
| `<class>_guide_f00.png` | The two-panel guide in the TA layout: clay over the iso grid with the red pivot row, IDs below |
| `<class>_walk_contact.png` | All 12 frames, clay and ID, S and E |
| `<class>_walk_{S,E}.gif` | Clay walk with the ground scrolling at the walk speed (the feet must stick to it), IDs beside it |

## The classes

- **Bastion (knight).** Helm with crest, big pauldrons, wide chest.
  - Kite shield on the left forearm, carried in front with little swing (±4°, elbow at 85°).
  - Flanged morning-star mace in the right fist, held at hip height with the handle forward and down, swinging ±12°.
  - Blue tabard front and back. The panels follow the thighs so they don't cut through them.
  - Long ragged cape.
  - Heavier walk: shorter stride (0.24 H), more bob (10 px).
- **Kestrel (ranger).**
  - Hood and mantle, knee-length ragged cloak.
  - Quiver over the left shoulder on the back.
  - Recurve longbow held low in the right hand, upper limb back, lower limb forward, so the arm swings little (±8°). The free left arm swings ±20°.
  - Slim limbs, tall boots. Stride 0.30 H, bob 8 px.
- **Gloam (rogue).**
  - Tall pointed hood, long ragged cloak.
  - Slight crouch with an 11° forward lean.
  - Twin curved daggers held low and out to the sides, elbows bent about 60°, small arm swing (±9°).
  - Stride 0.27 H, bob 7 px.
- **Mender (healer), design B** (Mauro picked B, 4 Oct; Scenario's concept in `refs/ref_mender.jpg`).
  - Hood and short mantle; a long ivory robe to the boot tops (front, back and side panels that follow the hips and swing half as much as a tabard); a sage sash; vial pouches at both hips.
  - Tall crook staff upright in the right fist, swinging ±6°, with a caged jade lantern hanging from the crook. The free left arm swings ±14°.
  - Calm walk: stride 0.25 H, small bob, 2° lean.
  - Actions: attack = a lantern swing (staff swept forward); skill = heal (lantern raised high, free hand open toward the ally).

## Actions (Mauro, 4 Oct: "show me how they walk and actions")

`<class>/<class>_actions.mp4` is the model in its design colours: turntable, idle, walk S/E, attack S/E, skill, hit, death (`scripts/actions.py` poses, `scripts/video.py` assembly).
- **Bastion:** overhead mace smash with a step in; skill = shield guard. The shield is strapped flat on the **outside** of the left forearm, over the fist, facing out and forward (Mauro: it looked inside the arm; fixed).
- **Kestrel:** the attack raises the bow, draws to the cheek and looses; skill = Mark Shot, aiming high. While walking, the bow **hangs limbs-down**. When she shoots, the bow's belly **faces the aim** with the string toward her (Mauro, 4 Oct).
- **Gloam:** crossed daggers high, then a lunge with a double slash out and down; skill = a shadow-step crouch.

## How to re-run or tune

Install Blender as a Python module (`pip install bpy==4.2.0` on Python 3.11, plus `numpy` and `pillow`; it needs libEGL). From this folder:

```
python scripts/blockout.py bastion bastion   # renders clay/ and id/, and writes joints_512.json
python scripts/preview.py  bastion bastion   # guide sheet, contact sheet, GIFs
python scripts/actions.py  bastion bastion   # action renders (bastion/show/)
python scripts/video.py    bastion bastion "Bastion (knight)"   # bastion_actions.mp4
```

All proportions, stride, bob, lean, arm swing, elbow bend and props are fractions of the height `H` in the `CLASSES` table at the top of `blockout.py`. Change a number and re-run; it takes a few seconds per class.

## Known limits (it's a blockout)

- The capes are two flat panels with a lag-and-sway rule, not cloth simulation. The ragged hems are for the painters.
- The Bastion and Gloam weapons follow the body, not full wrist rotation. Check the hold against the designs before painting.
- Hands are blocks. Paint the fists closed on the handles, as Luca asked for Ironjaw.
