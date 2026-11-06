import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/courses/data/models/course_models.dart';
import 'package:campuspulse/features/courses/data/repositories/course_repository_impl.dart';
import 'package:campuspulse/features/courses/data/repositories/mock_course_repository.dart';
import 'package:campuspulse/features/courses/domain/course_logic.dart';
import 'package:campuspulse/features/courses/domain/entities/course.dart';
import 'package:campuspulse/features/courses/domain/entities/course_resource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real `GET /api/courses` response, produced by the backend tests
/// (backend/test/courses.test.ts): the seeded demo student on Thursday
/// 5 November 2026 at 09:00 campus time, after submitting gl-lab-3.
List<dynamic> _coursesFixture() =>
    jsonDecode(File('test/features/courses/fixtures/courses.json').readAsStringSync())
        as List<dynamic>;

List<Course> _parse(List<dynamic> json) =>
    [for (final c in json) courseFromJson(c as Map<String, dynamic>)];

/// Answers every request with [respond] and records it.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final (int, Object?) Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = respond(options);
    if (body == null) return ResponseBody.fromString('', status);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(CourseRepositoryImpl, _FakeAdapter) _repo((int, Object?) Function(RequestOptions) respond) {
  final adapter = _FakeAdapter(respond);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'))..httpClientAdapter = adapter;
  return (CourseRepositoryImpl(dio), adapter);
}

