# DishToday

**1\. Visión General del Producto**
La aplicación es una plataforma social e interactiva centrada en la cocina casera y la nutrición inteligente. Combina las funcionalidades de una red social activa con la utilidad práctica de un gestor de despensa personalizado, permitiendo a los usuarios descubrir recetas adaptadas a los ingredientes que realmente tienen en casa, reduciendo el desperdicio de comida y facilitando la planificación nutricional.

**2\. Funcionalidades Principales**
*   **A. Módulo "Mi Despensa"**
Gestión de Inventario: Permite añadir, actualizar y quitar ingredientes disponibles en el hogar de forma rápida y sencilla.
Sugerencias Inteligentes de Recetas: Un algoritmo analiza los ingredientes en la despensa y recomienda recetas que el usuario puede preparar de inmediato.
Identificación de Faltantes: Indica qué ingredientes extras se necesitan para completar una receta determinada y permite añadirlos directamente a una lista de compras.
*   **B. Feed Social y Comunidad**
Exploración de Recetas: Feed dinámico con publicaciones de recetas compartidas por otros usuarios, clasificadas por tipo de cocina, tiempo de preparación e información nutricional.
Interacción Social: Opciones para dar "Me Gusta", comentar en las publicaciones, guardar recetas favoritas y compartirlas externamente o con otros miembros de la red.
Perfiles de Usuario: Espacio personalizado donde cada usuario puede publicar sus propias recetas, mostrar su progreso y conectar con personas con gustos o metas nutricionales afines.
*   **C. Módulos Adicionales y Valor Añadido**
Filtros Nutricionales: Búsqueda de recetas ajustadas a metas específicas (p. ej., conteo de calorías, macros, dietas keto, veganas o sin gluten).
Planificador Semanal: Herramienta para organizar el menú de la semana a partir de las recetas guardadas y los ingredientes disponibles.

**3\. Propuesta de Valor**
A diferencia de los recetarios tradicionales o redes sociales convencionales, la aplicación resuelve un problema cotidiano concreto ("¿qué puedo cocinar con lo que tengo?") al mismo tiempo que fomenta una comunidad activa centrada en la cocina saludable y el bienestar.

### **Stack Tecnológico:**
**1\. Infraestructura y Alojamiento**
El proyecto estará centralizado en un Servidor Privado Virtual (VPS) de Hetzner, aprovechando su alto rendimiento, escalabilidad y bajo costo de transferencia de datos.ComponenteTecnología / HerramientaDescripción y FunciónServidor VPSHetzner Cloud (Ubuntu Server)Instancia encargada de alojar la API del backend, bases de datos y servicios auxiliares.ContenerizaciónDocker & Docker ComposePermite empaquetar, desplegar y gestionar todos los servicios de forma aislada y reproducible.Servidor Web / Reverse ProxyNginx / CaddyGestiona el tráfico HTTP/HTTPS, balanceo de carga, proxy inverso y certificados SSL automáticos.

**2\. Frontend Móvil (iOS & Android)**
Para la aplicación móvil se selecciona una arquitectura multiplataforma orientada al alto rendimiento visual y fluidez de interfaz.Framework Principal: Flutter (Dart)Razones de elección:Permite desplegar aplicaciones nativas para iOS y Android desde una única base de código.Rendimiento gráfico fluido a 60 fps, esencial para el feed social con desplazamiento continuo y renderizado de imágenes.Facilidad para diseñar interfaces interactivas y dinámicas en el módulo "Mi Despensa".

**3\. Backend y Servicios del Servidor**
*   **API / Backend:** Node.js (NestJS) / Python (FastAPI). Gestión de usuarios, lógica social (comentarios, me gusta, feeds) y algoritmo de coincidencia de recetas según ingredientes de la despensa.
*   **Base de Datos:** PostgreSQL. Almacenamiento estructurado de perfiles, recetas, ingredientes, comentarios y relaciones de la red social.
*   **Base de Datos NoSQL / Caché:** Redis. Almacenamiento en memoria para acelerar la carga de feeds, gestión de sesiones y caché de búsquedas frecuentes.

**4\. Motor de Búsqueda y Sugerencias de Recetas**
*   **Tecnología:** Typesense (Alojado en el propio VPS vía Docker) o Algolia.
*   **Función:** Indexación ultra-rápida para autocompletado de ingredientes en la despensa, búsqueda avanzada de recetas por filtros nutricionales y cálculo inteligente de ingredientes faltantes.

