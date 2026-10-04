"""Bastion v1 rig definition. Anchors are in each cut part's own px (scratch parts dir, see cut_parts.py), AFTER the
listed mirror. s = cell px per part px. Kinds:
 helm  N=neck point (bottom opening), T=axis point toward head_top
 torso N=neck (gorget opening), W=waist (bottom centre)          -> neck joint, axis neck->pelvis
 belt  C=belt centre, D=hem centre                               -> pelvis, axis = torso axis + tabard swing
 pauld P=shoulder joint point                                    -> shoulder joint, torso angle + share of the arm swing
 limb  A=proximal joint, B=distal joint                          -> B on the distal joint, axis to proximal, k in [0.9,1.1]
 cop   C=centre                                                  -> joint, mean angle of the two segments
 fore  E=elbow end, W=wrist, H=weapon/fist ref                   -> E on elbow, axis elbow->wrist (+bias), k in [0.9,1.1]
 shield C=centre, U=top-centre (axis U->C points down)           -> wrist + forearm-local offset, forearm delta
 boot  heel/toe = sole reference points                          -> heel/toe joints, fixed scale (no squash)
 cape  T=top hang point, B=bottom (lower panel hangs at B of the upper)
"""
P = '/workspace/scratch/bastion/parts/'
PARTS = {
 'S': {
  'helm':    dict(file='S_helm', kind='helm', N=[190, 528], T=[172, 150], s=0.100),
  'torso':   dict(file='S_torso', kind='torso', N=[118, 40], W=[132, 330], s=0.21),
  'belt':    dict(file='S_belt', kind='belt', C=[150, 52], D=[150, 395], s=0.19),
  'R_pauld': dict(file='S_pauld_a', kind='pauld', P=[128, 112], s=0.155),
  'L_pauld': dict(file='S_pauld_b', kind='pauld', P=[110, 108], s=0.155),
  'R_upper': dict(file='S_upper_a', kind='limb', A=[87.6, 17.7], B=[73.0, 205.8], s=0.15),
  'L_upper': dict(file='S_upper_b', kind='limb', A=[46.0, 17.2], B=[56.0, 185.5], s=0.15),
  'R_elbowcop': dict(file='S_elbowcop', kind='cop', C=[77, 80], s=0.12),
  'L_elbowcop': dict(file='S_elbowcop', kind='cop', C=[77, 80], s=0.12),
  'R_fore':  dict(file='S_mace', kind='fore', E=[62, 52], W=[150, 112], H=[75, 360], s=0.23),
  'L_fore':  dict(file='S_fist', kind='fore', E=[158, 42], W=[100, 135], H=[62, 182], s=0.23),
  'shield':  dict(file='S_shield', kind='shield', C=[140, 190], U=[150, 25], s=0.28),
  'cape_u':  dict(file='S_cape_u', kind='cape', T=[128, 14], B=[128, 400], s=0.28),
  'cape_l':  dict(file='S_cape_l', kind='cape', T=[120, 14], B=[120, 470], s=0.28),
  'thigh_fwd':  dict(file='S_thigh_fwd', kind='limb', A=[100, 40], B=[78, 278], s=0.18),
  'thigh_down': dict(file='S_thigh_down', kind='limb', A=[76, 40], B=[62, 340], s=0.18),
  'thigh_back': dict(file='S_thigh_back', kind='limb', A=[55, 40], B=[86, 330], s=0.18),
  'kneecop': dict(file='S_kneecop', kind='cop', C=[70, 85], s=0.13),
  'greave':  dict(file='S_greave', kind='limb', A=[68, 24], B=[71, 262], s=0.18),
  'R_boot':  dict(file='S_sabaton_a', kind='boot', heel=[14, 222], toe=[184, 222], s=0.175),
  'L_boot':  dict(file='S_sabaton_b', kind='boot', heel=[22, 220], toe=[192, 220], s=0.175),
 },
 'E': {
  'helm':    dict(file='E_helm', kind='helm', N=[185, 520], T=[185, 170], s=0.104),
  'torso':   dict(file='E_torso', kind='torso', N=[125, 14], W=[125, 215], s=0.36),
  'belt':    dict(file='E_belt', kind='belt', C=[104, 22], D=[104, 240], s=0.33),
  'R_pauld': dict(file='E_pauld_b', kind='pauld', P=[110, 108], s=0.20),
  'L_pauld': dict(file='E_pauld_a', kind='pauld', P=[128, 112], s=0.20),
  'R_upper': dict(file='E_upper_a', kind='limb', A=[87.6, 17.6], B=[72.4, 206.2], s=0.185),
  'L_upper': dict(file='E_upper_b', kind='limb', A=[46.0, 17.1], B=[58.0, 187.4], s=0.185),
  'R_elbowcop': dict(file='E_elbowcop', kind='cop', C=[75, 80], s=0.15),
  'L_elbowcop': dict(file='E_elbowcop', kind='cop', C=[75, 80], s=0.15),
  'R_fore':  dict(file='E_mace', kind='fore', mirror=True, E=[187, 52], W=[99, 112], H=[174, 360], s=0.27),
  'L_fore':  dict(file='E_fist', kind='fore', E=[150, 40], W=[95, 135], H=[55, 175], s=0.27),
  'shield':  dict(file='S_shield', kind='shield', C=[140, 190], U=[150, 25], s=0.24, sx=0.62),
  'cape_u':  dict(file='E_cape_a', kind='cape', T=[117, 8], B=[117, 200], s=0.45, rows=(0, 215)),
  'cape_l':  dict(file='E_cape_b', kind='cape', T=[117, 150], B=[117, 345], s=0.55, rows=(140, 400)),
  'thigh_fwd':  dict(file='E_thigh_fwd', kind='limb', A=[52, 22], B=[50, 160], s=0.215, cap=True),
  'thigh_down': dict(file='E_thigh_down', kind='limb', A=[58.6, 22], B=[50, 228], s=0.215),
  'thigh_back': dict(file='E_thigh_back', kind='limb', A=[45, 25], B=[95, 150], s=0.215, cap=True),
  'greave':  dict(file='E_greave', kind='limb', A=[50, 20], B=[53, 205], s=0.215),
  'R_boot':  dict(file='E_sabaton', kind='boot', heel=[6, 145], toe=[151, 145], s=0.21),
  'L_boot':  dict(file='E_sabaton', kind='boot', heel=[6, 145], toe=[151, 145], s=0.21),
 }}
