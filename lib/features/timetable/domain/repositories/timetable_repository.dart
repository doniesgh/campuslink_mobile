import '../../../../core/error/result.dart';
import '../entities/class_session.dart';
import '../entities/timetable_week.dart';

abstract interface class TimetableRepository {
  /// The student's sessions on [day].
  Future<Result<TimetableDay>> getDay(DateTime day);

  /// The week (Monday to Sunday) containing [day].
  Future<Result<TimetableWeek>> getWeek(DateTime day);
}
