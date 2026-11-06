import type { Types } from 'mongoose';

import { NotificationModel } from './notification.model';

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

/** Tunisia is UTC+1 all year (no daylight saving time). */
const TUNIS_OFFSET = HOUR;

/** [days] calendar days before [now], at [hour]:[minute] Tunis time. */
function tunisDaysAgoAt(now: Date, days: number, hour: number, minute: number): Date {
  const tunis = new Date(now.getTime() + TUNIS_OFFSET); // its UTC fields read Tunis wall-clock time
  return new Date(
    Date.UTC(tunis.getUTCFullYear(), tunis.getUTCMonth(), tunis.getUTCDate() - days, hour, minute) -
      TUNIS_OFFSET,
  );
}

/**
 * The 9 notifications of the app's MockNotificationRepository, with the same
 * ids, read states, attachments and links (3 unread, 2 of them today).
 *
 * Times are relative to [now], the moment the seed runs ("15 min ago",
 * "yesterday 14:30"...), and then stored as fixed instants. They age like
 * real notifications: run `npm run seed` again to bring them back to "now".
 */
export function demoNotifications(now: Date) {
  const ago = (ms: number) => new Date(now.getTime() - ms);
  return [
    {
      key: 'room-change-gl',
      category: 'academic',
      label: 'Urgent Academic',
      title: 'Room Change: Génie Logiciel',
      body:
        'Lecture today at **10:15** moved from ~~Amphi 3B~~ to ' +
        '==Grand Amphi C== due to faculty seminar.',
      receivedAt: ago(15 * MINUTE),
      isRead: false,
      isUrgent: true,
      attachment: { type: 'place', place: 'Grand Amphi C, Pavillon Principal' },
      link: { destination: 'timetable', id: null },
    },
    {
      key: 'ride-confirmed-es-4091',
      category: 'covoiturage',
      label: 'Covoiturage',
      title: 'Ride Booking Confirmed with Sarra K.',
      body:
        'Departure today at **13h15** from **Tunis Passage**. ' +
        'Tap to view car details and contact driver.',
      receivedAt: ago(1 * HOUR),
      isRead: false,
      isUrgent: false,
      attachment: {
        type: 'ride',
        driverName: 'Sarra K.',
        carLabel: 'Clio 4 · Blanc glacier',
        isDriverVerified: true,
      },
      // Ride 'es-4091' of the carpool seed.
      link: { destination: 'ride', id: 'es-4091' },
    },
    {
      key: 'exam-timetable-s8',
      category: 'academic',
      label: 'Registrar Notice',
      title: 'Exam Timetable Published: Session Principale',
      body:
        'Check your assigned exam dates and rooms for Semester 8 exams starting ' +
        '**June 2nd**. Download PDF convocation before May 30.',
      receivedAt: tunisDaysAgoAt(now, 1, 14, 30),
      isRead: true,
      isUrgent: false,
      attachment: { type: 'schedule' },
      link: { destination: 'timetable', id: null },
    },
    {
      key: 'grade-bdd',
      category: 'academic',
      label: 'Grades',
      title: 'Nouvelle note publiée : Bases de Données',
      body:
        'Your **DS** mark for Bases de Données is now available. ' +
        'Moyenne de la classe : **12.4**.',
      receivedAt: tunisDaysAgoAt(now, 1, 9, 10),
      isRead: true,
      isUrgent: false,
      attachment: null,
      link: { destination: 'grades', id: null },
    },
    {
      key: 'lost-found-492',
      category: 'lostFound',
      label: 'Lost & Found',
      title: 'Potential match for your lost item',
      body:
        'A calculator matching your description (Casio fx-991EX with purple ' +
        'sticker) was turned in at **Bloc C reception**.',
      receivedAt: ago(2 * DAY + 3 * HOUR),
      isRead: true,
      isUrgent: true,
      attachment: {
        type: 'pickup',
        availability: 'Available for pickup until 17h00',
        ticket: '492',
      },
      link: { destination: 'forum', id: null },
    },
    {
      key: 'forum-reply',
      category: 'community',
      label: 'Forum',
      title: 'Nouvelle réponse à votre annonce',
      body: '**Youssef M.** a répondu à votre post covoiturage ==Passage → Ghazela==.',
      receivedAt: ago(2 * DAY + 6 * HOUR),
      isRead: true,
      isUrgent: false,
      attachment: null,
      link: { destination: 'forum', id: null },
    },
    {
      key: 'job-instadeep-viewed',
      category: 'career',
      label: 'Career',
      title: 'Application viewed by InstaDeep',
      body:
        'Your application for **Junior AI & ML Research Intern** was viewed ' +
        'by the recruiting team.',
      receivedAt: ago(3 * DAY + 2 * HOUR),
      isRead: false,
      isUrgent: false,
      attachment: null,
      // Job 'instadeep-ml' of the jobs seed.
      link: { destination: 'job', id: 'instadeep-ml' },
    },
    {
      key: 'course-material-gl',
      category: 'academic',
      label: 'Course Update',
      title: 'New course material: Génie Logiciel',
      body:
        'Prof. Ben Ali uploaded **Chapitre 7 – Design Patterns** slides ' +
        'and the TP 5 statement.',
      receivedAt: ago(4 * DAY + 1 * HOUR),
      isRead: true,
      isUrgent: false,
      attachment: null,
      link: { destination: 'courses', id: null },
    },
    {
      key: 'carpool-digest',
      category: 'covoiturage',
      label: 'Covoiturage',
      title: 'Weekly carpool digest',
      body: '**3 new rides** match your usual route Tunis Passage → Ghazela this week.',
      receivedAt: ago(5 * DAY + 4 * HOUR),
      isRead: true,
      isUrgent: false,
      attachment: null,
      link: { destination: 'forum', id: null },
    },
  ];
}

/**
 * Demo data for this module. Called by `npm run seed` with the demo
 * student's id. Idempotent: it resets the demo student's feed to the 9 demo
 * notifications (read states included) with times relative to now.
 */
export async function seedNotifications(
  demoUserId: Types.ObjectId,
  now: Date = new Date(),
): Promise<void> {
  await NotificationModel.deleteMany({ userId: demoUserId });
  await NotificationModel.insertMany(
    demoNotifications(now).map((n) => ({ ...n, userId: demoUserId })),
  );
}
