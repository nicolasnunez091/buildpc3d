# BUILDPC3D - Guía Interactiva de Ensamble de PC

**BUILDPC3D** es una aplicación móvil desarrollada con arquitectura monolítica modular, diseñada para guiar a usuarios sin experiencia en el ensamble de computadores de escritorio. Utiliza procesamiento de lenguaje natural para identificar el perfil de uso del cliente y un motor de recomendación estricto para garantizar 100% de compatibilidad física y eléctrica.

## Equipo de Desarrollo
* **Juan José Hernández** -  Desarrollador Principal
* **Nicolás Núñez** - Arquitecto de Datos / Diseñador UX/UI
* **Juan Lozano** - Analista
* **Samuel García** - QA Tester

## Stack Tecnológico
* **Frontend & Engine:** Godot Engine (GDScript) - *Implementación de modelos 3D Low Poly y patrón MVC.*
* **Backend de Datos:** Google Firebase (Firestore) - *Consumido vía API REST utilizando el patrón de diseño DAO.*
* **Servicio de IA:** Python - *Microservicio REST que integra el LLM Groq para NLP.*

## Estructura del Repositorio
* `/buildpc3d-app/`: Proyecto principal en Godot (Vista, Modelo, Controlador).
* `/ia-microservice/`: API en Python para la interpretación de intenciones del usuario.
* `/docs/`: Documentación formal del proyecto (ERS IEEE 830, Arquitectura de Sistema, Software y Datos).