void main() {
  group('backend JSON', () {
    test('parses into the courses the app shows', () {
      final courses = _parse(_coursesFixture());
      expect(courses.map((c) => c.id), ['genie-logiciel', 'algo', 'bases-de-donnees']);

      final gl = courses[0];
      expect(gl.code, 'GLA-401');
      expect(gl.professor.displayName, 'Prof. Ben Ali');
      expect(gl.professor.isOnline, isTrue);
      expect(gl.modules, hasLength(14));
      expect(gl.modules.first.number, 1);
      expect(gl.completedModules, 10);
      expect(gl.masteryPercent, 72);
      expect(gl.pace, CoursePace.ahead);
      expect(gl.isPresent, isTrue);
      expect(gl.community.onlineCount, 24);
      expect(gl.community.onlineClassmates, hasLength(10));

      // Instants, in local time.
      expect(gl.nextQuiz!.topic, 'Arch Microservices');
      expect(gl.nextQuiz!.date, DateTime.utc(2026, 11, 9, 9, 15).toLocal());
      expect(gl.nextQuiz!.date.isUtc, isFalse);

      final doc = gl.resources[0] as DocumentResource;
      expect(doc.id, 'gl-lesson-7');
      expect(doc.format, 'PDF');
      expect(doc.sizeBytes, 4404019);
      expect(doc.updatedAt, DateTime.utc(2026, 10, 11, 23).toLocal());

      final video = gl.resources[1] as VideoResource;
      expect(video.duration, const Duration(minutes: 45));
      expect(video.quality, '1080p');

      final lab = gl.resources[2] as AssignmentResource;
      expect(lab.id, 'gl-lab-3');
      expect(lab.dueAt, DateTime.utc(2026, 11, 6, 22, 59).toLocal()); // Friday 23:59 in Tunis
      expect(lab.points, 20);
      expect(lab.isMandatory, isTrue);
      expect(lab.submittedRepoUrl, 'https://github.com/dony/docker-lab');

      expect(courses[1].pace, CoursePace.onTrack);
      expect(courses[1].isPresent, isTrue);
      final bdd = courses[2];
      expect(bdd.pace, CoursePace.behind);
      expect(bdd.isPresent, isFalse);
      expect(bdd.nextQuiz, isNull);
      final tp = bdd.resources.whereType<AssignmentResource>().single;
      expect(tp.isMandatory, isFalse);
      expect(tp.isSubmitted, isFalse);
    });

    test('has the same content as the mock repository', () async {
      final api = _parse(_coursesFixture());
      final mock = (await MockCourseRepository(latency: Duration.zero).getCourses()).unwrap();

      expect(api.map(_describe), mock.map(_describe));
      for (var i = 0; i < api.length; i++) {
        expect(api[i].resources.map(_describeResource), mock[i].resources.map(_describeResource));
        expect(api[i].nextQuiz?.topic, mock[i].nextQuiz?.topic);
      }
    });

    test('skips resource types this app does not know', () {
      final json = _coursesFixture();
      final gl = Map<String, dynamic>.of(json.first as Map<String, dynamic>);
      gl['resources'] = [
        ...gl['resources'] as List,
        {'type': 'podcast', 'id': 'gl-podcast-1', 'title': 'Episode 1'},
      ];
      expect(courseFromJson(gl).resources.map((r) => r.id), [
        'gl-lesson-7',
        'gl-lesson-8',
        'gl-lab-3',
      ]);
    });
  });

  group('CourseRepositoryImpl', () {
    test('getCourses parses the list', () async {
      final (repo, adapter) = _repo((_) => (200, _coursesFixture()));
      final courses = (await repo.getCourses()).unwrap();
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.path, '/api/courses');
      expect(courses, hasLength(3));
    });

    test('setAttendance sends PUT { present }', () async {
      final (repo, adapter) = _repo((_) => (204, null));
      final result = await repo.setAttendance('genie-logiciel', present: false);
      expect(result, isA<Success<void>>());
      expect(adapter.requests.single.method, 'PUT');
      expect(adapter.requests.single.uri.path, '/api/courses/genie-logiciel/attendance');
      expect(adapter.requests.single.data, {'present': false});
    });

    test('downloadResource posts to the download endpoint', () async {
      final (repo, adapter) = _repo((_) => (200, {'url': 'https://files.campuspulse.test/x.pdf'}));
      expect(await repo.downloadResource('gl-lesson-7'), isA<Success<void>>());
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.uri.path, '/api/courses/resources/gl-lesson-7/download');
    });

    test('submitAssignment sends the trimmed link', () async {
      final (repo, adapter) = _repo((_) => (201, {'assignmentId': 'gl-lab-3'}));
      final result = await repo.submitAssignment('gl-lab-3', ' https://github.com/me/lab ');
      expect(result, isA<Success<void>>());
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.uri.path, '/api/courses/assignments/gl-lab-3/submission');
      expect(adapter.requests.single.data, {'repoUrl': 'https://github.com/me/lab'});
    });

    test('server messages reach the UI as-is', () async {
      Future<Failure> failureFor(
        int status,
        String message,
        Future<Result<void>> Function(CourseRepositoryImpl repo) call,
      ) async {
        final (repo, _) = _repo((_) => (status, {'message': message}));
        return ((await call(repo)) as Err<void>).failure;
      }

      final invalid = await failureFor(
        422,
        'Enter a valid https:// repository link.',
        (r) => r.submitAssignment('gl-lab-3', 'github.com/me/lab'),
      );
      expect(invalid, isA<ValidationFailure>());
      expect(invalid.message, 'Enter a valid https:// repository link.');

      final missing = await failureFor(
        404,
        'Course not found.',
        (r) => r.setAttendance('nope', present: true),
      );
      expect(missing, isA<ServerFailure>());
      expect(missing.message, 'Course not found.');

      final video = await failureFor(
        409,
        'Only documents can be downloaded.',
        (r) => r.downloadResource('gl-lesson-8'),
      );
      expect(video, isA<ServerFailure>());
      expect(video.message, 'Only documents can be downloaded.');
    });
  });
}

/// The non-personal, non-date content of a course.
List<Object?> _describe(Course c) => [
      c.id,
      c.code,
      c.location,
      c.title,
      c.term,
      c.track,
      c.professor.title,
      c.professor.name,
      c.professor.office,
      c.professor.email,
      c.professor.isOnline,
      [for (final m in c.modules) (m.number, m.title, m.hours, m.isCompleted)],
      c.lecturesHeld,
      c.lectureCount,
      c.community.onlineCount,
      c.community.onlineClassmates,
      c.isPresent,
    ];

List<Object?> _describeResource(CourseResource r) => switch (r) {
      DocumentResource() => ['document', r.id, r.title, r.format, r.sizeBytes],
      VideoResource() => ['video', r.id, r.title, r.duration, r.quality],
      AssignmentResource() => [
          'assignment',
          r.id,
          r.title,
          r.description,
          r.points,
          r.isMandatory,
        ],
    };