**5\. Almacenamiento de Multimedia e Integraciones Exteriores**
*   **Almacenamiento de Archivos (Fotos/Videos):** S3-Compatible Object Storage (Hetzner Storage Box / Cloud Storage) o Amazon S3 para alojar las imágenes subidas por la comunidad.
*   **Optimización de Imágenes:** Integración con Cloudinary o procesamiento previo en backend para compresión automática y carga instantánea.
*   **Notificaciones Push:** Firebase Cloud Messaging (FCM) o OneSignal para alertas de actividad social y recordatorios de la despensa.
*   **Autenticación:** Firebase Auth o Supabase Auth (Sign-in con Google, Apple y Email).

**6\. Ventajas del Stack en Hetzner**
*   **Control Total de Costos:** Al desplegar la infraestructura base (PostgreSQL, Redis, Backend, Typesense) en Docker sobre Hetzner, se evitan costos elevados por consumo variable de servicios gestionados en la nube durante la fase inicial.
*   **Escalabilidad Modular:** Cada componente está contenerizado, permitiendo escalar el VPS de Hetzner o migrar servicios individuales a instancias dedicadas a medida que crezca la base de usuarios.
*   **Baja Latencia:** Excelente conectividad para la entrega rápida de contenidos y datos en tiempo real.
**7\. Estrategia de Monetización**
*   **Modelo Freemium:** Acceso gratuito a la red social y a un límite básico en la despensa. Suscripción premium para planificación semanal avanzada, análisis nutricional detallado o recetas exclusivas de profesionales.
*   **Afiliación / E-commerce:** Integración de enlaces directos a supermercados para comprar los ingredientes faltantes de una receta con un solo clic.

**8\. Retención y Gamificación**
*   **Rachas de Cocina:** Recompensas a los usuarios por registrar sus comidas diarias o publicar recetas durante días consecutivos.
*   **Logros e Insignias (Badges):** Reconocimientos en el perfil público (p. ej., "Cero Desperdicio", "Chef Repostero", "Macro Master") para fomentar la participación activa.

**9\. Hoja de Ruta para el Lanzamiento (Roadmap)**
*   **Fase 1 (MVP):** Registro de usuarios, gestión básica de "Mi Despensa", motor de búsqueda e interacción en el feed social (publicar, dar me gusta y comentar).
*   **Fase 2:** Filtros nutricionales avanzados (macros/calorías), listas de compras automatizadas y escáner de códigos de barras para ingresar productos rápido.
*   **Fase 3:** Recomendaciones impulsadas por IA según hábitos e integración con apps de salud (Apple Health, Google Fit).

**10\. Aspectos Legales y Privacidad**
*   **Cumplimiento Regulatorio (GDPR):** Tratamiento transparente y seguro de datos sobre salud (alergias, intolerancias o metas nutricionales).
*   **Derechos de Contenido:** Términos de uso claros sobre la propiedad y moderación de las fotos y recetas subidas por la comunidad.

**11\. Arquitectura de Datos e Interfaz (UI/UX)**
*   **Flujo de Pantallas Principales:** Onboarding: Registro rápido, selección de alergias/preferencias (keto, vegano, etc.) y configuración inicial de la despensa.
*   **Vista "Mi Despensa":** Interfaz visual por categorías (Lácteos, Verduras, Especias) con indicador de stock y estado de frescura.
*   **Ficha de Receta:** Tiempo de preparación, desglose nutricional, porcentaje de coincidencia con tu despensa y botón "Faltan X ingredientes -> Añadir a la lista".
*   **Diseño del Feed:** Grid visual atractivo tipo Pinterest o TikTok (según si prefieres enfoque en fotos fijas o video corto).

**12\. Estrategia de Contenido Inicial (Efecto "Red Vacía")**
*   **Base de Datos Inicial:** Importar un catálogo base de 500-1000 recetas abiertas y verificadas con información nutricional precisa antes del lanzamiento.
*   **Creadores Semilla:** Acuerdos con nutricionistas e influencers gastronómicos pequeños para que publiquen sus recetas en exclusiva durante las primeras semanas.

**13\. KPIs y Métricas de Éxito**
*   **Métricas Sociales:** Tasa de engagement en publicaciones, recetas guardadas por usuario y frecuencia de comentarios.
*   **Métricas de Utilidad:** Porcentaje de recetas cocinadas a partir de la despensa y tasa de conversión de ingredientes a la lista de compras.