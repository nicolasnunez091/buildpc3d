# 🖥️ BUILDPC3D — Configurador Inteligente de Computadores en 3D

## 🖥️ BUILDPC3D — Configurador Inteligente de Computadores en 3D

#### Diseña, configura y explora tu computador de manera interactiva

**BUILDPC3D** es un proyecto académico orientado a facilitar la selección y configuración de computadores de escritorio mediante una aplicación móvil interactiva desarrollada en **Godot Engine 4.7.2**.

La aplicación permite que una persona describa para qué necesita un computador, reciba una recomendación basada en su perfil de uso, visualice el ensamblaje en un entorno tridimensional y cambie los componentes disponibles, teniendo en cuenta criterios de compatibilidad y costos estimados.

El proyecto integra desarrollo de software, inteligencia artificial, bases de datos en la nube y visualización 3D para ofrecer una herramienta educativa que ayude a comprender el funcionamiento y la selección de los componentes de un computador.

***

### 🎯 Objetivo del proyecto

#### Objetivo general

Desarrollar una aplicación móvil interactiva que permita configurar computadores de escritorio mediante inteligencia artificial, un catálogo de componentes de hardware, reglas de compatibilidad y visualización tridimensional.

#### Objetivos específicos

* Facilitar la selección de componentes según las necesidades del usuario.
* Interpretar solicitudes escritas en lenguaje natural utilizando inteligencia artificial.
* Recomendar configuraciones para actividades como estudio, videojuegos, programación, diseño y creación de contenido.
* Permitir consultar y reemplazar componentes de una configuración.
* Comprobar criterios técnicos de compatibilidad entre las piezas.
* Representar visualmente el computador mediante modelos 3D.
* Calcular dinámicamente el costo estimado en pesos colombianos.
* Integrar información de hardware almacenada en Firebase Firestore.
* Comprobar el funcionamiento de la aplicación mediante pruebas automatizadas y pruebas en Android.

***

### 🚀 Funcionalidades principales

#### 🤖 1. Interpretación de solicitudes mediante inteligencia artificial

BUILDPC3D permite que el usuario describa qué computador necesita utilizando lenguaje natural.

Por ejemplo:

> Mi hijo está en noveno de bachillerato y necesita un computador para realizar tareas y estudiar.

O también:

> Necesito un computador para jugar Minecraft, programar y estudiar.

La aplicación utiliza un sistema de validación de solicitudes y un servicio backend que integra **Groq** para interpretar el perfil de uso.

El sistema maneja tres perfiles principales:

| Perfil    | Actividades relacionadas                                           |
| --------- | ------------------------------------------------------------------ |
| Juegos    | Videojuegos, gaming y entretenimiento                              |
| Edición   | Diseño, programación, creación de contenido y edición de video     |
| Ofimática | Estudio, colegio, universidad, documentos y actividades de oficina |

**Validación de solicitudes**

Se incorporaron mejoras para distinguir entre solicitudes válidas, inválidas e incompletas.

**Solicitud válida:**

"Necesito un computador para grabar videos".

El sistema reconoce una necesidad relacionada con la creación de contenido.

**Solicitud inválida:**

"Quiero comer pizza".

El sistema debe rechazar la petición porque no corresponde a la configuración de un computador.

**Solicitud incompleta:**

"Quiero comprar un PC".

El sistema solicita más información sobre el uso previsto antes de generar una configuración.

Esta validación busca evitar recomendaciones generadas a partir de frases sin relación con el objetivo de la aplicación.

**Interpretación de respaldo**

Cuando el servicio remoto no está disponible, la aplicación dispone de un mecanismo local que puede reconocer determinadas solicitudes informáticas.

El respaldo local utiliza reglas y palabras relacionadas con los perfiles disponibles. No sustituye completamente las capacidades de interpretación del servicio de inteligencia artificial.

El sistema también incorpora manejo de solicitudes incorrectas, respuestas inesperadas y errores de conexión.

***

#### 🧩 2. Catálogo de componentes

La versión actual de BUILDPC3D dispone de **52 componentes**, distribuidos en siete categorías.

