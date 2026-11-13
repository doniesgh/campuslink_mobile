import '../../../../core/error/result.dart';
import '../../../auth/domain/entities/user.dart';
import '../entities/audit_entry.dart';
import '../entities/managed_user.dart';
import '../entities/user_import.dart';
import '../import_assist.dart';

/// User management and the audit log (`/admin/*`, admins only).
abstract interface class AdminRepository {
  /// Accounts matching [query] (every word must appear in the name, email or
  /// ENT ID) and [role], sorted by name.
  Future<Result<UserPage>> getUsers({
    String query = '',
    UserRole? role,
    int page = 1,
    int limit = 20,
  });

  Future<Result<UserStats>> getStats();

  Future<Result<ManagedUser>> getUser(String id);

  Future<Result<ManagedUser>> createUser(NewUser user);

  /// On the admin's own account, only the name, email and ENT ID can change.
  Future<Result<ManagedUser>> updateUser(String id, UserChanges changes);

  /// Refused for the admin's own account.
  Future<Result<void>> deleteUser(String id);

  /// Dry run: checks [rows] against the accounts that exist, creates nothing.
  Future<Result<ImportCheck>> checkImport(List<ImportRow> rows);

  /// Creates every account of [rows] (at most 50), or none of them.
  Future<Result<ImportOutcome>> importUsers(List<ImportRow> rows);

  /// Whether the server can read an import file with AI ("Read with AI").
  Future<Result<ImportAssistStatus>> getImportAssistStatus();

  /// Asks the AI how a file is laid out, from its first lines (masked, see
  /// [assistRequest]). Imports nothing. Fails with the server's message when
  /// the AI isn't set up (503), busy (429) or couldn't answer (502).
  Future<Result<ImportAssistAnswer>> assistImport(AssistRequest request);

  /// [action] is exact ("user.update") or a prefix ("user.*"); null for all.
  Future<Result<AuditPage>> getAudit({String? action, int page = 1, int limit = 30});

  /// The actions recorded so far, for the filter.
  Future<Result<List<String>>> getAuditActions();
}
