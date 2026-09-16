# DishToday — estado del MVP y siguiente paso en Hetzner

Documento de continuidad: qué está hecho, cómo está montado y **qué hacer al clonar este repo en el VPS**. Léelo en orden la primera vez; después usa la checklist del final.

Fecha de este corte: 16 septiembre 2026. Producto: **DishToday** (plan en [Plan de App.md](Plan%20de%20App.md)). Alcance entregado: **Fase 1 / MVP**.

---

## 1. Qué es el producto

App social de cocina casera cuya propuesta de valor es: **¿qué puedo cocinar con lo que tengo en la despensa?**

El usuario carga ingredientes, ve recetas ordenadas por coincidencia, abre una ficha con ingredientes faltantes, publica recetas con foto y puede dar like, comentar y guardar.

Fuera de este MVP (Fases 2–3 del plan): planificador semanal, macros avanzados, escáner de barras, lista de compra persistente, IA, Apple Health / Google Fit, freemium, rachas y badges.

---

## 2. Qué está hecho

### Backend (NestJS) — `backend/`

API lista y verificada en local (SQLite de demo). Endpoints:

| Método | Ruta | Qué hace |
| --- | --- | --- |
| GET | `/health` | Salud (público) |
| POST | `/auth/sync` | Crea/actualiza usuario tras login |
| GET / PATCH | `/me` | Perfil |
| PATCH | `/me/preferences` | Alergias y dietas |
| GET | `/ingredients?q=` | Catálogo / autocomplete |
| GET POST PATCH DELETE | `/pantry` | Despensa |
| GET | `/recipes/suggested` | Ranking por `%` de coincidencia |
| GET | `/recipes/search?q=` | Búsqueda (`fromPantry=true` reordena) |
| GET | `/recipes/:id` | Ficha + `matchPct` + `missingIngredients` |
| POST | `/recipes` | Publicar |
| POST | `/recipes/:id/photo` | Subir foto |
| GET | `/feed` | Feed paginado (caché Redis 30s si hay Redis) |
| GET | `/me/recipes` `/me/saved` | Recetas propias y guardadas |
| POST / DELETE | `/recipes/:id/likes` | Me gusta |
| POST / DELETE | `/recipes/:id/saves` | Guardar |
| GET / POST | `/recipes/:id/comments` | Comentarios |

Auth:

- Producción prevista: **Firebase Auth**. El backend verifica el ID token (`FIREBASE_PROJECT_ID` + `FIREBASE_SERVICE_ACCOUNT`).
- Desarrollo: `DEV_AUTH=true` acepta `Authorization: Bearer dev:email@dominio`. **Hay que apagarlo en Hetzner.**

Matching: se calcula en código (`backend/src/recipes/compute-match.ts`) sobre los ingredientes no opcionales vs la despensa. Typesense es solo búsqueda/autocomplete; si no está, hay fallback SQL.

Seed automático (`SEED_ON_START=true`): **57 ingredientes** y **10 recetas** de ejemplo. Solo corre si la tabla de ingredientes está vacía.

Verificación local ya hecha con despensa (huevos, tomate, aceite, cebolla, sal, pan, ajo):

- 100% Pan con tomate
- 80% Tortilla de patatas (falta patata)
- 66.7% Gazpacho (faltan pepino y pimiento)

Comandos útiles:

```bash
cd backend
npm test              # tests unitarios de matching
npm run verify:flow   # seed + despensa + ranking + like/comentario/guardar
npm run start:dev     # API en :3000 (usa .env)
```

### Infra — `infra/`

Docker Compose con:

- PostgreSQL 16
- Redis 7
- Typesense 27.1
- MinIO (fotos S3-compatible) + script que crea el bucket `dishtoday`
- API (build del `backend/Dockerfile`)
- Caddy como reverse proxy en **puerto 80** (hoy sin dominio; HTTPS automático cuando haya DNS)

### App Flutter — `mobile/`

Pantallas del MVP: splash, login, onboarding, feed tipo grid, despensa, sugeridas (“con lo que tengo”), ficha de receta, publicar, perfil.

**Pendiente de generar en la máquina que tenga Flutter:** las carpetas nativas. El código Dart está, pero no se ejecutó `flutter create` en el PC de desarrollo (no había SDK).

Demo login activo por defecto (`USE_DEV_AUTH=true`): email `demo@dishtoday.app`.

### Lo que no está hecho (no sorprenderse al clonar)

