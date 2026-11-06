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

---

## Login and account

**Screens:**
- `LoginPage`: the purple hero is also the onboarding screen.
- `RegisterPage`, `VerifyEmailPage`, `ForgotPasswordPage`, `ResetPasswordPage`.

All of them share the `AuthScaffold` layout.

- **Login** takes an **ENT ID or an email** with a password. "Continue with University SSO" is not available yet.
- **Register** creates an account, emails a 6-digit code, and opens *Check your inbox*. You can't reach the app until the email is verified.
- **Forgot password** emails a 6-digit code, then *Choose a new password* takes the code and the new password. All existing sessions are signed out.
- **Session:** it is restored at start-up. Tokens refresh automatically, and Log out also ends the session on the server.

**API:** `POST /auth/register`, `/login`, `/refresh`, `/logout`, `/forgot-password`, `/reset-password`, `/verify-email`, `/resend-verification`, and `GET /users/me`.

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

**Data:** Home has no repository of its own. It reads `todayTimetableProvider`, `highlightsProvider`, `ideaUpvotesProvider` and `unreadNotificationCountProvider`.

## Timetable

**Screen:** `TimetablePage`, the second tab.

- **Navigation:** previous/next week, and a Monday–Saturday day strip with dots for days that have classes or exams.
- **Day summary:** the number of sessions, exams and hours.
- **Timeline:** past sessions are faded, the current one is live with a progress bar, and the next one shows "Starts in …". Free periods and evaluations ("Major Evaluation · Coeff X") are highlighted.
- **Tapping a session** opens its course in **Courses**.

**API:** `GET /timetable/day?date=`, `GET /timetable/week?date=`. The data is one weekly template per class group (everyone is in "Tech Track 4BI" for now).

**Code:** `timetable/domain/schedule_logic.dart` holds the week maths, the statuses and the free periods, all unit-tested.

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

- **Ride list:** search, rides as cards and the campus CO₂ impact card.
- **Ride detail & booking:** a map preview, the driver card (with "New driver" for first-time drivers) and a seat picker. **Reserve Seat** books the chosen seats, and the seats you booked are labelled "You".
- **Publishing a ride:** the **"Proposer un trajet +"** button opens a form with:
  - route
  - day and time
  - duration
  - seats and price
  - car
  - options

  You become the driver and the ride appears for everyone. You can't book your own ride.

**API:** `GET /carpool/rides`, `GET /carpool/rides/:id`, `POST /carpool/rides`, `POST /carpool/rides/:id/reservations`, `GET /carpool/impact`.

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

  The button opens a sheet where the student sends proof of ownership.
- **"Publier une annonce"** opens a form to report a lost or found item.

**API:** `GET /forum/lost-items`, `POST /forum/lost-items`, `POST /forum/lost-items/:id/requests`.

## Forum: Ideas

**Screen:** the *Ideas* section of `ForumPage`.

- **Idea list:** most upvoted first, with an upvote button (one vote per student; tap again to remove it).
- **"Proposer une idée"** publishes an idea with a theme.

**API:** `GET /forum/ideas`, `POST /forum/ideas`, `POST /forum/ideas/:id/upvote`.

The *Experiences* section is still "coming soon".

## Jobs

**Screens:** `JobsPage` (fourth tab), `JobDetailPage`.

- **Offers:** a searchable list. An **"Applied"** badge shows on offers you applied to.
- **Offer detail:** the stats, workspace, mission and profile match.
- **Applying:** **Apply Now** sends the application. Applying twice is refused.
- **Save and share:** Save is local for now; Share copies a link.

**API:** `GET /jobs`, `GET /jobs/:id`, `POST /jobs/:id/applications`.

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
  - SSO and privacy (coming soon)
  - **Sign Out**

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

**API:** `GET /notifications`, `POST /notifications/:id/read`, `POST /notifications/read-all`.

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
- The Forum's *Experiences* section
