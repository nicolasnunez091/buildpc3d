# Modelos GLB en BUILDPC3D

## Modelos que ya están DENTRO de este ZIP

`godot/assets/models/` trae **42 archivos `.glb` verdaderos**, uno por producto del catálogo MVP, generados originalmente para este prototipo. No son capturas, archivos de muestra vacíos ni modelos de Sketchfab. Incluyen geometría para ventiladores de GPU, ranuras y conectores de placa madre, cubiertas y contactos de RAM, pines de procesador, rejilla de fuente y paneles de gabinete. Varios llevan etiquetas de producto como *referencia visual*.

**No son reconstrucciones CAD exactas**: los productos reales pueden tener otras dimensiones, colores y ubicación de conexiones. Las marcas del catálogo identifican los productos elegidos; la geometría se aproxima a su categoría y características, no a fotografías ni a planos originales. Una gráfica NVIDIA RTX 4060 de la lista no identifica un ensamblador (ASUS/MSI/Gigabyte) concreto.

## Modelo externo incluido y otros disponibles

La vista principal también incorpora seis modelos genéricos de Innerscene,
CC0 1.0, sin sustituir los 42 GLB originales. Sus fuentes individuales,
tratamiento y límites están en `docs/VISOR_3D_REALISMO.md` y en
`godot/assets/models/realismo_cc0/LICENCIA_Y_FUENTES.txt`.

Se incluye `godot/assets/models/cc0/graphics-card-light.glb`, de Grab3D:
https://grab3d.com/models/electronics/graphics-card/ . Su `LICENSE.txt` y
`manifest.json` originales están en la misma carpeta. El autor lo ofrece bajo
**CC0 1.0**; es una GPU genérica estilizada, no una réplica de un SKU comercial.
La variante ligera tiene 12.644 triángulos y se activa opcionalmente desde la
torre sin modificar el catálogo. SHA-256 del GLB descargado:
`8d6c2a72d0c6d4391150d0b013826b055867bd539c1ab4f845d07f07a202ec74`.
El origen declarado es procedural, con código asistido por IA; no se declara
generación directa de la geometría o las texturas mediante IA generativa.

El paquete "Cozy PC Parts Kit" de Grab3D contiene archivos GLB declarados **CC0**, con descarga sin cuenta, para estos seis tipos:

| Tipo | Página del modelo |
|---|---|
| Gabinete | https://grab3d.com/models/electronics/pc-case/ |
| Placa madre | https://grab3d.com/models/electronics/motherboard/ |
| GPU | https://grab3d.com/models/electronics/graphics-card/ |
| RAM | https://grab3d.com/models/electronics/ram-stick/ |
| CPU | https://grab3d.com/models/electronics/cpu/ |
| Fuente | https://grab3d.com/models/electronics/power-supply-unit/ |

Del kit **Grab3D** anterior, únicamente la GPU ligera indicada arriba está
incluida. Las otras piezas de Grab3D no se empaquetaron.
Revisa la licencia individual al descargar cualquier recurso adicional.

### Instalación automática en tu computador (Windows)

Abre PowerShell en la carpeta raíz del proyecto y escribe:

```powershell
python tools/instalar_modelos_cc0.py --aplicar-mvp
```

Este comando requiere Internet. Intentará descargar los seis GLB a `godot/assets/models/cc0/` y validar la cabecera GLB; **no modifica automáticamente las rutas del catálogo**. Los archivos genéricos no identifican realmente a una ASUS, Kingston, etc. La GPU ligera ya incluida es independiente de estas descargas opcionales.

Si la red bloquea alguna descarga, el script muestra las páginas oficiales; descarga el GLB manualmente y guárdalo como `slug.glb` en `godot/assets/models/cc0/`, vuelve a ejecutar el comando. Si Godot está abierto, cambia a otra escena y vuelve, o reimporta los archivos.

### Asignar uno a un producto distinto

```powershell
python tools/instalar_modelos_cc0.py --asignar gpu_nvidia_rtx_4060_8gb graphics-card
```

La vista detallada comparte bases genéricas, pero aplica variantes por ID
descritas en `VISOR_3D_REALISMO.md`. Si se asigna un modelo externo al catálogo,
el visor conserva el modo original para respetar sus anclajes; comprueba la
escala, posición, licencia y apariencia antes de distribuirlo.

## Sketchfab

También puede utilizarse para reemplazar piezas cuando exista un modelo específico descargable y su licencia permita uso en un proyecto redistribuible. Ejemplo de referencia: https://sketchfab.com/3d-models/corsair-4000d-airflow-free-34df3ba96cf94e71accdb5779c4b8694 . **No está incluido**, porque requiere una descarga que no se pudo realizar aquí. La licencia de ese modelo indica CC BY (hay que acreditar a Kirigami). Conservar licencia, autor y URL para cada asset.

## Rendimiento Android

Se recomienda trabajar con modelos *low-poly*, materiales comprimidos, pocas texturas y perfiles de carga. Para optimizar, inspecciona el conteo de triángulos y los materiales en Godot; una tarjeta visual detallada no garantiza rendimiento fluido en gama media. El APK, la interacción táctil y los tiempos de carga requieren pruebas en dispositivos reales.
