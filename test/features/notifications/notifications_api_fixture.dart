// Real responses of the backend, printed by backend/test/notifications.test.ts:
//   cd backend && PRINT_NOTIFICATIONS_JSON=1 npx jest test/notifications
// Copied as-is: if the API shape changes, paste the new output here.

/// `GET /api/notifications` for the demo student, right after
/// `seedNotifications(demo, now: 2026-11-05T09:30:00Z)` (10:30 in Tunis).
const seededNotificationsJson = r'''
[
  {
    "id": "room-change-gl",
    "category": "academic",
    "label": "Urgent Academic",
    "title": "Room Change: Génie Logiciel",
    "body": "Lecture today at **10:15** moved from ~~Amphi 3B~~ to ==Grand Amphi C== due to faculty seminar.",
    "receivedAt": "2026-11-05T09:15:00.000Z",
    "isRead": false,
    "isUrgent": true,
    "attachment": {
      "type": "place",
      "place": "Grand Amphi C, Pavillon Principal"
    },
    "link": {
      "destination": "timetable",
      "id": null
    }
  },
  {
    "id": "ride-confirmed-es-4091",
    "category": "covoiturage",
    "label": "Covoiturage",
    "title": "Ride Booking Confirmed with Sarra K.",
    "body": "Departure today at **13h15** from **Tunis Passage**. Tap to view car details and contact driver.",
    "receivedAt": "2026-11-05T08:30:00.000Z",
    "isRead": false,
    "isUrgent": false,
    "attachment": {
      "type": "ride",
      "driverName": "Sarra K.",
      "carLabel": "Clio 4 · Blanc glacier",
      "isDriverVerified": true
    },
    "link": {
      "destination": "ride",
      "id": "es-4091"
    }
  },
  {
    "id": "exam-timetable-s8",
    "category": "academic",
    "label": "Registrar Notice",
    "title": "Exam Timetable Published: Session Principale",
    "body": "Check your assigned exam dates and rooms for Semester 8 exams starting **June 2nd**. Download PDF convocation before May 30.",
    "receivedAt": "2026-11-04T13:30:00.000Z",
    "isRead": true,
    "isUrgent": false,
    "attachment": {
      "type": "schedule"
    },
    "link": {
      "destination": "timetable",
      "id": null
    }
  },
  {
    "id": "grade-bdd",
    "category": "academic",
    "label": "Grades",
    "title": "Nouvelle note publiée : Bases de Données",
    "body": "Your **DS** mark for Bases de Données is now available. Moyenne de la classe : **12.4**.",
    "receivedAt": "2026-11-04T08:10:00.000Z",
    "isRead": true,
    "isUrgent": false,
    "attachment": null,
    "link": {
      "destination": "grades",
      "id": null
    }
  },
  {
    "id": "lost-found-492",
    "category": "lostFound",
    "label": "Lost & Found",
    "title": "Potential match for your lost item",
    "body": "A calculator matching your description (Casio fx-991EX with purple sticker) was turned in at **Bloc C reception**.",
    "receivedAt": "2026-11-03T06:30:00.000Z",
    "isRead": true,
    "isUrgent": true,
    "attachment": {
      "type": "pickup",
      "availability": "Available for pickup until 17h00",
      "ticket": "492"
    },
    "link": {
      "destination": "forum",
      "id": null
    }
  },
  {
    "id": "forum-reply",
    "category": "community",
    "label": "Forum",
    "title": "Nouvelle réponse à votre annonce",
    "body": "**Youssef M.** a répondu à votre post covoiturage ==Passage → Ghazela==.",
    "receivedAt": "2026-11-03T03:30:00.000Z",
    "isRead": true,
    "isUrgent": false,
    "attachment": null,
    "link": {
      "destination": "forum",
      "id": null
    }
  },
  {
    "id": "job-instadeep-viewed",
    "category": "career",
    "label": "Career",
    "title": "Application viewed by InstaDeep",
    "body": "Your application for **Junior AI & ML Research Intern** was viewed by the recruiting team.",
    "receivedAt": "2026-11-02T07:30:00.000Z",
    "isRead": false,
    "isUrgent": false,
    "attachment": null,
    "link": {
      "destination": "job",
      "id": "instadeep-ml"
    }
  },
  {
    "id": "course-material-gl",
    "category": "academic",
    "label": "Course Update",
    "title": "New course material: Génie Logiciel",
    "body": "Prof. Ben Ali uploaded **Chapitre 7 – Design Patterns** slides and the TP 5 statement.",
    "receivedAt": "2026-11-01T08:30:00.000Z",
    "isRead": true,
    "isUrgent": false,
    "attachment": null,
    "link": {
      "destination": "courses",
      "id": null
    }
  },
  {
    "id": "carpool-digest",
    "category": "covoiturage",
    "label": "Covoiturage",
    "title": "Weekly carpool digest",
    "body": "**3 new rides** match your usual route Tunis Passage → Ghazela this week.",
    "receivedAt": "2026-10-31T05:30:00.000Z",
    "isRead": true,
    "isUrgent": false,
    "attachment": null,
    "link": {
      "destination": "forum",
      "id": null
    }
  }
]
''';

/// `GET /api/notifications` for a brand-new student (first visit).
const welcomeNotificationsJson = r'''
[
  {
    "id": "welcome",
    "category": "community",
    "label": "CampusPulse",
    "title": "Welcome to CampusPulse",
    "body": "Your timetable, rides, jobs and grades now live in one place. Campus alerts such as **room changes** and **new grades** will show up here.",
    "receivedAt": "2026-11-06T19:39:01.542Z",
    "isRead": false,
    "isUrgent": false,
    "attachment": null,
    "link": null
  }
]
''';
