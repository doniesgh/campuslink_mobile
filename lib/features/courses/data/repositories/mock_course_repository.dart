import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/course_logic.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_module.dart';
import '../../domain/entities/course_resource.dart';
import '../../domain/repositories/course_repository.dart';

/// In-memory fake. Replace with a Dio-based implementation when the API exists.
///
/// Dates (quizzes, deadlines) are relative to [clock] so the mock always looks
/// current. Attendance and submissions are kept for the app session.
class MockCourseRepository implements CourseRepository {
  MockCourseRepository({
    this.latency = const Duration(milliseconds: 400),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _clock;

  final _attendance = <String, bool>{};
  final _submissions = <String, String>{};

  @override
  Future<Result<List<Course>>> getCourses() async {
    await Future<void>.delayed(latency);
    return Success([
      for (final c in _seed(_clock()))
        c.copyWith(isPresent: _attendance[c.id]).withSubmissions(_submissions),
    ]);
  }

  @override
  Future<Result<void>> setAttendance(String courseId, {required bool present}) async {
    await Future<void>.delayed(latency);
    if (!_seed(_clock()).any((c) => c.id == courseId)) {
      return const Err(ServerFailure('Course not found.'));
    }
    _attendance[courseId] = present;
    return const Success(null);
  }

  @override
  Future<Result<void>> downloadResource(String resourceId) async {
    await Future<void>.delayed(latency * 2);
    final exists = _seed(_clock())
        .any((c) => c.resources.any((r) => r is DocumentResource && r.id == resourceId));
    return exists ? const Success(null) : const Err(ServerFailure('File not found.'));
  }

  @override
  Future<Result<void>> submitAssignment(String assignmentId, String repoUrl) async {
    await Future<void>.delayed(latency);
    if (!isValidRepoUrl(repoUrl)) {
      return const Err(ValidationFailure('Enter a valid https:// repository link.'));
    }
    final exists = _seed(_clock())
        .any((c) => c.resources.any((r) => r is AssignmentResource && r.id == assignmentId));
    if (!exists) return const Err(ServerFailure('Assignment not found.'));
    _submissions[assignmentId] = repoUrl.trim();
    return const Success(null);
  }

  static List<Course> _seed(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime inDays(int days, int hour, int minute) =>
        DateTime(today.year, today.month, today.day + days, hour, minute);
    // Next Friday, never today.
    final toFriday = (DateTime.friday - today.weekday + 7) % 7;

    List<CourseModule> modules(List<(String, int)> items, {required int completed}) => [
          for (var i = 0; i < items.length; i++)
            CourseModule(
              number: i + 1,
              title: items[i].$1,
              hours: items[i].$2,
              isCompleted: i < completed,
            ),
        ];

    return [
      Course(
        id: 'genie-logiciel',
        code: 'GLA-401',
        location: 'Block 2B',
        title: 'Génie Logiciel & Architecture',
        term: 'Winter Semester',
        track: 'Advanced Software Systems Track',
        professor: const Professor(
          title: 'Prof.',
          name: 'Ben Ali',
          office: 'Office Bloc B-114',
          email: 'benali@campus.edu',
          isOnline: true,
        ),
        // 36 of 50 hours done -> 72% mastery; 10 modules after 7 of 14
        // lectures -> ahead of schedule.
        modules: modules(
          const [
            ('Software Engineering Foundations', 3),
            ('Agile Lifecycles & Scrum', 3),
            ('Requirements Engineering', 4),
            ('UML Modeling', 4),
            ('Design Patterns', 3),
            ('Layered Architecture', 4),
            ('Microservices & REST APIs', 4),
            ('Clean Code & SOLID', 3),
            ('Unit Testing & TDD', 4),
            ('CI/CD Pipelines', 4),
            ('Docker Orchestration', 3),
            ('Kubernetes in Production', 4),
            ('Software Quality Metrics', 3),
            ('Architecture Final Project', 4),
          ],
          completed: 10,
        ),
        lecturesHeld: 7,
        lectureCount: 14,
        nextQuiz: CourseQuiz(topic: 'Arch Microservices', date: inDays(4, 10, 15)),
        resources: [
          DocumentResource(
            id: 'gl-lesson-7',
            title: 'Lesson 7: Microservices & REST APIs',
            format: 'PDF',
            sizeBytes: 4404019, // 4.2 MB
            updatedAt: today.subtract(const Duration(days: 24)),
          ),
          const VideoResource(
            id: 'gl-lesson-8',
            title: 'Lesson 8: Clean Code & SOLID',
            duration: Duration(minutes: 45),
            quality: '1080p',
          ),
          AssignmentResource(
            id: 'gl-lab-3',
            title: 'Lab 3: Docker Orchestration',
            description: 'Kubernetes cluster config & compose manifest',
            dueAt: inDays(toFriday == 0 ? 7 : toFriday, 23, 59),
            points: 20,
          ),
        ],
        community: const CourseCommunity(
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
        ),
        isPresent: true,
      ),
      Course(
        id: 'algo',
        code: 'ALG-302',
        location: 'Lab 14',
        title: 'Algorithmes & Complexité',
        term: 'Winter Semester',
        track: 'Core Computer Science Track',
        professor: const Professor(
          title: 'Dr.',
          name: 'Fersi',
          office: 'Office Bloc E-205',
          email: 'fersi@campus.edu',
        ),
        modules: modules(
          const [
            ('Asymptotic Complexity', 3),
            ('Recursion & Divide and Conquer', 3),
            ('Advanced Sorting', 3),
            ('Trees & Binary Search Trees', 3),
            ('Heaps & Priority Queues', 3),
            ('Hash Tables', 3),
            ('Dynamic Programming', 3),
            ('Greedy Algorithms', 3),
            ('Graph Traversals (BFS/DFS)', 3),
            ('Shortest Paths', 3),
            ('Flows & Matchings', 3),
            ('NP-Completeness', 3),
          ],
          completed: 6,
        ),
        lecturesHeld: 6,
        lectureCount: 12,
        nextQuiz: CourseQuiz(topic: 'Dynamic Programming', date: inDays(1, 8, 30)),
        resources: [
          DocumentResource(
            id: 'algo-lesson-6',
            title: 'Lesson 6: Hash Tables & Hashing',
            format: 'PDF',
            sizeBytes: 2936013, // 2.8 MB
            updatedAt: today.subtract(const Duration(days: 9)),
          ),
          AssignmentResource(
            id: 'algo-lab-4',
            title: 'Lab 4: Graph Traversals',
            description: 'BFS/DFS on the Tunis metro network',
            dueAt: inDays(9, 18, 0),
            points: 15,
          ),
        ],
        community: const CourseCommunity(
          onlineCount: 11,
          onlineClassmates: ['Omar Jebali', 'Nour Ayari', 'Hedi Kallel'],
        ),
        isPresent: true,
      ),
      Course(
        id: 'bases-de-donnees',
        code: 'BDD-303',
        location: 'Salle 208',
        title: 'Bases de Données',
        term: 'Winter Semester',
        track: 'Data Engineering Track',
        professor: const Professor(
          title: 'Dr.',
          name: 'Gharbi',
          office: 'Office Bloc C-310',
          email: 'gharbi@campus.edu',
          isOnline: true,
        ),
        modules: modules(
          const [
            ('Relational Model', 3),
            ('Relational Algebra', 3),
            ('SQL Fundamentals', 4),
            ('Advanced SQL & Joins', 3),
            ('Normalization (1NF to BCNF)', 4),
            ('Entity-Relationship Design', 3),
            ('Indexing & Query Plans', 4),
            ('Transactions & ACID', 3),
            ('Concurrency Control', 4),
            ('PL/SQL & Triggers', 3),
            ('NoSQL Overview', 4),
            ('Database Security', 3),
          ],
          completed: 7,
        ),
        lecturesHeld: 9,
        lectureCount: 12,
        resources: [
          DocumentResource(
            id: 'bdd-lesson-9',
            title: 'Lesson 9: Transactions & ACID',
            format: 'PDF',
            sizeBytes: 3250586, // 3.1 MB
            updatedAt: today.subtract(const Duration(days: 2)),
          ),
          const VideoResource(
            id: 'bdd-lesson-7',
            title: 'Lesson 7: Indexing & Query Plans',
            duration: Duration(minutes: 52),
            quality: '720p',
          ),
          AssignmentResource(
            id: 'bdd-tp-5',
            title: 'TP 5: PL/SQL Triggers',
            description: 'Audit triggers on the campus library schema',
            dueAt: inDays(2, 12, 0),
            points: 10,
            isMandatory: false,
          ),
        ],
        community: const CourseCommunity(onlineCount: 6),
      ),
    ];
  }
}
