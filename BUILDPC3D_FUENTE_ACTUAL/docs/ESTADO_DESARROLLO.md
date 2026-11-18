# Estado de desarrollo — BUILDPC3D

## Render y APK HTTPS

Android usa `https://buildpc3d-backend.onrender.com/interpretar` y realiza
GET `/health` con plazo de 90 s antes de un único POST. Si falla utiliza la
clasificación local, indicando su origen. Windows conserva su URL local.
`BUILDPC3D_Render_HTTPS_Debug.apk` fue exportado y firmado sin reemplazar
los APK anteriores; INTERNET y URL fueron comprobados en el paquete. Aún no
se probó este APK en un teléfono.

El backend tiene un diagnóstico temporal de arranque en el repositorio
independiente; Redis solo se ha comprobado desde Windows, no desde Render.
`GROQ_ENABLED` debe permanecer en false hasta verificar Redis desde Render y
la IP de cliente frente a falsificación. No se puede asegurar que la cuota IP
sea fiable con la cadena de proxies actual. No se ha activado Groq remoto.

## Preparación del servicio Ubuntu

Se adaptó la aplicación WSGI para acceso público sin inicio de sesión, con
cuotas IP y globales y control de concurrencia en Redis, desactivada por
defecto. No está desplegada ni probada con infraestructura real. Android no
necesita tokens; falta una URL HTTPS real y probarla antes de exportar. Pasos y
riesgos: `docs/DESPLIEGUE_UBUNTU.md`.

## Android y producción — trabajo actual

Se activó la emulación de ratón desde tacto y se declararon las propiedades
de edición y foco. La causa del fallo es probable, no confirmada en teléfono.
La prueba gráfica de propiedades y foco pasó; no hubo dispositivo ADB conectado.
Se exportó `godot/BUILDPC3D_Android_teclado_nuevo.apk` sin reemplazar el APK
anterior. Godot informó que falta icono de proyecto, pero firmó el APK debug.
Android tiene URL HTTPS independiente vacía y usará respaldo local. El backend
actual carece de autenticación y límites: no publicarlo. Véanse requisitos en
`docs/ANDROID_PRODUCCION.md`.

Actualización de trabajo: 16/11/2026. No guardar credenciales aquí.

## Objetivos y punto de partida

Proyecto Godot 4.7.2 existente, con catálogo local MVP de 42 productos,
ensamble 3D, compatibilidad y presupuesto, DAO Firestore y backend Python.
Prioridad: representaciones 3D diferenciadas; después Groq, catálogo y Android.
El PDF original no está en `docs/`; se utilizan `REQUISITOS.md` y
`MOCKUP_REFERENCIA_USUARIO.png`. Esta carpeta no es un repositorio Git.

## Situación inicial

- El visor detallado reutiliza un GLB genérico por categoría; cambiar producto
  actualiza los datos y el precio, pero no siempre cambia la apariencia.
- Hay seis GLB PBR genéricos de Innerscene CC0 y una GPU Grab3D CC0.
  Fuentes individuales: `VISOR_3D_REALISMO.md` y `GLB_Y_LICENCIAS.md`.
  Se conservan los 42 GLB originales ilustrativos.
- El backend llama a Groq pero no carga `backend/.env`; la URL en Godot está
  vacía. No hay clave disponible para probar Groq real en esta sesión.
- El DAO dispone de caché/versiones y respaldo local; Firebase real no está
  configurado. El APK y el rendimiento en Android real siguen sin comprobarse.
- Pruebas históricas, no pruebas de los cambios actuales: ver
  `RESULTADOS_DE_PRUEBAS.md` y `evidencias_windows/`.

## Fase 3D: variantes implementadas, fidelidad exacta pendiente

- `godot/data/variantes_3d.json` asigna los 42 ID a GLB PBR existentes y
  parámetros visuales independientes. Se usan dimensiones GPU del catálogo,
  ventiladores aproximados, acabados, iluminación RAM y detalles de chasis,
  fuente, placa y refrigeración. No son modelos comerciales exactos: las placas
  comparten la misma base ATX incluso si el SKU indica mATX, y los chasis
  comparten la misma envolvente. Esto no valida montaje real.
