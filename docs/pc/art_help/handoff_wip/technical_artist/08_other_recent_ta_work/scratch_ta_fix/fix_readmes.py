import json, re
SHIP = '/workspace/stasium-pc-look/ship/npc_sprites'
AO = ('one shared soft contact-AO ellipse (~70x24 px@2x centred on the pivot (128,240), #3b3a66, peak alpha 0.20, '
      'smooth falloff), identical in every frame of every strip (idle/walk/talk/work, S and N), under the figure')
TALKN = ('`talk_n` is a real back-view talk built from the back key (same gesture seen from behind: head tilt, '
         'shoulder/arm lift; the face is not visible), via the npc_work part-warp path like `work_n`')
WALK = ('**Walk support foot pinned on the pivot row** (TA fix 2026-10-03): every walk frame has the support sole on '
        'row 239/240 (flat ground line; the support foot slides in x only), the bob is in the hips/torso (legs '
        'stretch/compress), and only the swing foot lifts in the passing frames. Prop ground contact never pushes the body up.')
CENTRE = ('**Stance centred on the pivot** (TA fix 2026-10-03): the feet midpoint is at x=128 in every anim '
          '(props ignored), so W/E mirroring and anim switches do not jump.')
for role in ['farmer', 'woodcutter', 'fisher', 'smith', 'hermit', 'coil_engineer', 'warden']:
    p = f'{SHIP}/{role}/README.md'; t = open(p).read(); t0 = t
    a = json.load(open(f'{SHIP}/{role}/{role}.json'))['anims']
    w = a.get('work')
    if w:
        t = re.sub(r'\d+ f @ \d+ fps, loop\. (W/E come from the json mirror flags, as for the other anims\.) json: `"work": \{"frames": \d+, "fps": \d+, "loop": true\}`',
                   f'{w["frames"]} f @ {w["fps"]} fps, loop. \\1 json: `"work": {{"frames": {w["frames"]}, "fps": {w["fps"]}, "loop": true}}`', t)
    # talk_n
    t = t.replace('`talk_n` is `talk_s` flipped. Talk faces the player, and for an NPC facing N the nearest front facing is W.', TALKN + '.')
    t = t.replace('`talk_n` = `talk_s` flipped', TALKN)
    t = t.replace('**placeholder** (procedural lift and nod of the head, lantern dips slightly). It needs a painted `front_talk` key.',
                  '**placeholder** (procedural lift and nod of the head, lantern dips slightly). It needs a painted `front_talk` key. ' + TALKN + '.')
    # AO
    t = t.replace('soft contact AO only (#3b3a66, peak alpha 0.22, under the soles), no cast shadow.', AO + '; no cast shadow.')
    t = t.replace('contact AO only (#3b3a66, peak 0.22).', AO + '.')
    t = t.replace('Contact AO is #3b3a66 (peak 0.22).', 'Contact AO: ' + AO + '.')
    # walk lift / centroid notes
    t = t.replace('- In the walk passing frames the lowest row is up to 5 px above the pivot (a lifted foot).', '- ' + WALK)
    t = re.sub(r'- \*\*Walk lowest row 4–1?\d px off pivot y\*\*[^\n]*', '- ' + WALK, t)
    t = t.replace('- The feet centroid is off the pivot because of the 3/4 stance with the fork butt in the bottom rows.', '- ' + CENTRE)
    t = re.sub(r'- \*\*Feet centroid 11–1\d px off pivot x\*\*[^\n]*', '- ' + CENTRE, t)
    t = t.replace('so it stays **world-locked** when the engine moves the node at `stride_px` per cycle.',
                  'so it stays **world-locked** in x when the engine moves the node at `stride_px` per cycle (since the 2026-10-03 TA fix it stays on the pivot row instead of following the iso diagonal in y).')
    t = t.replace('gives **PASS 1, WARN 8, FAIL 0**', 'gives **PASS 9, WARN 0, FAIL 0** (2026-10-03 rebuild)')
    t = t.replace('→ **0 FAIL**. Report:', '→ **0 FAIL, 0 WARN** (2026-10-03 rebuild). Report:')
    t = t.replace('WARNs:\n- ' + CENTRE, 'Former WARNs, fixed:\n- ' + CENTRE)
    t = t.replace('WARNs:\n\n- ' + CENTRE, 'Former WARNs, fixed:\n- ' + CENTRE)
    open(p, 'w').write(t)
    print(role, 'changed' if t != t0 else 'UNCHANGED', '| left:', [l[:70] for l in t.splitlines() if re.search(r'flipped\. Talk|peak 0\.22|peak alpha 0\.22|lowest row|Feet centroid', l)])
