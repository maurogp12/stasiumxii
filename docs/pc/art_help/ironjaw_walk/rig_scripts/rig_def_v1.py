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
   'cape':       dict(file='S_cape.png',  mirror=False, kind='cape', A=[114, 14], B=[114, 400]),
   'R_thigh':    dict(file='S_thigh_b.png', mirror=False, kind='limb', A=[57, 84], B=[57, 176]),
   'L_thigh':    dict(file='S_thigh_a.png', mirror=False, kind='limb', A=[60, 86], B=[62, 178]),
   'R_shin':     dict(file='S_shin_a.png', mirror=False, kind='limb', A=[45, 128], B=[45, 206]),
   'L_shin':     dict(file='S_shin_b.png', mirror=False, kind='limb', A=[40, 130], B=[40, 208]),
   'R_boot':     dict(file='S_boot_a.png', mirror=False, kind='boot', A=[55, 65], B=[147, 118]),
   'L_boot':     dict(file='S_boot_b.png', mirror=False, kind='boot', A=[60, 65], B=[156, 116]),
   'R_upperarm': dict(file='Sarm_upper_a.png', mirror=False, kind='upper', A=[115, 110], B=None, opening=True),
   'L_upperarm': dict(file='Sarm_upper_b.png', mirror=False, kind='upper', A=[120, 105], B=None, opening=True),
   'R_forearm':  dict(file='Sarm_fore_a.png', mirror=False, kind='fore', E=[80, 72], G=[198, 272], H=[320, 478]),
   'L_forearm':  dict(file='Sarm_fore_b.png', mirror=False, kind='fore', E=[82, 70], G=[230, 265], H=[340, 458]),
 },
 'E': {
   'torso':      dict(file='E_torso.png', mirror=False, kind='torso'),
   'cape':       dict(file='E_cape.png',  mirror=False, kind='cape', A=[108, 10], B=[108, 355]),
   'R_thigh':    dict(file='E_thigh_b.png', mirror=False, kind='limb', A=[52, 66], B=[54, 150]),
   'L_thigh':    dict(file='E_thigh_a.png', mirror=False, kind='limb', A=[52, 66], B=[54, 150]),
   'R_shin':     dict(file='E_shin_a.png', mirror=False, kind='limb', A=[45, 90], B=[45, 175]),
   'L_shin':     dict(file='E_shin_b.png', mirror=False, kind='limb', A=[44, 90], B=[44, 176]),
   'R_boot':     dict(file='E_boot_b.png', mirror=False, kind='boot', A=[60, 110], B=[136, 172]),
   'L_boot':     dict(file='E_boot_a.png', mirror=True,  kind='boot', A=[55, 96], B=[186, 150]),
   'R_upperarm': dict(file='Earm_upper_a.png', mirror=False, kind='upper', A=[110, 105], B=None, opening=True),
   'L_upperarm': dict(file='Earm_upper_b.png', mirror=False, kind='upper', A=[105, 100], B=None, opening=True),
   'R_forearm':  dict(file='Earm_fore_a.png', mirror=False, kind='fore', E=[78, 70], G=[172, 272], H=[285, 485]),
   'L_forearm':  dict(file='Earm_fore_b.png', mirror=False, kind='fore', E=[78, 66], G=[207, 265], H=[315, 462]),
 }}
