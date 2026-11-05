import '../../../../core/error/result.dart';
import '../entities/class_session.dart';

abstract interface class TimetableRepository {
  /// The student's sessions on [day].
  Future<Result<TimetableDay>> getDay(DateTime day);
}
