# CampusPulse - foundation

## Setup
```bash
flutter create campuspulse --org com.campuspulse --platforms android,ios
# copy lib/, env/, assets/, pubspec.yaml, README.md over the generated project
rm test/widget_test.dart
flutter pub get          # then `flutter pub upgrade --major-versions` if you want latest versions
flutter run --dart-define-from-file=env/dev.json
```
Requires Flutter 3.27+ (uses `Color.withValues` and `Column.spacing`).
Mock mode (`USE_MOCK=true`) runs everything without the Node.js backend.
Production: `flutter build apk --dart-define-from-file=env/prod.json`.

## Expected backend contract (to implement in Node.js)
- POST /auth/login, /auth/register -> { user, accessToken, refreshToken }
- POST /auth/refresh {refreshToken} -> { accessToken, refreshToken? }
- POST /auth/forgot-password {email}
- POST /auth/verify-email {code} -> { user }
- GET  /users/me -> user
- Errors: JSON { "message": "..." } with proper HTTP status (400/401/422/500)
