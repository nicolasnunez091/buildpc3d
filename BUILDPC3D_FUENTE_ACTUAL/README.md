# BUILDPC3D — Entrega integral v4 (Godot 4.x)

Aplicación de escritorio/Android para crear un computador según su uso y presupuesto, revisar seis componentes en un visor 3D y reemplazar piezas compatibles. Basada en el PDF de arquitectura/requisitos y el mockup del equipo.

**Estado de verificación:** probado en Windows con Godot 4.7.2, tanto en modo gráfico OpenGL como en modo headless, con pruebas de Godot, Python e integración HTTP simulada. Se ha comprobado el empaquetado de recursos Android, pero **no se ha generado ni probado un APK en un teléfono**. Véase `docs/RESULTADOS_DE_PRUEBAS.md`.

## 1. Abrir el proyecto

1. Abre el administrador de proyectos de **Godot 4.7.2**, importa `godot/project.godot` y abre el proyecto **BUILDPC3D - Final V4**.
2. Permite que termine de importar los **42 modelos `.glb` del catálogo** y la GPU CC0 opcional.
3. Abre `godot/scenes/Main.tscn` y presiona **F5**.
4. Escribe, por ejemplo, «Quiero un PC para diseño» y pulsa **Analizar y generar**. También puedes seleccionar Gaming, Desarrollo/Render u Oficina manualmente. Para reemplazar, toca una pieza o su tarjeta, elige otra compatible y confirma.

**No necesitas instalar modelos para arrancar.** La torre usa variantes por
producto de un conjunto genérico detallado CC0 de Innerscene; también permite
volver a los 42 GLB originales. Longitudes y acabados son aproximados, no
réplicas comerciales. La GPU alternativa de Grab3D sigue disponible.

## 2. Diferencias con la v3

- Interfaz oscura con acentos fucsia, tres pantallas según mockup. Títulos y logo sin salto de línea por cada carácter.
- Visor con cámara y luces de menor intensidad, mapeo tonal fílmico y un **anclaje definido para cada tipo de pieza**. Los componentes importados se centran y escalan según los límites de su malla; se puede personalizar su rotación por modelo.
- Godot importaba las superficies con `COLOR_0` mediante un material que no utilizaba ese color. El visor activa los colores por vértice en copias de los materiales, conserva las texturas originales y ajusta posiciones, orientación y escala sin editar los GLB. Arrastra para orbitar, pellizca para zoom y toca al soltar para seleccionar.
- El conjunto detallado usa materiales PBR, mapas normales, disipador visual y una vista de corte. El disipador es ilustrativo y no está incluido en el precio. Procedencia y límites en `docs/VISOR_3D_REALISMO.md`.
- Gabinetes GLB reconstruidos con un lateral abierto, para visualizar las piezas internas y evitar que una pared opaca tape la GPU, RAM, CPU o fuente.
- **42 archivos GLB específicos del catálogo**, con diferencias visibles de marca/familia, ventiladores, tamaño y etiquetas; no se añaden cubos de forma predeterminada si el GLB está presente.
- Si el backend está configurado, se solicita a Groq la clasificación; si no
  responde, se intenta un clasificador local de palabras clave. La interfaz
  muestra el perfil sin detalles técnicos. La IA no decide compatibilidad.
- Precio total, compatibilidad, alternativas y presupuesto siguen ejecutándose localmente.
- Las alternativas mantienen, además, los mínimos del perfil elegido; los precios son orientativos.
- Reglas Firestore con escritura denegada y lectura pública limitada a las colecciones del catálogo.

## 3. Servicio IA real con Groq (opcional)

**Sin configurar Groq** el botón de interpretación funciona con palabras clave locales y selección manual. Esto no es inteligencia artificial generativa.

Para usar Groq debes disponer de una clave propia y ejecutar el backend Python. No pegues la clave en el código de Godot, en GitHub ni en este chat.

En Windows, desde PowerShell en la raíz del proyecto, copia el ejemplo solo si
todavía no existe `backend/.env` y ábrelo para editarlo en privado:

```powershell
if (-not (Test-Path backend\.env)) { Copy-Item backend\.env.example backend\.env }
notepad backend\.env
```

Dentro del archivo, pega tu clave después de `GROQ_API_KEY=` y guarda. No
compartas ese archivo. Las variables ya definidas en el entorno tienen
prioridad. Después ejecuta:

```powershell
py backend\app.py
```

