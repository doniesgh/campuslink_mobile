import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/courses/data/repositories/mock_course_repository.dart';
import 'package:campuspulse/features/courses/domain/course_logic.dart';
import 'package:campuspulse/features/courses/domain/entities/course.dart';
import 'package:campuspulse/features/courses/domain/entities/course_resource.dart';
import 'package:flutter_test/flutter_test.dart';

final _thursday = DateTime(2026, 11, 5, 9);

MockCourseRepository _repo([DateTime? now]) =>
    MockCourseRepository(latency: Duration.zero, clock: () => now ?? _thursday);

Future<List<Course>> _courses(MockCourseRepository repo) async =>
    (await repo.getCourses()).unwrap();

void main() {
  test('Génie Logiciel matches the design', () async {
    final gl = (await _courses(_repo())).first;
    expect(gl.id, 'genie-logiciel'); // same id as the timetable session
    expect(gl.code, 'GLA-401');
    expect(gl.completedModules, 10);
    expect(gl.modules.length, 14);
    expect(gl.masteryPercent, 72);
    expect(gl.pace, CoursePace.ahead);
    expect(gl.isPresent, isTrue);
    expect(daysUntil(gl.nextQuiz!.date, _thursday), 4);
    expect(gl.resources.length, 3);
    final lab = gl.resources.whereType<AssignmentResource>().single;
    expect(lab.dueAt, DateTime(2026, 11, 6, 23, 59)); // Friday
    expect(gl.community.onlineClassmates.length - 2, 8); // "+8" bubble
  });

  test('other courses give the other paces', () async {
    final courses = await _courses(_repo());
    expect(courses.map((c) => c.id), ['genie-logiciel', 'algo', 'bases-de-donnees']);
    expect(courses[1].pace, CoursePace.onTrack);
    expect(courses[2].pace, CoursePace.behind);
    expect(courses[2].nextQuiz, isNull);
  });

  test('the lab is due next Friday, never today', () async {
    final friday = DateTime(2026, 11, 6, 9);
    final gl = (await _courses(_repo(friday))).first;
    final lab = gl.resources.whereType<AssignmentResource>().single;
    expect(lab.dueAt, DateTime(2026, 11, 13, 23, 59));
  });

  test('attendance is kept', () async {
    final repo = _repo();
    expect(await repo.setAttendance('genie-logiciel', present: false), isA<Success<void>>());
    expect((await _courses(repo)).first.isPresent, isFalse);
    final unknown = await repo.setAttendance('nope', present: true);
    expect((unknown as Err<void>).failure, isA<ServerFailure>());
  });

  test('submissions are validated and kept', () async {
    final repo = _repo();
    final invalid = await repo.submitAssignment('gl-lab-3', 'github.com/me/lab');
    expect((invalid as Err<void>).failure, isA<ValidationFailure>());

    final ok = await repo.submitAssignment('gl-lab-3', ' https://github.com/me/lab ');
    expect(ok, isA<Success<void>>());
    final lab = (await _courses(repo)).first.resources.whereType<AssignmentResource>().single;
    expect(lab.submittedRepoUrl, 'https://github.com/me/lab');

    final unknown = await repo.submitAssignment('nope', 'https://github.com/me/lab');
    expect((unknown as Err<void>).failure, isA<ServerFailure>());
  });

  test('downloads only existing documents', () async {
    final repo = _repo();
    expect(await repo.downloadResource('gl-lesson-7'), isA<Success<void>>());
    expect(await repo.downloadResource('gl-lesson-8'), isA<Err<void>>()); // a video
  });
}
