# Verificación de BUILDPC3D — revisión 16/11/2026

## Ejecutadas

- **Godot 4.7.2, Windows, headless:** 63 comprobaciones aprobadas: CP001–CP022, compatibilidad, frases locales, respuestas/errores IA y DAO, 42 GLB instanciados, colores por vértice, texturas preservadas y límites de mallas.
- **Godot 4.7.2, Windows, OpenGL Compatibility / AMD Radeon:** prueba gráfica con capturas en `docs/evidencias_windows/`. Se ejercitaron las tres pantallas, generación para «diseño», pantalla estrecha 360 × 780, pellizco y selección de los seis tipos de pieza mediante eventos táctiles simulados, vista de GPU CC0, alternativa compatible, recálculo de precio y dashboard. Los eventos no se ejecutaron en un teléfono.
- **Backend Python:** 15 pruebas aprobadas, con Groq simulado: normalización, formato JSON, clave ausente, desconexión, respuesta inválida y rutas HTTP.
- **Datos y recursos Python:** 14 pruebas aprobadas, con `trimesh`, `numpy` y `Pillow`: coste mínimo para los tres perfiles, modelos y colores, geometría contenida en las envolventes de los gabinetes, no intersección de las piezas conectadas y hashes intactos de los 42 GLB originales. Las envolventes son aproximaciones, no certifican montaje físico real.
- **Godot ↔ backend HTTP local:** respuesta válida simulada, JSON inválido, HTTP 503 y conexión cerrada; cuatro casos aprobados. La clave y Groq real no se utilizaron.
- **DAO ↔ Firestore REST simulado:** CP023 y CP024 aprobados: versión sin cambios, actualización 1 → 2, dos páginas de CPU y persistencia en caché aislada.
- **Paquete Android de recursos:** `--export-pack Android` generado para prueba, con `catalog.json`, `app_config.json`, 42 modelos, GPU opcional y texturas ETC2. No es un APK.
- **Compilación Python:** `python -m compileall -q backend firebase tools tests` sin errores.

## Pendientes y límites

- La exportación **APK debug se intentó y falló**: faltan plantillas Android de Godot 4.7.2, rutas configuradas de SDK Android y JDK; no hay APK instalado ni ejecutado en Android.
- Gestos reales, legibilidad, rendimiento y tiempos de carga en teléfonos; verificar también GPU, luz y materiales en distintos dispositivos.
- Groq real con clave propia y HTTPS; medición de latencia y precisión frente al conjunto de frases del equipo.
- Firestore real o Emulator oficial: reglas de seguridad, credenciales y comportamiento en red.
- Pruebas de usabilidad con cinco personas y verificación de medidas/compatibilidad con fichas de fabricantes.

El PDF original no estaba presente; se utilizó la matriz de requisitos y el
mockup existentes en `docs`. El proyecto no debe presentarse como validado por
completo en Android ni como cotización comercial.

## Revisión visual 3D posterior

En Godot 4.7.2 para Windows se importaron seis modelos PBR CC0 genéricos y se
comprobaron sus texturas y mapas normales. El test de ensamble aprobó 28
verificaciones de anclaje y vista reversible; la prueba gráfica volvió a pasar
rotación, pellizco, selección y navegación. Se generó un paquete de **recursos**
Android de prueba con los seis GLB y texturas ETC2, no un APK. Capturas y
licencias: `docs/evidencias_windows/torre_realismo.png` y
`docs/VISOR_3D_REALISMO.md`. Android físico y rendimiento móvil siguen pendientes.

## Revisión integral actual — 16/11/2026

- **Godot 4.7.2 headless:** 69 comprobaciones generales aprobadas; seis modelos
  PBR con texturas y normales; 28 controles del ensamble; 42 variantes por ID,
  contactos de GPU, encuadre y conservación del zoom comprobados.
- **Godot 4.7.2 gráfico en Windows:** flujo y gestos táctiles simulados sin
  fallos. La prueba de variantes confirmó reemplazo y precio, y detectó
  diferencias de imagen para GPU, RAM, placa, fuente, chasis y refrigeración
  de CPU. Capturas reales en `docs/evidencias_finales/`. Es una muestra de
  sustituciones, no una comparación visual de todos los pares de los 42 SKU.
- **Python:** 18 pruebas backend y 18 de integridad/modelos aprobadas. Se
  comprobó la integridad de los 42 GLB originales frente al manifiesto.
- **Godot → backend Python → proveedor simulado:** ocho ejemplos/respuestas de
  error aprobados; ambos flujos de la UI también se probaron contra backend
  local con Groq simulado. **No es una llamada real a Groq.**
- **Firestore REST simulado:** cambio de versión, paginación y caché aprobados.
  El DAO rechaza datos técnicos incompletos y conserva el catálogo anterior.
  No se accedió a un proyecto Firebase ni se probaron sus reglas reales.
- **Android:** paquete de recursos generado, no APK. En el entorno no se
  encontraron `adb`, `javac`, SDK en la ruta habitual ni plantillas 4.7.2.
  No se midió rendimiento ni se instaló en dispositivo o emulador.

Las dimensiones GPU/chasis y algunos precios son aproximados; la compatibilidad
es una estimación del MVP, no una garantía para compra o montaje.

### Carga Firestore real autorizada

Se verificó la huella aprobada y la ausencia administrativa de los 43
documentos; se ejecutó un lote atómico de creación, confirmado en el primer
intento. Una lectura administrativa independiente confirmó 43 documentos
coincidentes; REST público confirmó 42 productos y `meta/catalog.version=4`,
sin diferencias respecto al catálogo local. Godot 4.7.2 confirmó lectura real
del DAO y 42 ID coincidentes; una desconexión simulada confirmó respaldo local.
Las 19 pruebas de reintentos, conflictos y límites del cargador pasaron. No se
modificaron reglas ni facturación. La causa exacta del `DeadlineExceeded`
anterior no quedó demostrada por las pruebas disponibles.

### Corrección posterior de Groq

Se identificó que el User-Agent predeterminado de Python recibía HTTP 403 de
Cloudflare; con `BUILDPC3D/1.0` la misma petición estructurada funcionó. Se
ejecutó una llamada **real** a Groq y un POST HTTP real al backend corregido
en un puerto local temporal: HTTP 200, `uso=edicion`, `fuente=groq`. Las 19
pruebas unitarias del backend pasaron. El proceso previo que pueda estar
escuchando en el puerto 8000 debe reiniciarse para cargar la corrección.
