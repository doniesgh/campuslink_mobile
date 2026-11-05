import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/academic_transcript.dart';
import '../../domain/grading.dart';
import '../providers/grades_providers.dart';
import '../widgets/course_grade_card.dart';
import '../widgets/semester_picker.dart';
import '../widgets/standing_hero_card.dart';
import '../widgets/transcript_sections.dart';

/// Stitch "11. Grades & Academic Transcript". Route: RoutePaths.grades.
class GradesPage extends ConsumerWidget {
  const GradesPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(transcriptProvider);
    try {
      await ref.read(transcriptProvider.future);
    } catch (_) {
      // The page shows the error.
    }
  }

  Future<void> _pickSemester(
    BuildContext context,
    WidgetRef ref,
    AcademicTranscript transcript,
    SemesterResult current,
  ) async {
    final id = await showSemesterPicker(
      context,
      semesters: transcript.semesters,
      selectedId: current.semester.id,
    );
    if (id != null && context.mounted) {
      ref.read(selectedSemesterIdProvider.notifier).state = id;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transcriptProvider);
    final selectedId = ref.watch(selectedSemesterIdProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final transcript = async.valueOrNull;
    final result = transcript == null ? null : semesterResultFor(transcript, selectedId);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm,
              ),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: DetailTopBar(
                  backLabel: 'Profile',
                  fallbackPath: RoutePaths.profile,
                  trailing: [
                    if (transcript != null && result != null)
                      // Takes (almost) all the space left by the back pill, so
                      // the label only ellipsizes when it really doesn't fit.
                      Flexible(
                        flex: 1000,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SemesterPickerPill(
                            label: result.semester.label,
                            onTap: () => _pickSemester(context, ref, transcript, result),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: async.when(
                skipLoadingOnReload: true,
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: failureMessage(e),
                  onRetry: () => ref.invalidate(transcriptProvider),
                ),
                data: (data) => result == null
                    ? const EmptyView(
                        message: 'No grades published yet.',
                        icon: Icons.school_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: () => _refresh(ref),
                        child: _GradesContent(
                          studentId: data.studentId,
                          result: result,
                          now: now,
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

class _GradesContent extends StatelessWidget {
  const _GradesContent({required this.studentId, required this.result, required this.now});

  final String studentId;
  final SemesterResult result;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semester = result.semester;
    final signedBy = semester.signedBy;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xxl,
      ),
      children: [
        RecordChips(
          studentId: studentId,
          isOfficial: semester.isOfficial,
          topPercent: result.topCohortPercent,
        ),
        const SizedBox(height: AppSpacing.md),
        StandingHeroCard(result: result, now: now),
        const SizedBox(height: AppSpacing.xl),
        ModuleBreakdownHeader(courseCount: result.courses.length),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < result.courses.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: CourseGradeCard(
              result: result.courses[i],
              accent: i.isEven ? scheme.primary : scheme.secondary,
            ),
          ),
        const SizedBox(height: AppSpacing.xl - AppSpacing.md),
        if (signedBy != null) ...[
          SignatureCard(signedBy: signedBy),
          const SizedBox(height: AppSpacing.xl),
        ],
        TranscriptDownloadCard(
          sizeMb: semester.documentSizeMb,
          // TODO: download the signed PDF transcript once the API exists.
          onDownload: () => showAppSnack(context, 'Transcript download is coming soon.'),
        ),
        if (result.isHonorRoll) ...[
          const SizedBox(height: AppSpacing.lg),
          HonorRollTile(semesterNumber: semester.number),
        ],
      ],
    );
  }
}