| Categoría                    | Cantidad |
| ---------------------------- | -------- |
| Procesadores (CPU)           | 8        |
| Tarjetas madre (Motherboard) | 8        |
| Memorias RAM                 | 8        |
| Tarjetas gráficas (GPU)      | 8        |
| Fuentes de poder (PSU)       | 5        |
| Gabinetes o chasis           | 5        |
| Unidades SSD                 | 10       |
| **Total**                    | **52**   |

El catálogo está conformado por 42 componentes base y diez unidades SSD incorporadas mediante una extensión local.

Los componentes incluyen información como nombre, referencia, características y precio estimado.

Las unidades de almacenamiento contemplan modelos SATA y NVMe, que también pueden representarse en el visor tridimensional.

***

#### 🔧 3. Comprobación de compatibilidad de hardware

BUILDPC3D incorpora reglas que permiten evaluar determinadas características de los componentes seleccionados.

Entre las comprobaciones implementadas se encuentran:

* Compatibilidad entre sockets de procesadores y placas madre.
* Tipos de memoria RAM admitidos.
* Restricciones conocidas de potencia.
* Determinadas dimensiones y restricciones físicas.
* Conectores de alimentación de GPU cuando existen datos suficientes.
* Formato y espacio de montaje entre fuentes de poder y gabinetes.
* Advertencias relacionadas con información no verificada de BIOS y revisiones de placa madre.

**Estados de compatibilidad**

La aplicación diferencia tres situaciones:

**Compatible:** los criterios técnicos evaluados coinciden.

**Incompatible:** existe una restricción conocida que impide utilizar la combinación.

**Pendiente de verificar:** faltan datos suficientes para confirmar algunos aspectos técnicos.

Cuando una combinación requiere verificaciones adicionales, la aplicación presenta advertencias al usuario.

El sistema busca evitar combinaciones con incompatibilidades conocidas y conservar un estado coherente cuando se rechaza el reemplazo de una pieza.

**Importante:** las comprobaciones son orientativas. No garantizan la compatibilidad comercial completa de todos los productos ni reemplazan la consulta de especificaciones oficiales del fabricante.

***

#### 🎮 4. Visualización interactiva en 3D

Una de las funciones principales de BUILDPC3D es su visor tridimensional, que permite explorar visualmente el ensamblaje de un computador.

El usuario puede:

* Observar la configuración del equipo en 3D.
* Girar la cámara alrededor del computador.
* Acercar y alejar la visualización.
* Restablecer la posición de la cámara.
* Observar representaciones de diferentes componentes.
* Cambiar piezas y visualizar las modificaciones correspondientes.
* Explorar la ubicación de unidades SSD SATA y NVMe.

El visor incorpora modelos 3D, materiales, texturas e iluminación para ofrecer una representación educativa del hardware.

Los modelos representan las características visuales de las piezas, pero no necesariamente reproducen con exactitud todas las dimensiones o acabados de los productos comerciales.

***

#### 💰 5. Cálculo dinámico de precios

BUILDPC3D calcula el valor estimado del computador utilizando los precios de los componentes seleccionados.

Los valores se presentan en **pesos colombianos (COP)**.

Cuando se reemplaza un componente, la aplicación actualiza el total de acuerdo con la nueva selección.

También se incorporaron validaciones para evitar que valores negativos o incorrectos alteren el cálculo.

Los precios utilizados son referencias del prototipo académico y pueden diferir de los valores actuales del mercado.

***

#### 🔄 6. Personalización del computador

Después de generar una configuración, el usuario puede consultar alternativas y reemplazar componentes.

El sistema permite:

* Revisar las piezas seleccionadas.
* Consultar alternativas disponibles.
* Comparar referencias y precios.
* Reemplazar componentes.
* Actualizar el costo total.
* Revisar advertencias de compatibilidad.
* Observar los cambios correspondientes en el visor 3D.

Las alternativas se evalúan mediante las reglas técnicas implementadas.

Cuando una combinación presenta una incompatibilidad conocida, el sistema debe impedir que se aplique como una selección válida.

***

### 📱 Estado actual del proyecto

