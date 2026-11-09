import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/repositories/admin_repository_impl.dart';
import '../../data/repositories/mock_admin_repository.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/repositories/admin_repository.dart';

/// Mock data with USE_MOCK=true, the Node.js API otherwise. Kept alive so
/// the mock's accounts survive leaving the screens.
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  if (!Env.useMock) return AdminRepositoryImpl(ref.watch(dioProvider));
  return MockAdminRepository(currentUserId: () => ref.read(currentUserIdProvider));
});

/// Counts for the role chips ("Students · 15").
final userStatsProvider = FutureProvider.autoDispose<UserStats>(
  (ref) async => (await ref.watch(adminRepositoryProvider).getStats()).unwrap(),
);

/// One account, for its edit screen.
final managedUserProvider = FutureProvider.autoDispose.family<ManagedUser, String>(
  (ref, id) async => (await ref.watch(adminRepositoryProvider).getUser(id)).unwrap(),
);

/// The audit log's actions, for its filter chips.
final auditActionsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) async => (await ref.watch(adminRepositoryProvider).getAuditActions()).unwrap(),
);

/// A list loaded page by page: what is loaded so far, and the state of the
/// next page.
class PagedState<T> {
  const PagedState({
    required this.items,
    required this.total,
    required this.page,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<T> items;

  /// Matching items on every page.
  final int total;

  /// Last page loaded (1-based).
  final int page;
  final bool isLoadingMore;

  /// Why the next page didn't load (the list shows a retry button).
  final String? loadMoreError;

  bool get hasMore => items.length < total;

  PagedState<T> copyWith({bool? isLoadingMore, String? Function()? loadMoreError}) =>
      PagedState(
        items: items,
        total: total,
        page: page,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        loadMoreError: loadMoreError == null ? this.loadMoreError : loadMoreError(),
      );

  /// This state followed by [next], skipping items already listed (an
  /// account added meanwhile shifts the pages by one).
  PagedState<T> append(List<T> next, {required int total, required int page, required Object Function(T) id}) {
    final seen = {for (final item in items) id(item)};
    return PagedState(
      items: [...items, ...next.where((item) => !seen.contains(id(item)))],
      total: total,
      page: page,
    );
  }
}

/// The search and role filter of the Users screen.
typedef UserFilter = ({String query, UserRole? role});

/// Accounts matching a [UserFilter], 20 at a time.
final userListProvider = AsyncNotifierProvider.autoDispose
    .family<UserListController, PagedState<ManagedUser>, UserFilter>(UserListController.new);

class UserListController extends AutoDisposeFamilyAsyncNotifier<PagedState<ManagedUser>, UserFilter> {
  static const pageSize = 20;

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  @override
  Future<PagedState<ManagedUser>> build(UserFilter arg) async {
    final page = (await ref
            .watch(adminRepositoryProvider)
            .getUsers(query: arg.query, role: arg.role, limit: pageSize))
        .unwrap();
    return PagedState(items: page.items, total: page.total, page: page.page);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true, loadMoreError: () => null));
    final result = await _repo.getUsers(
      query: arg.query,
      role: arg.role,
      page: current.page + 1,
      limit: pageSize,
    );
    // A refresh started meanwhile: its result wins.
    if (state.valueOrNull?.isLoadingMore != true) return;
    state = AsyncData(result.when(
      success: (p) => current.append(p.items, total: p.total, page: p.page, id: (u) => u.id),
      failure: (f) => current.copyWith(isLoadingMore: false, loadMoreError: () => f.message),
    ));
  }
}

/// Audit entries of one action filter (null: every action), newest first.
final auditListProvider = AsyncNotifierProvider.autoDispose
    .family<AuditListController, PagedState<AuditEntry>, String?>(AuditListController.new);

class AuditListController extends AutoDisposeFamilyAsyncNotifier<PagedState<AuditEntry>, String?> {
  static const pageSize = 30;

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  @override
  Future<PagedState<AuditEntry>> build(String? arg) async {
    final page =
        (await ref.watch(adminRepositoryProvider).getAudit(action: arg, limit: pageSize)).unwrap();
    return PagedState(items: page.items, total: page.total, page: page.page);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true, loadMoreError: () => null));
    final result = await _repo.getAudit(action: arg, page: current.page + 1, limit: pageSize);
    if (state.valueOrNull?.isLoadingMore != true) return;
    state = AsyncData(result.when(
      success: (p) => current.append(p.items, total: p.total, page: p.page, id: (e) => e.id),
      failure: (f) => current.copyWith(isLoadingMore: false, loadMoreError: () => f.message),
    ));
  }
}

/// Reloads everything the admin screens show, after a change.
void refreshAdminData(WidgetRef ref, {String? userId}) {
  ref.invalidate(userListProvider);
  ref.invalidate(userStatsProvider);
  ref.invalidate(auditListProvider);
  ref.invalidate(auditActionsProvider);
  if (userId != null) ref.invalidate(managedUserProvider(userId));
}
