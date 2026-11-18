# Android y backend de producción

En Windows `godot/config/app_config.json` usa `ai_service_url` para el backend
local. Android usa exclusivamente `ai_service_url_android`, inicialmente vacío:
sin un servicio configurado se aplica el clasificador local. Una vez exista un
servicio protegido, establece allí su URL HTTPS completa `/interpretar` y
vuelve a exportar; nunca incluyas claves o tokens en este archivo o en el APK.
El permiso INTERNET ya está activo.

## Bloqueo de producción

El servidor local `app.py` es solo para desarrollo. Existe una aplicación
WSGI pública separada con cuotas en Redis y configuración de Nginx; aún no
está desplegada ni probada en infraestructura real. No publicar el servidor
local ni exponer Gunicorn directamente.

Arquitectura propuesta: Android -> HTTPS/Nginx -> servicio Python privado con
límites Redis -> Groq. Firestore continúa como catálogo. El secreto Groq
permanece en variables de entorno del servidor, sin registros sensibles.

La aplicación será pública sin inicio de sesión; los límites no garantizan
protección contra abuso distribuido ni cargos. Faltan pruebas reales, dominio,
DNS, certificado, presupuesto, alertas y decisión autorizada de despliegue.
No se debe incluir una clave fija en el APK. Véase `DESPLIEGUE_UBUNTU.md`.

Un Droplet Basic de DigitalOcean de 1 GiB figura a USD 6/mes; hay costes
adicionales posibles de dominio, tráfico, copias y Groq. Cloud Run dispone de
nivel gratuito sujeto a facturación, región y límites, pero requiere adaptar el
servicio y configurar identidad y cuotas. Consultar precios vigentes antes de
contratar. Fuentes: https://www.digitalocean.com/pricing/droplets y
https://cloud.google.com/run/pricing.

## APK y prueba

En Godot 4.7.2 configura las rutas de Android SDK y JDK en Editor Settings,
instala plantillas de exportación y abre Project > Export > Android. Exporta
un APK de depuración con **otro nombre**, sin sobrescribir
`godot/BUILDPC3D_Prueba.apk`. Instálalo en el teléfono; puede requerir la misma
firma que la instalación anterior. No desinstales la aplicación existente sin
guardar antes sus datos. Toca el campo de petición y escribe; cierra el teclado,
desplázate y edita el presupuesto, comprueba el teclado numérico, el botón de
generar y los gestos del visor. Repite en vertical, con navegación y al volver
del teclado. La configuración `follow_focus` ayuda al desplazamiento, pero la
visibilidad real depende del teclado y dispositivo y requiere prueba física.
