# DishToday — operación del servidor

Fecha de este corte: **1 octubre 2026**. VPS de laboratorio (Helsinki). El código vive en el directorio de despliegue del servidor (p. ej. `~/dishtoday`). Producto: [Plan de App.md](Plan%20de%20App.md).

La **API del MVP ya está levantada y persistente** (`restart: unless-stopped`). Este archivo ya no es “cómo clonar”; es **qué queda por hacer**.

> **Ojo al volver a clonar el repo en el VPS.** Dos cosas viven fuera de git y se pierden si borras la carpeta:
> el `.env` del proyecto (secretos) y `mobile/build/web` (la UI compilada que sirve `dishtoday-web`).
> Cómo regenerarlas: [sección 5](#5-si-algo-se-cae).

---

## 1. Cómo verlo ahora

El firewall del proveedor **no abre el puerto 3010** hacia internet. No hace falta abrirlo: todo va por el **80/443**, que ya está permitido.

### En el navegador (desde tu PC)

- **App:** https://dishtoday.eu — correo, contraseña o Google (Firebase).
- **API:** https://api.dishtoday.eu/health → `{"ok":true,"service":"dishtoday-api"}`
- `dishtoday.net`, `dishtoday.online` y los `www` redirigen a `https://dishtoday.eu`.
- `dishtoday.es` sigue sin abrir: Red.es no ha publicado la delegación. Cuando lo haga, el canónico pasa a ser el `.es`. Detalle en [sección 3.1](#1-dominio-y-https).

**No uses** el puerto `3010` desde fuera: el firewall lo bloquea y se queda en “no responde”.

Si quieres que `:3010` funcione desde tu casa, en la consola del proveedor: **Firewall → regla inbound TCP 3010**. No es necesario para usar la app.

### Desde terminal (recetas, feed, login demo)

Usa el dominio público (o `http://127.0.0.1:3010` si estás en el propio servidor):

```bash
export BASE=https://api.dishtoday.eu
export AUTH="Authorization: Bearer dev:demo@dishtoday.app"

curl "$BASE/health"
curl -X POST -H "$AUTH" "$BASE/auth/sync"
curl -H "$AUTH" "$BASE/recipes/suggested"
curl -H "$AUTH" "$BASE/feed"
```

Usuario demo: `demo@dishtoday.app` (auth de desarrollo; `DEV_AUTH=true`). En producción `DEV_AUTH=false` y ese token no vale.

### Puertos en este VPS

**80/443** los usa Nginx Proxy Manager. DishToday entra por el vhost propio, no como Proxy Host. Caddy sigue en **3010** solo en la red local del servidor.

```bash
cd ~/dishtoday/infra   # o la ruta real del clone en el servidor
docker compose ps
docker compose logs -f api
```

---

## 2. Qué está vivo ahora

| Servicio | Contenedor | Acceso |
| --- | --- | --- |
| API NestJS | `dishtoday-api` | público `:3010` y `web_proxy` (NPM) |
| UI web Flutter | `dishtoday-web` | nginx sirviendo `mobile/build/web`, vía NPM en los dominios de DishToday |
| Caddy | `dishtoday-caddy` | `0.0.0.0:3010` → API `:3000` |
| PostgreSQL 16 | `dishtoday-postgres` | solo `127.0.0.1:5432` |
| Redis 7 | `dishtoday-redis` | solo `127.0.0.1:6379` |
| Typesense 27.1 | `dishtoday-typesense` | solo `127.0.0.1:8108` |

- Seed ya corrido: **126 ingredientes**, 10 recetas iniciales y el catálogo grande de `backend/src/seed/bulk-recipes.json` (unas 520, con foto de Wikimedia Commons cuando hay una libre). En `.env`: `SEED_ON_START=false`, `DB_SYNC=false`. Para volver a cargar solo lo que falte: `docker compose --env-file ../.env exec api node dist/scripts/sync-recipes.js` (tarda, descarga las fotos).
- Como `DB_SYNC=false`, los cambios de esquema se aplican a mano con `psql`. Ya aplicados (1 oct 2026): columnas `protein/carbs/fat/servings/difficulty` en `recipes` y tabla `shopping_items`. Si se añaden entidades nuevas, hay que repetir el `ALTER TABLE`/`CREATE TABLE` en producción antes de desplegar la API.
- Fotos: disco en el volumen `api_uploads` (`/uploads`). MinIO no está: las imágenes oficiales ya no se publican en Docker Hub.
- `DEV_AUTH=false`. La web entra con Firebase. El token `dev:` ya no vale.
- `ADMIN_EMAILS` (en `.env`, no se commitea) decide quién ve **Administración** en el perfil.

Comandos de operación:

```bash
cd ~/dishtoday/infra
docker compose --env-file ../.env ps
docker compose --env-file ../.env logs -f api
docker compose --env-file ../.env up -d --build
```

---

## 3. Próximos pasos (en este orden)

### 1. Dominio y HTTPS

Dominios comprados en Arsys (1 oct 2026), con servidores DNS `dns97.servidoresdns.net` y `dns98.servidoresdns.net`:

| Dominio | Estado en la zona de Arsys |
| --- | --- |
| `dishtoday.es` | Listo: `@`, `www` y `api` con registros A/AAAA apuntando al VPS |
| `dishtoday.eu` | `@` y `www` con A. Faltan AAAA y `api` |
| `dishtoday.net` | Sin registros A ni AAAA (la zona existe, vacía) |
| `dishtoday.online` | Sigue en el parking de Arsys |

El nombre canónico será `https://dishtoday.es` (app) y `https://api.dishtoday.es` (API). Los otros tres, cuando estén apuntados, redirigen al `.es`.

**Qué resuelve ya en internet** (1 oct 2026, por la tarde): `.eu`, `.net` y `.online`. El `.es` no: Red.es todavía no publica la delegación, así que `dig +short A dishtoday.es` sale vacío aunque Arsys sí conteste.

**HTTPS activo** en los tres que resuelven. Certificado Let's Encrypt gestionado junto al proxy (Nginx Proxy Manager / certbot en el host). Renovación vía cron del host.

- `https://dishtoday.eu` → app. `https://api.dishtoday.eu` → API.
- `.net`, `.online` y todos los `www` redirigen al `.eu`. `api` de esos dos redirige a `api.dishtoday.eu`.
- `PUBLIC_BASE_URL=https://api.dishtoday.eu`. La web se compila con `--dart-define=API_BASE_URL=https://api.dishtoday.eu`.
- `dishtoday.es` y `api.dishtoday.es` tienen el `server` de HTTP preparado, sin certificado.

**Cuando `dig +short A dishtoday.es` devuelva la IP pública del VPS:** ampliar el certificado con esos nombres, pasar el canónico a `https://dishtoday.es` / `https://api.dishtoday.es` y redirigir `.eu`, `.net` y `.online` hacia el `.es`.

En Arsys, los A/AAAA de un dominio nuevo salen bloqueados mientras la página de cortesía está activa (filas TXT `_dep_ws_mutex` y `_dcp_ws_mutex`). Se desbloquean en **Comportamiento del dominio**, quitando esa página. No tocar NS, SOA ni esos TXT.

Cuando el dominio esté estable se puede quitar el puerto 3010 público y cualquier host temporal tipo `sslip.io`.

### 2. App Flutter

**UI web (ya desplegada).** Se compila en el propio VPS con Docker, sin instalar Flutter:

```bash
cd ~/dishtoday/mobile
docker run --rm -v "$PWD":/work -w /work -e PUB_CACHE=/work/.pub-cache \
  ghcr.io/cirruslabs/flutter:stable \
  bash -c 'git config --global --add safe.directory "*" && flutter pub get && flutter build web --release --dart-define=API_BASE_URL=https://api.dishtoday.eu --dart-define=USE_DEV_AUTH=false'
rm -rf .pub-cache
cd ../infra && docker compose --env-file ../.env up -d --force-recreate --no-deps web
```

El `--force-recreate` de `web` es obligatorio si `mobile/build/web` se borró y volvió a crear (nginx se queda apuntando a la carpeta antigua). Tarda ~2 min; el `main.dart.js` resultante pesa ~3 MB.

**Móvil (Android/iOS).** Las carpetas `android/` e `ios/` ya están en el repo. Hace falta un PC/Mac con Flutter SDK:

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=https://api.dishtoday.eu
```

La web de producción ya entra con Firebase (`USE_DEV_AUTH=false`). En Android/iOS el demo sigue compilado por defecto hasta que existan `google-services.json` y `GoogleService-Info.plist`; contra esta API el token `dev:` ya no vale.

### 3. Firebase Auth

Hecho para la web (1 oct 2026):

1. Proyecto Firebase del producto. Correo/contraseña y Google. Dominio autorizado `dishtoday.eu` (añadir `dishtoday.es` cuando resuelva).
2. `FIREBASE_PROJECT_ID` y `FIREBASE_SERVICE_ACCOUNT` en `.env`. El JSON no está en el repo (`.gitignore` ignora `*firebase-adminsdk*.json`; copia en un directorio de secretos del host, fuera del clone).
3. La web usa `mobile/lib/firebase_options.dart`. En móvil faltan `google-services.json` y `GoogleService-Info.plist`.
4. `DEV_AUTH=false` en el servidor. Un id token de Firebase llega a `GET /me` y crea el perfil.
5. La web se compila con `--dart-define=USE_DEV_AUTH=false`.

Apple Sign-In sigue pendiente de una cuenta de Apple Developer.

### 4. Endurecer secretos y backups

- Definir `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` y `DATABASE_URL` en `.env` (el compose ya no lleva la clave en claro). Si la clave antigua llegó a estar en git, **rótala en el servidor**.
- Rotar `TYPESENSE_API_KEY` (está en `.env`; recrear `typesense` + `api`).
- Backups periódicos del volumen `infra_postgres_data` (y `infra_api_uploads` si hay fotos).
- Guardar una copia del `.env` fuera del repo (p. ej. en un directorio de backups del root): está en `.gitignore` y es lo único que tiene la `TYPESENSE_API_KEY`.
- Cuando el esquema no cambie: migraciones TypeORM en lugar de `synchronize`.

### 5. Almacenamiento de fotos (opcional)

MinIO comunitario ya no publica imágenes Docker. Opciones:

- Seguir con disco (`./uploads`) — es lo que hay ahora.
- S3 compatible (Hetzner Object Storage / Cloud Storage) y cablear `StorageService`.
- Construir MinIO desde fuente si se insiste en self-host.

### 6. Contenido inicial

El plan pide **500–1000 recetas** abiertas antes de lanzar. El catálogo de `bulk-recipes.json` cubre unas 520 recetas caseras (texto propio, no copiado de un recetario). Las fotos salen de Wikimedia Commons, con la atribución en la descripción (`Foto: …`). Regenerar el JSON: `python3 backend/scripts/build-bulk-recipes.py`. Cargarlo en el VPS es el `sync-recipes.js` de arriba.

Ingredientes: el catálogo base está en `backend/src/seed/seed-data.ts` (~125). Para añadir más, amplía esa lista y ejecuta en el VPS:

```bash
cd ~/dishtoday/infra
docker compose --env-file ../.env up -d --build api
docker compose --env-file ../.env exec api node dist/scripts/sync-ingredients.js
```

Solo inserta los que falten (por nombre, sin distinguir mayúsculas). Además los usuarios pueden crear ingredientes desde la app (`POST /ingredients`): si el nombre o un alias ya existe (ignorando acentos), devuelve el existente.

### 7. Producto (Fases 2–3)

Cuando el MVP se use de verdad, según [Plan de App.md](Plan%20de%20App.md):

- Fase 2: ~~filtros por tiempo/cocina/dieta~~, ~~lista de la compra~~ (hechos en la app), filtros nutricionales, escáner de barras.
- Fase 3: recomendaciones IA, Apple Health / Google Fit.
- Más adelante: planificador semanal, freemium, rachas y badges.

---

## 4. Mapa rápido de código

| Quieres tocar… | Archivo |
| --- | --- |
| Matching despensa ↔ receta | `backend/src/recipes/compute-match.ts` |
| Seed ingredientes/recetas | `backend/src/seed/seed-data.ts` |
| Auth token / demo | `backend/src/auth/auth.guard.ts` |
| Feed + Redis + filtros | `backend/src/recipes/recipes.service.ts` |
| Lista de la compra | `backend/src/shopping/shopping.service.ts` |
| Tarjeta de receta / filtros (app) | `mobile/lib/widgets/recipe_grid_card.dart`, `mobile/lib/widgets/filter_bar.dart` |
| Despensa + lista (app) | `mobile/lib/screens/pantry_screen.dart`, `mobile/lib/screens/shopping_screen.dart` |
| Typesense | `backend/src/search/search.service.ts` |
| Fotos (disco o S3) | `backend/src/storage/storage.service.ts` |
| URL de la API en el móvil | `mobile/lib/config.dart` |
| Compose / servicios | `infra/docker-compose.yml` |
| Proxy en :3010 | `infra/Caddyfile` |
| Host HTTP en NPM | config custom del proxy en el host (fuera del repo) |

---

## 5. Si algo se cae

```bash
cd ~/dishtoday/infra
docker compose --env-file ../.env ps
docker compose --env-file ../.env logs api postgres caddy
curl http://127.0.0.1:3010/health
```

Errores habituales: `DATABASE_URL` con `localhost` dentro del contenedor `api` (el host es `postgres`); pelear por el puerto 80 con Nginx Proxy Manager; `DEV_AUTH=false` sin Firebase.

### Falta `.env` (`couldn't find env file`)

Pasa si se volvió a clonar el repo. `.env` no está en git. Copia `.env.example` a `.env` y rellena los secretos (en prod: `NODE_ENV=production`, `DB_SYNC=false`, `SEED_ON_START=false`, `MINIO_ENDPOINT=` vacío, `PUBLIC_BASE_URL=https://api.dishtoday.eu`, `DEV_AUTH=false`, `FIREBASE_PROJECT_ID` y `FIREBASE_SERVICE_ACCOUNT`, más `POSTGRES_*` y `DATABASE_URL`). `REDIS_URL` y `TYPESENSE_HOST` los sobreescribe el compose. Luego `chmod 600 .env`. La cuenta de servicio de Firebase no se commitea.

### La UI web devuelve 403

`mobile/build/web` no existe o está vacío (también se pierde al reclonar). Recompila con el comando de Docker de la [sección 3.2](#2-app-flutter) y recrea el contenedor `web`.