El servicio escucha en `127.0.0.1:8000/interpretar` por defecto y Godot ya usa
esa URL para desarrollo en Windows. El modelo predeterminado
`openai/gpt-oss-20b` aparece en la documentación de Groq como modelo de
producción compatible con JSON Schema estricto; la disponibilidad efectiva
depende de la cuenta. `GROQ_MODEL` permite cambiarlo y `GROQ_JSON_MODE` elegir
`schema` o `json_object`. Para probar **una petición real**, con posible
consumo de cuota, ejecuta voluntariamente `py tools\probar_groq.py`. Sin una
clave propia no se ha probado la conexión real. El texto escrito se envía al
proveedor: no introduzcas datos sensibles.

La configuración predeterminada es:

```json
{
  "firebase_project_id": "",
  "ai_service_url": "http://127.0.0.1:8000/interpretar",
  "catalog_document": "catalog"
}
```

En el editor de Godot sobre el mismo Windows, `127.0.0.1` corresponde a tu computador. Para Android **no sirve `127.0.0.1` para hablar con el computador**: despliega el servicio Python en un servidor con **HTTPS** y usa esa dirección en `ai_service_url`. Nunca incluyas `GROQ_API_KEY` en el APK. La respuesta del servicio indica `"fuente":"groq"`; si falla, Godot usa el respaldo local o permite selección manual. Para desplegar, `HOST` permite cambiar la interfaz de escucha; añade autenticación, cuotas/rate limiting y un servidor de producción delante del servicio, no lo expongas directamente a Internet.

Puedes cambiar el modelo Groq mediante la variable de entorno `GROQ_MODEL` si el modelo predeterminado deja de estar disponible.

## 4. Firestore (opcional)

El catálogo de **42 componentes** se incluye en `godot/data/catalog.json`; se
puede probar sin Firebase. Para conectar uno propio:

1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com/)
   y habilita Firestore. Anota su **ID de proyecto**, no una clave privada.
2. En Firestore → Reglas pega el contenido de `firebase/firestore.rules` y
   publica. El cliente solo lee seis colecciones y `meta/catalog`; las
   escrituras de clientes están denegadas. Esta lectura es pública.
3. Revisa el plan sin red ni credenciales:

   ```powershell
   py firebase\seed_firestore.py --project-id buildpc3d
   ```

4. Para la carga, instala `py -m pip install --user firebase-admin` y configura
   autenticación administrativa local: con Google Cloud CLI, ejecuta
   `gcloud auth application-default login`; alternativamente, crea una cuenta
   de servicio con permisos de Firestore y guarda su JSON **fuera del proyecto**.
   No compartas el archivo ni su contenido.
5. **Solo después de autorizar el plan**, ejecuta:

   ```powershell
   py firebase\seed_firestore.py --project-id buildpc3d --apply --confirm-project buildpc3d --confirm-plan "HUELLA_DE_LA_VISTA_PREVIA"
   ```

   Para usar un JSON externo en vez de credenciales predeterminadas, añade
   `--credentials "C:\ruta\privada\cuenta.json"`. Copia la huella SHA-256
   mostrada en la vista previa autorizada: si el catálogo o destino cambia,
   se rechaza la carga. El script usa un único lote `create`, con una lectura
   administrativa antes de escribir y reintentos limitados solo después de
   reconciliar resultados inciertos. Si hay datos parciales o distintos, se
   detiene sin sobrescribir. Si todos ya coinciden, no vuelve a escribir.
   No elimina documentos. El SDK Admin omite las reglas de seguridad del cliente.
6. Comprueba `py firebase\verificar_firestore.py --project-id buildpc3d` y
   ejecuta `godot --headless --path godot --script res://tests/firestore_real_read.gd`.
   Ambas pruebas son de solo lectura. El ID ya está en `app_config.json`.
   El DAO conserva caché por proyecto y el catálogo local ante errores.

La herramienta actual es solo para **carga inicial**: no actualiza documentos
existentes. Para cambios posteriores se requiere un procedimiento de
actualización y autorización explícitos; incrementar la versión local por sí
solo no publica nada.

El JSON de cuenta de servicio de Firebase no se incluye ni se debe subir a GitHub. No se puede afirmar que las reglas ni el caché se hayan probado en un Firebase real sin desplegarlos.

## 5. Usar modelos exactos obtenidos de Sketchfab u otra fuente