BUILDPC3D cuenta con una versión Android que incorpora las mejoras recientes del sistema de interpretación, el catálogo ampliado y las validaciones orientativas de compatibilidad.

#### Características de la versión actual

| Característica                                | Estado             |
| --------------------------------------------- | ------------------ |
| Plataforma                                    | Android            |
| Motor                                         | Godot Engine 4.7.2 |
| Lenguaje principal                            | GDScript           |
| Componentes de hardware                       | 52                 |
| Categorías                                    | 7                  |
| Unidades SSD                                  | 10                 |
| Interpretación mediante IA                    | Implementada       |
| Respaldo local de interpretación              | Implementado       |
| Validación de solicitudes                     | Implementada       |
| Comprobaciones orientativas de compatibilidad | Implementadas      |
| Visualización interactiva en 3D               | Implementada       |
| Reemplazo de componentes                      | Implementado       |
| Cálculo de precios en COP                     | Implementado       |
| Integración con Firebase                      | Implementada       |
| Backend Python en Render                      | Desplegado         |

#### Evolución del proyecto

En una etapa anterior se generó una APK con 46 componentes, incluyendo cuatro unidades SSD.

Posteriormente se amplió el catálogo hasta alcanzar 52 componentes y se realizaron mejoras en la inteligencia artificial, los controles de la interfaz y la comprobación de compatibilidad.

La versión posterior fue exportada como APK Debug, instalada en BlueStacks y probada manualmente en un dispositivo Android.

Durante la prueba manual se comprobaron las funcionalidades principales, incluidos el catálogo, la interpretación de solicitudes y la visualización tridimensional.

Aunque los resultados fueron satisfactorios en las funciones revisadas, todavía pueden existir diferencias de funcionamiento entre dispositivos Android.

***

### 🛠️ Tecnologías utilizadas

| Tecnología         | Función dentro del proyecto                                   |
| ------------------ | ------------------------------------------------------------- |
| Godot Engine 4.7.2 | Desarrollo de la aplicación móvil y visualización 3D          |
| GDScript           | Lógica de aplicación, interfaz y componentes                  |
| Python             | Desarrollo del backend de interpretación                      |
| Groq               | Procesamiento de solicitudes mediante inteligencia artificial |
| Firebase Firestore | Almacenamiento del catálogo base                              |
| Render             | Alojamiento del backend remoto                                |
| JSON               | Configuración y almacenamiento de datos locales               |
| Git                | Control de versiones                                          |
| GitHub             | Repositorios del código fuente                                |
| GitBook            | Documentación técnica pública                                 |
| Android SDK        | Herramientas de compilación y depuración                      |
| BlueStacks         | Pruebas de funcionamiento en un entorno Android               |
| ADB                | Instalación, depuración y ejecución de pruebas Android        |

***

### 🏗️ Arquitectura del sistema

BUILDPC3D utiliza una arquitectura modular basada principalmente en **MVC (Modelo-Vista-Controlador)** y **DAO (Objeto de Acceso a Datos)**.

#### Modelo

Contiene las estructuras y reglas relacionadas con:

* Componentes de hardware.
* Perfiles de uso.
* Generación de recomendaciones.
* Reglas de compatibilidad.
* Cálculo de configuraciones.

Entre los archivos relacionados con esta capa se encuentran `Recommender.gd`, `CatalogDAO.gd` y `RequestValidator.gd`.

#### Vista

Se encarga de presentar las pantallas, controles, alternativas y representaciones tridimensionales.

Incluye la interfaz principal y los elementos visuales del computador.

Entre los archivos relacionados se encuentran `Main.gd`, `PCViewer.gd` y `DragScroll.gd`.

#### Controlador

Coordina las acciones del usuario con el modelo y los servicios externos.

Gestiona operaciones como interpretar solicitudes, generar recomendaciones y reemplazar componentes.

Uno de los archivos principales es `PCController.gd`.

#### DAO

El patrón DAO permite organizar el acceso a los datos del catálogo.

El componente `CatalogDAO.gd` gestiona información local y la integración con los registros de Firebase Firestore.

#### Servicio de inteligencia artificial

