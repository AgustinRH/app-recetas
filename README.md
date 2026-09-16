# DishToday

Plataforma social de cocina casera: **qué puedes cocinar con lo que tienes en la despensa**.

Este repositorio implementa el **MVP (Fase 1)**: registro, despensa, matching de recetas, feed social (publicar, like, comentar, guardar).

Para clonar en el VPS y seguir desde ahí, usa [CONTINUAR-EN-HETZNER.md](CONTINUAR-EN-HETZNER.md).

## Stack

- **Móvil:** Flutter (iOS + Android)
- **API:** NestJS
- **Datos:** PostgreSQL (producción) o SQLite/sql.js (demo local)
- **Caché:** Redis (opcional)
- **Búsqueda:** Typesense (opcional; fallback SQL)
- **Fotos:** MinIO/S3 (opcional; fallback `./uploads`)
- **Auth:** Firebase Auth, o `DEV_AUTH` con `Authorization: Bearer dev:email@dominio`

## Arranque local (sin Docker)

```bash
cd backend
copy ..\.env .env   # Windows
npm install
npm test            # matching unitario
npm run test:e2e    # flujo despensa → sugeridas
npm run start:dev   # API en http://localhost:3000
```

Demo: `GET /health` y `Authorization: Bearer dev:demo@dishtoday.app`.

```bash
curl http://localhost:3000/health
curl -H "Authorization: Bearer dev:demo@dishtoday.app" http://localhost:3000/recipes/suggested
```

## Infra en Hetzner (Docker)

Copia `.env.example` a `.env`, pon `DB_TYPE=postgres` y arranca:

```bash
cd infra
docker compose up --build
```

Caddy publica la API en el puerto 80.

## App Flutter

```bash
cd mobile
flutter create . --project-name dishtoday
flutter pub get
flutter run
```

En debug, `USE_DEV_AUTH` está activo: entra con `demo@dishtoday.app` (el emulador Android usa `http://10.0.2.2:3000`).

Para Google/Apple, configura Firebase (`google-services.json` / `GoogleService-Info.plist`), `FIREBASE_PROJECT_ID` en el backend y compila con `--dart-define=USE_DEV_AUTH=false`.

## API principal

| Método | Ruta | Descripción |
| --- | --- | --- |
| POST | `/auth/sync` | Upsert de perfil tras login |
| GET/PATCH | `/me` | Perfil |
| PATCH | `/me/preferences` | Alergias y dietas |
| GET | `/ingredients?q=` | Autocomplete |
| GET/POST/PATCH/DELETE | `/pantry` | Despensa |
| GET | `/recipes/suggested` | Ranking por coincidencia |
| GET | `/recipes/:id` | Ficha + `matchPct` + faltantes |
| POST | `/recipes` | Publicar |
| POST | `/recipes/:id/photo` | Foto |
| GET | `/feed` | Feed paginado |
| POST/DELETE | `/recipes/:id/likes` | Me gusta |
| POST/DELETE | `/recipes/:id/saves` | Guardar |
| GET/POST | `/recipes/:id/comments` | Comentarios |