Los **42 GLB del catálogo son ilustrativos y originales del proyecto**: no son digitalizaciones exactas de productos reales de ASUS/MSI/etc. Los nombres de GPU de tu lista, como «RTX 4060 8GB», tampoco indican un ensamblador preciso. Se añadió por separado una [GPU genérica de Grab3D](https://grab3d.com/models/electronics/graphics-card/), CC0 1.0, disponible como vista opcional.

Para sustituir un modelo por uno exacto que **hayas descargado con permiso de uso**, ejecuta desde la raíz del proyecto:

```cmd
py tools\poner_modelo_glb.py --id gpu_nvidia_rtx_4060_8gb --glb "C:\Descargas\mi_gpu.glb" --licencia "CC BY 4.0" --autor "Nombre autor" --url "https://..."
```

En caso de orientación distinta, añade `--rotar 90 0 0` (en grados). Después vuelve a abrir Godot y deja que importe el GLB. El importador registra licencia, autor, URL y rotación en el catálogo. No marques como «modelo exacto» uno que solo se parece.

**Sketchfab no da permiso de descarga para todos los modelos; comprueba la licencia individual antes de usarlos.** El script `instalar_modelos_cc0.py` permite descargar algunos GLB genéricos para experimentar, pero no sustituye automáticamente las piezas del ensamblaje.

## 6. Pruebas

Desde la raíz de la carpeta (las dependencias siguientes se usan para las pruebas de geometría; el servicio IA usa la biblioteca estándar de Python):

```cmd
py -m pip install -r requirements-dev.txt
py -m unittest discover -s backend\tests -v
py -m unittest discover -s tests -v
```

Las pruebas comprueban respuestas y errores HTTP del backend, compatibilidad y coste mínimo en los tres perfiles, integridad de los 42 GLB originales, geometría y procedencia de la GPU adicional.

Con Godot 4 instalado y disponible desde la terminal, puedes ejecutar las pruebas del proyecto:

```cmd
godot --headless --path godot --script res://tests/run_tests.gd
godot --headless --path godot --script res://tests/test_assets_realismo.gd
godot --headless --path godot --script res://tests/test_ensamble_realismo.gd
godot --headless --path godot --script res://tests/test_variantes_3d.gd
godot --path godot --script res://tests/visual_smoke.gd
godot --path godot --script res://tests/visual_variantes.gd
```

`godot` puede llamarse `godot4` o requerir la ruta completa al ejecutable de consola en Windows. Las dos últimas pruebas abren ventanas; la de variantes guarda capturas en `docs/evidencias_finales/`. Las pruebas HTTP Godot ↔ backend y DAO ↔ Firestore simulado se explican en `docs/PRUEBAS.md`; no requieren claves y no prueban servicios reales.

### Exportación Android

Existe un preset `godot/export_presets.cfg` con permiso de Internet y filtros
`*.json,*.txt`. Se comprobó un **paquete de recursos**, no un APK. Para probar
Android en Windows:

1. Instala OpenJDK 17 y Android Studio; en SDK Manager instala Platform-Tools
   35 o superior, Build-Tools 35.0.1, Android Platform 35, Command-line Tools,
   CMake 3.10.2.4988404 y NDK 28.1.13356709, según la
   [guía oficial Godot 4.7](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html).
2. En Godot instala las plantillas de exportación correspondientes a 4.7.2 y
   configura **Editor → Editor Settings → Export → Android → Java SDK Path /
   Android SDK Path**.
3. Para IA desde Android, configura previamente una URL de backend **HTTPS**;
   sin ella seguirá disponible el respaldo local. No incluyas claves en Godot.
4. En **Proyecto → Exportar → Android**, exporta un APK de depuración. Con un
   dispositivo autorizado por USB, usa `adb devices` y después
   `adb install ruta\buildpc3d-debug.apk`. No se ha realizado esta instalación.
5. Comprueba gestos, rendimiento, memoria y legibilidad. Para una publicación
   se requiere firma propia, nunca guardada en el proyecto; no publiques sin
   revisar seguridad y permisos.

## 7. Limitaciones declaradas

- Los precios en COP son en gran parte valores de referencia del archivo original y **no han sido verificados en tiempo real**. No uses el configurador como cotización comercial.
- El catálogo tiene medidas de chasis/GPU aproximadas para prototipo. Algunas compatibilidades adicionales (BIOS, conectores PCIe/PSU, refrigeración, RAM QVL) requieren datos del fabricante.
- Los GLB son piezas de referencia con materiales y detalles, no réplicas fotorrealistas; incorporar assets comerciales exactos depende de disponibilidad, licencia y optimización.
- No se ha producido ni probado un APK de Android. Para exportar se necesita configuración local de SDK/export templates de Godot.
- Cumplimiento de tiempos de carga, fluidez, IA externa y pruebas de usuario del PDF queda pendiente de medir en equipo real.
- El PDF original no se encuentra en esta carpeta; el análisis utilizó la matriz existente `docs/REQUISITOS.md` y el mockup. `docs/MANIFIESTO_INTEGRIDAD_V4.json` conserva hashes históricos de la entrega anterior; los scripts modificados ya no coinciden con él, pero los 42 GLB originales sí se verificaron.

**Estructura:** `godot/` (aplicación MVC y GLB), `backend/` (servicio Groq), `firebase/` (reglas y seed), `tools/` (importador de modelos), `tests/` (validaciones), `docs/` (trazabilidad y mockup).
