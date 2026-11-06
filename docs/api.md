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
- [Jobs](#jobs) · [Forum](#forum) · [Grades](#grades) · [Profile](#profile) · [Notifications](#notifications)

---

## Conventions

**Authentication.** Every route except `/health` and `/auth/*` (apart from the two marked 🔒) needs:

```http
Authorization: Bearer <accessToken>
```

Access tokens last 15 minutes. On a `401`, call `POST /auth/refresh` with the refresh token; the app does this automatically.

**Errors** are always JSON with a message written for students:

```json
{ "message": "This seat is no longer available." }
```

| Status | When |
|---|---|
| 400 | Bad request: wrong or expired code, malformed JSON |
| 401 | Not signed in, wrong credentials, or expired session |
| 404 | Unknown id (`"Job not found."`), or a route that doesn't exist |
| 409 | Conflict: seat taken, already applied, booking your own ride… |
| 422 | Invalid data. The message names the first problem (`"Use at least 8 characters"`) |
| 429 | Too many attempts on an auth route |
| 500 | Server error (`"Something went wrong. Please try again."`) |

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
| `POST /auth/register` | `{ displayName, email, password }` (password ≥ 8) | `201` session (below) + emails a 6-digit code | 409 email taken · 422 |
| `POST /auth/login` | `{ identifier, password }` | `200` session | 401 `"Invalid ENT ID/email or password."` |
| `POST /auth/refresh` | `{ refreshToken }` | `200 { accessToken, refreshToken }` (the old one is revoked) | 401 |
| `POST /auth/logout` | `{ refreshToken }` | `204` | — |
| `POST /auth/forgot-password` | `{ email }` | `200 { message }` + emails a 6-digit code | — (same answer for unknown emails) |
| `POST /auth/reset-password` | `{ email, code, password }` | `200 { message }`, signs out everywhere | 400 `"Invalid or expired code…"` · 422 |
| `POST /auth/verify-email` 🔒 | `{ code }` | `200 { user }` | 400 wrong / expired code · 401 · 422 |
| `POST /auth/resend-verification` 🔒 | — | `204` | 401 |

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
    "isEmailVerified": true
  },
  "accessToken": "eyJhbGciOiJIUzI1NiIs…",
  "refreshToken": "1C95PsLEqH…"
}
```

**Codes** have 6 digits, are valid for 15 minutes and are locked after 5 wrong tries. Without SMTP configured, the server prints them in its console (`[mail] Verification code for …: 042917`).

## Users

| | |
|---|---|
| `GET /users/me` | `200 user` (the same `user` object as above, not wrapped) |

## Timetable

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
  "notes": null
}
```

`kind` is one of `lecture`, `lab`, `exam`, `workshop`. Exams carry a `coefficient` and `notes`.

## Courses

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

| Method & path | Success | Errors |
|---|---|---|
| `GET /jobs` | `Job[]`, best match first | |
| `GET /jobs/:id` | `Job` | 404 |
| `POST /jobs/:id/applications` | `201 { jobId, appliedAt }` | 404 · 409 `"You already applied to this offer."` |

The `Job` fields are:
- `id`, `featuredLabel`, `title`, `company`, `location`, `tags[]`
- `stipendTnd`, `durationMonths`, `period`
- `labGroup`, `labGroupNote`, `workspaceTitle`, `workspaceBadges[]`
- `mission`, `missionItems[{ title, description }]`
- `matchPercent`, `criteria[]`, `skills[]`
- **`hasApplied`**, for the signed-in student.

## Forum

| Method & path | Body | Success | Errors |
|---|---|---|---|
| `GET /forum/highlights` | — | `ForumPost[]`, newest first (Home feed) | |
| `GET /forum/lost-items` | — | `LostItem[]`, newest first | |
| `POST /forum/lost-items` | notice (below) | `201 LostItem` with a reference `LF-412`, `LF-413`… | 422 (French messages) |
| `POST /forum/lost-items/:id/requests` | `{ proof }` | `201 { id, itemId, proof, createdAt }` | 404 · 409 already asked · 422 |
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
  "isSerialHidden": false
}
```

**New notice body:**
- `{ kind, title, category, zone, location, place, distinctiveDetail?, reward?, isUrgent?, dropOffNote?, pickupDesk? }`.
- `kind` is `lost` or `found`.
- `category` is one of `calculator`, `keys`, `audio`, `bag`, `card`, `bottle`, `other`.
- `place` is one of `classroom`, `parking`, `library`, `cafeteria`, `other`.
- A found item needs a `dropOffNote` or a `pickupDesk`. `reward` and `isUrgent` are for lost items only.

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
- `id`, `category`, `label`, `title`, `body`
- `receivedAt`, `isRead`, `isUrgent`
- `attachment`: `null` or one of these:
  - `{ type: "place", place }`
  - `{ type: "ride", driverName, carLabel, isDriverVerified }`
  - `{ type: "schedule" }`
  - `{ type: "pickup", availability, ticket }`
- `link`: `null` or `{ destination: "home" | "timetable" | "courses" | "grades" | "forum" | "ride" | "job", id }`

A new student's first `GET` creates a "Welcome to CampusPulse" notification.
