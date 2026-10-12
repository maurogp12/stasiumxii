# Referencia de interfaz: WAKFU, inventario y modulación (nueva UI)

Fuente: video de YouTube "WAKFU - Interfaz de Inventario y de modulación" (https://youtu.be/bg5MQ5P9iHU), 11:27, narrado en español. Claude no puede abrir YouTube, así que aquí está todo: este texto, 16 capturas en `frames/` (el nombre de cada una lleva el minuto: `t0420` = 7:00) y el video comprimido `wakfu_interfaz_480p.mp4`.

Pedido de Luca: copiar el estilo de esta interfaz para el juego de PC (PC solamente, 2D). Esto es referencia visual y funcional, no una orden de construir; los paquetes los define Claude.

Nota de fiabilidad: las capturas las vimos directamente. La descripción de los minutos 0:00 a 11:27 sale del video y de la narración; las partes de abajo marcadas "(capturas)" se comprobaron mirando los fotogramas. Donde dice "(narración)" lo dice el narrador y no se ve en una captura.

## 1. Estilo visual general (capturas)
- Tema oscuro tipo "Oscuro - Ankama": paneles gris carbón / verde azulado muy oscuro, casi opacos, con bordes finos. Esquinas ligeramente redondeadas.
- Cabecera de cada ventana: banda verde azulada (teal) con relieve de líneas diagonales, título blanco centrado en tipografía de rótulo, botón de cerrar "X" blanco a la derecha. Ver `t0050_hud_inventario.jpg`, `t0275_zoom_inventario_cabecera.jpg`.
- Texto: sans-serif limpia, blanco o gris claro; títulos de sección en gris claro con flechita de plegar; números verdes para bonos; texto naranja claro para secciones de cosméticos.
- Botón activo/primario: verde con check ("Activa"), o naranja/dorado ("Guardar"). Botón secundario gris oscuro.
- Contraste de estilo: las ventanas antiguas (Oficios, Opciones, el marco de la barra inferior) siguen con el estilo viejo (marcos gris piedra claro, relieve grueso, botones blancos). El narrador lo menciona y cree que Ankama las rehará (narración, 2:49 a 3:28). Para nuestro juego conviene un solo estilo.
- Animaciones: apertura y cierre casi instantáneos, sin fundidos largos; cambiar de pestaña es inmediato; al redimensionar la ventana de inventario arrastrando el borde, las casillas se reordenan en vivo (narración y video, 10:14).
- Sonido: el video no deja oír sonidos de la interfaz, solo la voz.

## 2. HUD principal (capturas `t0050_hud_inventario.jpg`, `t0050_zoom_barra_inferior.jpg`, `t0050_zoom_arriba_derecha.jpg`)
Importante: el HUD de Wakfu es pequeño y discreto, no hay globos grandes. Algunas descripciones automáticas decían "globo de vida", "minimapa circular" y "orbe central grande"; en las capturas NO se ven. Lo que sí se ve:
- Barra inferior, ancho completo abajo, de unos 30 px de alto. Al centro un emblema circular con laureles dorados y una "S" (la clase); arriba de él, los PdV actuales y máximos en números blancos (ej. 14577 / 25903) con un icono de huella azul. A la izquierda del emblema: una fila de botones cuadrados pequeños con iconos (menú del personaje, inventario, hechizos, etc.). A la derecha: casillas cuadradas de hechizos y objetos con iconos ilustrados, y flechas para cambiar de fila.
- Izquierda de la pantalla: una columna vertical con los retratos de tu personaje y de tus héroes (círculos con marco dorado, 3 retratos y un "+" para añadir), y debajo la lista de misiones/avisos en texto amarillo con temporizador ("Tiempo restante").
- Arriba a la derecha: cuatro iconos pequeños con marco blanco (estados/notificaciones) y un botón "Tienda" con icono de regalo y una gema verde azulada.
- No se ve minimapa ni barra de chat en estas escenas (hay un cuadro de misiones a la izquierda).
- PA / PM / PW (puntos de acción, movimiento y Wakfu): en combate aparecen como iconos con número (narración y descripciones: estrella azul PA, bota PM, gota turquesa PW). En el video no hay combate, así que no hay captura; confirmar al construir.

## 3. Inventario (tecla I) (capturas `t0050`, `t0275`, `t0245`, `t0380`)
- Ventana vertical estrecha a la derecha de la pantalla.
- Cabecera teal con "Inventario" y X. Debajo: pestañas de iconos cuadrados: cofre (recursos), llave (objetos de misión/llaves), estrella (fichas), y a la derecha botones para bolso/reunir, martillo (romper) y un icono de criatura (pacto/cosméticos). Barra de búsqueda con lupa y botón de ordenar (flechas).
- Secciones plegables por bolsa, con título y capacidad: "Bolsillos 30/30", "Bolso sadida blanco 30/30". Cuadrícula de 5 columnas de casillas cuadradas con ligero relieve hundido y un borde de color por rareza (gris común, verde, naranja, amarillo, magenta; según descripciones).
- Cantidad: número blanco pequeño abajo a la derecha de la casilla.
- Abajo a la derecha: Kamas (dinero) con icono de moneda y un botón "+" que lleva a la tienda (narración 4:06).
- Bolsas especiales (ej. de leñador): los recursos de ese tipo van solos a su sección sin gastar bolsillos (narración 3:30 a 4:00).
- Pestaña estrella: secciones plegables "Fichas" y "Misión". Pestaña máscara: secciones "Auras", "Golpes de gracia", "Carreras", "Apariencias de cascos/hombreras/monturas/mascotas", "Trajes" (`t0245`).
- Botones de la base: martillo = romper objetos para sacar esquirlas según rareza y nivel (5:14 a 5:45); cofre con flecha = reunir objetos de tus héroes en el inventario principal (4:44 a 5:13); A-Z = ordenar (primero sets, luego esquirlas, polvos, recursos y consumibles, 6:41 a 6:57).
- Pestaña "Inventario de pacto" (modo arriesgado, mejor drop pero otro jugador puede agredirte): ventana aparte con cuadrícula vacía y un botón "Recoger todo" (`t0380`, 5:46 a 6:40).
- Héroes: flecha bajo el retrato abre el inventario de cada héroe en otra pestaña (4:30 a 4:43).

## 4. Interacción con objetos (capturas `t0150`, `t0190`)
- Pasar el ratón: tooltip. Clic derecho: menú flotante horizontal con iconos: papelera (eliminar), mano (usar/equipar), corazón (curar completo de una vez) y yunque (ver recetas) (2:10 a 2:48). Esto reemplaza el doble clic de antes.
- Yunque abre la ventana de Oficios (profesiones a la izquierda: Armero, Joyero, Sastre..., recetas y materiales a la derecha) en el estilo antiguo (`t0170`, 2:49 a 3:28).

## 5. Tooltips (capturas `t0150`, `t0470`, `t0530`)
- Fondo casi negro con borde fino; etiqueta de rareza arriba con color ("Legendario" en verde amarillento, "Común" en gris, "Mítico" en naranja); nombre grande; icono a la izquierda; tipo entre corchetes, "Precio medio: N K", y "Niv." a la derecha; texto "Resumen"; lista de estadísticas con icono pequeño cuadrado (números en naranja o verde), nota de ligado.
- Tabs de texto "Utilización" y "Condiciones" en objetos consumibles.
- Comparación con lo equipado: pasando sobre un objeto del inventario aparece también una segunda ventana a su lado con el objeto que llevas puesto (`t0470`, dos tooltips juntos: el del inventario y el equipado). En la ventana de equipo, al elegir una casilla, el detalle del objeto aparece fijo abajo del personaje (`t0530`).

## 6. Ventana de personaje y equipo (tecla O) (capturas `t0420`, `t0530`, `t0585`, `t0555`, `t0452`)
- Ventana grande al centro, título = nombre del personaje. Tres columnas:
  - Izquierda: "Builds (0/24)" = la modulación. Lista vertical de builds, cada una con icono (espada, hoja, corazón, anillo...), nombre ("Build por defecto", "Build de franja 20, 35, 50, 65, 80, 95, 110, 125, 140, 155, 170, ... 230"), nivel ("Niv. 20", "Niv. real"), buscador, botón de ordenar y botón "+ Nuevo" abajo. La activa va resaltada con fondo dorado y "Activa" con check.
  - Centro: nombre de la build, botones: nivel ("Niv. real"), engranaje (modificar), candado, deshacer, "Guardar" naranja con desplegable, y "Activa" blanco. Pestañas "Equipables", "Hechizos", "Características". Debajo, el personaje con casillas de equipo a ambos lados: columna izquierda (casco, amuleto, pechera, anillo y más) y columna derecha (arma, hombreras, capa, cinturón, escudo), y una fila de objetos abajo (guantes, botas, emblema, mascota, etc.). Casillas vacías con silueta tenue del tipo de objeto. Abajo del personaje: detalle del objeto seleccionado.
  - Derecha: la lista cambia según la pestaña: Equipables (inventario filtrado), Hechizos, o Características.
- Modulación (narración 6:58 a 8:00): es una "build" por franja de nivel. El juego ya trae las franjas hechas con su límite de nivel. Si eliges la franja 200, solo puedes equipar objetos de nivel 200 o menos. Cada build guarda equipo, hechizos y características, así se puede cambiar de set o de reparto rápido ("Activa").
- Engranaje de una build abre un cuadro "Modificar la build": nombre, nivel (fijo en la franja), paleta de iconos (cuadrícula de unos 4x5 de gemas e iconos de colores) y botones "Cancelar" gris y "Guardar" naranja (`t0452`). Crear una build nueva usa un cuadro parecido (8:00).
- Pestaña Equipables (8:13 a 9:02): solo muestra equipo, sin recursos. Si haces clic en una casilla vacía (ej. "Casco"), la lista de la derecha se filtra a cascos y pone el título "Casco (9)" con secciones por héroe ("Serveruss 5", "Tudinski 3", "Sir Kakaroto 1") y una casilla "Inventario de los demás héroes" (`t0530`). El filtro de embudo permite filtrar por rareza (reliquia, épico, mítico, raro).
- Pestaña Hechizos (9:09 a 9:23): biblioteca de hechizos: arriba la barra de hechizos activos, pasivos y mecánica, abajo "Código" para compartir; a la derecha "Activos elementales", "Activos asociados" y "Pasivos" (`t0555`).
- Pestaña Características (9:23 a 10:01) (`t0585`): 5 bloques: Inteligencia, Fuerza, Agilidad, Suerte, Mayor, cada uno con "Restantes: N" y una lista de atributos con casilla numérica y botones - y + (ej. Placaje 34, Voluntad 20; Esquiva 0). Pasar el ratón sobre un atributo muestra un tooltip con "Nivel actual" y "Siguiente nivel". Abajo "Código de características" y "Reiniciar las características". Arriba "Guardar" confirma. Ventaja citada: ya no hay que reiniciar todo para cambiar un solo punto.

## 7. Opciones y escala (capturas `t0620`)
- Esc abre un menú pequeño (Opciones, Cambiar de personaje, Desconectar...). En Opciones (estilo antiguo, pestañas Juego, Vídeo, Audio, Interfaz...): "Escala de la interfaz" con deslizador del 73% al 140% (el narrador prefiere 140%) (1:11 a 1:38), "Tema de la interfaz" desplegable (10:18 a 10:41) y el tamaño de las ventanas de inventario se arrastra del borde.

## 8. Lista de funciones, de la más a la menos importante
1. Inventario por bolsas plegables con cuadrícula de casillas, cantidades y colores de rareza.
2. Ventana de personaje con equipo alrededor del modelo (casillas por tipo) y lista de equipables filtrada al elegir casilla.
3. Tooltips ricos con rareza, nivel, precio y estadísticas, y comparación con lo equipado.
4. Modulación: builds por franja de nivel (equipo, hechizos, características), activar con un clic, con límite de nivel.
5. Reparto de características por bloques con - y +, "Restantes" y guardar sin reiniciar.
6. Barra inferior: PdV/emblema de clase, menú de botones, hechizos y objetos.
7. Búsqueda, filtros (rareza) y ordenar (A-Z, por tipo de equipable) en todas las listas.
8. Menú de clic derecho: eliminar, usar, curar completo, ver receta.
9. Kamas y botón de tienda.
10. Héroes: retratos laterales, inventario por héroe y "reunir objetos".
11. Romper objetos para esquirlas y polvos.
12. Pestañas de misión/fichas y de cosméticos (auras, apariencias, trajes).
13. Bolsas especiales por oficio.
14. Biblioteca de hechizos y código para compartir.
15. Oficios (recetas), estilo antiguo todavía.
16. Inventario de pacto (modo PvP arriesgado).
17. Opciones: escala de interfaz y tema.
