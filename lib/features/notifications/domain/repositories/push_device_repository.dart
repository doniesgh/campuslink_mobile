import '../../../../core/error/result.dart';
import '../entities/push_message.dart';

/// The phones the API pushes to (`/push/devices`).
abstract interface class PushDeviceRepository {
  /// Tells the API to push the signed-in user's notifications to [token].
  /// Signing out removes it (the token goes with the logout request).
  Future<Result<void>> register(String token, PushPlatform platform);
}
