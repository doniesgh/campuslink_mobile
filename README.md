# CampusPulse

A campus companion app for ESPRIT students:
- timetable and courses
- carpooling ("covoiturage")
- lost & found and ideas
- internships and jobs
- grades
- a digital student ID
- notifications

The **Flutter app** works on demo data out of the box. With the **Node.js API** in [`backend/`](backend/), it works on real data stored in MongoDB.

| | |
|---|---|
| **App** | Flutter 3.27+ · Riverpod · go_router · Dio · feature-first Clean Architecture |
| **API** | Node.js 20+ · Express 5 · TypeScript · MongoDB (Mongoose) · Zod · JWT |
| **Design** | Google Stitch ("CampusPulse Student Companion Mobile App"), 12 screens |
| **Tests** | 452 app tests · 261 API tests |

## Quick start (5 minutes, no server)

```bash
git clone https://github.com/doniesgh/campuslink_mobile.git
cd campuslink_mobile
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

Sign in with any ENT ID and password. Every screen runs on built-in demo data. In VS Code, just press **F5** with **"CampusPulse (dev, mock data)"**.

## With the real API

```bash
cd backend
npm install
cp .env.example .env          # then set JWT_ACCESS_SECRET to a long random string
npm run seed                  # demo student + demo data (needs MongoDB on localhost:27017)
npm run dev                   # http://127.0.0.1:3000/api
```

Then run the app with `env/local.json` (VS Code: **"CampusPulse (local backend)"**) and sign in as the demo student, **`211JMT0428`** / **`CampusPulse2026!`**.

Full setup, including the Android emulator on Windows and MongoDB: **[docs/getting-started.md](docs/getting-started.md)**.

## Project structure

```text
campuslink_mobile/
├── lib/                Flutter app
│   ├── core/               config, errors, network (Dio + auth), router, theme, storage, utils
│   ├── shared/widgets/     reusable UI components
│   └── features/<name>/    one folder per feature, each split into
│                           domain/ (entities, interfaces) · data/ (mock + API repositories)
│                           · presentation/ (pages, widgets, providers)
├── test/               app tests (mirrors lib/)
├── backend/            Node.js API
│   └── src/modules/<name>/   one folder per feature: routes · schemas · service · model · seed
├── env/                dev.json (demo data) · local.json (local API) · prod.json
└── docs/               documentation
```

How it all fits together, the patterns used and why: **[docs/architecture.md](docs/architecture.md)**.

## Documentation

| Document | Read it to… |
|---|---|
| [Getting started](docs/getting-started.md) | set up your machine and run the app and the API |
| [Architecture](docs/architecture.md) | understand the structure, the layers, state, navigation, auth and the backend design |
| [Features](docs/features.md) | see what each screen does, where its code is and which endpoints it uses |
| [API reference](docs/api.md) | call the API: every endpoint with request and response examples |
| [Contributing](docs/contributing.md) | follow our conventions, add a feature end to end, write tests |
| [Troubleshooting](docs/troubleshooting.md) | fix the problems we already ran into |
| [Backend README](backend/README.md) | backend scripts and settings at a glance |

## Status

All 12 designed screens are built and connected to the API, including:
- publishing rides, lost & found notices and ideas
- password reset by email code
- real email sending over SMTP

Still to do (shown as "coming soon" in the app): university SSO, messaging, the NFC pass, calendar sync, video streaming and the Forum's *Experiences* section. The full list is in [features.md](docs/features.md#coming-soon-not-built-yet).
