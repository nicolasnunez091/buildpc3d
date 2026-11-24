# 🖥️ BUILDPC3D — Configurador Inteligente de Computadores en 3D

### Diseña, configura y explora tu computador de manera interactiva

**BUILDPC3D** es un proyecto académico que busca facilitar la selección y el ensamblaje de computadores de escritorio mediante una aplicación interactiva desarrollada en **Godot Engine**.

La aplicación permite que una persona describa para qué necesita su computador, reciba una configuración recomendada, explore sus componentes en un entorno 3D y realice modificaciones teniendo en cuenta criterios de compatibilidad y costos estimados.

El proyecto combina **desarrollo de software, inteligencia artificial, bases de datos en la nube y visualización tridimensional** para ofrecer una experiencia educativa y práctica.

---

## 🎯 Objetivo del proyecto

Desarrollar una aplicación móvil que permita a los usuarios configurar computadores de escritorio de forma sencilla, utilizando interpretación de lenguaje natural, un catálogo de componentes y un sistema de recomendaciones.

BUILDPC3D está pensado especialmente para personas que no tienen conocimientos avanzados de hardware y necesitan comprender cuáles componentes pueden utilizar en un computador según sus necesidades.

## 🚀 Funcionalidades principales

### 🤖 1. Interpretación de solicitudes con inteligencia artificial

El usuario puede describir el computador que necesita utilizando lenguaje natural.

Por ejemplo:

> Necesito un computador para estudiar programación, utilizar Android Studio y jugar ocasionalmente.

La aplicación puede enviar esta solicitud a un servicio backend que utiliza **Groq** para interpretar el perfil de uso.

A partir de esa información, el sistema recomienda una configuración utilizando las reglas y los componentes disponibles en el catálogo.

Si el servicio de inteligencia artificial no está disponible, la aplicación cuenta con un mecanismo local de interpretación para mantener las funciones básicas.

### 🧩 2. Selección de componentes

BUILDPC3D permite trabajar con siete categorías de hardware:

- Procesadores (CPU).
- Tarjetas madre (Motherboard).
- Memorias RAM.
- Tarjetas gráficas (GPU).
- Fuentes de poder (PSU).
- Gabinetes.
- Unidades de almacenamiento SSD.

Cada componente dispone de información que permite identificarlo, comparar alternativas y conocer su precio estimado.

### 🔧 3. Verificación de compatibilidad

El sistema incorpora reglas que permiten evaluar distintas características de los componentes seleccionados.

Entre ellas se encuentran la compatibilidad de sockets, los tipos de memoria y ciertas restricciones de potencia y dimensiones.

El objetivo es reducir las combinaciones incompatibles y ayudar al usuario a comprender la relación entre las piezas.

**Importante:** las comprobaciones son orientativas y no sustituyen la verificación de las especificaciones oficiales del fabricante.

### 🎮 4. Visualización interactiva en 3D

Una de las principales características de BUILDPC3D es su visor tridimensional.

Este permite:

- Observar el computador ensamblado.
- Girar la cámara alrededor del equipo.
- Acercar y alejar la vista.
- Inspeccionar componentes.
- Visualizar distintas piezas del computador.
- Explorar la ubicación de las unidades SSD SATA y NVMe.

Los modelos 3D cumplen una función educativa y representan visualmente los componentes, sin pretender ser reproducciones exactas de todos los productos comerciales.

### 💰 5. Cálculo dinámico de precios

La aplicación muestra el precio total estimado del computador en **pesos colombianos (COP)**.

Cuando el usuario cambia o retira un componente, el valor total se actualiza automáticamente.

Los precios son referencias utilizadas para el prototipo y pueden diferir de los precios comerciales actuales.

### 🔄 6. Personalización del computador

El usuario puede modificar su configuración inicial seleccionando otras piezas disponibles.

El sistema permite revisar alternativas y actualizar la configuración, manteniendo las validaciones de compatibilidad implementadas.

---

## 📱 Estado actual del proyecto

BUILDPC3D cuenta con una versión APK que ha sido instalada y probada en un dispositivo Android.

| Característica | APK estable |
|---|---|
| Plataforma | Android |
| Motor de desarrollo | Godot 4 |
| Componentes disponibles | 46 |
| Categorías | 7 |
| Almacenamiento SSD | 4 unidades |
| Visualización 3D | Implementada |
| Selección y cambio de componentes | Implementados |
| Precios estimados en COP | Implementados |
| Interpretación con Groq | Integrada mediante backend |
| Respaldo local de interpretación | Implementado |

### Diferencia entre la APK y el código fuente

Es importante distinguir las dos versiones del proyecto.

**Versión estable para demostraciones**

