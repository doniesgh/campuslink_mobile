import type { RelativeTime } from './campus-time';
import type { Course, CourseModule, CourseResource } from './courses.model';

// Demo catalog, ported from the app's MockCourseRepository (same ids, which
// other screens and notifications link to). Dates are relative to the day of
// the request: "in 4 days at 10:15", "next Friday at 23:59"...

type ResourceSeed = Omit<CourseResource, 'courseId' | 'position'>;
export type CourseSeed = Omit<Course, 'position'> & { resources: ResourceSeed[] };

const FRIDAY = 5;

const inDays = (days: number, time: string): RelativeTime => ({ inDays: days, time });
const daysAgo = (days: number): RelativeTime => ({ inDays: -days, time: '00:00' });

/** The syllabus, with the first [completed] modules done. */
const modules = (items: [string, number][], completed: number): CourseModule[] =>
  items.map(([title, hours], i) => ({ title, hours, isCompleted: i < completed }));

export const DEMO_COURSES: CourseSeed[] = [
  {
    _id: 'genie-logiciel',
    code: 'GLA-401',
    location: 'Block 2B',
    title: 'Génie Logiciel & Architecture',
    term: 'Winter Semester',
    track: 'Advanced Software Systems Track',
    professor: {
      title: 'Prof.',
      name: 'Ben Ali',
      office: 'Office Bloc B-114',
      email: 'benali@campus.edu',
      isOnline: true,
    },
    // 36 of 50 hours done -> 72% mastery; 10 modules after 7 of 14
    // lectures -> ahead of schedule.
    modules: modules(
      [
        ['Software Engineering Foundations', 3],
        ['Agile Lifecycles & Scrum', 3],
        ['Requirements Engineering', 4],
        ['UML Modeling', 4],
        ['Design Patterns', 3],
        ['Layered Architecture', 4],
        ['Microservices & REST APIs', 4],
        ['Clean Code & SOLID', 3],
        ['Unit Testing & TDD', 4],
        ['CI/CD Pipelines', 4],
        ['Docker Orchestration', 3],
        ['Kubernetes in Production', 4],
        ['Software Quality Metrics', 3],
        ['Architecture Final Project', 4],
      ],
      10,
    ),
    lecturesHeld: 7,
    lectureCount: 14,
    nextQuiz: { topic: 'Arch Microservices', at: inDays(4, '10:15') },
    resources: [
      {
        _id: 'gl-lesson-7',
        type: 'document',
        title: 'Lesson 7: Microservices & REST APIs',
        format: 'PDF',
        sizeBytes: 4404019, // 4.2 MB
        updated: daysAgo(24),
      },
      {
        _id: 'gl-lesson-8',
        type: 'video',
        title: 'Lesson 8: Clean Code & SOLID',
        durationSeconds: 45 * 60,
        quality: '1080p',
      },
      {
        _id: 'gl-lab-3',
        type: 'assignment',
        title: 'Lab 3: Docker Orchestration',
        description: 'Kubernetes cluster config & compose manifest',
        // Next Friday, never today.
        due: { weekday: FRIDAY, time: '23:59' },
        points: 20,
        isMandatory: true,
      },
    ],
    community: {
      onlineCount: 24,
      onlineClassmates: [
        'Yasmine Trabelsi',
        'Omar Jebali',
        'Ines Hammami',
        'Mehdi Bouzid',
        'Sarra Chaouch',
        'Aziz Mabrouk',
        'Nour Ayari',
        'Karim Ferchichi',
        'Rania Mansour',
        'Hedi Kallel',
      ],
    },
  },
  {
    _id: 'algo',
    code: 'ALG-302',
    location: 'Lab 14',
    title: 'Algorithmes & Complexité',
    term: 'Winter Semester',
    track: 'Core Computer Science Track',
    professor: {
      title: 'Dr.',
      name: 'Fersi',
      office: 'Office Bloc E-205',
      email: 'fersi@campus.edu',
      isOnline: false,
    },
    modules: modules(
      [
        ['Asymptotic Complexity', 3],
        ['Recursion & Divide and Conquer', 3],
        ['Advanced Sorting', 3],
        ['Trees & Binary Search Trees', 3],
        ['Heaps & Priority Queues', 3],
        ['Hash Tables', 3],
        ['Dynamic Programming', 3],
        ['Greedy Algorithms', 3],
        ['Graph Traversals (BFS/DFS)', 3],
        ['Shortest Paths', 3],
        ['Flows & Matchings', 3],
        ['NP-Completeness', 3],
      ],
      6,
    ),
    lecturesHeld: 6,
    lectureCount: 12,
    nextQuiz: { topic: 'Dynamic Programming', at: inDays(1, '08:30') },
    resources: [
      {
        _id: 'algo-lesson-6',
        type: 'document',
        title: 'Lesson 6: Hash Tables & Hashing',
        format: 'PDF',
        sizeBytes: 2936013, // 2.8 MB
        updated: daysAgo(9),
      },
      {
        _id: 'algo-lab-4',
        type: 'assignment',
        title: 'Lab 4: Graph Traversals',
        description: 'BFS/DFS on the Tunis metro network',
        due: inDays(9, '18:00'),
        points: 15,
        isMandatory: true,
      },
    ],
    community: {
      onlineCount: 11,
      onlineClassmates: ['Omar Jebali', 'Nour Ayari', 'Hedi Kallel'],
    },
  },
  {
    _id: 'bases-de-donnees',
    code: 'BDD-303',
    location: 'Salle 208',
    title: 'Bases de Données',
    term: 'Winter Semester',
    track: 'Data Engineering Track',
    professor: {
      title: 'Dr.',
      name: 'Gharbi',
      office: 'Office Bloc C-310',
      email: 'gharbi@campus.edu',
      isOnline: true,
    },
    modules: modules(
      [
        ['Relational Model', 3],
        ['Relational Algebra', 3],
        ['SQL Fundamentals', 4],
        ['Advanced SQL & Joins', 3],
        ['Normalization (1NF to BCNF)', 4],
        ['Entity-Relationship Design', 3],
        ['Indexing & Query Plans', 4],
        ['Transactions & ACID', 3],
        ['Concurrency Control', 4],
        ['PL/SQL & Triggers', 3],
        ['NoSQL Overview', 4],
        ['Database Security', 3],
      ],
      7,
    ),
    lecturesHeld: 9,
    lectureCount: 12,
    nextQuiz: null,
    resources: [
      {
        _id: 'bdd-lesson-9',
        type: 'document',
        title: 'Lesson 9: Transactions & ACID',
        format: 'PDF',
        sizeBytes: 3250586, // 3.1 MB
        updated: daysAgo(2),
      },
      {
        _id: 'bdd-lesson-7',
        type: 'video',
        title: 'Lesson 7: Indexing & Query Plans',
        durationSeconds: 52 * 60,
        quality: '720p',
      },
      {
        _id: 'bdd-tp-5',
        type: 'assignment',
        title: 'TP 5: PL/SQL Triggers',
        description: 'Audit triggers on the campus library schema',
        due: inDays(2, '12:00'),
        points: 10,
        isMandatory: false,
      },
    ],
    community: { onlineCount: 6, onlineClassmates: [] },
  },
];

/** Courses where the demo student has logged attendance (as in the mock). */
export const DEMO_PRESENT_COURSE_IDS = ['genie-logiciel', 'algo'];
