# DishToday — estado en Hetzner y próximos pasos

Fecha de este corte: **16 septiembre 2026**. VPS: `REDACTED_HOST` (`REDACTED`, Helsinki). Repo: `/path/to/app`. Producto: [Plan de App.md](Plan%20de%20App.md).

La **API del MVP ya está levantada y persistente** (`restart: unless-stopped`). Este archivo ya no es “cómo clonar”; es **qué queda por hacer**.

---

## 1. Cómo verlo ahora

El firewall de Hetzner **no abre el puerto 3010** hacia internet. No hace falta abrirlo: todo va por el **80**, que ya está permitido.

### En el navegador (desde tu PC)

- **App (pantallas):** http://dishtoday.REDACTED.sslip.io  
  Login demo: `demo@dishtoday.app` → **Entrar en demo**. No pulses Google (no hay Firebase).
- **API (JSON):** http://REDACTED/health → `{"ok":true,"service":"dishtoday-api"}`

**No uses** `http://REDACTED:3010` desde fuera: se queda en “no responde”.

Si quieres que `:3010` funcione desde tu casa, en la consola de Hetzner: **Firewall → regla inbound TCP 3010**. No es necesario para usar la app.

### Desde terminal (recetas, feed, login demo)

```bash
export BASE=http://REDACTED
export AUTH="Authorization: Bearer dev:demo@dishtoday.app"

curl "$BASE/health"
curl -X POST -H "$AUTH" "$BASE/auth/sync"
curl -H "$AUTH" "$BASE/recipes/suggested"
curl -H "$AUTH" "$BASE/feed"
```

Usuario demo: `demo@dishtoday.app` (auth de desarrollo; `DEV_AUTH=true`).

### Puertos en este VPS

**80/443** los usa Nginx Proxy Manager (FestivAll, PhotoJosma y ahora DishToday por Host/IP). Caddy sigue en **3010** solo en la red local del servidor.

SSH al servidor:

```bash
ssh root@REDACTED
cd /path/to/app/infra
docker compose ps
docker compose logs -f api
```

---

## 2. Qué está vivo ahora

| Servicio | Contenedor | Acceso |
| --- | --- | --- |
| API NestJS | `dishtoday-api` | público `:3010` y `web_proxy` (NPM) |
| Caddy | `dishtoday-caddy` | `0.0.0.0:3010` → API `:3000` |
| PostgreSQL 16 | `dishtoday-postgres` | solo `127.0.0.1:5432` |
| Redis 7 | `dishtoday-redis` | solo `127.0.0.1:6379` |
| Typesense 27.1 | `dishtoday-typesense` | solo `127.0.0.1:8108` |

- Seed ya corrido: **57 ingredientes** y **10 recetas**. En `.env`: `SEED_ON_START=false`, `DB_SYNC=false`.
- Fotos: disco en el volumen `api_uploads` (`/uploads`). MinIO no está: las imágenes oficiales ya no se publican en Docker Hub.
- `DEV_AUTH=true` (sin Firebase no hay otra forma de autenticar).

Comandos de operación:

```bash
cd /path/to/app/infra
docker compose --env-file ../.env ps
docker compose --env-file ../.env logs -f api
docker compose --env-file ../.env up -d --build
```

---

## 3. Próximos pasos (en este orden)

### 1. Dominio y HTTPS

Comprar (o apuntar) un dominio, por ejemplo `api.dishtoday.app`, a `REDACTED`.

En Nginx Proxy Manager (`http://REDACTED:81`):

1. Proxy Host → `dishtoday-api:3000` (la API ya está en la red `web_proxy`).
2. SSL Let’s Encrypt.
3. Forzar HTTPS.

Luego en `/path/to/app/.env`:

```env
PUBLIC_BASE_URL=https://api.dishtoday.app
```

Y recrear la API:

```bash
cd /path/to/app/infra
docker compose --env-file ../.env up -d --force-recreate api
```

Cuando el dominio esté estable se puede quitar el puerto 3010 público y el host `sslip.io`.

