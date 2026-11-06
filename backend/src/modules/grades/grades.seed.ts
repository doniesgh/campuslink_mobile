import type { Types } from 'mongoose';

import { TranscriptModel, type StoredCourse, type StoredSemester } from './transcript.model';

const DEAN = 'Dean Marc Lefèvre';

const course = (
  code: string,
  title: string,
  coefficient: number,
  credits: number,
  continuous: number | null,
  exam: number | null,
): StoredCourse => ({ code, title, coefficient, credits, continuous, exam });

/**
 * The marks of the app's MockGradesRepository: the three semesters before
 * the current one (in November 2026: Sem 6 and 5 of 2025–2026, Sem 4 of
 * 2024–2025). The app computes 16.57, 16.22 and 12.29 from them, with one
 * compensated course in the oldest semester.
 */
export const DEMO_SEMESTERS: StoredSemester[] = [
  {
    // The design's "Sem 8" content, updated 2 hours before the request.
    semestersAgo: 1,
    rank: 7,
    cohortSize: 142,
    signedBy: DEAN,
    documentSizeMb: 1.4,
    updatedHoursAgo: 2,
    courses: [
      course('CS-401', 'Génie Logiciel & Microservices', 3, 10, 17.5, 16),
      course('DB-408', 'Conception & BDD NoSQL', 2.5, 8, 18, 15.5),
      course('SEC-402', 'Réseaux & Sécurité Informatique', 2, 7, 14.5, 15),
      // Language course: continuous assessment only, no final exam.
      course('HUM-304', 'Anglais Pro & Soft Skills', 1.5, 5, 19, null),
    ],
  },
  {
    // Same course names as the timetable.
    semestersAgo: 2,
    rank: 11,
    cohortSize: 142,
    signedBy: DEAN,
    documentSizeMb: 1.3,
    updatedHoursAgo: null,
    courses: [
      course('CS-305', 'Algorithmes & Complexité', 3, 10, 16, 15.5),
      course('CS-307', 'Génie Logiciel & Architecture', 2.5, 8, 17, 16.5),
      course('DB-306', 'Bases de Données', 2, 7, 15.5, 16),
      course('MATH-302', 'Probabilités & Statistiques', 1.5, 5, 17, 17),
    ],
  },
  {
    semestersAgo: 3,
    rank: 48,
    cohortSize: 140,
    signedBy: DEAN,
    documentSizeMb: 1.2,
    updatedHoursAgo: null,
    courses: [
      course('CS-301', 'Programmation Orientée Objet', 3, 10, 14, 13),
      // 9.10/20, compensated by the semester average.
      course('MATH-303', 'Analyse Numérique', 2.5, 8, 10, 8.5),
      course('SYS-304', "Systèmes d'Exploitation", 2, 7, 13.5, 12),
      course('HUM-204', 'Français & Communication', 1.5, 5, 15, null),
    ],
  },
];

/**
 * Demo data for this module. Called by `npm run seed` with the demo
 * student's id. Must be idempotent (safe to run again).
 */
export async function seedGrades(demoUserId: Types.ObjectId): Promise<void> {
  await TranscriptModel.findOneAndUpdate(
    { userId: demoUserId },
    { $set: { semesters: DEMO_SEMESTERS } },
    { upsert: true, runValidators: true },
  );
}
