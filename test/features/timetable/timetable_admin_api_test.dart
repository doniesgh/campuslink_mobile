import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/timetable/data/models/timetable_admin_models.dart';
import 'package:campuspulse/features/timetable/data/repositories/mock_timetable_admin_repository.dart';
import 'package:campuspulse/features/timetable/data/repositories/mock_timetable_repository.dart';
import 'package:campuspulse/features/timetable/data/repositories/mock_timetable_store.dart';
import 'package:campuspulse/features/timetable/data/repositories/timetable_admin_repository_impl.dart';
import 'package:campuspulse/features/timetable/domain/entities/class_session.dart';
import 'package:campuspulse/features/timetable/domain/entities/timetable_slot.dart';
import 'package:campuspulse/features/timetable/domain/timetable_slot_rules.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real responses of the admin timetable API, produced by the backend
/// (seeded demo template): `list` = `GET /api/admin/timetable/slots`,
/// `conflict` = the 409 of a Monday 09:00–10:30 class in Amphi A with
/// Prof. Trabelsi.
Map<String, dynamic> _fixture() => jsonDecode(
      File('test/features/timetable/fixtures/timetable_admin_slots.json').readAsStringSync(),
    ) as Map<String, dynamic>;

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

(TimetableAdminRepositoryImpl, _FakeAdapter) _repo(
  (int, Object?) Function(RequestOptions) respond,
) {
  final adapter = _FakeAdapter(respond);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'))..httpClientAdapter = adapter;
  return (TimetableAdminRepositoryImpl(dio), adapter);
}

const _meet = 'https://meet.google.com/abc-defg-hij';

/// A free Saturday class.
const _saturday = SlotDraft(
  weekday: 6,
  start: '09:00',
  end: '11:00',
  course: 'Cloud Computing',
  teacher: 'Dr. Zribi',
  room: 'Salle C201',
);

SlotDraft _draft({
  int weekday = 6,
  String start = '09:00',
  String end = '11:00',
  String course = 'Cloud Computing',
  String teacher = 'Dr. Zribi',
  String room = 'Salle C201',
  SessionKind kind = SessionKind.lecture,
  SessionMode mode = SessionMode.onsite,
  String? meetUrl,
  double? coefficient,
}) =>
    SlotDraft(
      weekday: weekday,
      start: start,
      end: end,
      course: course,
      teacher: teacher,
      room: room,
      kind: kind,
      mode: mode,
      meetUrl: meetUrl,
      coefficient: coefficient,
    );

List<Object?> _describe(TimetableSlot s) => [
      s.id, s.weekday, s.start, s.end, s.course, s.room, s.teacher, s.kind, s.mode, s.meetUrl,
      s.notes, s.coefficient, s.lectureNumber, s.lectureCount,
    ];

