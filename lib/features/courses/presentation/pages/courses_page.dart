import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/course_logic.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_resource.dart';
import '../providers/course_providers.dart';
import '../widgets/community_card.dart';
import '../widgets/course_actions.dart';
import '../widgets/course_headline.dart';
import '../widgets/course_resources_section.dart';
import '../widgets/course_switcher.dart';
import '../widgets/mastery_card.dart';
import '../widgets/modules_sheet.dart';
import '../widgets/professor_card.dart';
import '../widgets/submit_repo_sheet.dart';

/// Stitch "04. Course Mastery & Lessons". Route: RoutePaths.courses.
///
/// Shows one course at a time; the code pill of the top bar switches course.
class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key, this.initialCourseId});

  /// Course to open first: the id of its timetable sessions
  /// (e.g. 'genie-logiciel'). Defaults to the first course.
  final String? initialCourseId;

  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage> {
  String? _selectedId;

  // Changes made on this screen, applied on top of the loaded courses.
  final _attendance = <String, bool>{};
  final _submissions = <String, String>{};
  final _downloads = <String, ResourceDownloadState>{};
  bool _savingAttendance = false;

  Course _withLocalChanges(Course c) =>
      c.copyWith(isPresent: _attendance[c.id]).withSubmissions(_submissions);

  Future<void> _refresh() async {
    ref.invalidate(coursesProvider);
    try {
      await ref.read(coursesProvider.future);
    } catch (_) {
      // The page shows the error.
    }
  }

  Future<void> _pickCourse(List<Course> courses, Course current) async {
    final id = await showCoursePickerSheet(context, courses: courses, selectedId: current.id);
    if (id != null && mounted) setState(() => _selectedId = id);
  }

  Future<void> _toggleAttendance(Course course) async {
    final present = !course.isPresent;
    setState(() => _savingAttendance = true);
    final result =
        await ref.read(courseRepositoryProvider).setAttendance(course.id, present: present);
    if (!mounted) return;
    setState(() => _savingAttendance = false);
    result.when(
      success: (_) {
        setState(() => _attendance[course.id] = present);
        showAppSnack(context, present ? 'Attendance logged.' : 'Attendance removed.');
      },
      failure: (f) => showAppSnack(context, f.message),
    );
  }

  Future<void> _download(DocumentResource doc) async {
    setState(() => _downloads[doc.id] = ResourceDownloadState.downloading);
    final result = await ref.read(courseRepositoryProvider).downloadResource(doc.id);
    if (!mounted) return;
    result.when(
      success: (_) => setState(() => _downloads[doc.id] = ResourceDownloadState.done),
      failure: (f) {
        setState(() => _downloads.remove(doc.id));
        showAppSnack(context, f.message);
      },
    );
  }

  Future<void> _submit(AssignmentResource lab, DateTime now) async {
    final url = await showSubmitRepoSheet(context, lab: lab, now: now);
    if (url == null || !mounted) return;
    setState(() => _submissions[lab.id] = url);
    showAppSnack(context, '${lab.title} submitted.');
  }

  Future<void> _emailProfessor(Professor professor) async {
    // TODO: open the mail app (mailto:) once url_launcher is added.
    await Clipboard.setData(ClipboardData(text: professor.email));
    if (mounted) showAppSnack(context, 'Email copied: ${professor.email}');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(coursesProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final courses = async.valueOrNull ?? const <Course>[];
    final selected = selectCourse(courses, _selectedId ?? widget.initialCourseId);
    final course = selected == null ? null : _withLocalChanges(selected);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm,
              ),
              child: DetailTopBar(
                backLabel: 'Timetable',
                fallbackPath: RoutePaths.timetable,
                trailing: [
                  if (course != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    // Takes (almost) all the free space so a long code can
                    // shrink instead of overflowing the row.
                    Expanded(
                      flex: 1000,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: CourseSwitcherChip(
                          course: course,
                          onTap: courses.length > 1 ? () => _pickCourse(courses, course) : null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: async.when(
                skipLoadingOnReload: true,
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: failureMessage(e),
                  onRetry: () => ref.invalidate(coursesProvider),
                ),
                data: (_) => course == null
                    ? const EmptyView(
                        message: 'No courses this semester.',
                        icon: Icons.menu_book_outlined,
                      )
                    : _buildContent(course, now),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Course course, DateTime now) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xxl,
        ),
        children: [
          CourseHeadline(course: course),
          const SizedBox(height: AppSpacing.lg),
          ProfessorCard(
            professor: course.professor,
            onEmail: () => _emailProfessor(course.professor),
          ),
          const SizedBox(height: AppSpacing.lg),
          MasteryCard(
            course: course,
            now: now,
            onTap: () => showModulesSheet(context, course),
          ),
          const SizedBox(height: AppSpacing.xl),
          CourseResourcesSection(
            resources: course.resources,
            now: now,
            downloads: _downloads,
            onDownload: _download,
            // TODO: stream lesson recordings once the video backend exists.
            onStream: (_) => showAppSnack(context, 'Streaming is coming soon.'),
            onSubmit: (lab) => _submit(lab, now),
            // TODO: multi-select handouts for a bulk download.
            onSelectAll: () => showAppSnack(context, 'Bulk download is coming soon.'),
          ),
          const SizedBox(height: AppSpacing.xl - AppSpacing.sm),
          CommunityCard(
            community: course.community,
            // TODO: open the course community / helpdesk channel.
            onTap: () => showAppSnack(context, 'Course community is coming soon.'),
          ),
          const SizedBox(height: AppSpacing.xl),
          CourseActions(
            isPresent: course.isPresent,
            savingAttendance: _savingAttendance,
            onToggleAttendance: () => _toggleAttendance(course),
            // TODO: link to the course Discord server and forum category.
            onJoinCommunity: () => showAppSnack(context, 'Course Discord & Forum is coming soon.'),
          ),
        ],
      ),
    );
  }
}
