# Plan de pruebas — BUILDPC3D

Basado en la matriz de 24 casos de prueba del PDF (página 4).

| Caso | Verificación prevista en `godot/tests/run_tests.gd` |
|---|---|
| CP001 | Tres usos predefinidos. |
| CP002 | El filtro reconoce selección manual; la caída del servicio requiere prueba de UI. |
| CP003 | El modelo admite `juegos`; el JSON de IA se prueba en backend y en integración. |
| CP004 | Uso inválido `xyz` no permitido. |
| CP005 | Uso vacío no permitido; JSON inválido se prueba en Python. |
| CP006 | Filtro entrega las seis categorías para juegos. |
| CP007 | GPU por debajo del mínimo no se ofrece. |
| CP008 | Perfil inexistente devuelve vacío. |
| CP009 | CPU AM5 y placa AM4 rechazadas. |
| CP010 | CPU/placa AM5 aceptadas. |
| CP011 | RAM DDR4 y placa DDR5 rechazadas. |
| CP012 | Fuente 450 W insuficiente para consumo alto. |
| CP013 | GPU 340 mm rechazada en chasis de 300 mm. |
| CP014 | Ensamble de juegos válido y completo. |
| CP015 | Ensamble de ofimática óptimo (no existe uno válido de menor precio dentro del presupuesto). |
| CP016 | Catálogo sin chasis no genera equipo. |
| CP017 | Suma de seis precios = 3.050.000. |
| CP018 | Cambio 300.000 -> 350.000 aumenta 50.000. |
| CP019 | Alternativas de placas no contienen otro tipo. |
| CP020 | Alternativas RAM respetan DDR. |
| CP021 | Reemplazo de pieza válida actualiza equipo. |
| CP022 | Pieza inventada o incompatible se rechaza. |
| CP023 | `firestore_http_integration.gd`: dos consultas de metadatos con versión sin cambio no descargan colecciones. |
| CP024 | `firestore_http_integration.gd`: cambio de versión 1 a 2, descarga paginada y almacenamiento en caché de prueba. |

> CP023–CP024 se ejecutaron contra un servidor REST simulado, no contra Firebase real. El flujo de UI se ejercitó gráficamente en Windows y la conexión de IA contra un backend simulado. Ninguna de estas pruebas equivale a ejecutar el caso completo en Android.

## Pruebas manuales antes de entregar al docente

1. Ejecutar la app en Windows y Android. Revisar que opciones y texto se muestren en español.
2. Generar ofimática, juegos y edición; mostrar seis piezas, el valor y la geometría 3D.
3. Elegir cualquier pieza tocando sobre la malla y usando su fila de la lista; revisar el panel alternativo.
4. Cambiar la RAM por compatible, verificar costo y detalle sin perder la escena.
5. Intentar un presupuesto por debajo del mínimo; debe dar error controlado.
6. Desconectar Groq: selección manual debe seguir funcionando.
7. Revisar con Firebase una versión igual y una versión distinta con un mock contabilizando solicitudes.
8. Medir carga 3D <5 s, recálculo <1 s y clasificación <10 s, cada una en dispositivo gama media.
9. Ejecutar batería de 30 casos de compatibilidad reales y registrar evidencia.
10. Evaluar 5 personas sin conocimientos técnicos y constatar al menos 4 equipos armados sin ayuda.
11. Revisar que la clave Groq no exista dentro del APK y que producción use HTTPS.
12. Intentar escritura en Firestore desde cliente no autorizado y registrar denegación.

## Comandos

```bash
python -m unittest discover -s backend/tests -v
godot --headless --path godot --script res://tests/run_tests.gd
godot --headless --path godot --script res://tests/test_assets_realismo.gd
godot --headless --path godot --script res://tests/test_ensamble_realismo.gd
godot --headless --path godot --script res://tests/test_variantes_3d.gd
godot --path godot --script res://tests/visual_smoke.gd
godot --path godot --script res://tests/visual_variantes.gd
```

Para probar HTTP real en localhost, abre **dos terminales** en la raíz. Inicia
el servidor y espera su mensaje «listo» antes de ejecutar Godot en la segunda
terminal. El servidor se detiene por sí solo tras las solicitudes de prueba.

```bash
# Terminal 1
python tests/ai_http_fixture.py
# Terminal 2
godot --headless --path godot --script res://tests/ai_http_integration.gd
```

Repite con `python tests/firestore_http_fixture.py` y, en la otra terminal,
`godot --headless --path godot --script res://tests/firestore_http_integration.gd`.
El mock Firestore usa un archivo de caché exclusivo de prueba en `user://` y
nunca accede a una cuenta ni reemplaza la caché normal del proyecto.

Para probar el recorrido completo contra el backend Python real, sin acceder a
Groq y sin leer una clave real, inicia `python tests/backend_groq_fixture.py` y
ejecuta `godot --headless --path godot --script res://tests/ai_backend_integration.gd`
en otra terminal. El fixture simula exclusivamente las respuestas de Groq.
Para comprobar también ambos botones de la vista, inicia
`python tests/ui_backend_fixture.py` y ejecuta
`godot --headless --path godot --script res://tests/ui_backend_integration.gd`.
Estos fixtures no prueban la disponibilidad ni exactitud del proveedor real.

Para verificar el catálogo real configurado, usa
`python firebase/verificar_firestore.py --project-id buildpc3d` y
`godot --headless --path godot --script res://tests/firestore_real_read.gd`.
Para comprobar el respaldo sin conexión sin tocar Firestore, usa
`godot --headless --path godot --script res://tests/firestore_offline_fallback.gd`.

Una comprobación **real** opcional, con posible consumo de cuota, es
`python tools/probar_groq.py` después de configurar privadamente `backend/.env`.
La prueba muestra únicamente el perfil, no la clave.
