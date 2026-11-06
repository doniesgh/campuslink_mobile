import 'dart:convert';
import 'dart:typed_data';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/profile/data/models/student_profile_model.dart';
import 'package:campuspulse/features/profile/data/repositories/mock_profile_repository.dart';
import 'package:campuspulse/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:campuspulse/features/profile/domain/entities/student_profile.dart';
import 'package:campuspulse/features/profile/presentation/providers/profile_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real response of GET /api/profile for the seeded demo student on
/// 5 November 2026 at 10:00 in Tunis, printed by backend/test/profile.test.ts.
const _fixture = r'''
{
  "studentId": "211JMT0428",
  "displayName": "Dony Mansour",
  "email": "dony.mansour@campus.test",
  "program": "Software Engineering",
  "programShort": "Software Eng.",
  "className": "4BI",
  "yearOfStudy": 4,
  "campus": "ESPRIT Ghazela",
  "campusLocation": "Ghazela Technopark",
  "semester": 7,
  "academicYearStart": 2026,
  "validUntil": "2027-09-30",
  "ectsCredits": 90,
  "gpa": 3.72,
  "rankTopPercent": 5,
  "promoYear": 2027,
  "honours": "Dean's List",
  "isOnCampus": true,
  "isVerified": true,
  "nfcReady": true,
  "hasEspritKey": true,
  "unreadNotifications": 3,
  "hasCarpoolActivity": true
}
''';

/// The backend's default profile (a student without a profile document).
const _defaultProfile = <String, dynamic>{
  'studentId': null,
  'displayName': 'Amira Trabelsi',
  'email': 'amira@campus.test',
  'program': 'Engineering Common Core',
  'programShort': 'Common Core',
  'className': '1A',
  'yearOfStudy': 1,
  'campus': 'ESPRIT Ghazela',
  'campusLocation': 'Ghazela Technopark',
  'semester': 1,
  'academicYearStart': 2026,
  'validUntil': '2027-09-30',
  'ectsCredits': 0,
  'gpa': 0,
  'rankTopPercent': 100,
  'promoYear': 2027,
  'honours': null,
  'isOnCampus': false,
  'isVerified': false,
  'nfcReady': false,
  'hasEspritKey': false,
  'unreadNotifications': 0,
  'hasCarpoolActivity': false,
};

Map<String, dynamic> _json() => jsonDecode(_fixture) as Map<String, dynamic>;

StudentProfile _parse(Map<String, dynamic> json) =>
    StudentProfileModel.fromJson(json).toEntity();

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
  group('backend profile JSON (contract)', () {
    final p = _parse(_json());

    test('parses into the entity', () {
      expect(p.studentId, '211JMT0428');
      expect(p.programLine, 'Software Engineering (4BI) · ESPRIT Ghazela');
      expect(p.cardProgramLine, 'Software Eng. · Sem 7');
      expect(p.semesterLabel, 'S7');
      expect(p.academicYearLabel, '2026–2027');
      expect(p.ectsCredits, 90);
      expect(p.gpaLabel, '3.72');
      expect(p.honours, "Dean's List");
      expect(p.rankLabel, 'Top 5%');
      expect(p.promoLabel, 'Promo 2027');
      expect(p.campusLocation, 'Ghazela Technopark');
      expect(
        [p.isOnCampus, p.isVerified, p.nfcReady, p.hasEspritKey, p.hasCarpoolActivity],
        everyElement(isTrue),
      );
      expect(p.unreadNotifications, 3);
    });

    test('validUntil is a calendar date: valid through the whole last day', () {
      expect(p.validUntil, DateTime(2027, 9, 30));
      expect(p.isValidOn(DateTime(2027, 9, 30, 23, 59)), isTrue);
      expect(p.isValidOn(DateTime(2027, 10, 1)), isFalse);
    });

    test('same as MockProfileRepository on the same day, credits from the transcript', () async {
      final mock = MockProfileRepository(
        latency: Duration.zero,
        clock: () => DateTime(2026, 11, 5, 10),
      );
      final m = (await mock.getMyProfile()).unwrap();
      List<Object?> fields(StudentProfile x) => [
            x.studentId, x.program, x.programShort, x.className, x.campus,
            x.campusLocation, x.semester, x.academicYearStart, x.validUntil,
            x.gpa, x.rankTopPercent, x.promoYear, x.honours, x.isOnCampus,
            x.isVerified, x.nfcReady, x.hasEspritKey, x.unreadNotifications,
            x.hasCarpoolActivity,
          ];
      expect(fields(p), fields(m));
      // The mock says 94; the API counts the credits of the published
      // semesters (3 × 30), like the Grades screen.
      expect(p.ectsCredits, 90);
    });

    test('default profile of a new student', () {
      final d = _parse(_defaultProfile);
      expect(d.studentId, StudentProfileModel.pendingStudentId);
      expect(d.programLine, 'Engineering Common Core (1A) · ESPRIT Ghazela');
      expect(d.semesterLabel, 'S1');
      expect(d.ectsCredits, 0);
      expect(d.gpaLabel, '0.00');
      expect(d.honours, isNull);
      expect(d.rankLabel, 'Top 100%');
      expect(d.isVerified, isFalse);
      expect(d.unreadNotifications, 0);
    });
  });

  group('ProfileRepositoryImpl', () {
    test('GETs /profile and maps the response', () async {
      final adapter = _FakeAdapter(200, _json());
      final result = await ProfileRepositoryImpl(_dio(adapter)).getMyProfile();

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.toString(), 'http://api.test/api/profile');
      expect(result, isA<Success<StudentProfile>>());
      expect(result.unwrap().className, '4BI');
    });

    test('maps errors to failures', () async {
      final unauthorized = await ProfileRepositoryImpl(
        _dio(_FakeAdapter(401, {'message': 'Invalid credentials or expired session.'})),
      ).getMyProfile();
      expect((unauthorized as Err<StudentProfile>).failure, isA<UnauthorizedFailure>());

      final server = await ProfileRepositoryImpl(
        _dio(_FakeAdapter(500, {'message': 'Something went wrong. Please try again.'})),
      ).getMyProfile();
      expect(
        (server as Err<StudentProfile>).failure,
        isA<ServerFailure>()
            .having((f) => f.message, 'message', 'Something went wrong. Please try again.'),
      );
    });

    test('a malformed body is a failure, not a crash', () async {
      final result =
          await ProfileRepositoryImpl(_dio(_FakeAdapter(200, {'studentId': 'X'}))).getMyProfile();
      expect((result as Err<StudentProfile>).failure, isA<UnknownFailure>());
    });
  });

  test('the provider uses the mock when USE_MOCK is true (the test default)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(profileRepositoryProvider), isA<MockProfileRepository>());
  });
}
