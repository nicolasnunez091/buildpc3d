# Modelos 3D: búsqueda y atribución (MVP)

## Estado actual

**No hay ficheros `.glb` de Sketchfab incluidos en este ZIP.** La API oficial
requiere iniciar sesión para descargar. Se incluyen enlaces a modelos de ejemplo,
y el visualizador de Godot está preparado para usar archivos GLB locales nombrados
según `godot/data/catalog.json` (`model3d_path`). La versión actual trae **42 modelos GLB originales diferenciados** (no importados de Sketchfab), con detalles geométricos y etiquetas. Consulta `GLB_Y_LICENCIAS.md` para el descargador del kit CC0 de Internet.

## Candidatos comprobados en Sketchfab (16-11-2026)

| Componente / enfoque | URL | Autor | Licencia mostrada | Triángulos aprox. | Precisión |
|---|---|---|---|---:|---|
| Chasis Corsair 4000D Airflow | https://sketchfab.com/3d-models/corsair-4000d-airflow-free-34df3ba96cf94e71accdb5779c4b8694 | Kirigami | CC BY | 98.500 | Modelo del chasis incluido en la lista |
| RAM Corsair Vengeance RGB Pro DDR4 | https://sketchfab.com/3d-models/ram-corsair-vengeance-ddr4-rgb-pro-ee5c6e6b2e524d63a7043365e73a2420 | lime.ball.animations | CC BY | 2.800 | Misma familia comercial; verificar variante exacta |
| RAM Corsair Vengeance RGB DDR5 Low Poly | https://sketchfab.com/3d-models/corsair-vengeance-rgb-ddr5-ram-low-poly-5352b17857ea4036ab61980c4c57f265 | PolyDavid | CC BY | 134 | Familia similar, no necesariamente mismo SKU |
| GPU con ventiladores (genérica) | https://sketchfab.com/3d-models/graphics-card-gpu-high-detail-3d-model-0426edcb09574887885cb7a669fc627c | GAMICO | CC BY | 6.400 | Referencia visual, no representa una SKU exacta |
| Motherboard de referencia | https://sketchfab.com/3d-models/motherboard-components-3bc94057328243d4b341a55f59160f8a | Daniel Cardona | CC BY | 82.100 | ASUS Z370-E, no compatible como ilustración exacta de las placas MVP |

Los autores, licencias y cifras son los mostrados por Sketchfab al revisar.
Verifica que sigan vigentes cuando descargues el archivo.

## Cómo integrar un modelo

1. Abre el enlace de Sketchfab y asegúrate de que tenga opción **Download 3D Model**.
2. Inicia sesión en tu cuenta de Sketchfab y revisa la licencia del modelo específico.
3. Descarga la versión glTF/GLB de forma autorizada (si viene glTF con texturas,
   conviértelo a GLB en Blender, conservando sus materiales).
4. Optimiza número de polígonos/texturas para Android. Usa Blender para rotar,
   aplicar escalas y centrar el objeto si hace falta.
5. Usa `tools/poner_modelo_glb.py` como se describe en el README. El importador
   copia a `assets/models/importados/` y modifica el catálogo. Si ya hay un
   archivo importado con ese ID, la herramienta se detiene sin sobrescribirlo;
   conserva una copia y decide manualmente cómo gestionar la versión anterior.
   Nunca sustituyas los 42 GLB originales.
6. Importa o recarga el proyecto Godot. Ejecuta el configurador y selecciona
   la pieza en el panel para ver cómo cambia al reemplazarla.
7. Añade los créditos (autor, enlace y licencia) a un apartado visible dentro de la
   aplicación antes de distribuirla. La atribución no debe existir solo en el README.

En Sketchfab la **licencia es por modelo**, no por sitio entero. Los modelos CC BY
requieren atribución. Otras licencias pueden prohibir uso comercial, cambios o la
redistribución como parte de una app. No descargues sin permiso ni elimines créditos.

Referencia: https://sketchfab.com/developers/download-api/guidelines

## Importante sobre tarjetas gráficas

La lista recibida nombra tarjetas como `NVIDIA RTX 4060 8GB` o `AMD Radeon RX 7600 8GB`,
pero **no indica el ensamblador (ASUS, MSI, Gigabyte, Sapphire, etc.)**. Esas variantes
pueden tener formas y largos muy diferentes. Para enseñar una GPU exacta, se debe
ampliar la entrada del catálogo con un SKU específico antes de asignar el `.glb`.
