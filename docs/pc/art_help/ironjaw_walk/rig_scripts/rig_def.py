"""Rig definition: parts, anchors (in each part's own px, AFTER the listed mirror), scales.
Anchors: A = proximal joint, B = distal joint (limbs); forearm+axe: E=elbow end, G=axe_grip (fist centre on
handle axis), H=axe_head_centre; boots: A = ankle, B = toe tip (rest orientation, delta-rotated from idle);
torso: neck/pelvis from the idle fit; cape: top hang point / bottom centre."""
import json
P = '/workspace/scratch/ij_walk/rig/parts/'
SCALE = {'S': 0.445, 'E': 0.43}          # global scale (parts kit px -> cell px), per facing
PARTS = {
 'S': {
   'torso':      dict(file='S_torso.png', mirror=True,  kind='torso'),
   'cape':       dict(file='fix_cape.png', mirror=False, kind='cape', A=[390, 15], B=[390, 667], k0=0.68),
   'R_thigh':    dict(file='S_thigh_b.png', mirror=False, kind='limb', A=[57, 84], B=[57, 176]),
   'L_thigh':    dict(file='S_thigh_a.png', mirror=False, kind='limb', A=[60, 86], B=[62, 178]),
   'R_shin':     dict(file='S_shin_a.png', mirror=False, kind='limb', A=[45, 128], B=[45, 206]),
   'L_shin':     dict(file='S_shin_b.png', mirror=False, kind='limb', A=[40, 130], B=[40, 208]),
   'R_boot':     dict(file='S_boot_a.png', mirror=False, kind='boot', A=[55, 65], B=[147, 118]),
   'L_boot':     dict(file='S_boot_b.png', mirror=False, kind='boot', A=[60, 65], B=[156, 116]),
   'R_upperarm': dict(file='fix_upper_A.png', mirror=False, kind='upper2', A=[87, 60], B=[64.5, 345]),
   'L_upperarm': dict(file='fix_upper_B.png', mirror=False, kind='upper2', A=[80, 60], B=[47.5, 345]),
   'R_forearm':  dict(file='Sarm_fore_a.png', mirror=False, kind='fore2', E=[80, 72], G=[198, 272], H=[320, 478]),
   'L_forearm':  dict(file='Sarm_fore_b.png', mirror=False, kind='fore2', E=[82, 70], G=[230, 265], H=[340, 458]),
 },
 'E': {
   'torso':      dict(file='E_torso.png', mirror=False, kind='torso'),
   'cape':       dict(file='E_cape.png',  mirror=False, kind='cape', A=[108, 10], B=[108, 355]),
   'R_thigh':    dict(file='E_thigh_b.png', mirror=False, kind='limb', A=[52, 66], B=[54, 150]),
   'L_thigh':    dict(file='E_thigh_a.png', mirror=False, kind='limb', A=[52, 66], B=[54, 150]),
   'R_shin':     dict(file='E_shin_a.png', mirror=False, kind='limb', A=[45, 90], B=[45, 175]),
   'L_shin':     dict(file='E_shin_b.png', mirror=False, kind='limb', A=[44, 90], B=[44, 176]),
   'R_boot':     dict(file='fix_boot_F.png', mirror=False, kind='boot', A=[85, 117], B=[245, 140], srel=0.63),
   'L_boot':     dict(file='fix_boot_E.png', mirror=False, kind='boot', A=[75, 104], B=[190, 165], srel=0.63),
   'R_upperarm': dict(file='fix_upper_D.png', mirror=False, kind='upper2', A=[58.5, 60], B=[60, 345]),
   'L_upperarm': dict(file='fix_upper_C.png', mirror=False, kind='upper2', A=[75.5, 60], B=[84.5, 345]),
   'R_forearm':  dict(file='Earm_fore_a.png', mirror=False, kind='fore2', E=[78, 70], G=[172, 272], H=[285, 485]),
   'L_forearm':  dict(file='Earm_fore_b.png', mirror=False, kind='fore2', E=[78, 66], G=[207, 265], H=[315, 462]),
 }}

# v2: each painted forearm+fist+axe piece is split into three sub-pieces (same file, masked in build.prepare):
#   X_forearm (cuff, elbow->wrist), X_fist (fist block on the grip), X_axe (handle beyond the fist + head)
for _fac in 'SE':
    for _sd in 'RL':
        _d = PARTS[_fac][f'{_sd}_forearm']
        PARTS[_fac][f'{_sd}_fist'] = dict(file=_d['file'], mirror=False, kind='fist', src=f'{_sd}_forearm')
        PARTS[_fac][f'{_sd}_axe'] = dict(file=_d['file'], mirror=False, kind='axe', src=f'{_sd}_forearm')
ARM_S = 0.28          # forearm cuff + fist scale
ARM_AXE = 0.30        # axe sub-piece scale: head ~250 painted px wide -> ~75 px (match the idle E/S painted heads)
SPLIT = dict(cuff_t=-45, cap_r=50, fist_t0=-60, fist_t1=88, axe_t0=80, wrist_t=-29)   # painted px along E->G / G->H from G
