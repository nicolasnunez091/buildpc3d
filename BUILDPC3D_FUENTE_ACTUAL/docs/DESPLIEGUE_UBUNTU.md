# Backend público sin inicio de sesión: Ubuntu

**No desplegado.** No crear Droplet ni abrir el servicio sin autorización.
Una API pública, aun con estas protecciones, puede sufrir abuso distribuido,
consumir cuota y generar cargos. No hay identidad ni garantía contra abuso.

## Arquitectura y límites

Android → HTTPS/Nginx → socket Unix privado/Gunicorn → Redis privado →
Groq. Firestore sigue siendo el catálogo y no participa en la autenticación.
No hay tokens, inicio de sesión ni claves dentro del APK.

`GROQ_ENABLED=false` por defecto desactiva la API con HTTP 503; cambiar la
variable y reiniciar el servicio para aplicarla. No cancela llamadas ya en
curso. Al activarla se requiere `GROQ_API_KEY` en el entorno del servidor.
No cargar `.env` en el proceso WSGI.

Redis aplica una reserva atómica: `IP_PER_HOUR=10` por IP durante una ventana
de 3600 segundos desde su primera solicitud, `GLOBAL_PER_DAY=100` por día UTC
(medianoche a medianoche según reloj de Redis), y `MAX_CONCURRENT=2` llamadas
simultáneas. Exceder cualquiera devuelve 429. Las cuotas se consumen antes de
llamar a Groq incluso si este falla; las rechazadas no se consumen. Cambiar
valores mediante el archivo de entorno y reiniciar todos los trabajadores.
Las IP de redes móviles/NAT pueden ser compartidas y limitar a varios usuarios;
un atacante con muchas IP puede eludir el límite por IP.

Las reservas de concurrencia caducan tras 120 segundos para recuperarse de
trabajadores caídos. Si una llamada sobrevive más de ese tiempo, podría haber
solapamiento: no es una garantía absoluta de concurrencia. Nginx y el número
de trabajadores añaden límites, pero si el cliente se desconecta el trabajo
del proveedor podría continuar. La llamada existente a Groq usa
`urllib.request.urlopen(..., timeout=15)` para operaciones de red/bloqueo;
**no es un plazo total estricto de extremo a extremo**. Godot espera 18 s.
Probar timeouts y cancelación reales antes de publicar.

Redis inaccesible devuelve 503 sin llamar a Groq. Tras un fallo posterior a la
reserva, una respuesta incierta no debe reintentarse automáticamente: podría
haber consumido cuota. Pérdida de datos o restauración antigua de Redis puede
reiniciar límites. Redis requiere persistencia y alertas; un límite de llamadas
no es un límite monetario. Configurar también límites, presupuesto y alertas
en Groq y DigitalOcean, con un responsable y procedimiento de emergencia.

Nginx sobrescribe `X-Forwarded-For` con la IP observada. La aplicación confía
en exactamente un proxy: no exponer Gunicorn por TCP ni poner otro proxy/CDN
delante sin rediseñar la política de IP y probar cabeceras falsificadas. Nginx
limita adicionalmente tasa por IP, conexiones por IP y conexiones globales.
Las respuestas 429/503 activan el respaldo local existente en Godot.

## Preparación del servidor

1. Elegir región, tamaño, dominio, DNS, presupuesto, alertas y responsable.
   No crear el Droplet antes de la autorización. Prever actualizaciones,
   copias cifradas, rotación de claves y respuesta a incidentes.
2. En Ubuntu instalar parches, `python3-venv`, Nginx, Redis, Certbot y plugin
   Nginx. Restringir SSH mediante claves y firewall; permitir solo 80/443 y
   acceso SSH administrativo restringido. No activar aún el sitio público.
3. Crear usuario de sistema sin login `buildpc3d`, grupo secundario `redis`,
   directorios `/opt/buildpc3d` y `/etc/buildpc3d`. Copiar solo código
   necesario; nunca `.env` ni credenciales. Crear un venv e instalar
   `backend/requirements-production.txt`. Antes de operar, fijar versiones
   resueltas con hashes, revisar vulnerabilidades y repetir las pruebas.
4. Configurar Redis sin TCP público: socket Unix
   `/run/redis/redis-server.sock`, modo 0770 y grupo `redis`. Configurar AOF
   `appendonly yes`, `appendfsync always`, `maxmemory-policy noeviction`,
   espacio de disco y memoria monitorizados. Comprobar persistencia,
   permisos, reloj y reinicios; no compartir Redis con otros sistemas.
5. Crear `/etc/buildpc3d/backend.env` a partir de
   `backend/deploy/backend.env.example`, propietario root, modo 0600. Systemd
   lo lee antes de bajar privilegios. Introducir la clave Groq por canal
   privado, nunca en comandos, registros, APK ni repositorio. Mantener
   `GROQ_ENABLED=false` hasta haber comprobado la instalación.
6. Copiar `backend/deploy/buildpc3d.service` a systemd, verificar rutas y
   ejecutar `systemd-analyze verify`. Recargar, habilitar y arrancar una vez
   configurado el entorno. Comprobar que Redis y el socket de Gunicorn no
   sean accesibles a usuarios no confiables. Revisar `journalctl` sin secretos
   ni texto de usuario. Access log de Nginx está desactivado; revisar
   configuración adicional y evitar registrar cuerpos o cabeceras.
7. Configurar DNS. Obtener certificado con Certbot mediante HTTP-01 o DNS-01;
   HTTP-01 requiere una configuración temporal que sirva solo el desafío en
   puerto 80. Sustituir `api.example.com` en `nginx.conf.example`, situar
   las zonas `limit_*_zone` en el contexto `http`, comprobar `nginx -t`,
   renovación y redirección HTTP→HTTPS. El ejemplo no emite certificados ni
   configura puerto 80.
8. En entorno restringido probar Redis real y concurrencia entre procesos,
   10/IP, 100/día UTC, 429, fallos/reinicio de Redis, kill switch, rechazo de
   JSON malformado y grande, cabeceras IP falsificadas, timeouts de proveedor,
   logs sin secretos y TLS/renovación. Ensayar la alarma y cierre inmediato.
   Solo después, con autorización, considerar exposición pública.

## Cliente y pruebas

No se requiere login. Windows sigue usando `ai_service_url`; Android utiliza
`ai_service_url_android`, vacío hasta disponer de URL HTTPS real. El
controlador ya envía JSON sin credenciales y vuelve al clasificador local ante
errores HTTP o de conexión. Tras tener URL real deberá configurarse y generarse
un APK, que se probará desde distintas redes; no se ha hecho ahora.

`python backend/app.py` conserva el servidor local y `.env` opcional. Las
pruebas con `backend/requirements-test.txt` usan fakeredis con Lua y Groq
simulado; no sustituyen Redis, Nginx, Gunicorn o proveedor reales:

```
python -m unittest discover -s backend/tests -v
```
