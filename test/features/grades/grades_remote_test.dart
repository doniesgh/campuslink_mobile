import 'dart:convert';
import 'dart:typed_data';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/grades/data/models/transcript_models.dart';
import 'package:campuspulse/features/grades/data/repositories/grades_repository_impl.dart';
import 'package:campuspulse/features/grades/data/repositories/mock_grades_repository.dart';
import 'package:campuspulse/features/grades/domain/entities/academic_transcript.dart';
import 'package:campuspulse/features/grades/domain/grading.dart';
import 'package:campuspulse/features/grades/presentation/providers/grades_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real response of GET /api/grades/transcript for the seeded demo student on
/// 5 November 2026 at 10:00 in Tunis, printed by backend/test/grades.test.ts.
const _fixture = r'''
{
  "studentId": "211JMT0428",
  "semesters": [
    {
      "id": "2025-2026-s6",
      "academicYear": "2025–2026",
      "number": 6,
      "updatedAt": "2026-11-05T07:00:00.000Z",
      "rank": 7,
      "cohortSize": 142,
      "signedBy": "Dean Marc Lefèvre",
      "documentSizeMb": 1.4,
      "courses": [
        {
          "code": "CS-401",
          "title": "Génie Logiciel & Microservices",
          "coefficient": 3,
          "credits": 10,
          "continuous": 17.5,
          "exam": 16
        },
        {
          "code": "DB-408",
          "title": "Conception & BDD NoSQL",
          "coefficient": 2.5,
          "credits": 8,
          "continuous": 18,
          "exam": 15.5
        },
        {
          "code": "SEC-402",
          "title": "Réseaux & Sécurité Informatique",
          "coefficient": 2,
          "credits": 7,
          "continuous": 14.5,
          "exam": 15
        },
        {
          "code": "HUM-304",
          "title": "Anglais Pro & Soft Skills",
          "coefficient": 1.5,
          "credits": 5,
          "continuous": 19,
          "exam": null
        }
      ]
    },
    {
      "id": "2025-2026-s5",
      "academicYear": "2025–2026",
      "number": 5,
      "updatedAt": "2026-02-07T13:30:00.000Z",
      "rank": 11,
      "cohortSize": 142,
      "signedBy": "Dean Marc Lefèvre",
      "documentSizeMb": 1.3,
      "courses": [
        {
          "code": "CS-305",
          "title": "Algorithmes & Complexité",
          "coefficient": 3,
          "credits": 10,
          "continuous": 16,
          "exam": 15.5
        },
        {
          "code": "CS-307",
          "title": "Génie Logiciel & Architecture",
          "coefficient": 2.5,
          "credits": 8,
          "continuous": 17,
          "exam": 16.5
        },
        {
          "code": "DB-306",
          "title": "Bases de Données",
          "coefficient": 2,
          "credits": 7,
          "continuous": 15.5,
          "exam": 16
        },
        {
          "code": "MATH-302",
          "title": "Probabilités & Statistiques",
          "coefficient": 1.5,
          "credits": 5,
          "continuous": 17,
          "exam": 17
        }
      ]
    },
    {
      "id": "2024-2025-s4",
      "academicYear": "2024–2025",
      "number": 4,
      "updatedAt": "2025-07-03T09:00:00.000Z",
      "rank": 48,
      "cohortSize": 140,
      "signedBy": "Dean Marc Lefèvre",
      "documentSizeMb": 1.2,
      "courses": [
        {
          "code": "CS-301",
          "title": "Programmation Orientée Objet",
          "coefficient": 3,
          "credits": 10,
          "continuous": 14,
          "exam": 13
        },
        {
          "code": "MATH-303",
          "title": "Analyse Numérique",
          "coefficient": 2.5,
          "credits": 8,
          "continuous": 10,
          "exam": 8.5
        },
        {
          "code": "SYS-304",
          "title": "Systèmes d'Exploitation",
          "coefficient": 2,
          "credits": 7,
          "continuous": 13.5,
          "exam": 12
        },
        {
          "code": "HUM-204",
          "title": "Français & Communication",
          "coefficient": 1.5,
          "credits": 5,
          "continuous": 15,
          "exam": null
        }
      ]
    }
  ]
}
''';

Map<String, dynamic> _json() => jsonDecode(_fixture) as Map<String, dynamic>;

AcademicTranscript _parse(Map<String, dynamic> json) =>
    AcademicTranscriptModel.fromJson(json).toEntity();

/// Everything but the publication date, to compare with the mock.
List<Object?> _content(SemesterRecord s) => [
      s.id,
      s.label,
      s.rank,
      s.cohortSize,
      s.signedBy,
      s.documentSizeMb,
      for (final c in s.courses) (c.code, c.title, c.coefficient, c.credits, c.continuous, c.exam),
    ];

/// Answers every request with [status] and [body], and records the requests.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  final int status;
  final Object body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

