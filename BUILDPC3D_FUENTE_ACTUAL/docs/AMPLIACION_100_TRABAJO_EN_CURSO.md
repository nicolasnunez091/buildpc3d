# Ampliación del catálogo: trabajo en curso

**No es un plan aprobado de escritura y no se ha actualizado Firebase.** El
catálogo activo sigue siendo de 42 componentes, versión local 4. La expansión
requiere verificar datos técnicos y precios antes de cambiar el DAO o el
recomendador; no tratar la lista siguiente como piezas disponibles.

## Investigación inicial de fabricantes

| Candidato | Información consultada | Pendiente |
| --- | --- | --- |
| Samsung 870 EVO 500 GB | SATA 6 Gb/s, 2,5 pulgadas | Precio COP y compatibilidad de cada placa |
| Samsung 870 EVO 1 TB | SATA 6 Gb/s, 2,5 pulgadas | Precio COP y compatibilidad de cada placa |
| Samsung 870 EVO 2 TB | SATA 6 Gb/s, 2,5 pulgadas | Precio COP y compatibilidad de cada placa |
| Crucial P3 Plus 500 GB | NVMe PCIe 4.0, M.2 2280 | Precio COP y compatibilidad de cada placa |
| Crucial P3 Plus 1 TB | NVMe PCIe 4.0, M.2 2280 | Precio COP y compatibilidad de cada placa |
| Crucial P3 Plus 2 TB | NVMe PCIe 4.0, M.2 2280 | Precio COP y compatibilidad de cada placa |
| Crucial P3 Plus 4 TB | NVMe PCIe 4.0, M.2 2280 | Precio COP y compatibilidad de cada placa |
| Noctua NH-U12S redux | Aire, 158 mm; AM4/AM5 y LGA1700 en montaje compatible | Precio COP, versión del kit, espacio y evaluación térmica por CPU |

Fuentes: [Samsung 870 EVO](https://news.samsung.com/global/samsung-introduces-latest-in-its-worlds-best-selling-consumer-sata-ssd-series-the-870-evo),
[Crucial P3 Plus](https://eu.crucial.com/products/ssd/crucial-p3-plus-ssd) y
[Noctua NH-U12S redux](https://www.noctua.at/en/products/nh-u12s-redux/specifications).
Los precios no están verificados: no se han asignado ni agregado al catálogo.
El NSPR de Noctua no es una cifra de vatios intercambiable con el TDP de CPU.

## Bloqueos de integración

- Los documentos originales no describen todas las conexiones de placa,
  salida gráfica integrada, refrigerador incluido o espacio de refrigeración.
  Hay que documentar estos datos por modelo sin sobrescribir los originales.
- El DAO y la versión 4 existentes consumen seis categorías. La transición
  debe impedir que un cliente adopte un catálogo parcial y conservar su caché
  y respaldo; primero hay que diseñar y probar una migración compatible.
- Faltan 58 registros completos con fuentes y precios COP, reglas de
  compatibilidad de SSD/refrigeración y casos de gráficos integrados.
- `DemandAnalyzer.gd` alimenta umbrales orientativos de CPU, RAM y VRAM del
  catálogo de seis categorías. Esto cambia la elección de piezas para varias
  solicitudes, pero esas métricas no garantizan rendimiento ni sustituyen
  benchmarks o requisitos oficiales. Los gráficos integrados siguen sin
  estar implementados y la GPU dedicada sigue siendo obligatoria.
- La copia local independiente del backend tiene una propuesta no desplegada
  para devolver nivel, actividad y resolución mediante valores enumerados.
  El cliente acepta estos valores solo si son válidos y conserva el respaldo
  de respuestas antiguas; los casos reconocidos por reglas locales prevalecen.
  Groq real y el esquema nuevo no se han probado en Render.
- `tools/preflight_catalogo_100.py PROPUESTA.json` comprueba parte de la
  estructura, cantidades, preservación de registros y presencia de fuentes;
  no verifica por sí mismo la exactitud de las fuentes, compatibilidad física
  completa, ni escribe en Firebase. No es un cargador de Firestore.
