import type { TimetableSlot } from './timetable.model';

// Demo weekly template, ported from the app's MockTimetableRepository.
// Every weekday has classes at 08:30, 10:15 and 13:30 (the courses change
// from day to day); Monday and Thursday end with an evaluation at 16:00.
// No classes on weekends.

/** The only class group for now: every student is in it. */
export const CLASS_GROUP = 'Tech Track 4BI';

type SlotInput = Pick<TimetableSlot, 'slotId' | 'weekday' | 'course' | 'room' | 'teacher'> &
  Partial<TimetableSlot> & { start: string; end: string };

const slot = (s: SlotInput): TimetableSlot => ({
  kind: 'lecture',
  lectureNumber: null,
  lectureCount: null,
  coefficient: null,
  notes: null,
  ...s,
});

const MONDAY = 1;
const TUESDAY = 2;
const WEDNESDAY = 3;
const THURSDAY = 4;
const FRIDAY = 5;

export const DEMO_TIMETABLE: TimetableSlot[] = [
  // Monday
  slot({
    slotId: 'algo-cm',
    weekday: MONDAY,
    course: 'Algorithmes & Complexité',
    room: 'Amphi A',
    teacher: 'Prof. Trabelsi',
    start: '08:30',
    end: '10:00',
    lectureNumber: 8,
    lectureCount: 14,
  }),
  slot({
    slotId: 'genie-logiciel-tp',
    weekday: MONDAY,
    course: 'Génie Logiciel & Architecture',
    room: 'Lab 204',
    teacher: 'Prof. Ben Ali',
    start: '10:15',
    end: '12:15',
    kind: 'lab',
  }),
  slot({
    slotId: 'nosql',
    weekday: MONDAY,
    course: 'Bases de Données Avancées (NoSQL)',
    room: 'Salle B12',
    teacher: 'Prof. Mansour',
    start: '13:30',
    end: '15:30',
    kind: 'workshop',
  }),
  slot({
    slotId: 'cc-reseaux',
    weekday: MONDAY,
    course: 'Contrôle Continu : Réseaux & Télécom',
    room: 'Grand Amphi C',
    teacher: 'Dr. Hammami',
    start: '16:00',
    end: '18:00',
    kind: 'exam',
    coefficient: 2.0,
    notes: 'Chapters 1–4 · Bring scientific calculator & Student ID',
  }),

  // Tuesday
  slot({
    slotId: 'algo',
    weekday: TUESDAY,
    course: 'Algorithmes & Complexité',
    room: 'Lab 14',
    teacher: 'Dr. Fersi',
    start: '08:30',
    end: '10:00',
    kind: 'lab',
  }),
  slot({
    slotId: 'genie-logiciel',
    weekday: TUESDAY,
    course: 'Génie Logiciel & Architecture',
    room: 'Amphi 3B',
    teacher: 'Prof. Ben Ali',
    start: '10:15',
    end: '12:15',
    lectureNumber: 7,
    lectureCount: 14,
  }),
  slot({
    slotId: 'bases-de-donnees',
    weekday: TUESDAY,
    course: 'Bases de Données',
    room: 'Salle 208',
    teacher: 'Dr. Gharbi',
    start: '13:30',
    end: '15:30',
    lectureNumber: 9,
    lectureCount: 12,
  }),

  // Wednesday
  slot({
    slotId: 'reseaux',
    weekday: WEDNESDAY,
    course: 'Réseaux & Télécom',
    room: 'Amphi B',
    teacher: 'Dr. Hammami',
    start: '08:30',
    end: '10:00',
    lectureNumber: 9,
    lectureCount: 14,
  }),
  slot({
    slotId: 'flutter-tp',
    weekday: WEDNESDAY,
    course: 'Développement Mobile (Flutter)',
    room: 'Lab 204',
    teacher: 'Ing. Jlassi',
    start: '10:15',
    end: '12:15',
    kind: 'lab',
  }),
  slot({
    slotId: 'pi',
    weekday: WEDNESDAY,
    course: 'Projet Intégré (PI)',
    room: 'Salle B12',
    teacher: 'Prof. Mansour',
    start: '13:30',
    end: '15:30',
    kind: 'workshop',
  }),

  // Thursday
  slot({
    slotId: 'algo',
    weekday: THURSDAY,
    course: 'Algorithmes & Complexité',
    room: 'Lab 14',
    teacher: 'Dr. Fersi',
    start: '08:30',
    end: '10:00',
    kind: 'lab',
  }),
  slot({
    slotId: 'genie-logiciel',
    weekday: THURSDAY,
    course: 'Génie Logiciel & Architecture',
    room: 'Amphi 3B',
    teacher: 'Prof. Ben Ali',
    start: '10:15',
    end: '12:15',
    lectureNumber: 8,
    lectureCount: 14,
  }),
  slot({
    slotId: 'bases-de-donnees',
    weekday: THURSDAY,
    course: 'Bases de Données',
    room: 'Salle 208',
    teacher: 'Dr. Gharbi',
    start: '13:30',
    end: '15:30',
    lectureNumber: 10,
    lectureCount: 12,
  }),
  slot({
    slotId: 'exam-flutter',
    weekday: THURSDAY,
    course: 'Examen TP : Développement Mobile',
    room: 'Lab 204',
    teacher: 'Ing. Jlassi',
    start: '16:00',
    end: '17:30',
    kind: 'exam',
    coefficient: 1.5,
    notes: 'Bring your laptop with the Flutter SDK installed',
  }),

  // Friday
  slot({
    slotId: 'stats',
    weekday: FRIDAY,
    course: 'Probabilités & Statistiques',
    room: 'Amphi A',
    teacher: 'Dr. Ayari',
    start: '08:30',
    end: '10:00',
    lectureNumber: 10,
    lectureCount: 14,
  }),
  slot({
    slotId: 'reseaux-tp',
    weekday: FRIDAY,
    course: 'Réseaux & Télécom',
    room: 'Lab 12',
    teacher: 'Dr. Hammami',
    start: '10:15',
    end: '12:15',
    kind: 'lab',
  }),
  slot({
    slotId: 'entrepreneuriat',
    weekday: FRIDAY,
    course: 'Entrepreneuriat & Innovation',
    room: 'Espace Coworking',
    teacher: 'Mme. Karoui',
    start: '13:30',
    end: '15:30',
    kind: 'workshop',
  }),
];
