import '../../domain/entities/class_session.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/timetable_slot_rules.dart';
import 'timetable_models.dart';

// JSON of the admin timetable API (backend/src/modules/timetable/timetable-admin.*).

/// Expected slot JSON:
/// { "id": "algo-cm", "weekday": 1, "start": "08:30", "end": "10:00",
///   "course": "...", "room": "Amphi A", "teacher": "...", "kind": "lecture",
///   "mode": "onsite", "meetUrl": null, "notes": null, "coefficient": null,
///   "lectureNumber": 8, "lectureCount": 14 }
TimetableSlot timetableSlotFromJson(Map<String, dynamic> json) => TimetableSlot(
      id: json['id'] as String,
      weekday: (json['weekday'] as num).toInt(),
      start: json['start'] as String,
      end: json['end'] as String,
      course: json['course'] as String,
      room: json['room'] as String? ?? '',
      teacher: json['teacher'] as String,
      kind: SessionKind.values.asNameMap()[json['kind']] ?? SessionKind.lecture,
      mode: sessionModeFromJson(json['mode']),
      meetUrl: json['meetUrl'] as String?,
      notes: json['notes'] as String?,
      coefficient: (json['coefficient'] as num?)?.toDouble(),
      lectureNumber: (json['lectureNumber'] as num?)?.toInt(),
      lectureCount: (json['lectureCount'] as num?)?.toInt(),
    );

/// Expected list JSON: { "classGroup": "Tech Track 4BI", "items": [slot...] }
List<TimetableSlot> timetableSlotsFromJson(Map<String, dynamic> json) => [
      for (final s in json['items'] as List) timetableSlotFromJson(s as Map<String, dynamic>),
    ]..sort(compareSlots);

/// Expected 409 JSON:
/// { "message": "...", "code": "TIMETABLE_CONFLICT",
///   "conflicts": [{ "reason": "room", "slot": {slot} }] }
SlotClash slotClashFromJson(Map<String, dynamic> json) => SlotClash(
      json['message'] as String? ?? SlotMessages.conflict,
      [
        for (final c in json['conflicts'] as List? ?? const [])
          SlotConflict(
            reason: (c as Map<String, dynamic>)['reason'] == 'room'
                ? ConflictReason.room
                : ConflictReason.teacher,
            slot: timetableSlotFromJson(c['slot'] as Map<String, dynamic>),
          ),
      ],
    );