- `PCViewer.gd` crea las variantes conservando los recursos originales; la UI
  muestra el producto elegido fuera del modelo y lo identifica como aproximado.
  `tools/generar_variantes_3d.py` crea el mapa inicial sin sobrescribirlo.
- `godot/tests/test_variantes_3d.gd`: 42 variantes instanciadas y contactos GPU
  alcanzan PCIe; prueba de geometría aproximada, no validación de fábrica.
- `godot/tests/visual_variantes.gd`: Godot 4.7.2 gráfico en Windows, reemplazos
  por la UI y diferencias de imagen detectadas en GPU, RAM, placa, PSU,
  chasis y CPU; precios también comprobados. Capturas en `evidencias_finales/`.
  Las variaciones visuales de CPU corresponden al cooler ilustrativo. La cámara
  encuadra por gabinete y conserva el zoom al cambiar otras piezas. La prueba
  gráfica identificó diferencias demasiado sutiles y un encuadre ajustado;
  se corrigieron y repitió con resultado satisfactorio.
- Nuevas búsquedas públicas no encontraron una GPU de 1/2 ventiladores con
  licencia inequívoca mejor que los recursos disponibles; no se añadieron
  modelos externos nuevos ni se simularon réplicas exactas.

## Trabajo en curso

### Groq: verificación real posterior

- `backend/app.py` carga `backend/.env` al iniciar sin imprimir valores ni
  sobrescribir variables existentes; `.env.example` no contiene clave y
  `.gitignore` excluye `.env`. Endpoint oficial HTTPS, espera de 15 s, JSON
  Schema estricto con `openai/gpt-oss-20b` y modelo configurable.
- La documentación oficial lista el modelo como producción y compatible con
  JSON estricto; no se puede garantizar acceso para una cuenta concreta.
- Godot usa `127.0.0.1:8000` en Windows y rechaza HTTP en Android; la UI muestra
  perfiles amigables. El respaldo local y selección manual se mantienen.
- La verificación posterior identificó un HTTP 403 de Cloudflare al usar el
  User-Agent predeterminado de Python; el backend ahora envía `BUILDPC3D/1.0`.
  Se confirmó una llamada real a Groq y el endpoint `/interpretar` respondió
  HTTP 200 con `uso=edicion` y `fuente=groq` en un servidor de prueba local en
  puerto temporal. No se registró la clave.
- 19 pruebas Python backend aprobadas; Godot → backend Python → proveedor
  **simulado** también aprobó ocho frases/errores. Los errores ahora registran
  únicamente categorías y códigos HTTP, no cuerpos ni credenciales.
- Si el servidor anterior seguía abierto en el puerto 8000, debe reiniciarse
  para cargar el código corregido y cualquier cambio del archivo `.env`.

### Catálogo y Android

- `CatalogDAO.gd` valida las seis categorías y atributos imprescindibles,
  rechaza descargas incompletas y asocia la caché al ID del proyecto. Las reglas
  existentes permiten lectura de catálogo y deniegan escrituras de clientes.
  Firestore simulado aprobó cambio de versión, paginación y caché; no se
  configuró Firebase real ni se probaron reglas en un emulador oficial.
- `Recommender.gd` rechaza socket, dimensiones y potencias faltantes en lugar
  de asumir compatibilidad. La UI habla de compatibilidad estimada: medidas y
  TDP del MVP no sustituyen fichas reales.
- Windows: no se encontraron `adb` ni `javac` en PATH, SDK en la ubicación
  habitual ni plantillas Android 4.7.2. Se generó un PCK de recursos, no un APK;
  no se ha ejecutado en Android. Pasos concretos en `README.md`.

### Archivos de esta revisión

- Vista y datos: `godot/scripts/view/PCViewer.gd`, `Main.gd`,
  `godot/data/variantes_3d.json`; utilitario `tools/generar_variantes_3d.py`.
