# Trazabilidad y alcance de BUILDPC3D

Fuente: PDF de 16 páginas entregado por el equipo, matriz de requisitos (página 5), arquitectura (páginas 7-16) y matriz de pruebas (página 4).

## Requerimientos funcionales

| ID | Alcance en esta versión | Dónde está |
|---|---|---|
| RF-01 | Campo de entrada de texto libre | `godot/scripts/view/Main.gd` |
| RF-02 | Opciones manuales Juegos, Edición, Ofimática aun sin IA | `Main.gd`, `PCController.gd`, `UseFilter.gd` |
| RF-03 | Cliente HTTP a Python; servicio Python llama a Groq y valida JSON | `PCController.gd`, `backend/app.py` |
| RF-04 | Perfiles mínimos locales por uso | `UseFilter.gd` |
| RF-05 | Compatibilidad zócalo, RAM, factor de forma, GPU/chasis y fuente | `Recommender.gd` |
| RF-06 | Ensamble de las seis piezas, de costo mínimo compatible | `Recommender.gd` |
| RF-07 | Vista 3D genérica PBR con variantes aproximadas por producto | `PCViewer.gd`, `variantes_3d.json` |
| RF-08 | Actualización local del precio total | `PCController.gd`, `Recommender.gd`, `Main.gd` |
| RF-09 | Selección de piezas tocando mallas o usando la lista | `PCViewer.gd`, `Main.gd` |
| RF-10 | Lista de alternativas compatibles y dentro del presupuesto | `Recommender.gd`, `Main.gd` |
| RF-11 | Reemplazo validado; actualiza nombre, lista, 3D y precio | `PCController.gd`, `Recommender.gd`, `Main.gd` |
| RF-12 | Diálogo de resumen con seis piezas, precios y total | `Main.gd` |

## No funcionales

| ID | Implementación / comprobación pendiente |
|---|---|
| RNF-01 | Se usa renderer Compatibility y geometría simple. Falta medir carga inferior a 5 s en Android gama media. |
| RNF-02 | Compatibilidad/precios en memoria sin acceso al servidor. Falta medir inferior a 1 s en teléfono. |
| RNF-03 | Timeout de 15 s en Python y 18 s en Godot para IA; aún falta medir respuesta real y comprobar el objetivo de 10 s. |
| RNF-04 | Mallas estáticas geométricas de baja complejidad. Falta medir fluidez del móvil. |
| RNF-05 | DAO carga caché o demo, solicita `meta/catalog.version` y actualiza cuando cambia; probado con servidor HTTP simulado, no con Firebase real. |
| RNF-06 | Compatibilidad determinista para atributos cargados. Necesario ejecutar 30 casos con catálogo de prueba e incluir comprobaciones de hardware adicionales si se usa para compras reales. |
| RNF-07 | El uso manual funciona sin Groq; el catálogo demo o la caché permiten uso sin internet. |
| RNF-08 | Clave de Groq exclusivamente en variable de entorno del servicio Python. En producción IA solo HTTPS. |
| RNF-09 | Firestore rules de lectura pública y escritura denegada. Falta probar reglas en Firebase Emulator/Console. |
| RNF-10 | Interfaz en español y mensajes de error. Faltan pruebas con 5 usuarios y demostrar 4/5. |
| RNF-11 | Motor Godot, proyecto preparado para Android. Falta compilar APK y ejecutar en dispositivos. |
| RNF-12 | MVC: vistas en `view/`, lógica y DAO en `model/`, orquestación y solicitudes de IA en `controller/PCController.gd`. La Vista solo recoge acciones y muestra resultados. |

## Decisiones de alcance

- El PDF exige **6 piezas obligatorias**, incluida GPU incluso en ofimática; por eso la configuración de oficina también incorpora tarjeta gráfica.
- Los perfiles no se alojan en Firebase: quedan definidos en código conforme al documento.
- El presupuesto está disponible y se filtra en la búsqueda; `0` significa que no hay límite.
- Los **precios son ficticios** y las reglas de compatibilidad son limitadas a los atributos modelados; no sustituyen comprobaciones de fabricación ni tiendas.
- La escena conserva 42 GLB ilustrativos originales y usa seis bases PBR CC0 de
  Innerscene con variantes aproximadas por ID, más una GPU CC0 opcional; no son
  reproducciones CAD exactas de los fabricantes.
- No se incluyó exportación APK firmada ni prueba en dispositivo físico por carecer de SDK/plantillas y equipo móvil en este entorno.
- No se puede afirmar 90% de acierto IA sin una muestra de frases, API activa y medición real.
