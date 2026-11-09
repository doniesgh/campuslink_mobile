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
- [Admin](#admin): user management and the audit log

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
| 403 | Signed in, but not allowed: an `/admin` route used by someone who isn't an admin, or the timetable or courses used by an admin or alumni |
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
| `POST /auth/logout` | `{ refreshToken, pushToken? }` | `204`. With `pushToken`, that phone stops getting [pushes](#push) | 422 (missing `refreshToken`, `pushToken` not text or too long) |
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
    "isEmailVerified": true,
    "role": "student"
  },
  "accessToken": "eyJhbGciOiJIUzI1NiIs…",
  "refreshToken": "1C95PsLEqH…"
}
```

`role` is `student`, `teacher`, `admin` or `alumni`. Sign-up always creates a `student`; only an admin can change a role (see [Admin](#admin)).

**Codes** have 6 digits, are valid for 15 minutes and are locked after 5 wrong tries. Without SMTP configured, the server prints them in its console (`[mail] Verification code for …: 042917`).

## Users

| | |
|---|---|
| `GET /users/me` | `200 user` (the same `user` object as above, not wrapped) |

## Timetable

Only students and teachers have a timetable. Admins and alumni get `403 { "message": "Only students and teachers have a timetable." }`.

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

Only students and teachers have courses. Admins and alumni get `403 { "message": "Only students and teachers have courses." }` on every route below.

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

**What is pushed:** every [account notification](#notifications), when it is created. Sending never delays or fails the request. When an admin sets a new password, the push goes out before the phones are signed out, so the user learns why.

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
- No Android `channelId` is sent: Android shows the push in the app's default notification channel.

---

## Admin

Every `/admin/*` route needs a signed-in user whose `role` is `admin`. Others get `403 { "message": "Only administrators can do this." }`. The role is read from the database on every request, so a demoted admin loses access at once.

**Bootstrap:** `npm run seed` creates the demo admin (`admin@campus.test` / `CampusPulseAdmin2026!`). On a real server, use `npm run create-admin -- <email> <password> [display name]` instead; it creates the account, or promotes an existing one (new password, every session signed out).

### Users

| Method & path | Body / query | Success | Errors |
|---|---|---|---|
| `GET /admin/users` | `?q=&role=&page=&limit=` | `200 { items: ManagedUser[], total, page, limit }` | 422 bad query |
| `GET /admin/users/stats` | — | `200 { total, byRole: { student, teacher, admin, alumni } }` (all four keys, 0 when none) | |
| `GET /admin/users/:id` | — | `200 ManagedUser` | 404 `"User not found."` |
| `POST /admin/users` | `{ displayName, email, password, studentId?, role? }` | `201 ManagedUser` | 409 email or ENT ID taken · 422 |
| `PATCH /admin/users/:id` | any of `{ displayName, email, studentId, role, password, isEmailVerified }` | `200 ManagedUser` | 400 · 404 · 409 · 422 |
| `DELETE /admin/users/:id` | — | `204` | 400 own account · 404 |
| `POST /admin/users/import` | `{ dryRun, users: ImportRow[] }` | see [Import](#import) | 422 |

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
| `INVALID_ROLE` | `role` | `"Role: not recognised (student, teacher, admin or alumni)"` |
| `PASSWORD_TOO_SHORT` | `password` | `"Password: at least 8 characters"` |
| `TOO_LONG` | `password` | `"Password: too long (at most 128 characters)"` |

A line gets at most one problem per field. For a duplicate, the first line is fine and the later ones are flagged.

Answers:
- **Dry run:** `200 { "dryRun": true, "valid": 48, "problems": [ … ] }`. `valid` counts the rows without problems. Nothing is created.
- **Import, no problems:** `201 { "dryRun": false, "created": [ ManagedUser, … ] }`. The accounts are verified, and no email is sent.
- **Import with problems:** `422 { "message": "The file has errors, so nothing was imported.", "problems": [ … ] }`.

### Audit log

Every change an admin makes is recorded.

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
  "targetId": "6aee283c10aef9a35cb4bcc9",
  "metadata": { "changes": ["role"], "role": { "from": "student", "to": "teacher" } },
  "ip": "127.0.0.1",
  "createdAt": "2026-11-09T10:42:00.000Z"
}
```

- `actor` is a copy taken when the action happened, so it survives the actor's deletion.
- `metadata` never contains a password.

| Action | Summary example | Metadata |
|---|---|---|
| `user.create` | `"Created the teacher account amira.bensalah@campus.test"` | `{ role }` |
| `user.update` | `"Changed the role of Sarra Mansouri to Teacher"`, `"Updated Sarra Mansouri (name, password)"` (the name before the change) | `{ changes, role?: { from, to } }`; `changes` lists field names (`displayName`, `email`, `studentId`, `role`, `password`, `isEmailVerified`) |
| `user.delete` | `"Deleted the account of Sarra Mansouri (sarra.mansouri@campus.test)"` | `{ email, role }` |
| `user.import` | `"Imported 12 accounts"` | `{ count, emails }` (the first 20) |