- Integración y modelo: `backend/app.py`, `backend/.env.example`, `.gitignore`,
  `godot/config/app_config.json`, `PCController.gd`, `CatalogDAO.gd`,
  `Recommender.gd`, `tools/probar_groq.py`.
- Pruebas: `backend/tests/test_backend.py`, `tests/test_project_integrity.py`,
  `tests/test_visual_models.py`, `tests/backend_groq_fixture.py`,
  `tests/ui_backend_fixture.py`, y scripts de `godot/tests/` para regresión,
  variantes, UI e integración IA. `tools/poner_modelo_glb.py` y
  `tools/instalar_modelos_cc0.py` ahora preservan archivos existentes.
- Documentación: `README.md`, `docs/REQUISITOS.md`, `PRUEBAS.md`,
  `RESULTADOS_DE_PRUEBAS.md`, `VISOR_3D_REALISMO.md`, `GLB_Y_LICENCIAS.md`,
  `MODELOS_SKETCHFAB.md` y `docs/evidencias_finales/`.

### Regresión ejecutada

- Godot 4.7.2 Windows: 69 comprobaciones generales; ensamble y assets PBR;
  variantes de 42 productos; prueba gráfica de sustituciones y precio para
  seis categorías; gestos táctiles simulados y navegación. Sin fallos en la
  última ejecución de cada prueba.
- Python: 18 pruebas backend y 18 de proyecto; compilan los scripts modificados.
- Godot ↔ Python ↔ proveedor simulado y UI ↔ backend simulado aprobados;
  Firestore REST simulado aprobado. No confundir con proveedores reales.
- PCK Android con catálogo, mapa de variantes, licencias, seis GLB y ETC2;
  no se detectó la ruta de `.env` ni el nombre de la variable privada en el PCK.

## Próxima tarea concreta

El usuario debe reiniciar su backend existente si aún no cargó la corrección;
verificar las reglas Firestore publicadas en un entorno seguro;
instalar SDK/JDK/plantillas para exportar y probar Android. Después contrastar
las medidas con fichas oficiales, medir rendimiento móvil y validar visualmente
todas las combinaciones importantes antes de declarar la entrega terminada.

## Firestore real: carga autorizada y verificada

- `firebase_project_id` configurado como `buildpc3d`; DAO, colecciones, reglas
  locales y `meta/catalog.version` coinciden. El catálogo local tiene 42
  componentes y versión 4.
- Antes de la carga, la lectura administrativa de los 43 documentos confirmó
  que todos estaban ausentes. Tras la autorización explícita y comprobar la
  huella aprobada, se creó el lote atómico de 42 productos y `meta/catalog`
  con versión 4. No se borraron ni sobrescribieron documentos.
- `firebase/seed_firestore.py` imprime una vista previa sin autenticación. La
  carga inicial requiere `--apply`, confirmación de proyecto y SHA-256 del plan;
  usa un lote de 43 operaciones `create`, sin sobrescribir ni borrar. El plan
  exacto está en `docs/PLAN_CARGA_FIRESTORE.md`.
- La lectura administrativa independiente confirmó que los 43 documentos
  coinciden exactamente. La verificación REST pública confirmó versión 4 y
  42 productos, sin campos distintos ni documentos extra en las seis
  colecciones. Godot 4.7.2 confirmó lectura real del DAO y 42 ID coincidentes.
  Una prueba de desconexión simulada confirmó el respaldo local.
- `seed_firestore.py` ahora desactiva los reintentos automáticos del SDK,
  limita el commit a 90 s y tres intentos y vuelve a leer los 43 documentos
  antes de cualquier reintento; se detiene ante lectura fallida, datos parciales
  o diferentes. 19 pruebas del cargador cubren estos casos con simulación.
- El `DeadlineExceeded` previo no pudo reproducirse ni atribuirse con certeza:
  gRPC de lectura respondió y el lote corregido funcionó en el primer intento.
  No se ha intentado una escritura de cliente para comprobar reglas reales;
  no se han cambiado reglas ni facturación.
