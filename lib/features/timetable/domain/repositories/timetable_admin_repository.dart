import '../../../../core/error/result.dart';
import '../entities/timetable_slot.dart';

/// Admins manage the weekly timetable of the class group (admins only: the
/// API answers 403 to everyone else). Students and teachers see the changes
/// through [TimetableRepository].
abstract interface class TimetableAdminRepository {
  /// Every class of the week, by weekday then start time.
  Future<Result<List<TimetableSlot>>> getSlots();

  /// Adds a class. [SlotClash] when it clashes with other classes.
  Future<Result<SlotSaveOutcome>> createSlot(SlotDraft draft);

  /// Replaces the fields of the class [id] with [draft]'s.
  Future<Result<SlotSaveOutcome>> updateSlot(String id, SlotDraft draft);

  Future<Result<void>> deleteSlot(String id);
}
