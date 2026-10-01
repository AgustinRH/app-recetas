# DishToday — cliente Flutter

Cliente web y móvil. Riverpod para el estado, Dio para la API, go_router para la navegación.

## Configuración

| Variable | Por defecto en código | Qué hace |
| --- | --- | --- |
| `API_BASE_URL` | ver `lib/config.dart` | URL de la API NestJS |
| `USE_DEV_AUTH` | `true` | Login demo con `Bearer dev:<email>`. En producción es `false` |

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3010 --dart-define=USE_DEV_AUTH=true
```

Emulador Android contra una API en el host: `--dart-define=API_BASE_URL=http://10.0.2.2:3010`.

La web pública se compila así:

```bash
docker run --rm -v "$PWD":/work -w /work -e PUB_CACHE=/work/.pub-cache \
  ghcr.io/cirruslabs/flutter:stable \
  bash -c 'git config --global --add safe.directory "*" && flutter pub get && flutter build web --release --dart-define=API_BASE_URL=https://api.dishtoday.eu --dart-define=USE_DEV_AUTH=false'
rm -rf .pub-cache
```

`build/web` no se versiona. Firebase en web usa `lib/firebase_options.dart`. Android e iOS necesitan sus archivos de Firebase, que no están en el repo.

## Estructura

- `lib/config.dart` — URL de la API y flag de auth.
- `lib/firebase_options.dart` — configuración web de Firebase.
- `lib/api_client.dart` — llamadas HTTP.
- `lib/providers.dart` — auth, despensa y feed.
- `lib/screens/` — login, onboarding, feed, despensa, búsqueda, publicar, perfil y ficha.
- `lib/models.dart` — DTOs de la API.
