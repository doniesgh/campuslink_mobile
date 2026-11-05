import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_search_field.dart';
import '../../../../shared/widgets/campus_header.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/job_providers.dart';
import '../widgets/job_card.dart';

/// "Jobs" tab: list of internship / job offers.
class JobsPage extends ConsumerStatefulWidget {
  const JobsPage({super.key});

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(jobsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const CampusHeader(section: 'Jobs'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: AppSearchField(
                hint: 'Search internships, companies...',
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: jobs.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: failureMessage(e),
                  onRetry: () => ref.invalidate(jobsProvider),
                ),
                data: (all) {
                  final list = all
                      .where((j) =>
                          _query.isEmpty ||
                          j.title.toLowerCase().contains(_query) ||
                          j.company.toLowerCase().contains(_query))
                      .toList();
                  if (list.isEmpty) return const EmptyView(message: 'No offers found.');
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl,
                    ),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (_, i) => JobCard(
                      job: list[i],
                      onTap: () => context.push(RoutePaths.job(list[i].id)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
