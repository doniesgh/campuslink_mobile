import 'class_session.dart';

/// A class of the weekly timetable as an admin edits it (without its id):
/// the same class every week, on [weekday] from [start] to [end].
class SlotDraft {
  const SlotDraft({
    required this.weekday,
    required this.start,
    required this.end,
    required this.course,
    required this.teacher,
    this.room = '',
    this.kind = SessionKind.lecture,
    this.mode = SessionMode.onsite,
    this.meetUrl,
    this.notes,
    this.coefficient,
  });

  /// 1 = Monday ... 7 = Sunday ([DateTime.weekday]).
  final int weekday;

  /// Wall-clock 'HH:mm' on campus.
  final String start;
  final String end;
  final String course;
  final String teacher;

  /// '' for an online class without a room.
  final String room;
  final SessionKind kind;
  final SessionMode mode;

  /// The Google Meet link of an online class.
  final String? meetUrl;
  final String? notes;

  /// Weight of an exam in the course grade.
  final double? coefficient;

  bool get isOnline => mode == SessionMode.online;

  /// The body of `POST`/`PATCH /admin/timetable/slots`.
  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'start': start,
        'end': end,
        'course': course,
        'room': room,
        'teacher': teacher,
        'kind': kind.name,
        'mode': mode.name,
        'meetUrl': isOnline ? meetUrl : null,
        'notes': notes,
        'coefficient': kind == SessionKind.exam ? coefficient : null,
      };
}

/// A class of the weekly timetable, with its id.
class TimetableSlot extends SlotDraft {
  const TimetableSlot({
    required this.id,
    required super.weekday,
    required super.start,
    required super.end,
    required super.course,
    required super.teacher,
    super.room,
    super.kind,
    super.mode,
    super.meetUrl,
    super.notes,
    super.coefficient,
    this.lectureNumber,
    this.lectureCount,
  });

  /// Stable: it never changes, even when the course is renamed.
  final String id;

  /// Course progress, kept as it is by the admin screens.
  final int? lectureNumber;
  final int? lectureCount;

  /// This class with [draft]'s fields.
  TimetableSlot withDraft(SlotDraft draft) => TimetableSlot(
        id: id,
        weekday: draft.weekday,
        start: draft.start,
        end: draft.end,
        course: draft.course,
        teacher: draft.teacher,
        room: draft.room,
        kind: draft.kind,
        mode: draft.mode,
        meetUrl: draft.isOnline ? draft.meetUrl : null,
        notes: draft.notes,
        coefficient: draft.kind == SessionKind.exam ? draft.coefficient : null,
        lectureNumber: lectureNumber,
        lectureCount: lectureCount,
      );
}

/// Why a class clashes with [slot]: at overlapping times on the same day.
enum ConflictReason { room, teacher }

class SlotConflict {
  const SlotConflict({required this.reason, required this.slot});

  final ConflictReason reason;
  final TimetableSlot slot;
}

/// What saving a class gave: saved, or refused because it clashes with
/// other classes (the server's 409 `TIMETABLE_CONFLICT`).
sealed class SlotSaveOutcome {
  const SlotSaveOutcome();
}

final class SlotSaved extends SlotSaveOutcome {
  const SlotSaved(this.slot);
  final TimetableSlot slot;
}

final class SlotClash extends SlotSaveOutcome {
  const SlotClash(this.message, this.conflicts);
  final String message;
  final List<SlotConflict> conflicts;
}
