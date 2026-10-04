# Putting the looks on the approved blockouts: Bastion, Kestrel, Gloam

Mauro, 4 Oct 2026: the blockouts are approved ("Bastion and Kestrel good", "Gloam looks good"). Next: "now we have to put the looks into these."

**Who:** Scenario Art paints; Technical Artist rigs; Claude scores and reviews.

**Pipeline:** the one that got Ironjaw to look 87.5 / 85.1 with motion locked (`docs/pc/art_help/ironjaw_walk/`). The blockout gives the motion; the design gives the look. Don't repaint frame by frame: that drifted Ironjaw five times.

**Rules:** PC only. Painted fantasy, no 3D-render look. Don't merge into main or mobile.

## Step 1: one approved look target per facing (per class)

Paint the full HD character over the blockout's `clay/<class>_walk_{S,E}_f00.png` and `idle_{S,E}_f00`. Keep the blockout's silhouette, pose, proportions and feet exactly; match Mauro's design (`refs/ref_<class>.jpg`) for everything else.
- **Output:** `targets/<class>_rp_{S,E}_f00.jpg`, 1280×720 on flat grey, like Ironjaw's `rp_S_f00_t1.jpg`.
- **Mauro approves these before Step 2.** They are what `match_metric.py` scores against.

| Class | Cell height (idle, px) | Look to match (from the design) |
|---|---|---|
| **Bastion** | 256 | Blackened steel plate with **gold trim**, scale mail on the chest and belly, a visored great-helm with a crest. **Blue** ragged cape and tabard with gold edging. Blue **kite shield with a gold trident**, strapped on the outside of the left forearm over the fist. Flanged spiked **morning-star mace** in the right fist. Heavy sabatons. |
| **Kestrel** | 234 | **Green** hooded ragged cloak and hood (the face shows: a young woman). Dark green leather armour with brown cross-straps and belts, a pouch at the hip. Brown leather leggings, **tall laced boots**. Recurve **longbow**: it hangs limbs-down in the right hand while she walks and faces the aim when she shoots. **Quiver** of fletched arrows over the left shoulder. |
| **Gloam** | 221 (S) / 232 (E) | **Purple** ragged hood and long tattered cloak, a face in shadow with **two glowing violet eyes**. Black leather with buckled straps, black trousers, wrapped boots. **Twin curved daggers** in both fists, held low and out. Slight crouch with a forward lean. |

## Step 2: painted parts on the blockout motion (the Ironjaw v7 method)

Paint each part from the approved target, then rig it on `<class>/joints_512.json`: joints, `draw_order` (nearest first), `rotation_deg`, `visible_length_scale`.

- **Part list:** use the ID colours in `<class>/id/` as the part map: torso, pelvis/belt, head/hood/helm, R/L upper arm, R/L forearm, R/L thigh, R/L shin, R/L boot, and the cape upper and lower.
  - Bastion adds pauldrons, tabard front and back, and the shield.
  - Kestrel adds the quiver and the bow.
  - Gloam adds the dagger blades.
- **Ironjaw lessons (do these from the start):**
  1. **Forearm + fist + weapon is one painted piece**, with the fist closed on the handle. Bastion's shield is its own piece strapped over the left fist.
  2. **Knee cops and elbow cops** as separate small parts over a 6–8 px overlap, so joints never show a seam.
  3. **Thighs: 2–3 painted keys per leg** (swinging toward the camera, under the body, back), swapped by phase, with only ±10% stretch. Never squash one painting.
  4. **Tassets, tabard and loincloth hang from the belt** in the body layer and swing a few degrees to hide the hip join.
  5. **Clip with the part's own alpha or a feathered capsule, never a box**, so there are no straight cut edges.
  6. **Capes and cloaks:** two panels with the lag in `joints_512.json`; the hem clears the support sole by 8 px or more. Kestrel's and Gloam's ragged hems are the read from the back.
  7. **Back views (E):** swing reads as foreshortening, not sideways rotation.
- **Facing and face (Mauro, 4 Oct: "make sure face looks towards the direction he is moving and make sure N, E, S, W is correct"):**
  - S = front, walks down-right; W = mirror of S (down-left); E = back, walks up-right; N = mirror of E (up-left). `facing_check.png` shows all four classes. The blockout travel is verified from the planted feet.
  - The head and eyes face the travel direction in every walk frame: head yaw = the blockout chest yaw, plus no more than ±10°.
  - Name files by these combat letters directly. Never use the old L10 art-letter remap.
- **House rules:** binary alpha, black under alpha 0, 512×360 cells, pivot (256, 329), 12 frames at 17.144 fps. W mirrors S, N mirrors E.
- **Actions:** idle, attack, skill, hit and death follow the poses in `<class>/<class>_actions.mp4`. Do the walk first, then the actions in the same way.

## Step 3: acceptance (same bar as Ironjaw)

- `match_metric.py`, from `claude/ironjaw-walk-help-reply`, against the Step 1 targets: **look ≥ 85 and motion ≥ 95 on S and E**.
- `qa_walk.py`: 48/48, skate 0.
- Leg highlights within the target's range: dark matte, not shiny.
- Commit the frames under `<class>/v1/frames/` so Claude can re-run the scores before anything goes to Mauro.
- **Media for Mauro** per class: walk S/E GIFs, f00/f06 stills beside the target, and the action clips.

**Order:** Bastion → Kestrel → Gloam, with Mender after its design arrives. Ironjaw v8 (thigh keys, alpha clips) continues in parallel.
