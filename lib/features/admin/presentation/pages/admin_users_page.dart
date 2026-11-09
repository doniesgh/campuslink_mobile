import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_search_field.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/user_tile.dart';

/// Administration › Users: search the accounts, filter them by role, and
/// open one to edit it. Admins only (route guarded by `authRedirect`).
/// No Stitch design: built on the look of the Jobs and Notifications screens.
class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  static const _searchDelay = Duration(milliseconds: 350);

  String _query = '';
  UserRole? _role;
  Timer? _debounce;

  UserFilter get _filter => (query: _query, role: _role);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Searches once the admin stops typing, not on every key.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDelay, () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(userStatsProvider);
    ref.invalidate(userListProvider(_filter));
    try {
      await ref.read(userListProvider(_filter).future);
    } catch (_) {
      // The list shows its own error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(userStatsProvider).valueOrNull;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.newUser),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add user'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.md, AppSpacing.page, 0,
              ),
              child: DetailTopBar(
                backLabel: 'Profile',
                fallbackPath: RoutePaths.profile,
                trailing: [
                  IconButton(
                    tooltip: 'Import accounts',
                    icon: const Icon(Icons.upload_file_outlined),
                    onPressed: () => context.push(RoutePaths.importUsers),
                  ),
                  IconButton(
                    tooltip: 'Audit log',
                    icon: const Icon(Icons.history),
                    onPressed: () => context.push(RoutePaths.auditLog),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.md,
              ),
              child: AdminTitle(
                title: 'Users',
                subtitle: 'Create accounts, choose their role and reset passwords.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: AppSearchField(hint: 'Name, email or ENT ID', onChanged: _onSearchChanged),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilterChipBar<UserRole?>(
              selected: _role,
              onSelected: (role) => setState(() => _role = role),
              options: [
                (null, 'All', null, stats?.total),
                for (final role in UserRole.values)
                  (role, rolePlural(role), roleIcon(role), stats?.count(role)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _list()),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    final filter = _filter;
    final async = ref.watch(userListProvider(filter));
    final me = ref.watch(currentUserIdProvider);
    final filtered = _query.isNotEmpty || _role != null;

    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: failureMessage(e),
        onRetry: () => ref.invalidate(userListProvider(filter)),
      ),
      data: (list) {
        final controller = ref.read(userListProvider(filter).notifier);
        if (list.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: AppSpacing.huge),
                EmptyView(
                  icon: Icons.person_search_outlined,
                  message: filtered ? 'No account matches.' : 'No accounts yet.',
                ),
              ],
            ),
          );
        }
        final countLabel = switch (list.total) {
          1 => filtered ? '1 result' : '1 account',
          final n => filtered ? '$n results' : '$n accounts',
        };
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            // Room for the "Add user" button over the last account.
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 96),
            itemCount: list.items.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    countLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                );
              }
              if (i == list.items.length + 1) {
                return PagedListFooter(
                  isLoading: list.isLoadingMore,
                  error: list.loadMoreError,
                  onRetry: controller.loadMore,
                );
              }
              final index = i - 1;
              // Close to the end: fetch the next page.
              if (index >= list.items.length - 4 && list.hasMore && list.loadMoreError == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) ref.read(userListProvider(filter).notifier).loadMore();
                });
              }
              final user = list.items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: UserTile(
                  user: user,
                  isYou: user.id == me,
                  onTap: () => context.push(RoutePaths.adminUser(user.id)),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
