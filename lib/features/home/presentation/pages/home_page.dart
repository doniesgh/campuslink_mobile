import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/campus_header.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../../../admin/presentation/widgets/admin_overview_card.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../forum/domain/entities/forum_post.dart';
import '../../../forum/presentation/pages/forum_page.dart';
import '../../../forum/presentation/providers/forum_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../timetable/presentation/providers/timetable_providers.dart';
import '../widgets/highlight_post_card.dart';
import '../widgets/home_greeting.dart';
import '../widgets/home_section_header.dart';
import '../widgets/quick_actions.dart';
import '../widgets/today_schedule.dart';
import '../widgets/up_next_card.dart';

const _page = EdgeInsets.symmetric(horizontal: AppSpacing.page);

ForumSection _forumSectionFor(PostCategory category) => switch (category) {
      PostCategory.carpool => ForumSection.carpooling,
      PostCategory.lostFound => ForumSection.lostFound,
      PostCategory.idea => ForumSection.ideas,
    };

/// Stitch "02. Home & Today Hub".
///
/// Admins, alumni and companies have no timetable: no "Up next" or "Today's Schedule"
/// for them. Admins get the [AdminOverviewCard] instead.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _refresh(WidgetRef ref, User? user) async {
    final hasClasses = user?.hasClasses ?? true;
    final isAdmin = user?.isAdmin ?? false;
    if (hasClasses) ref.invalidate(todayTimetableProvider);
    if (isAdmin) ref.invalidate(userStatsProvider);
    ref.invalidate(highlightsProvider);
    try {
      await Future.wait([
        if (hasClasses) ref.read(todayTimetableProvider.future),
        if (isAdmin) ref.read(userStatsProvider.future),
        ref.read(highlightsProvider.future),
      ]);
    } catch (_) {
      // Each section shows its own error.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final user = ref.watch(authControllerProvider).valueOrNull;
    final name = user?.displayName ?? '';
    final hasClasses = user?.hasClasses ?? true;
    final timetable = hasClasses ? ref.watch(todayTimetableProvider) : null;
    final highlights = ref.watch(highlightsProvider);
    final courseCount = timetable?.valueOrNull?.sessions.length;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const CampusHeader(section: 'Home'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _refresh(ref, user),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: _page,
                        child: HomeGreeting(
                          name: name,
                          now: now,
                          semesterWeek: timetable?.valueOrNull?.semesterWeek,
                          hasUnreadNotifications: unreadNotifications > 0,
                          onNotifications: () => context.push(RoutePaths.notifications),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (timetable != null) ...[
                        Padding(
                          padding: _page,
                          child: timetable.when(
                            skipLoadingOnReload: true,
                            loading: () => const _SectionLoading(height: 170),
                            error: (e, _) => _SectionError(
                              message: failureMessage(e),
                              onRetry: () => ref.invalidate(todayTimetableProvider),
                            ),
                            data: (day) => UpNextCard(
                              sessions: day.sessions,
                              now: now,
                              onTap: () => context.go(RoutePaths.timetable),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ] else if (user?.isAdmin ?? false) ...[
                        const Padding(padding: _page, child: AdminOverviewCard()),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      Padding(
                        padding: _page,
                        child: QuickActions(role: user?.role ?? UserRole.student),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (timetable != null) ...[
                        Padding(
                          padding: _page,
                          child: HomeSectionHeader(
                            title: "Today's Schedule",
                            badge: courseCount == null || courseCount == 0
                                ? null
                                : AppBadge(
                                    '$courseCount course${courseCount == 1 ? '' : 's'}',
                                    tone: BadgeTone.neutral,
                                  ),
                            actionLabel: 'View all',
                            onAction: () => context.go(RoutePaths.timetable),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        timetable.when(
                          skipLoadingOnReload: true,
                          loading: () => const _SectionLoading(height: 150),
                          // The error is already shown in place of the "Up next" card.
                          error: (_, __) => const SizedBox.shrink(),
                          data: (day) => TodaySchedule(sessions: day.sessions, now: now),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      Padding(
                        padding: _page,
                        child: HomeSectionHeader(
                          title: 'Campus Highlights',
                          badge: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: scheme.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          actionLabel: 'Forum',
                          onAction: () => context.go(RoutePaths.forum),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Padding(
                        padding: _page,
                        child: highlights.when(
                          skipLoadingOnReload: true,
                          loading: () => const _SectionLoading(height: 200),
                          error: (e, _) => _SectionError(
                            message: failureMessage(e),
                            onRetry: () => ref.invalidate(highlightsProvider),
                          ),
                          data: (posts) => posts.isEmpty
                              ? const EmptyView(message: 'Nothing new on campus yet.')
                              : Column(
                                  children: [
                                    for (final post in posts)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                        child: HighlightPostCard(
                                          post: post,
                                          now: now,
                                          onOpen: () {
                                            ref.read(forumSectionProvider.notifier).state =
                                                _forumSectionFor(post.category);
                                            context.go(RoutePaths.forum);
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
}

/// Compact error with a retry link, used inside a scrolling page.
class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
