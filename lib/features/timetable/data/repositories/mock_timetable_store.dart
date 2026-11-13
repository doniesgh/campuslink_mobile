import '../../domain/entities/class_session.dart';
import '../../domain/entities/timetable_slot.dart';

/// The weekly timetable of the demo mode, in memory: read by the student
/// screens (MockTimetableRepository), edited by the admin screens
/// (MockTimetableAdminRepository). Same classes and ids as the API's seed
/// (backend/src/modules/timetable/timetable.data.ts).
class MockTimetableStore {
  MockTimetableStore([List<TimetableSlot>? slots]) : slots = [...(slots ?? demoSlots)];

  static const classGroup = 'Tech Track 4BI';

  /// The (fake) Google Meet link of the demo's online class.
  static const demoMeetUrl = 'https://meet.google.com/xqd-fkzw-pnb';

  /// Edited in place by the admin mock.
  final List<TimetableSlot> slots;

  static const demoSlots = <TimetableSlot>[
    // Monday
    TimetableSlot(
      id: 'algo-cm', weekday: 1, start: '08:30', end: '10:00',
      course: 'Algorithmes & Complexité', room: 'Amphi A', teacher: 'Prof. Trabelsi',
      lectureNumber: 8, lectureCount: 14,
    ),
    TimetableSlot(
      id: 'genie-logiciel-tp', weekday: 1, start: '10:15', end: '12:15',
      course: 'Génie Logiciel & Architecture', room: 'Lab 204', teacher: 'Prof. Ben Ali',
      kind: SessionKind.lab,
    ),
    TimetableSlot(
      id: 'nosql', weekday: 1, start: '13:30', end: '15:30',
      course: 'Bases de Données Avancées (NoSQL)', room: 'Salle B12', teacher: 'Prof. Mansour',
      kind: SessionKind.workshop,
    ),
    TimetableSlot(
      id: 'cc-reseaux', weekday: 1, start: '16:00', end: '18:00',
      course: 'Contrôle Continu : Réseaux & Télécom', room: 'Grand Amphi C',
      teacher: 'Dr. Hammami', kind: SessionKind.exam, coefficient: 2.0,
      notes: 'Chapters 1–4 · Bring scientific calculator & Student ID',
    ),
    // Tuesday
    TimetableSlot(
      id: 'algo', weekday: 2, start: '08:30', end: '10:00',
      course: 'Algorithmes & Complexité', room: 'Lab 14', teacher: 'Dr. Fersi',
      kind: SessionKind.lab,
    ),
    TimetableSlot(
      id: 'genie-logiciel', weekday: 2, start: '10:15', end: '12:15',
      course: 'Génie Logiciel & Architecture', room: 'Amphi 3B', teacher: 'Prof. Ben Ali',
      lectureNumber: 7, lectureCount: 14,
    ),
    TimetableSlot(
      id: 'bases-de-donnees', weekday: 2, start: '13:30', end: '15:30',
      course: 'Bases de Données', room: 'Salle 208', teacher: 'Dr. Gharbi',
      lectureNumber: 9, lectureCount: 12,
    ),
    // Wednesday
    TimetableSlot(
      id: 'reseaux', weekday: 3, start: '08:30', end: '10:00',
      course: 'Réseaux & Télécom', room: 'Amphi B', teacher: 'Dr. Hammami',
      lectureNumber: 9, lectureCount: 14,
    ),
    TimetableSlot(
      id: 'flutter-tp', weekday: 3, start: '10:15', end: '12:15',
      course: 'Développement Mobile (Flutter)', room: 'Lab 204', teacher: 'Ing. Jlassi',
      kind: SessionKind.lab,
    ),
    TimetableSlot(
      id: 'pi', weekday: 3, start: '13:30', end: '15:30',
      course: 'Projet Intégré (PI)', room: 'Salle B12', teacher: 'Prof. Mansour',
      kind: SessionKind.workshop,
    ),
    // Thursday
    TimetableSlot(
      id: 'algo-thu', weekday: 4, start: '08:30', end: '10:00',
      course: 'Algorithmes & Complexité', room: 'Lab 14', teacher: 'Dr. Fersi',
      kind: SessionKind.lab,
    ),
    TimetableSlot(
      id: 'genie-logiciel-thu', weekday: 4, start: '10:15', end: '12:15',
      course: 'Génie Logiciel & Architecture', room: 'Amphi 3B', teacher: 'Prof. Ben Ali',
      lectureNumber: 8, lectureCount: 14,
    ),
    TimetableSlot(
      id: 'bases-de-donnees-thu', weekday: 4, start: '13:30', end: '15:30',
      course: 'Bases de Données', room: 'Salle 208', teacher: 'Dr. Gharbi',
      lectureNumber: 10, lectureCount: 12,
    ),
    TimetableSlot(
      id: 'exam-flutter', weekday: 4, start: '16:00', end: '17:30',
      course: 'Examen TP : Développement Mobile', room: 'Lab 204', teacher: 'Ing. Jlassi',
      kind: SessionKind.exam, coefficient: 1.5,
      notes: 'Bring your laptop with the Flutter SDK installed',
    ),
    // Friday
    TimetableSlot(
      id: 'stats', weekday: 5, start: '08:30', end: '10:00',
      course: 'Probabilités & Statistiques', room: 'Amphi A', teacher: 'Dr. Ayari',
      lectureNumber: 10, lectureCount: 14,
    ),
    TimetableSlot(
      id: 'reseaux-tp', weekday: 5, start: '10:15', end: '12:15',
      course: 'Réseaux & Télécom', room: 'Lab 12', teacher: 'Dr. Hammami',
      kind: SessionKind.lab,
    ),
    TimetableSlot(
      id: 'entrepreneuriat', weekday: 5, start: '13:30', end: '15:30',
      course: 'Entrepreneuriat & Innovation', teacher: 'Mme. Karoui',
      kind: SessionKind.workshop, mode: SessionMode.online, meetUrl: demoMeetUrl,
    ),
  ];
}
