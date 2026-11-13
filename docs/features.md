# Features

What every screen does, where its code lives and which endpoints it uses. The numbers (01–12) are the Stitch design screens. Paths are relative to `lib/features/` (app) and `backend/src/modules/` (API).

| Screen | Stitch | App code | API module |
|---|---|---|---|
| [Login & account](#login-and-account) | 01 | `auth/` | `auth/`, `users/` |
| [Home](#home) | 02 | `home/` | (reuses timetable, forum, notifications) |
| [Timetable](#timetable) | 03 | `timetable/` | `timetable/` |
| [Courses](#courses) | 04 | `courses/` | `courses/` |
| [Forum: Covoiturage](#forum-covoiturage-carpooling) | 05, 06 | `forum/`, `carpooling/` | `carpool/` |
| [Forum: Lost & Found](#forum-lost--found) | 07 | `forum/` | `forum/` |
| [Forum: Ideas](#forum-ideas) | — | `forum/` | `forum/` |
| [Jobs](#jobs) | 08, 09 | `jobs/` | `jobs/` |
| [Profile & Digital ID](#profile--digital-id) | 10 | `profile/` | `profile/` |
| [Grades](#grades) | 11 | `grades/` | `grades/` |
| [Notifications](#notifications) | 12 | `notifications/` | `notifications/` |
| [Administration](#administration) (admins only) | — | `admin/` | `admin/` |
| [Language](#language-french--english) (FR / EN) | — | `lib/core/l10n/`, `lib/l10n/`, `profile/` | `users/` (`PATCH /users/me`) |

---

## Login and account

**Screens:**
- `LoginPage`: the purple hero is also the onboarding screen.
- `RegisterPage`, `ForgotPasswordPage`, `ResetPasswordPage`.

All of them share the `AuthScaffold` layout.

- **Login** takes an **ENT ID or an email** with a password. "Continue with University SSO" is not available yet.
- **Register** creates the account and signs you in directly: *Create account* opens Home. No confirmation email is sent and there is no code to enter. Accounts created before this, with an unverified email, sign in normally too.
- **Forgot password** emails a 6-digit code, then *Choose a new password* takes the code and the new password. All existing sessions are signed out.
- **Session:** it is restored at start-up. Tokens refresh automatically, and Log out also ends the session on the server.
- **Too many attempts:** the API limits sign-in, sign-up and password resets (per account and per network). Past the limit the app shows "Too many attempts. Try again in a few minutes." (`TooManyRequestsFailure`, code `TOO_MANY_REQUESTS`).
- **Language:** a new account gets the language on screen. After a sign-in, if the account's language differs from the one on screen, the app updates the account (`PATCH /users/me`), so its emails come in the language the user reads the app in. See [Language](#language-french--english).

**API:** `POST /auth/register`, `/login`, `/refresh`, `/logout`, `/forgot-password`, `/reset-password`, `GET /users/me` and `PATCH /users/me`.

**Code:** `auth/presentation/pages/`, `auth/presentation/providers/auth_controller.dart` (`AuthController`, `currentUserIdProvider`). The redirect rules are in `core/router/app_router.dart` (`authRedirect`).

## Home

**Screen:** `HomePage`, the first tab.

- **Greeting:** the student's name, the date and the semester week, with search (coming soon) and a bell. The bell's dot shows when there are unread notifications.
- **"Up next" card:** the class in progress or the next one, with a live countdown and the course's progress.
- **Quick actions:**
  - Covoiturage, Objets Perdus and Idées open the matching Forum section.
  - Planning opens the Timetable.
- **Today's schedule:** today's classes, marked done, now/next or later.
- **Campus Highlights:** the latest forum posts.
  - Idea posts can be upvoted, with the same count as in the Forum.
  - "C'est à moi" opens Lost & Found.
  - "Répondre" (messaging) is coming soon.

**Admins, alumni and companies** have no timetable, so their Home has no "Up next" and no "Today's schedule".
- **Admins** get an **Administration** card instead: the number of accounts per role, and links to Users, Import and Audit log (`AdminOverviewCard`). Their Planning shortcut becomes **Comptes** (the users).
- **Alumni and companies:** Planning becomes **Offres** (Jobs).

**Online classes:** "Up next" shows "Online" and a **Join Google Meet** button; "Today's schedule" shows "Online" with a camera icon.

**Data:** Home has no repository of its own. It reads `todayTimetableProvider` (students and teachers only), `highlightsProvider`, `ideaUpvotesProvider`, `unreadNotificationCountProvider` and, for admins, `userStatsProvider`.

## Timetable

**Screen:** `TimetablePage`, the second tab.

**Class reminders:** a push 15 minutes before each session (see Notifications › Push notifications).

**Who:** students and teachers. Admins, alumni and companies follow no classes. They don't get the tab, `authRedirect` sends them home from `/app/timetable*`, and the API answers 403. The same goes for **Courses**.

- **Navigation:** previous/next week, and a Monday–Saturday day strip with dots for days that have classes or exams.
- **Day summary:** the number of sessions, exams and hours.
- **Timeline:** past sessions are faded, the current one is live with a progress bar, and the next one shows "Starts in …". Free periods and evaluations ("Major Evaluation · Coeff X") are highlighted.
- **Tapping a session** opens its course in **Courses**.
- **Online classes** (Google Meet): an **Online** chip and a **Join Google Meet** button that opens the link in the Meet app or the browser (`url_launcher`); not once the class is over. Home's "Up next" card has the button too, and "Today's schedule" says "Online". The demo's Friday workshop is online.

**Who edits it:** admins, in Administration › **Timetable** (see [Administration](#administration)). Every change notifies the students and teachers (a notification in their language, pushed to their phones), and the class reminders follow the new times.

**API:** `GET /timetable/day?date=`, `GET /timetable/week?date=`. The data is one weekly template per class group (everyone is in "Tech Track 4BI" for now). Sessions carry `mode` (`onsite` / `online`) and `meetUrl`.

**Code:**
- `timetable/domain/schedule_logic.dart` holds the week maths, the statuses and the free periods, all unit-tested.
- `timetable/presentation/widgets/meet_link.dart`: the Online chip and the Join button (`meetLauncherProvider`, replaced in tests).

## Courses

**Screen:** `CoursesPage` (`/app/timetable/courses?course=`), opened from the Timetable.

- **Header:** a course switcher (the code pill at the top), the professor card and an attendance badge.
- **Mastery card:** a progress ring weighted by module hours, the pace ("ahead / on / behind schedule") and the next quiz. Tapping it lists the modules.
- **Resources:**
  - Download a PDF.
  - Stream a video (coming soon).
  - Submit a lab with an https repository link.
- **Attendance:** "Mark as Present Now" records it.

**API:** `GET /courses`, `PUT /courses/:id/attendance`, `POST /courses/resources/:id/download`, `POST /courses/assignments/:id/submission`.

## Forum: Covoiturage (carpooling)

**Screens:** `ForumPage` (third tab, *Covoiturage* section), `RideDetailPage`, `NewRidePage`.

- **Ride list:** search and rides as cards.
- **Ride detail & booking:** a map preview, the driver card (with "New driver" for first-time drivers) and a seat picker. **Reserve Seat** books the chosen seats, and the seats you booked are labelled "You".
- **Publishing a ride:** the **"Proposer un trajet +"** button opens a form with:
  - route
  - day and time
  - duration
  - seats and price
  - car
  - options

  You become the driver and the ride appears for everyone. You can't book your own ride.

**API:** `GET /carpool/rides`, `GET /carpool/rides/:id`, `POST /carpool/rides`, `POST /carpool/rides/:id/reservations`.

**Code:**
- The Forum page itself is in `forum/presentation/pages/forum_page.dart`. Its selected section is `forumSectionProvider`, so other screens can open a given section.
- The carpooling screens and widgets are in `carpooling/`.
- The form's rules (`carpooling/domain/new_ride_rules.dart`) match the server's.

## Forum: Lost & Found

**Screen:** the *Lost & Found* section of `ForumPage`.

- **Filters:** Tous, Objets Perdus and Objets Trouvés, with counts. Search covers the object, room and building.
- **Item cards:** status, place, reporter, reward or drop-off desk, and an action button:
  - **"C'est à moi / Réclamer"** for found items
  - **"J'ai trouvé cet objet !"** for lost items
  - **"Vérifier le numéro de série"** for items with a hidden serial number

  The button opens a sheet where the student sends proof of ownership. It is not shown on the student's own notices, nor on resolved ones ("Résolu · objet rendu à son propriétaire").
- **"Publier une annonce"** opens a form to report a lost or found item.
- **Managing a notice:** its reporter (or an admin) gets a ⋮ menu on the card: **Modifier** (the publish form, prefilled), **Marquer comme résolue** / **Réactiver l'annonce**, and **Supprimer** (after a confirmation). The demo student reported "Calculatrice graphique TI-84" (lf-407).
- **"Correspondances possibles"** (on every active notice) opens a sheet with the active notices of the other kind that may be the same object: kind, zone, date, place, a score bar and why. The server scores them by rules (category, date, place and words) and, when AI is configured, re-ranks them with a short reason per match (an **IA** chip then shows). Tapping a match pins it above the board ("Correspondance sélectionnée"). The mock repository uses the same rules, without AI.

**API:** `GET /forum/lost-items`, `POST /forum/lost-items`, `PATCH` / `DELETE /forum/lost-items/:id`, `GET /forum/lost-items/:id/matches`, `POST /forum/lost-items/:id/requests`.

## Forum: Ideas

**Screen:** the *Ideas* section of `ForumPage`.

- **Idea list:** most upvoted first, with an upvote button (one vote per student; tap again to remove it).
- **"Proposer une idée"** publishes an idea with a theme.

**API:** `GET /forum/ideas`, `POST /forum/ideas`, `POST /forum/ideas/:id/upvote`.

## Jobs

**Screens:** `JobsPage` (fourth tab), `JobDetailPage`, `JobFormPage` (new and edit), the AI summary sheet.

- **Offers:** a searchable list (title, company, location). Offers posted by companies come first, then the catalogue. An **"Applied"** badge shows on offers you applied to.
- **Offer detail:** the stats, workspace, mission and profile match. Offers posted through the form only show what they have (no match, no workspace...).
- **Applying:** students only (as in the PWA): **Apply Now** sends the application, and applying twice is refused. Other roles see "Students apply".
- **Demo offers of the companies:** `npm run seed` gives Nadia Kooli (Medina Soft) and Walid Sassi (Carthage Data) one offer each, so a company account can show Edit / Delete right away.
- **Save and share:** Save is local for now; Share copies a link.
- **Posting an offer** (companies and admins): **New offer** on the Jobs tab opens the form: title, company, description (required), location, period, duration, stipend, skills and tags (comma-separated). The form checks the server's rules before sending; the offer opens once published.
- **Editing and deleting:** the offer's author and admins (who can also edit the seeded offers) get **Edit** and **Delete** on the detail; Delete asks for confirmation and removes the offer's applications too.
- **AI summary:** **AI summary** on any offer opens a sheet: a short summary, the key points, the skills asked for and who the offer is ideal for, in the account's language. The server caches it until the offer is edited. When AI isn't set up on the server (no OpenRouter key), when the AI is busy or out of credits, or after 30 summaries in an hour, the sheet says so (with the wait).
- **Demo:** sign in as a company (`nadia.kooli@campus.test` or `walid.sassi@campus.test`, the demo student's password) or as the admin. With `USE_MOCK=true` the mock posts, edits and deletes in memory and answers a canned summary; sign in with an identifier containing "admin" to see the buttons.

**API:** `GET /jobs`, `GET /jobs/:id`, `POST /jobs`, `PATCH /jobs/:id`, `DELETE /jobs/:id`, `POST /jobs/:id/summary`, `POST /jobs/:id/applications`.

## Profile & Digital ID

**Screen:** `ProfilePage`, the fifth tab.

- **Header:** a hero with the name and program.
- **Stats:** credits, GPA and rank. Tapping them opens **Grades**.
- **Digital student ID card:**
  - academic year, student ID and validity
  - a QR code, which is a **visual placeholder** generated from the ID
  - "NFC Student Pass", which is coming soon
- **Campus Services & Settings:**
  - curriculum, which opens Grades
  - covoiturage, which opens the Forum; its dot shows when you drive or booked a ride
  - notifications, with the unread count
  - **appearance**: Light, System or Dark
  - **language**: FR or EN (see [Language](#language-french--english))
  - SSO and privacy (coming soon)
  - **Sign Out**

**Roles:**
- Admins also get an **Administration** section: Users, Import accounts, Audit log (see [Administration](#administration)).
- Teachers, admins, alumni and companies don't see the student card, the stats or the NFC pass: the hero shows their role instead ("Admin · CampusPulse", "Company · CampusPulse").

**API:** `GET /profile`. Credits, rank and honours come from the transcript; the unread count and the carpool dot come from their modules.

## Grades

**Screen:** `GradesPage` (`/app/profile/grades`).

- **Semester picker:** the three published semesters.
- **Standing card:** the average (out of 20) with a ring, the mention (Très Bien / Bien / Assez Bien / Passable), ECTS credits and the trend compared with the previous semester.
- **Module breakdown:** continuous assessment, exam and final average, and the status (Validé / Compensé / Non validé).
- **Documents:** the dean's signature card, the transcript download (coming soon) and the honor-roll tile.

**API:** `GET /grades/transcript` sends raw marks only. The app computes everything in `grades/domain/grading.dart`:
- course average = 40% continuous assessment + 60% exam
- a course or semester is validated at 10/20 or more
- a course below 10 is compensated if the semester is validated

These rules also exist in `backend/src/modules/grades/grading.ts`, for the Profile stats. **Change both together.**

## Notifications

**Screen:** `NotificationsPage` (`/app/notifications`), opened from Home's bell or from Profile.

- **Filters:** All, Academic, Covoiturage and Urgent Alerts.
- **Groups:** Today / Yesterday / Earlier, with unread dots and **Mark all read**.
- **Tapping a notification** marks it read and opens its target: a ride, a job, the timetable, courses, grades or the forum.
- **Coming soon:** the extra actions (map, calendar, SMS, preferences).

**Account notifications** (category `account`):
- "Your account was updated" when an admin changes your role, email or password (urgent for a password). It opens Profile.
- "New account: <name>" to every admin when someone signs up. It opens that account in Administration.

**Push notifications** (Firebase Cloud Messaging):
- **What's sent:**
  - Every notification the API creates also goes to its user's phones. Today that means the account notifications above. Run `npm run push:test -- <email or ENT ID>` to send a test one.
  - **Class reminders:** 15 minutes before each class or exam, for example "Algorithmes & Complexité" / "Lecture in 15 min · 08:30–10:00 · Amphi A". They go to students and teachers, open the Timetable, and don't appear in the notifications list. They have their own Android channel, so you can mute them alone. Preview one with `--class`.
- **App in the background or closed:** the phone shows the notification. Tapping it opens the same screen as in the list and marks it read.
- **App open:** a banner with **View** appears, and the bell updates.
- **Registration:**
  - The phone registers after sign-in. The app asks for the permission on Android 13+ and iOS.
  - It's removed at sign-out, and when the password changes or the account is deleted.
- **Off** in demo mode and until the Firebase project is set up ([getting-started.md](getting-started.md#push-notifications-optional)). Nothing else changes.

**API:** `GET /notifications`, `POST /notifications/:id/read`, `POST /notifications/read-all`; for push, `PUT /push/devices` and the `pushToken` of `POST /auth/logout`.

**Code:**
- App: `notifications/presentation/push_controller.dart` and `notifications/data/push/firebase_push_messaging.dart`.
- Backend: `modules/push/`.

## Administration

**Who:** accounts whose role is `admin`. The demo admin is `admin@campus.test` / `CampusPulseAdmin2026!` (created by `npm run seed`). In demo mode, any identifier containing "admin" signs in as the admin.

**Where:** Profile › Administration, or the Administration card on Home. The routes are under `/app/profile/admin/`, inside the Profile tab. `authRedirect` sends non-admins back to Profile, and the API answers 403 to them anyway.

**Screens** (no Stitch design: they reuse the look of the Jobs and ride form screens):

- **Users** (`AdminUsersPage`):
  - search by name, email or ENT ID (accents ignored)
  - role chips with counts
  - 20 accounts at a time, more load as you scroll
  - "(you)" on your own account, an "Email not verified" badge
  - **Add user**, and buttons to Import and the Audit log
- **Add / edit user** (`UserFormPage`):
  - name, email, optional ENT ID, role (five cards: Student, Teacher, Admin, Alumni, Company) and password, with **Generate**
  - when editing: the password is optional (empty keeps it), and an "Email verified" switch
  - after creating an account or setting a password, a dialog shows the **sign-in details** once, with **Copy**
  - **Delete this account**, after a confirmation
  - **Your own account:** only the name, email and ENT ID. You can't change your role or password, or delete yourself, so there is always an admin left
- **Import accounts** (`ImportUsersPage`):
  1. Choose a **CSV file**, or **paste cells** copied from Excel or Google Sheets.
  2. The app reads the titles in English or French (`Nom`, `Prénom`, `Courriel`, `Rôle`, `Mot de passe`…). Required: a name (or first and last name) and an email. Optional: ENT ID, role, password; an empty password is generated.
  3. **Check the lines:** the app checks every line, then the server does a dry run ("an account already uses this email"). Lines with problems can be left out.
  4. **Import:** batches of 25, all or nothing per batch.
  5. **Copy the sign-in details** (a tab-separated sheet). Leaving without copying generated passwords asks first.
- **Read with AI** (only when the server has an AI key, `GET /admin/users/import/assist`):
  - Offered when the columns aren't found ("This file doesn't follow the template"), or as **Fix with AI** when some roles or names can't be read.
  - What is sent: the first 12 lines, with emails masked (`i…@campus.test`) and the cells of a password column (found by its title: `MDP`, `Mot de passe`, `Password`…) replaced by `•••`, plus the distinct values of short columns (roles). The card says so, with the model.
  - The AI says which line holds the titles, which column is which field (name, first / last name, or one full-name column, email, ENT ID, role, password) and what each role value means.
  - The app rewrites the whole file as the template and checks it again as usual. A full name is split: the words in capitals are the family name (`BEN ALI Ines` → `Ines BEN ALI`), otherwise the first or last word with its particles (`Ben`, `El`, `de`…). Line numbers stay those of the file.
  - A summary shows what the AI understood (title line, column letters, roles, values it couldn't read, the model), with **Undo**. Errors (not available, busy, failed, too many requests) are shown on the card. Nothing is imported until the admin taps **Import**.
- **Timetable** (`TimetableAdminPage`, in `timetable/presentation/admin/`, route `/app/profile/admin/timetable`): the weekly classes, grouped by day.
  - **Add a class** / tap a class to edit it (`SlotFormPage`): day, start and end (`HH:mm`, or the clock button), course, teacher, kind (Lecture, Lab, Workshop, Exam), **Online class** switch with the **Google Meet link**, room (optional online), coefficient for exams, notes.
  - The form checks the server's rules first (end after start, 8 hours max, a room on site, an https `meet.google.com` link online).
  - **Clashes** (same room or same teacher at overlapping times on that day) are listed in the form, one line per class in the way ("Same room: Algorithmes & Complexité, Monday 08:30–10:00 (Amphi A)"); nothing is saved.
  - The bin icon removes a class, after a confirmation.
  - Students and teachers are notified of every change (see [api.md](api.md#timetable-admin) for the texts).
- **Audit log** (`AuditLogPage`): every change made by an admin, and the passwords users reset themselves, newest first, filtered by action (Created, Updated, Deleted, Imported, Password reset…). Tapping an entry about an account opens it.

**What deleting an account removes:** its sessions, notifications, attendance, submissions, applications, votes, lost & found requests, transcript and profile; the rides it drives; its seats on other rides (freed). Its forum posts and notices stay, without a link to the account.

**Roles:** `student` (every sign-up), `teacher`, `admin`, `alumni` and `company`. A **company** is a recruiter (a partner company): an admin creates it (or imports it: `company`, `entreprise`, `société`, `recruteur`, `partenaire`… in the role column). It has no timetable, courses or student card; what it does in Jobs comes with the job offers. The seed creates two: Nadia Kooli (Medina Soft) and Walid Sassi (Carthage Data).

**Not built** (they exist in the PWA `campuslink_v1`): reading Excel files directly, and groups and programs. For the timetable: dated sessions (one-off classes, cancelling one date), several class groups, ICS export and CSV import (the app edits one weekly template).

**API:** `/admin/users` (list, stats, get, create, edit, delete, import, import assist), `/admin/timetable/slots` (list, add, edit, remove) and `/admin/audit`. See [api.md](api.md#admin).

**Code:**
- The import rules are in `admin/domain/user_import_parser.dart`, unit-tested: CSV/TSV reading, title aliases, role synonyms, password generation, the line checks.
- Read with AI: `admin/domain/import_assist.dart` (pure, unit-tested: `assistRequest` masking, `splitFullName`, `applyAssist`) and `backend/src/modules/admin/import-assist.service.ts` (prompt, schema, `sanitize`). In demo mode `MockAdminRepository` answers as `mock/import-assist` with a guess made from the lines.
- The page-by-page lists are `userListProvider` and `auditListProvider` (`PagedState`, `loadMore()`).
- `MockAdminRepository` follows the API's rules and messages, so the screens work the same in demo mode.
- Timetable: the rules and clash detection are in `timetable/domain/timetable_slot_rules.dart` (same messages as `backend/src/modules/timetable/timetable-admin.*`). In demo mode `MockTimetableAdminRepository` edits the same in-memory week (`MockTimetableStore`) as the students' `MockTimetableRepository`.

## Language (French / English)

**Where:** Profile › Campus Services & Settings › **Language**, next to Appearance: **FR** or **EN**.

- **The language on screen:** the one chosen, saved on the phone; until one is chosen, the phone's language when it is French or English, else French (`localeProvider`, `core/l10n/app_language.dart`).
- **The account follows it:** changing the language while signed in, and signing in with an account in another language, update the account (`PATCH /users/me { locale }`, in the background; a failure is ignored). The server writes the account's emails (password-reset codes) and notifications in that language, French with "tu".
- **Every request** says the language (`Accept-Language: fr` or `en`), so the server can answer in it before it knows the user.
- **Texts:** new texts are in `lib/l10n/app_en.arb` and `app_fr.arb` (see [contributing.md](contributing.md#5-translations-french--english)). Most screens still show their original texts (mostly English, French on the forum and carpool screens) until they are moved there; Material's own texts (dialogs, date pickers) already follow the language.

---

## Coming soon (not built yet)

These show a "coming soon" message and are marked with a `// TODO:` in the code:

- University SSO login
- Search on Home
- Messaging: "Répondre" on carpool posts
- The NFC student pass, and a real signed QR code
- Calendar sync, the "Find Seat" exam helper, video streaming
- The Discord / community links
- Transcript PDF download
- Notification preferences and SMS alerts
