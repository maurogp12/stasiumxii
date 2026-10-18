# Crosshaven NPCs (townsfolk). 🖼️ IMAGEN / CONCEPTO, TODAVÍA HAY QUE CONSTRUIRLO

Nothing here is in-game yet. Status: concept assets, rigged and animated, not integrated.

**12 NPCs:**
- Named: guard, merchant, blacksmith, priest, noble.
- Townsfolk: peasant_man, peasant_woman, child, elder.
- Story: guide, banker, herald.

**Prop:** `3d/itm_guard_spear_CONCEPTO_.glb`.

**Pipeline:**
1. Scenario Grok Imagine A-pose turnaround (16 CU each).
2. Front-view crop.
3. Scenario Tripo v3.1 image-to-3D, about 10k faces (45 CU).
4. Blender: normalised to metres, feet at y=0, facing +Z.
5. Meshy rig (5 credits).
6. Meshy 5 clips (15 credits).
7. Blender: Godot bone names, snake_case clips, in place, 30 fps, LOD0/1/2.

**Per NPC:**
- `3d/chr_<npc>_LOD0.glb`: skinned, with clips idle, walk, interact, sit, talk.
- `3d/chr_<npc>_LOD1.glb` and `_LOD2.glb`: mesh and skin only, decimate 0.5 and 0.2, textures 1024 and 512.
- `3d/chr_<npc>_CONCEPTO_.json`: clips, suggested route, work idles.

**Sheets:**
- `previews/npc_concept_check_CONCEPTO_.jpg`
- `previews/npc_clips_sheet_CONCEPTO_.jpg`

**Credits:**
- Meshy: 240 (12 × (5 + 15)).
- Scenario: 793 CU (208 for images, 585 for Tripo).
- Everything is in `credits_log.csv`.

**Known weaknesses:**
- Only the baseColor texture survives the Meshy rig. There are no PBR normal or roughness maps.
- Long robes, dresses and cloaks (priest, peasant_woman, elder, guide) are skinned to the legs, with no cloth sim. They stretch and clip in sit and walk.
- There are no finger bones. Hands stay in the open Tripo pose.
- The spear is a separate glb but is not attached or tuned. The guard has no fist, and no attach transform has been computed yet.
- Every clip comes from the Meshy library, which is generic:
  - child: an adult walk and an adult sit, retargeted;
  - elder: the shaky walk is used, but the idle is the generic one.
- Routes are tags and text suggestions. Story NPCs use the npcs.json cells. The other NPCs are named spots with no exact map coordinates.
- The LOD1/2 triangle counts in the JSONs are ratio targets, not measured.

## Fix pass 2 (drop-in, same filenames; v1 kept in backup_v1/). 🖼️ IMAGEN / CONCEPTO, TODAVÍA HAY QUE CONSTRUIRLO

**1. Textures.** Every NPC LOD0/1/2 now has baseColor, NormalGL and ORM, with occlusionTexture wired to ORM.R.
- The maps were restored from the Tripo PBR set, which the Meshy rigged glb still had (same mesh and UVs). Meshy's animation glb had dropped them.
- Sizes are 2048/1024/512.
- Preview: `previews/npc_textures_before_after_CONCEPTO_.jpg`.

**2. Guard spear.**
- Right hand sculpted into a hammer-grip fist (Ironjaw v3 method). Measured wrap is about 300° around a 1.6 cm-radius haft.
- New clips:
  - `idle_spear`: Blender arm edit of idle; spear upright, butt on the ground. This is now the default idle.
  - `walk_spear`: Meshy 672 Spear Walk inplace, 3 credits.
- Attach transforms (`in_hand`, `in_hand_reversed`, `back_sling`) are in the guard JSON, in glTF joint space, metres. They were verified by placing the spear from the JSON numbers alone on a re-import of the exported LOD0.
- The spear glb shaft was slimmed to 3.5 cm.
- Previews: `npc_guard_spear_check_CONCEPTO_.jpg`, `npc_guard_fist_closeup_CONCEPTO_.jpg`.

**3. Child walk.**
- Changes: leg swing ×0.8, arm swing ×0.85, hip bob ×0.8, cadence ×1.15. The idle cadence is also ×1.15.
- Every NPC JSON now has `walk_speed_mps`, the planted-foot speed. Moving the NPC at that speed avoids skating.
- Preview: `npc_child_walk_before_after_CONCEPTO_.jpg`.
