# BUILDPC3D

## Guía Interactiva de Ensamble y Configuración de PC

¡Bienvenido a la documentación oficial de **BUILDPC3D**! Este proyecto es una solución móvil diseñada para guiar a usuarios sin experiencia previa en el análisis, selección de componentes compatibles y ensamblaje 3D interactivo de computadores de escritorio.

***

### 1. Descripción del Proyecto

BUILDPC3D utiliza un microservicio basado en procesamiento de lenguaje natural (PLN) para determinar el perfil de uso del cliente, evaluando el presupuesto disponible y recomendando una configuración optimizada. La app garantiza un 100% de compatibilidad entre partes mediante un motor de verificación estricto y permite visualizar la compilación en un entorno 3D modular.

#### Requisitos Principales del Sistema

* **Interoperabilidad:** Descarga de catálogo de componentes en local una sola vez mediante patrón DAO.
* **Microservicio IA:** Análisis inteligente de necesidades según requerimientos del usuario.
* **Modelado 3D:** Renderizado de ensamblaje en tiempo real en dispositivos móviles.

***

### 2. Arquitectura del Software

El proyecto sigue una arquitectura monolítica modular orientada a servicios ligeros:

* **Frontend (App Móvil):** Cliente móvil interactivo desarrollado para la configuración e interfaz 3D.
* **Microservicio IA:** Módulo independiente encargado del procesamiento de requerimientos y recomendación de componentes.
* **Capa de Datos (DAO):** Implementación del patrón Data Access Object conectado a Firebase Firestore para la gestión de catálogos y persistencia offline/online.

***

### 3. Especificación de Requisitos (IEEE 830 / ERS)

#### Requisitos Funcionales

1. **RF-01:** Diagnóstico automatizado de perfil de uso según requerimientos en lenguaje natural.
2. **RF-02:** Verificación estricta de compatibilidad de hardware (socket, TDP, factor de forma, líneas PCIe).
3. **RF-03:** Visualización e interacción en escena 3D para el proceso de ensamble.
4. **RF-04:** Descarga y almacenamiento local del catálogo de partes.

#### Requisitos No Funcionales

1. **RNF-01:** Tiempo de respuesta del microservicio de IA inferior a 2 segundos.
2. **RNF-02:** Desempeño fluido del entorno 3D a un mínimo de 30 FPS en dispositivos gama media.
3. **RNF-03:** Interfaz intuitiva y accesible para usuarios novatos.

***

### 4. Estructura y Roles del Equipo (J2N Devs)

El proyecto cuenta con un plan de trabajo estructurado en 7 semanas y un presupuesto global de COP $9.700.000:

| Rol                      | Integrante                    | Responsabilidad Principal                                          |
| ------------------------ | ----------------------------- | ------------------------------------------------------------------ |
| **Analista de Sistemas** | Juan José Hernández Ruiz      | Análisis de requisitos, reglas de negocio y modelo ERS             |
| **Diseñador de Sistema** | Nicolás Carlos Núñez Figueroa | Arquitectura del software, UX/UI y diseño de integración 3D        |
| **Desarrollador**        | Juan David Lozano Rincón      | Codificación de la app cliente y conexión DAO / Firebase           |
| **Software Tester (QA)** | Samuel García                 | Diseño y ejecución de la matriz de pruebas unitarias e integración |

***

### 5. Guía de Inicio Rápido para Desarrolladores

#### Estructura del Repositorio

```
buildpc3d/
├── buildpc3d-app/      # Proyecto base de la aplicación móvil (Controller, Model, View)
├── docs/               # Documentación general y archivos GitBook (.md)
├── ia-microservice/    # Servicio backend de recomendación por PLN
└── generate_catalog.py # Script de automatización de catálogo
```
