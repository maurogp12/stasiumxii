# Ironjaw: sacar/guardar hachas (Meshy v2) — para Claude
🖼️ IMAGEN / CONCEPTO, TODAVÍA HAY QUE CONSTRUIRLO. Nada de esto está en Godot.

## Archivos (en el box de los bots, /workspace)
- Comparación (v6, v7b, Meshy v1, Meshy v2):
  - `luca_pics/chars/ironjaw_new/combat/catalog/polished/draw_compare_v6_v7b_meshy_v2_CONCEPTO.gif`
  - `luca_pics/chars/ironjaw_new/combat/catalog/polished/sheathe_compare_v6_v7b_meshy_v2_CONCEPTO.gif`
- Meshy v2 (8 direcciones, 18 cuadros a 12 fps):
  - `.../polished/draw_meshy_v2/`, `draw_meshy_v2_frames.json`
  - `.../polished/sheathe_meshy_v2/`, `sheathe_meshy_v2_frames.json`
- Fuente: clip Meshy 222 "Draw and Shoot from Back" (`meshy_pilot/ironjaw_new/catalog_v1/a222.glb`), rig `01a145ef-61b6-71eb-b480-ef12579dd403`. Script en Blender: `meshy_pilot/ironjaw_new/draw_meshy/dm2.py`.
- Referencias aprobadas: draw/sheathe v6 (`luca_pics/chars/ironjaw_new/draw8_v6.gif`, `sheathe8_v6.gif`), v7b (sin resbalón de mano), caminata con hachas en la espalda v7 (de ahí salen los sockets de la espalda).

## Reglas fijas
- Una sola hacha rígida: escala de la cabeza 0.52 y mango de 34 cm. El mango nunca se acorta y la mano no se desliza.
- Agarre de las fotos de la estatua. El filo apunta al lado contrario de la inclinación del mango.
- Piernas firmes: rodillas a 150° o más, nunca dobladas, cruzadas ni chuecas. Sin deslizar los pies.
- Terminar exacto en la guardia v6 (sacar) o en los sockets de la espalda de la v7 (guardar), sin saltos de pose.

## Qué mejorar
1. Sacar, cuadros 9 a 12: las hachas pasan pegadas al torso y la cadera, y de lado lo atraviesan. Al bajar, abre la trayectoria por fuera de los hombros (más o menos 15 a 20 cm hacia afuera) y gira el hacha antes, para que la cabeza pase por fuera del brazo. Revisa los choques contra la malla del cuerpo, no solo contra el esqueleto.
2. Guardar, cuadros 5 a 7: las cabezas pasan a 8–13 cm de los hombros. Sube más las manos por encima y por detrás de los hombros antes de meter las hachas en los sockets.
3. Al alcanzar las hachas (cuadros 3–4) los brazos suben demasiado, como arquero. Bájalos y haz que las manos vayan directo al mango, detrás del hombro.
4. Los últimos 2–3 cuadros quedan quietos. Repártelos en el movimiento o añade un pequeño asentamiento de peso.
5. Brazos parejos: los dos van al mismo tiempo, pero no son espejo exacto. Que el agarre y la guardia queden simétricos donde la v6 lo permita.
6. Al final compárala contra la v6 en las 8 direcciones y a buen tamaño. La v6 sigue siendo la versión segura hasta que Luca apruebe otra.
