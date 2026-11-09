# CampusPulse API

REST API for the CampusPulse app: Express 5 + TypeScript, MongoDB (Mongoose), Zod validation, JWT auth.

- **Endpoints, with request and response examples:** [docs/api.md](../docs/api.md)
- **How the backend is built** (modules, request life cycle, auth design): [docs/architecture.md § 4](../docs/architecture.md#4-the-backend-api)
- **Common problems:** [docs/troubleshooting.md](../docs/troubleshooting.md#backend)

## Run it

Requirements: Node 20+ and a MongoDB on `localhost:27017`. If you don't have one, `docker compose up -d` starts it.

```bash
cd backend
npm install
cp .env.example .env      # then put a long random value in JWT_ACCESS_SECRET
npm run seed              # demo student + demo data for every screen
npm run dev               # http://127.0.0.1:3000/api, restarts on file changes
```

Demo student: ENT ID `211JMT0428` (or email `dony.mansour@campus.test`), password `CampusPulse2026!`.
Demo admin: `admin@campus.test`, password `CampusPulseAdmin2026!`.

Run the app with `env/local.json` (VS Code: **CampusPulse (local backend)**) to use this API. With `env/dev.json` the app uses its built-in demo data and needs no server.

## Scripts

| Command | What it does |
|---|---|
| `npm run dev` | Start in watch mode (tsx) |
| `npm run seed` | Create or reset the demo student and every module's demo data, the demo admin and a few demo accounts (idempotent). Re-run it to refresh dates like "today 13:15" |
| `npm run create-admin -- <email> <password> [display name]` | On a real server: create an admin, or promote an existing account (new password, signed out everywhere) |
| `npm run push:test -- <email or ENT ID>` | Add a "Push test" notification to that account and push it to its phones. Prints how many phones got it, and says so when push is off or the account has no registered phone |
| `npm test` | Jest + Supertest on a throwaway `campuspulse_test_<n>` database. Set `TEST_DB_PREFIX` to keep simultaneous runs apart |
| `npm run typecheck` | Type-check src and tests |
| `npm run build` / `npm start` | Compile to `dist/` and run it |

## Layout

```text
src/
├── server.ts / app.ts        start-up · Express app (security middleware, /api routers, error handler)
├── config/env.ts             .env validated with Zod
├── lib/ · middleware/        HttpError, validateBody, requireAuth, requireRole, rate limit, error handler
├── modules/<name>/           routes · schemas · service · model · seed (one folder per feature)
└── scripts/                  seed.ts (npm run seed) · create-admin.ts (npm run create-admin) · push-test.ts (npm run push:test)
```

The modules are auth, users, timetable, courses, carpool, jobs, forum, grades, profile, notifications, push (the phones that get push notifications) and admin (user management and audit log, admins only).

## Settings

Every setting is documented in [`.env.example`](.env.example). The main ones are:

- `JWT_ACCESS_SECRET`, which is required.
- `MONGO_URL`.
- `HOST` and `PORT`. Use `HOST=0.0.0.0` for real phones on your Wi-Fi.
- `SMTP_*`, for real emails. Without `SMTP_HOST`, verification and reset codes are printed in the console as `[mail] …`.
- `FIREBASE_SERVICE_ACCOUNT_FILE`, for push notifications: the path (relative paths start in `backend/`) of a service account key from the Firebase console (**Project settings › Service accounts › Generate new private key**). The key is a secret: keep it out of git (`.gitignore` skips `*firebase-adminsdk*.json`). At start-up the console says `[push] On: …`, or `[push] Off: …` with the reason. When it is off, phones are still registered but nothing is sent.

## Known limitation

The grading rules exist twice: in `src/modules/grades/grading.ts` and in the app's `lib/features/grades/domain/grading.dart`. Change both together.
