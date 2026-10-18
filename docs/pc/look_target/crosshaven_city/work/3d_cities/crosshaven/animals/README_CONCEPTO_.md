# Crosshaven ambient animals. 🖼️ IMAGEN / CONCEPTO, TODAVÍA HAY QUE CONSTRUIRLO

**Animals:** cat, dog, chicken, duck, cart horse, pigeon.

**Pipeline:**
1. Scenario Grok Imagine concept (16 CU).
2. Tripo v3.1 image-to-3D (45 CU).
3. Blender: normalise to metres, face +Z, feet at y=0.
4. Custom armature from mesh landmarks.
5. Procedural keyframed loops at 30 fps, in place.
6. LODs at decimate 1 / 0.5 / 0.2.

Meshy's auto-rig is humanoid only (per its rigging docs), so no Meshy credits were used. Scenario spend was 366 CU.

**Clips:**
| Animal | Clips |
|---|---|
| cat | idle, walk, run, sit |
| dog | idle, walk, run, sit |
| horse | idle, walk, run, graze |
| chicken | idle, walk, run, peck |
| duck | idle, walk, run, peck |
| pigeon | idle, walk, run, peck, fly (placeholder) |

Each JSON (`3d/ani_<x>_CONCEPTO_.json`) holds the bones, clips, move_speed_mps, route type, suggested route and role idles.

**Sheets:** `previews/ani_concept_check_CONCEPTO_.jpg` and `previews/ani_clips_sheet_CONCEPTO_.jpg`.

**Weaknesses:**
- **Weights:** bone heat failed on the horse, chicken and pigeon, so those are skinned entirely with nearest-bone distance weights (top 2, not smoothed). Expect some stretching at the shoulders, hips and neck in close-ups.
- **Animation:** the loops are simple sine-driven cycles, not mocap. The gaits are believable at city-camera distance but stiff up close. There are no ear, jaw or mane bones.
- **Pigeon fly:** placeholder. The wings don't open because the folded wings are fused into the body mesh.
- **Sit:** the folded hind legs float slightly.
- **Move speeds are measured, not tuned to real animals.** The horse walk speed is 2.18 m/s, faster than a real walk (about 1.5 m/s). Use the JSON values to avoid skating, or retime.
