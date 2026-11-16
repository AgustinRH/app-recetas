# DishToday — operación del servidor

Fecha de este corte: **1 octubre 2026**. VPS de laboratorio. Host de ejemplo: `<SERVER_HOST>`. IP pública: `<SERVER_IP>`. Código en `/path/to/app`. Producto: [Plan de App.md](Plan%20de%20App.md).

La **API del MVP ya está levantada y persistente** (`restart: unless-stopped`). Este archivo ya no es “cómo clonar”; es **qué queda por hacer**.

> **Ojo al volver a clonar el repo en el VPS.** Dos cosas viven fuera de git y se pierden si borras la carpeta:
> `/path/to/app/infra/.env` (secretos) y `mobile/build/web` (la UI compilada que sirve `dishtoday-web`).
> Cómo regenerarlas: [sección 5](#5-si-algo-se-cae).

---

## 1. Cómo verlo ahora

El firewall del proveedor **no abre el puerto 3010** hacia internet. No hace falta abrirlo: todo va por el **80/443**, que ya está permitido.

### En el navegador (desde tu PC)

- **App:** https://dishtoday.eu — correo, contraseña o Google (Firebase).
- **API:** https://api.dishtoday.eu/health → `{"ok":true,"service":"dishtoday-api"}`
- `dishtoday.net`, `dishtoday.online` y los `www` redirigen a `https://dishtoday.eu`.
- `dishtoday.es` sigue sin abrir: Red.es no ha publicado la delegación. Cuando lo haga, el canónico pasa a ser el `.es`. Detalle en [sección 3.1](#1-dominio-y-https).

Hosts temporales tipo `sslip.io` y `http://<SERVER_IP>` pueden usarse en lab; no documentes la IP real en git.

**No uses** `http://<SERVER_IP>:3010` desde fuera: el firewall lo bloquea.

Si quieres que `:3010` funcione desde tu casa, en la consola del proveedor: **Firewall → regla inbound TCP 3010**. No es necesario para usar la app.

### Desde terminal (recetas, feed, login demo)

```bash
export BASE=https://api.dishtoday.eu
# o en el propio servidor: export BASE=http://127.0.0.1:3010
export AUTH="Authorization: Bearer dev:demo@dishtoday.app"

curl "$BASE/health"
curl -X POST -H "$AUTH" "$BASE/auth/sync"
curl -H "$AUTH" "$BASE/recipes/suggested"
curl -H "$AUTH" "$BASE/feed"
```

Usuario demo: `demo@dishtoday.app` (auth de desarrollo; `DEV_AUTH=true`). En producción `DEV_AUTH=false`.

### Puertos en este VPS

**80/443** los usa Nginx Proxy Manager. DishToday entra por el vhost propio, no como Proxy Host. Caddy sigue en **3010** solo en la red local del servidor.

```bash
cd /path/to/app/infra
docker compose --env-file .env ps
docker compose --env-file .env logs -f api
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

- Seed ya corrido: **126 ingredientes**, 10 recetas iniciales y el catálogo grande de `backend/src/seed/bulk-recipes.json` (unas 520). En `infra/.env`: `SEED_ON_START=false`, `DB_SYNC=false`. Recarga parcial: `docker compose --env-file .env exec api node dist/scripts/sync-recipes.js`.
- Con `DB_SYNC=false`, el esquema se aplica a mano con `psql`.
- Fotos: volumen `api_uploads` (`/uploads`).
- `DEV_AUTH=false`. La web entra con Firebase.
- `ADMIN_EMAILS` (en `infra/.env`) decide quién ve **Administración**.

```bash
cd /path/to/app/infra
docker compose --env-file .env ps
docker compose --env-file .env logs -f api
docker compose --env-file .env up -d --build
```

---

## 3. Próximos pasos (en este orden)

### 1. Dominio y HTTPS

Dominios en el registrador (1 oct 2026). Registros A/AAAA apuntan a `<SERVER_IP>` / `<SERVER_IPV6>` (valores reales solo en DNS, no en git).

| Dominio | Estado |
| --- | --- |
| `dishtoday.es` | Zona preparada (`@`, `www`, `api`) |
| `dishtoday.eu` | `@` y `www`; faltan AAAA y `api` |
| `dishtoday.net` / `.online` | Completar o redirigir al canónico |

Canónico previsto: `https://dishtoday.es` y `https://api.dishtoday.es`.

**HTTPS:** Let's Encrypt en el proxy del host (rutas del proxy fuera de este repo). `PUBLIC_BASE_URL` y el build Flutter usan `https://api.dishtoday.eu` hasta que el `.es` resuelva.

Cuando `dig +short A dishtoday.es` devuelva `<SERVER_IP>`: ampliar el certificado y pasar el canónico al `.es`.

### 2. App Flutter

```bash
cd /path/to/app/mobile
docker run --rm -v "$PWD":/work -w /work -e PUB_CACHE=/work/.pub-cache \
  ghcr.io/cirruslabs/flutter:stable \
  bash -c 'git config --global --add safe.directory "*" && flutter pub get && flutter build web --release --dart-define=API_BASE_URL=https://api.dishtoday.eu --dart-define=USE_DEV_AUTH=false'
rm -rf .pub-cache
cd ../infra && docker compose --env-file .env up -d --force-recreate --no-deps web
```

Móvil:

```bash
cd /path/to/app/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=https://api.dishtoday.eu
```

### 3. Firebase Auth

1. Proyecto Firebase del producto. Dominios autorizados `dishtoday.eu` (+ `.es` cuando resuelva).
2. `FIREBASE_PROJECT_ID` y `FIREBASE_SERVICE_ACCOUNT` en `infra/.env`. JSON de service account fuera de git.
3. Web: `mobile/lib/firebase_options.dart` (valores vía `--dart-define` / build local, no secretos de Admin).
4. `DEV_AUTH=false` en el servidor.

### 4. Endurecer secretos y backups

- `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` y `DATABASE_URL` solo en `infra/.env`.
- Rotar `TYPESENSE_API_KEY` si estuvo en git.
- Backups del volumen Postgres y de `infra/.env` fuera del clone.
- Migraciones TypeORM en lugar de `synchronize` cuando el esquema se estabilice.

### 5–7. Fotos, contenido, producto

Igual que el plan de producto en [Plan de App.md](Plan%20de%20App.md). Sync de ingredientes/recetas desde `/path/to/app/infra` con `docker compose --env-file .env`.

---

## 4. Mapa rápido de código

| Quieres tocar… | Archivo |
| --- | --- |
| Matching despensa ↔ receta | `backend/src/recipes/compute-match.ts` |
| Seed | `backend/src/seed/seed-data.ts` |
| Auth | `backend/src/auth/auth.guard.ts` |
| Compose / secretos | `infra/docker-compose.yml`, `infra/.env.example` |
| Proxy :3010 | `infra/Caddyfile` |
| Proxy HTTP del host | config del NPM en el servidor (fuera del repo) |

---

## 5. Si algo se cae

```bash
cd /path/to/app/infra
docker compose --env-file .env ps
docker compose --env-file .env logs api postgres caddy
curl http://127.0.0.1:3010/health
```

### Falta `.env`

Copia `infra/.env.example` → `infra/.env`, rellena secretos, `chmod 600 infra/.env`.

### La UI web devuelve 403

Recompila Flutter web (sección 3.2) y recrea el contenedor `web`.
