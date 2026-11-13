import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/repositories/timetable_admin_repository.dart';
import '../../domain/timetable_slot_rules.dart';
import 'mock_timetable_store.dart';

/// In-memory fake of the admin timetable API, on [store] (shared with the
/// student screens' MockTimetableRepository in demo mode). Same rules and
/// messages as the server: 422-like [ValidationFailure]s, [SlotClash] for
/// classes that clash.
class MockTimetableAdminRepository implements TimetableAdminRepository {
  MockTimetableAdminRepository({MockTimetableStore? store, this.delay = const Duration(milliseconds: 300)})
      : store = store ?? MockTimetableStore();

  final MockTimetableStore store;

  /// Fake network latency (zero in widget tests: no pending timers).
  final Duration delay;

  var _next = 0;

  Future<void> _wait() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<Result<List<TimetableSlot>>> getSlots() async {
    await _wait();
    return Success([...store.slots]..sort(compareSlots));
  }

  @override
  Future<Result<SlotSaveOutcome>> createSlot(SlotDraft draft) async {
    await _wait();
    final problem = validateSlotDraft(draft);
    if (problem != null) return Err(ValidationFailure(problem, 'VALIDATION_ERROR'));
    final conflicts = findSlotConflicts(store.slots, draft);
    if (conflicts.isNotEmpty) return Success(SlotClash(SlotMessages.conflict, conflicts));

    final slot = TimetableSlot(
      id: _newId(draft.course),
      weekday: draft.weekday,
      start: draft.start,
      end: draft.end,
      course: draft.course,
      teacher: draft.teacher,
    ).withDraft(_trimmed(draft));
    store.slots.add(slot);
    return Success(SlotSaved(slot));
  }

  @override
  Future<Result<SlotSaveOutcome>> updateSlot(String id, SlotDraft draft) async {
    await _wait();
    final i = store.slots.indexWhere((s) => s.id == id);
    if (i < 0) return const Err(ServerFailure('This class is not in the timetable.'));
    final problem = validateSlotDraft(draft);
    if (problem != null) return Err(ValidationFailure(problem, 'VALIDATION_ERROR'));
    final conflicts = findSlotConflicts(store.slots, draft, exceptId: id);
    if (conflicts.isNotEmpty) return Success(SlotClash(SlotMessages.conflict, conflicts));

    final slot = store.slots[i].withDraft(_trimmed(draft));
    store.slots[i] = slot;
    return Success(SlotSaved(slot));
  }

  @override
  Future<Result<void>> deleteSlot(String id) async {
    await _wait();
    final before = store.slots.length;
    store.slots.removeWhere((s) => s.id == id);
    return store.slots.length < before
        ? const Success(null)
        : const Err(ServerFailure('This class is not in the timetable.'));
  }

  /// Like the server: trimmed texts, blank notes and links dropped.
  static SlotDraft _trimmed(SlotDraft d) {
    final notes = d.notes?.trim() ?? '';
    final meetUrl = d.meetUrl?.trim() ?? '';
    return SlotDraft(
      weekday: d.weekday,
      start: d.start,
      end: d.end,
      course: d.course.trim(),
      teacher: d.teacher.trim(),
      room: d.room.trim(),
      kind: d.kind,
      mode: d.mode,
      meetUrl: meetUrl.isEmpty ? null : meetUrl,
      notes: notes.isEmpty ? null : notes,
      coefficient: d.coefficient,
    );
  }

  /// 'cloud-computing-3' (unique in the store).
  String _newId(String course) {
    final slug = course
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = slug.isEmpty ? 'class' : (slug.length > 24 ? slug.substring(0, 24) : slug);
    String id;
    do {
      id = '$base-${++_next}';
    } while (store.slots.any((s) => s.id == id));
    return id;
  }
}
