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

## Backend
The Node.js API lives in [`backend/`](backend/README.md) (Express + TypeScript + MongoDB).
It implements the auth contract the app uses:
- POST /auth/login {identifier, password} -> { user, accessToken, refreshToken }
  (`identifier` is the student's ENT ID, e.g. `211JMT0428`, or their email)
- POST /auth/register {displayName, email, password} -> { user, accessToken, refreshToken }
- POST /auth/refresh {refreshToken} -> { accessToken, refreshToken }
- POST /auth/forgot-password {email}
- POST /auth/verify-email {code} -> { user }
- GET  /users/me -> user
- Errors: JSON { "message": "..." } with proper HTTP status (400/401/409/422/500)

To sign in against it: start it (`cd backend && npm run dev`, see its README), then run the app
with `--dart-define-from-file=env/local.json` (VS Code: "CampusPulse (local backend)").
