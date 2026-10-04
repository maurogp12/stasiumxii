# Asset check report: `jungle`

- Folder: `/workspace/scratch/l9_v1_decor_check/checker/jungle_mapped`
- Overall: **FAIL**

| File | Status | Details |
|---|---|---|
| `back_far@2x.png` | **PASS** | OK |
| `back_mid@2x.png` | **PASS** | INFO: fully transparent pixels contain non-black RGB values; INFO: hole above corner line 40.9%; INFO: hole below corner line 0.0% |
| `back_mid_sway.png` | **PASS** | OK |
| `front_leaves_bottom@2x.png` | **PASS** | INFO: fully transparent pixels contain non-black RGB values |
| `front_leaves_bottom_sway.png` | **PASS** | OK |
| `front_leaves_left@2x.png` | **FAIL** | dimensions 1024x808, expected 1024x1440; INFO: fully transparent pixels contain non-black RGB values |
| `front_leaves_left_sway.png` | **FAIL** | dimensions 512x404, expected 512x720 |
| `front_leaves_right@2x.png` | **FAIL** | dimensions 1024x1168, expected 1024x1440; INFO: fully transparent pixels contain non-black RGB values |
| `front_leaves_right_sway.png` | **FAIL** | dimensions 512x584, expected 512x720 |
| `front_leaves_top@2x.png` | **FAIL** | dimensions 2560x592, expected 2560x480; INFO: fully transparent pixels contain non-black RGB values |
| `front_leaves_top_sway.png` | **FAIL** | dimensions 1280x296, expected 1280x240 |
| `leaf_shadow@2x.png` | **PASS** | OK |

Status rules: FAIL blocks import; WARN needs review. Dimensions must be divisible by 4 for BC7.
