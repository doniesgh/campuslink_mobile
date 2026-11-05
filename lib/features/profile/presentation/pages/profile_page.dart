import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/campus_header.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../providers/profile_providers.dart';
import '../widgets/academic_stats.dart';
import '../widgets/digital_id_card.dart';
import '../widgets/profile_hero.dart';
import '../widgets/services_settings_list.dart';

const _page = EdgeInsets.symmetric(horizontal: AppSpacing.page);

/// Stitch "10. Student Profile & Digital ID" (the Profile tab).
///
/// The settings list (theme + sign out) does not depend on the profile
/// request, so it stays usable when that request fails.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(studentProfileProvider);
    try {
      await ref.read(studentProfileProvider.future);
    } catch (_) {
      // The section shows its own error.
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Are you sure you want to log out of CampusPulse?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // The router redirects to the login screen once the user is null.
    await ref.read(authControllerProvider.notifier).logout();
  }

  void _comingSoon(BuildContext context, String feature) =>
      showAppSnack(context, '$feature is coming soon.');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);
    final profileAsync = ref.watch(studentProfileProvider);
    final profile = profileAsync.valueOrNull;
    final displayName = user?.displayName.trim() ?? '';
    final name = displayName.isEmpty ? 'Student' : displayName;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const CampusHeader(section: 'Profile'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _refresh(ref),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProfileHero(
                        name: name,
                        programLine: profile?.programLine,
                        campusStatus: profile != null && profile.isOnCampus
                            ? 'On Campus: ${profile.campusLocation}'
                            : null,
                        // TODO: profile editing (photo, contact details).
                        onEdit: () => _comingSoon(context, 'Profile editing'),
                        // TODO: NFC pass emulation (HCE) once the campus readers API exists.
                        onNfcPass: () => _comingSoon(context, 'NFC Student Pass'),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Padding(
                        padding: _page,
                        child: profileAsync.when(
                          skipLoadingOnReload: true,
                          loading: () => const _SectionLoading(height: 360),
                          error: (e, _) => _SectionError(
                            message: failureMessage(e),
                            onRetry: () => ref.invalidate(studentProfileProvider),
                          ),
                          data: (p) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AcademicStats(
                                profile: p,
                                onTap: () => context.push(RoutePaths.grades),
                              ),
                              const SizedBox(height: AppSpacing.xxl),
                              DigitalIdSection(profile: p, name: name, now: DateTime.now()),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Padding(
                        padding: _page,
                        child: ServicesSettingsList(
                          themeMode: themeMode,
                          onThemeModeChanged: (mode) =>
                              ref.read(themeModeProvider.notifier).set(mode),
                          semesterLabel: profile?.semesterLabel,
                          unreadNotifications: profile?.unreadNotifications ?? 0,
                          hasCarpoolActivity: profile?.hasCarpoolActivity ?? false,
                          onCurriculum: () => context.push(RoutePaths.grades),
                          // The Forum tab opens on its "Covoiturage" section.
                          onCarpool: () => context.go(RoutePaths.forum),
                          onNotifications: () => context.push(RoutePaths.notifications),
                          // TODO: SSO / Office365 account & privacy settings.
                          onPrivacy: () => _comingSoon(context, 'Campus SSO & Privacy'),
                          onSignOut: () => _confirmSignOut(context, ref),
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
        borderRadius: AppRadius.lgAll,
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
