import 'entities/class_session.dart';
import 'entities/timetable_slot.dart';

// The rules of a class of the weekly timetable, with the server's messages
// (backend/src/modules/timetable/timetable-admin.schemas.ts and
// timetable-admin.service.ts). Change both together.

abstract final class SlotLimits {
  static const courseMaxLength = 120;
  static const roomMaxLength = 60;
  static const teacherMaxLength = 80;
  static const notesMaxLength = 1000;
  static const meetUrlMaxLength = 200;
  static const maxDurationMinutes = 8 * 60;
  static const maxCoefficient = 10;
}

abstract final class SlotMessages {
  static const endBeforeStart = 'The class must end after it starts';
  static const tooLong = 'A class lasts at most 8 hours';
  static const courseMissing = 'Enter the course';
  static const courseTooLong =
      'The course name is too long (${SlotLimits.courseMaxLength} characters max)';
  static const roomMissing = 'Enter the room of an on-site class';
  static const roomTooLong = 'The room is too long (${SlotLimits.roomMaxLength} characters max)';
  static const teacherMissing = 'Enter the teacher';
  static const teacherTooLong =
      "The teacher's name is too long (${SlotLimits.teacherMaxLength} characters max)";
  static const meetUrlMissing = 'Enter the Google Meet link of an online class';
  static const meetUrlInvalid =
      'Enter a Google Meet link, like https://meet.google.com/abc-defg-hij';
  static const notesTooLong =
      'The notes are too long (${SlotLimits.notesMaxLength} characters max)';
  static const coefficient =
      'The coefficient must be between 0 and ${SlotLimits.maxCoefficient}';
  static const conflict = 'This class clashes with another class of the timetable';
}

/// A Google Meet link: https://meet.google.com/abc-defg-hij (same rule as the server).
final _meetUrl = RegExp(
  r'^https://meet\.google\.com/[a-z0-9_-]{3,40}(?:/[a-z0-9_-]+)?(?:\?\S*)?$',
  caseSensitive: false,
);

bool isMeetUrl(String value) =>
    value.length <= SlotLimits.meetUrlMaxLength && _meetUrl.hasMatch(value);

/// Minutes since midnight of 'HH:mm'.
int hmToMinutes(String hm) => int.parse(hm.substring(0, 2)) * 60 + int.parse(hm.substring(3, 5));

/// 'HH:mm' of [minutes] since midnight.
String minutesToHm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String? validateCourse(String value) {
  final v = value.trim();
  if (v.isEmpty) return SlotMessages.courseMissing;
  if (v.length > SlotLimits.courseMaxLength) return SlotMessages.courseTooLong;
  return null;
}

String? validateTeacher(String value) {
  final v = value.trim();
  if (v.isEmpty) return SlotMessages.teacherMissing;
  if (v.length > SlotLimits.teacherMaxLength) return SlotMessages.teacherTooLong;
  return null;
}

/// The room is needed on campus only.
String? validateRoom(String value, {required bool online}) {
  final v = value.trim();
  if (v.isEmpty && !online) return SlotMessages.roomMissing;
  if (v.length > SlotLimits.roomMaxLength) return SlotMessages.roomTooLong;
  return null;
}

/// The Meet link is needed (and checked) online only.
String? validateMeetUrl(String? value, {required bool online}) {
  if (!online) return null;
  final v = value?.trim() ?? '';
  if (v.isEmpty) return SlotMessages.meetUrlMissing;
  if (!isMeetUrl(v)) return SlotMessages.meetUrlInvalid;
  return null;
}

String? validateTimes(String start, String end) {
  final s = hmToMinutes(start), e = hmToMinutes(end);
  if (e <= s) return SlotMessages.endBeforeStart;
  if (e - s > SlotLimits.maxDurationMinutes) return SlotMessages.tooLong;
  return null;
}

String? validateNotes(String? value) =>
    (value?.trim().length ?? 0) > SlotLimits.notesMaxLength ? SlotMessages.notesTooLong : null;

String? validateCoefficient(double? value) =>
    value != null && (value <= 0 || value > SlotLimits.maxCoefficient)
        ? SlotMessages.coefficient
        : null;

/// The first problem of [draft] (as the server would say it), or null.
String? validateSlotDraft(SlotDraft draft) =>
    validateTimes(draft.start, draft.end) ??
    validateCourse(draft.course) ??
    validateRoom(draft.room, online: draft.isOnline) ??
    validateTeacher(draft.teacher) ??
    validateMeetUrl(draft.meetUrl, online: draft.isOnline) ??
    validateNotes(draft.notes) ??
    (draft.kind == SessionKind.exam ? validateCoefficient(draft.coefficient) : null);

bool _same(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

/// The classes of [slots] that [candidate] clashes with: the same weekday at
/// overlapping times (touching is fine), in the same room or with the same
/// teacher. [exceptId] is the class being edited.
List<SlotConflict> findSlotConflicts(
  Iterable<TimetableSlot> slots,
  SlotDraft candidate, {
  String? exceptId,
}) {
  final start = hmToMinutes(candidate.start), end = hmToMinutes(candidate.end);
  final sorted = [...slots]..sort(compareSlots);
  return [
    for (final other in sorted)
      if (other.id != exceptId &&
          other.weekday == candidate.weekday &&
          start < hmToMinutes(other.end) &&
          hmToMinutes(other.start) < end) ...[
        if (candidate.room.trim().isNotEmpty &&
            other.room.trim().isNotEmpty &&
            _same(candidate.room, other.room))
          SlotConflict(reason: ConflictReason.room, slot: other),
        if (_same(candidate.teacher, other.teacher))
          SlotConflict(reason: ConflictReason.teacher, slot: other),
      ],
  ];
}

/// By weekday, then start time.
int compareSlots(SlotDraft a, SlotDraft b) {
  final byDay = a.weekday.compareTo(b.weekday);
  return byDay != 0 ? byDay : a.start.compareTo(b.start);
}

const weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

/// "Monday" for 1 ... "Sunday" for 7.
String weekdayName(int weekday) => weekdayNames[weekday - 1];
