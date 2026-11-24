# Diagnóstico OpenGL al cerrar pruebas

Fecha: 24 de noviembre de 2026. Godot 4.7.2, Windows, renderizador
Compatibility/OpenGL 3.3, AMD Radeon Graphics, controlador 26.11.2.261112.

Al terminar pruebas gráficas pueden aparecer dos mensajes de este tipo:

```text
ERROR: Texture with GL ID of 24: leaked 349524 bytes.
   at: ~Utilities (drivers/gles3/storage/utilities.cpp:82)
ERROR: Texture with GL ID of 25: leaked 349524 bytes.
   at: ~Utilities (drivers/gles3/storage/utilities.cpp:82)
```

Los identificadores GL pueden variar. Se reprodujeron con los scripts
anteriores a la mejora de IA y con los actuales. Una escena de prueba sin
instanciar la aplicación no presentó mensajes. Instanciar solo el visor sí.
Un SubViewport aislado no los produjo; un SubViewport con WorldEnvironment
y ProceduralSkyMaterial sí los produjo sin instanciar el visor ni la app.

Esto acota el fenómeno al cierre del entorno gráfico con cielo procedural en
esta configuración; no demuestra si es un defecto de Godot, del controlador
o de su interacción, ni establece su efecto en Android. No se deshabilitó el
cielo ni se alteró el visor. Todas las ejecuciones de diagnóstico devolvieron
código 0. Se requiere prueba física en Android y observación en sesiones
prolongadas antes de descartar problemas de memoria allí.

Prueba reproducible: `godot/tests/gl_cleanup_diagnostic.gd`, modos `empty`,
`ui`, `assembly`, `viewer`, `viewport` y `sky`, por ejemplo:

```text
godot --path godot --script res://tests/gl_cleanup_diagnostic.gd -- sky
```
