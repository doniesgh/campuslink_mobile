import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/bottom_action_bar.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_draft.dart';
import '../../domain/job_form_rules.dart';
import '../providers/job_providers.dart';

/// "New offer" / "Edit offer" form, for companies and admins (the API
/// refuses everyone else). Edits offer [jobId] when given.
class JobFormPage extends ConsumerWidget {
  const JobFormPage({super.key, this.jobId});

  final String? jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = jobId;
    if (id == null) return const _JobForm();
    final job = ref.watch(jobDetailProvider(id));
    return job.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        body: SafeArea(
          child: ErrorView(
            message: failureMessage(e),
            onRetry: () => ref.invalidate(jobDetailProvider(id)),
          ),
        ),
      ),
      data: (job) => _JobForm(job: job),
    );
  }
}

class _JobForm extends ConsumerStatefulWidget {
  const _JobForm({this.job});

  /// The offer being edited, null for a new one.
  final Job? job;

  @override
  ConsumerState<_JobForm> createState() => _JobFormState();
}

class _JobFormState extends ConsumerState<_JobForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _company;
  late final TextEditingController _location;
  late final TextEditingController _period;
  late final TextEditingController _duration;
  late final TextEditingController _stipend;
  late final TextEditingController _skills;
  late final TextEditingController _tags;
  late final TextEditingController _description;
  bool _submitted = false;
  bool _saving = false;

  bool get _editing => widget.job != null;

  @override
  void initState() {
    super.initState();
    final job = widget.job;
    final draft = job == null ? null : JobDraft.fromJob(job);
    _title = TextEditingController(text: draft?.title);
    _company = TextEditingController(text: draft?.company);
    _location = TextEditingController(text: draft?.location);
    _period = TextEditingController(text: draft?.period);
    _duration = TextEditingController(text: draft?.durationMonths?.toString());
    _stipend = TextEditingController(text: draft?.stipendTnd?.toString());
    _skills = TextEditingController(text: draft?.skills.join(', '));
    _tags = TextEditingController(text: draft?.tags.join(', '));
    _description = TextEditingController(text: draft?.description);
  }

  @override
  void dispose() {
    for (final c in [
      _title, _company, _location, _period, _duration, _stipend, _skills, _tags, _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  JobDraft _draft() => JobDraft(
        title: _title.text.trim(),
        company: _company.text.trim(),
        description: _description.text.trim(),
        location: _location.text.trim(),
        period: _period.text.trim(),
        durationMonths: JobFormRules.parseNumber(_duration.text),
        stipendTnd: JobFormRules.parseNumber(_stipend.text),
        skills: JobFormRules.splitList(_skills.text),
        tags: JobFormRules.splitList(_tags.text),
      );

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      showAppSnack(context, 'Check the highlighted fields.');
      return;
    }
    setState(() => _saving = true);
    final repository = ref.read(jobRepositoryProvider);
    final job = widget.job;
    final result =
        job == null ? await repository.createJob(_draft()) : await repository.updateJob(job.id, _draft());
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (saved) {
        ref.invalidate(jobsProvider);
        ref.invalidate(jobDetailProvider(saved.id));
        if (job == null) {
          showAppSnack(context, 'Offer published. Students can see it now.');
          context.pushReplacement(RoutePaths.job(saved.id));
        } else {
          showAppSnack(context, 'Offer updated.');
          context.canPop() ? context.pop() : context.go(RoutePaths.job(saved.id));
        }
      },
      failure: (f) => showAppSnack(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                autovalidateMode:
                    _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                // Not a ListView: a lazy list would leave the fields below the
                // fold out of the form's validation.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DetailTopBar(
                        backLabel: _editing ? 'Offer' : 'Opportunities',
                        fallbackPath: _editing ? RoutePaths.job(widget.job!.id) : RoutePaths.jobs,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        _editing ? 'Edit offer' : 'New offer',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Only the title, the company and the description are required.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _Field(
                        name: 'title',
                        label: 'Title *',
                        controller: _title,
                        hint: 'e.g. Flutter Mobile Intern',
                        validator: JobFormRules.title,
                      ),
                      _Field(
                        name: 'company',
                        label: 'Company *',
                        controller: _company,
                        hint: 'e.g. Medina Soft',
                        validator: JobFormRules.company,
                      ),
                      _Field(
                        name: 'location',
                        label: 'Location',
                        controller: _location,
                        hint: 'e.g. Lac 1, Tunis',
                        validator: JobFormRules.location,
                      ),
                      _Field(
                        name: 'period',
                        label: 'Period',
                        controller: _period,
                        hint: 'e.g. Feb – Jul 2026',
                        validator: JobFormRules.period,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Field(
                              name: 'duration',
                              label: 'Duration (months)',
                              controller: _duration,
                              hint: '6',
                              validator: JobFormRules.durationMonths,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _Field(
                              name: 'stipend',
                              label: 'Stipend (TND/month)',
                              controller: _stipend,
                              hint: '800',
                              validator: JobFormRules.stipendTnd,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      _Field(
                        name: 'skills',
                        label: 'Skills',
                        controller: _skills,
                        hint: 'Flutter, Dart, Firebase',
                        helper: 'Separated by commas',
                        validator: JobFormRules.skills,
                      ),
                      _Field(
                        name: 'tags',
                        label: 'Tags',
                        controller: _tags,
                        hint: 'PFE 2026, Hybrid',
                        helper: 'Separated by commas',
                        validator: JobFormRules.tags,
                      ),
                      _Field(
                        name: 'description',
                        label: 'Description *',
                        controller: _description,
                        hint: 'Missions, profile wanted, team…',
                        validator: JobFormRules.description,
                        maxLength: JobFormRules.descriptionMax,
                        maxLines: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            BottomActionBar(
              leading: Text(
                _editing ? 'Changes are visible at once.' : 'Visible to every student.',
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
              action: AppButton(
                label: _editing ? 'Save' : 'Publish',
                icon: Icons.check_rounded,
                variant: AppButtonVariant.accent,
                isLoading: _saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled field of the form.
class _Field extends StatelessWidget {
  const _Field({
    required this.name,
    required this.label,
    required this.controller,
    required this.validator,
    this.hint,
    this.helper,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
  });

  /// Keys the input (`ValueKey('job-form-title')`), for tests.
  final String name;
  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  /// Shows a counter and stops the typing there.
  final int? maxLength;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          TextFormField(
            key: ValueKey('job-form-$name'),
            controller: controller,
            validator: validator,
            keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
            maxLines: maxLines,
            minLines: maxLines > 1 ? 4 : 1,
            maxLength: maxLength,
            textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
            decoration: InputDecoration(hintText: hint, helperText: helper),
          ),
        ],
      ),
    );
  }
}