El backend está desarrollado en Python y recibe las solicitudes enviadas por la aplicación.

El servicio puede utilizar Groq para interpretar el perfil requerido y devolver una respuesta estructurada que Godot procesa mediante su propia lógica.

***

### ☁️ Integración con Firebase Firestore

BUILDPC3D utiliza **Firebase Firestore** para almacenar el catálogo base de hardware.

El catálogo original contiene 42 registros distribuidos en seis categorías.

Posteriormente se añadieron diez unidades SSD mediante una extensión local.

#### Funcionamiento general

1. La aplicación inicia y consulta la información del catálogo.
2. Se utilizan los registros disponibles de Firebase y los datos locales correspondientes.
3. Los componentes se organizan por categoría.
4. El recomendador utiliza los registros para construir configuraciones.
5. El usuario puede consultar y cambiar las piezas desde la interfaz.

La aplicación incorpora mecanismos de respaldo local para conservar funciones básicas cuando no es posible obtener determinados datos remotos.

***

### 🧠 Integración de Groq y Render

La inteligencia artificial de BUILDPC3D se comunica con un servicio backend desarrollado en Python.

El backend se encuentra alojado en Render y se administra mediante un repositorio independiente.

#### Flujo de interpretación

1. El usuario escribe una solicitud.
2. La aplicación verifica la información ingresada.
3. Las solicitudes que requieren interpretación remota se envían mediante HTTP al backend.
4. El backend procesa la petición utilizando Groq cuando el servicio está disponible.
5. Se devuelve una interpretación del perfil de uso.
6. Godot utiliza el perfil válido para generar una configuración.
7. La aplicación presenta los componentes recomendados y su costo.

#### Backend desplegado

