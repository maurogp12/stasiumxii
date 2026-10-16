> **L9 v1 decor run (Scenario Art, 2026-10-04).** The jungle package checker only knows the v4
> slot names, so it was run on a temp copy of `ship/l9_v1_decor/` with the v1 files renamed to their v4 slots:
> `sky -> back_far`, `clearing -> back_mid`, `clearing_sway -> back_mid_sway`, `leaf_frame_<edge> -> front_leaves_<edge>`
> (+ `_sway`), with `leaf_shadow` taken unchanged from `ship/crosshaven_jungle`.
> The six dimension FAILs on `front_leaves_left/right/top` (+ sway) are the v4 size pins
> (1024x1440, 2560x480). The v1 leaf frames are re-framed on purpose (left 1024x808, right 1024x1168,
> top 2560x592; see `l9_v1_decor/README.md`). The branch's `v1_decor` loader has no size pin.
> Those FAILs do not apply to the v1 slots. Every other check passes, including the back_mid hole rule (40.9%).

# Asset check report: `jungle`

- Folder: `ship/l9_v1_decor (mapped to v4 names, see note)`
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