- Firebase (proyecto, `google-services.json`, Apple Sign-In).
- Carpetas `android/` e `ios/` de Flutter.
- Dominio, TLS y contraseñas reales.
- Migraciones TypeORM formales (`DB_SYNC=true` solo vale para el primer arranque).
- Lista de compras persistente, pagos, IA, planificador.
- Tests e2e de Jest contra Nest (el paquete `@nestjs/config` es ESM; se usa `npm run verify:flow` en su lugar).

---

## 3. Estructura del repo

```
app-recetas/
  Plan de App.md              # visión de producto
  README.md                   # arranque rápido
  CONTINUAR-EN-HETZNER.md     # este archivo
  .env.example                # plantilla de variables
  infra/
    docker-compose.yml
    Caddyfile
    minio-init.sh
  backend/                    # NestJS
  mobile/                     # Flutter (solo lib/ + pubspec)
```

---

## 4. Siguiente paso: clonar y levantar en Hetzner

Supuesto: VPS Ubuntu (Hetzner Cloud), acceso SSH, dominio opcional apuntando a la IP.

### 4.1 Sistema

```bash
sudo apt update && sudo apt install -y git curl ca-certificates
# Docker: https://docs.docker.com/engine/install/ubuntu/
sudo usermod -aG docker $USER
# cierra sesión SSH y vuelve a entrar
docker compose version
```

Abre en el firewall de Hetzner (y/o UFW) los puertos **22, 80 y 443**. No hace falta exponer 3000, 5432, 6379, 8108 ni 9000 a internet: Compose ya los publica en localhost del VPS; Caddy es la puerta pública. Si quieres endurecer, en `infra/docker-compose.yml` quita los `ports` de postgres/redis/typesense/minio y déjalos solo en la red interna.

### 4.2 Clonar

```bash
cd /opt   # o $HOME
git clone <URL_DEL_REPO> app-recetas
cd app-recetas
```

### 4.3 Variables de entorno

```bash
cp .env.example .env
nano .env
```

Valores **mínimos para el primer arranque en el VPS**:

```env
NODE_ENV=production
PORT=3000
DB_TYPE=postgres
DB_SYNC=true
SEED_ON_START=true

# Auth de desarrollo: SOLO el primer smoke test. Luego false.
DEV_AUTH=true
FIREBASE_PROJECT_ID=
FIREBASE_SERVICE_ACCOUNT=

# Compose pisa hostnames (postgres, redis, typesense, minio).
# Estas URLs de localhost sirven si algún día corres la API fuera de Docker.
DATABASE_URL=postgres://dishtoday:REDACTED@postgres:5432/dishtoday
REDIS_URL=redis://redis:6379
TYPESENSE_HOST=typesense
TYPESENSE_PORT=8108
TYPESENSE_PROTOCOL=http
TYPESENSE_API_KEY=CAMBIA_ESTA_CLAVE
MINIO_ENDPOINT=minio
MINIO_PORT=9000
MINIO_USE_SSL=false
MINIO_ACCESS_KEY=minio
MINIO_SECRET_KEY=CAMBIA_ESTA_CLAVE_MINIO
MINIO_BUCKET=dishtoday

# URL pública con la que la app y las fotos se ven desde fuera
PUBLIC_BASE_URL=http://TU_IP_O_DOMINIO
```

Cambia ya las claves de Typesense y MinIO. El usuario/clave de Postgres están en `infra/docker-compose.yml` (`dishtoday` / `dishtoday`): **cámbialos antes de un entorno real** (compose + `DATABASE_URL` a la vez).

Si cambias `TYPESENSE_API_KEY`, usa la misma en `.env` y al levantar:

```bash
export TYPESENSE_API_KEY=CAMBIA_ESTA_CLAVE
```

### 4.4 Caddy y dominio

Hoy `infra/Caddyfile` escucha en `:80` sin TLS:

```
:80 {
	encode gzip
	reverse_proxy api:3000
}
```

Cuando el dominio (ej. `api.dishtoday.app`) apunte a la IP del VPS, sustitúyelo por:

```
api.dishtoday.app {
	encode gzip
	reverse_proxy api:3000
}
```

Caddy sacará el certificado Let’s Encrypt solo. Pon `PUBLIC_BASE_URL=https://api.dishtoday.app`.

### 4.5 Levantar

```bash
cd /opt/app-recetas/infra
docker compose up --build -d
docker compose ps
docker compose logs -f api
```

Prueba:

```bash
curl http://localhost/health
# o desde fuera:
curl http://TU_IP/health

curl -H "Authorization: Bearer dev:demo@dishtoday.app" http://TU_IP/auth/sync
curl -H "Authorization: Bearer dev:demo@dishtoday.app" http://TU_IP/recipes/suggested
```

