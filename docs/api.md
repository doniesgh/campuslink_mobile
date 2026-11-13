# API reference

The CampusPulse REST API (`backend/`).

- To run it, see [getting-started.md](getting-started.md#4-run-the-backend).
- To see how it is built, see [architecture.md](architecture.md#4-the-backend-api).

**Base URL:**
- `http://127.0.0.1:3000/api` from your PC.
- `http://10.0.2.2:3000/api` from the Android emulator.

The **exact JSON** of every response is pinned by the app's contract tests. They are real backend responses saved in `test/features/<feature>/` (e.g. `carpool_fixtures.dart`, `fixtures/courses.json`). When this page and a fixture disagree, the fixture is right.

- [Conventions](#conventions)
- [Auth](#auth) · [Users](#users) · [Timetable](#timetable) · [Courses](#courses) · [Carpool](#carpool)
- [Jobs](#jobs) · [Forum](#forum) · [Grades](#grades) · [Profile](#profile) · [Notifications](#notifications) · [Push](#push)
- [Admin](#admin): user management, the timetable and the audit log

---

## Conventions

**Authentication.** Every route except `/health` and `/auth/*` needs:

```http
Authorization: Bearer <accessToken>
```

Access tokens last 15 minutes. On a `401`, call `POST /auth/refresh` with the refresh token; the app does this automatically.

**Errors** are always JSON with a message written for students, and sometimes a machine-readable `code` and extra fields:

```json
{ "message": "This seat is no longer available." }
{ "message": "Use at least 8 characters", "code": "VALIDATION_ERROR" }
{ "message": "Too many attempts. Try again in a few minutes.", "code": "TOO_MANY_REQUESTS", "retryAfter": 873 }
```

The app shows `message` as it is, or translates a `code` it knows (`failureText` in `lib/core/error/failure_text.dart`). Old app builds ignore `code`.

| Status | When |
|---|---|
| 400 | Bad request: wrong or expired code, malformed JSON |
| 401 | Not signed in, wrong credentials, or expired session |
| 403 | Signed in, but not allowed: an `/admin` route used by someone who isn't an admin, or the timetable or courses used by an admin, alumni or company |
| 404 | Unknown id (`"Job not found."`), or a route that doesn't exist |
| 409 | Conflict: seat taken, already applied, booking your own ride… |
| 422 | Invalid data. The message names the first problem (`"Use at least 8 characters"`). A body or query refused by its schema has `code: "VALIDATION_ERROR"` |
| 429 | Too many requests (see **Rate limits** below): `code: "TOO_MANY_REQUESTS"`, `retryAfter` in seconds and a `Retry-After` header |
| 500 | Server error (`"Something went wrong. Please try again."`) |
| 502, 503 | An AI feature could not answer (see **AI** below) |

**Error codes** (`code`, optional):

| Code | Status | When |
|---|---|---|
| `VALIDATION_ERROR` | 422 | A body or query refused by its schema (`validateBody`, `parseQuery`) |
| `TOO_MANY_REQUESTS` | 429 | A rate limit was hit. `retryAfter`: seconds to wait |
| `AI_UNAVAILABLE` | 503 | AI is off on this server (no `OPENROUTER_API_KEY`), or the key is refused |
| `AI_NO_CREDITS` | 503 | The OpenRouter account has no credits left |
| `AI_BUSY` | 429 | Every AI model is busy or out of its daily quota |
| `AI_FAILED` | 502 | The AI service is unreachable, too slow, or answered something that isn't JSON |
| `TIMETABLE_CONFLICT` | 409 | A class of the timetable clashes with others (same room or teacher at overlapping times). `conflicts`: the clashing classes, see [Timetable (admin)](#timetable-admin) |

**Rate limits** (in memory, per API instance; off in tests):

| Routes | Counted per | Limit (production; 5× elsewhere) |
|---|---|---|
| `register`, `login`, `forgot-password`, `reset-password` (each its own counter) | route + IP + email (or `identifier`), lower-cased | 20 per 15 min |
| the same four together | IP (not counted for a loopback caller without a proxy: the emulator, a dev on localhost) | 100 per 15 min |
| `POST /jobs/:id/summary` (cached answers included) | signed-in user | 30 per hour (everywhere) |

`refresh` and `logout` have no limit. Behind Render's proxy (`TRUST_PROXY=1`) the IP is the client's.

**Language.** The app sends `Accept-Language: fr` or `en` on every request. The server writes a user's emails and notifications in their account's `locale` (see [Users](#users)). At sign-up the account's `locale` is the one in the body, else this header, else French.

**AI** (`backend/src/lib/openrouter.ts`). Optional: without `OPENROUTER_API_KEY` every AI feature answers `503 AI_UNAVAILABLE` or falls back to rules. Used by the admin import assist ([Read with AI](#read-with-ai)) and the AI summary of a job offer ([Jobs](#jobs)).

**Data formats:**
- Keys are camelCase, and ids are strings in `id`.
- Enums are sent as Dart enum names.
- Class times are wall-clock (`"date": "2026-11-05", "start": "08:30"`).
- Other dates are ISO-8601 UTC (`"2026-11-05T09:15:00.000Z"`).
- Campus time is Tunis (UTC+1).

---

## Health

| | |
|---|---|
| `GET /health` | `200 { "status": "ok" }` |

## Auth

| Method & path | Body | Success | Errors |
|---|---|---|---|
| `POST /auth/register` | `{ displayName, email, password, locale? }` (password ≥ 8, `locale` `fr`/`en`) | `201` session (below): the new account is signed in, already verified. No email is sent | 409 email taken · 422 · 429 |
| `POST /auth/login` | `{ identifier, password }` | `200` session | 401 `"Invalid ENT ID/email or password."` · 429 |
| `POST /auth/refresh` | `{ refreshToken }` | `200 { accessToken, refreshToken }` (the old one is revoked) | 401 |
| `POST /auth/logout` | `{ refreshToken, pushToken? }` | `204`. With `pushToken`, that phone stops getting [pushes](#push) | 422 (missing `refreshToken`, `pushToken` not text or too long) |
| `POST /auth/forgot-password` | `{ email }` | `200 { message }` + emails a 6-digit code, in the account's language | 429 (same answer for unknown emails) |
| `POST /auth/reset-password` | `{ email, code, password }` | `200 { message }`, signs out everywhere, audit `auth.password_reset` | 400 `"Invalid or expired code…"` · 422 · 429 |

`identifier` is the student's **ENT ID** (`211JMT0428`, any case) **or email**.

**Session** (login and register):

```json
{
  "user": {
    "id": "6aee283c10aef9a35cb4bcc6",
    "email": "dony.mansour@campus.test",
    "studentId": "211JMT0428",
    "displayName": "Dony Mansour",
    "avatarUrl": null,
    "isEmailVerified": true,
    "role": "student",
    "locale": "fr"
  },
  "accessToken": "eyJhbGciOiJIUzI1NiIs…",
  "refreshToken": "1C95PsLEqH…"
}
```

`role` is `student`, `teacher`, `admin`, `alumni` or `company` (a recruiter: a partner company that posts job offers). Sign-up always creates a `student`; only an admin can change a role (see [Admin](#admin)). Students and teachers have classes; admins, alumni and companies don't (403 on the timetable and courses). Old app builds read `company` as `student`.

`locale` is the account's language, `fr` (the default) or `en`: the server writes this user's emails in it (French says "tu"). The app keeps it equal to the language on screen: it sends it at sign-up and, after a sign-in or a change in Profile, `PATCH /users/me` when it differs.

Sign-up needs no email confirmation: `isEmailVerified` is `true` for a new account, and nothing in the API checks it. Admins can still see and change it ([Admin](#admin)).

**Password-reset codes** have 6 digits, are valid for 15 minutes and are locked after 5 wrong tries. Without email settings, the server prints them in its console (`[mail] Password reset code for … (fr): 042917`).

## Users

| Method & path | Body | Success | Errors |
|---|---|---|---|
| `GET /users/me` | — | `200 user` (the same `user` object as above, not wrapped) | 401 |
| `PATCH /users/me` | `{ locale }` (`fr` or `en`, any case) | `200 user`, updated | 401 · 422 (`"Language: choose fr or en"`, `"There's nothing to save."`) |

`PATCH /users/me` changes the signed-in user's own settings. Other fields (`email`, `role`…) are ignored: only an admin changes them.

## Timetable

Only students and teachers have a timetable. Admins, alumni and companies get `403 { "message": "Only students and teachers have a timetable." }`.

| Method & path | Success |
|---|---|
| `GET /timetable/day?date=YYYY-MM-DD` | `{ date, semesterWeek, sessions[] }` (sorted by start time) |
| `GET /timetable/week?date=YYYY-MM-DD` | `{ start (Monday), days[7], semester, classGroup }`: the week containing `date` |

Missing or invalid date → `422 "Pass the date as YYYY-MM-DD"`. A session:

```json
{
  "id": "genie-logiciel-tp-2026-11-2",
  "course": "Génie Logiciel & Architecture",
  "room": "Lab 204",
  "teacher": "Prof. Ben Ali",
  "date": "2026-11-02",
  "start": "10:15",
  "end": "12:15",
  "kind": "lab",
  "lectureNumber": null,
  "lectureCount": null,
  "coefficient": null,
  "notes": null,
  "mode": "onsite",
  "meetUrl": null
}
```

- `kind` is one of `lecture`, `lab`, `exam`, `workshop`. Exams carry a `coefficient` and `notes`.
- `mode` is `onsite` or `online`. An online class has its Google Meet link in `meetUrl` (else `null`), and `room` is `"Online"` when it has no room (older apps show it as is).
- The `id` is `<slot id>-<Y>-<M>-<D>` (one per class and date). Admins edit the classes: see [Timetable (admin)](#timetable-admin).

## Courses

Only students and teachers have courses. Admins, alumni and companies get `403 { "message": "Only students and teachers have courses." }` on every route below.

| Method & path | Body | Success | Errors |
|---|---|---|---|
| `GET /courses` | — | `Course[]` with **your** attendance and submissions | |
| `PUT /courses/:courseId/attendance` | `{ present: boolean }` | `204` | 404 · 422 |
| `POST /courses/resources/:resourceId/download` | — | `{ url }` | 404 · 409 not a document |
| `POST /courses/assignments/:assignmentId/submission` | `{ repoUrl }` (https link to a repository) | `201 { assignmentId, repoUrl, submittedAt }` | 404 · 422 |

A course looks like this (trimmed):

```json
{
  "id": "genie-logiciel",
  "code": "GLA-401",
  "title": "Génie Logiciel & Architecture",
  "professor": { "title": "Prof.", "name": "Ben Ali", "office": "Office Bloc B-114", "email": "benali@campus.edu", "isOnline": true },
  "modules": [{ "number": 1, "title": "Software Engineering Foundations", "hours": 3, "isCompleted": true }],
  "lecturesHeld": 7,
  "lectureCount": 14,
  "nextQuiz": { "topic": "Arch Microservices", "date": "2026-11-09T09:15:00.000Z" },
  "resources": [
    { "type": "document", "id": "gl-lesson-7", "title": "Lesson 7: Microservices & REST APIs", "format": "PDF", "sizeBytes": 4404019, "updatedAt": "…" },
    { "type": "video", "id": "gl-lesson-8", "title": "Lesson 8: Clean Code & SOLID", "durationSeconds": 2700, "quality": "1080p" },
    { "type": "assignment", "id": "gl-lab-3", "title": "Lab 3: Docker Orchestration", "dueAt": "…", "points": 20, "isMandatory": true, "submittedRepoUrl": null }
  ],
  "community": { "onlineCount": 24, "onlineClassmates": ["Yasmine Trabelsi", "…"] },
  "isPresent": true
}
```

Quiz and due dates are computed on each request, relative to today, so the demo never goes stale.

## Carpool

| Method & path | Body | Success | Errors |
|---|---|---|---|
| `GET /carpool/rides` | — | `Ride[]`, soonest first | |
| `GET /carpool/rides/:id` | — | `Ride` | 404 |
| `POST /carpool/rides` | new ride (below) | `201 Ride`. You are the driver; ids `es-4094`, `es-4095`… | 422 (French messages) |
| `POST /carpool/rides/:id/reservations` | `{ seatIds: ["s3"] }` | `201` updated `Ride` | 404 · 409 seat taken or your own ride · 422 |
| `GET /carpool/impact` | — | `{ savedKg, goalKg }` (campus, this month) | |

A `Ride` looks like this:

```json
{
  "id": "es-4091",
  "code": "ES-4091",
  "pickup": "Tunis Centre (Passage)",
  "pickupTag": "Passage",
  "dropoff": "ESPRIT Ghazela (Bloc H)",
  "dropoffTag": "ESPRIT Bloc H",
  "dropoffNote": "Drop-off direct at Bloc H (Ghazela Technopark)",
  "departure": "2026-11-05T12:15:00.000Z",
  "arrival": "2026-11-05T12:45:00.000Z",
  "distanceKm": 14.2,
  "pricePerSeat": 2.5,
  "driver": { "name": "Sarra K.", "rating": 4.9, "profile": "4th Year Telecom Engineering student", "ridesCompleted": 38, "carModel": "Renault Clio 4", "carColor": "White", "plate": "218 · TN · 9812", "isCarVerified": true },
  "seats": [
    { "id": "s1", "label": "Sarra K.", "status": "driver" },
    { "id": "s2", "label": "Ahmed D.", "status": "booked" },
    { "id": "s3", "label": "You", "status": "booked" },
    { "id": "s4", "label": "Seat #4", "status": "free" }
  ],
  "amenities": ["nonSmoking", "airConditioned", "musicOk"],
  "isMine": false
}
```

- **Seat labels** depend on who asks: your seats say "You", other students' bookings show their name, and free seats show "Seat #n".
- **Booking** is all-or-nothing and safe when two students try at once: one gets `201`, the other `409`.
- **New ride body:**
  - `{ pickup, pickupTag, dropoff, dropoffTag, departure, arrival, seatCount (1–4), pricePerSeat (0–50), carModel, carColor, plate, amenities?, dropoffNote?, distanceKm? }`
  - `departure` must be in the future, and `arrival` after `departure`.
  - A new driver has `rating: 0, ridesCompleted: 0`; the app shows "New driver".

## Jobs

Every signed-in user reads offers. **Companies** (role `company`) and **admins** post them; a company edits and deletes its own offers, an admin every offer (the seeded catalogue included).

| Method & path | Who | Success | Errors |
|---|---|---|---|
| `GET /jobs` | anyone | `Job[]`: posted offers first (newest first), then the catalogue, best match first | |
| `GET /jobs/:id` | anyone | `Job` | 404 `"Job not found."` |
| `POST /jobs` | company, admin | `201 Job` | 403 `"Only companies and administrators can post offers."` · 422 |
| `PATCH /jobs/:id` | its author (company), admin | `Job` (only the fields sent change; clears the cached AI summary) | 403 (role, as above) · 403 `"This offer isn't yours."` · 404 · 422 |
| `DELETE /jobs/:id` | its author (company), admin | `204` (its applications are deleted too) | 403 · 404 |
| `POST /jobs/:id/summary` | anyone | `{ summary, keyPoints[], skills[], idealFor, model, cached }` | 404 · 422 `"This offer is too short to summarise."` · 429 · 502 · 503 (see below) |
| `POST /jobs/:id/applications` | students | `201 { jobId, appliedAt }` | 403 `"Only students can apply to offers."` · 404 · 409 `"You already applied to this offer."` |

**Body of `POST /jobs`** (`PATCH`: any of these fields, at least one; `422 "Nothing to update."` otherwise). The app's form checks the same rules (`lib/features/jobs/domain/job_form_rules.dart`); a refused body is a 422 `VALIDATION_ERROR` naming the first problem:

| Field | Rule |
|---|---|
| `title` | required, 3–120 characters |
| `description` | required, 20–5000 characters (stored and sent as `mission` too) |
| `company` | 2–100 characters; default: the author's display name |
| `location` · `period` | at most 100 · 60 characters; default `""` |
| `durationMonths` · `stipendTnd` | whole numbers, 1–36 · 0–100000, or `null` (default) |
| `skills[]` · `tags[]` | at most 15 · 6 labels of 40 characters; trimmed, blanks and duplicates dropped |

```json
{ "title": "Flutter Mobile Intern", "company": "Medina Soft", "location": "Lac 1, Tunis",
  "description": "Build the Flutter app our clients use to book appointments every day.",
  "period": "Feb – Jul 2026", "durationMonths": 6, "stipendTnd": null, "skills": ["Flutter", "Dart"], "tags": ["PFE 2026"] }
```

The `Job` fields are:
- `id` (readable for the catalogue, e.g. `"instadeep-ml"`; an ObjectId string for posted offers), `featuredLabel`, `title`, `company`, `location`, `tags[]`
- `stipendTnd`, `durationMonths`, `period`
- `labGroup`, `labGroupNote`, `workspaceTitle`, `workspaceBadges[]`
- `mission` and `description` (the same text), `missionItems[{ title, description }]`
- `matchPercent`, `criteria[]`, `skills[]`
- **`hasApplied`**, for the signed-in student.
- **`authorId`**: the company or admin who posted it, `null` for the seeded catalogue.
- **`canEdit`**: whether the signed-in user may edit and delete it (its author, or an admin).

Posted offers only have what the form asks for: `stipendTnd`, `durationMonths`, `matchPercent`, `labGroup`, `labGroupNote` and `workspaceTitle` are `null`, `location` and `period` may be `""`, and the lists may be empty. The app hides what is missing.

**AI summary** (`POST /jobs/:id/summary`, no body), a port of the PWA's offer summary: 2–3 sentences, 3–5 key points, the skills asked for and the student it suits, written in the user's `locale` (French or English). The offer text is sent as data, never as instructions.

```json
{ "summary": "A 6-month research internship in reinforcement learning at InstaDeep, in Tunis.",
  "keyPoints": ["Benchmark new RL exploration strategies", "Work with the London research team"],
  "skills": ["PyTorch", "JAX"], "idealFor": "A 5th-year student who enjoys research and Python.",
  "model": "anthropic/claude-haiku-5.5", "cached": false }
```

- **Cached** on the offer, per language, until the offer is edited (`cached: true`, no AI call).
- **Limit:** 30 calls per user and hour (cached ones included): then `429 TOO_MANY_REQUESTS` `"Too many summaries. Try again later."` with `retryAfter`.
- **Errors of the AI** (see **AI** above): `503 AI_UNAVAILABLE` (no `OPENROUTER_API_KEY`: there is no fallback summary), `503 AI_NO_CREDITS`, `429 AI_BUSY`, `502 AI_FAILED` (also for an answer without a summary). The app explains each one.
- `422` when the description (with its mission items and criteria) has fewer than 80 characters.

## Forum

| Method & path | Body | Success | Errors |
|---|---|---|---|
| `GET /forum/highlights` | — | `ForumPost[]`, newest first (Home feed) | |
| `GET /forum/lost-items` | — | `LostItem[]`, newest first (resolved ones included) | |
| `POST /forum/lost-items` | notice (below) | `201 LostItem` with a reference `LF-412`, `LF-413`… | 422 (French messages) |
| `PATCH /forum/lost-items/:id` | notice fields and/or `status` (below) | `LostItem`, edited | 403 not its reporter nor an admin · 404 · 422 |
| `DELETE /forum/lost-items/:id` | — | `204` (the requests about it are deleted too) | 403 · 404 |
| `GET /forum/lost-items/:id/matches` | — | possible matches (below) | 404 |
| `POST /forum/lost-items/:id/requests` | `{ proof }` | `201 { id, itemId, proof, createdAt }` | 404 · 409 already asked, or the notice is resolved · 422 |
| `GET /forum/ideas` | — | idea `ForumPost[]`, most upvoted first | |
| `POST /forum/ideas` | `{ body (10–500 chars), tag? }` | `201 ForumPost` | 422 |
| `POST /forum/ideas/:id/upvote` | — | `{ upvotes, isUpvotedByMe }` (toggles your vote) | 404 |

**`ForumPost`:**

```json
{
  "id": "post-3",
  "authorName": "Amina T.",
  "authorInfo": "4A - Data Science",
  "category": "idea",
  "tag": "Proposition",
  "body": "Installation de bornes de recharge rapide…",
  "place": null,
  "upvotes": 42,
  "comments": 8,
  "status": "En examen BDE",
  "postedAt": "2026-11-05T08:00:00.000Z",
  "isUpvotedByMe": false
}
```

`category` is `carpool`, `lostFound` or `idea`.

**`LostItem`:**

```json
{
  "id": "lf-409",
  "kind": "found",
  "title": "Calculatrice TI-84 Plus CE",
  "category": "calculator",
  "zone": "Bloc C",
  "location": "Salle C12 (Ghazela)",
  "place": "classroom",
  "reporterName": "Youssef M.",
  "reporterIsStaff": false,
  "reportedAt": "2026-11-06T12:15:00.000Z",
  "reference": "TF-409",
  "photoCount": 1,
  "isUrgent": false,
  "reward": null,
  "distinctiveDetail": null,
  "dropOffNote": "Déposé à l'accueil Bloc C",
  "pickupDesk": "Accueil Bloc C - Salle C12",
  "isSerialHidden": false,
  "status": "active",
  "reporterId": null,
  "isMine": false,
  "canManage": false
}
```

- `status` is `active` or `resolved` (the object went back to its owner: still listed, never matched, no new requests).
- `reporterId` is the reporter's account id, or `null` for the demo and desk notices.
- `isMine` (you reported it) and `canManage` (you may edit, resolve or delete it: its reporter, or an admin) are the signed-in user's.

**New notice body:**
- `{ kind, title, category, zone, location, place, distinctiveDetail?, reward?, isUrgent?, dropOffNote?, pickupDesk? }`.
- `kind` is `lost` or `found`.
- `category` is one of `calculator`, `keys`, `audio`, `bag`, `card`, `bottle`, `other`.
- `place` is one of `classroom`, `parking`, `library`, `cafeteria`, `other`.
- A found item needs a `dropOffNote` or a `pickupDesk`. `reward` and `isUrgent` are for lost items only.

**Editing a notice** (`PATCH /forum/lost-items/:id`, its reporter or an admin):
- Any field of the new notice body, and/or `status` (`active` or `resolved`). At least one field (else 422 `"Rien à modifier : envoyez au moins un champ."`).
- A field sent replaces the stored one, `null` clears an optional field, a field left out is kept. The notice is then checked whole, with the messages of a new notice.
- Switching `kind` drops the other kind's fields (`reward`/`isUrgent`, or `dropOffNote`/`pickupDesk`): a lost item turned found needs a `pickupDesk`.
- 403 `"Seul l'auteur de l'annonce (ou un administrateur) peut la modifier ou la supprimer."`, 404 `"Cette annonce n'existe plus."` (also for `DELETE` and `/matches`).

**Possible matches** (`GET /forum/lost-items/:id/matches`, any signed-in user), a port of the PWA's lost & found matching:

```json
{
  "items": [
    {
      "item": { "id": "lf-409", "kind": "found", "...": "a LostItem" },
      "score": 90,
      "reason": "Même modèle TI-84, trouvée au Bloc C le lendemain.",
      "reasons": ["Même catégorie", "1 jour d'écart", "Lieu proche", "Description proche"],
      "ai": true
    }
  ],
  "ai": true,
  "model": "anthropic/claude-haiku-4.5"
}
```

- **Candidates:** active notices of the other kind (lost ↔ found), the 200 newest. A resolved notice has no matches.
- **Rules** (0–100): +40 same `category` (+20 when both are `other`); +25 the same day down to 0 at 14 days apart (more than 30 days apart: never a match); +20 × shared place words (`zone` + `location`), at least +10 for the same `place`; +15 × shared words of `title` + `distinctiveDetail`. Words: lowercase, no accents, longer than 2 letters. `reasons` are the rules that matched, in the user's `locale` (French or English); without AI, `reason` joins them.
- **AI** (when `OPENROUTER_API_KEY` is set, see **AI** above): the 8 best by rules are sent (as data, scrubbed of e-mails and phone numbers) for a 0–100 score and a short reason in the user's language. Score = 0.3 × rules + 0.7 × AI, `reason` = the AI's, `ai: true` on the match and the answer, `model` = the model that answered. 15 s at most, 10 analyses per user and minute, cached 15 minutes. **Any AI error falls back to the rules** (`ai: false`, `model: null`): the route never fails because of the AI.
- Matches under 50 are dropped; the 5 best are sent, best first.

## Grades

| | |
|---|---|
| `GET /grades/transcript` | `{ studentId, semesters[] }`, most recent first; `semesters: []` when no grades are published |

```json
{
  "studentId": "211JMT0428",
  "semesters": [{
    "id": "2025-2026-s6", "academicYear": "2025–2026", "number": 6,
    "updatedAt": "2026-11-05T07:00:00.000Z", "rank": 7, "cohortSize": 142,
    "signedBy": "Dean Marc Lefèvre", "documentSizeMb": 1.4,
    "courses": [{ "code": "CS-401", "title": "Génie Logiciel & Microservices", "coefficient": 3, "credits": 10, "continuous": 17.5, "exam": 16 }]
  }]
}
```

- **Raw marks only.** The app computes the averages (40% continuous assessment + 60% exam), validation (≥ 10/20) and mentions.
- **Semester numbers follow today's date:** you get the three semesters before the current one.

## Profile

| | |
|---|---|
| `GET /profile` | `StudentProfile` |

The `StudentProfile` fields are:
- `studentId`, `displayName`, `email`
- `program`, `programShort`, `className`, `yearOfStudy`, `campus`, `campusLocation`
- `semester`, `academicYearStart`, `validUntil` ("YYYY-MM-DD")
- `ectsCredits`, `gpa`, `rankTopPercent`, `promoYear`, `honours`
- `isOnCampus`, `isVerified`, `nfcReady`, `hasEspritKey`
- `unreadNotifications`, `hasCarpoolActivity`

Where the computed values come from:
- **Grades:** `ectsCredits`, `rankTopPercent` and `honours`.
- **Notifications and carpool modules:** `unreadNotifications` and `hasCarpoolActivity`.
- **Today's date:** `semester` and `validUntil`.

A student without a profile document gets a default 1st-year profile.

## Notifications

| Method & path | Success | Errors |
|---|---|---|
| `GET /notifications` | your `AppNotification[]`, newest first | |
| `POST /notifications/:id/read` | `204` | 404 (also for another student's notification) |
| `POST /notifications/read-all` | `204` | |

An `AppNotification` has these fields:
- `id`, `category` (`academic`, `covoiturage`, `lostFound`, `career`, `community` or `account`), `label`, `title`, `body`
- `receivedAt`, `isRead`, `isUrgent`
- `attachment`: `null` or one of these:
  - `{ type: "place", place }`
  - `{ type: "ride", driverName, carLabel, isDriverVerified }`
  - `{ type: "schedule" }`
  - `{ type: "pickup", availability, ticket }`
- `link`: `null` or `{ destination, id }`. `destination` is one of `home`, `timetable`, `courses`, `grades`, `forum`, `ride`, `job`, `profile` or `adminUsers`. `id` is the ride, job or user id for `ride`, `job` and `adminUsers`, otherwise `null`.

A new student's first `GET` creates a "Welcome to CampusPulse" notification.

**Account notifications** (category `account`, label `"Account"`):

| When | Who gets it | Title | Link |
|---|---|---|---|
| An admin changes someone's role, email or password | that user (never the admin acting on their own account) | `"Your account was updated"`; the body has one line per change, e.g. `"Your role is now: **Teacher**."` Urgent when the password changed | `profile` |
| Someone signs up in the app | every admin | `"New account: <name>"`, body `"**<email>** just signed up."` | `adminUsers` + the new user's id |

Account notifications are also sent to the user's phones as [push notifications](#push).

**Timetable notifications** (category `academic`, label `"Timetable"` / `"Emploi du temps"`, link `timetable`): when an admin adds, changes or removes a class, every student and teacher gets one, also pushed. See [Timetable (admin)](#timetable-admin).

## Push

Push notifications go through Firebase Cloud Messaging (FCM). The app registers the FCM token of each phone, and the server pushes to every registered phone of the user.

| Method & path | Body | Success | Errors |
|---|---|---|---|
| `PUT /push/devices` | `{ token, platform }` | `204` | 401 · 422 |
| `DELETE /push/devices` | `{ token }` | `204`, also when the phone isn't registered | 401 · 422 |

**Registering (`PUT /push/devices`):**
- `token` is the FCM registration token: 1 to 4096 characters, trimmed. `platform` is `android` or `ios`.
- Call it after every sign-in, and whenever FCM gives the app a new token. Registering a known token again only refreshes it.
- A token registered by another account moves to the caller. On a shared phone, the last account signed in gets the pushes.
- An account keeps at most 10 phones. Registering an 11th forgets the one seen least recently.
- The 422 messages are `"Send the push token of this device"`, `"The push token is too long (at most 4096 characters)"` and `"Platform: android or ios"`.

**Unregistering (`DELETE /push/devices`):** the phone stops getting pushes, only if it is registered to the caller. Another account's phone is left alone (still `204`). Use it when the user turns notifications off.

**When a phone stops getting pushes:**
- **Sign-out:** send `pushToken` with [`POST /auth/logout`](#auth). The phone is removed if it is registered to the account of the refresh token.
- **Every session ends:** password reset, a new password set by an admin, `create-admin`, or a reused refresh token. All the user's phones are removed; the app registers again at the next sign-in.
- **The account is deleted** by an admin.
- **FCM no longer knows the token** (app uninstalled, token replaced): that phone is removed on the next push.

**What is pushed:**
- Every [account notification](#notifications) and timetable notification, when it is created. Sending never delays or fails the request. When an admin sets a new password, the push goes out before the phones are signed out, so the user learns why.
- **Class reminders**, 15 minutes before each session of the timetable, to every student and teacher with a phone (never to admins, alumni or companies). See below.

Without `FIREBASE_SERVICE_ACCOUNT_FILE` on the server, push is off: the routes above still store the phones, but nothing is sent. To test a phone, run `npm run push:test -- <email or ENT ID>` (see [backend/README.md](../backend/README.md#scripts)).

**The FCM message** (one per phone):

```json
{
  "notification": { "title": "Your account was updated", "body": "Your role is now: Teacher." },
  "data": {
    "notificationId": "6aee2d5a10aef9a35cb4bd01",
    "category": "account",
    "destination": "profile",
    "targetId": ""
  },
  "android": { "priority": "high", "notification": { "tag": "6aee2d5a10aef9a35cb4bd01" } },
  "apns": { "payload": { "aps": { "sound": "default" } } }
}
```

- `notification.body` is the notification's `body` as plain text: the markup (`**…**`, `~~…~~`, `==…==`) is removed, and the text and line breaks are kept.
- The `data` values are always strings. The app reads:
  - `notificationId`: the `id` of the notification in `GET /notifications` (mark it read with `POST /notifications/:id/read`).
  - `category`: as in an `AppNotification`.
  - `destination` and `targetId`: the notification's `link` (`destination` and `id`). Each is `""` when there is no link, or no id.
- `android.notification.tag` is the notification id, so on Android a new push of the same notification replaces the old one.
- No Android `channelId` is sent: Android shows the push in the app's default notification channel ("Campus updates").

**Class reminders** come from a job the API runs every minute while push is on:
- **When:** for each session of today (campus time) starting in the next 15 minutes. A session is reminded **once**: a `classreminders` record with a unique key (the session id) is kept for 2 days, so several API instances never send it twice. If the API was down, the reminder still goes out with the time left ("in 6 min"), but never once the session has started.
- **Not a notification of the feed:** nothing is added to `GET /notifications`.
- **Preview:** `npm run push:test -- <email or ENT ID> --class` sends the reminder of the next class now, without using up the real one.

```json
{
  "notification": {
    "title": "Algorithmes & Complexité",
    "body": "Lecture in 15 min · 08:30–10:00 · Amphi A"
  },
  "data": { "notificationId": "", "category": "academic", "destination": "timetable", "targetId": "" },
  "android": {
    "priority": "high",
    "notification": { "tag": "class-algo-cm-2026-11-9", "channelId": "class_reminders" }
  },
  "apns": { "payload": { "aps": { "sound": "default" } } }
}
```

- The body starts with the kind: `Lecture`, `Lab`, `Workshop` or `Exam`.
- `notificationId` is `""`: there is nothing to mark as read. The app opens the timetable.
- `channelId` is `class_reminders`, the app's "Class reminders" channel, so people can mute reminders in Android's settings and keep the other pushes.

---

## Admin

Every `/admin/*` route needs a signed-in user whose `role` is `admin`. Others get `403 { "message": "Only administrators can do this." }`. The role is read from the database on every request, so a demoted admin loses access at once.

**Bootstrap:** `npm run seed` creates the demo admin (`admin@campus.test` / `CampusPulseAdmin2026!`). On a real server, use `npm run create-admin -- <email> <password> [display name]` instead; it creates the account, or promotes an existing one (new password, every session signed out).

### Users

| Method & path | Body / query | Success | Errors |
|---|---|---|---|
| `GET /admin/users` | `?q=&role=&page=&limit=` | `200 { items: ManagedUser[], total, page, limit }` | 422 bad query |
| `GET /admin/users/stats` | — | `200 { total, byRole: { student, teacher, admin, alumni, company } }` (every role, 0 when none) | |
| `GET /admin/users/:id` | — | `200 ManagedUser` | 404 `"User not found."` |
| `POST /admin/users` | `{ displayName, email, password, studentId?, role? }` | `201 ManagedUser` | 409 email or ENT ID taken · 422 |
| `PATCH /admin/users/:id` | any of `{ displayName, email, studentId, role, password, isEmailVerified }` | `200 ManagedUser` | 400 · 404 · 409 · 422 |
| `DELETE /admin/users/:id` | — | `204` | 400 own account · 404 |
| `POST /admin/users/import` | `{ dryRun, users: ImportRow[] }` | see [Import](#import) | 422 |
| `GET /admin/users/import/assist` | — | `200 { available, model }` (see [Read with AI](#read-with-ai)) | |
| `POST /admin/users/import/assist` | `{ lines, values? }` | `200 { mapping, model }` | 422 · 429 · 502 · 503 |

A `ManagedUser`:

```json
{
  "id": "6aee283c10aef9a35cb4bcc6",
  "email": "dony.mansour@campus.test",
  "studentId": "211JMT0428",
  "displayName": "Dony Mansour",
  "role": "student",
  "isEmailVerified": true,
  "createdAt": "2026-11-05T09:15:00.000Z"
}
```

**Listing (`GET /admin/users`):**
- `q`: every word must appear in the name, email or ENT ID. Case and accents are ignored (`"helene"` finds `"Hélène"`).
- `role`: one of the four roles.
- `page` ≥ 1 (default 1), `limit` 1–100 (default 20).
- Sorted by name (case and accents ignored), then by id.

**Creating (`POST /admin/users`):**
- `displayName` 1–80 characters, `email` valid, `password` 8–128 characters.
- `studentId`: optional ENT ID, 3–20 letters or digits, stored in capitals.
- `role` defaults to `student`.
- The account is created with its email already verified (the admin vouches for it). No email is sent.

**Editing (`PATCH /admin/users/:id`):**
- Send only the fields to change. `studentId: null` (or `""`) removes the ENT ID. An empty body gives `422 "There's nothing to save."`.
- A field sent with its current value isn't a change. When nothing really changes, the answer is `200` with the account, and nothing is recorded.
- A new `password` signs the user out on every device.
- The user gets an `account` notification when their role, email or password changes.
- **Your own account:** only `displayName`, `email` and `studentId` can be changed (your current `role` or `isEmailVerified` sent unchanged is fine; a `password` never is). Anything else gives `400 "On your own account, you can only change your name, email and ENT ID."`, so an admin can't demote themselves or lock themselves out. (That also means the last admin can never be removed.)

**Deleting (`DELETE /admin/users/:id`):**
- Your own account gives `400 "You can't delete your own account."`.
- Removed with the account: its sessions, push phones, notifications, attendance, lab submissions, job applications, idea votes, lost & found requests, transcript and profile. The rides it drives are deleted, and the seats it booked on other rides become free again.
- Kept: the forum posts and lost & found notices it published, under their author name, with no link to the account.

### Import

`POST /admin/users/import` creates many accounts at once, **all or nothing**.

```json
{
  "dryRun": true,
  "users": [
    { "row": 2, "displayName": "Sarra Mansouri", "email": "sarra.mansouri@campus.test",
      "password": "Kp7m-x2Qa-9zTb", "studentId": "221JMT0101", "role": "student" }
  ]
}
```

- `dryRun` is required (`true` or `false`).
- `row` is the line number in the admin's file, echoed back in the problems. Without it, the position in `users` (from 1) is used.
- `password` is required (the app generates one when the file has none).
- `studentId` and `role` are optional. `role` ignores case and defaults to `student`.
- An empty `users` gives `422 "The file has no accounts."`. This route accepts bodies up to 1 MB (100 kB elsewhere).
- At most **1000** rows with `dryRun: true`, at most **50** to import. More gives `422 "At most 50 accounts per import."` (or `"At most 1000 lines per check."`).

Every row is checked. A problem is `{ row, field, code, message }`:

| `code` | `field` | `message` |
|---|---|---|
| `REQUIRED` | `displayName`, `email` or `password` | `"Name: missing"`, `"Email: missing"`, `"Password: missing"` |
| `TOO_LONG` | `displayName` | `"Name: too long (at most 80 characters)"` |
| `INVALID_EMAIL` | `email` | `"Email: not a valid address"` |
| `DUPLICATE_EMAIL` | `email` | `"Email: already on another line of the file"` |
| `EMAIL_TAKEN` | `email` | `"Email: an account already uses it"` |
| `INVALID_STUDENT_ID` | `studentId` | `"ENT ID: 3 to 20 letters or digits"` |
| `DUPLICATE_STUDENT_ID` | `studentId` | `"ENT ID: already on another line of the file"` |
| `STUDENT_ID_TAKEN` | `studentId` | `"ENT ID: an account already uses it"` |
| `INVALID_ROLE` | `role` | `"Role: not recognised (student, teacher, admin, alumni or company)"` |
| `PASSWORD_TOO_SHORT` | `password` | `"Password: at least 8 characters"` |
| `TOO_LONG` | `password` | `"Password: too long (at most 128 characters)"` |

A line gets at most one problem per field. For a duplicate, the first line is fine and the later ones are flagged.

Answers:
- **Dry run:** `200 { "dryRun": true, "valid": 48, "problems": [ … ] }`. `valid` counts the rows without problems. Nothing is created.
- **Import, no problems:** `201 { "dryRun": false, "created": [ ManagedUser, … ] }`. The accounts are verified, and no email is sent.
- **Import with problems:** `422 { "message": "The file has errors, so nothing was imported.", "problems": [ … ] }`.

### Read with AI

When the app can't read an import file (no known titles, roles written loosely), the server's AI says how it is laid out. Nothing is imported: the app rewrites the file as the template and checks it as usual (`backend/src/modules/admin/import-assist.service.ts`).

`GET /admin/users/import/assist` → `200 { "available": true, "model": "nvidia/nemotron-3.5-lightning:free" }`. `available` is false (and `model` null) without `OPENROUTER_API_KEY`.

`POST /admin/users/import/assist`, limited to **20 per admin per hour** (`429 TOO_MANY_REQUESTS`):

```json
{
  "lines": [
    ["Nom complet", "Adresse", "Profil", "MDP"],
    ["BEN ALI Ines", "i…@campus.test", "Étudiant(e)", "•••"]
  ],
  "values": [{ "column": 2, "values": ["Profil", "Étudiant(e)", "Enseignant"] }]
}
```

- `lines`: the first lines of the file, as cells (text, number or null). The app masks emails (`i…@domain`) and replaces the cells of a password column by `•••`. The server keeps 12 lines, 15 cells and 80 characters per cell, and masks emails again. 1 to 50 lines, else `422`.
- `values` (optional): the distinct values of short columns (roles), at most 40 per column, columns 0–14.

```json
{
  "mapping": {
    "headerRow": 1,
    "columns": { "lastName": null, "firstName": null, "fullName": 0, "email": 1,
                 "studentId": null, "role": 2, "password": 3 },
    "nameOrder": "LAST_FIRST",
    "roles": [{ "text": "Étudiant(e)", "role": "student" }, { "text": "Enseignant", "role": "teacher" }]
  },
  "model": "nvidia/nemotron-3.5-lightning:free"
}
```

- `headerRow`: the 1-based line (of `lines`) holding the titles, 0 when there is none.
- `columns`: the 0-based column of each field, or null. `fullName` is one column with both names, split by the app using `nameOrder` (`LAST_FIRST` or `FIRST_LAST`).
- `roles`: what each value of the role column means (`student`, `teacher`, `admin`, `alumni`, `company`, or null when the AI can't tell).

The answer is checked before it is sent (no free text of the model is kept):
- A column must exist and be used once; a column claimed twice keeps the first meaning in this order: email, lastName, firstName, fullName, studentId, role, password. With both lastName and firstName, fullName is null.
- `headerRow` outside `0…lines.length` becomes 0; `nameOrder` defaults to `LAST_FIRST`.
- Corrections: a lone last (or first) name column whose cells mostly hold 2 words or more becomes `fullName`; without a password column, the first free column whose filled cells are all `•••` becomes `password`.
- A role pair is kept only for a value that was sent and isn't the column's title; an unknown role becomes null.

Errors: the AI codes above (`503 AI_UNAVAILABLE` without a key, `503 AI_NO_CREDITS`, `429 AI_BUSY`, `502 AI_FAILED`), with their messages. The audit log records each answered request (`user.import.assist`); the file's content is never stored.

### Timetable (admin)

Admins manage the weekly timetable of the class group (one for now: "Tech Track 4BI"): the same classes every week. Students and teachers see the changes at once in `GET /timetable/*`, and the [class reminders](#push) follow them.

| Method & path | Body | Success | Errors |
|---|---|---|---|
| `GET /admin/timetable/slots` | — | `200 { classGroup, items: Slot[] }`, by weekday then start time | |
| `POST /admin/timetable/slots` | a slot without `id` | `201 Slot` | 409 · 422 |
| `PATCH /admin/timetable/slots/:id` | the fields to change | `200 Slot` | 404 · 409 · 422 |
| `DELETE /admin/timetable/slots/:id` | — | `204` | 404 `"This class is not in the timetable."` |

```json
{
  "id": "entrepreneuriat",
  "weekday": 5,
  "start": "13:30",
  "end": "15:30",
  "course": "Entrepreneuriat & Innovation",
  "room": "",
  "teacher": "Mme. Karoui",
  "kind": "workshop",
  "mode": "online",
  "meetUrl": "https://meet.google.com/xqd-fkzw-pnb",
  "notes": null,
  "coefficient": null,
  "lectureNumber": null,
  "lectureCount": null
}
```

**Rules** (`422 VALIDATION_ERROR`, the app checks the same: `timetable/domain/timetable_slot_rules.dart`):
- Required on `POST`: `weekday` (1 = Monday … 7 = Sunday), `start`, `end` (`HH:mm`), `course` (≤ 120), `teacher` (≤ 80). Optional: `room` (≤ 60), `kind` (default `lecture`), `mode` (default `onsite`), `meetUrl`, `notes` (≤ 1000), `coefficient`.
- The class ends after it starts, the same day, and lasts at most 8 hours (`"The class must end after it starts"`, `"A class lasts at most 8 hours"`).
- On site: a `room` is required. Online: the room is optional, and `meetUrl` is required and must be an https Google Meet link (`https://meet.google.com/abc-defg-hij`, ≤ 200). An on-site class drops its `meetUrl`.
- `coefficient` (0 < c ≤ 10) is kept for exams only. `lectureNumber` / `lectureCount` are kept as they are.
- `PATCH` changes only the fields sent (at least one, else `"Nothing to update"`); the result is checked like a new class. The `id` never changes.

**Clashes:** a class clashes with another one on the same weekday at overlapping times (back to back is fine) in the same room (case ignored) or with the same teacher. Nothing is saved, and the answer lists every clash (a class can appear twice, once per reason):

```json
{
  "message": "This class clashes with another class of the timetable",
  "code": "TIMETABLE_CONFLICT",
  "conflicts": [{ "reason": "room", "slot": { "id": "algo-cm", "weekday": 1, "start": "08:30", "end": "10:00", "...": "..." } }]
}
```

`reason` is `room` or `teacher`.

**Ids:** a new class gets a readable id that never changes: the course in lower case plus 4 random hex digits (`cloud-computing-3f1a`). Classes that shared an id in an older template get a new one the first time an admin opens the list.

**Notifications:** every add, change and removal notifies every student and teacher (not admins, alumni or companies), in their language (French with "tu"), and pushes it to their phones. One notification per person and class: the newest replaces the previous one about the same class (`id`: `timetable-<slot id>`). Category `academic`, label `"Timetable"` / `"Emploi du temps"`, link `timetable`. Saving a class without any change notifies nobody.

| Change | Title (EN) | Body (EN) |
|---|---|---|
| Added | `"Cloud Computing: new class on Saturdays, 09:00–11:00"` | `"A new class is in your timetable: **Cloud Computing** on Saturdays, 09:00–11:00, in room C201."` |
| New time, same day | `"Algo: time changed 08:30 → 08:00 (Mondays)"` | `"From now on, your class takes place on Mondays, 08:00–09:30, in room Amphi A."` |
| Another day | `"Algo: class moved Mondays, 08:30 → Saturdays, 08:30"` | same |
| Room or online | `"Algo: room changed Amphi A → Online (Mondays, 08:30)"` | `"Your class on Mondays, 08:30–10:00 now takes place online."` |
| New Meet link | `"Algo: new Google Meet link (Mondays, 08:30)"` | `"Your online class on … has a new Google Meet link: open the timetable to join it."` |
| Other details (course, teacher, kind, notes…) | `"Algo: class updated (Mondays, 08:30)"` | `"The details of your class on … changed: open the timetable to see them."` |
| Removed | `"Algo: class removed (Mondays, 08:30)"` | `"Your class on Mondays, 08:30–10:00 is no longer in your timetable."` |

In French: `"Algo : horaire changé 08:30 → 08:00 (lundi)"`, `"Désormais, ton cours a lieu le lundi de 08:00 à 09:30, en salle Amphi A."`… A notification that fails is logged, never fails the request.

**Audit:** `timetable.slot.create`, `timetable.slot.update`, `timetable.slot.delete` with a summary such as `"Added Cloud Computing on Saturday 09:00–11:00"` and `metadata: { slotId, course, weekday, notified }` (`targetType` null).

### Audit log

Every change an admin makes is recorded, and so is a password a user resets themselves.

| Method & path | Query | Success |
|---|---|---|
| `GET /admin/audit` | `?action=&page=&limit=` | `200 { items: AuditEntry[], total, page, limit }`, newest first |
| `GET /admin/audit/actions` | — | `200 ["user.create", "user.delete", …]`, the actions recorded so far |

- `action` is exact (`user.update`) or a prefix with `*` (`user.*`; a lone `*` is everything).
- `page` ≥ 1, `limit` 1–100 (default 30).

```json
{
  "id": "6aee2d5a10aef9a35cb4bd01",
  "action": "user.update",
  "summary": "Changed the role of Sarra Mansouri to Teacher",
  "actor": { "id": "6aee283c10aef9a35cb4bcc0", "displayName": "Campus Admin", "email": "admin@campus.test" },
  "targetType": "user",
  "targetId": "6aee283c10aef9a35cb4bcc9",
  "metadata": { "changes": ["role"], "role": { "from": "student", "to": "teacher" } },
  "ip": "127.0.0.1",
  "userAgent": "Dart/3.13 (dart:io)",
  "createdAt": "2026-11-09T10:42:00.000Z"
}
```

- `actor` is a copy taken when the action happened, so it survives the actor's deletion.
- `targetType` says what `targetId` is (`user`), or is null with `targetId` for an entry about no one thing (an import).
- `userAgent` is the request's `User-Agent` (at most 512 characters, null when missing). Both are null in entries recorded before they existed.
- `metadata` never contains a password.

| Action | Summary example | Metadata |
|---|---|---|
| `user.create` | `"Created the teacher account amira.bensalah@campus.test"` | `{ role }` |
| `user.update` | `"Changed the role of Sarra Mansouri to Teacher"`, `"Updated Sarra Mansouri (name, password)"` (the name before the change) | `{ changes, role?: { from, to } }`; `changes` lists field names (`displayName`, `email`, `studentId`, `role`, `password`, `isEmailVerified`) |
| `user.delete` | `"Deleted the account of Sarra Mansouri (sarra.mansouri@campus.test)"` | `{ email, role }` |
| `user.import` | `"Imported 12 accounts"` | `{ count, emails }` (the first 20) |
| `auth.password_reset` | `"Password reset with an emailed code for sarra.kefi@campus.test"` (the actor is the user) | `{}` |
| `auth.password_change` | reserved for the change of password (signed in) | |
| `user.import.assist` | `"Asked the AI (nvidia/nemotron-3.5-lightning:free) how an import file is laid out"` | `{ model, lines, columns }` (no file content) |
| `timetable.slot.create` · `.update` · `.delete` | `"Added Cloud Computing on Saturday 09:00–11:00"`, `"Changed …"`, `"Removed …"` | `{ slotId, course, weekday, notified }` |
