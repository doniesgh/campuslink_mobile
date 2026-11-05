import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/notification_feed.dart';
import '../notification_routes.dart';
import '../providers/notification_providers.dart';
import '../widgets/alerts_header.dart';
import '../widgets/notification_card.dart';
import '../widgets/notification_extras.dart';
import '../widgets/notification_filter_bar.dart';

const _page = EdgeInsets.symmetric(horizontal: AppSpacing.page);

/// Stitch "12. Notifications & Alerts". Pushed over the tab shell from the Home bell.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsControllerProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm,
              ),
              child: DetailTopBar(
                backLabel: 'Home',
                fallbackPath: RoutePaths.home,
                trailing: [_ProfileButton()],
              ),
            ),
            Expanded(
              child: notifications.when(
                skipLoadingOnReload: true,
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: failureMessage(e),
                  onRetry: () => ref.invalidate(notificationsControllerProvider),
                ),
                data: (items) => _Feed(items: items),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feed extends ConsumerWidget {
  const _Feed({required this.items});

  final List<AppNotification> items;

  void _open(BuildContext context, WidgetRef ref, AppNotification n) {
    // Optimistic; the controller reverts the read state if the call fails.
    unawaited(ref.read(notificationsControllerProvider.notifier).markAsRead(n.id));
    final link = n.link;
    final route = link == null ? null : notificationRoute(link);
    // `go`, not `push`: this page sits above the tab shell (see notificationRoute).
    if (route != null) context.go(route);
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final failure = await ref.read(notificationsControllerProvider.notifier).markAllAsRead();
    if (failure != null && context.mounted) showAppSnack(context, failure.message);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final filter = ref.watch(notificationFilterProvider);
    final sections = groupByDay(filterNotifications(items, filter), now);

    return RefreshIndicator(
      onRefresh: ref.read(notificationsControllerProvider.notifier).refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Padding(
            padding: _page,
            child: AlertsHeader(
              unreadToday: unreadTodayCount(items, now),
              unreadTotal: unreadCount(items),
              onMarkAllRead: () => _markAllRead(context, ref),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          NotificationFilterBar(
            selected: filter,
            totalCount: items.length,
            hasUnreadUrgent: items.any((n) => n.isUrgent && !n.isRead),
            onSelected: (f) => ref.read(notificationFilterProvider.notifier).state = f,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Padding(padding: _page, child: BroadcastCard()),
          if (sections.isEmpty)
            EmptyView(message: _emptyMessage(filter), icon: Icons.notifications_off_outlined)
          else
            for (final section in sections) ...[
              Padding(
                padding: _page,
                child: _GroupHeader(notificationGroupTitle(section.group)),
              ),
              for (final n in section.items)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, 0, AppSpacing.page, AppSpacing.md,
                  ),
                  child: NotificationCard(
                    notification: n,
                    now: now,
                    onOpen: () => _open(context, ref, n),
                  ),
                ),
            ],
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: _page,
            child: SmsTipCard(
              // TODO: subscribe to SMS alerts once the notifications API exists.
              onEnable: () => showAppSnack(context, 'SMS alerts are coming soon.'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: _page,
            child: NotificationPreferencesTile(
              // TODO: open the notification preferences screen.
              onTap: () => showAppSnack(context, 'Notification preferences are coming soon.'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Padding(padding: _page, child: PrivacyFootnote()),
        ],
      ),
    );
  }
}

String _emptyMessage(NotificationFilter filter) => switch (filter) {
      NotificationFilter.all => 'No notifications yet.',
      NotificationFilter.academic => 'No academic notifications.',
      NotificationFilter.covoiturage => 'No covoiturage notifications.',
      NotificationFilter.urgent => 'No urgent alerts. All calm on campus!',
    };

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Avatar in the top bar, as in the design header; opens the Profile tab.
class _ProfileButton extends ConsumerWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authControllerProvider).valueOrNull?.displayName ?? '';
    return Tooltip(
      message: 'Profile',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.go(RoutePaths.profile),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: UserAvatar(name: name, radius: 16),
        ),
      ),
    );
  }
}