Si `/health` responde `{ "ok": true, "service": "dishtoday-api" }`, el backend en Hetzner está vivo.

Después del primer seed correcto, en `.env`:

```env
SEED_ON_START=false
DB_SYNC=false
DEV_AUTH=false
```

Y `docker compose up -d --force-recreate api`. **No dejes `DEV_AUTH=true` ni `DB_SYNC=true` en producción.**

---

## 5. Después de que la API esté arriba

Orden recomendado; no hace falta hacerlo todo el mismo día.

### Paso A — Firebase Auth (imprescindible para app real)

1. Crea un proyecto en Firebase (Authentication: email, Google, Apple).
2. Genera una cuenta de servicio y pega el JSON en `FIREBASE_SERVICE_ACCOUNT` (una línea) o monta el archivo y usa Application Default Credentials.
3. `FIREBASE_PROJECT_ID=tu-proyecto`.
4. En Flutter: FlutterFire / `google-services.json` + `GoogleService-Info.plist`.
5. Compila la app con auth real:

```bash
flutter run --dart-define=USE_DEV_AUTH=false --dart-define=API_BASE_URL=https://api.dishtoday.app
```

Apple Sign-In es obligatorio en iOS si ofreces Google. Hace falta cuenta de Apple Developer.

### Paso B — Generar el proyecto nativo Flutter

En un PC/Mac con Flutter SDK (puede ser local, no el VPS):

```bash
cd mobile
flutter create . --project-name dishtoday --org app.dishtoday
flutter pub get
```

Apunta la API al VPS:

```bash
flutter run --dart-define=API_BASE_URL=https://api.dishtoday.app
```

Sin `--dart-define`, Android emulador usa `http://10.0.2.2:3000` y el resto `http://127.0.0.1:3000` (solo sirve en local).

### Paso C — Endurecer el VPS

- Contraseñas distintas en Postgres, MinIO y Typesense.
- `DEV_AUTH=false`.
- No publicar 5432/6379/9000/8108 a internet.
- Backups: volumen `postgres_data` y `minio_data` (`docker compose` volumes).
- Cuando el esquema esté estable, pasar de `synchronize` a migraciones TypeORM.

### Paso D — Contenido

El seed son 10 recetas de prueba. El plan pide 500–1000 recetas abiertas antes de lanzar: eso es trabajo de datos (CSV/SQL hacia `ingredients` + `recipes`), no de arquitectura. El esquema ya lo admite.

### Paso E — Producto (cuando el MVP esté en el aire)

Según [Plan de App.md](Plan%20de%20App.md):

- Fase 2: filtros nutricionales, lista de compras, escáner de barras.
- Fase 3: recomendaciones IA, Health/Fit.

---

## 6. Mapa rápido de código

| Quieres tocar… | Archivo |
| --- | --- |
| Matching despensa ↔ receta | `backend/src/recipes/compute-match.ts` |
| Seed ingredientes/recetas | `backend/src/seed/seed-data.ts` |
| Auth token / demo | `backend/src/auth/auth.guard.ts` |
| Feed + Redis | `backend/src/recipes/recipes.service.ts` |
| Typesense | `backend/src/search/search.service.ts` |
| Fotos MinIO o disco | `backend/src/storage/storage.service.ts` |
| URL de la API en el móvil | `mobile/lib/config.dart` |
| Compose / servicios | `infra/docker-compose.yml` |
| TLS / dominio | `infra/Caddyfile` |

---

## 7. Checklist al llegar al VPS

1. Instalar Docker + Compose.
2. `git clone` de este repo.
3. Copiar `.env.example` → `.env` y poner `PUBLIC_BASE_URL`, claves nuevas, `DB_TYPE=postgres`.
4. `cd infra && docker compose up --build -d`.
5. `curl /health` y un `POST /auth/sync` con `Bearer dev:…`.
6. Apuntar dominio y cambiar el Caddyfile a HTTPS.
7. `DEV_AUTH=false` + Firebase.
8. En un equipo con Flutter: `flutter create .` dentro de `mobile/` y `--dart-define=API_BASE_URL=...`.
9. Cambiar secretos por defecto y cerrar puertos internos.

Si algo falla al levantar: `docker compose logs api postgres caddy` desde `infra/`. El error más habitual es `.env` con `DB_TYPE=sqlite` o `DATABASE_URL` apuntando a `localhost` **dentro** del contenedor `api` (ahí el host de Postgres se llama `postgres`, no `localhost`).