La APK probada en Android contiene 46 componentes, incluyendo cuatro unidades SSD. Esta es la versión utilizada como referencia para las demostraciones del proyecto.

**Versión de desarrollo del repositorio**

El código fuente más reciente incorpora 42 componentes base y 10 unidades SSD locales, para un total de 52 registros de hardware.

Esta versión contiene modificaciones posteriores a la APK estable que todavía requieren compilación y validación en un dispositivo Android.

Las ampliaciones propuestas hacia 70 o 100 componentes siguen siendo trabajo pendiente y no deben confundirse con funcionalidades terminadas.

---

## 🛠️ Tecnologías utilizadas

| Tecnología | Utilización |
|---|---|
| Godot Engine 4.7.2 | Desarrollo de la aplicación y visualización 3D |
| GDScript | Programación de interfaces, lógica y funcionalidades |
| Python | Desarrollo de servicios backend |
| Firebase Firestore | Almacenamiento del catálogo de componentes |
| Groq | Interpretación de solicitudes mediante modelos de lenguaje |
| Render | Alojamiento del servicio backend remoto |
| Git y GitHub | Control de versiones y almacenamiento del código |
| JSON | Configuración, intercambio y almacenamiento local de datos |

## 🏗️ Arquitectura del sistema

BUILDPC3D utiliza una organización modular basada en los patrones **MVC (Modelo-Vista-Controlador)** y **DAO (Objeto de Acceso a Datos)**.

### Modelo

Contiene las estructuras y reglas relacionadas con los componentes del computador, las recomendaciones y la compatibilidad.

### Vista

Se encarga de mostrar las pantallas de la aplicación, los componentes disponibles y la visualización tridimensional.

### Controlador

Gestiona las interacciones del usuario y coordina las operaciones entre la vista, el modelo y los servicios.

### DAO

Administra el acceso al catálogo de hardware, incluyendo los datos locales y los registros obtenidos desde Firebase Firestore.

### Servicio de inteligencia artificial

Es un backend desarrollado en Python que recibe las solicitudes de los usuarios y utiliza Groq para interpretar el tipo de computador requerido.

La aplicación aplica posteriormente su propia lógica de recomendación y compatibilidad.

---

## ☁️ Integración con Firebase

BUILDPC3D utiliza **Google Firebase Firestore** para almacenar y consultar información del catálogo base.

El catálogo remoto contiene 42 componentes organizados en seis categorías originales.

Las unidades SSD añadidas posteriormente se gestionan mediante una extensión local del proyecto.

Esta arquitectura permite separar la información de hardware de parte de la lógica de la aplicación y conservar datos locales de respaldo cuando no sea posible acceder al servicio remoto.

---

## 🧠 Integración con Groq y Render

Para incorporar inteligencia artificial, BUILDPC3D utiliza un backend Python desplegado en Render.

El funcionamiento general es el siguiente:

1. El usuario escribe una solicitud en la aplicación.
2. Godot envía el texto al servicio backend.
3. El backend procesa la solicitud utilizando Groq.
4. El servicio devuelve una interpretación del perfil de uso.
5. La aplicación utiliza esa información para generar una configuración con los componentes disponibles.
6. El usuario puede consultar y modificar la recomendación desde la interfaz.

**Backend desplegado:**

https://buildpc3d-backend.onrender.com

**Repositorio del backend remoto:**

https://github.com/nicolasnunez091/buildpc3d-backend

El backend se administra de manera independiente del repositorio principal. Las claves privadas de Groq y las credenciales administrativas no se incluyen en el código público.

El alojamiento gratuito de Render puede tardar en activarse después de un periodo de inactividad.

---

## 📂 Estructura del repositorio

El proyecto conserva una estructura anterior y una carpeta con el código fuente de desarrollo más reciente.

```text
buildpc3d/
│
├── BUILDPC3D_FUENTE_ACTUAL/
│   ├── godot/
│   │   ├── assets/
│   │   ├── config/
│   │   ├── data/
│   │   ├── scenes/
│   │   ├── scripts/
│   │   ├── tests/
│   │   └── project.godot
│   │
│   ├── backend/
│   ├── firebase/
│   ├── docs/
│   ├── tests/
│   ├── tools/
│   └── README.md
│
├── buildpc3d-app/
├── ia-microservice/
├── docs/
├── README.md
└── .gitignore
```

### Ubicación del proyecto principal

El código de desarrollo más reciente se encuentra en:

`BUILDPC3D_FUENTE_ACTUAL/godot/`

Las carpetas `buildpc3d-app` e `ia-microservice` corresponden a estructuras anteriores que se conservaron como referencia del desarrollo.

---

## 💻 Cómo ejecutar el proyecto

### Requisitos