[https://buildpc3d-backend.onrender.com](https://buildpc3d-backend.onrender.com)

#### Repositorio del backend

[https://github.com/nicolasnunez091/buildpc3d-backend](https://github.com/nicolasnunez091/buildpc3d-backend)

El backend remoto se administra por separado del código principal de Godot. Las modificaciones realizadas localmente en el backend no se consideran desplegadas automáticamente.

Las credenciales privadas utilizadas para conectar servicios no deben publicarse en los repositorios.

El servicio alojado en Render puede presentar demoras de activación después de permanecer inactivo.

***

### 📂 Estructura del repositorio

El repositorio principal conserva una estructura de desarrollo anterior y una carpeta que contiene el código fuente más reciente.

```
buildpc3d/
│
├── BUILDPC3D_FUENTE_ACTUAL/
│   ├── godot/
│   │   ├── assets/
│   │   ├── config/
│   │   ├── data/
│   │   ├── scenes/
│   │   ├── scripts/
│   │   │   ├── controller/
│   │   │   ├── model/
│   │   │   └── view/
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

#### Código fuente principal

El proyecto Godot más reciente se encuentra en:

`BUILDPC3D_FUENTE_ACTUAL/godot/`

Las carpetas `buildpc3d-app` e `ia-microservice` corresponden a estructuras anteriores conservadas como referencia del proceso de desarrollo.

***

### 💻 Instalación y ejecución del proyecto

#### Requisitos

* Godot Engine 4.7.2.
* Git.
* Un computador compatible con Godot 4.
* Herramientas de exportación Android para generar la APK.
* Android SDK y Java configurados para exportación.
* Conexión a Internet para las funcionalidades remotas.

#### Paso 1. Clonar el repositorio

Desde una terminal:

```
git clone https://github.com/nicolasnunez091/buildpc3d.git
```

#### Paso 2. Abrir Godot

Iniciar Godot Engine y seleccionar **Importar proyecto**.

Buscar:

```
buildpc3d/BUILDPC3D_FUENTE_ACTUAL/godot/project.godot
```

#### Paso 3. Importar los recursos

Permitir que Godot importe los modelos tridimensionales, texturas y demás archivos del proyecto.

#### Paso 4. Ejecutar

Abrir la escena principal:

`res://scenes/Main.tscn`

Presionar **F5** para ejecutar desde el editor.

#### Paso 5. Exportación Android

Para generar una APK es necesario configurar las herramientas Android, disponer de una plantilla de exportación compatible y utilizar un perfil de exportación de Godot.

La aplicación se ha exportado en formato APK Debug para realizar comprobaciones en Android.

***

### 🧪 Pruebas y validaciones

Durante el desarrollo se realizaron pruebas orientadas a detectar errores en las funcionalidades principales.

#### 1. Pruebas de interpretación

Se ejecutaron **62 casos de interpretación**, que incluyeron:

* Solicitudes de estudio.
* Solicitudes relacionadas con videojuegos.
* Programación y creación de contenido.
* Peticiones incompletas.
* Solicitudes absurdas.
* Textos incorrectos.
* Negaciones.
* Entradas vacías.
* Frases con caracteres especiales.

Los 62 casos reportados finalizaron satisfactoriamente en las pruebas automatizadas.

#### 2. Pruebas del backend

Se ejecutaron **32 pruebas automatizadas** utilizando proveedores y respuestas simuladas.

Estas incluyeron comprobaciones sobre respuestas HTTP, errores de conexión, estructuras de respuesta y tratamiento de solicitudes.

Las simulaciones permiten comprobar el manejo de errores sin consumir innecesariamente recursos del servicio remoto.

#### 3. Pruebas generales de Godot

Se reportaron **69 comprobaciones generales** ejecutadas satisfactoriamente.

Estas incluyeron funciones relacionadas con catálogo, recomendaciones, componentes y comportamiento de la aplicación.

#### 4. Auditoría de estrés funcional

Se realizó una auditoría de diferentes escenarios de uso.

Entre las operaciones verificadas se encontraron:

* Navegación repetitiva.
* Generación de configuraciones.
* Reemplazo de componentes.
* Cambios de unidades SSD.
* Interacciones de cámara.
* Operaciones de zoom.
* Validaciones de precios.
* Respuestas incorrectas y errores simulados.

La auditoría inicial permitió detectar deficiencias en determinadas reglas de compatibilidad.

Posteriormente se incorporaron comprobaciones adicionales y pruebas de regresión.

#### 5. Pruebas de compatibilidad

Se añadieron escenarios para comprobar:

* Componentes compatibles.
* Componentes incompatibles.
* Datos técnicos pendientes.
* Rechazo de reemplazos incompatibles.
* Conservación del precio después de una selección rechazada.
* Conservación del estado del visor.
* Manejo de configuraciones sin alternativas compatibles.

Estas pruebas utilizan tanto datos del catálogo como casos sintéticos preparados para comprobar situaciones específicas.

No equivalen a una certificación física de todos los componentes comerciales.

#### 6. Pruebas en BlueStacks

La APK fue instalada y ejecutada en BlueStacks, utilizando un entorno Android 9.

Se comprobaron distintas interacciones, entre ellas:

* Apertura de la aplicación.
* Visualización del catálogo.
* Generación de configuraciones.
* Navegación.
* Consulta de alternativas.
* Cambios de algunos componentes.
* Actualización de nombres y precios.
* Visualización del computador 3D.
* Giro y restablecimiento de cámara.

Las verificaciones automatizadas y las observaciones del emulador permitieron revisar aspectos del funcionamiento Android.

#### 7. Pruebas en dispositivo Android

La versión más reciente también fue instalada y probada manualmente en un celular Android.

Durante esa revisión se comprobó el funcionamiento general, la inteligencia artificial, la disponibilidad de los componentes y la representación tridimensional.

No se reportaron problemas evidentes en las funcionalidades revisadas.

Estas observaciones corresponden a las pruebas realizadas y no garantizan que el programa esté libre de errores en todos los dispositivos.

***

### ⚠️ Limitaciones conocidas

BUILDPC3D es un prototipo académico y tiene limitaciones que deben considerarse.

#### Compatibilidad técnica

No se dispone de toda la información necesaria para garantizar:

* La versión de BIOS instalada en cada placa madre.
* El soporte oficial de todas las combinaciones de CPU y motherboard.
* Los conectores exactos de todas las variantes comerciales de GPU.
* Los adaptadores o cables requeridos por determinadas tarjetas gráficas.
* La compatibilidad física completa entre todos los componentes.
* El comportamiento real de potencia ante todas las condiciones de carga.

Por lo anterior, el sistema utiliza advertencias cuando una compatibilidad queda pendiente de verificar.

#### Precios

Los precios son estimados y no corresponden necesariamente a cotizaciones comerciales actualizadas.

#### Inteligencia artificial

La interpretación depende de los servicios disponibles y de las reglas locales implementadas.

El sistema puede encontrar solicitudes ambiguas o formulaciones que requieran información adicional.

#### Visualización 3D

Los modelos representan de manera educativa las piezas del computador.

No constituyen planos físicos exactos ni sustituyen especificaciones de fabricación.

#### Rendimiento

El desempeño puede variar según el procesador, la memoria, el sistema operativo y la GPU del dispositivo Android.

***

### 🔮 Posibles mejoras futuras

Entre las mejoras propuestas se encuentran:

* Ampliar el catálogo con referencias adicionales verificadas.
* Incorporar refrigeración como categoría independiente.
* Añadir más metadatos oficiales para comprobar compatibilidad.
* Mejorar las validaciones de BIOS, conectores y montaje.
* Incorporar actualizaciones de precios.
* Optimizar el rendimiento en dispositivos móviles.
* Continuar mejorando la interpretación de solicitudes.
* Ampliar la cobertura de pruebas en distintos equipos Android.
* Desarrollar nuevas funciones de personalización.

Estas mejoras forman parte de posibles etapas posteriores y no deben confundirse con funcionalidades ya terminadas.

***

### 🎨 Modelos 3D y recursos

BUILDPC3D integra modelos tridimensionales utilizados como representaciones educativas de componentes de hardware.

Los recursos se emplean para visualizar distintas piezas y sus posiciones dentro del ensamblaje.

La procedencia, condiciones de uso y limitaciones de los recursos externos están documentadas en archivos del repositorio:

* `BUILDPC3D_FUENTE_ACTUAL/docs/GLB_Y_LICENCIAS.md`
* `BUILDPC3D_FUENTE_ACTUAL/docs/VISOR_3D_REALISMO.md`

Los modelos y texturas de terceros deben utilizarse y redistribuirse respetando sus licencias correspondientes.

***

### 🔗 Repositorios y documentación

#### Repositorio principal de BUILDPC3D

[https://github.com/nicolasnunez091/buildpc3d](https://github.com/nicolasnunez091/buildpc3d)

Contiene el código fuente de la aplicación, modelos, lógica de recomendaciones y pruebas.

#### Repositorio del backend

[https://github.com/nicolasnunez091/buildpc3d-backend](https://github.com/nicolasnunez091/buildpc3d-backend)

Contiene el servicio Python utilizado para la interpretación remota.

#### Documentación pública

[https://nico0910.gitbook.io/buildpc3d](https://nico0910.gitbook.io/buildpc3d)

Contiene la información general y técnica del proyecto.

***

### 👨‍💻 Equipo de desarrollo

Proyecto académico desarrollado con participación de:

| Integrante          | Rol                                  |
| ------------------- | ------------------------------------ |
| Juan José Hernández | Desarrollador principal              |
| Nicolás Núñez       | Arquitectura de datos y diseño UX/UI |
| Juan Lozano         | Analista                             |
| Samuel García       | Pruebas y control de calidad         |

***

### 🎓 Propósito académico

BUILDPC3D integra conocimientos de programación, arquitectura de software, inteligencia artificial, bases de datos, desarrollo móvil y diseño de experiencias tridimensionales.

El proyecto responde a la necesidad de facilitar la comprensión de los componentes que forman parte de un computador y de apoyar la selección de configuraciones según diferentes necesidades.

La aplicación permite conocer piezas, comparar alternativas, consultar precios estimados y explorar un computador mediante una representación tridimensional interactiva.

De esta manera, BUILDPC3D reúne conocimientos técnicos y una experiencia visual accesible para apoyar el aprendizaje sobre hardware.

***

**BUILDPC3D — Construye, explora y aprende.**

_Proyecto académico — Universidad Santiago de Cali — Noviembre de 2026._