### 2. App Flutter (para “ver” la UI)

Hace falta un PC/Mac con Flutter SDK (no el VPS):

```bash
cd mobile
flutter create . --project-name dishtoday --org app.dishtoday
flutter pub get
flutter run --dart-define=API_BASE_URL=http://REDACTED
```

Cuando haya HTTPS, cambia `API_BASE_URL` al dominio. Login demo: `demo@dishtoday.app` (`USE_DEV_AUTH` sigue en true por defecto).

Pendiente: carpetas `android/` e `ios/` (no se generaron todavía).

### 3. Firebase Auth (imprescindible antes de usuarios reales)

1. Proyecto Firebase (email, Google; Apple si hay iOS).
2. Cuenta de servicio → `FIREBASE_SERVICE_ACCOUNT` + `FIREBASE_PROJECT_ID` en `.env`.
3. `google-services.json` / `GoogleService-Info.plist` en Flutter.
4. `DEV_AUTH=false` y recrear `api`.
5. Compilar con `--dart-define=USE_DEV_AUTH=false`.

**No apagues `DEV_AUTH` hasta que Firebase verifique tokens.** Si lo haces ahora, toda la API autenticada devolverá 401.

### 4. Endurecer secretos y backups

- Cambiar usuario/clave de Postgres en `infra/docker-compose.yml` **y** `DATABASE_URL` a la vez (hoy son `dishtoday` / `dishtoday`).
- Rotar `TYPESENSE_API_KEY` (está en `.env`; recrear `typesense` + `api`).
- Backups periódicos del volumen `infra_postgres_data` (y `infra_api_uploads` si hay fotos).
- Cuando el esquema no cambie: migraciones TypeORM en lugar de `synchronize`.

### 5. Almacenamiento de fotos (opcional)

MinIO comunitario ya no publica imágenes Docker. Opciones:

- Seguir con disco (`./uploads`) — es lo que hay ahora.
- S3 compatible (Hetzner Object Storage / Cloud Storage) y cablear `StorageService`.
- Construir MinIO desde fuente si se insiste en self-host.

### 6. Contenido inicial

El plan pide **500–1000 recetas** abiertas antes de lanzar. El seed son 10 de prueba. Es trabajo de datos (CSV/SQL → `ingredients` + `recipes`), no de arquitectura.

### 7. Producto (Fases 2–3)

Cuando el MVP se use de verdad, según [Plan de App.md](Plan%20de%20App.md):

- Fase 2: filtros nutricionales, lista de compras, escáner de barras.
- Fase 3: recomendaciones IA, Apple Health / Google Fit.
- Más adelante: planificador semanal, freemium, rachas y badges.

---

## 4. Mapa rápido de código

| Quieres tocar… | Archivo |
| --- | --- |
| Matching despensa ↔ receta | `backend/src/recipes/compute-match.ts` |
| Seed ingredientes/recetas | `backend/src/seed/seed-data.ts` |
| Auth token / demo | `backend/src/auth/auth.guard.ts` |
| Feed + Redis | `backend/src/recipes/recipes.service.ts` |
| Typesense | `backend/src/search/search.service.ts` |
| Fotos (disco o S3) | `backend/src/storage/storage.service.ts` |
| URL de la API en el móvil | `mobile/lib/config.dart` |
| Compose / servicios | `infra/docker-compose.yml` |
| Proxy en :3010 | `infra/Caddyfile` |
| Host HTTP en NPM | `/path/to/proxy/data/nginx/custom/http.conf` |

---

## 5. Si algo se cae

```bash
cd /path/to/app/infra
docker compose --env-file ../.env ps
docker compose --env-file ../.env logs api postgres caddy
curl http://127.0.0.1:3010/health
```

Errores habituales: `DATABASE_URL` con `localhost` dentro del contenedor `api` (el host es `postgres`); pelear por el puerto 80 con Nginx Proxy Manager; `DEV_AUTH=false` sin Firebase.