- Godot Engine 4.7.2.
- Git para clonar el repositorio.
- Un computador compatible con Godot 4.
- Python para ejecutar los servicios locales y algunas herramientas complementarias.
- Conexión a Internet para utilizar los servicios remotos.

### Paso 1. Clonar el repositorio

Abre una terminal y ejecuta:

```bash
git clone https://github.com/nicolasnunez091/buildpc3d.git
```

### Paso 2. Abrir Godot

Inicia Godot Engine y selecciona la opción **Importar proyecto**.

Busca el archivo:

```text
buildpc3d/BUILDPC3D_FUENTE_ACTUAL/godot/project.godot
```

### Paso 3. Importar los recursos

Permite que Godot termine de importar los modelos 3D, las texturas y los demás recursos.

### Paso 4. Ejecutar la aplicación

Abre la escena principal:

```text
res://scenes/Main.tscn
```

Presiona **F5** para ejecutar el proyecto desde el editor.

**Nota:** estas instrucciones permiten abrir el código fuente actual. Algunas funcionalidades pueden requerir configuración adicional o pruebas, ya que esta versión contiene cambios posteriores a la APK estable.

### Ejecución en Android

Para generar una APK se necesitan las herramientas de exportación de Android, el SDK correspondiente y la configuración de exportación de Godot.

El APK de demostración probado se conserva por separado y no está publicado actualmente en la sección Releases de este repositorio.

---

## 🧪 Pruebas y validaciones

Durante el desarrollo se han realizado verificaciones sobre diferentes partes del sistema, entre ellas:

- Carga y lectura del catálogo.
- Reglas de compatibilidad.
- Generación de recomendaciones.
- Integración con servicios de interpretación.
- Visualización de componentes en 3D.
- Selección y reemplazo de piezas.
- Interacción de la interfaz.
- Funcionamiento de la APK estable en un dispositivo Android.

El proyecto incluye carpetas de pruebas automatizadas y documentación técnica.

No todas las modificaciones recientes del código fuente han sido comprobadas en Android. Las pruebas de la APK estable no deben interpretarse como una validación de los cambios posteriores.

---

## ⚠️ Limitaciones y mejoras futuras

BUILDPC3D es un prototipo académico en desarrollo, por lo que todavía existen oportunidades de mejora.

Entre las principales se encuentran:

- Ampliar el catálogo con más componentes verificados.
- Incorporar sistemas de refrigeración como categoría independiente.
- Mejorar las reglas de compatibilidad física y eléctrica.
- Optimizar el rendimiento del visor 3D en dispositivos móviles.
- Actualizar los precios con información comercial más reciente.
- Mejorar la precisión de las recomendaciones según programas y videojuegos.
- Continuar realizando pruebas sobre diferentes dispositivos Android.
- Validar y publicar nuevas versiones instalables.

La finalidad del proyecto es ofrecer una herramienta educativa de apoyo a la configuración de computadores, no reemplazar las verificaciones técnicas necesarias antes de comprar o ensamblar equipos reales.

---

## 🎨 Modelos 3D y recursos

BUILDPC3D incluye modelos tridimensionales de referencia y algunos recursos externos documentados dentro del proyecto.

Los modelos comerciales utilizados como referencia no necesariamente representan las dimensiones o características exactas de los productos reales.

La información sobre procedencia, licencias y limitaciones de los recursos se encuentra en:

- `BUILDPC3D_FUENTE_ACTUAL/docs/GLB_Y_LICENCIAS.md`
- `BUILDPC3D_FUENTE_ACTUAL/docs/VISOR_3D_REALISMO.md`

Los recursos externos deben utilizarse y redistribuirse de acuerdo con sus respectivas licencias.

---

## 👨‍💻 Equipo de desarrollo

Proyecto académico desarrollado con participación de:

| Integrante | Rol |
|---|---|
| Juan José Hernández | Desarrollador principal |
| Nicolás Núñez | Arquitectura de datos y diseño UX/UI |
| Juan Lozano | Analista |
| Samuel García | Pruebas y control de calidad |

---

## 🎓 Propósito académico

BUILDPC3D integra conocimientos de programación, arquitectura de software, bases de datos, inteligencia artificial, desarrollo de aplicaciones y diseño de experiencias interactivas.

A través del proyecto se busca aplicar estos conocimientos a una problemática real: la dificultad que enfrentan muchas personas al momento de seleccionar componentes compatibles para construir su propio computador.

El resultado es un prototipo que permite aprender sobre hardware de forma visual, explorar alternativas y comprender mejor el proceso de configuración de una computadora.

---

**BUILDPC3D — Construye, explora y aprende.**

*Proyecto académico en desarrollo — Noviembre de 2026.*
