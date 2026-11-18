# Visor 3D: modelos y revisión visual

## Diagnóstico

Los 42 GLB iniciales se conservaron. Aunque contienen geometría y colores por
vértice, son formas de prototipo con una etiqueta texturizada por pieza: no
incluyen el detalle ni la variedad de materiales de un equipo real. La versión
anterior tampoco mostraba un refrigerador. El nuevo conjunto utiliza geometría
genérica más detallada, con texturas base, roughness/metallic, normales y
emisivos donde los proporciona el autor. Las superficies antiguas siguen
activando los colores por vértice sin sustituir sus texturas.

## Fuentes y licencia

Estos seis modelos genéricos son obras originales de **Innerscene** ofrecidas
bajo [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) según las
páginas de descarga y las [condiciones de la biblioteca](https://www.innerscene.com/tools/library/terms).
Se descargaron el 16/11/2026. No representan marcas ni SKU concretos.

| GLB incluido | Fuente | Triángulos |
|---|---|---:|
| `gabinete.glb` | [Closed mid-tower PC case](https://www.innerscene.com/tools/library/3d-parts/closed-mid-tower-pc-case-1374583e) | 23.108 |
| `placa.glb` | [ATX motherboard](https://www.innerscene.com/tools/library/3d-parts/atx-motherboard-7794769f) | 14.468 |
| `gpu.glb` | [Graphics card with fans](https://www.innerscene.com/tools/library/3d-parts/graphics-card-with-fans-6af50057) | 19.732 |
| `ram.glb` | [DDR5 RAM stick](https://www.innerscene.com/tools/library/3d-parts/ddr5-ram-stick-376e4682) | 3.796 |
| `fuente.glb` | [ATX power supply](https://www.innerscene.com/tools/library/3d-parts/atx-power-supply-675d6448) | 12.732 |
| `cpu_refrigerador.glb` | [CPU with cooler](https://www.innerscene.com/tools/library/3d-parts/cpu-with-cooler-6590ab40) | 6.684 |

Están en `godot/assets/models/realismo_cc0/`, con licencia también disponible
dentro del proyecto. La GPU opcional de Grab3D y su licencia CC0 se conservan.
`godot/data/variantes_3d.json` contiene una entrada por cada uno de los 42
ID: ruta al GLB base y parámetros de apariencia. **Las seis categorías
comparten su GLB base** entre productos; las diferencias son transformaciones,
acabados y detalles genéricos añadidos por el visor, no réplicas comerciales.
Puede desactivarse la vista detallada para volver a los GLB originales.

Las GPU se alargan según `length_mm` del catálogo y se presentan con 1, 2 o 3
ventiladores aproximados en función de esa longitud, no de un SKU confirmado.
En las variantes de hasta 75 W se ocultan los conectores y el mazo auxiliar
genéricos; esto es una simplificación visual, no verifica los conectores reales.
La RAM cambia entre uno/dos módulos, color, franjas y RGB si el nombre lo
indica. Las placas comparten geometría base ATX, incluidos socket y ranuras,
también para referencias mATX y DDR4: cambia el acabado del protector, no el
factor de forma real. Los chasis comparten envolvente; cambia su frente y
cantidad de ventiladores. La fuente cambia panel/rotulado y el refrigerador
ilustrativo cambia su aro. Nombres comerciales se presentan en la interfaz,
no como logotipos sobre las mallas. La GPU alternativa Grab3D es una vista
comparativa común, no una variante por producto.

## Tratamiento y montaje

- `tools/optimizar_texturas_glb.py` reduce los mapas originales de 2048 px,
  conservando hasta 1024 px en superficies con detalles y usando 512 o 128 px
  para el resto. No cambia mallas, UV, índices, materiales ni normales de la
  geometría. Los seis GLB pasan de aproximadamente 77 MB a 9,4 MB en disco.
- Las texturas importadas usan mipmaps y compresión VRAM S3TC/ETC2; los mapas
  normales están marcados como tales. Godot generó 144 texturas ETC2 cuyo
  tamaño importado conjunto es de aproximadamente 22,3 MiB. Esto no sustituye
  una medición real de memoria y fluidez en Android.
- Las piezas utilizan una escala común de 5 unidades por metro y anclajes
  específicos: placa sobre separadores, CPU en socket, disipador sobre CPU,
  contactos RAM en DIMM y contactos GPU en PCIe. Se reflejó el eje vertical de
  la GPU genérica para orientar los ventiladores hacia abajo.
- Se ocultan de forma reversible el lateral de vidrio y la cubierta de fuente
  del gabinete para ofrecer una vista de corte. También se oculta la etiqueta
  fija de 750 W del modelo genérico y se dibuja el vataje seleccionado. El
  disipador es ilustrativo: no es una pieza adicional ni se incluye en el precio.
- Se añadió un mazo de cables ilustrativo desde el conector de GPU hacia un
  pasacables; tampoco constituye una pieza adicional del catálogo.
- Luz principal con sombra, relleno frío, contraluz fucsia y cielo procedural
  para reflejos PBR; exposición ACES, MSAA 2× y visor que deja de actualizar
  cuando no está visible. Las seis escenas detalladas se reutilizan en memoria
  al reconstruir el equipo, evitando volver a cargarlas en cada reemplazo.

## Pruebas y límites

En Godot 4.7.2 Windows se importaron las seis escenas PBR y se verificaron
texturas y normales. El test de ensamble aprobó 28 verificaciones de límites,
contactos de GPU y RAM, cableado, ausencia de intersección entre piezas
seleccionadas, cambio reversible al modo original y respeto a modelos propios.
Cuando un producto usa un GLB importado por el usuario, se vuelve a la
disposición original para conservar sus anclajes. La prueba gráfica genera
capturas y simula rotación, zoom, selección de las seis categorías y reemplazo.
Las capturas están en `docs/evidencias_windows/torre_realismo.png` y
`docs/evidencias_windows/torre_realismo_lateral.png`.

Los límites calculados son aproximaciones visuales, no validaciones CAD o de
fábrica. Las variantes CPU solo cambian el refrigerador ilustrativo visible;
la CPU queda tapada. La escala horizontal de GPU altera también el conector;
la intersección visual no certifica geometría PCIe real. Quedan pendientes una
prueba en Android, mediciones de rendimiento,
ajustes finos por SKU, cables, disipación específica y materiales/fotografías
de referencia autorizados; no es un render fotorrealista ni una garantía de
montaje físico.