Dio _dio(_FakeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://api.test/api'))..httpClientAdapter = adapter;

void main() {
  group('backend transcript JSON (contract)', () {
    final t = _parse(_json());

    test('parses into the entity, most recent first', () {
      expect(t.studentId, '211JMT0428');
      expect(t.semesters.map((s) => s.label), [
        '2025–2026 · Sem 6',
        '2025–2026 · Sem 5',
        '2024–2025 · Sem 4',
      ]);
      expect(t.semesters.map((s) => s.id), ['2025-2026-s6', '2025-2026-s5', '2024-2025-s4']);
      expect(t.semesters.every((s) => s.isOfficial), isTrue);
      expect(t.semesters.first.documentSizeMb, 1.4);

      final hum = t.semesters.first.courses.last;
      expect((hum.code, hum.coefficient, hum.credits, hum.continuous, hum.exam),
          ('HUM-304', 1.5, 5, 19.0, null));
    });

    test('instants are UTC on the wire and local in the app', () {
      final updated = t.semesters.map((s) => s.updatedAt).toList();
      expect(updated.every((d) => !d.isUtc), isTrue);
      expect(updated.map((d) => d.toUtc()), [
        DateTime.utc(2026, 11, 5, 7),
        DateTime.utc(2026, 2, 7, 13, 30),
        DateTime.utc(2025, 7, 3, 9),
      ]);
    });

    test('the app computes the same results as with the mock', () {
      final latest = semesterResultFor(t, null)!;
      expect(latest.courses.map((c) => c.average), [16.6, 16.5, 14.8, 19.0]);
      expect(latest.average, 16.57);
      expect(latest.previousAverage, 16.22);
      expect(latest.delta, 0.35);
      expect(latest.creditsEarned, 30);
      expect(latest.topCohortPercent, 5);
      expect(latest.isHonorRoll, isTrue);

      final oldest = semesterResultFor(t, '2024-2025-s4')!;
      expect(oldest.average, 12.29);
      expect(oldest.courses[1].status, CourseStatus.compensated);
      expect(oldest.creditsEarned, 30);
    });

    test('same content as MockGradesRepository on the same day', () async {
      final mock = MockGradesRepository(
        latency: Duration.zero,
        clock: () => DateTime(2026, 11, 5, 10),
      );
      final expected = (await mock.getTranscript()).unwrap();
      expect(t.semesters.map(_content), expected.semesters.map(_content));
    });

    test('no ENT ID and no grades yet', () {
      final empty = _parse({'studentId': null, 'semesters': <Object>[]});
      expect(empty.studentId, AcademicTranscriptModel.pendingStudentId);
      expect(empty.semesters, isEmpty);
      expect(semesterResultFor(empty, null), isNull);
    });

    test('provisional semester: no rank, no signature, no document', () {
      final s = _parse({
        'studentId': '221JMT0002',
        'semesters': [
          {
            'id': '2025-2026-s2',
            'academicYear': '2025–2026',
            'number': 2,
            'updatedAt': '2026-07-03T09:00:00.000Z',
            'rank': null,
            'cohortSize': null,
            'signedBy': null,
            'documentSizeMb': null,
            'courses': [
              {
                'code': 'MATH-101',
                'title': 'Analyse 1',
                'coefficient': 2,
                'credits': 6,
                'continuous': null,
                'exam': 11,
              },
            ],
          },
        ],
      }).semesters.single;
      expect(s.isOfficial, isFalse);
      expect(s.rank, isNull);
      expect(s.documentSizeMb, isNull);
      expect(s.courses.single.exam, 11.0);
    });
  });

  group('GradesRepositoryImpl', () {
    test('GETs /grades/transcript and maps the response', () async {
      final adapter = _FakeAdapter(200, _json());
      final result = await GradesRepositoryImpl(_dio(adapter)).getTranscript();

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.toString(), 'http://api.test/api/grades/transcript');
      expect(result, isA<Success<AcademicTranscript>>());
      expect(result.unwrap().semesters, hasLength(3));
    });

    test('maps errors to failures', () async {
      final unauthorized = await GradesRepositoryImpl(
        _dio(_FakeAdapter(401, {'message': 'Invalid credentials or expired session.'})),
      ).getTranscript();
      expect(
        (unauthorized as Err<AcademicTranscript>).failure,
        isA<UnauthorizedFailure>()
            .having((f) => f.message, 'message', 'Invalid credentials or expired session.'),
      );

      final server = await GradesRepositoryImpl(
        _dio(_FakeAdapter(500, {'message': 'Something went wrong. Please try again.'})),
      ).getTranscript();
      expect((server as Err<AcademicTranscript>).failure, isA<ServerFailure>());
    });

    test('a malformed body is a failure, not a crash', () async {
      final result = await GradesRepositoryImpl(
        _dio(_FakeAdapter(200, {'studentId': 'X'})),
      ).getTranscript();
      expect((result as Err<AcademicTranscript>).failure, isA<UnknownFailure>());
    });
  });

  test('the provider uses the mock when USE_MOCK is true (the test default)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(gradesRepositoryProvider), isA<MockGradesRepository>());
  });
}