void main() {
  group('backend JSON', () {
    test('parses the list of classes', () {
      final slots = timetableSlotsFromJson(_fixture()['list'] as Map<String, dynamic>);

      expect(slots, hasLength(17));
      expect(slots.map((s) => s.id).toSet(), hasLength(17));
      final first = slots.first;
      expect(_describe(first), [
        'algo-cm', 1, '08:30', '10:00', 'Algorithmes & Complexité', 'Amphi A', 'Prof. Trabelsi',
        SessionKind.lecture, SessionMode.onsite, null, null, null, 8, 14,
      ]);
      final online = slots.last;
      expect(online.id, 'entrepreneuriat');
      expect(online.isOnline, isTrue);
      expect(online.room, '');
      expect(online.meetUrl, MockTimetableStore.demoMeetUrl);
    });

    test('the demo store has the same classes as the API seed', () {
      final api = timetableSlotsFromJson(_fixture()['list'] as Map<String, dynamic>);
      final mock = [...MockTimetableStore.demoSlots]..sort(compareSlots);
      expect(mock.map(_describe), api.map(_describe));
    });

    test('parses a 409 into the clashing classes', () {
      final clash = slotClashFromJson(_fixture()['conflict'] as Map<String, dynamic>);
      expect(clash.message, SlotMessages.conflict);
      expect(clash.conflicts.map((c) => (c.reason, c.slot.id)), [
        (ConflictReason.room, 'algo-cm'),
        (ConflictReason.teacher, 'algo-cm'),
      ]);
    });

    test('the body sent has the API names, the link only online, the coefficient only for exams', () {
      expect(_saturday.toJson(), {
        'weekday': 6,
        'start': '09:00',
        'end': '11:00',
        'course': 'Cloud Computing',
        'room': 'Salle C201',
        'teacher': 'Dr. Zribi',
        'kind': 'lecture',
        'mode': 'onsite',
        'meetUrl': null,
        'notes': null,
        'coefficient': null,
      });
      final online = _draft(mode: SessionMode.online, meetUrl: _meet, coefficient: 2).toJson();
      expect(online['mode'], 'online');
      expect(online['meetUrl'], _meet);
      expect(online['coefficient'], isNull);
      expect(_draft(kind: SessionKind.exam, coefficient: 2, meetUrl: _meet).toJson(),
          containsPair('coefficient', 2.0));
      expect(_draft(meetUrl: _meet).toJson()['meetUrl'], isNull);
    });
  });

  group('TimetableAdminRepositoryImpl', () {
    final fixture = _fixture();
    final list = fixture['list'] as Map<String, dynamic>;
    final created = (list['items'] as List).first as Map<String, dynamic>;

    test('getSlots reads the list', () async {
      final (repo, adapter) = _repo((_) => (200, list));
      final slots = (await repo.getSlots()).unwrap();
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.path, '/api/admin/timetable/slots');
      expect(slots, hasLength(17));
    });

    test('createSlot posts the class and answers it', () async {
      final (repo, adapter) = _repo((_) => (201, created));
      final outcome = (await repo.createSlot(_saturday)).unwrap();
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.uri.path, '/api/admin/timetable/slots');
      expect(adapter.requests.single.data, _saturday.toJson());
      expect((outcome as SlotSaved).slot.id, 'algo-cm');
    });

    test('updateSlot patches the class, deleteSlot deletes it', () async {
      final (repo, adapter) = _repo((o) => o.method == 'DELETE' ? (204, null) : (200, created));
      expect((await repo.updateSlot('algo-cm', _saturday)).unwrap(), isA<SlotSaved>());
      expect(await repo.deleteSlot('algo-cm'), isA<Success<void>>());
      expect(adapter.requests.map((r) => (r.method, r.uri.path)), [
        ('PATCH', '/api/admin/timetable/slots/algo-cm'),
        ('DELETE', '/api/admin/timetable/slots/algo-cm'),
      ]);
    });

    test('a 409 TIMETABLE_CONFLICT is the list of clashing classes', () async {
      final (repo, _) = _repo((_) => (409, fixture['conflict']));
      final outcome = (await repo.createSlot(_saturday)).unwrap();
      expect(outcome, isA<SlotClash>());
      expect((outcome as SlotClash).conflicts, hasLength(2));
    });

    test('a 422 is a validation failure with the server message', () async {
      final (repo, _) = _repo(
        (_) => (422, {'message': SlotMessages.meetUrlMissing, 'code': 'VALIDATION_ERROR'}),
      );
      final result = await repo.createSlot(_saturday);
      final failure = (result as Err<SlotSaveOutcome>).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, SlotMessages.meetUrlMissing);
      expect(failure.code, 'VALIDATION_ERROR');
    });
  });

  group('slot rules (same as the server)', () {
    test('a valid class has no problem', () {
      expect(validateSlotDraft(_saturday), isNull);
      expect(validateSlotDraft(_draft(mode: SessionMode.online, room: '', meetUrl: _meet)), isNull);
    });

    test('the first problem, with the server messages', () {
      expect(validateSlotDraft(_draft(end: '09:00')), SlotMessages.endBeforeStart);
      expect(validateSlotDraft(_draft(start: '08:00', end: '16:30')), SlotMessages.tooLong);
      expect(validateSlotDraft(_draft(course: '  ')), SlotMessages.courseMissing);
      expect(validateSlotDraft(_draft(room: '')), SlotMessages.roomMissing);
      expect(validateSlotDraft(_draft(teacher: '')), SlotMessages.teacherMissing);
      expect(validateSlotDraft(_draft(mode: SessionMode.online)), SlotMessages.meetUrlMissing);
      expect(
        validateSlotDraft(_draft(mode: SessionMode.online, meetUrl: 'https://zoom.us/j/1')),
        SlotMessages.meetUrlInvalid,
      );
      expect(
        validateSlotDraft(_draft(mode: SessionMode.online, meetUrl: 'http://meet.google.com/abc-defg-hij')),
        SlotMessages.meetUrlInvalid,
      );
      expect(
        validateSlotDraft(_draft(kind: SessionKind.exam, coefficient: 0)),
        SlotMessages.coefficient,
      );
    });

    test('conflicts: same room or teacher at overlapping times on the same day', () {
      final slots = MockTimetableStore.demoSlots;
      // Monday: Algorithmes 08:30–10:00, Amphi A, Prof. Trabelsi.
      List<(ConflictReason, String)> clashes(SlotDraft d, {String? exceptId}) => [
            for (final c in findSlotConflicts(slots, d, exceptId: exceptId)) (c.reason, c.slot.id),
          ];

      expect(clashes(_draft(weekday: 1, start: '09:00', end: '10:30', room: 'amphi a')),
          [(ConflictReason.room, 'algo-cm')]);
      expect(
        clashes(_draft(weekday: 1, start: '09:00', end: '10:30', teacher: 'Prof. Trabelsi')),
        [(ConflictReason.teacher, 'algo-cm')],
      );
      // Touching, another day, or the class itself: fine.
      expect(clashes(_draft(weekday: 1, start: '10:00', end: '10:15', room: 'Amphi A')), isEmpty);
      expect(clashes(_draft(weekday: 6, start: '09:00', end: '10:30', room: 'Amphi A')), isEmpty);
      expect(
        clashes(
          _draft(weekday: 1, start: '08:45', end: '10:00', room: 'Amphi A', teacher: 'Prof. Trabelsi'),
          exceptId: 'algo-cm',
        ),
        isEmpty,
      );
    });
  });

  group('MockTimetableAdminRepository', () {
    test('changes show in the students\' timetable of the same store', () async {
      final store = MockTimetableStore();
      final admin = MockTimetableAdminRepository(store: store, delay: Duration.zero);
      final student = MockTimetableRepository(store: store, latency: Duration.zero);
      final saturday = DateTime(2026, 11, 14);

      final saved = (await admin.createSlot(
        _draft(mode: SessionMode.online, room: '', meetUrl: ' $_meet '),
      ))
          .unwrap() as SlotSaved;
      expect(saved.slot.id, startsWith('cloud-computing-'));
      expect(saved.slot.meetUrl, _meet);

      final session = (await student.getDay(saturday)).unwrap().sessions.single;
      expect(session.id, '${saved.slot.id}-2026-11-14');
      expect(session.isOnline, isTrue);
      expect(session.room, 'Online');
      expect(session.meetUrl, _meet);

      final updated = (await admin.updateSlot(saved.slot.id, _draft(start: '14:00', end: '15:00')))
          .unwrap() as SlotSaved;
      expect(updated.slot.id, saved.slot.id);
      expect(updated.slot.isOnline, isFalse);
      expect(updated.slot.meetUrl, isNull);
      expect((await student.getDay(saturday)).unwrap().sessions.single.start,
          DateTime(2026, 11, 14, 14));

      expect(await admin.deleteSlot(saved.slot.id), isA<Success<void>>());
      expect((await student.getDay(saturday)).unwrap().sessions, isEmpty);
      expect(await admin.deleteSlot(saved.slot.id), isA<Err<void>>());
    });

    test('refuses invalid classes and clashes like the API', () async {
      final admin = MockTimetableAdminRepository(delay: Duration.zero);

      final invalid = await admin.createSlot(_draft(mode: SessionMode.online));
      expect((invalid as Err<SlotSaveOutcome>).failure.message, SlotMessages.meetUrlMissing);

      final clash = (await admin.createSlot(
        _draft(weekday: 1, start: '09:00', end: '10:30', room: 'Amphi A', teacher: 'Prof. Trabelsi'),
      ))
          .unwrap();
      expect((clash as SlotClash).conflicts.map((c) => c.reason),
          [ConflictReason.room, ConflictReason.teacher]);
      expect((await admin.getSlots()).unwrap(), hasLength(17));
    });
  });
}
