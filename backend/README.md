# CampusPulse API

REST API for the CampusPulse app: Express 5 + TypeScript, MongoDB (Mongoose), Zod validation, JWT auth.

## Run it

Requirements: Node 20+ and a MongoDB on `localhost:27017`. If you don't have one, `docker compose up -d` starts it.

```bash
cd backend
npm install
cp .env.example .env      # then put a long random value in JWT_ACCESS_SECRET
npm run seed              # creates the demo student (below)
npm run dev               # http://127.0.0.1:3000/api, restarts on file changes
```

Demo student: ENT ID `211JMT0428` (or email `dony.mansour@campus.test`), password `CampusPulse2026!`.

## Use it from the app

Start the API, then run the app with `env/local.json` (`USE_MOCK=false`): in VS Code, pick the **CampusPulse (local backend)** launch configuration.

- **Emulator:** it reaches the PC as `10.0.2.2`, which `env/local.json` already uses.
- **Real phone on the same Wi-Fi:** set `HOST=0.0.0.0` in `.env` and put the PC's IP address in `API_BASE_URL`.

Only sign-in talks to the API for now. Every other screen still uses mock data.

## Scripts

| Command | What it does |
|---|---|
| `npm run dev` | Start in watch mode (tsx) |
| `npm test` | Jest + Supertest. Each worker uses its own `campuspulse_test_<n>` database on the local MongoDB, or `MONGO_URL_TEST` if set |
| `npm run typecheck` | Type-check src and tests |
| `npm run build` / `npm start` | Compile to `dist/` and run it |
| `npm run seed` | Create or reset the demo student |

## Endpoints

Base path: `/api`. Errors are always `{ "message": "..." }` with the right status:

- `400` bad request
- `401` invalid credentials or expired session
- `409` duplicate
- `422` invalid data
- `429` too many attempts
- `500` server error

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/health` | | `{ status: "ok" }` |
| POST | `/auth/register` | `{ displayName, email, password }` | `201 { user, accessToken, refreshToken }` (and emails a 6-digit code) |
| POST | `/auth/login` | `{ identifier, password }`: identifier is the ENT ID or the email | `{ user, accessToken, refreshToken }` |
| POST | `/auth/refresh` | `{ refreshToken }` | `{ accessToken, refreshToken }` (rotated) |
| POST | `/auth/logout` | `{ refreshToken }` | `204` |
| POST | `/auth/forgot-password` | `{ email }` | `200 { message }` (the same whether the account exists or not) |
| POST | `/auth/reset-password` | `{ token, password }` | `200 { message }` |
| POST | `/auth/verify-email` 🔒 | `{ code }` | `{ user }` |
| POST | `/auth/resend-verification` 🔒 | | `204` |
| GET | `/users/me` 🔒 | | `user` |

🔒 = needs `Authorization: Bearer <accessToken>`. A `user` is `{ id, email, studentId, displayName, avatarUrl, isEmailVerified }`.

## Security notes

- **Passwords:** hashed with bcrypt.
- **Access tokens:** JWT (HS256) that expire after 15 minutes by default.
- **Refresh tokens:**
  - random, and stored only as SHA-256 hashes;
  - replaced on every refresh (rotation);
  - reusing an old one ends every session of that user, since it suggests the token was stolen.
- **Email verification codes and reset tokens:** stored hashed, with an expiry. A code is locked after 5 wrong attempts.
- **Login errors:** the same message and similar timing whether the account exists or not.
- **Rate limiting:** on the auth routes (strict in production).

## Not done yet

- **Real email sending:** emails are printed in the server console (`[mail] ...`). See `src/modules/auth/mailer.ts`.
- **Endpoints for the other screens:** timetable, rides, jobs, forum, grades, notifications.
- **App logout:** the app doesn't call `/auth/logout` yet.
