import 'package:campuspulse/features/courses/domain/course_logic.dart';
import 'package:campuspulse/features/courses/domain/entities/course.dart';
import 'package:campuspulse/features/courses/domain/entities/course_module.dart';
import 'package:campuspulse/features/courses/domain/entities/course_resource.dart';
import 'package:flutter_test/flutter_test.dart';

CourseModule _m(int number, int hours, {bool done = false}) =>
    CourseModule(number: number, title: 'M$number', hours: hours, isCompleted: done);

Course _course(String id, {List<CourseResource> resources = const []}) => Course(
      id: id,
      code: 'C-$id',
      location: 'Salle 1',
      title: 'Course $id',
      term: 'Winter Semester',
      track: 'Track',
      professor: const Professor(title: 'Dr.', name: 'X', office: 'B-1', email: 'x@campus.edu'),
      modules: [_m(1, 3, done: true), _m(2, 2)],
      lecturesHeld: 1,
      lectureCount: 2,
      resources: resources,
      community: const CourseCommunity(onlineCount: 0),
    );

void main() {
  group('mastery', () {
    test('weighs modules by their hours', () {
      final modules = [_m(1, 3, done: true), _m(2, 2), _m(3, 5, done: true)];
      expect(masteryHours(modules), (done: 8, total: 10));
      expect(masteryRatio(modules), 0.8);
    });

    test('empty syllabus is 0', () {
      expect(masteryRatio(const []), 0);
      expect(masteryRatio([_m(1, 0)]), 0);
    });

    test('Course getters', () {
      final c = _course('a');
      expect(c.completedModules, 1);
      expect(c.mastery, 0.6);
      expect(c.masteryPercent, 60);
    });
  });

  group('coursePace', () {
    CoursePace pace(int done, int total, int held, int count) => coursePace(
          completedModules: done,
          totalModules: total,
          lecturesHeld: held,
          lectureCount: count,
        );

    test('ahead when a full module or more past the lectures', () {
      expect(pace(10, 14, 7, 14), CoursePace.ahead);
      expect(pace(8, 14, 7, 14), CoursePace.ahead);
    });

    test('on track within one module', () {
      expect(pace(6, 12, 6, 12), CoursePace.onTrack);
      expect(pace(5, 10, 5, 9), CoursePace.onTrack); // expected 5.56
    });

    test('behind when a full module or more late', () {
      expect(pace(7, 12, 9, 12), CoursePace.behind);
      expect(pace(6, 14, 7, 14), CoursePace.behind);
    });

    test('degenerate inputs are on track, extra lectures are clamped', () {
      expect(pace(3, 0, 2, 4), CoursePace.onTrack);
      expect(pace(3, 6, 2, 0), CoursePace.onTrack);
      expect(pace(12, 12, 20, 12), CoursePace.onTrack);
    });
  });

  group('splitModules / nextModule', () {
    final modules = [_m(3, 1), _m(1, 1, done: true), _m(4, 1, done: true), _m(2, 1)];

    test('splits and sorts by syllabus order', () {
      final split = splitModules(modules);
      expect(split.completed.map((m) => m.number), [1, 4]);
      expect(split.upcoming.map((m) => m.number), [2, 3]);
    });

    test('next module is the first not completed', () {
      expect(nextModule(modules)?.number, 2);
      expect(nextModule([_m(1, 1, done: true)]), isNull);
      expect(nextModule(const []), isNull);
    });
  });

  group('daysUntil', () {
    final now = DateTime(2026, 11, 5, 23, 59);

    test('counts calendar days, not 24h periods', () {
      expect(daysUntil(DateTime(2026, 11, 5, 8), now), 0);
      expect(daysUntil(DateTime(2026, 11, 6, 0, 1), now), 1);
      expect(daysUntil(DateTime(2026, 11, 9, 10, 15), now), 4);
      expect(daysUntil(DateTime(2026, 11, 4, 23), now), -1);
    });

    test('across a month boundary', () {
      expect(daysUntil(DateTime(2026, 11, 2), DateTime(2026, 10, 30, 12)), 3);
    });
  });

  group('selectCourse', () {
    final courses = [_course('a'), _course('b')];

    test('finds by id or title, falls back to the first', () {
      expect(selectCourse(courses, 'b')?.id, 'b');
      expect(selectCourse(courses, 'Course b')?.id, 'b');
      expect(selectCourse(courses, 'zzz')?.id, 'a');
      expect(selectCourse(courses, null)?.id, 'a');
    });

    test('null when there are no courses', () {
      expect(selectCourse(const [], 'a'), isNull);
    });
  });

  group('isValidRepoUrl', () {
    test('accepts https links to a repository', () {
      expect(isValidRepoUrl('https://github.com/raed/docker-lab'), isTrue);
      expect(isValidRepoUrl('  https://gitlab.com/esprit/gl/lab-3  '), isTrue);
    });

    test('rejects anything else', () {
      expect(isValidRepoUrl(''), isFalse);
      expect(isValidRepoUrl('github.com/raed/docker-lab'), isFalse);
      expect(isValidRepoUrl('http://github.com/raed/docker-lab'), isFalse);
      expect(isValidRepoUrl('https://github.com/raed'), isFalse);
      expect(isValidRepoUrl('https://localhost/raed/lab'), isFalse);
      expect(isValidRepoUrl('https://github.com/raed/docker lab'), isFalse);
    });
  });

  test('withSubmissions marks only the listed assignments', () {
    final lab1 = AssignmentResource(
      id: 'lab-1',
      title: 'Lab 1',
      description: 'd',
      dueAt: DateTime(2026, 11, 6),
      points: 10,
    );
    final lab2 = AssignmentResource(
      id: 'lab-2',
      title: 'Lab 2',
      description: 'd',
      dueAt: DateTime(2026, 11, 6),
      points: 10,
    );
    final c = _course('a', resources: [lab1, lab2]);
    final updated = c.withSubmissions({'lab-2': 'https://github.com/a/b'});
    final labs = updated.resources.cast<AssignmentResource>();
    expect(labs.first.isSubmitted, isFalse);
    expect(labs.last.submittedRepoUrl, 'https://github.com/a/b');
    expect(identical(c.withSubmissions(const {}), c), isTrue);
  });
}
